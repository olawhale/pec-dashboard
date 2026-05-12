from __future__ import annotations

import os
import pyodbc
from functools import lru_cache
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

_DRIVER = "{ODBC Driver 18 for SQL Server}"


def _to_pyodbc(conn_str: str) -> str:
    """Convert ADO.NET-style connection string to pyodbc format if needed."""
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
        f"DRIVER={_DRIVER};SERVER={server};DATABASE={database};"
        f"UID={uid};PWD={pwd};Encrypt={encrypt};TrustServerCertificate=no"
    )


@lru_cache(maxsize=1)
def _get_conn_str() -> str:
    kv_name = os.environ.get("KEY_VAULT_NAME")
    if kv_name:
        cred = DefaultAzureCredential()
        kv   = SecretClient(vault_url=f"https://{kv_name}.vault.azure.net", credential=cred)
        return _to_pyodbc(kv.get_secret("sql-connection-string").value)
    return _to_pyodbc(os.environ["SQL_CONNECTION_STRING"])


def get_connection() -> pyodbc.Connection:
    return pyodbc.connect(_get_conn_str(), timeout=30)
