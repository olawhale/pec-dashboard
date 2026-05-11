from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import pyodbc

from services.agent import nl_to_sql
from services.db import get_connection

router = APIRouter(prefix="/api/query", tags=["query"])


class QueryRequest(BaseModel):
    question: str


class QueryResponse(BaseModel):
    sql: str
    columns: list[str]
    rows: list[list]


@router.post("", response_model=QueryResponse)
def run_nl_query(req: QueryRequest):
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="question must not be empty")

    try:
        sql = nl_to_sql(req.question)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    try:
        with get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql)
            columns = [d[0] for d in cursor.description]
            rows    = [list(r) for r in cursor.fetchall()]
    except pyodbc.Error as exc:
        raise HTTPException(status_code=500, detail=f"SQL error: {exc}")

    return QueryResponse(sql=sql, columns=columns, rows=rows)
