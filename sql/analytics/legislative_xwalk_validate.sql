-- ============================================================
-- LEGISLATIVE_DISTRICT_XWALK validation (KAN-158)
-- Run after scripts/load_snowflake_xwalk.py.
-- Built from the current 2021-plan / 123rd GA districts (the map SEA-1's 2025
-- voters sit in), so values reflect CURRENT incumbents — not the pre-2022 map.
-- ============================================================

-- 1. Coverage: expect 1,002 townships / 92 counties / 100 House / 50 Senate
SELECT
    COUNT(*)                                              AS row_count,
    COUNT(DISTINCT county_number || township_number)      AS townships,
    COUNT(DISTINCT county_number)                         AS counties,
    COUNT(DISTINCT house_district)                        AS house_districts,
    COUNT(DISTINCT senate_district)                       AS senate_districts,
    SUM(CASE WHEN is_split = 'true' THEN 1 ELSE 0 END)    AS split_rows
FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK;

-- 2. ACCEPTANCE — Bartholomew County (county_number = '03'), all 12 townships.
--    Verified current expectation: every township SD-41; House in {59,69,73};
--    Wayne split HD-59/HD-69; Columbus = HD-59 (not split).
SELECT township_number, township_name, house_district, senate_district,
       congressional_district, is_split, precinct_count
FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK
WHERE county_number = '03'
ORDER BY township_name, house_district;

-- 3. Bartholomew must be 100% SD-41 (expect a single row: SD-041)
SELECT DISTINCT senate_district
FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK
WHERE county_number = '03';

-- 4. Referential integrity: every house_district / senate_district in the
--    crosswalk should exist in LEGISCAN_PEOPLE.district (same 'HD-0NN' format).
--    Expect zero rows returned.
WITH x AS (
    SELECT DISTINCT house_district AS d FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK
    UNION
    SELECT DISTINCT senate_district FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK
)
SELECT x.d AS district_missing_from_legiscan_people
FROM x
LEFT JOIN (SELECT DISTINCT district FROM HOOSIER_DATA.RAW.LEGISCAN_PEOPLE) p
       ON p.district = x.d
WHERE p.district IS NULL;

-- 5. Packet driver: unique House+Senate district pairs per county, with the
--    townships that fall in each pair (one VFD brief per pair).
SELECT county_number, county_name, house_district, senate_district,
       LISTAGG(township_name, ', ') WITHIN GROUP (ORDER BY township_name) AS townships,
       MAX(is_split) AS any_split
FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK
GROUP BY county_number, county_name, house_district, senate_district
ORDER BY county_number, house_district, senate_district;

-- 6. Bartholomew incumbents + their SEA-1 House final-passage votes (sanity for
--    the KAN-157 packet). House roll_call_id 1543337; SELECT DISTINCT required
--    (LEGISCAN_VOTES has duplicate rows from the KAN-142 reload).
SELECT DISTINCT x.house_district, p.name AS representative, p.party, v.vote_desc
FROM HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK x
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE p ON p.district = x.house_district
LEFT JOIN HOOSIER_DATA.RAW.LEGISCAN_VOTES v
       ON v.people_id = p.people_id AND v.roll_call_id = '1543337'
WHERE x.county_number = '03'
ORDER BY x.house_district;
