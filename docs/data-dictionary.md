# Data Dictionary — HOOSIER_DATA RAW Layer

All RAW tables store columns as VARCHAR. Type casting happens in the STAGING layer.

---

## CAMPAIGN_FINANCE_SOURCE

Indiana campaign contribution records from the Indiana Election Division.

| Column | Description |
|---|---|
| file_number | Committee registration number |
| committee_type | Type of committee (e.g., candidate, PAC) |
| committee | Full committee name |
| candidate_name | Candidate associated with the committee |
| contributor_type | Individual, business, PAC, etc. |
| name | Contributor name |
| address | Street address |
| city | City |
| state | State code |
| zip | ZIP code |
| occupation | Contributor occupation (individuals only) |
| type | Transaction type (contribution, loan, etc.) |
| description | Optional description |
| amount | Dollar amount |
| contribution_date | Date of contribution (MM/DD/YYYY) |
| received_by | Name of person who received the contribution |
| amended | Whether this record amends a prior filing |

---

## LEGISCAN_BILLS

Legislative bills from LegiScan for Indiana sessions 2020–2026.

| Column | Description |
|---|---|
| bill_id | LegiScan unique bill identifier |
| session_id | LegiScan session identifier |
| bill_number | Official bill number (e.g., HB1234, SB56) |
| status | Numeric status code |
| status_desc | Human-readable status (Passed, Failed, etc.) |
| status_date | Date of last status change |
| title | Short bill title |
| description | Full bill description |
| committee_id | Committee assignment ID |
| committee | Committee name |
| last_action_date | Date of most recent action |
| last_action | Text description of most recent action |
| url | LegiScan URL for this bill |
| state_link | Indiana General Assembly URL |

---

## LEGISCAN_PEOPLE

Legislators and their identifiers across multiple external databases.

| Column | Description |
|---|---|
| people_id | LegiScan unique legislator ID |
| name | Full name |
| first_name | First name |
| middle_name | Middle name |
| last_name | Last name |
| suffix | Name suffix (Jr., Sr., etc.) |
| nickname | Common nickname |
| party_id | Party numeric code |
| party | Party name (Republican, Democrat, etc.) |
| role_id | Chamber role numeric code |
| role | Role description (Representative, Senator) |
| district | District identifier (e.g., HD-059) |
| followthemoney_eid | FollowTheMoney.org entity ID |
| votesmart_id | VoteSmart.org candidate ID |
| opensecrets_id | OpenSecrets.org candidate ID |
| ballotpedia | Ballotpedia page slug |
| knowwho_pid | KnowWho person ID |
| committee_id | Primary committee assignment |

---

## LEGISCAN_ROLLCALLS

Roll call vote summaries for each vote taken on a bill.

| Column | Description |
|---|---|
| bill_id | References LEGISCAN_BILLS.bill_id |
| roll_call_id | LegiScan unique roll call identifier |
| date | Date of the vote |
| chamber | House or Senate |
| description | Description of the vote |
| yea | Count of Yea votes |
| nay | Count of Nay votes |
| nv | Count of Not Voting |
| absent | Count of Absent |
| total | Total members voting |

---

## LEGISCAN_VOTES

Individual legislator votes on each roll call.

| Column | Description |
|---|---|
| roll_call_id | References LEGISCAN_ROLLCALLS.roll_call_id |
| people_id | References LEGISCAN_PEOPLE.people_id |
| vote | Numeric vote code |
| vote_desc | Yea, Nay, NV, Absent, Excused |

---

## LEGISCAN_SPONSORS

Bill sponsorship records.

| Column | Description |
|---|---|
| bill_id | References LEGISCAN_BILLS.bill_id |
| people_id | References LEGISCAN_PEOPLE.people_id |
| position | Primary or co-sponsor designation |

---

## LOBBYING_EMPLOYER

Lobbying expenditures by employer (who hired and paid lobbyists), by year and reporting period. Source: Indiana Lobby Registration Commission.

| Column | Description |
|---|---|
| year | Reporting year |
| lobbyist | Lobbyist or firm name |
| terminated | Whether registration was terminated this period |
| first_period_compensation | Compensation paid Jan–Jun |
| first_period_reimbursements | Reimbursements Jan–Jun |
| first_period_receptions | Reception costs Jan–Jun |
| first_period_other_entertainment | Other entertainment Jan–Jun |
| first_period_other_gifts | Gifts to legislators Jan–Jun |
| first_period_expenditures_all_members | Total expenditures for all legislative members Jan–Jun |
| first_period_gifts | Gift totals Jan–Jun |
| first_period_registration_late_fees | Late registration fees Jan–Jun |
| first_period_other_expenses | Other expenses Jan–Jun |
| first_period_gross_expenditures | Total gross expenditures Jan–Jun |
| second_period_* | Same fields for Jul–Dec reporting period |
| grand_totals | Full-year totals |

---

## LOBBYING_COMPENSATED

Lobbying expenditures by individual lobbyist and client, by year. Source: Indiana Lobby Registration Commission.

Same structure as LOBBYING_EMPLOYER with the addition of:

| Column | Description |
|---|---|
| client | Name of the client (employer) the lobbyist represented |
| first_period_deductions | Deductions applied to gross expenditures Jan–Jun |
| first_period_net_expenditures | Net expenditures after deductions Jan–Jun |
| second_period_deductions | Same for Jul–Dec |
| second_period_net_expenditures | Same for Jul–Dec |

---

## STATE_EXPENDITURES

Indiana state government expenditures from the Indiana Transparency Portal. One row per journal transaction.

**Source**: Indiana Data Hub | **Stage**: EXPENDITURE_STAGE | **Rows**: 6,488,697 | **Coverage**: FY2020 Q1 – FY2026 Q2

| Column | Description |
|---|---|
| account_name | Budget account name |
| account_id | Budget account ID |
| agency_name | State agency name |
| agency_id | State agency ID |
| amount | Dollar amount of expenditure |
| expenditure_category | Category of spending |
| fiscal_year | Indiana fiscal year (July 1 – June 30) |
| function_of_govt | Government function classification |
| fund_name | Fund name |
| fund_id | Fund ID |
| funding_source | Funding source type |
| journal_date | Date of journal entry |
| journal_id | Journal entry ID |
| last_updated | Record last updated timestamp |
| legal_fund_name | Legal fund name |
| legal_fund_id | Legal fund ID |
| source | Data source indicator |
| vendor_name | Vendor paid |
| vendor_id | Vendor ID |
| journal_agency_id | Journal agency ID |

**Notes**
- All columns are VARCHAR in RAW layer — cast to proper types in STAGING
- Indiana fiscal year runs July 1 through June 30
- FY2025 Q4 and FY2026 Q1/Q2 are partial/preliminary

---

## VENDOR_EXPENDITURES

Indiana state expenditures summarized by vendor. Same columns as STATE_EXPENDITURES plus `voucher_id`.

| Column | Description |
|---|---|
| voucher_id | Payment voucher identifier |
| (all others) | Same as STATE_EXPENDITURES |

---

## GATEWAY_DISBURSEMENTS

Local government disbursements by fund, from Indiana Gateway. Annual files 2020–2024. 20 columns.

| Column | Description |
|---|---|
| year | Fiscal year |
| cnty_cd | County numeric code |
| cnty_description | County name |
| budget_unit_type | Type of budget unit |
| unit_code | Unit identifier code |
| sboa_id | State Board of Accounts ID |
| afr_unit_type | Annual Financial Report unit type |
| unit_name | Government unit name (city, school, township, etc.) |
| ent_id | Entity identifier |
| ent_name | Entity name |
| fund_code | Fund code |
| unit_fund_number | Unit-assigned fund number |
| fund_name | Fund name |
| disburse_class_code | Disbursement class code |
| class_name | Disbursement class name |
| disburse_code | Disbursement line code |
| section | Section identifier |
| disburse_name | Disbursement line name |
| amount | Dollar amount |
| spare_col | Unused trailing column |

**GATEWAY_DISBURSEMENTS_LEGACY** — legacy bulk file with 17 columns, different column ordering. Pre-2020 schema.

---

## GATEWAY_RECEIPTS

Local government receipts, from Indiana Gateway. Annual files 2021–2024. 23 columns.

| Column | Description |
|---|---|
| year | Fiscal year |
| cnty_cd | County numeric code |
| cnty_description | County name |
| budget_unit_type | Type of budget unit |
| unit_code | Unit identifier code |
| sboa_id | State Board of Accounts ID |
| afr_unit_type | Annual Financial Report unit type |
| unit_name | Government unit name |
| ent_id | Entity identifier |
| ent_name | Entity name |
| fund_code | Fund code |
| unit_fund_number | Unit-assigned fund number |
| fund_name | Fund name |
| receipt_class_code | Receipt class code |
| receipt_class_name | Receipt class name |
| receipt_code | Receipt line code |
| section | Section identifier |
| other_item_flag | Flag for other/misc receipt items |
| receipt_name | Receipt line name |
| unit_account_number | Unit-assigned account number |
| unit_account_name | Unit-assigned account name |
| amount | Dollar amount |
| spare_col | Unused trailing column |

**GATEWAY_RECEIPTS_LEGACY** — legacy bulk file with 20 columns, different column ordering.

---

## GATEWAY_TOWNSHIP_VENDOR

Township disbursements broken down by vendor. Annual files 2020–2025.

| Column | Description |
|---|---|
| year | Fiscal year |
| cnty_description | County name |
| county_cd_fk | County code foreign key |
| budget_unit_type | Budget unit type |
| unit_code | Unit code |
| unit_name | Township name |
| sboa_id | State Board of Accounts ID |
| afr_unit_type | AFR unit type |
| fund_code | Fund code |
| unit_fund_number | Unit fund number |
| unit_fund_name | Fund name |
| disburse_class_code | Disbursement class code |
| disburse_class_name | Disbursement class name |
| vendor_name | Vendor or payee name |
| vendor_disburse_code | Vendor-specific disbursement code |
| amount | Dollar amount |
| spare_col | Unused trailing column |

**GATEWAY_TOWNSHIP_VENDOR_LEGACY** — same without `sboa_id` and `spare_col`.

---

## GATEWAY_ECA_EXPENDITURES / GATEWAY_ECA_RECEIPTS / GATEWAY_ECA_BALANCES

School extra-curricular activity (ECA) fund financials from Indiana Gateway.

| Column | Description |
|---|---|
| year | Fiscal year |
| cnty_description | County name |
| county_cd_fk | County code |
| unit_type_id | Unit type |
| unit_code | School/unit code |
| corp_county | School corporation county |
| corp_name | School corporation name |
| unit_name | School name |
| fund_id | ECA fund identifier |
| fund_name | ECA fund name |
| purpose | Expenditure purpose (ECA_EXPENDITURES only) |
| source / nature | Receipt source and nature (ECA_RECEIPTS only) |
| beginning_bal / rcpts / expd / end_bal | Fund balance fields (ECA_BALANCES only) |
| amount | Dollar amount |
| submit_status | Submission status |

---

## GATEWAY_TAX_DISTRIBUTIONS

Property tax distributions to local government units, from Indiana Gateway (Form 22).

| Column | Description |
|---|---|
| yr_nbr | Year number |
| county | County name |
| county_cd | County code |
| unit_type_cd | Unit type code |
| unit_cd | Unit code |
| unit_type_desc | Unit type description |
| unit | Unit name |
| entity_cd | Entity code |
| entity | Entity name |
| distribution_cd | Distribution type code |
| distrib_type | Distribution type description |
| distribution_date | Date of distribution |
| advance | Advance payment amount |
| warrant | Warrant amount |
| amt | Total distribution amount |
| distribution_month | Month of distribution |

---

## GATEWAY_ENTITY_FUNDS

Federal pass-through funds received by local entities (E-1 filings), from Indiana Gateway. 55 columns covering entity identity, auditor information, and federal fund details.

Key columns:

| Column | Description |
|---|---|
| year | Fiscal year |
| entity_id | Entity identifier |
| unit_name | Government unit name |
| legal_name | Legal entity name |
| cfda_number | CFDA program number (federal grant identifier) |
| gvmt_agency_name | Federal agency that issued the grant |
| program_title | Federal program title |
| amount_received | Federal funds received |
| amount_disbursed | Federal funds disbursed |
| fund_classification | Fund classification |
| sboa_fund_classification | State Board of Accounts fund classification |

---

## FEDERAL_CONTRACTS

Federal contract awards to Indiana recipients or performed in Indiana, from USASpending.gov. 297 columns.

Key columns:

| Column | Description |
|---|---|
| contract_transaction_unique_key | Unique identifier for this transaction |
| award_id_piid | Contract award ID |
| federal_action_obligation | Dollar amount obligated in this action |
| total_dollars_obligated | Cumulative obligation on this award |
| action_date | Date of this contract action |
| awarding_agency_name | Federal agency making the award |
| awarding_sub_agency_name | Sub-agency making the award |
| recipient_name | Contractor name |
| recipient_city_name | Contractor city |
| recipient_state_code | Contractor state (IN for Indiana) |
| primary_place_of_performance_state_code | State where work is performed |
| primary_place_of_performance_city_name | City where work is performed |
| naics_code | NAICS industry code |
| naics_description | Industry description |
| product_or_service_code | Product/service code |
| product_or_service_code_description | Product/service description |
| transaction_description | Description of this contract action |
| extent_competed | Whether contract was competitively bid |
| type_of_set_aside | Small business set-aside type |
| action_date_fiscal_year | Federal fiscal year of action |
| usaspending_permalink | Direct link to award on USASpending.gov |

---

## LEGISLATIVE_DISTRICT_XWALK

Township → Indiana legislative district crosswalk (KAN-158). Current 2021-plan /
123rd GA districts — the map the SEA-1 (2025) legislators sit in. One row per
township-district pair; built by `scripts/build_legislative_xwalk.py`.

| Column | Description |
|---|---|
| county_number | DLGF alphabetical county number, e.g. `03`; joins `DLGF_TOWNSHIP_CODES` / `GATEWAY_PARCEL` |
| county_name | County name, e.g. `BARTHOLOMEW COUNTY` |
| township_number | DLGF township number, e.g. `0004` |
| township_name | Township name, e.g. `FLATROCK TOWNSHIP` |
| house_district | Indiana House district, `HD-0NN` format (matches `LEGISCAN_PEOPLE.district`) |
| senate_district | Indiana Senate district, `SD-0NN` format (matches `LEGISCAN_PEOPLE.district`) |
| congressional_district | U.S. House district, `CD-0N`; comma-separated when a township straddles a line |
| is_split | `true`/`false` — township crosses >1 House OR >1 Senate district |
| precinct_count | Number of precincts backing this township-district pair |
| data_vintage | Source vintage year, e.g. `2024` |
