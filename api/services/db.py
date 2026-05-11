from __future__ import annotations

import os
import pyodbc
from functools import lru_cache
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


@lru_cache(maxsize=1)
def _get_conn_str() -> str:
    kv_name = os.environ.get("KEY_VAULT_NAME")
    if kv_name:
        cred = DefaultAzureCredential()
        kv   = SecretClient(vault_url=f"https://{kv_name}.vault.azure.net", credential=cred)
        return kv.get_secret("sql-connection-string").value
    return os.environ["SQL_CONNECTION_STRING"]


def get_connection() -> pyodbc.Connection:
    return pyodbc.connect(_get_conn_str(), timeout=30)
