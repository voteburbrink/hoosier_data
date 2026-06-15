-- KAN-182: IVFA directory modeled to department grain for the statewide
-- acceptance test. Safe to CREATE OR REPLACE (view, not a table).
--
-- What this view does that RAW must not:
--   1. Rolls station rows up to ONE row per department (station_count keeps the
--      detail). The acceptance test "every IVFA fire dept is explainable by
--      exactly one classifier outcome" only holds at department grain.
--   2. Excludes the non-fire/industrial rows (flag='Y') from matching, while
--      RAW keeps them. EMS units, plant brigades, haz-mat, career centers,
--      retirees orgs must not pollute the reconciliation.
--   3. Builds dept_norm — an uppercased, dash/punct-normalized join key — so
--      this can be matched to the IRS M24 nonprofit list and to classifier
--      output. Names are messy; this key is best-effort, not authoritative.
--   4. Pins to the latest snapshot (MAX as_of_date).
--
-- NOT done here (documented limitation, needs a follow-on source):
--   County is NOT derived. RAW has no city->county crosswalk yet. When one
--   lands, add county_number (DLGF alphabetical, not FIPS) and a
--   city_is_multi_county flag — never silently assign a county.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.IVFA_DEPARTMENTS AS
WITH latest AS (
    SELECT * FROM HOOSIER_DATA.RAW.IVFA_DEPARTMENTS_SOURCE
    WHERE as_of_date = (SELECT MAX(as_of_date) FROM HOOSIER_DATA.RAW.IVFA_DEPARTMENTS_SOURCE)
),
stripped AS (
    SELECT
        -- strip trailing station/company-number/headquarters markers to a base name
        TRIM(REGEXP_REPLACE(
            dept_name,
            '\\s+(Station\\b.*|Sta\\.?\\s*[0-9].*|Co\\.?\\s*[0-9].*|#\\s*[0-9].*|Headquarters.*)$',
            '', 1, 0, 'i'
        ))                                   AS dept_base,
        dept_name,
        TRIM(city)                           AS city,
        name_pattern,
        nonfire_or_industrial_flag,
        as_of_date
    FROM latest
)
SELECT
    dept_base                                                AS dept_name,
    city,
    -- best-effort fuzzy join key: upper, dashes->space, drop punctuation, collapse ws
    TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(UPPER(dept_base), '[‐-―\\-\\.,/]', ' '),
        '\\s+', ' '))                                        AS dept_norm,
    TRIM(REGEXP_REPLACE(UPPER(city), '\\s+', ' '))           AS city_norm,
    MAX(name_pattern)                                        AS name_pattern_hint,
    COUNT(*)                                                 AS station_count,
    as_of_date
FROM stripped
WHERE COALESCE(nonfire_or_industrial_flag, 'N') <> 'Y'   -- fire departments only
GROUP BY dept_base, city, dept_norm, city_norm, as_of_date;

-- Acceptance-test scaffold (KAN-182): every fire department should resolve to
-- exactly one funded classifier outcome. Anything that does not is a classifier
-- gap or a real anomaly worth knowing — surfaced, never silent.
--
--   SELECT i.dept_name, i.city, i.name_pattern_hint
--   FROM HOOSIER_DATA.ANALYTICS.IVFA_DEPARTMENTS i
--   LEFT JOIN <classifier_outcomes> c
--     ON c.dept_norm = i.dept_norm AND c.city_norm = i.city_norm
--   WHERE c.dept_norm IS NULL;          -- unexplained departments
