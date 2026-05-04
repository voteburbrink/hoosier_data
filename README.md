# hoosier_data

Snowflake data warehouse for Indiana public records. Covers campaign finance, legislative voting, lobbying, state and local government spending, federal contracts, and local government financial data.

Built as shared research infrastructure for Indiana Democratic candidates.

## Dashboards

### Bartholomew County Township Trustee Dashboard

Streamlit in Snowflake app analyzing the fiscal health of all 12 Bartholomew County townships. Core focus: the fiscal impact of **Indiana Senate Enrolled Act 1 (2025)** on township budgets.

**Location:** `dashboards/bartholomew_twp_trustee/app.py`

**Key features:**
- SEA-1 Impact tab: what the law does, who benefits, who pays (including corporate/BPP tax provisions), county-wide 5-year fiscal projections
- Trends and Forecast: revenue vs expenditure with policy-aware scenarios; one-time spike detection anchors forecasts to smoothed baselines
- Spending by Category: disbursement class breakdown (Personal Services, Capital, etc.)
- YoY Growth: top movers across all townships
- Township Assistance: admin cost vs dollars delivered, TA-7 application outcome tracking with Harrison Township denial anomaly
- Data Explorer: raw view of all underlying data

**Harrison Township 2024 anomaly:** A one-time $393K fund transfer inflated 2024 expenditures ~51% above the trailing 3-year average. The `is_end_of_series_spike()` function detects this and anchors the forecast to the smoothed baseline (~$742K) rather than the inflated $1.12M figure.

**SEA-1 context:** Levy growth caps constrain township revenue that historically grew at 5-7%/yr. Fixed costs (salaries, utilities) continue rising with inflation. The cumulative result is a structural deficit that widens each year without service cuts or levy appeals. The law simultaneously extends Business Personal Property exemptions, commercial assessment caps, and data center incentives - each of which permanently reduces the property tax base townships collect from.

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
| Local Govt Disbursements | Indiana Gateway | 783,024 | 2020-2024 |
| Local Govt Receipts | Indiana Gateway | 448,339 | 2021-2024 |
| Township Vendor Payments | Indiana Gateway | 379,050 | 2020-2025 |
| ECA Expenditures | Indiana Gateway | 4,385,913 | Multi-year |
| ECA Receipts | Indiana Gateway | 4,223,741 | Multi-year |
| ECA Balances | Indiana Gateway | 537,161 | Multi-year |
| Tax Distributions (Form 22) | Indiana Gateway | 1,014,580 | Multi-year |
| Entity Funds (federal) | Indiana Gateway | 74,662 | Multi-year |
| Disbursements Detail (all units) | Indiana Gateway | ~Bartholomew | 2011-2024 |
| Receipts Detail (all units) | Indiana Gateway | ~Bartholomew | 2015-2024 |
| Certified Net Assessed Value | Indiana Gateway | ~Bartholomew | 2016-2024 |
| Township Assistance TA-7 | Indiana Gateway | ~Bartholomew | 2011-2025 |
| Federal Contracts | USASpending.gov | 304,116 | FY2020-FY2026 |

43M+ rows across 26 tables.

## Repository Structure

```
sql/
  raw/
    create_tables.sql           -- All RAW layer table definitions (all VARCHAR)
    copy_into.sql               -- Snowflake COPY INTO statements
  analytics/
    candidate_research.sql      -- Legislator research queries
    bartholomew_township_views.sql  -- Township dashboard analytics views

dashboards/
  bartholomew_twp_trustee/
    app.py                      -- Streamlit in Snowflake app (full source)

scripts/
  prepare_gateway_data.ps1      -- Filter/convert Indiana Gateway bulk files
  download_state_expenditures.ps1
  filter_indiana_contracts.py
  organize_gateway_files.ps1
  split_large_files.ps1

docs/
  data-dictionary.md
  data-sources.md
  scripts.md
  snowflake-setup.md
  sql-reference.md
```

## Setup

See [docs/snowflake-setup.md](docs/snowflake-setup.md) for Snowflake instance setup and [docs/data-sources.md](docs/data-sources.md) for data download instructions.

## Downloading Gateway Data

Indiana Gateway bulk AFR downloads are statewide (100MB-400MB). Use `scripts/prepare_gateway_data.ps1` to filter to Bartholomew County and convert pipe-delimited files to CSV before uploading to Snowflake.

Files available at: https://gateway.ifionline.org/report_builder/Default3a.aspx?rptType=expenditure

Key files:
- **Annual Financial Reports > Detailed Disbursements with Departments** - `detailedDisburse_fundswithdept.csv` (pipe-delimited)
- **Annual Financial Reports > Detailed Receipts** - `detailedReceipts.csv` (pipe-delimited)
- **Budget Data > Form 22** - `form22.csv` (pipe-delimited)
- **Budget Data > Certified Net Assessed Value** - `certNav.csv` (comma-delimited)

## License

Public domain. All source data is from public government records.
