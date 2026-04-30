# Data Sources

All data is from public government sources. Download instructions and direct links below.

---

## Indiana Campaign Finance

**Source**: Indiana Election Division
**URL**: https://campaignfinance.in.gov/PublicSite/Reporting/DataDownload.aspx
**Bulk downloads**: https://publicaccountability.org/datasets/35/in_contribs/
**Coverage**: 2018-2026
**Format**: CSV, comma-delimited, double-quote enclosed
**Snowflake table**: `HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE`

Direct download pattern:
```
https://campaignfinance.in.gov/PublicSite/Docs/BulkDataDownloads/YYYY_ContributionData.csv.zip
```

---

## Legislative Votes (LegiScan)

**Source**: LegiScan
**URL**: https://legiscan.com/IN/datasets
**Coverage**: 2020-2026 (all regular sessions)
**Format**: CSV zip archives containing bills.csv, votes.csv, people.csv, rollcalls.csv, sponsors.csv
**Snowflake tables**: `LEGISCAN_BILLS`, `LEGISCAN_VOTES`, `LEGISCAN_PEOPLE`, `LEGISCAN_ROLLCALLS`, `LEGISCAN_SPONSORS`

Download instructions:
1. Register free account at legiscan.com
2. Go to legiscan.com/IN/datasets
3. Download each session ZIP
4. Rename files with year suffix: `bills_2024.csv`, `votes_2024.csv` etc.
5. Upload to `LEGISCAN_STAGE`

---

## Indiana Lobbying Data

**Source**: Indiana Lobby Registration Commission (ILRC)
**URL**: https://www.in.gov/ilrc/lobbying-data/
**Coverage**: 2021-2025
**Format**: XLSX (convert to CSV before loading)
**Snowflake tables**: `LOBBYING_EMPLOYER`, `LOBBYING_COMPENSATED`

Files:
- Employer Lobbyist Total: who paid lobbyists and how much
- Compensated Lobbyist Total: what each lobbyist was paid per client

Direct download URLs:
```
https://www.in.gov/ilrc/files/YYYY-Employer-Lobbyist-Total.xlsx
https://www.in.gov/ilrc/files/YYYY-Compensated-Lobbyist-Totals.xlsx
```

Convert XLSX to CSV using the inline conversion block in `docs/scripts.md` before uploading.

---

## Indiana Gateway - Local Government

**Source**: Indiana Gateway for Government Units
**URL**: https://gateway.ifionline.org/public/download.aspx
**Coverage**: 2020-2025
**Format**: Pipe-delimited TXT
**Snowflake tables**: Multiple `GATEWAY_*` tables

| File | Table | Description |
|---|---|---|
| detailedDisburse_fundsNOdept_YYYY.txt | GATEWAY_DISBURSEMENTS | Local govt disbursements by fund |
| detailedReceipts_YYYY.txt | GATEWAY_RECEIPTS | Local govt detailed receipts |
| townshipDisburseByVendor_YYYY.txt | GATEWAY_TOWNSHIP_VENDOR | Township payments by vendor |
| eca_fund_expenditures.txt | GATEWAY_ECA_EXPENDITURES | School extra-curricular spending |
| eca_fund_receipts.txt | GATEWAY_ECA_RECEIPTS | School extra-curricular receipts |
| eca_fund_balances.txt | GATEWAY_ECA_BALANCES | School fund balances |
| form22.txt | GATEWAY_TAX_DISTRIBUTIONS | Property tax distributions |
| e1_entity_funds.txt | GATEWAY_ENTITY_FUNDS | Federal funds to local entities |

Note: Files over 250MB must be split before uploading. Use `scripts/split_large_files.ps1`.

---

## Indiana State Expenditures

**Source**: Indiana Data Hub (Indiana Transparency Portal)
**URL**: https://hub.mph.in.gov/dataset/expenditures-data
**Coverage**: FY2020 Q1 - FY2026 Q2 (26 quarterly files)
**Format**: CSV, comma-delimited, double-quote enclosed
**Snowflake table**: `HOOSIER_DATA.RAW.STATE_EXPENDITURES`
**Download script**: `scripts/download_state_expenditures.ps1`

---

## Indiana State Vendor Spending

**Source**: Indiana Data Hub (Indiana Transparency Portal)
**URL**: https://hub.mph.in.gov/dataset/vendors-data
**Coverage**: FY2018 Q1 - FY2026 Q2
**Format**: CSV, comma-delimited
**Snowflake table**: `HOOSIER_DATA.RAW.VENDOR_EXPENDITURES`
**Download script**: `scripts/download_indiana_vendor_data.ps1`

Note: Vendor CSV columns load out of order relative to the RAW table definition. The mapping is corrected in `HOOSIER_DATA.STAGING.VENDOR_EXPENDITURES`. See `docs/snowflake-setup.md` Step 6.

---

## Federal Contracts (USASpending)

**Source**: USASpending.gov
**URL**: https://www.usaspending.gov/download_center/award_data_archive
**Coverage**: FY2020-FY2026
**Format**: CSV (297 columns, all 50 states -- filter to Indiana before loading)
**Snowflake table**: `HOOSIER_DATA.RAW.FEDERAL_CONTRACTS`

Download instructions:
1. Go to usaspending.gov/download_center/award_data_archive
2. Select Contracts, select Indiana, download by fiscal year
3. Run `scripts/filter_indiana_contracts.py` to extract Indiana-only rows
4. Upload filtered files to `CONTRACTS_STAGE`
