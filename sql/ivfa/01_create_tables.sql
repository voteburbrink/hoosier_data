-- KAN-182: IVFA volunteer fire department directory (statewide ground truth).
-- RAW lands exactly as downloaded — all VARCHAR, no casting, no cleanup here.
-- Table uses CREATE TABLE IF NOT EXISTS (never OR REPLACE - June 5 2026 wipe).
--
-- Source: ivfa.org department directory, pulled 2026-06-12 (firedata/).
-- Grain: one row per station as listed by IVFA (827 rows). Multi-station
--   departments (e.g. Otter Creek Twp. Station 1/2/3) appear as multiple rows;
--   the ANALYTICS view rolls these to department grain for the acceptance test.
-- Provenance: as_of_date is carried in the file so re-pulls SNAPSHOT rather than
--   clobber. Future loads should append a new as_of_date, not overwrite.
--
-- Three documented limitations (constraints, not surprises):
--   1. No county column. County must be derived from city downstream; cities
--      that span counties must be flagged, never silently assigned.
--   2. name_pattern is a HINT only (IVFA naming, not a funding fact). Never let
--      it drive classifier logic — Marengo-Liberty is the proof that names lie.
--   3. IVFA is membership-based: PRESENCE is signal, ABSENCE proves nothing.
--      Do not treat "not in IVFA" as "not a fire department."

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_DEPARTMENTS_SOURCE (
    dept_name                   VARCHAR,
    city                        VARCHAR,
    name_pattern                VARCHAR,  -- HINT only: TOWNSHIP_NAMED|TERRITORY|DISTRICT|OTHER
    nonfire_or_industrial_flag  VARCHAR,  -- 'Y' = EMS/plant brigade/haz-mat/career center/retirees
    source                      VARCHAR,
    as_of_date                  VARCHAR   -- snapshot date; part of the natural key
);
