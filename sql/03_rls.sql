-- ============================================================
-- PEC Dashboard – Row-Level Security
-- Partners may only see their own rows in FactPEC.
-- The API uses a dedicated low-privilege SQL login whose
-- SESSION_CONTEXT is populated at connection time.
-- ============================================================

-- ── Helper function ─────────────────────────────────────────
CREATE OR ALTER FUNCTION dbo.fn_PartnerFilter(@PartnerKey INT)
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN
    SELECT 1 AS fn_result
    WHERE
        -- Admins (run as the SQL admin) bypass the filter
        IS_MEMBER('db_owner') = 1
        OR
        -- Regular callers must match the partner in session context
        @PartnerKey = CAST(SESSION_CONTEXT(N'PartnerKey') AS INT);
GO

-- ── Apply policy to FactPEC ──────────────────────────────────
CREATE SECURITY POLICY dbo.PartnerRLS
    ADD FILTER PREDICATE dbo.fn_PartnerFilter(PartnerKey)
        ON dbo.FactPEC,
    ADD BLOCK  PREDICATE dbo.fn_PartnerFilter(PartnerKey)
        ON dbo.FactPEC AFTER INSERT,
    ADD BLOCK  PREDICATE dbo.fn_PartnerFilter(PartnerKey)
        ON dbo.FactPEC AFTER UPDATE
WITH (STATE = ON, SCHEMABINDING = ON);
GO

-- ── Apply policy to FactPECForecast ─────────────────────────
CREATE SECURITY POLICY dbo.PartnerForecastRLS
    ADD FILTER PREDICATE dbo.fn_PartnerFilter(PartnerKey)
        ON dbo.FactPECForecast
WITH (STATE = ON, SCHEMABINDING = ON);
GO

-- ── Read-only role for the API app ──────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'pec_reader')
    CREATE ROLE pec_reader;

GRANT SELECT ON SCHEMA::dbo TO pec_reader;
GO
