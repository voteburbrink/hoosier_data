-- ============================================================
-- KAN-153 — RAW table for the DLGF Tax Rate Chart district→unit crosswalk
-- Run as ACCOUNTADMIN.  Standalone copy of the DDL that also lives in
-- sql/raw/create_tables.sql (kept here so you don't have to dig for it).
--
-- NOTE: scripts/load_snowflake_trc.py ALREADY runs this CREATE for you.
--       Only run this file if you are loading manually (e.g. via Snowsight).
--
-- SAFE: CREATE TABLE IF NOT EXISTS — never drops data. Do NOT change to
--       CREATE OR REPLACE (June 5 2026 incident wiped ~22M rows).
-- ============================================================

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS (
    budget_year         VARCHAR,  -- YR_NBR (pay year)
    county_number       VARCHAR,  -- CNTY_CD
    unit_type_cd        VARCHAR,  -- 1=County 2=Township 3=City/Town 4=School 5=Library 6=Special
    unit_code           VARCHAR,  -- UNIT_CD
    unit_name           VARCHAR,  -- UNIT_NAME
    fund_code           VARCHAR,  -- FUND_CD
    fund_name           VARCHAR,  -- FUND_LONG_NAME
    tax_district_code   VARCHAR,  -- TAX_DIST_CD
    tax_district_name   VARCHAR,  -- TAX_DIST_NAME
    certd_tax_rate_pct  VARCHAR   -- CERTD_TAX_RATE_PCNT (per $100 AV)
);

ALTER TABLE HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS SET DATA_RETENTION_TIME_IN_DAYS = 7;
