# IVFA Department Directory — Load Runbook (KAN-182)

Statewide IVFA volunteer fire department directory: ground-truth reference for
the classifier acceptance test. **Presence is signal; absence proves nothing**
(IVFA is membership-based).

## Source
- File: `firedata/ivfa_departments_2026-06-12.csv` (827 rows, UTF-8)
- Origin: ivfa.org department directory, pulled 2026-06-12
- Columns: `dept_name, city, name_pattern, nonfire_or_industrial_flag, source, as_of_date`

## Load order (run through the MFA loader — CLAUDE_USER is read-only)
1. `01_create_tables.sql` — RAW table, all VARCHAR, `IF NOT EXISTS`.
2. Stage + upload:
   ```sql
   CREATE STAGE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_STAGE;
   PUT file://<repo>/firedata/ivfa_departments_2026-06-12.csv @HOOSIER_DATA.RAW.IVFA_STAGE;
   ```
3. `02_copy_into.sql` — COPY INTO RAW. Snapshot load: appends by `as_of_date`,
   does NOT clobber. Never TRUNCATE between pulls.
4. `03_analytics_view.sql` — `ANALYTICS.IVFA_DEPARTMENTS` (dept grain).

## Expected counts (2026-06-12 snapshot)
- RAW: **827** rows (`SELECT as_of_date, COUNT(*) ... GROUP BY 1`)
- Excluded by flag='Y': **20** (EMS/plant brigade/haz-mat/career center/retirees)
- ANALYTICS.IVFA_DEPARTMENTS: **782** departments (805 fire rows rolled up by station)
- name_pattern hints: TOWNSHIP_NAMED 291, OTHER 501, TERRITORY 26, DISTRICT 9

## Constraints baked into the model
- **No county.** Derived downstream only; multi-county cities must be flagged,
  never silently assigned. No city->county crosswalk exists in RAW yet.
- **name_pattern is a hint**, not a funding fact (Marengo-Liberty: names lie).
- **dept_norm** is a best-effort fuzzy join key, not authoritative.

## Acceptance test (KAN-182)
Every department in `ANALYTICS.IVFA_DEPARTMENTS` must resolve to exactly one
funded classifier outcome (township fund / territory / district / municipal /
documented contract). Unmatched rows are a classifier gap or a real anomaly —
they surface in the reconciliation report, never silently. Join scaffold is at
the bottom of `03_analytics_view.sql`.

Optional enrichment: join `dept_norm`+`city_norm` to the IRS M24 nonprofit fire
list for EIN/tax status. IVFA-present + no IRS record => municipal/government
department (a legitimate outcome, not a gap).
