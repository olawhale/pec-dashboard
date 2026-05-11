-- ============================================================
-- PEC Dashboard – Views
-- ============================================================

-- ── Monthly PEC summary per partner ─────────────────────────
CREATE OR ALTER VIEW dbo.vw_PECMonthlySummary AS
SELECT
    dd.[Year],
    dd.[Month],
    dd.MonthName,
    DATEFROMPARTS(dd.[Year], dd.[Month], 1) AS MonthStart,
    dp.PartnerTenantId,
    dp.PartnerName,
    ds.ServiceFamily,
    SUM(f.UnitAmount)  AS TotalUnitAmount,
    SUM(f.PECAmount)   AS TotalPECAmount,
    COUNT(*)           AS LineCount
FROM dbo.FactPEC f
JOIN dbo.DimDate        dd ON f.DateKey    = dd.DateKey
JOIN dbo.DimPartner     dp ON f.PartnerKey = dp.PartnerKey
JOIN dbo.DimService     ds ON f.ServiceKey = ds.ServiceKey
WHERE f.PECApplied = 1
GROUP BY dd.[Year], dd.[Month], dd.MonthName,
         dp.PartnerTenantId, dp.PartnerName, ds.ServiceFamily;
GO

-- ── Forecast vs. actual (joined) ────────────────────────────
CREATE OR ALTER VIEW dbo.vw_ForecastVsActual AS
SELECT
    dd.[Year],
    dd.[Month],
    dd.MonthName,
    DATEFROMPARTS(dd.[Year], dd.[Month], 1) AS MonthStart,
    dp.PartnerTenantId,
    dp.PartnerName,
    SUM(f.PECAmount)            AS ActualPECAmount,
    MAX(fc.ForecastedPECAmount) AS ForecastedPECAmount,
    MAX(fc.LowerBound)          AS ForecastLower,
    MAX(fc.UpperBound)          AS ForecastUpper,
    MAX(fc.ModelRunDate)        AS ModelRunDate
FROM dbo.DimDate    dd
JOIN dbo.DimPartner dp ON 1 = 1
LEFT JOIN dbo.FactPEC f
       ON f.DateKey = dd.DateKey AND f.PartnerKey = dp.PartnerKey AND f.PECApplied = 1
LEFT JOIN dbo.FactPECForecast fc
       ON fc.DateKey = dd.DateKey AND fc.PartnerKey = dp.PartnerKey
WHERE dd.[Date] >= '2023-01-01'
GROUP BY dd.[Year], dd.[Month], dd.MonthName,
         dp.PartnerTenantId, dp.PartnerName;
GO

-- ── Locked-down view for AI agent (no PII, no financials raw) ─
CREATE OR ALTER VIEW dbo.vw_AIQuery AS
SELECT
    dd.[Year],
    dd.[Month],
    dd.MonthName,
    dp.PartnerName,
    dc.CustomerName,
    ds.ServiceName,
    ds.ServiceFamily,
    ds.ServiceCategory,
    SUM(f.PECAmount)  AS PECAmount,
    SUM(f.UnitAmount) AS UsageAmount,
    f.BillingCurrency
FROM dbo.FactPEC f
JOIN dbo.DimDate         dd ON f.DateKey      = dd.DateKey
JOIN dbo.DimPartner      dp ON f.PartnerKey   = dp.PartnerKey
JOIN dbo.DimCustomer     dc ON f.CustomerKey  = dc.CustomerKey
JOIN dbo.DimService      ds ON f.ServiceKey   = ds.ServiceKey
GROUP BY dd.[Year], dd.[Month], dd.MonthName,
         dp.PartnerName, dc.CustomerName,
         ds.ServiceName, ds.ServiceFamily, ds.ServiceCategory,
         f.BillingCurrency;
GO
