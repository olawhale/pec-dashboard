"""
Daily PEC ingestion: Cost Management API → ADLS Gen2 bronze → Azure SQL star schema.
Run as a scheduled container job (ACI or App Service WebJob).
"""
from __future__ import annotations

import json
import logging
import os
from datetime import date, timedelta

import pandas as pd
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.mgmt.costmanagement import CostManagementClient
from azure.mgmt.costmanagement.models import (
    ExportType,
    QueryDataset,
    QueryDefinition,
    QueryTimePeriod,
    TimeframeType,
)
from azure.storage.filedatalake import DataLakeServiceClient
from tenacity import retry, stop_after_attempt, wait_exponential

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

BILLING_ACCOUNT_ID = os.environ.get("BILLING_ACCOUNT_ID", "")
SUBSCRIPTION_ID    = os.environ.get("SUBSCRIPTION_ID", "")
STORAGE_ACCOUNT    = os.environ["STORAGE_ACCOUNT_NAME"]
KV_NAME            = os.environ.get("KEY_VAULT_NAME")   # optional when secrets passed directly
CONTAINER          = "bronze"


DRIVER = "{ODBC Driver 18 for SQL Server}"


def _to_pyodbc(conn_str: str) -> str:
    if "DRIVER=" in conn_str.upper():
        return conn_str
    parts = {k.strip(): v.strip() for k, v in
             (p.split("=", 1) for p in conn_str.split(";") if "=" in p)}
    server   = parts.get("Server", parts.get("Data Source", ""))
    database = parts.get("Database", parts.get("Initial Catalog", ""))
    uid      = parts.get("User Id", parts.get("UID", ""))
    pwd      = parts.get("Password", parts.get("PWD", ""))
    encrypt  = parts.get("Encrypt", "yes")
    return (
        f"DRIVER={DRIVER};SERVER={server};DATABASE={database};"
        f"UID={uid};PWD={pwd};Encrypt={encrypt};TrustServerCertificate=no"
    )


def get_conn_str(cred: DefaultAzureCredential) -> str:
    if os.environ.get("SQL_CONNECTION_STRING"):
        return _to_pyodbc(os.environ["SQL_CONNECTION_STRING"])
    kv = SecretClient(vault_url=f"https://{KV_NAME}.vault.azure.net", credential=cred)
    return _to_pyodbc(kv.get_secret("sql-connection-string").value)


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2))
def fetch_pec_data(
    cm_client: CostManagementClient,
    query_scope: str,
    start: date,
    end: date,
) -> list[dict]:
    """Query Cost Management for cost rows.

    At billing-account scope (CSP): PartnerEarnedCreditApplied is available.
    At subscription scope: falls back to Cost + MeterCategory grouping.
    """
    is_sub_scope = "/subscriptions/" in query_scope and "/billingAccounts/" not in query_scope

    if is_sub_scope:
        aggregation = {
            "totalCost": {"name": "Cost", "function": "Sum"},
        }
        grouping = [
            {"type": "Dimension", "name": "SubscriptionId"},
            {"type": "Dimension", "name": "SubscriptionName"},
            {"type": "Dimension", "name": "ServiceName"},
            {"type": "Dimension", "name": "MeterCategory"},
            {"type": "Dimension", "name": "ChargeType"},
        ]
    else:
        aggregation = {
            "totalCost": {"name": "Cost",                       "function": "Sum"},
            "pecAmount": {"name": "PartnerEarnedCreditApplied", "function": "Sum"},
        }
        grouping = [
            {"type": "Dimension", "name": "SubscriptionId"},
            {"type": "Dimension", "name": "SubscriptionName"},
            {"type": "Dimension", "name": "ServiceName"},
            {"type": "Dimension", "name": "ServiceFamily"},
            {"type": "Dimension", "name": "PublisherName"},
            {"type": "Dimension", "name": "ChargeType"},
            {"type": "Dimension", "name": "BillingCurrency"},
        ]

    definition = QueryDefinition(
        type=ExportType.ACTUAL_COST,
        timeframe=TimeframeType.CUSTOM,
        time_period=QueryTimePeriod(from_property=start, to=end),
        dataset=QueryDataset(
            granularity="Daily",
            aggregation=aggregation,
            grouping=grouping,
        ),
    )
    result = cm_client.query.usage(scope=query_scope, parameters=definition)
    rows = []
    columns = [c.name for c in result.columns]
    for row in result.rows:
        r = dict(zip(columns, row))
        # Normalise field names so downstream code is consistent
        if "pecAmount" not in r:
            r["pecAmount"] = r.get("totalCost", 0)   # treat full cost as proxy PEC
        if "ServiceFamily" not in r:
            r["ServiceFamily"] = r.get("MeterCategory", "Unknown")
        if "PublisherName" not in r:
            r["PublisherName"] = "Microsoft"
        if "BillingCurrency" not in r:
            r["BillingCurrency"] = "USD"
        rows.append(r)
    return rows


def upload_to_bronze(
    adls: DataLakeServiceClient,
    data: list[dict],
    run_date: date,
) -> str:
    """Write raw JSON to bronze/pec/YYYY/MM/DD/data.json and return the path."""
    fs = adls.get_file_system_client(CONTAINER)
    path = f"pec/{run_date.year}/{run_date.month:02d}/{run_date.day:02d}/data.json"
    file_client = fs.get_file_client(path)
    content = json.dumps(data, default=str).encode()
    file_client.upload_data(content, overwrite=True)
    log.info("Uploaded %d rows to bronze/%s", len(data), path)
    return path


def upsert_to_sql(conn_str: str, df: pd.DataFrame, source_file: str) -> None:
    """Upsert PEC data into the SQL star schema."""
    with pyodbc.connect(conn_str, timeout=30) as conn:
        cursor = conn.cursor()

        for _, row in df.iterrows():
            # Upsert DimService
            cursor.execute(
                """
                MERGE dbo.DimService AS t
                USING (SELECT ? AS ServiceName, ? AS ServiceFamily,
                              ? AS ServiceCategory, ? AS PublisherName) AS s
                ON t.ServiceName = s.ServiceName AND t.PublisherName = s.PublisherName
                WHEN NOT MATCHED THEN INSERT (ServiceName, ServiceFamily, ServiceCategory, PublisherName)
                    VALUES (s.ServiceName, s.ServiceFamily, s.ServiceCategory, s.PublisherName);
                """,
                row.get("ServiceName", "Unknown"),
                row.get("ServiceFamily", "Unknown"),
                row.get("ServiceName", "Unknown"),
                row.get("PublisherName", "Microsoft"),
            )

            # Upsert DimSubscription / DimCustomer
            cursor.execute(
                """
                MERGE dbo.DimCustomer AS t
                USING (SELECT ? AS CustomerTenantId, ? AS CustomerName) AS s
                ON t.CustomerTenantId = s.CustomerTenantId
                WHEN NOT MATCHED THEN INSERT (CustomerTenantId, CustomerName)
                    VALUES (s.CustomerTenantId, s.CustomerName);
                """,
                row.get("SubscriptionId", "unknown"),
                row.get("SubscriptionName", "Unknown"),
            )
            cursor.execute(
                """
                MERGE dbo.DimSubscription AS t
                USING (SELECT ? AS SubscriptionId, ? AS SubscriptionName,
                              (SELECT CustomerKey FROM dbo.DimCustomer
                               WHERE CustomerTenantId = ?) AS CustomerKey) AS s
                ON t.SubscriptionId = s.SubscriptionId
                WHEN NOT MATCHED THEN INSERT (SubscriptionId, SubscriptionName, CustomerKey)
                    VALUES (s.SubscriptionId, s.SubscriptionName, s.CustomerKey);
                """,
                row.get("SubscriptionId", "unknown"),
                row.get("SubscriptionName", "Unknown"),
                row.get("SubscriptionId", "unknown"),
            )

            # Insert FactPEC row
            date_key = int(str(row["UsageDate"]).replace("-", "")[:8])
            cursor.execute(
                """
                INSERT INTO dbo.FactPEC
                    (DateKey, PartnerKey, CustomerKey, SubscriptionKey, ServiceKey,
                     BillingCurrency, ChargeType, UnitAmount, PECAmount,
                     PECPercentage, PECApplied, SourceFileName)
                SELECT
                    ?,
                    1,  -- PartnerKey: replace with real lookup when multi-partner
                    dc.CustomerKey,
                    ds2.SubscriptionKey,
                    ds.ServiceKey,
                    ?, ?, ?, ?,
                    CASE WHEN ? > 0 THEN 0.15 ELSE 0 END,
                    CASE WHEN ? > 0 THEN 1    ELSE 0 END,
                    ?
                FROM dbo.DimService ds
                CROSS JOIN dbo.DimCustomer dc
                CROSS JOIN dbo.DimSubscription ds2
                WHERE ds.ServiceName = ? AND ds.PublisherName = ?
                  AND dc.CustomerTenantId = ?
                  AND ds2.SubscriptionId = ?;
                """,
                date_key,
                row.get("BillingCurrency", "USD"),
                row.get("ChargeType", "Usage"),
                float(row.get("totalCost", 0)),
                float(row.get("pecAmount", 0)),
                float(row.get("pecAmount", 0)),
                float(row.get("pecAmount", 0)),
                source_file,
                row.get("ServiceName", "Unknown"),
                row.get("PublisherName", "Microsoft"),
                row.get("SubscriptionId", "unknown"),
                row.get("SubscriptionId", "unknown"),
            )

        conn.commit()
    log.info("Upserted %d rows into FactPEC", len(df))


def main() -> None:
    cred = DefaultAzureCredential()
    conn_str = get_conn_str(cred)

    # Prefer subscription scope (needs only Cost Management Reader on the sub).
    # Fall back to billing account scope if SUBSCRIPTION_ID is not set.
    if SUBSCRIPTION_ID:
        query_scope = f"/subscriptions/{SUBSCRIPTION_ID}"
    else:
        query_scope = f"/providers/Microsoft.Billing/billingAccounts/{BILLING_ACCOUNT_ID}"
    log.info("Query scope: %s", query_scope)

    cm_client  = CostManagementClient(credential=cred, subscription_id=None)
    adls       = DataLakeServiceClient(
        account_url=f"https://{STORAGE_ACCOUNT}.dfs.core.windows.net",
        credential=cred,
    )

    end   = date.today() - timedelta(days=1)
    start = end - timedelta(days=1)          # yesterday; widen window as needed

    log.info("Fetching PEC data %s to %s", start, end)
    rows = fetch_pec_data(cm_client, query_scope, start, end)
    if not rows:
        log.warning("No PEC rows returned for %s to %s", start, end)
        return

    source_path = upload_to_bronze(adls, rows, end)
    df = pd.DataFrame(rows)
    df["UsageDate"] = end
    upsert_to_sql(conn_str, df, source_path)
    log.info("Ingest complete.")


if __name__ == "__main__":
    main()
