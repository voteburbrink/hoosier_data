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
    data_vintage      VARCHAR
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
-- subdivisions only. Where a county also has fire territories, fire
-- districts, or municipal departments as statutory recipients, those would
-- share the pool too and dilute each township's slice. This view models the
-- township-VFD allocation; refine the denominator when recipient rosters
-- are loaded.
CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED AS
WITH twp AS (
    SELECT UPPER(county_name) AS county_u,
           county_name,
           township_name,
           population_2020,
           land_sqmi,
           COALESCE(population_2020, 0) + COALESCE(land_sqmi, 0) * 20
               AS statutory_weight
    FROM HOOSIER_DATA.RAW.TOWNSHIP_POP_AREA
    WHERE subdivision_type = 'township'
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
SELECT t.county_name,
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
