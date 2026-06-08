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
| Certified Net Assessed Value (Bartholomew) | Indiana Gateway | 387 | 2016-2024 |
| Form 22 Detail (Bartholomew) | Indiana Gateway | 6,843 | Multi-year |

44M+ rows across 34 tables.

## Repository Structure

```
sql/
  raw/
    create_tables.sql           -- All RAW layer table definitions (all VARCHAR)
    copy_into.sql               -- Snowflake COPY INTO statements
  analytics/
    candidate_research.sql      -- Legislator research queries
    bartholomew_township_views.sql  -- Township analytics views

scripts/
  prepare_gateway_data.ps1      -- Filter Indiana Gateway bulk files to Bartholomew County
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

Indiana Gateway bulk AFR downloads are statewide. Use `scripts/prepare_gateway_data.ps1` to filter to Bartholomew County and convert pipe-delimited files to CSV before uploading to Snowflake.

Files available at: https://gateway.ifionline.org/public/download.aspx

Bartholomew-filtered detail tables (run through `prepare_gateway_data.ps1`):
- **Detailed Disbursements with Departments** — `detailedDisburse_fundswithdept.txt` (pipe-delimited)
- **Detailed Receipts** — `detailedReceipts.txt` (pipe-delimited)
- **Form 22** — `form22.txt` (pipe-delimited)
- **Certified Net Assessed Value** — `certNav.txt` (comma-delimited; schema changed 2024 — see data-sources.md)

Statewide bulk files (upload directly to GATEWAY_STAGE):
- All other `GATEWAY_*` tables load directly from the pipe-delimited `.txt` files. Files over 250MB must be split first using `scripts/split_large_files.ps1`.

## License

Public domain. All source data is from public government records.
