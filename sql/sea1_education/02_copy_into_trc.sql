-- ============================================================
-- KAN-153 — COPY INTO RAW.DLGF_TAX_DISTRICT_UNITS
-- Run as ACCOUNTADMIN, AFTER staging the TRC CSVs to GATEWAY_STAGE.
-- Standalone copy of the COPY that also lives in sql/raw/copy_into.sql.
--
-- NOTE: scripts/load_snowflake_trc.py ALREADY does the xlsx→csv→PUT→COPY.
--       Only run this file if you are loading manually.
--
-- Expects files named <year>_trc_unit.csv (header already stripped by the
-- loader, hence SKIP_HEADER=0). PURGE=FALSE.
-- To refresh a year, DELETE that budget_year first — never re-create the table.
-- ============================================================

COPY INTO HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS
FROM @HOOSIER_DATA.RAW.GATEWAY_STAGE
PATTERN = '.*_trc_unit\.csv.*'
FILE_FORMAT = (TYPE='CSV' SKIP_HEADER=0 FIELD_OPTIONALLY_ENCLOSED_BY='"'
    NULL_IF=('') ERROR_ON_COLUMN_COUNT_MISMATCH=FALSE)
ON_ERROR = 'CONTINUE';

-- Sanity check after load:
SELECT budget_year, COUNT(*) AS rows, COUNT(DISTINCT county_number) AS counties
FROM HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS
GROUP BY budget_year ORDER BY budget_year;
