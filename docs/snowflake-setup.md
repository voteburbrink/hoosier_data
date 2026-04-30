# Snowflake Setup

Covers account setup, schema design, roles, stages, and data ingestion for all data sources.

> Account identifier, URL, and credentials are not stored in this repository. Replace all `<placeholders>` below with your actual values.

---

## Account Details

| Field | Value |
|---|---|
| Account | `<your-account-identifier>` |
| URL | `https://<your-account-identifier>.snowflakecomputing.com` |
| Database | HOOSIER_DATA |
| Warehouse | COMPUTE_WH (X-Small) |
| Admin User | `<your-snowflake-username>` |
| Estimated Cost | $25-50/month at current usage |

---

## Step 1 - Create Database and Schemas

Four schemas follow a strict RAW -> STAGING -> ANALYTICS pipeline. All source data lands untouched in RAW. Transformations happen in STAGING. Dashboards and analysis live in ANALYTICS.

```sql
CREATE DATABASE IF NOT EXISTS HOOSIER_DATA;
CREATE SCHEMA IF NOT EXISTS HOOSIER_DATA.CONFIG;
CREATE SCHEMA IF NOT EXISTS HOOSIER_DATA.RAW;
CREATE SCHEMA IF NOT EXISTS HOOSIER_DATA.STAGING;
CREATE SCHEMA IF NOT EXISTS HOOSIER_DATA.ANALYTICS;
```

---

## Step 2 - Create Read-Only Role

A dedicated `readonly_user` role provides read-only SELECT access to all tables and stages. No write access is granted.

```sql
CREATE ROLE readonly_user;
GRANT ROLE readonly_user TO USER <your-snowflake-username>;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE readonly_user;
GRANT USAGE ON DATABASE HOOSIER_DATA TO ROLE readonly_user;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HOOSIER_DATA TO ROLE readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA HOOSIER_DATA.RAW TO ROLE readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA HOOSIER_DATA.STAGING TO ROLE readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA HOOSIER_DATA.ANALYTICS TO ROLE readonly_user;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HOOSIER_DATA.RAW TO ROLE readonly_user;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HOOSIER_DATA.STAGING TO ROLE readonly_user;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HOOSIER_DATA.ANALYTICS TO ROLE readonly_user;
GRANT USAGE ON ALL STAGES IN SCHEMA HOOSIER_DATA.RAW TO ROLE readonly_user;
GRANT USAGE ON FUTURE STAGES IN SCHEMA HOOSIER_DATA.RAW TO ROLE readonly_user;
ALTER USER <your-snowflake-username> SET DEFAULT_ROLE = readonly_user;
```

---

## Step 3 - Create Stages

One internal stage per data source. File format is defined at stage creation so COPY INTO commands stay clean.

```sql
-- Campaign finance CSVs (Indiana Election Division)
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.CAMPAIGN_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('')
  );

-- LegiScan legislative data CSVs
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.LEGISCAN_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('')
  );

-- Indiana Gateway pipe-delimited TXT files
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.GATEWAY_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = '|'
    SKIP_HEADER = 1
    NULL_IF = ('')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
  );

-- State expenditure quarterly CSVs (Indiana Data Hub)
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.EXPENDITURE_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('')
  );

-- ILRC lobbying CSVs (converted from XLSX)
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.LOBBYING_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('')
  );

-- Federal contracts CSVs (USASpending - Indiana-filtered)
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.CONTRACTS_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
  );

-- State vendor spending quarterly CSVs (Indiana Data Hub)
CREATE OR REPLACE STAGE HOOSIER_DATA.RAW.VENDOR_STAGE
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('')
  );
```

---

## Step 4 - RAW Layer Design

**All columns are VARCHAR.** No type casting happens in the RAW layer. Types are cast in STAGING using `TRY_TO_NUMBER`, `TRY_TO_DATE`, etc. This protects data integrity -- bad source data loads without failing the entire batch.

**Legacy tables for schema mismatches.** Several Indiana Gateway files exist in two forms: individual year files (consistent schemas) and a bare multi-year bulk export (fewer columns, different column order). These load into separate `_LEGACY` tables.

| Year files | Legacy bulk file |
|---|---|
| GATEWAY_DISBURSEMENTS | GATEWAY_DISBURSEMENTS_LEGACY |
| GATEWAY_RECEIPTS | GATEWAY_RECEIPTS_LEGACY |
| GATEWAY_TOWNSHIP_VENDOR | GATEWAY_TOWNSHIP_VENDOR_LEGACY |

**File splitting required.** Snowflake's UI upload limit is 250MB. Several Gateway files exceed this (up to 919MB). Split into 200MB chunks using `scripts/split_large_files.ps1` with the header row repeated in each part.

**Federal contracts pre-filtered.** USASpending publishes national data -- 44 files x ~2GB = ~85GB total. Filtered to Indiana-only rows using `scripts/filter_indiana_contracts.py` before upload, reducing to ~300K rows.

**Lobbying data converted from XLSX.** ILRC publishes lobbying data as Excel files. Convert to CSV using the inline block in `docs/scripts.md` before upload.

**"Data Not Available" files.** Some Indiana Gateway year files contain only the text "Data Not Available for this Year and Unit Type" -- these were skipped during upload.

---

## Step 5 - RAW Tables and Row Counts

### Campaign Finance

| Table | Rows | Source | Coverage |
|---|---|---|---|
| CAMPAIGN_FINANCE_SOURCE | 852,566 | Indiana Election Division | 2018-2026 |

### Legislative Votes

| Table | Rows | Source | Coverage |
|---|---|---|---|
| LEGISCAN_BILLS | 8,211 | LegiScan | 2020-2026 |
| LEGISCAN_PEOPLE | 1,077 | LegiScan | 2020-2026 |
| LEGISCAN_ROLLCALLS | 7,403 | LegiScan | 2020-2026 |
| LEGISCAN_SPONSORS | 40,152 | LegiScan | 2020-2026 |
| LEGISCAN_VOTES | 447,503 | LegiScan | 2020-2026 |

### Lobbying

| Table | Rows | Source | Coverage |
|---|---|---|---|
| LOBBYING_EMPLOYER | 5,186 | ILRC | 2021-2025 |
| LOBBYING_COMPENSATED | 9,963 | ILRC | 2021-2025 |

### State Spending

| Table | Rows | Source | Coverage |
|---|---|---|---|
| STATE_EXPENDITURES | 6,488,697 | Indiana Data Hub | FY2020-FY2026 Q2 |
| VENDOR_EXPENDITURES | 14,476,017 | Indiana Data Hub | FY2016-FY2026 |

### Indiana Gateway - Local Government

| Table | Rows | Description |
|---|---|---|
| GATEWAY_DISBURSEMENTS | 783,024 | Local govt disbursements by fund, 2020-2024 |
| GATEWAY_DISBURSEMENTS_LEGACY | 1,591,099 | Multi-year bulk disbursements |
| GATEWAY_RECEIPTS | 448,339 | Local govt detailed receipts, 2021-2024 |
| GATEWAY_RECEIPTS_LEGACY | 1,310,571 | Multi-year bulk receipts |
| GATEWAY_TOWNSHIP_VENDOR | 379,050 | Township disbursements by vendor, 2020-2025 |
| GATEWAY_TOWNSHIP_VENDOR_LEGACY | 981,242 | Multi-year bulk township vendor |
| GATEWAY_ECA_EXPENDITURES | 4,385,913 | School extra-curricular account spending |
| GATEWAY_ECA_RECEIPTS | 4,223,741 | School extra-curricular account receipts |
| GATEWAY_ECA_BALANCES | 537,161 | School extra-curricular fund balances |
| GATEWAY_TAX_DISTRIBUTIONS | 1,014,580 | Property tax distributions to local units |
| GATEWAY_ENTITY_FUNDS | 74,662 | Federal funds received by local entities |

### Federal Contracts

| Table | Rows | Source | Coverage |
|---|---|---|---|
| FEDERAL_CONTRACTS | 304,116 | USASpending.gov (Indiana-filtered) | FY2020-FY2026 |

**Total RAW: ~43 million rows across 22 tables**

---

## Step 6 - STAGING Layer

STAGING views clean and correctly type RAW data. No data is duplicated -- views reference RAW tables directly.

### VENDOR_EXPENDITURES - column mapping fix

The vendor spending CSV columns loaded positionally out of order relative to the table definition. The key fix: `vendor_name` was sitting in the `SOURCE` column of the RAW table.

```sql
CREATE OR REPLACE VIEW HOOSIER_DATA.STAGING.VENDOR_EXPENDITURES AS
SELECT
    ACCOUNT_ID           AS account_name,
    ACCOUNT_NAME         AS account_id,
    AGENCY_ID            AS agency_name,
    AGENCY_NAME          AS agency_id,
    TRY_TO_DECIMAL(AMOUNT, 18, 2) AS amount,
    EXPENDITURE_CATEGORY AS expenditure_category,
    TRY_TO_NUMBER(FISCAL_YEAR) AS fiscal_year,
    FUNCTION_OF_GOVT     AS function_of_govt,
    FUND_ID              AS fund_name,
    FUND_NAME            AS fund_id,
    FUNDING_SOURCE       AS funding_source,
    JOURNAL_AGENCY_ID    AS journal_date,
    JOURNAL_DATE         AS journal_id,
    JOURNAL_ID           AS last_updated,
    LAST_UPDATED         AS legal_fund_name,
    LEGAL_FUND_ID        AS legal_fund_id,
    LEGAL_FUND_NAME      AS source_system,
    SOURCE               AS vendor_name,
    VENDOR_ID            AS vendor_id,
    VENDOR_NAME          AS voucher_id,
    VOUCHER_ID           AS journal_agency_id
FROM HOOSIER_DATA.RAW.VENDOR_EXPENDITURES;
```

### LEGISLATORS - deduplication view

LEGISCAN_PEOPLE contains one row per legislator per session (7 sessions = 7 rows per person). This view deduplicates to one row per legislator.

```sql
CREATE OR REPLACE VIEW HOOSIER_DATA.STAGING.LEGISLATORS AS
SELECT DISTINCT
    people_id,
    name,
    first_name,
    last_name,
    party,
    role,
    district,
    followthemoney_eid,
    votesmart_id,
    ballotpedia
FROM HOOSIER_DATA.RAW.LEGISCAN_PEOPLE
QUALIFY ROW_NUMBER() OVER (PARTITION BY people_id ORDER BY people_id) = 1;
```

---

## Troubleshooting

**File size limit exceeded on stage upload**
Snowflake UI limits uploads to 250MB. Split files using `scripts/split_large_files.ps1` -- it repeats the header row in each part so COPY INTO works correctly across all parts.

**COPY INTO loads wrong columns**
Happens when the CSV column order differs from the CREATE TABLE column order. Fix in STAGING with a corrected view rather than reloading RAW data. Always verify with `SELECT * LIMIT 5` after loading.

**"Data Not Available" files**
Several Indiana Gateway year files contain only the text "Data Not Available for this Year and Unit Type". These load as 1-row garbage. Filter in STAGING using `WHERE FISCAL_YEAR IS NOT NULL AND LENGTH(FISCAL_YEAR) = 4`.

**Multiple rows per legislator in LEGISCAN_PEOPLE**
Expected -- LegiScan includes one record per session. Deduplicate in STAGING using `QUALIFY ROW_NUMBER() OVER (PARTITION BY people_id ORDER BY people_id) = 1`.

**Pipe-delimited files rejected**
Gateway files use `|` as delimiter, not comma. The GATEWAY_STAGE file format must specify `FIELD_DELIMITER = '|'`. Running COPY INTO with the wrong stage against these files will load all columns into column 1.
