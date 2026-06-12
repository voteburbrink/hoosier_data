-- KAN-163 / KAN-165: Statewide county fire impact ranking (2031, fully phased).
-- Combines township impact (SEA1_FIRE_IMPACT_SUMMARY) and district impact
-- (SEA1_FIRE_DISTRICT_IMPACT). County_number is DLGF alphabetical (not FIPS).
--
-- Rural/VFD filter: counties with zero township AND district fire levy are excluded
-- (pure city-fire areas where neither townships nor districts levy independently).
-- Marion remains #1 due to fire territories; apply an additional rural filter
-- if needed (e.g. WHERE county_number NOT IN ('49') for Marion).
--
-- Columns:
--   twp_loss  / dist_loss     — SEA-1 loss from township / district units at 2031
--   total_fire_levy           — combined 2024/2025 baseline levy
--   lit_rev_0_Xpct            — projected LIT revenue at X% rate (township share only)

WITH twp AS (
    SELECT county_number,
           MAX(county_description)         AS county_description,
           SUM(total_sea1_loss)            AS twp_sea1_loss,
           SUM(COALESCE(fire_levy_2024,0)) AS twp_fire_levy
    FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY
    WHERE phase_year = 2031
    GROUP BY county_number
),
dist AS (
    SELECT county_number,
           SUM(total_sea1_loss)            AS dist_sea1_loss,
           SUM(COALESCE(fire_levy_2025,0)) AS dist_fire_levy,
           COUNT(DISTINCT unit_code)       AS fire_districts
    FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_DISTRICT_IMPACT
    WHERE phase_year = 2031
    GROUP BY county_number
),
lit AS (
    SELECT county_number,
           ROUND(SUM(rev_0_1pct)) AS lit_rev_0_1pct,
           ROUND(SUM(rev_0_2pct)) AS lit_rev_0_2pct,
           ROUND(SUM(rev_0_3pct)) AS lit_rev_0_3pct
    FROM HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED
    GROUP BY county_number
)
SELECT
    ROW_NUMBER() OVER (ORDER BY COALESCE(t.twp_sea1_loss,0)+COALESCE(d.dist_sea1_loss,0) DESC) AS rank,
    COALESCE(t.county_number, d.county_number)                          AS county_number,
    COALESCE(t.county_description, '')                                  AS county,
    s.fire_service_structure                                            AS structure,
    ROUND(COALESCE(t.twp_sea1_loss,0))                                  AS twp_loss,
    ROUND(COALESCE(d.dist_sea1_loss,0))                                 AS dist_loss,
    ROUND(COALESCE(t.twp_sea1_loss,0)+COALESCE(d.dist_sea1_loss,0))    AS total_loss,
    ROUND(COALESCE(t.twp_fire_levy,0)+COALESCE(d.dist_fire_levy,0))    AS total_fire_levy,
    COALESCE(d.fire_districts,0)                                        AS districts,
    l.lit_rev_0_1pct,
    l.lit_rev_0_2pct,
    l.lit_rev_0_3pct
FROM twp t
FULL OUTER JOIN dist d ON t.county_number = d.county_number
LEFT JOIN HOOSIER_DATA.ANALYTICS.COUNTY_FIRE_SERVICE_STRUCTURE s
    ON COALESCE(t.county_number, d.county_number) = s.county_number
LEFT JOIN lit l ON COALESCE(t.county_number, d.county_number) = l.county_number
WHERE COALESCE(t.twp_fire_levy,0)+COALESCE(d.dist_fire_levy,0) > 0
ORDER BY total_loss DESC;
