-- ============================================================
-- SEA-1 Education Impact Model — Schools & Libraries (statewide)
-- Run as ACCOUNTADMIN in HOOSIER_DATA Snowflake account
--
-- Generalizes the township fire model (sea1_impact.sql) to ANY taxing unit
-- via the DLGF Tax Rate Chart (TRC) district→unit crosswalk.
--
-- Tickets: KAN-153 (TRC load), KAN-154 (SEA1_UNIT_AV_BASE),
--          KAN-155 (SEA1_SCHOOL_IMPACT), KAN-156 (SEA1_LIBRARY_IMPACT +
--          SEA1_EDUCATION_SUMMARY)
--
-- Depends on:
--   RAW.DLGF_TAX_DISTRICT_UNITS  — fund-grain crosswalk, KAN-153
--                                  (load via scripts/load_snowflake_trc.py)
--   RAW.GATEWAY_PARCEL (pay_year='2025'), ANALYTICS.CERT_NAV_CLEAN,
--   RAW.SEA1_DEDUCTION_PARAMS, RAW.GATEWAY_DISBURSEMENTS
--
-- Baseline vintage + rules inherited from sea1_impact.sql:
--   - pay_year='2025' (2024 assessment, payable 2025)
--   - CERT_NAV: dedup on (budget_year, county_number, tax_district_code)
--   - Parcel district join: LPAD(state_district_number,3,'0') = tax_district_code
--   - county_number in EVERY district join (codes repeat across counties)
--
-- ── UNIT-TYPE CODE SYSTEMS (two different schemes — do not confuse) ──────────
--   DLGF TRC / unit_type_cd : 1=County 2=Township 3=City/Town 4=School 5=Library
--   GATEWAY_DISBURSEMENTS afr_unit_type : 5=School 6=Library 7=Township
--
-- ── METHODOLOGY: tax-district nesting ───────────────────────────────────────
--   A tax district is the unique intersection of every overlapping taxing unit,
--   so each district nests ENTIRELY within one school corp and one library.
--   => a unit's loss = SUM over its districts of the FULL district AV delta.
--      No fractional parcel allocation is required.
--   Verified against 2025 TRC: 0 of 1,700 districts map to >1 library;
--   only 6 of 2,059 map to >1 school corp (rare overlap districts — full
--   attribution slightly double-counts those 6 statewide; none in Bartholomew).
--
-- ── BPP CAVEAT (read before citing BPP numbers) ─────────────────────────────
--   Like the fire model, BPP loss assumes 100% of a district's business
--   personal property becomes exempt under the $80K→$2M threshold. That holds
--   for small rural districts, but OVERSTATES loss anywhere large taxpayers
--   (>$2M acquisition cost — e.g. Cummins in the City of Columbus district)
--   remain taxable. For school/library units spanning cities, BPP loss is an
--   UPPER BOUND. Provenance is therefore flagged 'ESTIMATED — BPP upper bound'.
--   CERT_NAV gives only district BPP totals (no per-taxpayer detail), so the
--   exempt share cannot be isolated from the warehouse today.
--
-- Validated Bartholomew 2031 full-phase-in (operations/general fund only):
--   BCSC               bpp≈$4.33M(UB)  homestead≈$0.94M  2%≈$1.08M
--   Flatrock-Hawcreek  bpp≈$0.13M(UB)  homestead≈$0.07M  2%≈$0.12M
--   BCPL               bpp≈$0.60M(UB)  homestead≈$0.14M  2%≈$0.16M
-- ============================================================


-- ══════════════════════════════════════════════════════════════════════════════
-- 0. DLGF_DISTRICT_UNIT_CLEAN  (KAN-153 companion)
--    Cleaned, typed view over the raw fund-grain crosswalk.
--    One row per (budget_year, county, unit, fund, tax_district).
--    tax_district_code normalized to 3-char to match PARCEL / CERT_NAV.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN AS
SELECT
    TRIM(budget_year)                              AS budget_year,
    TRIM(county_number)                            AS county_number,
    TRIM(unit_type_cd)                             AS unit_type_cd,
    TRIM(unit_code)                                AS unit_code,
    TRIM(unit_name)                                AS unit_name,
    TRIM(fund_code)                                AS fund_code,
    TRIM(fund_name)                                AS fund_name,
    LPAD(TRIM(tax_district_code), 3, '0')          AS tax_district_code,
    TRIM(tax_district_name)                        AS tax_district_name,
    TRY_TO_DECIMAL(certd_tax_rate_pct, 18, 6)      AS certd_tax_rate_pct
FROM HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS;


-- ══════════════════════════════════════════════════════════════════════════════
-- 1. PARCEL_DISTRICT_AV  (reusable, TRC-independent)
--    District-grain roll-up of GATEWAY_PARCEL cap-class AV (pay 2025).
--    One row per (county, tax_district). Consumed by SEA1_UNIT_AV_BASE.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_AV AS
SELECT
    TRIM(county_number)                                          AS county_number,
    county_description,
    LPAD(TRIM(state_district_number), 3, '0')                    AS tax_district_code,
    COUNT(*)                                                     AS parcel_count,
    ROUND(SUM(COALESCE(TRY_TO_NUMBER(av_total_land_and_impr), 0)))   AS gross_av,
    ROUND(SUM(COALESCE(TRY_TO_NUMBER(av_land_1pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_impr_1pct), 0)))             AS homestead_av,
    ROUND(SUM(COALESCE(TRY_TO_NUMBER(av_nonhs_res_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_nonhs_res_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_apt_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_apt_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_ltc_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_ltc_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_farmland_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_mobile_home_land_2pct), 0)))  AS two_pct_av,
    ROUND(SUM(COALESCE(TRY_TO_NUMBER(av_land_3pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_impr_3pct), 0)))             AS three_pct_av
FROM HOOSIER_DATA.RAW.GATEWAY_PARCEL
WHERE pay_year = '2025'
GROUP BY TRIM(county_number), county_description,
         LPAD(TRIM(state_district_number), 3, '0');


-- ══════════════════════════════════════════════════════════════════════════════
-- 2. SEA1_DISTRICT_AV_DELTA  (reusable, TRC-independent)
--    Per (county, tax_district, phase_year): AV removed from the taxable base
--    by SEA-1's homestead and 2%-bucket mechanisms.
--    Per-parcel deduction caps applied at parcel grain, then summed to district.
--    Mirrors SEA1_HOMESTEAD_LOSS / SEA1_2PCT_BUCKET_LOSS but keyed by district
--    (a district nests in every overlapping unit, so district-grain deltas can
--    be re-attributed to any unit by summation — see header).
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_DISTRICT_AV_DELTA AS
WITH hs_params AS (
    SELECT
        phase_year,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN param_value   END) AS cap_new,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN old_law_value END) AS cap_old,
        MAX(CASE WHEN param_name = 'STD_DED_PCT'     THEN param_value   END) AS pct,
        MAX(CASE WHEN param_name = 'SUPP_RATE_TIER1' THEN param_value   END) AS r1,
        MAX(CASE WHEN param_name = 'SUPP_THRESHOLD'  THEN param_value   END) AS thr,
        MAX(CASE WHEN param_name = 'SUPP_RATE_TIER2' THEN param_value   END) AS r2,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN verified      END) AS hs_verified
    FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD'
    GROUP BY phase_year
),
bucket_params AS (
    SELECT phase_year, param_value AS ded_pct, verified AS bk_verified
    FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = '2PCT_BUCKET' AND param_name = 'BUCKET_DED_PCT'
),
parcel AS (
    SELECT
        TRIM(county_number)                                          AS county_number,
        LPAD(TRIM(state_district_number), 3, '0')                    AS tax_district_code,
        COALESCE(TRY_TO_NUMBER(av_land_1pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_impr_1pct), 0)               AS hav,
        COALESCE(TRY_TO_NUMBER(av_nonhs_res_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_nonhs_res_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_apt_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_apt_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_ltc_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_ltc_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_farmland_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(av_mobile_home_land_2pct), 0)   AS tpav
    FROM HOOSIER_DATA.RAW.GATEWAY_PARCEL
    WHERE pay_year = '2025'
)
SELECT
    p.county_number,
    p.tax_district_code,
    hp.phase_year,
    -- Homestead AV removed = (Δ standard deduction) + (Δ supplemental deduction)
    ROUND(SUM(
        (LEAST(hp.pct * p.hav, hp.cap_new) - LEAST(hp.pct * p.hav, hp.cap_old))
        + (
            hp.r1 * LEAST(GREATEST(p.hav - LEAST(hp.pct * p.hav, hp.cap_new), 0), hp.thr)
            + hp.r2 * GREATEST(p.hav - LEAST(hp.pct * p.hav, hp.cap_new) - hp.thr, 0)
            - hp.r1 * LEAST(GREATEST(p.hav - LEAST(hp.pct * p.hav, hp.cap_old), 0), hp.thr)
            - hp.r2 * GREATEST(p.hav - LEAST(hp.pct * p.hav, hp.cap_old) - hp.thr, 0)
          )
    ))                                                               AS homestead_av_delta,
    -- 2%-bucket AV removed = 2%-cap AV × phased deduction fraction
    ROUND(SUM(p.tpav * bk.ded_pct))                                  AS two_pct_av_delta,
    CASE WHEN hp.hs_verified THEN 'VERIFIED' ELSE 'ESTIMATED' END    AS homestead_provenance,
    CASE WHEN bk.bk_verified THEN 'VERIFIED' ELSE 'ESTIMATED' END    AS two_pct_provenance
FROM parcel p
JOIN hs_params hp      ON TRUE
JOIN bucket_params bk  ON bk.phase_year = hp.phase_year
GROUP BY p.county_number, p.tax_district_code, hp.phase_year,
         hp.hs_verified, bk.bk_verified;


-- ══════════════════════════════════════════════════════════════════════════════
-- 3. SEA1_UNIT_AV_BASE  (KAN-154)
--    Generalized parcel-AV allocation to ANY taxing unit via the TRC.
--    One row per (county, unit_type_cd, unit_name, tax_district_code).
--    Parcel cap-class AV comes from the district (full district nests in unit);
--    BPP comes from CERT_NAV (personal property is not in PARCEL);
--    levy rate is the unit's combined certified rate in that district (TRC).
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_UNIT_AV_BASE AS
WITH unit_district AS (
    -- Distinct (unit × district) membership + combined certified rate
    SELECT
        county_number,
        unit_type_cd,
        unit_code,
        unit_name,
        tax_district_code,
        MAX(tax_district_name)                  AS tax_district_name,
        SUM(certd_tax_rate_pct)                 AS unit_district_rate
    FROM HOOSIER_DATA.ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN
    WHERE budget_year = '2025'
    GROUP BY county_number, unit_type_cd, unit_code, unit_name, tax_district_code
),
cert_bpp AS (
    SELECT
        TRIM(county_number)                     AS county_number,
        TRIM(tax_district_code)                 AS tax_district_code,
        TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)    AS bpp_nav
    FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(budget_year), TRIM(county_number), TRIM(tax_district_code)
        ORDER BY TRIM(tax_district_name)
    ) = 1
    AND TRIM(budget_year) = '2025'
)
SELECT
    ud.county_number,
    pda.county_description,
    ud.unit_type_cd,
    ud.unit_code,
    ud.unit_name,
    ud.tax_district_code,
    ud.tax_district_name,
    pda.parcel_count,
    pda.gross_av,
    pda.homestead_av,
    pda.two_pct_av,
    pda.three_pct_av,
    ROUND(cb.bpp_nav)                           AS bpp_nav,
    ROUND(ud.unit_district_rate, 6)             AS levy_rate_per_100
FROM unit_district ud
LEFT JOIN HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_AV pda
    ON ud.county_number = pda.county_number
   AND ud.tax_district_code = pda.tax_district_code
LEFT JOIN cert_bpp cb
    ON ud.county_number = cb.county_number
   AND ud.tax_district_code = cb.tax_district_code;


-- ══════════════════════════════════════════════════════════════════════════════
-- 4. SCHOOL_COST_TREND  (KAN-155 companion)
--    Operating disbursement CAGR per school corp, 2020–2024 + 2029 projection.
--    afr_unit_type = '5'. Excludes debt service, capital, and transfers
--    (transfer-exclusion rule inherited from FIRE_COST_TREND).
--    NOTE: school AFR coverage on Gateway is uneven — <4 clean years flags
--    LOW_CONFIDENCE. Many corps also report to IDOE rather than Gateway.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SCHOOL_COST_TREND AS
WITH operating AS (
    SELECT
        YEAR::INTEGER                                              AS year,
        TRIM(cnty_description)                                     AS county_description,
        TRIM(unit_name)                                            AS school_corp,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(amount, ',', ''))))        AS operating_cost
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE afr_unit_type = '5'
      AND UPPER(fund_name) NOT LIKE '%DEBT%'
      AND UPPER(fund_name) NOT LIKE '%CAPITAL%'
      AND UPPER(fund_name) NOT LIKE '%CONSTRUCTION%'
      AND UPPER(fund_name) NOT LIKE '%REFERENDUM%'
      AND NOT (UPPER(class_name) = 'OTHER DISBURSEMENTS'
               AND UPPER(disburse_name) LIKE 'TRANSFER OUT%')
    GROUP BY YEAR::INTEGER, TRIM(cnty_description), TRIM(unit_name)
),
series AS (
    SELECT * FROM operating WHERE year BETWEEN 2020 AND 2024 AND operating_cost > 0
),
cagr_calc AS (
    SELECT
        county_description,
        school_corp,
        COUNT(DISTINCT year)                                       AS years_of_data,
        MIN(year)                                                  AS first_year,
        MAX(year)                                                  AS last_year,
        MIN(CASE WHEN year = (SELECT MIN(year) FROM series s2
                              WHERE s2.county_description = s.county_description
                                AND s2.school_corp = s.school_corp)
                 THEN operating_cost END)                          AS first_year_cost,
        MAX(CASE WHEN year = 2024 THEN operating_cost END)         AS cost_2024
    FROM series s
    GROUP BY county_description, school_corp
)
SELECT
    county_description,
    school_corp,
    years_of_data,
    first_year,
    last_year,
    ROUND(first_year_cost)                                         AS first_year_operating,
    ROUND(cost_2024)                                               AS cost_2024_operating,
    CASE WHEN first_year_cost > 0 AND cost_2024 > 0 AND (last_year - first_year) > 0
         THEN ROUND((POWER(cost_2024 / first_year_cost, 1.0 / (last_year - first_year)) - 1) * 100, 2)
         ELSE NULL END                                             AS operating_cagr_pct,
    ROUND(cost_2024 * POWER(
        1 + COALESCE(
            CASE WHEN first_year_cost > 0 AND cost_2024 > 0 AND (last_year - first_year) > 0
                 THEN POWER(cost_2024 / first_year_cost, 1.0 / (last_year - first_year)) - 1
                 ELSE 0 END, 0), 5))                               AS proj_2029,
    CASE
        WHEN years_of_data < 4 THEN 'LOW_CONFIDENCE — fewer than 4 years'
        ELSE 'OK'
    END                                                           AS confidence_flag
FROM cagr_calc;


-- ══════════════════════════════════════════════════════════════════════════════
-- 5. SEA1_SCHOOL_IMPACT  (KAN-155)
--    SEA-1 levy loss per school corporation × phase year (2026-2031).
--    Operations-fund frame (the recurring, non-referendum levy).
--    Built entirely from TRC crosswalk + CERT_NAV + SEA1_DISTRICT_AV_DELTA —
--    no name-join to FORM4B (TRC unit names differ, e.g. "CORP" vs
--    "CORPORATION"); rate and NAV both derive from the district crosswalk.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_SCHOOL_IMPACT AS
WITH school_rate AS (
    -- Operations-fund rate per school corp (constant across its districts)
    SELECT
        county_number, unit_code, unit_name,
        MAX(CASE WHEN UPPER(fund_name) LIKE '%OPERATION%' THEN certd_tax_rate_pct END) AS ops_rate
    FROM HOOSIER_DATA.ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN
    WHERE budget_year = '2025' AND unit_type_cd = '4'
    GROUP BY county_number, unit_code, unit_name
),
school_district AS (
    SELECT DISTINCT county_number, unit_code, unit_name, tax_district_code
    FROM HOOSIER_DATA.ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN
    WHERE budget_year = '2025' AND unit_type_cd = '4'
),
cert AS (
    SELECT
        TRIM(county_number)                     AS county_number,
        TRIM(tax_district_code)                 AS tax_district_code,
        TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)    AS bpp_nav,
        TRY_TO_DECIMAL(net_av_1pct, 18, 0)
            + TRY_TO_DECIMAL(net_av_2pct, 18, 0)
            + TRY_TO_DECIMAL(net_av_3pct, 18, 0) AS district_net_av
    FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(budget_year), TRIM(county_number), TRIM(tax_district_code)
        ORDER BY TRIM(tax_district_name)
    ) = 1
    AND TRIM(budget_year) = '2025'
),
-- School × district × phase_year with district deltas + bpp + nav
school_district_year AS (
    SELECT
        sd.county_number,
        sd.unit_code,
        sd.unit_name,
        d.phase_year,
        d.homestead_av_delta,
        d.two_pct_av_delta,
        d.homestead_provenance,
        d.two_pct_provenance,
        c.bpp_nav,
        c.district_net_av
    FROM school_district sd
    JOIN HOOSIER_DATA.ANALYTICS.SEA1_DISTRICT_AV_DELTA d
        ON sd.county_number = d.county_number
       AND sd.tax_district_code = d.tax_district_code
    LEFT JOIN cert c
        ON sd.county_number = c.county_number
       AND sd.tax_district_code = c.tax_district_code
    WHERE d.phase_year BETWEEN 2026 AND 2031
)
SELECT
    sdy.county_number,
    cn.cnty_description                                              AS county_description,
    sdy.unit_name                                                    AS school_corp_name,
    sdy.phase_year,
    ROUND(sr.ops_rate, 6)                                            AS ops_rate_per_100,
    ROUND(SUM(sdy.district_net_av))                                  AS ops_nav,
    -- BPP loss (UPPER BOUND — see header caveat)
    ROUND(SUM(sdy.bpp_nav) * sr.ops_rate / 100)                      AS bpp_loss,
    'ESTIMATED — BPP upper bound'                                    AS bpp_provenance,
    -- Homestead loss
    ROUND(SUM(sdy.homestead_av_delta) * sr.ops_rate / 100)          AS homestead_loss,
    MAX(sdy.homestead_provenance)                                    AS homestead_provenance,
    -- 2%-bucket loss
    ROUND(SUM(sdy.two_pct_av_delta) * sr.ops_rate / 100)            AS two_pct_loss,
    MAX(sdy.two_pct_provenance)                                      AS two_pct_provenance,
    -- Total SEA-1 loss
    ROUND(
        SUM(sdy.bpp_nav) * sr.ops_rate / 100
        + SUM(sdy.homestead_av_delta) * sr.ops_rate / 100
        + SUM(sdy.two_pct_av_delta) * sr.ops_rate / 100
    )                                                                AS total_sea1_loss
FROM school_district_year sdy
JOIN school_rate sr
    ON sdy.county_number = sr.county_number AND sdy.unit_code = sr.unit_code
LEFT JOIN (SELECT DISTINCT TRIM(county_number) county_number, cnty_description
           FROM HOOSIER_DATA.ANALYTICS.CERT_NAV_CLEAN) cn
    ON sdy.county_number = cn.county_number
GROUP BY sdy.county_number, cn.cnty_description, sdy.unit_name, sdy.phase_year, sr.ops_rate
ORDER BY sdy.county_number, sdy.unit_name, sdy.phase_year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 6. LIBRARY_COST_TREND  (KAN-156 companion)
--    Operating disbursement CAGR per library, 2020–2024 + 2029 projection.
--    afr_unit_type = '6'. Library operating fund = 'Operating' (confirmed).
--    Small districts may have sparse AFR data — <4 years flags LOW_CONFIDENCE.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.LIBRARY_COST_TREND AS
WITH operating AS (
    SELECT
        YEAR::INTEGER                                              AS year,
        TRIM(cnty_description)                                     AS county_description,
        TRIM(unit_name)                                            AS library_name,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(amount, ',', ''))))        AS operating_cost
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE afr_unit_type = '6'
      AND UPPER(fund_name) LIKE '%OPERAT%'
      AND NOT (UPPER(class_name) = 'OTHER DISBURSEMENTS'
               AND UPPER(disburse_name) LIKE 'TRANSFER OUT%')
    GROUP BY YEAR::INTEGER, TRIM(cnty_description), TRIM(unit_name)
),
series AS (
    SELECT * FROM operating WHERE year BETWEEN 2020 AND 2024 AND operating_cost > 0
),
cagr_calc AS (
    SELECT
        county_description,
        library_name,
        COUNT(DISTINCT year)                                       AS years_of_data,
        MIN(year)                                                  AS first_year,
        MAX(year)                                                  AS last_year,
        MIN(CASE WHEN year = (SELECT MIN(year) FROM series s2
                              WHERE s2.county_description = s.county_description
                                AND s2.library_name = s.library_name)
                 THEN operating_cost END)                          AS first_year_cost,
        MAX(CASE WHEN year = 2024 THEN operating_cost END)         AS cost_2024
    FROM series s
    GROUP BY county_description, library_name
)
SELECT
    county_description,
    library_name,
    years_of_data,
    first_year,
    last_year,
    ROUND(first_year_cost)                                         AS first_year_operating,
    ROUND(cost_2024)                                               AS cost_2024_operating,
    CASE WHEN first_year_cost > 0 AND cost_2024 > 0 AND (last_year - first_year) > 0
         THEN ROUND((POWER(cost_2024 / first_year_cost, 1.0 / (last_year - first_year)) - 1) * 100, 2)
         ELSE NULL END                                             AS operating_cagr_pct,
    ROUND(cost_2024 * POWER(
        1 + COALESCE(
            CASE WHEN first_year_cost > 0 AND cost_2024 > 0 AND (last_year - first_year) > 0
                 THEN POWER(cost_2024 / first_year_cost, 1.0 / (last_year - first_year)) - 1
                 ELSE 0 END, 0), 5))                               AS proj_2029,
    CASE
        WHEN years_of_data < 4 THEN 'LOW_CONFIDENCE — fewer than 4 years'
        ELSE 'OK'
    END                                                           AS confidence_flag
FROM cagr_calc;


-- ══════════════════════════════════════════════════════════════════════════════
-- 7. SEA1_LIBRARY_IMPACT  (KAN-156)
--    SEA-1 levy loss per library district × phase year (2026-2031).
--    General-fund frame. Same three-mechanism model as schools.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_LIBRARY_IMPACT AS
WITH lib_rate AS (
    SELECT
        county_number, unit_code, unit_name,
        MAX(CASE WHEN UPPER(fund_name) LIKE '%GENERAL%' THEN certd_tax_rate_pct END) AS general_rate
    FROM HOOSIER_DATA.ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN
    WHERE budget_year = '2025' AND unit_type_cd = '5'
    GROUP BY county_number, unit_code, unit_name
),
lib_district AS (
    SELECT DISTINCT county_number, unit_code, unit_name, tax_district_code
    FROM HOOSIER_DATA.ANALYTICS.DLGF_DISTRICT_UNIT_CLEAN
    WHERE budget_year = '2025' AND unit_type_cd = '5'
),
cert AS (
    SELECT
        TRIM(county_number)                     AS county_number,
        TRIM(tax_district_code)                 AS tax_district_code,
        TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)    AS bpp_nav,
        TRY_TO_DECIMAL(net_av_1pct, 18, 0)
            + TRY_TO_DECIMAL(net_av_2pct, 18, 0)
            + TRY_TO_DECIMAL(net_av_3pct, 18, 0) AS district_net_av
    FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(budget_year), TRIM(county_number), TRIM(tax_district_code)
        ORDER BY TRIM(tax_district_name)
    ) = 1
    AND TRIM(budget_year) = '2025'
),
lib_district_year AS (
    SELECT
        ld.county_number, ld.unit_code, ld.unit_name, d.phase_year,
        d.homestead_av_delta, d.two_pct_av_delta,
        d.homestead_provenance, d.two_pct_provenance,
        c.bpp_nav, c.district_net_av
    FROM lib_district ld
    JOIN HOOSIER_DATA.ANALYTICS.SEA1_DISTRICT_AV_DELTA d
        ON ld.county_number = d.county_number
       AND ld.tax_district_code = d.tax_district_code
    LEFT JOIN cert c
        ON ld.county_number = c.county_number
       AND ld.tax_district_code = c.tax_district_code
    WHERE d.phase_year BETWEEN 2026 AND 2031
)
SELECT
    ldy.county_number,
    cn.cnty_description                                              AS county_description,
    ldy.unit_name                                                    AS library_name,
    ldy.phase_year,
    ROUND(lr.general_rate, 6)                                        AS general_rate_per_100,
    ROUND(SUM(ldy.district_net_av))                                  AS library_nav,
    ROUND(SUM(ldy.bpp_nav) * lr.general_rate / 100)                 AS bpp_loss,
    'ESTIMATED — BPP upper bound'                                    AS bpp_provenance,
    ROUND(SUM(ldy.homestead_av_delta) * lr.general_rate / 100)      AS homestead_loss,
    MAX(ldy.homestead_provenance)                                    AS homestead_provenance,
    ROUND(SUM(ldy.two_pct_av_delta) * lr.general_rate / 100)        AS two_pct_loss,
    MAX(ldy.two_pct_provenance)                                      AS two_pct_provenance,
    ROUND(
        SUM(ldy.bpp_nav) * lr.general_rate / 100
        + SUM(ldy.homestead_av_delta) * lr.general_rate / 100
        + SUM(ldy.two_pct_av_delta) * lr.general_rate / 100
    )                                                                AS total_sea1_loss
FROM lib_district_year ldy
JOIN lib_rate lr
    ON ldy.county_number = lr.county_number AND ldy.unit_code = lr.unit_code
LEFT JOIN (SELECT DISTINCT TRIM(county_number) county_number, cnty_description
           FROM HOOSIER_DATA.ANALYTICS.CERT_NAV_CLEAN) cn
    ON ldy.county_number = cn.county_number
GROUP BY ldy.county_number, cn.cnty_description, ldy.unit_name, ldy.phase_year, lr.general_rate
ORDER BY ldy.county_number, ldy.unit_name, ldy.phase_year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 8. SEA1_EDUCATION_SUMMARY  (KAN-156 — the headline deliverable)
--    Unified fire + school + library SEA-1 loss, normalized to one schema.
--    "What does SEA-1 cost a community's public services, year by year, unit by
--    unit?"  Filter by county_number (+ phase_year) for any district packet.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_EDUCATION_SUMMARY AS
SELECT
    county_number,
    county_description,
    township_name                                   AS unit_name,
    'FIRE'                                           AS unit_type,
    phase_year,
    bpp_loss,
    homestead_loss,
    two_pct_loss,
    total_sea1_loss
FROM HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY
WHERE phase_year BETWEEN 2026 AND 2031

UNION ALL

SELECT
    county_number,
    county_description,
    school_corp_name                                AS unit_name,
    'SCHOOL'                                         AS unit_type,
    phase_year,
    bpp_loss,
    homestead_loss,
    two_pct_loss,
    total_sea1_loss
FROM HOOSIER_DATA.ANALYTICS.SEA1_SCHOOL_IMPACT

UNION ALL

SELECT
    county_number,
    county_description,
    library_name                                    AS unit_name,
    'LIBRARY'                                        AS unit_type,
    phase_year,
    bpp_loss,
    homestead_loss,
    two_pct_loss,
    total_sea1_loss
FROM HOOSIER_DATA.ANALYTICS.SEA1_LIBRARY_IMPACT;
