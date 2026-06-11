# Landing KAN-129 + KAN-159: verified fire/EMS LIT model

Two data loads remove the last estimates blocking real LIT revenue figures in
the VFD packet. `CLAUDE_USER` is read-only, so **you run the loaders** (MFA),
same flow as `load_snowflake_xwalk.py`.

## What you're loading and why

| Ticket | Gap today | Data to load | Target table |
|---|---|---|---|
| **KAN-159** | LIT split uses fire-levy share; statute uses `population + sq mi x 20` | township population + land area | `RAW.TOWNSHIP_POP_AREA` |
| **KAN-129** | County income base is a hand-entered $40.3M estimate | DLGF certified LIT distribution + rate, per county | `RAW.DLGF_LIT_CERTIFIED` |

Both feed `ANALYTICS.LIT_FIRE_RATE_VERIFIED`, which replaces the estimated
`LIT_FIRE_RATE_PROJECTION` and lets the packet print real per-township LIT
revenue instead of the labeled estimate.

## Data sources (all public)

**KAN-159 — population + land area (automated; one free key):**
- 2020 Census population by township: Census P.L. 94-171 API (`P1_001N`,
  county subdivisions, state 18). **Requires a free Census API key** (instant
  signup at https://api.census.gov/data/key_signup.html). Set it as
  `CENSUS_API_KEY` before running the build.
- Land area: 2023 Census Gazetteer, National County Subdivisions file
  (`ALAND_SQMI`). Auto-downloaded by the build script (no key; verified
  working, 1,012 Indiana subdivisions).
- Build script: `scripts/build_township_pop_area.py` fetches and joins both on
  the 10-digit GEOID and writes `censusdata/township_pop_area.csv`.

**KAN-129 — verified county LIT base (automated, all 92 counties):**
- Source: SBA **2026 Certification Calculations** (has per-county distributions
  AND rate components in one report):
  https://www.in.gov/sba/files/2026-Certification-Calculations-November-Release.pdf
  plus DOR DN#1 for county codes.
- Income base per county: `AGI = total LIT distribution / total LIT rate`
  (equivalently certified-shares / certified-shares rate; the two agree to the
  dollar — validated on Bartholomew = $3.335B).
- `litdata/lit_certified.csv` is **already generated for all 92 counties** by
  `scripts/build_lit_certified.py`. No manual fill-in. Re-run that script only
  to refresh for a new year (it needs the `pdftotext` utility).

## Run order

```powershell
# 1. KAN-159: build + load township population/area (automated)
$env:CENSUS_API_KEY = "your_free_census_key"   # one-time, instant signup
python scripts/build_township_pop_area.py
python scripts/load_snowflake_township_pop_area.py   # prompts for user/pw/MFA

# 2. KAN-129: litdata/lit_certified.csv is already built (all 92 counties).
#    Just load it (re-run build_lit_certified.py only to refresh a new year).
python scripts/load_snowflake_lit_certified.py       # prompts for user/pw/MFA

# 3. Create the output view + validate (run in a Snowflake worksheet, or via
#    the loader role)
#    sql/lit_fire/01_create_tables.sql
#    sql/lit_fire/02_validate.sql
```

`SNOWFLAKE_USER` / `SNOWFLAKE_PASSWORD` come from env vars; `--passcode` is the
6-digit MFA code. Loaders TRUNCATE-then-load (full-snapshot refresh) and use
`CREATE TABLE IF NOT EXISTS`.

## Validation gate

`02_validate.sql` step 2 reproduces the analysis page's published number: a
0.025% Bartholomew fire LIT should compute to about **$805,967**. If it does,
KAN-129's base is verified. Step 3 prints the new statutory per-township shares
(KAN-159).

## After it lands

Swap the packet's estimated LIT line for verified figures: point
`build_brief.py` / `build_data_sheet.py` at `ANALYTICS.LIT_FIRE_RATE_VERIFIED`
instead of the `lit` config block, and drop the "estimate" caveat. The
per-township minimum-rate figure then becomes printable too.
