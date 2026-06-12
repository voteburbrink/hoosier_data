-- ============================================================
-- SEA1_FIRE_IMPACT_BY_COUNTY
-- County-level rollup of SEA-1 fire fund impact.
--
-- Grain: one row per county. Aggregates SEA1_FIRE_IMPACT_SUMMARY
-- (phase_year = 2031, full-phase-in), 2025 fire distributions, verified
-- LIT revenue splits, and an interim 2031 cost projection.
--
-- Provenance flags (printed in provenance_note column):
--   BPP_LOSS      ESTIMATED — SEA1_BPP_LOSS uses 2024 FORM4B rates;
--                 reconcile to 2026 certified rates before citing externally.
--                 Bartholomew: $72,342 view vs $110,999 verified (35% gap).
--   HOMESTEAD/2PCT VERIFIED (KAN-171 2026-06-12) — IC 6-1.1-12-37/37.5 per SEA 1 s44/s45; IC 6-1.1-12-47 per SEA 1 s52.
--   GAP RATE      MODELED — cost_2031 is interim (see cost31 CTE note).
--
-- cost_2031: reads projected_operating_cost from SEA1_FIRE_IMPACT_SUMMARY at
-- phase_year = 2031, which draws from FIRE_COST_TREND PROJ_2031 (KAN-169 2b).
--
-- Spot-checks (Bartholomew, validated 2026-06-12, query 01c5014a-0105-dd6c-000d-a8fe00517072):
--   lit_rev_at_cap  = ROUND(county_agi_base * 0.004)  -- $13,340,683 (unchanged)
--   sea1_loss_full_phase = 383,157 (KAN-171: corrected from 656,417 with wrong homestead params)
--   binding_township = 'OHIO TOWNSHIP'
--   binding_rate_pct ~0.165 (KAN-171: was 0.167; KAN-169 fixed from 0.402 at cap)
--   fire_dist_2025_total short of levy table by exactly Clay delta ($57,017);
--     Clay fund-structure check pending (KAN-169 Section 2e).
-- NOTE: binding_rate_pct and all per-township req_rate figures require revalidation
-- after deploy — pending warehouse quota restore.
--
-- NOTE: HD rows in SEA1_FIRE_IMPACT_BY_HD are NOT summable to these county
-- totals — split townships appear in multiple HDs.
--
-- Tickets: KAN-167 (spec), KAN-169 (worked solution, Section 6.2)
-- ============================================================

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_COUNTY AS
WITH loss AS (
  SELECT county_number, MAX(county_description) AS county_name,
         COUNT(DISTINCT township_number)                                  AS township_fire_units,
         SUM(fire_levy_2024)                                              AS fire_levy_2024_total,
         SUM(bpp_loss)                                                    AS bpp_loss_total,
         -- ESTIMATED until SEA1_BPP_LOSS moves to 2026 certified rates (KAN-169 6.1.3)
         SUM(homestead_loss)                                              AS homestead_loss_total,
         -- ESTIMATED (KAN-138 params)
         SUM(two_pct_loss)                                                AS two_pct_loss_total,
         -- ESTIMATED (KAN-141 params)
         SUM(total_sea1_loss)                                             AS sea1_loss_full_phase,
         SUM(CASE WHEN cost_confidence = 'OK' THEN 1 ELSE 0 END)         AS cost_ok_units
  FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY
  WHERE phase_year = 2031
  GROUP BY county_number
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
),
twp_gap AS (
  SELECT d.county_number, d.township_number, s.township_name, d.dist_2025,
         CASE
           WHEN s.cost_confidence = 'OK' AND l.rev_0_4pct > 0
           THEN GREATEST(s.projected_operating_cost - (d.dist_2025 - s.total_sea1_loss), 0)
                / l.rev_0_4pct * 0.4
         END AS req_rate_pct
  FROM dist d
  JOIN HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY s
    ON s.county_number = d.county_number
   AND s.township_number = d.township_number
   AND s.phase_year = 2031
  LEFT JOIN lit l
    ON l.county_number = d.county_number AND l.township_number = d.township_number
),
binding AS (
  SELECT county_number,
         SUM(dist_2025)                       AS dist_2025_total,
         MAX(req_rate_pct)                    AS binding_rate_pct,
         MAX_BY(township_name, req_rate_pct)  AS binding_township
  FROM twp_gap
  GROUP BY county_number
),
lit_cty AS (
  SELECT county_number,
         MAX(agi)          AS county_agi_base,
         SUM(rev_0_4pct)   AS lit_rev_at_cap
  FROM lit
  GROUP BY 1
)
SELECT
    lo.county_number,
    lo.county_name,
    lo.township_fire_units,
    lo.cost_ok_units,
    lo.fire_levy_2024_total,
    b.dist_2025_total                         AS fire_dist_2025_total,
    lo.bpp_loss_total,
    lo.homestead_loss_total,
    lo.two_pct_loss_total,
    lo.sea1_loss_full_phase,
    lc.county_agi_base,
    lc.lit_rev_at_cap,
    b.binding_township,
    b.binding_rate_pct,
    'BPP=ESTIMATED until 2026-rate reconciliation; HOMESTEAD/2PCT=VERIFIED (KAN-171); GAP RATE=MODELED'
        AS provenance_note
FROM loss lo
LEFT JOIN binding  b  ON b.county_number  = lo.county_number
LEFT JOIN lit_cty  lc ON lc.county_number = lo.county_number;
