-- ============================================================
-- SEA1_FIRE_IMPACT_BY_HD
-- House-district-level rollup of SEA-1 fire fund impact.
--
-- Grain: one row per house district. Joins SEA1_FIRE_IMPACT_SUMMARY
-- (phase_year = 2031) to the legislative district crosswalk.
--
-- CRITICAL: xwalk grain is (county, township, HD, SD) — 61 duplicate HD
-- keys exist for multi-SD split townships (Allen Wayne Twp has 4 rows in
-- HD-082, one per SD; verified query 01c5014c-0105-e61a-000d-a8fe0051f032).
-- The xwalk_hd CTE deduplicates with SELECT DISTINCT on (county, township,
-- HD) before all joins. Without this dedup, Allen HD-082 would show 10
-- unit-rows instead of 4.
--
-- Split-township counting rule (per KAN-167 spec): split townships count
-- fully in each HD they touch. Consequence: HD rows are NOT summable to
-- county or state totals — split townships and their LIT shares appear in
-- multiple HDs. Document this in any dashboard that uses this view.
--
-- cost_2031: reads projected_operating_cost from SEA1_FIRE_IMPACT_SUMMARY at
-- phase_year = 2031, which draws from FIRE_COST_TREND PROJ_2031 (KAN-169 2b).
--
-- Spot-checks (validated 2026-06-12, query 01c5014c-0105-e30f-000d-a8fe0050b13a):
--   HD-059: fire_units=6, counties=1, split_townships=1 (Wayne), loss=$564,276,
--            binding=OHIO TOWNSHIP, binding_rate_pct~0.167 (was 0.402; changed by KAN-169 fix)
--   HD-069: 16 units, 4 counties, binding Monroe 0.249%
--   HD-073: 18 units, 4 counties, binding Noble 0.162%
--   HD-080: 3 units (post-dedup), HD-082: 4 units (post-dedup)
--
-- Xwalk grain assertion: COUNT(*) from RAW.LEGISLATIVE_DISTRICT_XWALK
--   should equal 1,183; COUNT(DISTINCT county_number, township_number,
--   house_district) should equal 1,122 (61 duplicate HD keys confirmed).
--
-- Tickets: KAN-167 (spec), KAN-169 (worked solution, Section 6.3)
-- ============================================================

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD AS
WITH xwalk_hd AS (
  -- MANDATORY dedup: xwalk grain is (county, township, HD, SD).
  -- Any HD aggregation must collapse here first. See header note and
  -- KAN-169 Section 6.1.1 for the full defect description.
  SELECT DISTINCT county_number, township_number, house_district, is_split
  FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK
),
dist AS (
  -- Join key: county_cd = county_number, unit_cd = township_number (verified
  -- query 01c50149-0105-e30f-000d-a8fe0050b132; do not parse the prefixed UNIT name).
  SELECT county_cd AS county_number, unit_cd AS township_number,
         SUM(amt_num) AS dist_2025
  FROM HOOSIER_DATA.ANALYTICS.TAX_DISTRIBUTIONS_CLEAN
  WHERE yr_nbr = '2025'
    AND entity_cd IN ('1111','1105','1190','8604','8692','8704','8792')
  GROUP BY 1, 2
),
lit AS (
  SELECT county_number, township_number,
         MAX(county_agi_base) AS agi,
         SUM(rev_0_4pct)      AS rev_0_4pct
  FROM HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED
  GROUP BY 1, 2
)
SELECT
    x.house_district,
    COUNT(*)                                                               AS fire_units,
    COUNT(DISTINCT s.county_number)                                        AS counties,
    SUM(CASE WHEN x.is_split = 'true' THEN 1 ELSE 0 END)                  AS split_townships,
    SUM(s.fire_levy_2024)                                                  AS fire_levy_2024_total,
    SUM(d.dist_2025)                                                       AS fire_dist_2025_total,
    SUM(s.total_sea1_loss)                                                 AS sea1_loss_full_phase,
    SUM(l.rev_0_4pct)                                                      AS lit_rev_at_cap_hd_share,
    MAX_BY(
        s.township_name,
        CASE
          WHEN s.cost_confidence = 'OK' AND l.rev_0_4pct > 0
          THEN GREATEST(s.projected_operating_cost - (d.dist_2025 - s.total_sea1_loss), 0)
               / l.rev_0_4pct * 0.4
        END
    )                                                                      AS binding_township,
    MAX(
        CASE
          WHEN s.cost_confidence = 'OK' AND l.rev_0_4pct > 0
          THEN GREATEST(s.projected_operating_cost - (d.dist_2025 - s.total_sea1_loss), 0)
               / l.rev_0_4pct * 0.4
        END
    )                                                                      AS binding_rate_pct
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY s
JOIN xwalk_hd x
  ON x.county_number  = s.county_number
 AND x.township_number = s.township_number
LEFT JOIN dist d
  ON d.county_number  = s.county_number AND d.township_number = s.township_number
LEFT JOIN lit l
  ON l.county_number  = s.county_number AND l.township_number = s.township_number
WHERE s.phase_year = 2031
GROUP BY x.house_district;
