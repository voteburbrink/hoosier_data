-- ============================================================
-- Validation assertions for SEA1_FIRE_IMPACT_BY_COUNTY and
-- SEA1_FIRE_IMPACT_BY_HD.
--
-- Run after deploying both views. All assertions should return zero rows.
-- Re-run after swapping the cost31 CTE to PROJ_2031 (KAN-169 Section 6.4.4).
--
-- Validated 2026-06-12 against live warehouse. Query IDs:
--   county view  01c5014a-0105-dd6c-000d-a8fe00517072
--   HD view      01c5014c-0105-e30f-000d-a8fe0050b13a
--   xwalk grain  01c5014b-0105-e794-000d-a8fe0052100e
--                01c5014c-0105-e61a-000d-a8fe0051f032
-- ============================================================


-- 1. Xwalk grain assertion: confirm known duplicate count.
--    Expected: total_rows=1183, distinct_hd_keys=1122, duplicate_hd_keys=61
SELECT
    COUNT(*)                                                                AS total_rows,
    COUNT(DISTINCT county_number || '|' || township_number || '|' || house_district)
                                                                            AS distinct_hd_keys,
    COUNT(*) - COUNT(DISTINCT county_number || '|' || township_number || '|' || house_district)
                                                                            AS duplicate_hd_keys
FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK;
-- If duplicate_hd_keys = 0 the xwalk has been corrected; remove the DISTINCT
-- from xwalk_hd CTE and this note from both view headers.


-- 2. County view — Bartholomew spot-checks (all should return 'PASS').
--    Single scan via CTE; four UNION ALL branches would re-execute the full view each time.
WITH bart AS (
  SELECT * FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_COUNTY
  WHERE county_name ILIKE '%BARTHOLOMEW%'
)
SELECT 'lit_rev_at_cap matches 0.4% of AGI'      AS assertion,
       CASE WHEN ABS(lit_rev_at_cap - ROUND(county_agi_base * 0.004)) <= 1
            THEN 'PASS' ELSE 'FAIL' END           AS result,
       lit_rev_at_cap::VARCHAR                    AS actual,
       ROUND(county_agi_base * 0.004)::VARCHAR    AS expected
FROM bart
UNION ALL
SELECT 'sea1_loss_full_phase within $1 of 656417',
       CASE WHEN ABS(sea1_loss_full_phase - 656417) <= 1 THEN 'PASS' ELSE 'FAIL' END,
       sea1_loss_full_phase::VARCHAR, '656417'
FROM bart
UNION ALL
SELECT 'binding_township = OHIO TOWNSHIP',
       CASE WHEN binding_township ILIKE '%OHIO%' THEN 'PASS' ELSE 'FAIL' END,
       binding_township, NULL
FROM bart
UNION ALL
SELECT 'binding_rate_pct at cap (0.400-0.402)',
       CASE WHEN binding_rate_pct BETWEEN 0.400 AND 0.402 THEN 'PASS' ELSE 'FAIL' END,
       binding_rate_pct::VARCHAR, '0.402'
FROM bart;


-- 3. HD view — HD-059 spot-checks (all should return 'PASS').
SELECT
    'HD-059 fire_units = 6' AS assertion,
    CASE WHEN fire_units = 6 THEN 'PASS' ELSE 'FAIL' END AS result,
    fire_units, 6 AS expected
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD
WHERE house_district = 'HD-059'

UNION ALL

SELECT
    'HD-059 counties = 1' AS assertion,
    CASE WHEN counties = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
    counties, 1
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD
WHERE house_district = 'HD-059'

UNION ALL

SELECT
    'HD-059 split_townships = 1' AS assertion,
    CASE WHEN split_townships = 1 THEN 'PASS' ELSE 'FAIL' END AS result,
    split_townships, 1
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD
WHERE house_district = 'HD-059'

UNION ALL

SELECT
    'HD-059 sea1_loss within $1 of 564276' AS assertion,
    CASE WHEN ABS(sea1_loss_full_phase - 564276) <= 1
         THEN 'PASS' ELSE 'FAIL' END AS result,
    sea1_loss_full_phase, 564276
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD
WHERE house_district = 'HD-059'

UNION ALL

SELECT
    'HD-059 binding = OHIO TOWNSHIP' AS assertion,
    CASE WHEN binding_township ILIKE '%OHIO%' THEN 'PASS' ELSE 'FAIL' END AS result,
    NULL, NULL
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD
WHERE house_district = 'HD-059'

UNION ALL

SELECT
    'HD-082 fire_units = 4 (post-dedup)' AS assertion,
    CASE WHEN fire_units = 4 THEN 'PASS' ELSE 'FAIL' END AS result,
    fire_units, 4
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_BY_HD
WHERE house_district = 'HD-082';
