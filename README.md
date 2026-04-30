# hoosier_data

Snowflake data warehouse for Indiana public records. Covers campaign finance, legislative voting, lobbying, state and local government spending, and federal contracts.

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
| Local Govt Disbursements | Indiana Gateway | 783,024 | 2020-2024 |
| Local Govt Receipts | Indiana Gateway | 448,339 | 2021-2024 |
| Township Vendor Payments | Indiana Gateway | 379,050 | 2020-2025 |
| ECA Expenditures | Indiana Gateway | 4,385,913 | Multi-year |
| ECA Receipts | Indiana Gateway | 4,223,741 | Multi-year |
| ECA Balances | Indiana Gateway | 537,161 | Multi-year |
| Tax Distributions | Indiana Gateway | 1,014,580 | Multi-year |
| Entity Funds (federal) | Indiana Gateway | 74,662 | Multi-year |
| Federal Contracts | USASpending.gov | 304,116 | FY2020-FY2026 |

43 million rows across 22 tables.

## Setup

See [docs/snowflake-setup.md](docs/snowflake-setup.md) for Snowflake instance setup and [docs/data-sources.md](docs/data-sources.md) for data download instructions.

## License

Public domain. All source data is from public government records.
