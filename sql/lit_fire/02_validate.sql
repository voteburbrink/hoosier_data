-- KAN-129 + KAN-159 validation. Run after both loads.

-- 1. Row counts and coverage.
SELECT 'TOWNSHIP_POP_AREA' AS tbl, COUNT(*) AS n_rows,
       COUNT(DISTINCT county_name) AS counties,
       SUM(CASE WHEN subdivision_type = 'township' THEN 1 ELSE 0 END) AS townships,
       SUM(CASE WHEN population_2020 IS NULL THEN 1 ELSE 0 END) AS null_pop,
       SUM(CASE WHEN land_sqmi IS NULL THEN 1 ELSE 0 END) AS null_area
FROM HOOSIER_DATA.RAW.TOWNSHIP_POP_AREA;

SELECT 'DLGF_LIT_CERTIFIED' AS tbl, COUNT(*) AS n_rows,
       COUNT(DISTINCT county_name) AS counties
FROM HOOSIER_DATA.RAW.DLGF_LIT_CERTIFIED;

-- 2. Bartholomew sanity check. AGI = total distribution / total rate.
--    2026 SBA data: $58,365,490 / 1.75% = $3.335B base; 0.025% = ~$833,793
--    (the 2025 analysis figure was ~$805,967 -- one year older, same method).
SELECT county_name, lit_rate_pct, certified_distribution,
       certified_distribution / (lit_rate_pct / 100)            AS county_agi_base,
       certified_distribution / (lit_rate_pct / 100) * 0.00025  AS rev_at_0_025pct
FROM HOOSIER_DATA.RAW.DLGF_LIT_CERTIFIED
WHERE UPPER(county_name) = 'BARTHOLOMEW';

-- 3. Statutory weights for Bartholomew townships (population + sqmi x 20)
--    and each township's share and projected revenue at 0.2/0.3/0.4%.
SELECT township_name, population_2020, land_sqmi,
       statutory_weight,
       ROUND(township_share, 4)  AS share,
       ROUND(rev_0_2pct)         AS rev_0_2pct,
       ROUND(rev_0_3pct)         AS rev_0_3pct,
       ROUND(rev_0_4pct)         AS rev_0_4pct
FROM HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED
WHERE UPPER(county_name) = 'BARTHOLOMEW'
ORDER BY statutory_weight DESC;

-- 4. Compare the new statutory shares against the old fire-levy-share method
--    (KAN-159 was filed because these differ).
SELECT v.township_name,
       ROUND(v.township_share, 4) AS statutory_share
FROM HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_VERIFIED v
WHERE UPPER(v.county_name) = 'BARTHOLOMEW'
ORDER BY v.township_share DESC;
