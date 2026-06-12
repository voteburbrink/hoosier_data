-- ============================================================
-- KAN-153/154/155/156 — Validation / acceptance checks
-- Run after Steps 1-3. Read-only; safe to run anytime.
-- ============================================================

-- 1. Crosswalk loaded statewide (expect ~53k rows/yr, 92 counties) ────────────
SELECT budget_year, COUNT(*) AS rows,
       COUNT(DISTINCT county_number) AS counties,
       COUNT(DISTINCT CASE WHEN unit_type_cd='4' THEN unit_code END) AS school_codes,
       COUNT(DISTINCT CASE WHEN unit_type_cd='5' THEN unit_code END) AS library_codes
FROM HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS
GROUP BY budget_year ORDER BY budget_year;

-- 2. All 288 school corps + 237 libraries appear in the impact views ──────────
SELECT 'schools' AS unit, COUNT(DISTINCT county_number||school_corp_name) AS n
FROM HOOSIER_DATA.ANALYTICS.SEA1_SCHOOL_IMPACT
UNION ALL
SELECT 'libraries', COUNT(DISTINCT county_number||library_name)
FROM HOOSIER_DATA.ANALYTICS.SEA1_LIBRARY_IMPACT;

-- 3. Bartholomew sanity: BCSC 2026 vs 2031 (expect ~$4.67M → ~$6.36M total) ───
SELECT school_corp_name, phase_year, ops_rate_per_100,
       bpp_loss, homestead_loss, two_pct_loss, total_sea1_loss
FROM HOOSIER_DATA.ANALYTICS.SEA1_SCHOOL_IMPACT
WHERE county_number='03' AND phase_year IN (2026,2031)
ORDER BY school_corp_name, phase_year;

-- 4. THE PACKET — full Bartholomew community impact at 2031 ────────────────────
--    Fire + every school corp + every library, biggest first.
SELECT unit_type, unit_name, total_sea1_loss,
       bpp_loss, homestead_loss, two_pct_loss
FROM HOOSIER_DATA.ANALYTICS.SEA1_EDUCATION_SUMMARY
WHERE county_number='03' AND phase_year=2031
ORDER BY total_sea1_loss DESC;

-- 5. THE HEADLINE — total SEA-1 burden on Bartholomew, year by year ───────────
SELECT phase_year,
       ROUND(SUM(CASE WHEN unit_type='FIRE'    THEN total_sea1_loss END)) AS fire,
       ROUND(SUM(CASE WHEN unit_type='SCHOOL'  THEN total_sea1_loss END)) AS schools,
       ROUND(SUM(CASE WHEN unit_type='LIBRARY' THEN total_sea1_loss END)) AS libraries,
       ROUND(SUM(total_sea1_loss))                                        AS total_community_impact
FROM HOOSIER_DATA.ANALYTICS.SEA1_EDUCATION_SUMMARY
WHERE county_number='03'
GROUP BY phase_year ORDER BY phase_year;
