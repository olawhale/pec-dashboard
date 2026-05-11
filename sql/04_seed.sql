-- ============================================================
-- PEC Dashboard – Sample data seed (dev / demo environment)
-- ============================================================

-- Partners
MERGE dbo.DimPartner AS t
USING (VALUES
    ('11111111-aaaa-aaaa-aaaa-111111111111', 'Cloudware Solutions',  'Active'),
    ('22222222-bbbb-bbbb-bbbb-222222222222', 'Reliance Infosystems', 'Active'),
    ('33333333-cccc-cccc-cccc-333333333333', 'NexGen Cloud Partners','Active')
) AS s (PartnerTenantId, PartnerName, PartnerStatus)
ON t.PartnerTenantId = s.PartnerTenantId
WHEN NOT MATCHED THEN INSERT (PartnerTenantId, PartnerName, PartnerStatus)
    VALUES (s.PartnerTenantId, s.PartnerName, s.PartnerStatus);

-- Customers
MERGE dbo.DimCustomer AS t
USING (VALUES
    ('aaaa0001-0000-0000-0000-000000000001', 'Acme Corp',        'US'),
    ('aaaa0002-0000-0000-0000-000000000002', 'Globex Industries', 'UK'),
    ('aaaa0003-0000-0000-0000-000000000003', 'Initech Ltd',       'AU'),
    ('aaaa0004-0000-0000-0000-000000000004', 'Umbrella Corp',     'DE'),
    ('aaaa0005-0000-0000-0000-000000000005', 'Cyberdyne Systems', 'US')
) AS s (CustomerTenantId, CustomerName, Country)
ON t.CustomerTenantId = s.CustomerTenantId
WHEN NOT MATCHED THEN INSERT (CustomerTenantId, CustomerName, Country)
    VALUES (s.CustomerTenantId, s.CustomerName, s.Country);

-- Subscriptions
MERGE dbo.DimSubscription AS t
USING (VALUES
    ('sub-0001', 'Acme-Prod',     (SELECT CustomerKey FROM dbo.DimCustomer WHERE CustomerTenantId='aaaa0001-0000-0000-0000-000000000001')),
    ('sub-0002', 'Globex-Prod',   (SELECT CustomerKey FROM dbo.DimCustomer WHERE CustomerTenantId='aaaa0002-0000-0000-0000-000000000002')),
    ('sub-0003', 'Initech-Dev',   (SELECT CustomerKey FROM dbo.DimCustomer WHERE CustomerTenantId='aaaa0003-0000-0000-0000-000000000003')),
    ('sub-0004', 'Umbrella-Prod', (SELECT CustomerKey FROM dbo.DimCustomer WHERE CustomerTenantId='aaaa0004-0000-0000-0000-000000000004')),
    ('sub-0005', 'Cyberdyne-Dev', (SELECT CustomerKey FROM dbo.DimCustomer WHERE CustomerTenantId='aaaa0005-0000-0000-0000-000000000005'))
) AS s (SubscriptionId, SubscriptionName, CustomerKey)
ON t.SubscriptionId = s.SubscriptionId
WHEN NOT MATCHED THEN INSERT (SubscriptionId, SubscriptionName, CustomerKey)
    VALUES (s.SubscriptionId, s.SubscriptionName, s.CustomerKey);

-- Services
MERGE dbo.DimService AS t
USING (VALUES
    ('Azure Virtual Machines',    'Compute',        'IaaS',      'Microsoft'),
    ('Azure Kubernetes Service',  'Compute',        'Containers','Microsoft'),
    ('Azure SQL Database',        'Databases',      'PaaS',      'Microsoft'),
    ('Azure Storage',             'Storage',        'IaaS',      'Microsoft'),
    ('Azure App Service',         'Web',            'PaaS',      'Microsoft'),
    ('Azure OpenAI Service',      'AI + Machine Learning','PaaS','Microsoft'),
    ('Azure Monitor',             'Management',     'SaaS',      'Microsoft'),
    ('Azure Networking',          'Networking',     'IaaS',      'Microsoft')
) AS s (ServiceName, ServiceFamily, ServiceCategory, PublisherName)
ON t.ServiceName = s.ServiceName AND t.PublisherName = s.PublisherName
WHEN NOT MATCHED THEN INSERT (ServiceName, ServiceFamily, ServiceCategory, PublisherName)
    VALUES (s.ServiceName, s.ServiceFamily, s.ServiceCategory, s.PublisherName);

-- ── Fact: 15 months of daily PEC data ───────────────────────────────────────
-- One row per (month, partner, customer, service) averaged over the month.
-- PEC rate: 15% for partners actively managing. Randomised per customer.
WITH months AS (
    SELECT DISTINCT DateKey, [Year], [Month]
    FROM dbo.DimDate
    WHERE [Date] >= DATEADD(MONTH, -15, CAST(GETDATE() AS DATE))
      AND [Date] <= CAST(GETDATE() AS DATE)
      AND [Day] = 1
),
combos AS (
    SELECT
        m.DateKey,
        p.PartnerKey,
        cu.CustomerKey,
        s.SubscriptionKey,
        svc.ServiceKey,
        -- Deterministic but varied spend by customer+service combo
        ABS(CHECKSUM(p.PartnerKey, cu.CustomerKey, svc.ServiceKey, m.DateKey)) % 8000 + 500
            AS BaseSpend
    FROM months m
    CROSS JOIN dbo.DimPartner p
    JOIN dbo.DimCustomer cu ON cu.CustomerKey BETWEEN 1 AND 3   -- 3 customers per partner
    JOIN dbo.DimSubscription s ON s.CustomerKey = cu.CustomerKey
    CROSS JOIN (SELECT TOP 4 ServiceKey FROM dbo.DimService ORDER BY ServiceKey) svc
    WHERE p.PartnerKey <= 3
)
INSERT INTO dbo.FactPEC
    (DateKey, PartnerKey, CustomerKey, SubscriptionKey, ServiceKey,
     BillingCurrency, ChargeType, UnitAmount, PECAmount, PECPercentage, PECApplied)
SELECT
    DateKey,
    PartnerKey,
    CustomerKey,
    SubscriptionKey,
    ServiceKey,
    'USD',
    'Usage',
    CAST(BaseSpend AS DECIMAL(18,6)),
    CAST(BaseSpend * 0.15 AS DECIMAL(18,6)),
    0.15,
    1
FROM combos;
GO

SELECT
    CONCAT(CAST([Year] AS VARCHAR), '-', RIGHT('0'+CAST([Month] AS VARCHAR),2)) AS YearMonth,
    COUNT(*) AS rows,
    CAST(SUM(PECAmount) AS DECIMAL(18,2)) AS TotalPEC
FROM dbo.FactPEC f
JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY [Year], [Month]
ORDER BY [Year], [Month];
GO
