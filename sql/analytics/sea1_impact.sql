-- ============================================================
-- SEA-1 Fire Fund Impact Model — Statewide Views
-- Run as ACCOUNTADMIN in HOOSIER_DATA Snowflake account
--
-- Mechanisms modeled:
--   BPP         — BPP exemption increase ($80K → $2M per taxpayer)
--   HOMESTEAD   — homestead standard + supplemental deduction increase
--   2PCT_BUCKET — phased AV deduction for 2%-cap property (KAN-141)
--
-- IMPORTANT: Homestead and 2%-bucket deduction parameters are ESTIMATES.
--   Verify STD_DED_CAP phase-in schedule against HEA 1001 (2024) enrolled
--   act and LSA fiscal note before citing figures externally.
--
-- Design rules (Confluence IK/16547841, 2026-06-09):
--   - Baseline vintage: pay_year = '2025' (2024p2025 GATEWAY_PARCEL)
--   - CERT_NAV: dedup on (budget_year, county_number, tax_district_code)
--   - PARCEL district join: LPAD(state_district_number, 3, '0') = tax_district_code
--   - Always include county_number in CERT_NAV joins (codes repeat statewide)
--   - Transfer exclusion: CLASS_NAME='Other Disbursements' AND DISBURSE_NAME LIKE 'Transfer Out%'
--   - Harrison proper = district 011 only (024/027 are Columbus annex, confirmed)
--   - Pre-2025 CERT_NAV cap-class splits unreliable (classification correction)
--
-- Tickets: KAN-138 (shared infra + homestead), KAN-141 (2% bucket),
--          KAN-139 (cost trend), KAN-140 (summary)
-- ============================================================


-- ══════════════════════════════════════════════════════════════════════════════
-- 0. DEDUCTION PARAMETER TABLE
--    Mechanism-keyed; adding a mechanism = INSERT new rows, no schema change.
--    VERIFIED = FALSE until confirmed against enrolled act / LSA fiscal note.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS (
    mechanism       VARCHAR   NOT NULL,  -- HOMESTEAD | 2PCT_BUCKET | BPP
    phase_year      INTEGER   NOT NULL,  -- payable year; 2025 = pre-SEA-1 baseline
    param_name      VARCHAR   NOT NULL,  -- parameter key
    param_value     FLOAT     NOT NULL,  -- SEA-1 (new law) value
    old_law_value   FLOAT,               -- pre-SEA-1 baseline
    verified        BOOLEAN   DEFAULT FALSE,
    source_note     VARCHAR
);

-- ── HOMESTEAD: standard deduction cap (IC 6-1.1-12-37) ──────────────────────
-- Old law cap: $45,000. SEA-1 phases to $60,000 by 2031 (+$2,500/yr).
-- ESTIMATE — verify exact phase-in schedule against HEA 1001 (2024).
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT 'HOMESTEAD', yr, 'STD_DED_CAP', cap, 45000.0, FALSE,
    'ESTIMATE — old law $45K; SEA-1 +$2,500/yr to $60K by 2031. Verify HEA 1001 (2024).'
FROM (VALUES
    (2025, 45000.0),
    (2026, 47500.0),
    (2027, 50000.0),
    (2028, 52500.0),
    (2029, 55000.0),
    (2030, 57500.0),
    (2031, 60000.0)
) t(yr, cap)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD' AND phase_year = t.yr AND param_name = 'STD_DED_CAP'
);

-- HOMESTEAD: 60% AV fraction (unchanged by SEA-1)
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT 'HOMESTEAD', yr, 'STD_DED_PCT', 0.60, 0.60, TRUE,
    'IC 6-1.1-12-37 — 60% of AV unchanged by SEA-1.'
FROM (VALUES (2025),(2026),(2027),(2028),(2029),(2030),(2031)) t(yr)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD' AND phase_year = t.yr AND param_name = 'STD_DED_PCT'
);

-- HOMESTEAD: supplemental deduction tier 1 rate (IC 6-1.1-12-37.5)
-- Old law: 35% on net AV (after std ded) ≤ $600K. Verify SEA-1 change.
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT 'HOMESTEAD', yr, 'SUPP_RATE_TIER1', 0.35, 0.35, FALSE,
    'ESTIMATE — old law 35%. Verify whether SEA-1 revised supplemental formula.'
FROM (VALUES (2025),(2026),(2027),(2028),(2029),(2030),(2031)) t(yr)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD' AND phase_year = t.yr AND param_name = 'SUPP_RATE_TIER1'
);

-- HOMESTEAD: supplemental deduction tier threshold
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT 'HOMESTEAD', yr, 'SUPP_THRESHOLD', 600000.0, 600000.0, FALSE,
    'ESTIMATE — old law $600K tier. Verify SEA-1 change if any.'
FROM (VALUES (2025),(2026),(2027),(2028),(2029),(2030),(2031)) t(yr)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD' AND phase_year = t.yr AND param_name = 'SUPP_THRESHOLD'
);

-- HOMESTEAD: supplemental deduction tier 2 rate (above $600K)
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT 'HOMESTEAD', yr, 'SUPP_RATE_TIER2', 0.25, 0.25, FALSE,
    'ESTIMATE — old law 25% above $600K. Verify SEA-1 change if any.'
FROM (VALUES (2025),(2026),(2027),(2028),(2029),(2030),(2031)) t(yr)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD' AND phase_year = t.yr AND param_name = 'SUPP_RATE_TIER2'
);

-- ── 2PCT_BUCKET: phased AV deduction (KAN-141 mechanism) ────────────────────
-- SEA-1 phases in AV deduction for all 2%-cap property, reaching 1/3 by 2031.
-- Linear 6-year phase-in assumed. Verify exact annual schedule.
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT '2PCT_BUCKET', yr, 'BUCKET_DED_PCT', pct, 0.0, FALSE,
    'ESTIMATE — SEA-1 phases to 1/3 AV by 2031 (6-yr linear assumed). Verify schedule.'
FROM (VALUES
    (2025, 0.0),
    (2026, 0.0556),
    (2027, 0.1111),
    (2028, 0.1667),
    (2029, 0.2222),
    (2030, 0.2778),
    (2031, 0.3333)
) t(yr, pct)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = '2PCT_BUCKET' AND phase_year = t.yr AND param_name = 'BUCKET_DED_PCT'
);

-- ── BPP: exemption threshold (IC 6-1.1-31.5) ────────────────────────────────
-- Raised $80K → $2M effective 2025 assessment. All taxpayers with BPP AV ≤ $2M exempt.
INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
SELECT 'BPP', yr, 'BPP_EXEMPTION_THRESHOLD', 2000000.0, 80000.0, TRUE,
    'HEA 1001 (2024) IC 6-1.1-31.5 — threshold $80K→$2M effective 2025 assessment.'
FROM (VALUES (2025),(2026),(2027),(2028),(2029),(2030),(2031)) t(yr)
WHERE NOT EXISTS (
    SELECT 1 FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'BPP' AND phase_year = t.yr AND param_name = 'BPP_EXEMPTION_THRESHOLD'
);


-- ══════════════════════════════════════════════════════════════════════════════
-- 1. PARCEL_DISTRICT_RATE
--    Reusable base view: GATEWAY_PARCEL (pay-2025) joined to CERT_NAV (deduped)
--    + DLGF_TOWNSHIP_CODES + FORM4B fire rate.
--    Consumed by SEA1_HOMESTEAD_LOSS and SEA1_2PCT_BUCKET_LOSS.
--    One row per parcel. county_number in all joins (CERT_NAV is statewide).
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_RATE AS
WITH cert_nav_deduped AS (
    SELECT
        TRIM(budget_year)                       AS budget_year,
        TRIM(county_number)                     AS county_number,
        TRIM(tax_district_code)                 AS tax_district_code,
        TRIM(tax_district_name)                 AS tax_district_name,
        TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)    AS bus_pp_net_av,
        TRY_TO_DECIMAL(real_est_net_av, 18, 0)  AS real_est_net_av,
        TRY_TO_DECIMAL(net_av_1pct, 18, 0)      AS net_av_1pct,
        TRY_TO_DECIMAL(net_av_2pct, 18, 0)      AS net_av_2pct,
        TRY_TO_DECIMAL(net_av_3pct, 18, 0)      AS net_av_3pct,
        TRY_TO_DECIMAL(pp_net_av, 18, 0)        AS pp_net_av
    FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(budget_year), TRIM(county_number), TRIM(tax_district_code)
        ORDER BY TRIM(tax_district_name)
    ) = 1
),
township_fire_rate AS (
    -- Weighted average combined fire rate per township (2024 FORM4B certified)
    -- Weights by NAV so multi-fund townships (fire + cumulative) yield a blended rate.
    SELECT
        TRIM(cnty_cd)   AS county_number,
        TRIM(unit_name) AS unit_name,
        SUM(net_tax_rate_adopted_num * net_assessed_valuation_num)
            / NULLIF(SUM(net_assessed_valuation_num), 0) AS fire_rate_per_100
    FROM HOOSIER_DATA.ANALYTICS.FORM4B_CLEAN
    WHERE unit_type = '2'
      AND UPPER(fund_description) LIKE '%FIRE%'
      AND year_num = 2024
    GROUP BY 1, 2
),
township_codes AS (
    SELECT
        TRIM(county_number)                      AS county_number,
        LPAD(TRIM(township_number), 4, '0')      AS township_number,
        UPPER(TRIM(township_name))               AS township_name_upper
    FROM HOOSIER_DATA.RAW.DLGF_TOWNSHIP_CODES
)
SELECT
    p.pay_year,
    p.assessment_year,
    TRIM(p.county_number)                                          AS county_number,
    p.county_description,
    LPAD(TRIM(p.township_number), 4, '0')                         AS township_number,
    tc.township_name_upper                                         AS township_name,
    LPAD(TRIM(p.state_district_number), 3, '0')                   AS tax_district_code,
    cn.tax_district_name,
    -- Parcel AV buckets (COALESCE handles sparse records)
    COALESCE(TRY_TO_NUMBER(p.av_total_land_and_impr), 0)          AS av_total,
    COALESCE(TRY_TO_NUMBER(p.av_land_1pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_impr_1pct), 0)              AS homestead_av,
    COALESCE(TRY_TO_NUMBER(p.av_nonhs_res_land_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_nonhs_res_impr_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_apt_land_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_apt_impr_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_ltc_land_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_ltc_impr_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_farmland_2pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_mobile_home_land_2pct), 0)  AS two_pct_av,
    COALESCE(TRY_TO_NUMBER(p.av_land_3pct), 0)
        + COALESCE(TRY_TO_NUMBER(p.av_impr_3pct), 0)              AS three_pct_av,
    -- CERT_NAV district AV for cross-reference
    cn.bus_pp_net_av                                               AS district_bpp_nav,
    cn.real_est_net_av                                             AS district_real_est_nav,
    -- Fire rate from FORM4B (2024 certified)
    tfr.fire_rate_per_100
FROM HOOSIER_DATA.RAW.GATEWAY_PARCEL p
JOIN cert_nav_deduped cn
    ON TRIM(p.county_number) = cn.county_number
    AND LPAD(TRIM(p.state_district_number), 3, '0') = cn.tax_district_code
    AND cn.budget_year = p.pay_year
LEFT JOIN township_codes tc
    ON TRIM(p.county_number) = tc.county_number
    AND LPAD(TRIM(p.township_number), 4, '0') = tc.township_number
LEFT JOIN township_fire_rate tfr
    ON TRIM(p.county_number) = tfr.county_number
    AND tc.township_name_upper = UPPER(tfr.unit_name)
WHERE p.pay_year = '2025';


-- ══════════════════════════════════════════════════════════════════════════════
-- 2. SEA1_BPP_LOSS
--    Formalizes the verified BPP loss table (Confluence IK/16547841).
--    BPP loss = district BPP AV (CERT_NAV 2025) × combined fire rate / 100.
--    Statewide; filter to county for specific packets.
--
--    SCOPE RULE: township-proper districts only (tax_district_name LIKE '%TWP%'
--    or '%TOWNSHIP%'). City, annex, and town sub-districts are excluded —
--    those areas are served by city/town fire departments, not the township VFD,
--    and their BPP (often very large) would wildly overstate township fire loss.
--    E.g. City of Columbus district BPP = $573M vs Columbus Twp-proper = $14M.
--
--    RATE NOTE: Uses 2024 FORM4B certified rates. Confluence IK/16547841 used
--    2026 DLGF certified rates; dollar totals will differ until FORM4B 2026 loads.
--    Note: reconcile Confluence total $110,999 vs $110,989 in KAN-140.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_BPP_LOSS AS
WITH cert_nav_deduped AS (
    SELECT
        TRIM(budget_year)                       AS budget_year,
        TRIM(county_number)                     AS county_number,
        TRIM(tax_district_code)                 AS tax_district_code,
        TRIM(tax_district_name)                 AS tax_district_name,
        TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)    AS bus_pp_net_av
    FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
    WHERE UPPER(TRIM(tax_district_name)) LIKE '%TWP%'
       OR UPPER(TRIM(tax_district_name)) LIKE '% TOWNSHIP%'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(budget_year), TRIM(county_number), TRIM(tax_district_code)
        ORDER BY TRIM(tax_district_name)
    ) = 1
),
district_township_map AS (
    -- Aggregate parcel view to district level to get township + fire rate mapping
    SELECT DISTINCT
        county_number, tax_district_code, township_number, township_name, fire_rate_per_100
    FROM HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_RATE
)
SELECT
    cn.budget_year                                                  AS pay_year,
    cn.county_number,
    cn.tax_district_code,
    cn.tax_district_name,
    dtm.township_number,
    dtm.township_name,
    ROUND(cn.bus_pp_net_av)                                        AS bpp_nav,
    ROUND(dtm.fire_rate_per_100, 6)                                AS fire_rate_per_100,
    ROUND(cn.bus_pp_net_av * COALESCE(dtm.fire_rate_per_100, 0) / 100, 2) AS bpp_annual_loss,
    'VERIFIED'                                                     AS provenance
FROM cert_nav_deduped cn
LEFT JOIN district_township_map dtm
    ON cn.county_number = dtm.county_number
    AND cn.tax_district_code = dtm.tax_district_code
WHERE cn.budget_year = '2025';


-- ══════════════════════════════════════════════════════════════════════════════
-- 3. SEA1_HOMESTEAD_LOSS  (KAN-138)
--    Per-parcel homestead deduction delta × fire rate, rolled up to township × year.
--    Uses parcel-grain because standard deduction caps per parcel (not aggregate).
--    Statewide; 2025 vintage only per cap-class reliability rule.
--
--    Deduction formulas (ESTIMATES — verify against HEA 1001 2024):
--      Standard ded = LEAST(0.60 × homestead_av, std_ded_cap)
--      Net AV after std = homestead_av - standard_ded
--      Supplemental ded = 0.35 × LEAST(net_av, 600K) + 0.25 × MAX(net_av - 600K, 0)
--      AV delta = (new_std_ded - old_std_ded) + (new_supp_ded - old_supp_ded)
--      Fire loss = AV_delta × fire_rate / 100
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_HOMESTEAD_LOSS AS
WITH params AS (
    -- Pivot parameter rows into columns per phase year for efficiency
    SELECT
        phase_year,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN param_value END) AS std_ded_cap_new,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN old_law_value END) AS std_ded_cap_old,
        MAX(CASE WHEN param_name = 'STD_DED_PCT'     THEN param_value END) AS std_ded_pct,
        MAX(CASE WHEN param_name = 'SUPP_RATE_TIER1' THEN param_value END) AS supp_r1,
        MAX(CASE WHEN param_name = 'SUPP_THRESHOLD'  THEN param_value END) AS supp_thresh,
        MAX(CASE WHEN param_name = 'SUPP_RATE_TIER2' THEN param_value END) AS supp_r2,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN verified END)    AS params_verified
    FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD'
    GROUP BY phase_year
),
parcel_base AS (
    SELECT
        county_number, county_description, township_number, township_name,
        homestead_av,
        COALESCE(fire_rate_per_100, 0) AS fire_rate_per_100
    FROM HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_RATE
    WHERE homestead_av > 0
)
SELECT
    p.county_number,
    p.county_description,
    p.township_number,
    p.township_name,
    pr.phase_year,
    COUNT(*)                                                            AS homestead_parcel_count,
    -- Old law deductions
    ROUND(SUM(LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old))) AS total_old_std_ded,
    ROUND(SUM(
        pr.supp_r1 * LEAST(GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old), 0), pr.supp_thresh)
        + pr.supp_r2 * GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old) - pr.supp_thresh, 0)
    ))                                                                  AS total_old_supp_ded,
    -- SEA-1 deductions
    ROUND(SUM(LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new))) AS total_new_std_ded,
    ROUND(SUM(
        pr.supp_r1 * LEAST(GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new), 0), pr.supp_thresh)
        + pr.supp_r2 * GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new) - pr.supp_thresh, 0)
    ))                                                                  AS total_new_supp_ded,
    -- AV delta (taxable base removed)
    ROUND(SUM(
        (LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new) - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old))
        + (
            pr.supp_r1 * LEAST(GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new), 0), pr.supp_thresh)
            + pr.supp_r2 * GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new) - pr.supp_thresh, 0)
            - pr.supp_r1 * LEAST(GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old), 0), pr.supp_thresh)
            - pr.supp_r2 * GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old) - pr.supp_thresh, 0)
          )
    ))                                                                  AS homestead_av_delta,
    -- Dollar fire levy loss
    ROUND(SUM(
        (
            (LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new) - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old))
            + (
                pr.supp_r1 * LEAST(GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new), 0), pr.supp_thresh)
                + pr.supp_r2 * GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_new) - pr.supp_thresh, 0)
                - pr.supp_r1 * LEAST(GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old), 0), pr.supp_thresh)
                - pr.supp_r2 * GREATEST(p.homestead_av - LEAST(pr.std_ded_pct * p.homestead_av, pr.std_ded_cap_old) - pr.supp_thresh, 0)
              )
        ) * p.fire_rate_per_100 / 100
    ), 2)                                                               AS homestead_fire_loss,
    CASE WHEN pr.params_verified THEN 'VERIFIED' ELSE 'ESTIMATED' END  AS provenance
FROM parcel_base p
CROSS JOIN params pr
GROUP BY
    p.county_number, p.county_description, p.township_number,
    p.township_name, pr.phase_year, pr.params_verified
ORDER BY p.county_number, p.township_name, pr.phase_year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 4. SEA1_2PCT_BUCKET_LOSS  (KAN-141)
--    Phased AV deduction for all 2%-cap property × fire rate.
--    Reuses PARCEL_DISTRICT_RATE and SEA1_DEDUCTION_PARAMS (no new plumbing).
--    Statewide; 2025 vintage per baseline rule.
--    Verify statutory coverage (farmland, mobile home, apartments, LTC) vs HEA 1001.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_2PCT_BUCKET_LOSS AS
WITH bucket_params AS (
    SELECT
        phase_year,
        param_value   AS bucket_ded_pct,
        verified      AS params_verified
    FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = '2PCT_BUCKET'
      AND param_name = 'BUCKET_DED_PCT'
),
parcel_base AS (
    SELECT
        county_number, county_description, township_number, township_name,
        two_pct_av,
        COALESCE(fire_rate_per_100, 0) AS fire_rate_per_100
    FROM HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_RATE
    WHERE two_pct_av > 0
)
SELECT
    p.county_number,
    p.county_description,
    p.township_number,
    p.township_name,
    bp.phase_year,
    COUNT(*)                                                              AS two_pct_parcel_count,
    ROUND(SUM(p.two_pct_av))                                             AS total_two_pct_av,
    ROUND(bp.bucket_ded_pct, 6)                                          AS bucket_ded_pct,
    ROUND(SUM(p.two_pct_av * bp.bucket_ded_pct))                        AS two_pct_av_delta,
    ROUND(SUM(p.two_pct_av * bp.bucket_ded_pct * p.fire_rate_per_100 / 100), 2) AS two_pct_fire_loss,
    CASE WHEN bp.params_verified THEN 'VERIFIED' ELSE 'ESTIMATED' END    AS provenance
FROM parcel_base p
CROSS JOIN bucket_params bp
GROUP BY
    p.county_number, p.county_description, p.township_number,
    p.township_name, bp.phase_year, bp.bucket_ded_pct, bp.params_verified
ORDER BY p.county_number, p.township_name, bp.phase_year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 5. FIRE_COST_TREND  (KAN-139)
--    Cleaned operating CAGR per township, 2011–2024 actuals + 2025–2029 projection.
--    Full history: 2020+ from RAW.GATEWAY_DISBURSEMENTS (cleaned, authoritative);
--    2011–2019 from RAW.GATEWAY_DISBURSEMENTS_LEGACY. The legacy table's fields
--    are double-quote-wrapped and space-padded (REPLACE+TRIM), and two columns
--    map differently: fund_name -> unit_fund_name, class_name -> disburse_class_name.
--    CAGR runs over the full span (first observed year -> 2024).
--    Transfer exclusion rule (MANDATORY):
--      Exclude CLASS_NAME = 'Other Disbursements' AND DISBURSE_NAME LIKE 'Transfer Out%'
--      Harrison 2024 without exclusion: ~$943K; with exclusion: ~$549K (correct).
--    Capital (CUMULATIVE FIRE) tracked separately as replacement reserve — not in CAGR.
--    Statewide; fire funds identified by '%FIRE%' in fund_name.
--    LOW_CONFIDENCE when: fewer than 4 clean years; full-span |CAGR| > 25%; no 2024
--    actual; or 2024 collapses to < 40% of the series median (e.g. Wayne moved
--    fire service out — 2024 $7.5K vs $70.5K median).
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.FIRE_COST_TREND AS
WITH operating AS (
    -- Operating fire disbursements with transfer exclusion.
    -- 2020+ : current cleaned table.
    SELECT
        YEAR::INTEGER                                              AS year,
        TRIM(cnty_description)                                     AS county_description,
        TRIM(unit_name)                                            AS township,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(amount, ',', ''))))        AS operating_cost
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE afr_unit_type = '7'
      AND YEAR::INTEGER >= 2020
      AND UPPER(fund_name) LIKE '%FIRE%'
      AND UPPER(fund_name) NOT LIKE '%CUMULATIVE FIRE%'
      AND UPPER(fund_name) NOT LIKE '%FIRE BUILDING%'
      AND NOT (
          UPPER(class_name) = 'OTHER DISBURSEMENTS'
          AND UPPER(disburse_name) LIKE 'TRANSFER OUT%'
      )
    GROUP BY YEAR::INTEGER, TRIM(cnty_description), TRIM(unit_name)
    UNION ALL
    -- 2011-2019 : legacy table (quote-wrapped + space-padded fields;
    -- fund_name -> unit_fund_name, class_name -> disburse_class_name).
    SELECT
        TRIM(REPLACE(year, '"', ''))::INTEGER                      AS year,
        TRIM(REPLACE(cnty_description, '"', ''))                   AS county_description,
        TRIM(REPLACE(unit_name, '"', ''))                          AS township,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(amount, '"', ''), ',', '')))) AS operating_cost
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
    WHERE TRIM(REPLACE(afr_unit_type, '"', '')) = '7'
      AND TRIM(REPLACE(year, '"', ''))::INTEGER BETWEEN 2011 AND 2019
      AND UPPER(REPLACE(unit_fund_name, '"', '')) LIKE '%FIRE%'
      AND UPPER(REPLACE(unit_fund_name, '"', '')) NOT LIKE '%CUMULATIVE FIRE%'
      AND UPPER(REPLACE(unit_fund_name, '"', '')) NOT LIKE '%FIRE BUILDING%'
      AND NOT (
          UPPER(TRIM(REPLACE(disburse_class_name, '"', ''))) = 'OTHER DISBURSEMENTS'
          AND UPPER(TRIM(REPLACE(disburse_name, '"', ''))) LIKE 'TRANSFER OUT%'
      )
    GROUP BY 1, 2, 3
),
cumulative_fire AS (
    -- Capital / replacement reserve (kept separate from operating)
    SELECT
        YEAR::INTEGER                                              AS year,
        TRIM(cnty_description)                                     AS county_description,
        TRIM(unit_name)                                            AS township,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(amount, ',', ''))))        AS replacement_reserve
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE afr_unit_type = '7'
      AND YEAR::INTEGER >= 2020
      AND (fund_code IN ('1190', '8190') OR UPPER(fund_name) LIKE '%CUMULATIVE FIRE%')
    GROUP BY YEAR::INTEGER, TRIM(cnty_description), TRIM(unit_name)
    UNION ALL
    SELECT
        TRIM(REPLACE(year, '"', ''))::INTEGER                      AS year,
        TRIM(REPLACE(cnty_description, '"', ''))                   AS county_description,
        TRIM(REPLACE(unit_name, '"', ''))                          AS township,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(amount, '"', ''), ',', '')))) AS replacement_reserve
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
    WHERE TRIM(REPLACE(afr_unit_type, '"', '')) = '7'
      AND TRIM(REPLACE(year, '"', ''))::INTEGER BETWEEN 2011 AND 2019
      AND (TRIM(REPLACE(fund_code, '"', '')) IN ('1190', '8190')
           OR UPPER(REPLACE(unit_fund_name, '"', '')) LIKE '%CUMULATIVE FIRE%')
    GROUP BY 1, 2, 3
),
series AS (
    SELECT
        o.county_description,
        o.township,
        o.year,
        o.operating_cost,
        COALESCE(cf.replacement_reserve, 0)                       AS replacement_reserve
    FROM operating o
    LEFT JOIN cumulative_fire cf
        ON o.county_description = cf.county_description
        AND o.township = cf.township
        AND o.year = cf.year
    WHERE o.year BETWEEN 2011 AND 2024
      AND o.operating_cost > 0
),
cagr_calc AS (
    SELECT
        county_description,
        township,
        COUNT(DISTINCT year)                                       AS years_of_data,
        MIN(year)                                                  AS first_year,
        MAX(year)                                                  AS last_year,
        MIN(CASE WHEN year = (SELECT MIN(year) FROM series s2
                              WHERE s2.county_description = s.county_description
                                AND s2.township = s.township)
                 THEN operating_cost END)                          AS first_year_cost,
        MAX(CASE WHEN year = 2024 THEN operating_cost END)        AS cost_2024,
        MEDIAN(operating_cost)                                     AS median_cost,
        AVG(replacement_reserve)                                   AS avg_replacement_reserve,
        -- Actuals exposed as year columns (full 2011-2024 history)
        MAX(CASE WHEN year = 2011 THEN operating_cost END)        AS cost_2011,
        MAX(CASE WHEN year = 2012 THEN operating_cost END)        AS cost_2012,
        MAX(CASE WHEN year = 2013 THEN operating_cost END)        AS cost_2013,
        MAX(CASE WHEN year = 2014 THEN operating_cost END)        AS cost_2014,
        MAX(CASE WHEN year = 2015 THEN operating_cost END)        AS cost_2015,
        MAX(CASE WHEN year = 2016 THEN operating_cost END)        AS cost_2016,
        MAX(CASE WHEN year = 2017 THEN operating_cost END)        AS cost_2017,
        MAX(CASE WHEN year = 2018 THEN operating_cost END)        AS cost_2018,
        MAX(CASE WHEN year = 2019 THEN operating_cost END)        AS cost_2019,
        MAX(CASE WHEN year = 2020 THEN operating_cost END)        AS cost_2020,
        MAX(CASE WHEN year = 2021 THEN operating_cost END)        AS cost_2021,
        MAX(CASE WHEN year = 2022 THEN operating_cost END)        AS cost_2022,
        MAX(CASE WHEN year = 2023 THEN operating_cost END)        AS cost_2023
    FROM series s
    GROUP BY county_description, township
),
with_cagr AS (
    SELECT
        *,
        CASE
            WHEN first_year_cost > 0 AND cost_2024 > 0 AND (last_year - first_year) > 0
            THEN POWER(cost_2024 / first_year_cost, 1.0 / (last_year - first_year)) - 1
            ELSE NULL
        END                                                        AS operating_cagr
    FROM cagr_calc
)
SELECT
    w.county_description,
    w.township,
    w.years_of_data,
    w.first_year,
    w.last_year,
    ROUND(w.first_year_cost)                                       AS first_year_operating,
    ROUND(w.cost_2024)                                             AS cost_2024_operating,
    ROUND(w.avg_replacement_reserve)                               AS avg_replacement_reserve,
    ROUND(w.operating_cagr * 100, 2)                               AS operating_cagr_pct,
    -- Actuals (full 2011-2024 history)
    w.cost_2011, w.cost_2012, w.cost_2013, w.cost_2014, w.cost_2015,
    w.cost_2016, w.cost_2017, w.cost_2018, w.cost_2019, w.cost_2020,
    w.cost_2021, w.cost_2022, w.cost_2023,
    w.cost_2024                                                    AS cost_2024_actual,
    -- Projections 2025-2029
    ROUND(w.cost_2024 * POWER(1 + COALESCE(w.operating_cagr, 0), 1)) AS proj_2025,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(w.operating_cagr, 0), 2)) AS proj_2026,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(w.operating_cagr, 0), 3)) AS proj_2027,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(w.operating_cagr, 0), 4)) AS proj_2028,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(w.operating_cagr, 0), 5)) AS proj_2029,
    CASE
        WHEN w.years_of_data < 4                       THEN 'LOW_CONFIDENCE — fewer than 4 years'
        WHEN w.cost_2024 IS NULL                       THEN 'LOW_CONFIDENCE — no 2024 actual'
        WHEN ABS(w.operating_cagr) > 0.25              THEN 'LOW_CONFIDENCE — CAGR > 25%'
        WHEN w.cost_2024 < 0.4 * w.median_cost         THEN 'LOW_CONFIDENCE — 2024 collapse vs median'
        ELSE 'OK'
    END                                                            AS confidence_flag
FROM with_cagr w
ORDER BY county_description, township;


-- ══════════════════════════════════════════════════════════════════════════════
-- 6. SEA1_FIRE_IMPACT_SUMMARY  (KAN-140)
--    Single output view per township × phase year.
--    Provenance flags per column — ESTIMATED/TBD columns ship in v1.
--    The 2%-bucket column is ESTIMATED/TBD until KAN-141 parameters are verified.
--    Keyed on county_number + township_number for statewide extension.
--    Reconcile $110,999 (BPP table) vs $110,989 (exec summary) in Bartholomew
--    totals — fix at source here (KAN-140 acceptance criterion).
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY AS
WITH townships AS (
    SELECT DISTINCT
        county_number, county_description, township_number, township_name
    FROM HOOSIER_DATA.ANALYTICS.PARCEL_DISTRICT_RATE
    -- Exclude parcels in abolished civil townships (absorbed by municipalities;
    -- no DLGF township code, city fire service, no fire levy).
    WHERE township_name IS NOT NULL AND township_name != ''
),
phase_years AS (
    SELECT DISTINCT phase_year FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE phase_year BETWEEN 2026 AND 2031
),
bpp AS (
    SELECT
        county_number, township_number, township_name,
        SUM(bpp_annual_loss) AS bpp_loss
    FROM HOOSIER_DATA.ANALYTICS.SEA1_BPP_LOSS
    GROUP BY 1, 2, 3
),
homestead AS (
    SELECT
        county_number, township_number, phase_year,
        homestead_fire_loss,
        homestead_av_delta,
        homestead_parcel_count,
        provenance AS hs_provenance
    FROM HOOSIER_DATA.ANALYTICS.SEA1_HOMESTEAD_LOSS
),
two_pct AS (
    SELECT
        county_number, township_number, phase_year,
        two_pct_fire_loss,
        two_pct_av_delta,
        provenance AS two_pct_provenance
    FROM HOOSIER_DATA.ANALYTICS.SEA1_2PCT_BUCKET_LOSS
),
cost AS (
    -- Join cost trend via county_description + township name
    SELECT
        t.county_number,
        t.township_number,
        fc.operating_cagr_pct,
        fc.proj_2026, fc.proj_2027, fc.proj_2028, fc.proj_2029,
        fc.avg_replacement_reserve,
        fc.confidence_flag
    FROM HOOSIER_DATA.ANALYTICS.FIRE_COST_TREND fc
    JOIN townships t
        ON UPPER(fc.county_description) = UPPER(t.county_description)
        AND UPPER(fc.township) = UPPER(t.township_name)
),
levy AS (
    -- Current baseline fire levy from FORM4B
    SELECT
        TRIM(cnty_cd)   AS county_number,
        TRIM(unit_name) AS unit_name,
        SUM(net_tax_rate_adopted_num * net_assessed_valuation_num / 100) AS fire_levy_2024
    FROM HOOSIER_DATA.ANALYTICS.FORM4B_CLEAN
    WHERE unit_type = '2'
      AND UPPER(fund_description) LIKE '%FIRE%'
      AND year_num = 2024
    GROUP BY 1, 2
)
SELECT
    t.county_number,
    t.county_description,
    t.township_number,
    t.township_name,
    py.phase_year,
    -- Baseline
    ROUND(lv.fire_levy_2024)                                      AS fire_levy_2024,
    -- BPP loss (VERIFIED)
    ROUND(b.bpp_loss)                                             AS bpp_loss,
    'VERIFIED'                                                    AS bpp_provenance,
    -- Homestead loss
    ROUND(h.homestead_fire_loss)                                  AS homestead_loss,
    h.hs_provenance                                               AS homestead_provenance,
    -- 2%-bucket loss (ESTIMATED/TBD until KAN-141 verified)
    ROUND(tp.two_pct_fire_loss)                                   AS two_pct_loss,
    COALESCE(tp.two_pct_provenance, 'ESTIMATED/TBD')              AS two_pct_provenance,
    -- Total SEA-1 loss
    ROUND(COALESCE(b.bpp_loss, 0)
        + COALESCE(h.homestead_fire_loss, 0)
        + COALESCE(tp.two_pct_fire_loss, 0))                      AS total_sea1_loss,
    -- Cost projections
    CASE py.phase_year
        WHEN 2026 THEN c.proj_2026
        WHEN 2027 THEN c.proj_2027
        WHEN 2028 THEN c.proj_2028
        WHEN 2029 THEN c.proj_2029
        ELSE NULL
    END                                                           AS projected_operating_cost,
    ROUND(c.avg_replacement_reserve)                              AS avg_replacement_reserve,
    ROUND(c.operating_cagr_pct, 2)                                AS operating_cagr_pct,
    c.confidence_flag                                             AS cost_confidence,
    -- Net gap (positive = shortfall)
    ROUND(
        COALESCE(b.bpp_loss, 0)
        + COALESCE(h.homestead_fire_loss, 0)
        + COALESCE(tp.two_pct_fire_loss, 0)
        + CASE py.phase_year
              WHEN 2026 THEN COALESCE(c.proj_2026, 0) - COALESCE(lv.fire_levy_2024, 0)
              WHEN 2027 THEN COALESCE(c.proj_2027, 0) - COALESCE(lv.fire_levy_2024, 0)
              WHEN 2028 THEN COALESCE(c.proj_2028, 0) - COALESCE(lv.fire_levy_2024, 0)
              WHEN 2029 THEN COALESCE(c.proj_2029, 0) - COALESCE(lv.fire_levy_2024, 0)
              ELSE 0
          END
    )                                                             AS projected_net_gap,
    -- Parcel / AV diagnostics
    h.homestead_parcel_count,
    ROUND(h.homestead_av_delta)                                   AS homestead_av_delta,
    ROUND(tp.two_pct_av_delta)                                    AS two_pct_av_delta
FROM townships t
CROSS JOIN phase_years py
LEFT JOIN bpp b
    ON t.county_number = b.county_number AND t.township_number = b.township_number
LEFT JOIN homestead h
    ON t.county_number = h.county_number AND t.township_number = h.township_number
    AND h.phase_year = py.phase_year
LEFT JOIN two_pct tp
    ON t.county_number = tp.county_number AND t.township_number = tp.township_number
    AND tp.phase_year = py.phase_year
LEFT JOIN cost c
    ON t.county_number = c.county_number AND t.township_number = c.township_number
LEFT JOIN levy lv
    ON t.county_number = lv.county_number AND UPPER(t.township_name) = UPPER(lv.unit_name)
ORDER BY t.county_number, t.township_name, py.phase_year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 7. FIRE_REVENUE_TREND  (KAN-126)
--    Actual fire fund receipts by township × year × revenue source.
--    Combines GATEWAY_RECEIPTS (2021+) + GATEWAY_RECEIPTS_LEGACY (2011-2020).
--    Statewide; covers all receipt types into fire-related funds.
--    Revenue source grouping:
--      property_tax  — R101 General Property Taxes
--      vehicle_excise — R114 Vehicle/Aircraft Excise + R135 CVET
--      lit_shares     — R138 LIT Certified Shares + R123 LIT PTRC + R139 LIT Public Safety
--      investment     — R902 Earnings on Investments
--      other          — everything else (refunds, transfers in, etc.)
--    Transfer-in receipts (R910) excluded — accounting artifacts like the
--    Harrison 2024 $393K inter-fund transfer already excluded from disbursements.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.FIRE_REVENUE_TREND AS
WITH modern AS (
    SELECT
        YEAR::INTEGER                                                             AS year,
        TRIM(cnty_description)                                                    AS county_description,
        TRIM(unit_name)                                                           AS township,
        TRIM(fund_name)                                                           AS fund_name,
        receipt_code,
        TRIM(receipt_name)                                                        AS receipt_name,
        TRY_TO_DOUBLE(REPLACE(amount, ',', ''))                                   AS amount
    FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS
    WHERE afr_unit_type = '7'
      AND UPPER(fund_name) LIKE '%FIRE%'
      AND receipt_code != 'R910'  -- exclude inter-fund transfers
),
legacy AS (
    SELECT
        TRIM(REPLACE(year, '"', ''))::INTEGER                                     AS year,
        TRIM(REPLACE(cnty_description, '"', ''))                                  AS county_description,
        TRIM(REPLACE(unit_name, '"', ''))                                         AS township,
        TRIM(REPLACE(unit_fund_name, '"', ''))                                    AS fund_name,
        TRIM(REPLACE(receipt_code, '"', ''))                                      AS receipt_code,
        TRIM(REPLACE(receipt_name, '"', ''))                                      AS receipt_name,
        TRY_TO_DOUBLE(REPLACE(REPLACE(amount, '"', ''), ',', ''))                 AS amount
    FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_LEGACY
    WHERE TRIM(REPLACE(afr_unit_type, '"', '')) = '7'
      AND UPPER(TRIM(REPLACE(unit_fund_name, '"', ''))) LIKE '%FIRE%'
      AND TRIM(REPLACE(year, '"', ''))::INTEGER < 2021
      AND TRIM(REPLACE(receipt_code, '"', '')) != 'R910'
),
combined AS (
    SELECT * FROM modern
    UNION ALL
    SELECT * FROM legacy
)
SELECT
    county_description,
    township,
    year,
    ROUND(SUM(CASE WHEN receipt_code = 'R101'
                   THEN amount ELSE 0 END))                                       AS property_tax,
    ROUND(SUM(CASE WHEN receipt_code IN ('R114', 'R135')
                   THEN amount ELSE 0 END))                                       AS vehicle_excise,
    ROUND(SUM(CASE WHEN receipt_code IN ('R138', 'R123', 'R139', 'R142')
                   THEN amount ELSE 0 END))                                       AS lit_and_ptrc,
    ROUND(SUM(CASE WHEN receipt_code = 'R902'
                   THEN amount ELSE 0 END))                                       AS investment_income,
    ROUND(SUM(CASE WHEN receipt_code NOT IN ('R101','R114','R135','R138','R123','R139','R142','R902')
                   THEN amount ELSE 0 END))                                       AS other_receipts,
    ROUND(SUM(amount))                                                            AS total_fire_revenue,
    -- Fund breakdown
    ROUND(SUM(CASE WHEN UPPER(fund_name) LIKE '%CUMULATIVE FIRE%'
                   THEN amount ELSE 0 END))                                       AS cumulative_fire_revenue,
    ROUND(SUM(CASE WHEN UPPER(fund_name) NOT LIKE '%CUMULATIVE FIRE%'
                        AND UPPER(fund_name) NOT LIKE '%FIRE BUILDING%'
                   THEN amount ELSE 0 END))                                       AS operating_fire_revenue
FROM combined
GROUP BY county_description, township, year
ORDER BY county_description, township, year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 8. FIRE_COST_TREND_DISTRICT  (KAN-165)
--    Operating cost CAGR for type-6 fire protection district units.
--    Mirrors FIRE_COST_TREND but uses budget_unit_type='6'. Only modern Gateway
--    data available (2020+); no legacy table coverage for districts.
--    LOW_CONFIDENCE when < 3 clean years or no 2024 actual.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.FIRE_COST_TREND_DISTRICT AS
WITH operating AS (
    SELECT
        YEAR::INTEGER                                              AS year,
        TRIM(cnty_description)                                     AS county_description,
        TRIM(unit_code)                                            AS unit_code,
        TRIM(unit_name)                                            AS unit_name,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(amount, ',', ''))))        AS operating_cost
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE budget_unit_type = '6'
      AND (UPPER(unit_name) LIKE '%FIRE%' OR UPPER(unit_name) LIKE '%RESCUE%')
      AND YEAR::INTEGER BETWEEN 2020 AND 2024
      -- Scope to operating funds; fire districts use either fire-specific names
      -- (SPECL FIRE GENERAL) or generic names (General Fund) — filter by exclusion.
      AND UPPER(fund_name) NOT LIKE '%CUMULATIVE%'
      AND UPPER(fund_name) NOT LIKE '%RAINY DAY%'
      AND UPPER(fund_name) NOT LIKE '%DEBT%'
      AND UPPER(fund_name) NOT LIKE '%CAPITAL%'
      AND UPPER(fund_name) NOT LIKE '%INVESTMENT%'
      AND UPPER(fund_name) NOT LIKE '%BUILDING%'
      AND NOT (
          UPPER(class_name) = 'OTHER DISBURSEMENTS'
          AND UPPER(disburse_name) LIKE 'TRANSFER OUT%'
      )
    GROUP BY YEAR::INTEGER, TRIM(cnty_description), TRIM(unit_code), TRIM(unit_name)
),
series AS (
    SELECT *, MIN(year) OVER (PARTITION BY county_description, unit_code) AS min_year
    FROM operating
    WHERE operating_cost > 0
),
cagr_calc AS (
    SELECT
        county_description,
        unit_code,
        unit_name,
        COUNT(DISTINCT year)                                                    AS years_of_data,
        MIN(year)                                                               AS first_year,
        MAX(year)                                                               AS last_year,
        MIN(CASE WHEN year = min_year THEN operating_cost END)                  AS first_year_cost,
        MAX(CASE WHEN year = 2024 THEN operating_cost END)                      AS cost_2024,
        MEDIAN(operating_cost)                                                  AS median_cost,
        MAX(CASE WHEN year = 2020 THEN operating_cost END)                      AS cost_2020,
        MAX(CASE WHEN year = 2021 THEN operating_cost END)                      AS cost_2021,
        MAX(CASE WHEN year = 2022 THEN operating_cost END)                      AS cost_2022,
        MAX(CASE WHEN year = 2023 THEN operating_cost END)                      AS cost_2023
    FROM series
    GROUP BY county_description, unit_code, unit_name
)
SELECT
    w.county_description,
    w.unit_code,
    w.unit_name,
    w.years_of_data,
    w.first_year,
    w.last_year,
    ROUND(w.first_year_cost)                                                    AS first_year_operating,
    ROUND(w.cost_2024)                                                          AS cost_2024_operating,
    ROUND(CASE
        WHEN w.first_year_cost > 0 AND w.cost_2024 > 0 AND (w.last_year - w.first_year) > 0
        THEN (POWER(w.cost_2024 / w.first_year_cost, 1.0 / (w.last_year - w.first_year)) - 1) * 100
        ELSE NULL
    END, 2)                                                                     AS operating_cagr_pct,
    w.cost_2020, w.cost_2021, w.cost_2022, w.cost_2023,
    w.cost_2024                                                                 AS cost_2024_actual,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(
        CASE WHEN w.first_year_cost > 0 AND w.cost_2024 > 0 AND (w.last_year - w.first_year) > 0
             THEN POWER(w.cost_2024 / w.first_year_cost, 1.0 / (w.last_year - w.first_year)) - 1
             ELSE 0 END, 0), 1))                                                AS proj_2025,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(
        CASE WHEN w.first_year_cost > 0 AND w.cost_2024 > 0 AND (w.last_year - w.first_year) > 0
             THEN POWER(w.cost_2024 / w.first_year_cost, 1.0 / (w.last_year - w.first_year)) - 1
             ELSE 0 END, 0), 2))                                                AS proj_2026,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(
        CASE WHEN w.first_year_cost > 0 AND w.cost_2024 > 0 AND (w.last_year - w.first_year) > 0
             THEN POWER(w.cost_2024 / w.first_year_cost, 1.0 / (w.last_year - w.first_year)) - 1
             ELSE 0 END, 0), 3))                                                AS proj_2027,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(
        CASE WHEN w.first_year_cost > 0 AND w.cost_2024 > 0 AND (w.last_year - w.first_year) > 0
             THEN POWER(w.cost_2024 / w.first_year_cost, 1.0 / (w.last_year - w.first_year)) - 1
             ELSE 0 END, 0), 4))                                                AS proj_2028,
    ROUND(w.cost_2024 * POWER(1 + COALESCE(
        CASE WHEN w.first_year_cost > 0 AND w.cost_2024 > 0 AND (w.last_year - w.first_year) > 0
             THEN POWER(w.cost_2024 / w.first_year_cost, 1.0 / (w.last_year - w.first_year)) - 1
             ELSE 0 END, 0), 5))                                                AS proj_2029,
    CASE
        WHEN w.years_of_data < 3     THEN 'LOW_CONFIDENCE — fewer than 3 years'
        WHEN w.cost_2024 IS NULL     THEN 'LOW_CONFIDENCE — no 2024 actual'
        ELSE 'OK'
    END                                                                         AS confidence_flag
FROM cagr_calc w
ORDER BY county_description, unit_name;


-- ══════════════════════════════════════════════════════════════════════════════
-- 9. SEA1_FIRE_DISTRICT_IMPACT  (KAN-165)
--    Impact summary for type-6 fire protection district units, mirroring
--    SEA1_FIRE_IMPACT_SUMMARY. Grain: unit × phase_year.
--
--    Rate source: DLGF_TAX_DISTRICT_UNITS (budget_year 2025, unit_type_cd='6',
--      fire fund codes). Sum of all fire levy funds (general + cumulative +
--      debt) per (unit, tax_district); rainy day (0061) excluded.
--    BPP loss: CERT_NAV BPP AV × rate per tax district, summed to unit level.
--    Homestead/2%-bucket loss: GATEWAY_PARCEL parcels joined to unit territory
--      via state_district_number → tax_district_code, then deduction formula.
--    Levy baseline: rate × (real_est + BPP AV) per tax district, summed.
--    Cost trend: FIRE_COST_TREND_DISTRICT (2020-2024 only; no legacy data).
--
--    DLGF creates a separate tax_district_code per (fire district, township area)
--    so one parcel maps to at most one fire district — no double-count risk.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.SEA1_FIRE_DISTRICT_IMPACT AS
WITH
-- Fire rates: sum all fire levy funds per (county, unit, tax_district)
district_rates AS (
    SELECT
        county_number,
        unit_code,
        UPPER(TRIM(unit_name))                          AS unit_name,
        tax_district_code,
        SUM(TRY_TO_DOUBLE(certd_tax_rate_pct))          AS fire_rate_per_100
    FROM HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS
    WHERE budget_year = '2025'
      AND unit_type_cd = '6'
      -- Match on fund_name OR unit_name: some districts use fire-specific fund
      -- names (SPECL FIRE GENERAL), others use generic (General Fund).
      AND (UPPER(fund_name) LIKE '%FIRE%'
           OR UPPER(unit_name) LIKE '%FIRE%'
           OR UPPER(unit_name) LIKE '%RESCUE%')
      AND fund_code != '0061'
      AND TRY_TO_DOUBLE(certd_tax_rate_pct) > 0
    GROUP BY county_number, unit_code, unit_name, tax_district_code
),
-- CERT_NAV deduped (same pattern as existing views)
cert_nav AS (
    SELECT
        TRIM(budget_year)                       AS budget_year,
        TRIM(county_number)                     AS county_number,
        TRIM(tax_district_code)                 AS tax_district_code,
        TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)    AS bus_pp_net_av,
        TRY_TO_DECIMAL(real_est_net_av, 18, 0)  AS real_est_net_av
    FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(budget_year), TRIM(county_number), TRIM(tax_district_code)
        ORDER BY TRIM(tax_district_name)
    ) = 1
),
-- BPP loss per district unit
district_bpp AS (
    SELECT
        dr.county_number,
        dr.unit_code,
        ROUND(SUM(COALESCE(cn.bus_pp_net_av, 0)))                                       AS total_bpp_nav,
        ROUND(SUM(COALESCE(cn.bus_pp_net_av, 0) * dr.fire_rate_per_100 / 100), 2)      AS bpp_annual_loss
    FROM district_rates dr
    LEFT JOIN cert_nav cn
        ON dr.county_number = cn.county_number
        AND dr.tax_district_code = cn.tax_district_code
        AND cn.budget_year = '2025'
    GROUP BY dr.county_number, dr.unit_code
),
-- Baseline levy per district unit: rate × (real_est + BPP) AV per tax_district
district_levy AS (
    SELECT
        dr.county_number,
        dr.unit_code,
        ROUND(SUM(
            (COALESCE(cn.real_est_net_av, 0) + COALESCE(cn.bus_pp_net_av, 0))
            * dr.fire_rate_per_100 / 100
        ))                                                                              AS fire_levy_2025
    FROM district_rates dr
    LEFT JOIN cert_nav cn
        ON dr.county_number = cn.county_number
        AND dr.tax_district_code = cn.tax_district_code
        AND cn.budget_year = '2025'
    GROUP BY dr.county_number, dr.unit_code
),
-- Parcel AV within each district's territory (one row per parcel × unit)
district_parcel AS (
    SELECT
        dr.county_number,
        dr.unit_code,
        dr.fire_rate_per_100,
        COALESCE(TRY_TO_NUMBER(p.av_land_1pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_impr_1pct), 0)              AS homestead_av,
        COALESCE(TRY_TO_NUMBER(p.av_nonhs_res_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_nonhs_res_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_apt_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_apt_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_ltc_land_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_ltc_impr_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_farmland_2pct), 0)
            + COALESCE(TRY_TO_NUMBER(p.av_mobile_home_land_2pct), 0)  AS two_pct_av
    FROM HOOSIER_DATA.RAW.GATEWAY_PARCEL p
    JOIN district_rates dr
        ON TRIM(p.county_number) = dr.county_number
        AND LPAD(TRIM(p.state_district_number), 3, '0') = dr.tax_district_code
    WHERE p.pay_year = '2025'
),
-- Homestead deduction parameters (reuse from SEA1_DEDUCTION_PARAMS)
hs_params AS (
    SELECT
        phase_year,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN param_value END) AS std_ded_cap_new,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN old_law_value END) AS std_ded_cap_old,
        MAX(CASE WHEN param_name = 'STD_DED_PCT'     THEN param_value END) AS std_ded_pct,
        MAX(CASE WHEN param_name = 'SUPP_RATE_TIER1' THEN param_value END) AS supp_r1,
        MAX(CASE WHEN param_name = 'SUPP_THRESHOLD'  THEN param_value END) AS supp_thresh,
        MAX(CASE WHEN param_name = 'SUPP_RATE_TIER2' THEN param_value END) AS supp_r2,
        MAX(CASE WHEN param_name = 'STD_DED_CAP'     THEN verified END)    AS params_verified
    FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = 'HOMESTEAD'
    GROUP BY phase_year
),
bkt_params AS (
    SELECT phase_year, param_value AS bucket_ded_pct, verified AS params_verified
    FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE mechanism = '2PCT_BUCKET' AND param_name = 'BUCKET_DED_PCT'
),
-- Homestead loss per district × phase_year
district_homestead AS (
    SELECT
        dp.county_number,
        dp.unit_code,
        pr.phase_year,
        COUNT(*)                                                                AS homestead_parcel_count,
        ROUND(SUM(
            (LEAST(pr.std_ded_pct * dp.homestead_av, pr.std_ded_cap_new)
                - LEAST(pr.std_ded_pct * dp.homestead_av, pr.std_ded_cap_old)
            + pr.supp_r1 * LEAST(GREATEST(dp.homestead_av - LEAST(pr.std_ded_pct * dp.homestead_av, pr.std_ded_cap_new), 0), pr.supp_thresh)
            + pr.supp_r2 * GREATEST(dp.homestead_av - LEAST(pr.std_ded_pct * dp.homestead_av, pr.std_ded_cap_new) - pr.supp_thresh, 0)
            - pr.supp_r1 * LEAST(GREATEST(dp.homestead_av - LEAST(pr.std_ded_pct * dp.homestead_av, pr.std_ded_cap_old), 0), pr.supp_thresh)
            - pr.supp_r2 * GREATEST(dp.homestead_av - LEAST(pr.std_ded_pct * dp.homestead_av, pr.std_ded_cap_old) - pr.supp_thresh, 0)
            ) * dp.fire_rate_per_100 / 100
        ), 2)                                                                   AS homestead_fire_loss,
        CASE WHEN pr.params_verified THEN 'VERIFIED' ELSE 'ESTIMATED' END      AS hs_provenance
    FROM district_parcel dp
    CROSS JOIN hs_params pr
    WHERE dp.homestead_av > 0
    GROUP BY dp.county_number, dp.unit_code, pr.phase_year, pr.params_verified
),
-- 2%-bucket loss per district × phase_year
district_two_pct AS (
    SELECT
        dp.county_number,
        dp.unit_code,
        bp.phase_year,
        ROUND(SUM(dp.two_pct_av * bp.bucket_ded_pct * dp.fire_rate_per_100 / 100), 2) AS two_pct_fire_loss,
        CASE WHEN bp.params_verified THEN 'VERIFIED' ELSE 'ESTIMATED' END              AS two_pct_provenance
    FROM district_parcel dp
    CROSS JOIN bkt_params bp
    WHERE dp.two_pct_av > 0
    GROUP BY dp.county_number, dp.unit_code, bp.phase_year, bp.params_verified
),
phase_years AS (
    SELECT DISTINCT phase_year FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    WHERE phase_year BETWEEN 2026 AND 2031
),
districts AS (
    SELECT DISTINCT county_number, unit_code, unit_name FROM district_rates
)
SELECT
    d.county_number,
    d.unit_code,
    d.unit_name,
    py.phase_year,
    ROUND(lv.fire_levy_2025)                                                    AS fire_levy_2025,
    ROUND(b.bpp_annual_loss)                                                    AS bpp_loss,
    'VERIFIED'                                                                  AS bpp_provenance,
    ROUND(h.homestead_fire_loss)                                                AS homestead_loss,
    COALESCE(h.hs_provenance, 'ESTIMATED')                                      AS homestead_provenance,
    ROUND(tp.two_pct_fire_loss)                                                 AS two_pct_loss,
    COALESCE(tp.two_pct_provenance, 'ESTIMATED')                                AS two_pct_provenance,
    ROUND(COALESCE(b.bpp_annual_loss, 0)
        + COALESCE(h.homestead_fire_loss, 0)
        + COALESCE(tp.two_pct_fire_loss, 0))                                    AS total_sea1_loss,
    CASE py.phase_year
        WHEN 2026 THEN ct.proj_2026
        WHEN 2027 THEN ct.proj_2027
        WHEN 2028 THEN ct.proj_2028
        WHEN 2029 THEN ct.proj_2029
        ELSE NULL
    END                                                                         AS projected_operating_cost,
    ROUND(ct.operating_cagr_pct, 2)                                             AS operating_cagr_pct,
    ct.confidence_flag                                                          AS cost_confidence,
    h.homestead_parcel_count,
    b.total_bpp_nav
FROM districts d
CROSS JOIN phase_years py
LEFT JOIN district_bpp b
    ON b.county_number = d.county_number AND b.unit_code = d.unit_code
LEFT JOIN district_levy lv
    ON lv.county_number = d.county_number AND lv.unit_code = d.unit_code
LEFT JOIN district_homestead h
    ON h.county_number = d.county_number AND h.unit_code = d.unit_code
    AND h.phase_year = py.phase_year
LEFT JOIN district_two_pct tp
    ON tp.county_number = d.county_number AND tp.unit_code = d.unit_code
    AND tp.phase_year = py.phase_year
LEFT JOIN HOOSIER_DATA.ANALYTICS.FIRE_COST_TREND_DISTRICT ct
    ON ct.unit_code = d.unit_code AND ct.county_description = (
        SELECT MAX(cnty_description)
        FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
        WHERE TRIM(unit_code) = d.unit_code AND budget_unit_type = '6'
    )
ORDER BY d.county_number, d.unit_name, py.phase_year;


-- ══════════════════════════════════════════════════════════════════════════════
-- 10. COUNTY_FIRE_SERVICE_STRUCTURE  (KAN-165)
--     Classifies each Indiana county by how fire service is organized:
--       township_only  — township fire funds, no type-6 special units with levies
--       district_only  — type-6 special units only, no township fire levy (e.g. Crawford)
--       mixed          — both township fire funds and type-6 districts (e.g. Johnson)
--     Used by packet templates to branch the "shall" vs "may" framing under
--     IC 6-3.6-6-4.3 (districts = mandatory recipient) vs IC 6-3.6-6-4.5
--     (township VFDs = trustee-resolution path).
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.COUNTY_FIRE_SERVICE_STRUCTURE AS
WITH twp_counties AS (
    SELECT DISTINCT TRIM(cnty_cd) AS county_number
    FROM HOOSIER_DATA.ANALYTICS.FORM4B_CLEAN
    WHERE unit_type = '2'
      AND UPPER(fund_description) LIKE '%FIRE%'
      AND year_num = 2024
      AND net_tax_rate_adopted_num > 0
),
dist_counties AS (
    -- Type-6 fire/rescue units with a certified levy. Identify by unit_name
    -- (authoritative) rather than fund_name (varies: fire-specific vs generic).
    SELECT DISTINCT county_number
    FROM HOOSIER_DATA.RAW.DLGF_TAX_DISTRICT_UNITS
    WHERE budget_year = '2025'
      AND unit_type_cd = '6'
      AND (UPPER(unit_name) LIKE '%FIRE%' OR UPPER(unit_name) LIKE '%RESCUE%')
      AND TRY_TO_DOUBLE(certd_tax_rate_pct) > 0
),
all_counties AS (
    SELECT county_number FROM twp_counties
    UNION
    SELECT county_number FROM dist_counties
)
SELECT
    ac.county_number,
    CASE
        WHEN t.county_number IS NOT NULL AND d.county_number IS NOT NULL THEN 'mixed'
        WHEN t.county_number IS NOT NULL                                  THEN 'township_only'
        WHEN d.county_number IS NOT NULL                                  THEN 'district_only'
        ELSE 'unknown'
    END AS fire_service_structure,
    CASE WHEN d.county_number IS NOT NULL THEN 'TRUE' ELSE 'FALSE' END   AS has_mandatory_recipients,
    CASE WHEN t.county_number IS NOT NULL THEN 'TRUE' ELSE 'FALSE' END   AS has_discretionary_recipients
FROM all_counties ac
LEFT JOIN twp_counties t ON t.county_number = ac.county_number
LEFT JOIN dist_counties d ON d.county_number = ac.county_number
ORDER BY ac.county_number;
