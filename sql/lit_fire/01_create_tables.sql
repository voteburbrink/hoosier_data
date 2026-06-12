-- KAN-129 + KAN-159: verified fire/EMS LIT modeling inputs and output view.
-- Tables use CREATE TABLE IF NOT EXISTS (never OR REPLACE - June 5 2026 wipe).
-- The view is safe to CREATE OR REPLACE.

-- KAN-159 input: township population + land area (Census), for the
-- statutory distribution weight = service population + square miles x 20.
CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.TOWNSHIP_POP_AREA (
    geoid             VARCHAR,
    state_fips        VARCHAR,
    county_fips       VARCHAR,
    county_name       VARCHAR,
    cousub_fips       VARCHAR,
    subdivision_name  VARCHAR,
    township_name     VARCHAR,
    subdivision_type  VARCHAR,
    population_2020   NUMBER,
    land_sqmi         FLOAT,
    data_vintage      VARCHAR,
    county_number     VARCHAR,  -- DLGF county_number (KAN-164)
    township_number   VARCHAR   -- DLGF township_number (KAN-164)
);

-- Municipal/city-township exclusions for LIT fire distribution weight denominator.
-- Rows here are removed from the township weight pool in LIT_FIRE_RATE_VERIFIED.
-- A township belongs here when the city's fire department is the primary service
-- provider for that area; adding it to the township weight pool overstates the
-- per-capita denominator and understates every rural VFD's share.
-- Seed statewide as packets roll out; currently seeded for Bartholomew.
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

-- KAN-129 input: verified county LIT base from the DLGF Certified LIT Report.
CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.DLGF_LIT_CERTIFIED (
    county_number          VARCHAR,
    county_name            VARCHAR,
    report_year            VARCHAR,
    lit_rate_pct           FLOAT,
    certified_distribution NUMBER,
    agi_base_reported      NUMBER,
    source_url             VARCHAR,
    notes                  VARCHAR
);

-- Output view: statutory fire/EMS LIT distribution by township, on a
-- verified county income base. Replaces the fire-levy-share method in
-- LIT_FIRE_RATE_PROJECTION (KAN-159) and the estimated base (KAN-129).
--
-- Simplification to document: the county denominator here sums township
-- subdivisions only, minus any township in LIT_FIRE_MUNICIPAL_EXCLUSIONS.
-- Excluded townships have their primary fire service provided by a city
-- department; including them in the weight pool overstates the denominator
-- and understates every rural VFD's share.
-- Where a county also has fire territories or fire districts as statutory
-- recipients, those would further dilute each township's slice; refine
-- the denominator when recipient rosters are loaded.
-- KAN-164: county_number + township_number exposed so downstream joins use
-- DLGF codes, never township name strings (which silently drop on DLGF/Census
-- spelling mismatches like "HAWCREEK TOWNSHIP" vs "Haw Creek township").
-- KAN-169: municipal exclusion now enforced via LIT_FIRE_MUNICIPAL_EXCLUSIONS.
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


-- ============================================================
-- LIT_GAP_CLOSING_RATE  (KAN-169 Section 2a)
-- Per (county, township, phase_year): projected income, cost,
-- gap, and the county LIT rate required to close that gap.
-- County-level rollup: binding township (highest required rate)
-- and the binding rate for the full-phase-in year.
--
-- Gap formula: max(0, projected_cost - (dist_2025 - sea1_loss))
-- Rate formula: gap / rev_0_4pct × 0.4
--   where rev_0_4pct is Harrison's (or any township's) revenue
--   at the statutory 0.4% cap — used as the denominator to
--   normalize the required rate.
--
-- Grain: one row per (county_number, township_number, phase_year)
-- for phase_years 2026-2031, where cost data is available.
--
-- Three-tier framing per KAN-169 Section 1:
--   tier_label = 'OFFSET'        — rate just undoes SEA-1 loss
--   tier_label = 'COST_TRACKING' — rate keeps income ≥ cost
--   tier_label = 'CAP'           — statutory 0.4% max
-- The binding township row at the full-phase year (2031) drives
-- the county ask; all other tiers are reference values.
--
-- Tickets: KAN-169 (spec Section 2a), depends on KAN-169 2b
-- (FIRE_COST_TREND extended to 2031).
-- ============================================================
CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.LIT_GAP_CLOSING_RATE AS
WITH dist AS (
  SELECT county_cd AS county_number, unit_cd AS township_number,
         SUM(amt_num) AS dist_2025
  FROM HOOSIER_DATA.ANALYTICS.TAX_DISTRIBUTIONS_CLEAN
  WHERE yr_nbr = '2025'
    AND entity_cd IN ('1111','1105','1190','8604','8692','8704','8792')
  GROUP BY 1, 2
),
summary AS (
  SELECT county_number, township_number, township_name,
         phase_year, total_sea1_loss, projected_operating_cost,
         cost_confidence
  FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY
  WHERE phase_year BETWEEN 2026 AND 2031
    AND projected_operating_cost IS NOT NULL
),
lit AS (
  SELECT county_number, township_number, rev_0_4pct
  FROM HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED
),
sea1_offset_rate AS (
  -- The SEA-1 offset rate: smallest rate that just recovers the SEA-1 loss.
  -- Uses total_sea1_loss at full phase-in (2031) as the fixed numerator.
  SELECT county_number, township_number,
         MAX(CASE WHEN phase_year = 2031 THEN total_sea1_loss END) AS sea1_loss_2031
  FROM summary
  GROUP BY 1, 2
),
per_twp AS (
  SELECT
    s.county_number,
    s.township_number,
    s.township_name,
    s.phase_year,
    d.dist_2025,
    s.total_sea1_loss                                             AS sea1_loss,
    GREATEST(d.dist_2025 - s.total_sea1_loss, 0)                 AS net_income_no_lit,
    s.projected_operating_cost                                    AS projected_cost,
    GREATEST(s.projected_operating_cost
             - GREATEST(d.dist_2025 - s.total_sea1_loss, 0), 0)  AS gap,
    l.rev_0_4pct,
    CASE
      WHEN s.cost_confidence = 'OK' AND l.rev_0_4pct > 0
      THEN ROUND(
             GREATEST(s.projected_operating_cost
                      - GREATEST(d.dist_2025 - s.total_sea1_loss, 0), 0)
             / l.rev_0_4pct * 0.4,
             4)
    END                                                           AS req_rate_pct,
    -- SEA-1 offset rate (constant across years; derived from 2031 full loss)
    CASE
      WHEN l.rev_0_4pct > 0
      THEN ROUND(COALESCE(o.sea1_loss_2031, 0) / l.rev_0_4pct * 0.4, 4)
    END                                                           AS sea1_offset_rate_pct,
    s.cost_confidence
  FROM summary s
  LEFT JOIN dist    d ON d.county_number = s.county_number
                     AND d.township_number = s.township_number
  LEFT JOIN lit     l ON l.county_number = s.county_number
                     AND l.township_number = s.township_number
  LEFT JOIN sea1_offset_rate o ON o.county_number = s.county_number
                               AND o.township_number = s.township_number
)
SELECT
    pt.county_number,
    pt.township_number,
    pt.township_name,
    pt.phase_year,
    ROUND(pt.dist_2025)          AS dist_2025,
    ROUND(pt.sea1_loss)          AS sea1_loss,
    ROUND(pt.net_income_no_lit)  AS net_income_no_lit,
    ROUND(pt.projected_cost)     AS projected_cost,
    ROUND(pt.gap)                AS gap,
    pt.rev_0_4pct,
    pt.req_rate_pct              AS cost_tracking_rate_pct,
    pt.sea1_offset_rate_pct,
    0.4                          AS cap_rate_pct,
    pt.cost_confidence,
    -- County-level binding values (2031 only; NULL for other years)
    CASE WHEN pt.phase_year = 2031
         THEN MAX(pt.req_rate_pct) OVER (PARTITION BY pt.county_number)
    END                          AS county_binding_rate_pct,
    CASE WHEN pt.phase_year = 2031
         THEN MAX_BY(pt.township_name, pt.req_rate_pct)
                  OVER (PARTITION BY pt.county_number)
    END                          AS county_binding_township
FROM per_twp pt
ORDER BY pt.county_number, pt.township_number, pt.phase_year;
