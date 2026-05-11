from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import pyodbc

from services.db import get_connection

router = APIRouter(prefix="/api/pec", tags=["pec"])


class MonthlySummaryRow(BaseModel):
    year: int
    month: int
    month_name: str
    partner_name: str
    service_family: str
    total_pec_amount: float
    total_unit_amount: float


class ForecastRow(BaseModel):
    year: int
    month: int
    month_name: str
    partner_name: str
    actual_pec_amount: Optional[float]
    forecasted_pec_amount: Optional[float]
    forecast_lower: Optional[float]
    forecast_upper: Optional[float]


@router.get("/summary", response_model=list[MonthlySummaryRow])
def get_monthly_summary(
    partner_name: Optional[str] = None,
    year: Optional[int] = None,
):
    sql = """
        SELECT TOP 1000
            [Year], [Month], MonthName,
            PartnerName, ServiceFamily,
            TotalPECAmount, TotalUnitAmount
        FROM dbo.vw_PECMonthlySummary
        WHERE 1=1
    """
    params: list = []
    if partner_name:
        sql += " AND PartnerName = ?"
        params.append(partner_name)
    if year:
        sql += " AND [Year] = ?"
        params.append(year)
    sql += " ORDER BY [Year], [Month]"

    try:
        with get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql, params)
            rows = cursor.fetchall()
            cols = [d[0] for d in cursor.description]
    except pyodbc.Error as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    return [
        MonthlySummaryRow(
            year=r[cols.index("Year")],
            month=r[cols.index("Month")],
            month_name=r[cols.index("MonthName")],
            partner_name=r[cols.index("PartnerName")],
            service_family=r[cols.index("ServiceFamily")],
            total_pec_amount=float(r[cols.index("TotalPECAmount")] or 0),
            total_unit_amount=float(r[cols.index("TotalUnitAmount")] or 0),
        )
        for r in rows
    ]


@router.get("/forecast", response_model=list[ForecastRow])
def get_forecast(partner_name: Optional[str] = None):
    sql = """
        SELECT TOP 500
            [Year], [Month], MonthName,
            PartnerName,
            ActualPECAmount,
            ForecastedPECAmount,
            ForecastLower,
            ForecastUpper
        FROM dbo.vw_ForecastVsActual
        WHERE 1=1
    """
    params: list = []
    if partner_name:
        sql += " AND PartnerName = ?"
        params.append(partner_name)
    sql += " ORDER BY [Year], [Month]"

    try:
        with get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql, params)
            rows = cursor.fetchall()
            cols = [d[0] for d in cursor.description]
    except pyodbc.Error as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    def _f(val) -> Optional[float]:
        return float(val) if val is not None else None

    return [
        ForecastRow(
            year=r[cols.index("Year")],
            month=r[cols.index("Month")],
            month_name=r[cols.index("MonthName")],
            partner_name=r[cols.index("PartnerName")],
            actual_pec_amount=_f(r[cols.index("ActualPECAmount")]),
            forecasted_pec_amount=_f(r[cols.index("ForecastedPECAmount")]),
            forecast_lower=_f(r[cols.index("ForecastLower")]),
            forecast_upper=_f(r[cols.index("ForecastUpper")]),
        )
        for r in rows
    ]


@router.get("/partners", response_model=list[str])
def list_partners():
    sql = "SELECT DISTINCT PartnerName FROM dbo.DimPartner ORDER BY PartnerName"
    try:
        with get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(sql)
            return [row[0] for row in cursor.fetchall()]
    except pyodbc.Error as exc:
        raise HTTPException(status_code=500, detail=str(exc))
