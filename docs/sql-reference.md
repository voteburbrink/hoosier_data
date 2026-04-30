# SQL Reference

All SQL lives in the `sql/` folder organized by layer.

---

## RAW Layer

### sql/raw/create_tables.sql

CREATE TABLE statements for all 22 RAW tables. All columns are defined as VARCHAR -- no type casting at the landing layer.

Run once during initial setup, or re-run with `CREATE OR REPLACE` to reset a table.

Tables created:
- `CAMPAIGN_FINANCE_SOURCE`
- `LEGISCAN_BILLS`, `LEGISCAN_PEOPLE`, `LEGISCAN_ROLLCALLS`, `LEGISCAN_SPONSORS`, `LEGISCAN_VOTES`
- `LOBBYING_EMPLOYER`, `LOBBYING_COMPENSATED`
- `STATE_EXPENDITURES`, `VENDOR_EXPENDITURES`
- `GATEWAY_DISBURSEMENTS`, `GATEWAY_DISBURSEMENTS_LEGACY`
- `GATEWAY_RECEIPTS`, `GATEWAY_RECEIPTS_LEGACY`
- `GATEWAY_TOWNSHIP_VENDOR`, `GATEWAY_TOWNSHIP_VENDOR_LEGACY`
- `GATEWAY_ECA_EXPENDITURES`, `GATEWAY_ECA_RECEIPTS`, `GATEWAY_ECA_BALANCES`
- `GATEWAY_TAX_DISTRIBUTIONS`, `GATEWAY_ENTITY_FUNDS`
- `FEDERAL_CONTRACTS`

---

### sql/raw/copy_into.sql

COPY INTO commands for loading staged files into RAW tables. Each command uses a PATTERN regex to match specific files within a shared stage.

| Table | Stage | Pattern |
|---|---|---|
| CAMPAIGN_FINANCE_SOURCE | CAMPAIGN_STAGE | `.*ContributionData.*\.csv` |
| LEGISCAN_BILLS | LEGISCAN_STAGE | `.*bills.*\.csv` |
| GATEWAY_DISBURSEMENTS | GATEWAY_STAGE | `.*detailedDisburse_fundsNOdept_20.*\.txt` |
| GATEWAY_DISBURSEMENTS_LEGACY | GATEWAY_STAGE | `.*detailedDisburse_fundsNOdept_part.*\.txt` |
| GATEWAY_ECA_EXPENDITURES | GATEWAY_STAGE | `.*eca_fund_expenditures.*\.txt` |
| STATE_EXPENDITURES | EXPENDITURE_STAGE | `.*expenditure.*\.csv` |
| LOBBYING_EMPLOYER | LOBBYING_STAGE | `.*employer.*\.csv` |
| LOBBYING_COMPENSATED | LOBBYING_STAGE | `.*compensated.*\.csv` |
| FEDERAL_CONTRACTS | CONTRACTS_STAGE | `.*\.csv` |
| VENDOR_EXPENDITURES | VENDOR_STAGE | `.*\.csv` |

All commands use `ON_ERROR = 'CONTINUE'` so a single bad row does not abort an entire file load.

Snowflake tracks which files have already been loaded per stage. Running COPY INTO twice will not duplicate data -- it skips already-processed files.

---

## STAGING Layer

STAGING views are defined in `docs/snowflake-setup.md` Step 6.

### VENDOR_EXPENDITURES view

Corrects the column mapping where CSV columns loaded positionally out of order. The vendor name was sitting in the `SOURCE` column of RAW.

### LEGISLATORS view

Deduplicates LEGISCAN_PEOPLE from 7 rows per legislator (one per session) down to 1. Exposes `people_id`, `name`, `party`, `role`, `district` for clean lookups.

---

## ANALYTICS Layer

### sql/analytics/candidate_research.sql

A 13-query candidate research playbook. Set the district and target legislator at the top, then run any query against any Indiana House or Senate district.

**Setup:**

```sql
-- Find the legislator
SELECT DISTINCT people_id, name, party, role, district
FROM HOOSIER_DATA.RAW.LEGISCAN_PEOPLE
WHERE district = 'HD-059'       -- change to target district
   OR last_name ILIKE '%Smith%'; -- or search by name

-- Set their ID
SET target_id = '20210';        -- change to people_id from above
```

**Queries included:**

| # | Query | What it answers |
|---|---|---|
| 1 | Legislator lookup | Find people_id by district or name |
| 2 | Finance summary | Total raised by contributor type |
| 3 | Top 25 donors | Biggest donors with dates |
| 4 | PAC donors only | Which PACs funded them |
| 5 | Donations by year | Fundraising trend over time |
| 6 | Voting record summary | Yea/Nay/Absent breakdown |
| 7 | Missed votes | Every absence with bill context |
| 8 | Bills sponsored | All legislation they introduced |
| 9 | Votes by topic | Filter votes by keyword |
| 10 | PAC donors vs state contracts | Donors that also received state payments |
| 11 | PAC donors vs federal contracts | Donors that also received federal awards |
| 12 | Out of district donors | Geographic breakdown of contributions |
| 13 | Legislator cross-reference | All external IDs (FollowTheMoney, VoteSmart, Ballotpedia) |

**Example output -- Ryan Lauer (HD-059, people_id 20210):**
- $210,330 raised from 760 contributions
- Top PAC: Indiana Realtors PAC ($15,000)
- Duke Energy PAC donated $2,300; Lauer voted YES on HB1002 (electric utility bill) and NO on all 7 consumer protection amendments
- Anthem Insurance received $2.76B in state payments and is a campaign donor

**Example output -- Greg Walker (SD-041, people_id 5608):**
- $2.62M raised
- 83.8% Yea voting rate, 5 absences
- Out-of-state money from DC, Ohio, Illinois, Texas

---

## Adding New Data Years

When new data becomes available (new LegiScan session, new campaign finance cycle, new Gateway files):

1. Download new files following `docs/data-sources.md`
2. Upload to the appropriate stage
3. Run the relevant COPY INTO from `sql/raw/copy_into.sql`

Snowflake skips previously loaded files automatically. No table changes are needed unless the source adds new columns -- in that case update `sql/raw/create_tables.sql` and reload.
