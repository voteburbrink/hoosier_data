-- KAN-182: Geography bridge — Indiana place/city -> DLGF county_number.
-- Lets IVFA departments (keyed by city) reconcile to DLGF fire-funding units
-- (keyed by county). All VARCHAR; RAW lands exactly as built.
-- Tables use CREATE TABLE IF NOT EXISTS (never OR REPLACE - June 5 2026 wipe).
--
-- Two tables:
--   PLACE_COUNTY_XWALK         — authoritative, from Census TIGER geometry
--                                (scripts/build_place_county_xwalk.py).
--                                Multi-county places carry every county they
--                                overlap >=2% by area; is_primary marks the
--                                largest. ~976 places / ~1010 rows.
--   IVFA_CITY_COUNTY_SUPPLEMENT — the ~23 IVFA cities that are NOT Census places
--                                (small unincorporated communities + IVFA
--                                spelling variants), resolved via USGS GNIS and
--                                aliases. confidence='verify' = ambiguous name
--                                (duplicate across counties) set from the IVFA
--                                department's township context — confirm these.

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.PLACE_COUNTY_XWALK (
    place_geoid       VARCHAR,
    place_name        VARCHAR,
    place_namelsad    VARCHAR,
    county_name       VARCHAR,
    county_number     VARCHAR,   -- DLGF alphabetical (not FIPS)
    overlap_pct       VARCHAR,
    is_primary        VARCHAR,
    is_multi_county   VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_CITY_COUNTY_SUPPLEMENT (
    city_norm         VARCHAR,
    county_name       VARCHAR,
    county_number     VARCHAR,
    method            VARCHAR,
    confidence        VARCHAR    -- 'high' | 'verify' (ambiguous, confirm)
);

-- Loaded by scripts/load_snowflake_place_county.py (PUT + COPY for both).
-- These are full-snapshot reference tables: the loader TRUNCATEs before COPY.
