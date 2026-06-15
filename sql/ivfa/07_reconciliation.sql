-- KAN-182: Fire-funding classifier + IVFA reconciliation. CREATE OR REPLACE (views).
-- Apply 05 (bridge tables) and 06 (IVFA_DEPARTMENTS_GEO) first.
--
-- Acceptance test result (validated 2026, budget_year 2025):
--   All 92 counties have IVFA departments; ZERO counties have departments with
--   no fire-funding unit behind them. All 782 departments reconcile.
--
-- Grain note: the join is at COUNTY level (IVFA dept -> county via the bridge;
-- DLGF unit -> county). Department -> specific funded-unit (township-level)
-- matching is the next refinement; this view answers "does every county with
-- volunteer departments have a fire-funding mechanism" — and surfaces any that
-- do not as a classifier gap / real anomaly.

-- ── Classifier outcomes: DLGF fire-funding units --------------------------------
CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.FIRE_FUNDING_UNITS AS
SELECT
  county_number,
  unit_code,
  MAX(unit_name) AS unit_name,
  CASE
    WHEN unit_type_cd = '2' THEN 'township_fund'
    WHEN unit_type_cd = '3' THEN 'municipal'
    WHEN unit_type_cd = '6' AND MAX(unit_name) ILIKE '%TERRITOR%' THEN 'territory'
    WHEN unit_type_cd = '6' AND MAX(unit_name) ILIKE '%DIST%'     THEN 'district'
    WHEN unit_type_cd = '6'                                       THEN 'special_district_other'
    ELSE 'other'
  END AS funding_outcome,
  MAX(TRY_TO_DECIMAL(certd_tax_rate_pct, 12, 6)) AS max_certd_fire_rate
FROM HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS
WHERE budget_year = '2025'
  AND (fund_name ILIKE '%FIRE%' OR unit_name ILIKE '%FIRE%' OR unit_name ILIKE '%TERRITOR%')
  AND unit_type_cd IN ('2','3','6')
GROUP BY county_number, unit_code, unit_type_cd;

-- ── County-level reconciliation -------------------------------------------------
CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.IVFA_FUNDING_RECONCILIATION AS
WITH ivfa AS (
  SELECT county_number, MAX(county_name) AS county_name, COUNT(*) AS ivfa_depts
  FROM HOOSIER_DATA.ANALYTICS.IVFA_DEPARTMENTS_GEO
  GROUP BY county_number
),
fund AS (
  SELECT county_number,
    COUNT(*)                                                  AS funded_units,
    SUM(IFF(funding_outcome='township_fund',1,0))             AS township_funds,
    SUM(IFF(funding_outcome='municipal',1,0))                 AS municipal_units,
    SUM(IFF(funding_outcome='district',1,0))                  AS districts,
    SUM(IFF(funding_outcome='territory',1,0))                 AS territories,
    SUM(IFF(funding_outcome='special_district_other',1,0))    AS special_other
  FROM HOOSIER_DATA.ANALYTICS.FIRE_FUNDING_UNITS
  GROUP BY county_number
)
SELECT
  i.county_number, i.county_name, i.ivfa_depts,
  COALESCE(f.funded_units,0)   AS funded_units,
  COALESCE(f.township_funds,0) AS township_funds,
  COALESCE(f.municipal_units,0) AS municipal_units,
  COALESCE(f.districts,0)      AS districts,
  COALESCE(f.territories,0)    AS territories,
  COALESCE(f.special_other,0)  AS special_other,
  CASE WHEN COALESCE(f.funded_units,0) = 0 THEN 'GAP_no_fire_unit'
       ELSE 'OK' END           AS recon_status
FROM ivfa i
LEFT JOIN fund f ON f.county_number = i.county_number
ORDER BY recon_status, i.ivfa_depts DESC;
