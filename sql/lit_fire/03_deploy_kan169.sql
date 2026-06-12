-- KAN-169 deploy script. Run in order; requires a role with CREATE TABLE/VIEW
-- privileges on HOOSIER_DATA (CLAUDE_USER is read-only; use your own session).
--
-- Changes:
--   1. LIT_FIRE_MUNICIPAL_EXCLUSIONS table + Columbus seed row
--   2. LIT_FIRE_RATE_VERIFIED  — Columbus excluded from denominator
--   3. FIRE_COST_TREND          — extended to PROJ_2030 / PROJ_2031
--   4. SEA1_FIRE_IMPACT_SUMMARY — 2030/2031 cost projections populated
--   5. SEA1_FIRE_IMPACT_BY_COUNTY — interim cost31 CTE removed
--   6. SEA1_FIRE_IMPACT_BY_HD     — interim cost31 CTE removed
--   7. LIT_GAP_CLOSING_RATE       — new three-tier rate view
--
-- Spot-check after deploy (Bartholomew):
--   SELECT county_number, binding_township, binding_rate_pct, lit_rev_at_cap
--   FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_COUNTY
--   WHERE county_number = '03';
--   Expected: binding=OHIO TOWNSHIP, binding_rate_pct~0.167, lit_rev_at_cap=$13,340,683
--
--   SELECT township_number, township_name, cost_tracking_rate_pct,
--          sea1_offset_rate_pct, county_binding_rate_pct
--   FROM HOOSIER_DATA.ANALYTICS.LIT_GAP_CLOSING_RATE
--   WHERE county_number = '03' AND phase_year = 2031
--   ORDER BY township_number;
--   Expected: Harrison ~0.094%, Ohio ~0.167% (binding), Columbus absent

-- ── Step 1: exclusion table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LIT_FIRE_MUNICIPAL_EXCLUSIONS (
    county_number    VARCHAR,
    township_number  VARCHAR,
    county_name      VARCHAR,
    township_name    VARCHAR,
    reason           VARCHAR
);

INSERT INTO HOOSIER_DATA.RAW.LIT_FIRE_MUNICIPAL_EXCLUSIONS
    (county_number, township_number, county_name, township_name, reason)
SELECT '03', '0003', 'Bartholomew', 'Columbus',
       'City of Columbus Fire Department is primary provider; township fire fund serves ~4K rural residents only'
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.LIT_FIRE_MUNICIPAL_EXCLUSIONS
    WHERE county_number = '03' AND township_number = '0003'
);

-- ── Step 2: LIT_FIRE_RATE_VERIFIED ────────────────────────────────────────
CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED AS
WITH twp AS (
    SELECT UPPER(p.county_name) AS county_u,
           p.county_name,
           p.county_number,
           p.township_number,
           p.township_name,
           p.population_2020,
           p.land_sqmi,
           COALESCE(p.population_2020, 0) + COALESCE(p.land_sqmi, 0) * 20
               AS statutory_weight
    FROM HOOSIER_DATA.RAW.TOWNSHIP_POP_AREA p
    LEFT JOIN HOOSIER_DATA.RAW.LIT_FIRE_MUNICIPAL_EXCLUSIONS ex
        ON ex.county_number = p.county_number
       AND ex.township_number = p.township_number
    WHERE p.subdivision_type = 'township'
      AND ex.county_number IS NULL
),
cty AS (
    SELECT county_u, SUM(statutory_weight) AS county_weight
    FROM twp GROUP BY county_u
),
lit AS (
    SELECT UPPER(county_name) AS county_u,
           lit_rate_pct,
           certified_distribution,
           certified_distribution / NULLIF(lit_rate_pct / 100, 0)
               AS county_agi_base
    FROM HOOSIER_DATA.RAW.DLGF_LIT_CERTIFIED
)
SELECT t.county_number,
       t.township_number,
       t.county_name,
       t.township_name,
       t.population_2020,
       t.land_sqmi,
       t.statutory_weight,
       t.statutory_weight / NULLIF(c.county_weight, 0) AS township_share,
       l.lit_rate_pct,
       l.certified_distribution,
       l.county_agi_base,
       l.county_agi_base * 0.001 * (t.statutory_weight / NULLIF(c.county_weight, 0)) AS rev_0_1pct,
       l.county_agi_base * 0.002 * (t.statutory_weight / NULLIF(c.county_weight, 0)) AS rev_0_2pct,
       l.county_agi_base * 0.003 * (t.statutory_weight / NULLIF(c.county_weight, 0)) AS rev_0_3pct,
       l.county_agi_base * 0.004 * (t.statutory_weight / NULLIF(c.county_weight, 0)) AS rev_0_4pct
FROM twp t
JOIN cty c   ON c.county_u = t.county_u
LEFT JOIN lit l ON l.county_u = t.county_u;

-- ── Step 3+4: FIRE_COST_TREND + SEA1_FIRE_IMPACT_SUMMARY ─────────────────
-- Run the full sea1_impact.sql (it's one CREATE OR REPLACE block per view;
-- run the FIRE_COST_TREND section then the SEA1_FIRE_IMPACT_SUMMARY section).

-- ── Step 5: SEA1_FIRE_IMPACT_BY_COUNTY ────────────────────────────────────
-- Run sql/analytics/sea1_fire_impact_by_county.sql

-- ── Step 6: SEA1_FIRE_IMPACT_BY_HD ────────────────────────────────────────
-- Run sql/analytics/sea1_fire_impact_by_hd.sql

-- ── Step 7: LIT_GAP_CLOSING_RATE ──────────────────────────────────────────
-- Run the LIT_GAP_CLOSING_RATE section in sql/lit_fire/01_create_tables.sql
