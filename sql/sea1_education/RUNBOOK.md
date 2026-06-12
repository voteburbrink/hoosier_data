# SEA-1 Education Impact — Run Bundle (KAN-153/154/155/156)

Everything needed to stand up the statewide SEA-1 school + library impact model,
in order. You only run the four steps below — nothing in this bundle requires
editing or scrolling through `sql/raw/create_tables.sql` or `copy_into.sql`
(the same statements live there too, for repo consistency).

## What gets built
- `RAW.DLGF_TAX_DISTRICT_UNITS` — DLGF Tax Rate Chart, the statewide tax-district→taxing-unit
  crosswalk (~53k rows/year, all 92 counties, 288 school corps, 237 libraries).
- `ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN` — typed crosswalk
- `ANALYTICS.PARCEL_DISTRICT_AV` — district-grain parcel AV
- `ANALYTICS.SEA1_DISTRICT_AV_DELTA` — homestead + 2% AV removed per district × phase year
- `ANALYTICS.SEA1_UNIT_AV_BASE` — parcel AV allocated to any taxing unit (KAN-154)
- `ANALYTICS.SEA1_SCHOOL_IMPACT` — per school corp × phase year (KAN-155)
- `ANALYTICS.SEA1_LIBRARY_IMPACT` — per library × phase year (KAN-156)
- `ANALYTICS.SEA1_EDUCATION_SUMMARY` — fire + school + library, unified (KAN-156)
- `ANALYTICS.SCHOOL_COST_TREND`, `ANALYTICS.LIBRARY_COST_TREND` — cost trends

---

## Step 1 — Download the TRC workbooks  (already done; re-run to refresh)
```powershell
python scripts/download_dlgf_trc.py
```
Lands `propertydata/trc/2024_trc_unit.xlsx` and `2025_trc_unit.xlsx`.

## Step 2 — Load into Snowflake  (creates the table + COPYs; MFA prompt)
```powershell
python scripts/load_snowflake_trc.py
```
This converts xlsx→csv, PUTs to `GATEWAY_STAGE`, runs `CREATE TABLE IF NOT EXISTS`,
and `COPY INTO`. Prints row counts by year at the end (expect ~53,372 each).

> Manual alternative (skip the loader): stage the CSVs yourself, then run
> `01_create_table_trc.sql` and `02_copy_into_trc.sql` in Snowsight.

## Step 3 — Build the analytics views  (ACCOUNTADMIN)
Run the views file:
```
sql/analytics/sea1_education_impact.sql
```
All `CREATE OR REPLACE VIEW` — safe to re-run.

## Step 4 — Validate
Run:
```
sql/sea1_education/04_validate.sql
```
Confirms statewide coverage and prints the Bartholomew County packet.

---

## Known caveat — BPP loss is an UPPER BOUND
BPP loss assumes 100% of each district's business personal property becomes
exempt. True for small rural districts; **overstated** wherever large taxpayers
(>$2M, e.g. Cummins in the City of Columbus) stay taxable. Flagged in-view as
`'ESTIMATED — BPP upper bound'`. The defensible recurring number is
**homestead + 2%** (BCSC ≈ $2.0M/yr at 2031); BCSC total incl. BPP upper bound ≈ $6.36M.
