# hoosier_data

Snowflake data warehouse for Indiana public records. Covers campaign finance, legislative voting, lobbying, state and local government spending, federal contracts, and local government financial data.

Built as shared research infrastructure for Indiana Democratic candidates.

## Data

| Dataset | Source | Rows | Coverage |
|---|---|---|---|
| Campaign Finance | Indiana Election Division | 852,566 | 2018-2026 |
| Legislative Bills | LegiScan | 8,211 | 2020-2026 |
| Legislative Votes | LegiScan | 447,503 | 2020-2026 |
| Legislators | LegiScan | 1,077 | 2020-2026 |
| Roll Calls | LegiScan | 7,403 | 2020-2026 |
| Bill Sponsors | LegiScan | 40,152 | 2020-2026 |
| Lobbying (employer) | ILRC | 5,186 | 2021-2025 |
| Lobbying (compensated) | ILRC | 9,963 | 2021-2025 |
| State Expenditures | Indiana Data Hub | 6,488,697 | FY2020-FY2026 Q2 |
| Vendor Spending | Indiana Data Hub | 14,476,017 | FY2016-FY2026 |
| Federal Contracts | USASpending.gov | 304,116 | FY2020-FY2026 |
| Local Govt Disbursements | Indiana Gateway | 783,246 | 2020-2025 |
| Local Govt Disbursements (legacy) | Indiana Gateway | 1,591,099 | 2011-2019 |
| Local Govt Receipts | Indiana Gateway | 448,490 | 2021-2025 |
| Local Govt Receipts (legacy) | Indiana Gateway | 1,310,571 | 2015-2020 |
| Township Vendor Payments | Indiana Gateway | 379,050 | 2020-2025 |
| Township Vendor Payments (legacy) | Indiana Gateway | 981,273 | 2011-2019 |
| ECA Expenditures | Indiana Gateway | 4,385,913 | Multi-year |
| ECA Receipts | Indiana Gateway | 4,223,741 | Multi-year |
| ECA Balances | Indiana Gateway | 537,246 | Multi-year |
| Tax Distributions (Form 22) | Indiana Gateway | 1,014,580 | Multi-year |
| Entity Funds | Indiana Gateway | 74,885 | Multi-year |
| Capital Assets | Indiana Gateway | 279,469 | Multi-year |
| Form 4A (Budget Estimates) | Indiana Gateway | 3,579,002 | Multi-year |
| Form 4B (Budget Adopted) | Indiana Gateway | 250,340 | Multi-year |
| Detailed Revenue | Indiana Gateway | 578,029 | Multi-year |
| Grants | Indiana Gateway | 150,283 | Multi-year |
| Non-Governmental Entities | Indiana Gateway | 49,431 | Multi-year |
| Cash & Investments Combined | Indiana Gateway | 701,573 | Multi-year |
| Township Assistance (TA-7) | Indiana Gateway | 15,033 | Multi-year |
| Disbursements Detail (Bartholomew) | Indiana Gateway | 6,889 | 2011-2024 |
| Receipts Detail (Bartholomew) | Indiana Gateway | 12,782 | 2015-2024 |
| Certified Net Assessed Value | Indiana Gateway | 31,174 | Statewide, 2016-2025 |
| Form 22 Detail (Bartholomew) | Indiana Gateway | 6,843 | Multi-year |
| Real Property Parcel | Indiana Gateway | 7,137,858 | Statewide, 2022p2023 + 2024p2025 |
| DLGF Township Codes | DLGF | 1,002 | All 92 counties |

51M+ rows across 36 tables.

## Analytics Views

Views in `HOOSIER_DATA.ANALYTICS` that sit on top of the raw tables:

**SEA-1 Fire Fund Impact Model** (`sql/analytics/sea1_impact.sql`): models the revenue loss to township fire departments from Indiana HEA 1001 (2024) property tax reform. Three mechanisms: BPP exemption increase, homestead deduction increases, and phased 2%-cap deduction. Covers all 92 Indiana counties.

| View | Purpose |
|---|---|
| `PARCEL_DISTRICT_RATE` | Joins parcel data to tax district rates. Base for all per-parcel models. |
| `SEA1_BPP_LOSS` | BPP levy loss by township, township-proper districts only |
| `SEA1_HOMESTEAD_LOSS` | Per-parcel homestead deduction delta by township and phase year 2026-2031 |
| `SEA1_2PCT_BUCKET_LOSS` | Phased AV deduction for 2%-cap property (third SEA-1 mechanism) |
| `FIRE_COST_TREND` | Township fire operating CAGR and 2029 projections, with transfer exclusion |
| `SEA1_FIRE_IMPACT_SUMMARY` | Combined output: loss + cost + net gap, provenance-flagged per column |
| `FIRE_REVENUE_TREND` | Actual fire fund receipts 2020-2024 by source (property tax, LIT, excise, etc.) |
| `LIT_FIRE_RATE_PROJECTION` | LIT fire rate revenue scenarios at 0.025/0.05/0.10% AGI |

Parameter table `HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS` holds the phase-in schedule for each mechanism. Homestead and 2%-bucket parameters are estimates pending statutory verification against the enrolled act.

**Township Trustee Dashboard** (`sql/analytics/bartholomew_township_views.sql`): Bartholomew County township financial views -- revenue vs expenditure, spending by category, poor relief, TA-7, and LIT rate projections.

## Repository Structure

```
sql/
  raw/
    create_tables.sql           -- All RAW layer table definitions (CREATE TABLE IF NOT EXISTS)
    copy_into.sql               -- Snowflake COPY INTO statements for all stages
  analytics/
    candidate_research.sql      -- Legislator research queries
    bartholomew_township_views.sql  -- Township trustee dashboard views
    sea1_impact.sql             -- SEA-1 fire fund impact model (statewide)

scripts/
  download_gateway_parcel.py    -- Download PARCEL files by county from Gateway
  parse_gateway_parcel.py       -- Parse fixed-width PARCEL records to CSV
  load_snowflake_parcel.py      -- Stage and COPY INTO GATEWAY_PARCEL
  verify_parcel_load.py         -- Row count verification after load
  prepare_gateway_data.ps1      -- Filter Gateway bulk files to Bartholomew County
  download_state_expenditures.ps1
  filter_indiana_contracts.py
  organize_gateway_files.ps1
  split_large_files.ps1
```

## Setup

See [docs/snowflake-setup.md](docs/snowflake-setup.md) for Snowflake instance setup and [docs/data-sources.md](docs/data-sources.md) for data download instructions.

## Downloading Gateway Data

Indiana Gateway bulk AFR downloads are statewide. Use `scripts/prepare_gateway_data.ps1` to filter to Bartholomew County and convert pipe-delimited files to CSV before uploading to Snowflake.

Files available at: https://gateway.ifionline.org/public/download.aspx

**PARCEL files** (real property, fixed-width format):

Download per-county PARCEL zip files from Gateway > Property Files > Real Property. Parse with `scripts/parse_gateway_parcel.py` before loading. Two vintages needed: 2022p2023 (pre-SEA-1 baseline) and 2024p2025 (current). Coverage: all 92 counties, roughly 3.5M parcels per year.

**Certified Net Assessed Value** (`certNav.txt`):

Single statewide file, comma-delimited. Schema changed in 2024 from homestead/rental/commercial breakdown to AV-by-cap-class (1%/2%/3%). The statewide file contains exact duplicate rows -- always dedup on (budget_year, county_number, tax_district_code) before aggregating.

**Other statewide bulk files** (upload directly to GATEWAY_STAGE):

All other `GATEWAY_*` tables load from pipe-delimited `.txt` files. Files over 250MB must be split first using `scripts/split_large_files.ps1`.

Bartholomew-filtered detail tables (run through `prepare_gateway_data.ps1`):
- Detailed Disbursements with Departments -- `detailedDisburse_fundswithdept.txt`
- Detailed Receipts -- `detailedReceipts.txt`
- Form 22 -- `form22.txt`

## Notes

- All RAW layer columns are VARCHAR. Casting happens in ANALYTICS views.
- GATEWAY text fields include embedded double-quotes. Use `REPLACE(field, '"', '')` before casting, or query through the `_CLEAN` views in ANALYTICS.
- Re-running `create_tables.sql` is safe -- all statements use `CREATE TABLE IF NOT EXISTS`. Schema changes require `ALTER TABLE ADD COLUMN`.

## License

Public domain. All source data is from public government records.
