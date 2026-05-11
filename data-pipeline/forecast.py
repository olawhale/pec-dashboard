"""
Nightly Prophet forecast job.
Reads monthly PEC actuals from SQL, trains a model per partner,
writes predictions into FactPECForecast for the next 6 months.
"""
from __future__ import annotations

import logging
import os
from datetime import date

import pandas as pd
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from prophet import Prophet

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

KV_NAME    = os.environ["KEY_VAULT_NAME"]
HORIZON    = 6   # months ahead to forecast
MIN_ROWS   = 3   # skip partners with fewer than this many months of data


def get_conn_str(kv_name: str) -> str:
    cred = DefaultAzureCredential()
    kv   = SecretClient(vault_url=f"https://{kv_name}.vault.azure.net", credential=cred)
    return kv.get_secret("sql-connection-string").value


def load_actuals(conn_str: str) -> pd.DataFrame:
    query = """
        SELECT
            dp.PartnerKey,
            dp.PartnerName,
            DATEFROMPARTS(dd.[Year], dd.[Month], 1) AS MonthStart,
            SUM(f.PECAmount) AS PECAmount
        FROM dbo.FactPEC f
        JOIN dbo.DimDate    dd ON f.DateKey    = dd.DateKey
        JOIN dbo.DimPartner dp ON f.PartnerKey = dp.PartnerKey
        WHERE f.PECApplied = 1
        GROUP BY dp.PartnerKey, dp.PartnerName, dd.[Year], dd.[Month]
        ORDER BY dp.PartnerKey, MonthStart;
    """
    with pyodbc.connect(conn_str, timeout=30) as conn:
        return pd.read_sql(query, conn)


def train_and_forecast(actuals: pd.DataFrame, partner_key: int) -> pd.DataFrame:
    sub = actuals[actuals["PartnerKey"] == partner_key].copy()
    sub = sub.rename(columns={"MonthStart": "ds", "PECAmount": "y"})
    sub["ds"] = pd.to_datetime(sub["ds"])

    model = Prophet(
        yearly_seasonality=True,
        weekly_seasonality=False,
        daily_seasonality=False,
        interval_width=0.80,
    )
    model.fit(sub[["ds", "y"]])

    future = model.make_future_dataframe(periods=HORIZON, freq="MS")
    forecast = model.predict(future)

    future_only = forecast[forecast["ds"] > sub["ds"].max()].copy()
    future_only["PartnerKey"]  = partner_key
    future_only["ModelRunDate"] = date.today()
    return future_only[["ds", "PartnerKey", "yhat", "yhat_lower", "yhat_upper", "ModelRunDate"]]


def write_forecasts(conn_str: str, forecasts: pd.DataFrame, model_run: date) -> None:
    with pyodbc.connect(conn_str, timeout=30) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "DELETE FROM dbo.FactPECForecast WHERE ModelRunDate = ?", model_run
        )
        for _, row in forecasts.iterrows():
            date_key = int(row["ds"].strftime("%Y%m%d"))
            cursor.execute(
                """
                INSERT INTO dbo.FactPECForecast
                    (DateKey, PartnerKey, ForecastedPECAmount,
                     LowerBound, UpperBound, ModelRunDate)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                date_key,
                int(row["PartnerKey"]),
                max(float(row["yhat"]), 0),
                max(float(row["yhat_lower"]), 0),
                max(float(row["yhat_upper"]), 0),
                str(model_run),
            )
        conn.commit()
    log.info("Wrote %d forecast rows (model run %s)", len(forecasts), model_run)


def main() -> None:
    conn_str = get_conn_str(KV_NAME)
    actuals  = load_actuals(conn_str)
    log.info("Loaded %d actuals rows across %d partners",
             len(actuals), actuals["PartnerKey"].nunique())

    all_forecasts = []
    for partner_key in actuals["PartnerKey"].unique():
        sub = actuals[actuals["PartnerKey"] == partner_key]
        if len(sub) < MIN_ROWS:
            log.warning("Skipping PartnerKey=%d — only %d months of data", partner_key, len(sub))
            continue
        log.info("Training forecast for PartnerKey=%d", partner_key)
        fc = train_and_forecast(actuals, partner_key)
        all_forecasts.append(fc)

    if not all_forecasts:
        log.warning("No forecasts generated.")
        return

    combined = pd.concat(all_forecasts, ignore_index=True)
    write_forecasts(conn_str, combined, date.today())
    log.info("Forecast job complete.")


if __name__ == "__main__":
    main()
