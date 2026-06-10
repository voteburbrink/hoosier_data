# Data Sources

All data is from public government sources. Download instructions and direct links below.

---

## Indiana Campaign Finance

**Source**: Indiana Election Division
**URL**: https://campaignfinance.in.gov/PublicSite/Reporting/DataDownload.aspx
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
**Format**: Pipe-delimited TXT (except certNav which is comma-delimited)

### Statewide Bulk Tables

Upload directly to `GATEWAY_STAGE` (no filtering required). Files over 250MB must be split using `scripts/split_large_files.ps1`.

| File | Table | Description |
|---|---|---|
| detailedDisburse_fundsNOdept_YYYY.txt | GATEWAY_DISBURSEMENTS | Local govt disbursements by fund (year files 2020-2025) |
| detailedDisburse_fundsNOdept_part*.txt | GATEWAY_DISBURSEMENTS_LEGACY | Local govt disbursements (legacy bulk, pre-2020) |
| detailedReceipts_YYYY.txt | GATEWAY_RECEIPTS | Local govt detailed receipts (year files 2021-2025) |
| detailedReceipts_part*.txt | GATEWAY_RECEIPTS_LEGACY | Local govt receipts (legacy bulk) |
| townshipDisburseByVendor_YYYY.txt | GATEWAY_TOWNSHIP_VENDOR | Township payments by vendor (year files 2020-2025) |
| townshipDisburseByVendor.txt | GATEWAY_TOWNSHIP_VENDOR_LEGACY | Township vendor payments (legacy bulk) |
| eca_fund_expenditures.txt | GATEWAY_ECA_EXPENDITURES | School extra-curricular spending |
| eca_fund_receipts.txt | GATEWAY_ECA_RECEIPTS | School extra-curricular receipts |
| eca_fund_balances.txt | GATEWAY_ECA_BALANCES | School fund balances |
| form22.txt | GATEWAY_TAX_DISTRIBUTIONS | Property tax distributions |
| e1_entity_funds.txt | GATEWAY_ENTITY_FUNDS | Federal funds to local entities |
| afr_CapAssets.txt | GATEWAY_CAP_ASSETS | Capital assets reporting |
| form4a.txt | GATEWAY_FORM4A | Budget estimates |
| form4b.txt | GATEWAY_FORM4B | Budget adopted |
| detailedRevenue.txt | GATEWAY_DETAILED_REVENUE | Detailed revenue by fund |
| Grants.txt | GATEWAY_GRANTS | Grant receipts |
| nonGovEntities.txt | GATEWAY_NONGOV_ENTITIES | Non-governmental entity filings |
| CashInvCombined.txt | GATEWAY_CASH_INV_COMBINED | Cash and investments combined |
| TA7.txt | GATEWAY_TA7 | Township assistance applications |

### Bartholomew-Filtered Detail Tables

Run `scripts/prepare_gateway_data.ps1` to filter statewide files to Bartholomew County rows and convert pipe-delimited format to CSV before uploading.

| Source file | Output CSV | Table |
|---|---|---|
| detailedDisburse_fundswithdept.txt | detailedDisburse_fundswithdept.csv | GATEWAY_DISBURSEMENTS_DETAIL |
| detailedReceipts.txt | detailedReceipts.csv | GATEWAY_RECEIPTS_DETAIL |
| form22.txt | form22.csv | GATEWAY_FORM22 |
| certNav.txt | certNav.csv | GATEWAY_CERT_NAV |

**certNav schema note**: Indiana Gateway changed the certNav column structure in 2024. The old schema (homestead/rental/commercial NAV breakdown) was replaced with AV-by-tax-classification (1%/2%/3%) plus TIF components. The current `GATEWAY_CERT_NAV` DDL reflects the new 20-column schema.

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
**Coverage**: FY2015 Q1 - FY2026 Q3
**Format**: CSV, comma-delimited
**Snowflake table**: `HOOSIER_DATA.RAW.VENDOR_EXPENDITURES`

Note: Vendor CSV columns load out of order relative to the RAW table definition. The mapping is corrected in `HOOSIER_DATA.STAGING.VENDOR_EXPENDITURES`. See `docs/snowflake-setup.md` Step 6.

---

## Federal Contracts (USASpending)

**Source**: USASpending.gov
**URL**: https://www.usaspending.gov/download_center/award_data_archive
**Coverage**: FY2020-FY2026
**Format**: CSV (297 columns, all 50 states — filter to Indiana before loading)
**Snowflake table**: `HOOSIER_DATA.RAW.FEDERAL_CONTRACTS`

Download instructions:
1. Go to usaspending.gov/download_center/award_data_archive
2. Select Contracts, select Indiana, download by fiscal year
3. Run `scripts/filter_indiana_contracts.py` to extract Indiana-only rows
4. Upload filtered files to `CONTRACTS_STAGE`

---

## Township → Legislative District Crosswalk (KAN-158)

**Sources** (both public, no account required):
- **Precincts**: IndianaMap "Voting District Boundaries 2024" (current 123rd GA /
  2021 redistricting plan, from the IGA + Indiana Election Division). Each
  precinct carries its House (`h`), Senate (`s`), and Congressional (`c`)
  district and county FIPS.
  `https://gisdata.in.gov/server/rest/services/Hosted/Voting_District_Boundaries_2024/FeatureServer/1`
- **Township polygons**: U.S. Census TIGER/Line 2024 county subdivisions (Indiana
  civil townships). `https://www2.census.gov/geo/tiger/TIGER2024/COUSUB/tl_2024_18_cousub.zip`

**Snowflake table**: `HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK`

**Method**: Precincts nest within a single House + Senate district and a single
township by statute (IC 3-11-1.5), so each precinct is assigned to the township
polygon containing it, then matched to `DLGF_TOWNSHIP_CODES` on (county, name).
County FIPS ↔ DLGF county_number is deterministic: `fips = 2 * county_number - 1`.
This gives exact township→district sets with no area-sliver false splits.

Build + load:
```
python scripts/build_legislative_xwalk.py   # -> districtdata/legislative_district_xwalk.csv
python scripts/load_snowflake_xwalk.py       # TRUNCATE + COPY (full-snapshot refresh)
```

District codes use the `LEGISCAN_PEOPLE.district` format (`HD-059`, `SD-041`) for
a direct join. **Important**: this reflects the **current** districts the SEA-1
(2025) legislators sit in — not the pre-2022 map. ~48 precincts in non-DLGF
subdivisions (consolidated towns e.g. Zionsville, Camp Atterbury, Lake Michigan
water) have no township_number and are excluded; the builder prints them.
Validate with `sql/analytics/legislative_xwalk_validate.sql`.
