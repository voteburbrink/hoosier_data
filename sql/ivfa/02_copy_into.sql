-- KAN-182: Load IVFA department directory into RAW.
-- Executes through the MFA loader (CLAUDE_USER is read-only).
--
-- Run the three steps IN ORDER. Step 2 (PUT) is a client-side command
-- (SnowSQL / Python connector) — it does NOT run in a SQL worksheet, and it
-- must happen AFTER the stage exists (step 1) and BEFORE the COPY (step 3).
--
-- Snapshot loads: each new pull keeps a distinct as_of_date, so the COPY
-- appends rather than clobbers. Do NOT TRUNCATE between pulls.

-- ── STEP 1: create the stage (idempotent) ────────────────
CREATE STAGE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_STAGE;

-- ── STEP 2: upload the file (client-side, not worksheet) ──
--   PUT file://<repo>/firedata/ivfa_departments_2026-06-12.csv @HOOSIER_DATA.RAW.IVFA_STAGE;
--   Verify it landed:  LIST @HOOSIER_DATA.RAW.IVFA_STAGE;

-- ── STEP 3: load into RAW ────────────────────────────────
COPY INTO HOOSIER_DATA.RAW.IVFA_DEPARTMENTS_SOURCE
FROM @HOOSIER_DATA.RAW.IVFA_STAGE
PATTERN = '.*ivfa_departments.*\.csv'
FILE_FORMAT = (
    TYPE = 'CSV'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ENCODING = 'UTF-8'
    NULL_IF = ('')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = 'CONTINUE';

-- Sanity check after load (expect 827 rows for the 2026-06-12 snapshot):
-- SELECT as_of_date, COUNT(*) FROM HOOSIER_DATA.RAW.IVFA_DEPARTMENTS_SOURCE GROUP BY 1;
