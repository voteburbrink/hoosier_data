-- KAN-182: County-resolved IVFA departments. Safe to CREATE OR REPLACE (view).
-- Adds DLGF county_number to ANALYTICS.IVFA_DEPARTMENTS via the geography bridge.
-- Validated: all 782 departments resolve to exactly one county, zero fan-out.
--
-- Resolution priority (first non-null wins):
--   1. override   — 7 cities whose name collides with a same-named CDP in another
--                   county; disambiguated from the IVFA department context.
--   2. supplement — RAW.IVFA_CITY_COUNTY_SUPPLEMENT (non-Census-place cities).
--   3. place      — RAW.PLACE_COUNTY_XWALK primary, on normalized name.
--   4. place_despaced — spacing-variant fallback (e.g. "Laporte" vs "La Porte").
--
-- City normalization is applied identically to both sides (IVFA city and TIGER
-- place_name): uppercase; drop . , ( ); strip trailing state " IN"; expand
-- Ft/St/Mt/N/S/E/W/Hts/Shrs/Indpls; collapse spaces; strip trailing CITY/TOWN/
-- BALANCE tokens (symmetric, so name-component "City" matches on both sides).

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.IVFA_DEPARTMENTS_GEO AS
WITH ivfa AS (
  SELECT dept_name, city, name_pattern_hint, station_count, dept_norm, as_of_date,
    TRIM(REGEXP_REPLACE(TRIM(REGEXP_REPLACE(
      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        REGEXP_REPLACE(' '||REGEXP_REPLACE(UPPER(city),'[.,()]',' ')||' ',' IN $',' '),
        ' FT ',' FORT '),' ST ',' SAINT '),' MT ',' MOUNT '),' N ',' NORTH '),' S ',' SOUTH '),
        ' E ',' EAST '),' W ',' WEST '),' HTS ',' HEIGHTS '),' SHRS ',' SHORES '),
        ' INDPLS ',' INDIANAPOLIS '),' +',' ')),'( (CITY|TOWN|BALANCE))+$','')) AS cnorm
  FROM HOOSIER_DATA.ANALYTICS.IVFA_DEPARTMENTS
),
plc AS (
  SELECT county_number, county_name,
    TRIM(REGEXP_REPLACE(TRIM(REGEXP_REPLACE(
      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        REGEXP_REPLACE(' '||REGEXP_REPLACE(UPPER(place_name),'[.,()]',' ')||' ',' IN $',' '),
        ' FT ',' FORT '),' ST ',' SAINT '),' MT ',' MOUNT '),' N ',' NORTH '),' S ',' SOUTH '),
        ' E ',' EAST '),' W ',' WEST '),' HTS ',' HEIGHTS '),' SHRS ',' SHORES '),
        ' INDPLS ',' INDIANAPOLIS '),' +',' ')),'( (CITY|TOWN|BALANCE))+$','')) AS pnorm
  FROM HOOSIER_DATA.RAW.PLACE_COUNTY_XWALK WHERE is_primary='True'
),
-- County dimension (number -> name) derived from the loaded crosswalk.
cdim AS (SELECT DISTINCT county_number, county_name FROM HOOSIER_DATA.RAW.PLACE_COUNTY_XWALK),
-- Ambiguous cities (name collides with a same-named CDP elsewhere), resolved
-- from the IVFA department context. Geneva=Adams, Highland=Lake (town),
-- Marion=Grant (county seat), Middlebury=Elkhart, Milford=Kosciusko,
-- Monroe=Adams (town), Monroe City=Knox.
ovr(city, county_number) AS (
  SELECT * FROM VALUES ('Geneva','01'),('Highland','45'),('Marion','27'),
    ('Middlebury','20'),('Milford','43'),('Monroe','01'),('Monroe City','42')
)
SELECT
  i.dept_name, i.city, i.name_pattern_hint, i.station_count, i.dept_norm, i.as_of_date,
  COALESCE(o.county_number, s.county_number, p.county_number, pd.county_number) AS county_number,
  cd.county_name,
  CASE WHEN o.county_number IS NOT NULL THEN 'override'
       WHEN s.county_number IS NOT NULL THEN 'supplement'
       WHEN p.county_number IS NOT NULL THEN 'place'
       WHEN pd.county_number IS NOT NULL THEN 'place_despaced' END AS county_resolution
FROM ivfa i
LEFT JOIN ovr o ON o.city = i.city
LEFT JOIN HOOSIER_DATA.RAW.IVFA_CITY_COUNTY_SUPPLEMENT s
       ON s.city_norm = i.cnorm AND o.county_number IS NULL
LEFT JOIN plc p
       ON p.pnorm = i.cnorm AND o.county_number IS NULL AND s.county_number IS NULL
LEFT JOIN plc pd
       ON REPLACE(pd.pnorm,' ','') = REPLACE(i.cnorm,' ','')
      AND o.county_number IS NULL AND s.county_number IS NULL AND p.county_number IS NULL
LEFT JOIN cdim cd
       ON cd.county_number = COALESCE(o.county_number, s.county_number, p.county_number, pd.county_number);
