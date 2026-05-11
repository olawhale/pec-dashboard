-- ============================================================
-- PEC Dashboard – Star Schema
-- ============================================================

-- ── Dimension: Date ─────────────────────────────────────────
CREATE TABLE dbo.DimDate (
    DateKey        INT          NOT NULL PRIMARY KEY,  -- YYYYMMDD
    [Date]         DATE         NOT NULL,
    [Year]         SMALLINT     NOT NULL,
    Quarter        TINYINT      NOT NULL,
    [Month]        TINYINT      NOT NULL,
    MonthName      NVARCHAR(9)  NOT NULL,
    [Day]          TINYINT      NOT NULL,
    WeekDay        NVARCHAR(9)  NOT NULL,
    IsWeekend      BIT          NOT NULL DEFAULT 0,
    FiscalYear     SMALLINT     NOT NULL,
    FiscalQuarter  TINYINT      NOT NULL
);

-- ── Dimension: Partner ──────────────────────────────────────
CREATE TABLE dbo.DimPartner (
    PartnerKey      INT           IDENTITY(1,1) PRIMARY KEY,
    PartnerTenantId NVARCHAR(36)  NOT NULL UNIQUE,
    PartnerName     NVARCHAR(200) NOT NULL,
    PartnerStatus   NVARCHAR(50)  NOT NULL DEFAULT 'Active',
    CreatedAt       DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── Dimension: Customer ─────────────────────────────────────
CREATE TABLE dbo.DimCustomer (
    CustomerKey      INT           IDENTITY(1,1) PRIMARY KEY,
    CustomerTenantId NVARCHAR(36)  NOT NULL UNIQUE,
    CustomerName     NVARCHAR(200) NOT NULL,
    Country          NVARCHAR(100) NULL,
    CreatedAt        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── Dimension: Subscription ─────────────────────────────────
CREATE TABLE dbo.DimSubscription (
    SubscriptionKey  INT           IDENTITY(1,1) PRIMARY KEY,
    SubscriptionId   NVARCHAR(36)  NOT NULL UNIQUE,
    SubscriptionName NVARCHAR(200) NOT NULL,
    CustomerKey      INT           NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
    CreatedAt        DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ── Dimension: Service ──────────────────────────────────────
CREATE TABLE dbo.DimService (
    ServiceKey      INT           IDENTITY(1,1) PRIMARY KEY,
    ServiceName     NVARCHAR(200) NOT NULL,
    ServiceFamily   NVARCHAR(100) NOT NULL,
    ServiceCategory NVARCHAR(100) NOT NULL,
    PublisherName   NVARCHAR(200) NOT NULL DEFAULT 'Microsoft',
    CONSTRAINT UQ_Service UNIQUE (ServiceName, PublisherName)
);

-- ── Fact: PEC ───────────────────────────────────────────────
CREATE TABLE dbo.FactPEC (
    FactPECKey         BIGINT        IDENTITY(1,1) PRIMARY KEY,
    DateKey            INT           NOT NULL REFERENCES dbo.DimDate(DateKey),
    PartnerKey         INT           NOT NULL REFERENCES dbo.DimPartner(PartnerKey),
    CustomerKey        INT           NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
    SubscriptionKey    INT           NOT NULL REFERENCES dbo.DimSubscription(SubscriptionKey),
    ServiceKey         INT           NOT NULL REFERENCES dbo.DimService(ServiceKey),
    BillingCurrency    NCHAR(3)      NOT NULL DEFAULT 'USD',
    ChargeType         NVARCHAR(50)  NOT NULL,
    UnitAmount         DECIMAL(18,6) NOT NULL DEFAULT 0,
    PECAmount          DECIMAL(18,6) NOT NULL DEFAULT 0,
    PECPercentage      DECIMAL(5,4)  NOT NULL DEFAULT 0,
    PECApplied         BIT           NOT NULL DEFAULT 0,
    LoadedAt           DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceFileName     NVARCHAR(500) NULL
);

CREATE INDEX IX_FactPEC_DateKey     ON dbo.FactPEC (DateKey);
CREATE INDEX IX_FactPEC_PartnerKey  ON dbo.FactPEC (PartnerKey);
CREATE INDEX IX_FactPEC_ServiceKey  ON dbo.FactPEC (ServiceKey);

-- ── Fact: PEC Forecast ──────────────────────────────────────
CREATE TABLE dbo.FactPECForecast (
    ForecastKey          BIGINT        IDENTITY(1,1) PRIMARY KEY,
    DateKey              INT           NOT NULL REFERENCES dbo.DimDate(DateKey),
    PartnerKey           INT           NOT NULL REFERENCES dbo.DimPartner(PartnerKey),
    ForecastedPECAmount  DECIMAL(18,6) NOT NULL,
    LowerBound           DECIMAL(18,6) NOT NULL,
    UpperBound           DECIMAL(18,6) NOT NULL,
    ModelRunDate         DATE          NOT NULL,
    CreatedAt            DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE INDEX IX_FactPECForecast_DateKey    ON dbo.FactPECForecast (DateKey);
CREATE INDEX IX_FactPECForecast_PartnerKey ON dbo.FactPECForecast (PartnerKey);

-- ── Populate DimDate (2023-01-01 → 2027-12-31) ──────────────
WITH dates AS (
    SELECT CAST('2023-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(day, 1, d) FROM dates WHERE d < '2027-12-31'
)
INSERT INTO dbo.DimDate
SELECT
    CONVERT(INT, CONVERT(NCHAR(8), d, 112)) AS DateKey,
    d                                         AS [Date],
    YEAR(d)                                   AS [Year],
    DATEPART(QUARTER, d)                      AS Quarter,
    MONTH(d)                                  AS [Month],
    DATENAME(MONTH, d)                        AS MonthName,
    DAY(d)                                    AS [Day],
    DATENAME(WEEKDAY, d)                      AS WeekDay,
    CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 1 ELSE 0 END AS IsWeekend,
    CASE WHEN MONTH(d) >= 7 THEN YEAR(d)+1 ELSE YEAR(d) END   AS FiscalYear,
    CASE
        WHEN MONTH(d) IN (7,8,9)   THEN 1
        WHEN MONTH(d) IN (10,11,12) THEN 2
        WHEN MONTH(d) IN (1,2,3)   THEN 3
        ELSE 4
    END AS FiscalQuarter
FROM dates
OPTION (MAXRECURSION 2000);
GO
