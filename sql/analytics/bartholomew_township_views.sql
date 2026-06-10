-- ============================================================
-- Bartholomew County Township Trustee Dashboard - Analytics Views
-- Run as ACCOUNTADMIN in HOOSIER_DATA Snowflake account
-- ============================================================


-- ── REVENUE vs EXPENDITURE (2011-2024) ───────────────────────────────────────
--   Combines modern tables (2020+) with legacy tables (2011-2019/2020)
--   FULL OUTER JOIN so a township present in only one side is not dropped.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_REV_VS_EXP AS
WITH expenditures AS (
    SELECT
        YEAR::INTEGER                                              AS YEAR,
        TRIM(UNIT_NAME)                                           AS TOWNSHIP,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS EXPENDITURE
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND AFR_UNIT_TYPE = '7'
    GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME)

    UNION ALL

    SELECT
        TRIM(REPLACE(YEAR, '"', ''))::INTEGER                     AS YEAR,
        TRIM(REPLACE(UNIT_NAME, '"', ''))                         AS TOWNSHIP,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS EXPENDITURE
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
      AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2020
    GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER, TRIM(REPLACE(UNIT_NAME, '"', ''))
),
revenue AS (
    SELECT
        YEAR::INTEGER                                              AS YEAR,
        TRIM(UNIT_NAME)                                           AS TOWNSHIP,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS REVENUE
    FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND AFR_UNIT_TYPE = '7'
    GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME)

    UNION ALL

    SELECT
        TRIM(REPLACE(YEAR, '"', ''))::INTEGER                     AS YEAR,
        TRIM(REPLACE(UNIT_NAME, '"', ''))                         AS TOWNSHIP,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS REVENUE
    FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_LEGACY
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
      AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2021
    GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER, TRIM(REPLACE(UNIT_NAME, '"', ''))
)
SELECT
    COALESCE(e.YEAR, r.YEAR)                                      AS YEAR,
    COALESCE(e.TOWNSHIP, r.TOWNSHIP)                              AS TOWNSHIP,
    COALESCE(e.EXPENDITURE, 0)                                    AS EXPENDITURE,
    COALESCE(r.REVENUE, 0)                                        AS REVENUE,
    COALESCE(r.REVENUE, 0) - COALESCE(e.EXPENDITURE, 0)          AS SURPLUS_DEFICIT,
    CASE
        WHEN COALESCE(r.REVENUE, 0) >= COALESCE(e.EXPENDITURE, 0) THEN 'Surplus'
        ELSE 'Deficit'
    END AS FISCAL_STATUS
FROM expenditures e
FULL OUTER JOIN revenue r
    ON e.YEAR = r.YEAR AND e.TOWNSHIP = r.TOWNSHIP;


-- ── 2024 SNAPSHOT ────────────────────────────────────────────────────────────
--   Latest year snapshot for the bar chart on the right side of the Trends tab.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_2024_SNAPSHOT AS
SELECT
    TOWNSHIP,
    REVENUE,
    EXPENDITURE,
    SURPLUS_DEFICIT,
    FISCAL_STATUS,
    ROUND(SURPLUS_DEFICIT / NULLIF(REVENUE, 0) * 100, 1)          AS SURPLUS_PCT
FROM HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_REV_VS_EXP
WHERE YEAR = (
    SELECT MAX(YEAR) FROM HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_REV_VS_EXP
);


-- ── SPENDING BY CATEGORY (2011-2024) ─────────────────────────────────────────
--   Disbursement class breakdown (Personal Services, Capital, Supplies, etc.)

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_SPENDING_BY_CATEGORY AS
SELECT
    YEAR::INTEGER                                                  AS YEAR,
    TRIM(UNIT_NAME)                                               AS TOWNSHIP,
    CLASS_NAME                                                     AS CATEGORY,
    ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))            AS AMOUNT
FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
  AND AFR_UNIT_TYPE = '7'
GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME), CLASS_NAME

UNION ALL

SELECT
    TRIM(REPLACE(YEAR, '"', ''))::INTEGER                         AS YEAR,
    TRIM(REPLACE(UNIT_NAME, '"', ''))                             AS TOWNSHIP,
    TRIM(REPLACE(DISBURSE_CLASS_NAME, '"', ''))                   AS CATEGORY,
    ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS AMOUNT
FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
  AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
  AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2020
GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER, TRIM(REPLACE(UNIT_NAME, '"', '')), TRIM(REPLACE(DISBURSE_CLASS_NAME, '"', ''));


-- ── YEAR-OVER-YEAR EXPENDITURE GROWTH ────────────────────────────────────────

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_YOY_GROWTH AS
WITH base AS (
    SELECT
        YEAR::INTEGER                                              AS YEAR,
        TRIM(UNIT_NAME)                                           AS TOWNSHIP,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS EXPENDITURE
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND AFR_UNIT_TYPE = '7'
    GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME)

    UNION ALL

    SELECT
        TRIM(REPLACE(YEAR, '"', ''))::INTEGER                     AS YEAR,
        TRIM(REPLACE(UNIT_NAME, '"', ''))                         AS TOWNSHIP,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS EXPENDITURE
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
      AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2020
    GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER, TRIM(REPLACE(UNIT_NAME, '"', ''))
)
SELECT
    curr.YEAR,
    curr.TOWNSHIP,
    curr.EXPENDITURE,
    prev.EXPENDITURE                                              AS PRIOR_YEAR_EXP,
    ROUND(curr.EXPENDITURE - prev.EXPENDITURE)                   AS CHANGE,
    ROUND((curr.EXPENDITURE - prev.EXPENDITURE)
        / NULLIF(prev.EXPENDITURE, 0) * 100, 1)                  AS YOY_GROWTH_PCT
FROM base curr
LEFT JOIN base prev
    ON curr.TOWNSHIP = prev.TOWNSHIP
   AND curr.YEAR = prev.YEAR + 1
WHERE prev.EXPENDITURE IS NOT NULL;


-- ── COUNTY-WIDE SUMMARY ───────────────────────────────────────────────────────
--   Aggregate revenue, expenditure, and largest township by year.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_COUNTY_SUMMARY AS
WITH exp AS (
    SELECT
        YEAR::INTEGER                                              AS YEAR,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS TOTAL_EXPENDITURE,
        COUNT(DISTINCT TRIM(UNIT_NAME))                           AS TOWNSHIP_COUNT
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND AFR_UNIT_TYPE = '7'
    GROUP BY YEAR::INTEGER

    UNION ALL

    SELECT
        TRIM(REPLACE(YEAR, '"', ''))::INTEGER                     AS YEAR,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS TOTAL_EXPENDITURE,
        COUNT(DISTINCT TRIM(REPLACE(UNIT_NAME, '"', '')))         AS TOWNSHIP_COUNT
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
      AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2020
    GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER
),
rev AS (
    SELECT
        YEAR::INTEGER                                              AS YEAR,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS TOTAL_REVENUE
    FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND AFR_UNIT_TYPE = '7'
    GROUP BY YEAR::INTEGER

    UNION ALL

    SELECT
        TRIM(REPLACE(YEAR, '"', ''))::INTEGER                     AS YEAR,
        ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS TOTAL_REVENUE
    FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_LEGACY
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
      AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2021
    GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER
),
township_exp AS (
    SELECT YEAR, TOWNSHIP, SUM(EXPENDITURE) AS EXPENDITURE FROM (
        SELECT
            YEAR::INTEGER                                          AS YEAR,
            TRIM(UNIT_NAME)                                       AS TOWNSHIP,
            ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))   AS EXPENDITURE
        FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
        WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
          AND AFR_UNIT_TYPE = '7'
        GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME)

        UNION ALL

        SELECT
            TRIM(REPLACE(YEAR, '"', ''))::INTEGER                 AS YEAR,
            TRIM(REPLACE(UNIT_NAME, '"', ''))                     AS TOWNSHIP,
            ROUND(SUM(TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', ''))))  AS EXPENDITURE
        FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
        WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
          AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
          AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2020
        GROUP BY TRIM(REPLACE(YEAR, '"', ''))::INTEGER, TRIM(REPLACE(UNIT_NAME, '"', ''))
    )
    GROUP BY YEAR, TOWNSHIP
),
largest AS (
    SELECT YEAR, TOWNSHIP AS LARGEST_TOWNSHIP, EXPENDITURE AS LARGEST_EXPENDITURE
    FROM township_exp
    QUALIFY ROW_NUMBER() OVER (PARTITION BY YEAR ORDER BY EXPENDITURE DESC) = 1
)
SELECT
    e.YEAR,
    e.TOTAL_EXPENDITURE,
    r.TOTAL_REVENUE,
    r.TOTAL_REVENUE - e.TOTAL_EXPENDITURE                        AS COUNTY_SURPLUS_DEFICIT,
    e.TOWNSHIP_COUNT,
    l.LARGEST_TOWNSHIP,
    l.LARGEST_EXPENDITURE,
    ROUND(l.LARGEST_EXPENDITURE / NULLIF(e.TOTAL_EXPENDITURE, 0) * 100, 1) AS LARGEST_TWP_SHARE_PCT
FROM exp e
JOIN rev r ON e.YEAR = r.YEAR
JOIN largest l ON e.YEAR = l.YEAR;


-- ── TOWNSHIP ASSISTANCE FUND: ADMIN COST vs ASSISTANCE PAID ──────────────────
--   Flags townships where administrative overhead exceeds dollars delivered.
--   Personal Services in the Township Assistance fund = clerk/admin cost.
--   All other disbursements = assistance actually paid to residents.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_POOR_RELIEF AS
WITH dis AS (
    SELECT
        YEAR::INTEGER                                             AS YEAR,
        TRIM(UNIT_NAME)                                          AS TOWNSHIP,
        CLASS_NAME,
        TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))                  AS AMOUNT
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND AFR_UNIT_TYPE = '7'
      AND UPPER(FUND_NAME) LIKE '%TOWNSHIP ASSISTANCE%'

    UNION ALL

    SELECT
        TRIM(REPLACE(YEAR, '"', ''))::INTEGER                    AS YEAR,
        TRIM(REPLACE(UNIT_NAME, '"', ''))                        AS TOWNSHIP,
        TRIM(REPLACE(DISBURSE_CLASS_NAME, '"', ''))              AS CLASS_NAME,
        TRY_TO_DOUBLE(REPLACE(REPLACE(AMOUNT, '"', ''), ',', '')) AS AMOUNT
    FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY
    WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
      AND TRIM(REPLACE(AFR_UNIT_TYPE, '"', '')) = '7'
      AND UPPER(UNIT_FUND_NAME) LIKE '%TOWNSHIP ASSISTANCE%'
      AND TRIM(REPLACE(YEAR, '"', ''))::INTEGER < 2020
)
SELECT
    YEAR,
    TOWNSHIP,
    ROUND(SUM(CASE WHEN UPPER(CLASS_NAME) LIKE '%PERSONAL SERVICE%'
                   THEN AMOUNT ELSE 0 END))                      AS CLERK_ADMIN_COST,
    ROUND(SUM(CASE WHEN UPPER(CLASS_NAME) NOT LIKE '%PERSONAL SERVICE%'
                   THEN AMOUNT ELSE 0 END))                      AS ASSISTANCE_PAID,
    ROUND(SUM(AMOUNT))                                           AS TOTAL_ASSISTANCE_FUND,
    ROUND(
        SUM(CASE WHEN UPPER(CLASS_NAME) LIKE '%PERSONAL SERVICE%'
                 THEN AMOUNT ELSE 0 END)
        / NULLIF(
            SUM(CASE WHEN UPPER(CLASS_NAME) NOT LIKE '%PERSONAL SERVICE%'
                     THEN AMOUNT ELSE 0 END), 0),
    2)                                                           AS ADMIN_PER_DOLLAR_ASSISTANCE
FROM dis
GROUP BY YEAR, TOWNSHIP;


-- ── TA-7 TOWNSHIP ASSISTANCE STATISTICAL REPORT ───────────────────────────────
--   Self-reported annual application outcomes from each trustee.
--   UNACCOUNTED_CASES = reviewed - approved - denied (should be near zero).

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_TWP_TA7
  COMMENT = 'Township Assistance Statistical Report (TA-7) - Bartholomew County, 2011-2025'
AS
SELECT
    year::INTEGER                                                                      AS YEAR,
    TRIM(unit_name)                                                                    AS TOWNSHIP,
    TRY_TO_NUMBER(question1)                                                           AS APPLICATIONS_RECEIVED,
    TRY_TO_NUMBER(question2a)                                                          AS APPLICATIONS_REVIEWED,
    TRY_TO_NUMBER(question2b)                                                          AS CASES_APPROVED,
    CASE WHEN question2c IS NULL OR question2c = '' THEN NULL
         ELSE TRY_TO_NUMBER(question2c) END                                            AS CASES_DENIED,
    CASE WHEN question2c IS NULL OR question2c = '' THEN FALSE
         ELSE TRUE END                                                                 AS DENIAL_LOGGING_ACTIVE,
    ROUND(TRY_TO_NUMBER(question2b) / NULLIF(TRY_TO_NUMBER(question2a), 0) * 100, 1)  AS APPROVAL_RATE_PCT,
    TRY_TO_NUMBER(question2a)
        - TRY_TO_NUMBER(question2b)
        - COALESCE(CASE WHEN question2c = '' THEN NULL ELSE TRY_TO_NUMBER(question2c) END, 0)
                                                                                       AS UNACCOUNTED_CASES
FROM HOOSIER_DATA.RAW.GATEWAY_TA7
WHERE cnty_description ILIKE '%Bartholomew%'
  AND afr_unit_type = '7';


-- ── CERT_NAV CLEAN VIEW (statewide, deduped) ─────────────────────────────────
--   Source file contains exact duplicate rows (2-3x per district per year).
--   SELECT DISTINCT is safe because all duplicates are identical across every column.
--   Key on (BUDGET_YEAR, TAX_DISTRICT_CODE) — TAX_DISTRICT_NAME drifts across years.
--   KAN-134.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.CERT_NAV_CLEAN AS
SELECT DISTINCT
    TRIM(budget_year)                                           AS budget_year,
    TRY_TO_NUMBER(TRIM(budget_year))                           AS budget_year_num,
    TRIM(county_number)                                        AS county_number,
    TRIM(cnty_description)                                     AS cnty_description,
    TRIM(tax_district_code)                                    AS tax_district_code,
    TRIM(tax_district_name)                                    AS tax_district_name,
    bank_pp_av,
    TRY_TO_DECIMAL(bank_pp_av, 18, 0)                          AS bank_pp_av_num,
    net_av_1pct,
    TRY_TO_DECIMAL(net_av_1pct, 18, 0)                         AS net_av_1pct_num,
    net_av_2pct,
    TRY_TO_DECIMAL(net_av_2pct, 18, 0)                         AS net_av_2pct_num,
    net_av_3pct,
    TRY_TO_DECIMAL(net_av_3pct, 18, 0)                         AS net_av_3pct_num,
    real_est_net_av,
    TRY_TO_DECIMAL(real_est_net_av, 18, 0)                     AS real_est_net_av_num,
    bus_pp_net_av,
    TRY_TO_DECIMAL(bus_pp_net_av, 18, 0)                       AS bus_pp_net_av_num,
    utility_pp_net_av,
    TRY_TO_DECIMAL(utility_pp_net_av, 18, 0)                   AS utility_pp_net_av_num,
    rail_pp_net_av,
    TRY_TO_DECIMAL(rail_pp_net_av, 18, 0)                      AS rail_pp_net_av_num,
    pp_net_av,
    TRY_TO_DECIMAL(pp_net_av, 18, 0)                           AS pp_net_av_num,
    av_tif_real_est,
    TRY_TO_DECIMAL(av_tif_real_est, 18, 0)                     AS av_tif_real_est_num,
    av_tif_pp,
    TRY_TO_DECIMAL(av_tif_pp, 18, 0)                           AS av_tif_pp_num,
    av_withholding,
    TRY_TO_DECIMAL(av_withholding, 18, 0)                      AS av_withholding_num,
    adjusting_net_av,
    TRY_TO_DECIMAL(adjusting_net_av, 18, 0)                    AS adjusting_net_av_num,
    av_tif_released,
    TRY_TO_DECIMAL(av_tif_released, 18, 0)                     AS av_tif_released_num,
    av_annex_change,
    TRY_TO_DECIMAL(av_annex_change, 18, 0)                     AS av_annex_change_num
FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV;


-- ── FORM 4B: BUDGET LEVY CLEAN VIEW (statewide) ──────────────────────────────
--   Trims strings and adds _num casts for all dollar/rate columns.
--   Created in KAN-135; tracked here per KAN-137.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.FORM4B_CLEAN AS
SELECT
    TRIM(REPLACE(year,             '"', ''))                           AS year,
    TRY_TO_NUMBER(REPLACE(year,    '"', ''))                           AS year_num,
    TRIM(REPLACE(cnty_description, '"', ''))                           AS cnty_description,
    TRIM(REPLACE(cnty_cd,          '"', ''))                           AS cnty_cd,
    TRIM(REPLACE(unit_type,        '"', ''))                           AS unit_type,
    TRIM(REPLACE(unit_code,        '"', ''))                           AS unit_code,
    TRIM(REPLACE(unit_name,        '"', ''))                           AS unit_name,
    TRIM(REPLACE(fund_cd,          '"', ''))                           AS fund_cd,
    TRIM(REPLACE(fund_description, '"', ''))                           AS fund_description,
    total_budget_estimate_published,
    TRY_TO_DECIMAL(REPLACE(total_budget_estimate_published, '"', ''), 18, 2)             AS total_budget_estimate_published_num,
    total_budget_estimate_adopted,
    TRY_TO_DECIMAL(REPLACE(total_budget_estimate_adopted, '"', ''), 18, 2)               AS total_budget_estimate_adopted_num,
    necessary_expenditures_published,
    TRY_TO_DECIMAL(REPLACE(necessary_expenditures_published, '"', ''), 18, 2)            AS necessary_expenditures_published_num,
    necessary_expenditures_adopted,
    TRY_TO_DECIMAL(REPLACE(necessary_expenditures_adopted, '"', ''), 18, 2)              AS necessary_expenditures_adopted_num,
    additional_appropriation_published,
    TRY_TO_DECIMAL(REPLACE(additional_appropriation_published, '"', ''), 18, 2)          AS additional_appropriation_published_num,
    additional_appropriation_adopted,
    TRY_TO_DECIMAL(REPLACE(additional_appropriation_adopted, '"', ''), 18, 2)            AS additional_appropriation_adopted_num,
    outstanding_temp_loans_paid_published,
    TRY_TO_DECIMAL(REPLACE(outstanding_temp_loans_paid_published, '"', ''), 18, 2)       AS outstanding_temp_loans_paid_published_num,
    outstanding_temp_loans_paid_adopted,
    TRY_TO_DECIMAL(REPLACE(outstanding_temp_loans_paid_adopted, '"', ''), 18, 2)         AS outstanding_temp_loans_paid_adopted_num,
    outstanding_temp_loans_not_repaid_published,
    TRY_TO_DECIMAL(REPLACE(outstanding_temp_loans_not_repaid_published, '"', ''), 18, 2) AS outstanding_temp_loans_not_repaid_published_num,
    outstanding_temp_loans_not_repaid_adopted,
    TRY_TO_DECIMAL(REPLACE(outstanding_temp_loans_not_repaid_adopted, '"', ''), 18, 2)   AS outstanding_temp_loans_not_repaid_adopted_num,
    total_funds_reqd_published,
    TRY_TO_DECIMAL(REPLACE(total_funds_reqd_published, '"', ''), 18, 2)                  AS total_funds_reqd_published_num,
    total_funds_reqd_adopted,
    TRY_TO_DECIMAL(REPLACE(total_funds_reqd_adopted, '"', ''), 18, 2)                    AS total_funds_reqd_adopted_num,
    actual_cash_balance_published,
    TRY_TO_DECIMAL(REPLACE(actual_cash_balance_published, '"', ''), 18, 2)               AS actual_cash_balance_published_num,
    actual_cash_balance_adopted,
    TRY_TO_DECIMAL(REPLACE(actual_cash_balance_adopted, '"', ''), 18, 2)                 AS actual_cash_balance_adopted_num,
    taxes_to_be_collected_published,
    TRY_TO_DECIMAL(REPLACE(taxes_to_be_collected_published, '"', ''), 18, 2)             AS taxes_to_be_collected_published_num,
    taxes_to_be_collected_adopted,
    TRY_TO_DECIMAL(REPLACE(taxes_to_be_collected_adopted, '"', ''), 18, 2)               AS taxes_to_be_collected_adopted_num,
    misc_revenue_form2_cola_published,
    TRY_TO_DECIMAL(REPLACE(misc_revenue_form2_cola_published, '"', ''), 18, 2)           AS misc_revenue_form2_cola_published_num,
    misc_revenue_form2_cola_adopted,
    TRY_TO_DECIMAL(REPLACE(misc_revenue_form2_cola_adopted, '"', ''), 18, 2)             AS misc_revenue_form2_cola_adopted_num,
    misc_revenue_form2_colb_published,
    TRY_TO_DECIMAL(REPLACE(misc_revenue_form2_colb_published, '"', ''), 18, 2)           AS misc_revenue_form2_colb_published_num,
    misc_revenue_form2_colb_adopted,
    TRY_TO_DECIMAL(REPLACE(misc_revenue_form2_colb_adopted, '"', ''), 18, 2)             AS misc_revenue_form2_colb_adopted_num,
    total_funds_published,
    TRY_TO_DECIMAL(REPLACE(total_funds_published, '"', ''), 18, 2)                       AS total_funds_published_num,
    total_funds_adopted,
    TRY_TO_DECIMAL(REPLACE(total_funds_adopted, '"', ''), 18, 2)                         AS total_funds_adopted_num,
    operating_balance_published,
    TRY_TO_DECIMAL(REPLACE(operating_balance_published, '"', ''), 18, 2)                 AS operating_balance_published_num,
    operating_balance_adopted,
    TRY_TO_DECIMAL(REPLACE(operating_balance_adopted, '"', ''), 18, 2)                   AS operating_balance_adopted_num,
    prop_tax_repl_cred_published,
    TRY_TO_DECIMAL(REPLACE(prop_tax_repl_cred_published, '"', ''), 18, 2)                AS prop_tax_repl_cred_published_num,
    prop_tax_repl_cred_adopted,
    TRY_TO_DECIMAL(REPLACE(prop_tax_repl_cred_adopted, '"', ''), 18, 2)                  AS prop_tax_repl_cred_adopted_num,
    operating_loit_published,
    TRY_TO_DECIMAL(REPLACE(operating_loit_published, '"', ''), 18, 2)                    AS operating_loit_published_num,
    operating_loit_adopted,
    TRY_TO_DECIMAL(REPLACE(operating_loit_adopted, '"', ''), 18, 2)                      AS operating_loit_adopted_num,
    net_amt_to_be_raised_published,
    TRY_TO_DECIMAL(REPLACE(net_amt_to_be_raised_published, '"', ''), 18, 2)              AS net_amt_to_be_raised_published_num,
    net_amt_to_be_raised_adopted,
    TRY_TO_DECIMAL(REPLACE(net_amt_to_be_raised_adopted, '"', ''), 18, 2)                AS net_amt_to_be_raised_adopted_num,
    levy_excess_fund_published,
    TRY_TO_DECIMAL(REPLACE(levy_excess_fund_published, '"', ''), 18, 2)                  AS levy_excess_fund_published_num,
    levy_excess_fund_adopted,
    TRY_TO_DECIMAL(REPLACE(levy_excess_fund_adopted, '"', ''), 18, 2)                    AS levy_excess_fund_adopted_num,
    net_amount_to_be_raised_published,
    TRY_TO_DECIMAL(REPLACE(net_amount_to_be_raised_published, '"', ''), 18, 2)           AS net_amount_to_be_raised_published_num,
    net_amount_to_be_raised_adopted,
    TRY_TO_DECIMAL(REPLACE(net_amount_to_be_raised_adopted, '"', ''), 18, 2)             AS net_amount_to_be_raised_adopted_num,
    net_tax_rate_published,
    TRY_TO_DECIMAL(REPLACE(net_tax_rate_published, '"', ''), 18, 6)                      AS net_tax_rate_published_num,
    net_tax_rate_adopted,
    TRY_TO_DECIMAL(REPLACE(net_tax_rate_adopted, '"', ''), 18, 6)                        AS net_tax_rate_adopted_num,
    property_tax_cap_published,
    TRY_TO_DECIMAL(REPLACE(property_tax_cap_published, '"', ''), 18, 2)                  AS property_tax_cap_published_num,
    property_tax_cap_adopted,
    TRY_TO_DECIMAL(REPLACE(property_tax_cap_adopted, '"', ''), 18, 2)                    AS property_tax_cap_adopted_num,
    net_assessed_valuation,
    TRY_TO_DECIMAL(REPLACE(net_assessed_valuation, '"', ''), 18, 2)                      AS net_assessed_valuation_num,
    net_to_be_raised_for_expenses_published,
    TRY_TO_DECIMAL(REPLACE(net_to_be_raised_for_expenses_published, '"', ''), 18, 2)     AS net_to_be_raised_for_expenses_published_num,
    net_to_be_raised_for_expenses_adopted,
    TRY_TO_DECIMAL(REPLACE(net_to_be_raised_for_expenses_adopted, '"', ''), 18, 2)       AS net_to_be_raised_for_expenses_adopted_num,
    amt_to_be_raised_taxlevy_published,
    TRY_TO_DECIMAL(REPLACE(amt_to_be_raised_taxlevy_published, '"', ''), 18, 2)          AS amt_to_be_raised_taxlevy_published_num,
    amt_to_be_raised_taxlevy_adopted,
    TRY_TO_DECIMAL(REPLACE(amt_to_be_raised_taxlevy_adopted, '"', ''), 18, 2)            AS amt_to_be_raised_taxlevy_adopted_num
FROM HOOSIER_DATA.RAW.GATEWAY_FORM4B;


-- ============================================================
-- PENDING: Schools and library views
-- Run after GATEWAY_DISBURSEMENTS_DETAIL and GATEWAY_RECEIPTS_DETAIL
-- are confirmed to have data for AFR_UNIT_TYPE = '5' and '6'.
-- ============================================================

-- ── SCHOOLS: REVENUE vs EXPENDITURE ──────────────────────────────────────────
-- CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.BARTHOLOMEW_SCHOOLS_REV_VS_EXP AS
-- WITH expenditures AS (
--     SELECT
--         YEAR::INTEGER                                              AS YEAR,
--         TRIM(UNIT_NAME)                                           AS ENTITY,
--         ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS EXPENDITURE
--     FROM HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_DETAIL
--     WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
--       AND AFR_UNIT_TYPE = '5'
--     GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME)
-- ),
-- revenue AS (
--     SELECT
--         YEAR::INTEGER                                              AS YEAR,
--         TRIM(UNIT_NAME)                                           AS ENTITY,
--         ROUND(SUM(TRY_TO_DOUBLE(REPLACE(AMOUNT, ',', ''))))       AS REVENUE
--     FROM HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_DETAIL
--     WHERE CNTY_DESCRIPTION ILIKE '%Bartholomew%'
--       AND AFR_UNIT_TYPE = '5'
--     GROUP BY YEAR::INTEGER, TRIM(UNIT_NAME)
-- )
-- SELECT
--     COALESCE(e.YEAR, r.YEAR)         AS YEAR,
--     COALESCE(e.ENTITY, r.ENTITY)     AS ENTITY,
--     COALESCE(e.EXPENDITURE, 0)       AS EXPENDITURE,
--     COALESCE(r.REVENUE, 0)           AS REVENUE,
--     COALESCE(r.REVENUE, 0) - COALESCE(e.EXPENDITURE, 0) AS SURPLUS_DEFICIT,
--     CASE WHEN COALESCE(r.REVENUE, 0) >= COALESCE(e.EXPENDITURE, 0) THEN 'Surplus'
--          ELSE 'Deficit' END AS FISCAL_STATUS
-- FROM expenditures e
-- FULL OUTER JOIN revenue r ON e.YEAR = r.YEAR AND e.ENTITY = r.ENTITY;


-- ── LIBRARY: REVENUE vs EXPENDITURE ──────────────────────────────────────────
-- Same pattern as schools but AFR_UNIT_TYPE = '6'
-- Uncomment and run after verifying library data loaded correctly.


-- ── HOMESTEAD AV BY TOWNSHIP (KAN-128) ───────────────────────────────────────
--   Aggregates GATEWAY_PARCEL to township level.
--   1% cap fields (av_land_1pct + av_impr_1pct) = homestead-eligible gross AV.
--   Key for SEA-1 fire fund impact model; join to CERT_NAV on township_number
--   to layer in levy rates and compute revenue loss projections.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.HOMESTEAD_AV_BY_TOWNSHIP AS
SELECT
    pay_year,
    assessment_year,
    county_number,
    county_description,
    township_number,
    COUNT(*)                                                                AS parcel_count,

    SUM(TRY_TO_NUMBER(av_total_land_and_impr))                              AS gross_av,
    SUM(TRY_TO_NUMBER(av_land_1pct) + TRY_TO_NUMBER(av_impr_1pct))         AS homestead_gross_av,
    SUM(TRY_TO_NUMBER(av_nonhs_res_land_2pct)
        + TRY_TO_NUMBER(av_nonhs_res_impr_2pct))                           AS nonhs_res_av,
    SUM(TRY_TO_NUMBER(av_apt_land_2pct)
        + TRY_TO_NUMBER(av_apt_impr_2pct))                                 AS apt_av,
    SUM(TRY_TO_NUMBER(av_ltc_land_2pct)
        + TRY_TO_NUMBER(av_ltc_impr_2pct))                                 AS ltc_av,
    SUM(TRY_TO_NUMBER(av_farmland_2pct))                                    AS farmland_av,
    SUM(TRY_TO_NUMBER(av_mobile_home_land_2pct))                            AS mobile_home_av,
    SUM(TRY_TO_NUMBER(av_land_3pct)
        + TRY_TO_NUMBER(av_impr_3pct))                                     AS commercial_av,
    SUM(TRY_TO_NUMBER(av_classified_land))                                  AS classified_land_av,

    ROUND(
        SUM(TRY_TO_NUMBER(av_land_1pct) + TRY_TO_NUMBER(av_impr_1pct))
        / NULLIF(SUM(TRY_TO_NUMBER(av_total_land_and_impr)), 0)
    , 4)                                                                    AS homestead_pct

FROM HOOSIER_DATA.RAW.GATEWAY_PARCEL
GROUP BY 1, 2, 3, 4, 5;


-- ── LIT FIRE PROTECTION RATE PROJECTION (KAN-129) ────────────────────────────
--   Projects revenue at 3 LIT fire rate scenarios per IC 6-3.6-6-2.5.
--   LIT rates expressed as $/100 of AGI.
--   Scenarios: $0.025, $0.05, $0.10 per $100 AGI = 0.025%, 0.05%, 0.10%.
--
--   METHODOLOGY (corrected per Confluence IK/16547841, 2026-06-09):
--   County LIT base = $40,298,353 (2025 DLGF certified report — ESTIMATED,
--   not yet reproduced by warehouse query; see KAN-129 open item).
--   Each 0.025% fire rate generates ~$806K county-wide.
--   Revenue is distributed by each township's share of total 2024 fire levy
--   (not by R138 certified shares, which exclude county/city distributions).
--
--   Break-even rate = LIT rate needed to fully replace current fire levy.
--
--   PRIOR VERSION ERROR: used township R138 share (~$29.3M base) as proxy,
--   understating revenue ~10x vs the correct $40.3M base. Fixed here.

CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.LIT_FIRE_RATE_PROJECTION AS
WITH params AS (
    SELECT
        40298353.0 AS county_lit_certified,  -- 2025 DLGF certified; ESTIMATED until KAN-129 loads DOR data
        0.0125     AS combined_lit_rate,      -- Bartholomew County 2024 combined rate
        2024       AS levy_year
),
fire_fund AS (
    SELECT
        TRIM(unit_name)                                                              AS township,
        year_num,
        SUM(net_tax_rate_adopted_num * net_assessed_valuation_num / 100)             AS fire_levy_est,
        SUM(net_assessed_valuation_num)                                              AS fire_nav,
        MAX(CASE WHEN UPPER(fund_description) LIKE '%FIRE AND E%'
                 THEN net_tax_rate_adopted_num END)                                  AS ems_fire_rate,
        MAX(CASE WHEN UPPER(fund_description) LIKE '%CUMULATIVE FIRE%'
                 THEN net_tax_rate_adopted_num END)                                  AS cum_fire_rate
    FROM HOOSIER_DATA.ANALYTICS.FORM4B_CLEAN
    WHERE cnty_description ILIKE '%Bartholomew%'
      AND unit_type = '2'
      AND UPPER(fund_description) LIKE '%FIRE%'
      AND year_num = (SELECT levy_year FROM params)
    GROUP BY 1, 2
),
county_levy_total AS (
    SELECT SUM(fire_levy_est) AS total_levy FROM fire_fund
)
SELECT
    f.township,
    f.year_num                                                                       AS year,
    ROUND(f.fire_nav)                                                                AS fire_fund_nav,
    ROUND(f.fire_levy_est)                                                           AS fire_levy_est,
    f.ems_fire_rate                                                                  AS ems_fire_rate_per_100,
    f.cum_fire_rate                                                                  AS cum_fire_rate_per_100,
    -- Township's share of county fire levy pool (distribution basis)
    ROUND(f.fire_levy_est / NULLIF(clt.total_levy, 0) * 100, 4)                     AS fire_levy_share_pct,
    -- County LIT base (ESTIMATED — external figure, not yet in warehouse)
    ROUND(p.county_lit_certified)                                                    AS county_lit_certified,
    ROUND(p.county_lit_certified / p.combined_lit_rate)                              AS est_county_agi,
    -- LIT fire rate scenarios: revenue distributed by fire-levy share
    ROUND(p.county_lit_certified / p.combined_lit_rate
        * 0.00025
        * f.fire_levy_est / NULLIF(clt.total_levy, 0))                              AS lit_fire_rev_0025_per_100,
    ROUND(p.county_lit_certified / p.combined_lit_rate
        * 0.0005
        * f.fire_levy_est / NULLIF(clt.total_levy, 0))                              AS lit_fire_rev_005_per_100,
    ROUND(p.county_lit_certified / p.combined_lit_rate
        * 0.001
        * f.fire_levy_est / NULLIF(clt.total_levy, 0))                              AS lit_fire_rev_01_per_100,
    -- Break-even: LIT rate ($/100 AGI) to fully replace this township's fire levy
    ROUND(
        f.fire_levy_est
        / NULLIF(
            p.county_lit_certified / p.combined_lit_rate
            * f.fire_levy_est / NULLIF(clt.total_levy, 0)
          , 0)
        * 100
    , 4)                                                                             AS breakeven_lit_rate_per_100,
    'ESTIMATED'                                                                      AS provenance
FROM fire_fund f
CROSS JOIN params p
CROSS JOIN county_levy_total clt
ORDER BY f.township;
