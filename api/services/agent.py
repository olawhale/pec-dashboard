"""
NL-to-SQL agent using Azure OpenAI.
Generates SELECT queries restricted to vw_AIQuery.
"""
from __future__ import annotations

import os
import re

from openai import AzureOpenAI

_SCHEMA_DESCRIPTION = """
View: dbo.vw_AIQuery
Columns:
  Year         INT
  Month        INT
  MonthName    NVARCHAR(9)
  PartnerName  NVARCHAR(200)
  CustomerName NVARCHAR(200)
  ServiceName  NVARCHAR(200)
  ServiceFamily NVARCHAR(100)
  ServiceCategory NVARCHAR(100)
  PECAmount    DECIMAL   (Partner Earned Credit in billing currency)
  UsageAmount  DECIMAL
  BillingCurrency NCHAR(3)
"""

_SYSTEM_PROMPT = f"""You are a SQL generator for an Azure Partner Earned Credit dashboard.
Generate a single, read-only T-SQL SELECT query against the view described below.
Rules:
- Only use dbo.vw_AIQuery — no other tables or views.
- Never use INSERT, UPDATE, DELETE, DROP, CREATE, EXEC, or xp_ commands.
- Always include a TOP 500 clause to prevent runaway queries.
- Return ONLY the SQL query, no explanation.

{_SCHEMA_DESCRIPTION}
"""


def get_client() -> AzureOpenAI:
    return AzureOpenAI(
        azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
        api_key=os.environ.get("AZURE_OPENAI_KEY", ""),
        api_version="2024-02-01",
    )


def nl_to_sql(question: str) -> str:
    client     = get_client()
    deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-4o")

    response = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user",   "content": question},
        ],
        temperature=0,
        max_tokens=500,
    )
    sql = response.choices[0].message.content.strip()

    # Safety: reject any statement that isn't a SELECT
    if not re.match(r"(?i)\s*SELECT\b", sql):
        raise ValueError("Generated statement is not a SELECT query.")
    # Reject obvious injection patterns
    forbidden = re.compile(r"(?i)\b(INSERT|UPDATE|DELETE|DROP|CREATE|EXEC|xp_)\b")
    if forbidden.search(sql):
        raise ValueError("Generated SQL contains forbidden keywords.")

    return sql
