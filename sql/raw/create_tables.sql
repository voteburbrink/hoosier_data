-- ============================================================
-- HOOSIER_DATA RAW Layer Table Definitions
-- All columns VARCHAR — no type casting in RAW layer
-- Sources land exactly as downloaded
--
-- WARNING: DDL ONLY. Do NOT re-run against a populated database.
-- All statements use CREATE TABLE IF NOT EXISTS — re-running is
-- safe but will NOT add new columns to existing tables. Use
-- ALTER TABLE for schema changes; never drop/recreate to avoid data loss.
-- (Incident: June 5 2026 — CREATE OR REPLACE wiped ~22M rows across 8 tables)
-- ============================================================

-- ── CAMPAIGN FINANCE ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE (
    file_number         VARCHAR,
    committee_type      VARCHAR,
    committee           VARCHAR,
    candidate_name      VARCHAR,
    contributor_type    VARCHAR,
    name                VARCHAR,
    address             VARCHAR,
    city                VARCHAR,
    state               VARCHAR,
    zip                 VARCHAR,
    occupation          VARCHAR,
    type                VARCHAR,
    description         VARCHAR,
    amount              VARCHAR,
    contribution_date   VARCHAR,
    received_by         VARCHAR,
    amended             VARCHAR
);

-- ── LEGISCAN LEGISLATIVE DATA ─────────────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LEGISCAN_BILLS (
    bill_id           VARCHAR,
    session_id        VARCHAR,
    bill_number       VARCHAR,
    status            VARCHAR,
    status_desc       VARCHAR,
    status_date       VARCHAR,
    title             VARCHAR,
    description       VARCHAR,
    committee_id      VARCHAR,
    committee         VARCHAR,
    last_action_date  VARCHAR,
    last_action       VARCHAR,
    url               VARCHAR,
    state_link        VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LEGISCAN_PEOPLE (
    people_id             VARCHAR,
    name                  VARCHAR,
    first_name            VARCHAR,
    middle_name           VARCHAR,
    last_name             VARCHAR,
    suffix                VARCHAR,
    nickname              VARCHAR,
    party_id              VARCHAR,
    party                 VARCHAR,
    role_id               VARCHAR,
    role                  VARCHAR,
    district              VARCHAR,
    followthemoney_eid    VARCHAR,
    votesmart_id          VARCHAR,
    opensecrets_id        VARCHAR,
    ballotpedia           VARCHAR,
    knowwho_pid           VARCHAR,
    committee_id          VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LEGISCAN_ROLLCALLS (
    bill_id         VARCHAR,
    roll_call_id    VARCHAR,
    date            VARCHAR,
    chamber         VARCHAR,
    description     VARCHAR,
    yea             VARCHAR,
    nay             VARCHAR,
    nv              VARCHAR,
    absent          VARCHAR,
    total           VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LEGISCAN_VOTES (
    roll_call_id    VARCHAR,
    people_id       VARCHAR,
    vote            VARCHAR,
    vote_desc       VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LEGISCAN_SPONSORS (
    bill_id         VARCHAR,
    people_id       VARCHAR,
    position        VARCHAR
);

-- ── LOBBYING ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LOBBYING_EMPLOYER (
    year                                    VARCHAR,
    lobbyist                                VARCHAR,
    terminated                              VARCHAR,
    first_period_compensation               VARCHAR,
    first_period_reimbursements             VARCHAR,
    first_period_receptions                 VARCHAR,
    first_period_other_entertainment        VARCHAR,
    first_period_other_gifts                VARCHAR,
    first_period_expenditures_all_members   VARCHAR,
    first_period_gifts                      VARCHAR,
    first_period_registration_late_fees     VARCHAR,
    first_period_other_expenses             VARCHAR,
    first_period_gross_expenditures         VARCHAR,
    second_period_compensation              VARCHAR,
    second_period_reimbursements            VARCHAR,
    second_period_receptions                VARCHAR,
    second_period_other_entertainment       VARCHAR,
    second_period_other_gifts               VARCHAR,
    second_period_expenditures_all_members  VARCHAR,
    second_period_gifts                     VARCHAR,
    second_period_registration_late_fees    VARCHAR,
    second_period_other_expenses            VARCHAR,
    second_period_gross_expenditures        VARCHAR,
    grand_totals                            VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.LOBBYING_COMPENSATED (
    year                                    VARCHAR,
    lobbyist                                VARCHAR,
    client                                  VARCHAR,
    terminated                              VARCHAR,
    first_period_compensation               VARCHAR,
    first_period_reimbursements             VARCHAR,
    first_period_receptions                 VARCHAR,
    first_period_other_entertainment        VARCHAR,
    first_period_other_gifts                VARCHAR,
    first_period_expenditures_all_members   VARCHAR,
    first_period_gifts                      VARCHAR,
    first_period_registration_late_fees     VARCHAR,
    first_period_other_expenses             VARCHAR,
    first_period_gross_expenditures         VARCHAR,
    first_period_deductions                 VARCHAR,
    first_period_net_expenditures           VARCHAR,
    second_period_compensation              VARCHAR,
    second_period_reimbursements            VARCHAR,
    second_period_receptions                VARCHAR,
    second_period_other_entertainment       VARCHAR,
    second_period_other_gifts               VARCHAR,
    second_period_expenditures_all_members  VARCHAR,
    second_period_gifts                     VARCHAR,
    second_period_registration_late_fees    VARCHAR,
    second_period_other_expenses            VARCHAR,
    second_period_gross_expenditures        VARCHAR,
    second_period_deductions                VARCHAR,
    second_period_net_expenditures          VARCHAR,
    grand_totals                            VARCHAR
);

-- ── STATE EXPENDITURES ────────────────────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.STATE_EXPENDITURES (
    account_name         VARCHAR,
    account_id           VARCHAR,
    agency_name          VARCHAR,
    agency_id            VARCHAR,
    amount               VARCHAR,
    expenditure_category VARCHAR,
    fiscal_year          VARCHAR,
    function_of_govt     VARCHAR,
    fund_name            VARCHAR,
    fund_id              VARCHAR,
    funding_source       VARCHAR,
    journal_date         VARCHAR,
    journal_id           VARCHAR,
    last_updated         VARCHAR,
    legal_fund_name      VARCHAR,
    legal_fund_id        VARCHAR,
    source               VARCHAR,
    vendor_name          VARCHAR,
    vendor_id            VARCHAR,
    journal_agency_id    VARCHAR
);

-- ── VENDOR EXPENDITURES ───────────────────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.VENDOR_EXPENDITURES (
    account_id           VARCHAR,
    account_name         VARCHAR,
    agency_id            VARCHAR,
    agency_name          VARCHAR,
    amount               VARCHAR,
    expenditure_category VARCHAR,
    fiscal_year          VARCHAR,
    function_of_govt     VARCHAR,
    fund_id              VARCHAR,
    fund_name            VARCHAR,
    funding_source       VARCHAR,
    journal_agency_id    VARCHAR,
    journal_date         VARCHAR,
    journal_id           VARCHAR,
    last_updated         VARCHAR,
    legal_fund_id        VARCHAR,
    legal_fund_name      VARCHAR,
    source               VARCHAR,
    vendor_id            VARCHAR,
    vendor_name          VARCHAR,
    voucher_id           VARCHAR
);

-- ── INDIANA GATEWAY LOCAL GOVERNMENT ─────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS (
    year                 VARCHAR,
    cnty_cd              VARCHAR,
    cnty_description     VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    sboa_id              VARCHAR,
    afr_unit_type        VARCHAR,
    unit_name            VARCHAR,
    ent_id               VARCHAR,
    ent_name             VARCHAR,
    fund_code            VARCHAR,
    unit_fund_number     VARCHAR,
    fund_name            VARCHAR,
    disburse_class_code  VARCHAR,
    class_name           VARCHAR,
    disburse_code        VARCHAR,
    section              VARCHAR,
    disburse_name        VARCHAR,
    amount               VARCHAR,
    spare_col            VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY (
    year                 VARCHAR,
    cnty_description     VARCHAR,
    cnty_cd              VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    unit_name            VARCHAR,
    afr_unit_type        VARCHAR,
    ent_id               VARCHAR,
    ent_name             VARCHAR,
    fund_code            VARCHAR,
    disburse_code        VARCHAR,
    disburse_name        VARCHAR,
    amount               VARCHAR,
    disburse_class_code  VARCHAR,
    disburse_class_name  VARCHAR,
    unit_fund_name       VARCHAR,
    unit_fund_number     VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_RECEIPTS (
    year                 VARCHAR,
    cnty_cd              VARCHAR,
    cnty_description     VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    sboa_id              VARCHAR,
    afr_unit_type        VARCHAR,
    unit_name            VARCHAR,
    ent_id               VARCHAR,
    ent_name             VARCHAR,
    fund_code            VARCHAR,
    unit_fund_number     VARCHAR,
    fund_name            VARCHAR,
    receipt_class_code   VARCHAR,
    receipt_class_name   VARCHAR,
    receipt_code         VARCHAR,
    section              VARCHAR,
    other_item_flag      VARCHAR,
    receipt_name         VARCHAR,
    unit_account_number  VARCHAR,
    unit_account_name    VARCHAR,
    amount               VARCHAR,
    spare_col            VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_LEGACY (
    year                 VARCHAR,
    cnty_description     VARCHAR,
    cnty_cd              VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    unit_name            VARCHAR,
    afr_unit_type        VARCHAR,
    ent_id               VARCHAR,
    ent_name             VARCHAR,
    fund_code            VARCHAR,
    receipt_code         VARCHAR,
    receipt_name         VARCHAR,
    amount               VARCHAR,
    receipt_class_code   VARCHAR,
    other_item_flag      VARCHAR,
    receipt_class_name   VARCHAR,
    unit_account_number  VARCHAR,
    unit_account_name    VARCHAR,
    unit_fund_name       VARCHAR,
    unit_fund_number     VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_TOWNSHIP_VENDOR (
    year                 VARCHAR,
    cnty_description     VARCHAR,
    county_cd_fk         VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    unit_name            VARCHAR,
    sboa_id              VARCHAR,
    afr_unit_type        VARCHAR,
    fund_code            VARCHAR,
    unit_fund_number     VARCHAR,
    unit_fund_name       VARCHAR,
    disburse_class_code  VARCHAR,
    disburse_class_name  VARCHAR,
    vendor_name          VARCHAR,
    vendor_disburse_code VARCHAR,
    amount               VARCHAR,
    spare_col            VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_TOWNSHIP_VENDOR_LEGACY (
    year                 VARCHAR,
    cnty_description     VARCHAR,
    county_cd_fk         VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    unit_name            VARCHAR,
    afr_unit_type        VARCHAR,
    fund_code            VARCHAR,
    unit_fund_number     VARCHAR,
    unit_fund_name       VARCHAR,
    disburse_class_code  VARCHAR,
    disburse_class_name  VARCHAR,
    vendor_name          VARCHAR,
    vendor_disburse_code VARCHAR,
    amount               VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_ECA_EXPENDITURES (
    year             VARCHAR,
    cnty_description VARCHAR,
    county_cd_fk     VARCHAR,
    unit_type_id     VARCHAR,
    unit_code        VARCHAR,
    corp_county      VARCHAR,
    corp_name        VARCHAR,
    unit_name        VARCHAR,
    fund_id          VARCHAR,
    fund_name        VARCHAR,
    purpose          VARCHAR,
    amount           VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_ECA_RECEIPTS (
    year             VARCHAR,
    cnty_description VARCHAR,
    county_cd_fk     VARCHAR,
    unit_type_id     VARCHAR,
    unit_code        VARCHAR,
    corp_county      VARCHAR,
    corp_name        VARCHAR,
    unit_name        VARCHAR,
    fund_id          VARCHAR,
    fund_name        VARCHAR,
    source           VARCHAR,
    nature           VARCHAR,
    amount           VARCHAR,
    submit_status    VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_ECA_BALANCES (
    year             VARCHAR,
    cnty_description VARCHAR,
    county_cd_fk     VARCHAR,
    unit_type_id     VARCHAR,
    unit_code        VARCHAR,
    corp_county      VARCHAR,
    corp_name        VARCHAR,
    unit_name        VARCHAR,
    fund_id          VARCHAR,
    fund_name        VARCHAR,
    beginning_bal    VARCHAR,
    rcpts            VARCHAR,
    expd             VARCHAR,
    end_bal          VARCHAR,
    submit_status    VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_TAX_DISTRIBUTIONS (
    yr_nbr              VARCHAR,
    county              VARCHAR,
    county_cd           VARCHAR,
    unit_type_cd        VARCHAR,
    unit_cd             VARCHAR,
    unit_type_desc      VARCHAR,
    unit                VARCHAR,
    entity_cd           VARCHAR,
    entity              VARCHAR,
    distribution_cd     VARCHAR,
    distrib_type        VARCHAR,
    distribution_date   VARCHAR,
    advance             VARCHAR,
    warrant             VARCHAR,
    amt                 VARCHAR,
    distribution_month  VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_ENTITY_FUNDS (
    year                       VARCHAR,
    entity_id                  VARCHAR,
    unit_id                    VARCHAR,
    sba_id                     VARCHAR,
    cnty_cd                    VARCHAR,
    cnty_description           VARCHAR,
    unit_type_id               VARCHAR,
    unit_type_desc             VARCHAR,
    unit_code                  VARCHAR,
    unit_name                  VARCHAR,
    submit_timestamp           VARCHAR,
    sboa_file_number           VARCHAR,
    e1_status                  VARCHAR,
    entity_fiscal_year_end     VARCHAR,
    legal_name                 VARCHAR,
    doing_business_as          VARCHAR,
    address1                   VARCHAR,
    address2                   VARCHAR,
    city                       VARCHAR,
    state                      VARCHAR,
    zip                        VARCHAR,
    county                     VARCHAR,
    bus_phone                  VARCHAR,
    bus_ext                    VARCHAR,
    operating_officer_name     VARCHAR,
    operating_officer_title    VARCHAR,
    organization_type          VARCHAR,
    legal_status               VARCHAR,
    date_org_was_founded       VARCHAR,
    organization_purpose       VARCHAR,
    org_governing_structure    VARCHAR,
    initial_e1_for_entity      VARCHAR,
    audited_before_by_ipa      VARCHAR,
    last_fiscal_year_audited   VARCHAR,
    name_of_ipa                VARCHAR,
    ipa_address1               VARCHAR,
    ipa_address2               VARCHAR,
    ipa_city                   VARCHAR,
    ipa_state                  VARCHAR,
    ipa_zip                    VARCHAR,
    audit_cycle                VARCHAR,
    entity_total_disbursements VARCHAR,
    info_reported_on           VARCHAR,
    entity_fund_id             VARCHAR,
    cfda_number                VARCHAR,
    gvmt_agency_name           VARCHAR,
    gvmt_agency_address1       VARCHAR,
    gvmt_agency_address2       VARCHAR,
    gvmt_agency_city           VARCHAR,
    gvmt_agency_state          VARCHAR,
    gvmt_agency_zip            VARCHAR,
    program_title              VARCHAR,
    amount_received            VARCHAR,
    amount_disbursed           VARCHAR,
    fund_classification        VARCHAR,
    sboa_fund_classification   VARCHAR
);

-- ── INDIANA GATEWAY - EXTENDED DETAIL TABLES (2011+) ─────────────────────────
-- Downloaded as statewide files, filtered to Bartholomew County, converted to CSV.
-- Covers all AFR unit types: '7' Township, '5' School Corp, '6' Library, '1' County.
-- These extend coverage back to 2011 and include department-level coding.

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_DETAIL (
    year                 VARCHAR,
    cnty_cd              VARCHAR,
    cnty_description     VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    sboa_id              VARCHAR,
    afr_unit_type        VARCHAR,
    unit_name            VARCHAR,
    ent_id               VARCHAR,
    ent_name             VARCHAR,
    fund_code            VARCHAR,
    unit_fund_number     VARCHAR,
    fund_name            VARCHAR,
    department_code      VARCHAR,
    department_name      VARCHAR,
    disburse_class_code  VARCHAR,
    class_name           VARCHAR,
    disburse_code        VARCHAR,
    disburse_name        VARCHAR,
    amount               VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_DETAIL (
    year                 VARCHAR,
    cnty_cd              VARCHAR,
    cnty_description     VARCHAR,
    budget_unit_type     VARCHAR,
    unit_code            VARCHAR,
    sboa_id              VARCHAR,
    afr_unit_type        VARCHAR,
    unit_name            VARCHAR,
    ent_id               VARCHAR,
    ent_name             VARCHAR,
    fund_code            VARCHAR,
    unit_fund_number     VARCHAR,
    fund_name            VARCHAR,
    receipt_class_code   VARCHAR,
    receipt_class_name   VARCHAR,
    receipt_code         VARCHAR,
    section              VARCHAR,
    other_item_flag      VARCHAR,
    receipt_name         VARCHAR,
    amount               VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_FORM22 (
    yr_nbr               VARCHAR,
    county               VARCHAR,
    county_cd            VARCHAR,
    unit_type_cd         VARCHAR,
    unit_cd              VARCHAR,
    unit_type_desc       VARCHAR,
    unit                 VARCHAR,
    entity_cd            VARCHAR,
    entity               VARCHAR,
    distribution_cd      VARCHAR,
    distrib_type         VARCHAR,
    distribution_date    VARCHAR,
    advance              VARCHAR,
    warrant              VARCHAR,
    amt                  VARCHAR,
    distribution_month   VARCHAR
);

-- Certified Net Assessed Value by tax district (comma-delimited source, unlike other Gateway files)
-- Schema updated 2026-06-08: Indiana Gateway changed columns from homestead/rental/commercial breakdown
-- to AV-by-classification (1%/2%/3%) + TIF components.
CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_CERT_NAV (
    budget_year          VARCHAR,
    county_number        VARCHAR,
    cnty_description     VARCHAR,
    tax_district_code    VARCHAR,
    tax_district_name    VARCHAR,
    bank_pp_av           VARCHAR,
    net_av_1pct          VARCHAR,
    net_av_2pct          VARCHAR,
    net_av_3pct          VARCHAR,
    real_est_net_av      VARCHAR,
    bus_pp_net_av        VARCHAR,
    utility_pp_net_av    VARCHAR,
    rail_pp_net_av       VARCHAR,
    pp_net_av            VARCHAR,
    av_tif_real_est      VARCHAR,
    av_tif_pp            VARCHAR,
    av_withholding       VARCHAR,
    adjusting_net_av     VARCHAR,
    av_tif_released      VARCHAR,
    av_annex_change      VARCHAR
);

-- ── FEDERAL CONTRACTS (297 columns, all states — filtered to Indiana) ──

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.FEDERAL_CONTRACTS (
    contract_transaction_unique_key                                    VARCHAR,
    contract_award_unique_key                                         VARCHAR,
    award_id_piid                                                     VARCHAR,
    modification_number                                               VARCHAR,
    transaction_number                                                VARCHAR,
    parent_award_agency_id                                            VARCHAR,
    parent_award_agency_name                                          VARCHAR,
    parent_award_id_piid                                              VARCHAR,
    parent_award_modification_number                                  VARCHAR,
    federal_action_obligation                                         VARCHAR,
    total_dollars_obligated                                           VARCHAR,
    total_outlayed_amount_for_overall_award                           VARCHAR,
    base_and_exercised_options_value                                  VARCHAR,
    current_total_value_of_award                                      VARCHAR,
    base_and_all_options_value                                        VARCHAR,
    potential_total_value_of_award                                    VARCHAR,
    disaster_emergency_fund_codes_for_overall_award                   VARCHAR,
    outlayed_amount_from_covid19_supplementals_for_overall_award      VARCHAR,
    obligated_amount_from_covid19_supplementals_for_overall_award     VARCHAR,
    outlayed_amount_from_iija_supplemental_for_overall_award          VARCHAR,
    obligated_amount_from_iija_supplemental_for_overall_award         VARCHAR,
    action_date                                                       VARCHAR,
    action_date_fiscal_year                                           VARCHAR,
    period_of_performance_start_date                                  VARCHAR,
    period_of_performance_current_end_date                            VARCHAR,
    period_of_performance_potential_end_date                          VARCHAR,
    ordering_period_end_date                                          VARCHAR,
    solicitation_date                                                 VARCHAR,
    awarding_agency_code                                              VARCHAR,
    awarding_agency_name                                              VARCHAR,
    awarding_sub_agency_code                                          VARCHAR,
    awarding_sub_agency_name                                          VARCHAR,
    awarding_office_code                                              VARCHAR,
    awarding_office_name                                              VARCHAR,
    funding_agency_code                                               VARCHAR,
    funding_agency_name                                               VARCHAR,
    funding_sub_agency_code                                           VARCHAR,
    funding_sub_agency_name                                           VARCHAR,
    funding_office_code                                               VARCHAR,
    funding_office_name                                               VARCHAR,
    treasury_accounts_funding_this_award                              VARCHAR,
    federal_accounts_funding_this_award                               VARCHAR,
    object_classes_funding_this_award                                 VARCHAR,
    program_activities_funding_this_award                             VARCHAR,
    foreign_funding                                                   VARCHAR,
    foreign_funding_description                                       VARCHAR,
    sam_exception                                                     VARCHAR,
    sam_exception_description                                         VARCHAR,
    recipient_uei                                                     VARCHAR,
    recipient_duns                                                    VARCHAR,
    recipient_name                                                    VARCHAR,
    recipient_name_raw                                                VARCHAR,
    recipient_doing_business_as_name                                  VARCHAR,
    cage_code                                                         VARCHAR,
    recipient_parent_uei                                              VARCHAR,
    recipient_parent_duns                                             VARCHAR,
    recipient_parent_name                                             VARCHAR,
    recipient_parent_name_raw                                         VARCHAR,
    recipient_country_code                                            VARCHAR,
    recipient_country_name                                            VARCHAR,
    recipient_address_line_1                                          VARCHAR,
    recipient_address_line_2                                          VARCHAR,
    recipient_city_name                                               VARCHAR,
    prime_award_transaction_recipient_county_fips_code                VARCHAR,
    recipient_county_name                                             VARCHAR,
    prime_award_transaction_recipient_state_fips_code                 VARCHAR,
    recipient_state_code                                              VARCHAR,
    recipient_state_name                                              VARCHAR,
    recipient_zip_4_code                                              VARCHAR,
    prime_award_transaction_recipient_cd_original                     VARCHAR,
    prime_award_transaction_recipient_cd_current                      VARCHAR,
    recipient_phone_number                                            VARCHAR,
    recipient_fax_number                                              VARCHAR,
    primary_place_of_performance_country_code                         VARCHAR,
    primary_place_of_performance_country_name                         VARCHAR,
    primary_place_of_performance_city_name                            VARCHAR,
    prime_award_transaction_place_of_performance_county_fips_code     VARCHAR,
    primary_place_of_performance_county_name                          VARCHAR,
    prime_award_transaction_place_of_performance_state_fips_code      VARCHAR,
    primary_place_of_performance_state_code                           VARCHAR,
    primary_place_of_performance_state_name                           VARCHAR,
    primary_place_of_performance_zip_4                                VARCHAR,
    prime_award_transaction_place_of_performance_cd_original          VARCHAR,
    prime_award_transaction_place_of_performance_cd_current           VARCHAR,
    award_or_idv_flag                                                 VARCHAR,
    award_type_code                                                   VARCHAR,
    award_type                                                        VARCHAR,
    idv_type_code                                                     VARCHAR,
    idv_type                                                          VARCHAR,
    multiple_or_single_award_idv_code                                 VARCHAR,
    multiple_or_single_award_idv                                      VARCHAR,
    type_of_idc_code                                                  VARCHAR,
    type_of_idc                                                       VARCHAR,
    type_of_contract_pricing_code                                     VARCHAR,
    type_of_contract_pricing                                          VARCHAR,
    transaction_description                                           VARCHAR,
    prime_award_base_transaction_description                          VARCHAR,
    action_type_code                                                  VARCHAR,
    action_type                                                       VARCHAR,
    solicitation_identifier                                           VARCHAR,
    number_of_actions                                                 VARCHAR,
    inherently_governmental_functions                                 VARCHAR,
    inherently_governmental_functions_description                     VARCHAR,
    product_or_service_code                                           VARCHAR,
    product_or_service_code_description                               VARCHAR,
    contract_bundling_code                                            VARCHAR,
    contract_bundling                                                 VARCHAR,
    dod_claimant_program_code                                         VARCHAR,
    dod_claimant_program_description                                  VARCHAR,
    naics_code                                                        VARCHAR,
    naics_description                                                 VARCHAR,
    recovered_materials_sustainability_code                           VARCHAR,
    recovered_materials_sustainability                                 VARCHAR,
    domestic_or_foreign_entity_code                                   VARCHAR,
    domestic_or_foreign_entity                                        VARCHAR,
    dod_acquisition_program_code                                      VARCHAR,
    dod_acquisition_program_description                               VARCHAR,
    information_technology_commercial_item_category_code              VARCHAR,
    information_technology_commercial_item_category                   VARCHAR,
    epa_designated_product_code                                       VARCHAR,
    epa_designated_product                                            VARCHAR,
    country_of_product_or_service_origin_code                         VARCHAR,
    country_of_product_or_service_origin                              VARCHAR,
    place_of_manufacture_code                                         VARCHAR,
    place_of_manufacture                                              VARCHAR,
    subcontracting_plan_code                                          VARCHAR,
    subcontracting_plan                                               VARCHAR,
    extent_competed_code                                              VARCHAR,
    extent_competed                                                   VARCHAR,
    solicitation_procedures_code                                      VARCHAR,
    solicitation_procedures                                           VARCHAR,
    type_of_set_aside_code                                            VARCHAR,
    type_of_set_aside                                                 VARCHAR,
    evaluated_preference_code                                         VARCHAR,
    evaluated_preference                                              VARCHAR,
    research_code                                                     VARCHAR,
    research                                                          VARCHAR,
    fair_opportunity_limited_sources_code                             VARCHAR,
    fair_opportunity_limited_sources                                  VARCHAR,
    other_than_full_and_open_competition_code                         VARCHAR,
    other_than_full_and_open_competition                              VARCHAR,
    number_of_offers_received                                         VARCHAR,
    commercial_item_acquisition_procedures_code                       VARCHAR,
    commercial_item_acquisition_procedures                            VARCHAR,
    small_business_competitiveness_demonstration_program              VARCHAR,
    simplified_procedures_for_certain_commercial_items_code           VARCHAR,
    simplified_procedures_for_certain_commercial_items                VARCHAR,
    a76_fair_act_action_code                                          VARCHAR,
    a76_fair_act_action                                               VARCHAR,
    fed_biz_opps_code                                                 VARCHAR,
    fed_biz_opps                                                      VARCHAR,
    local_area_set_aside_code                                         VARCHAR,
    local_area_set_aside                                              VARCHAR,
    price_evaluation_adjustment_preference_percent_difference         VARCHAR,
    clinger_cohen_act_planning_code                                   VARCHAR,
    clinger_cohen_act_planning                                        VARCHAR,
    materials_supplies_articles_equipment_code                        VARCHAR,
    materials_supplies_articles_equipment                             VARCHAR,
    labor_standards_code                                              VARCHAR,
    labor_standards                                                   VARCHAR,
    construction_wage_rate_requirements_code                          VARCHAR,
    construction_wage_rate_requirements                               VARCHAR,
    interagency_contracting_authority_code                            VARCHAR,
    interagency_contracting_authority                                 VARCHAR,
    other_statutory_authority                                         VARCHAR,
    program_acronym                                                   VARCHAR,
    parent_award_type_code                                            VARCHAR,
    parent_award_type                                                 VARCHAR,
    parent_award_single_or_multiple_code                              VARCHAR,
    parent_award_single_or_multiple                                   VARCHAR,
    major_program                                                     VARCHAR,
    national_interest_action_code                                     VARCHAR,
    national_interest_action                                          VARCHAR,
    cost_or_pricing_data_code                                         VARCHAR,
    cost_or_pricing_data                                              VARCHAR,
    cost_accounting_standards_clause_code                             VARCHAR,
    cost_accounting_standards_clause                                  VARCHAR,
    government_furnished_property_code                                VARCHAR,
    government_furnished_property                                     VARCHAR,
    sea_transportation_code                                           VARCHAR,
    sea_transportation                                                VARCHAR,
    undefinitized_action_code                                         VARCHAR,
    undefinitized_action                                              VARCHAR,
    consolidated_contract_code                                        VARCHAR,
    consolidated_contract                                             VARCHAR,
    performance_based_service_acquisition_code                        VARCHAR,
    performance_based_service_acquisition                             VARCHAR,
    multi_year_contract_code                                          VARCHAR,
    multi_year_contract                                               VARCHAR,
    contract_financing_code                                           VARCHAR,
    contract_financing                                                VARCHAR,
    purchase_card_as_payment_method_code                              VARCHAR,
    purchase_card_as_payment_method                                   VARCHAR,
    contingency_humanitarian_or_peacekeeping_operation_code           VARCHAR,
    contingency_humanitarian_or_peacekeeping_operation                VARCHAR,
    alaskan_native_corporation_owned_firm                             VARCHAR,
    american_indian_owned_business                                    VARCHAR,
    indian_tribe_federally_recognized                                 VARCHAR,
    native_hawaiian_organization_owned_firm                           VARCHAR,
    tribally_owned_firm                                               VARCHAR,
    veteran_owned_business                                            VARCHAR,
    service_disabled_veteran_owned_business                           VARCHAR,
    woman_owned_business                                              VARCHAR,
    women_owned_small_business                                        VARCHAR,
    economically_disadvantaged_women_owned_small_business             VARCHAR,
    joint_venture_women_owned_small_business                          VARCHAR,
    joint_venture_economic_disadvantaged_women_owned_small_bus        VARCHAR,
    minority_owned_business                                           VARCHAR,
    subcontinent_asian_asian_indian_american_owned_business           VARCHAR,
    asian_pacific_american_owned_business                             VARCHAR,
    black_american_owned_business                                     VARCHAR,
    hispanic_american_owned_business                                  VARCHAR,
    native_american_owned_business                                    VARCHAR,
    other_minority_owned_business                                     VARCHAR,
    contracting_officers_determination_of_business_size               VARCHAR,
    contracting_officers_determination_of_business_size_code          VARCHAR,
    emerging_small_business                                           VARCHAR,
    community_developed_corporation_owned_firm                        VARCHAR,
    labor_surplus_area_firm                                           VARCHAR,
    us_federal_government                                             VARCHAR,
    federally_funded_research_and_development_corp                    VARCHAR,
    federal_agency                                                    VARCHAR,
    us_state_government                                               VARCHAR,
    us_local_government                                               VARCHAR,
    city_local_government                                             VARCHAR,
    county_local_government                                           VARCHAR,
    inter_municipal_local_government                                  VARCHAR,
    local_government_owned                                            VARCHAR,
    municipality_local_government                                     VARCHAR,
    school_district_local_government                                  VARCHAR,
    township_local_government                                         VARCHAR,
    us_tribal_government                                              VARCHAR,
    foreign_government                                                VARCHAR,
    organizational_type                                               VARCHAR,
    corporate_entity_not_tax_exempt                                   VARCHAR,
    corporate_entity_tax_exempt                                       VARCHAR,
    partnership_or_limited_liability_partnership                      VARCHAR,
    sole_proprietorship                                               VARCHAR,
    small_agricultural_cooperative                                    VARCHAR,
    international_organization                                        VARCHAR,
    us_government_entity                                              VARCHAR,
    community_development_corporation                                 VARCHAR,
    domestic_shelter                                                  VARCHAR,
    educational_institution                                           VARCHAR,
    foundation                                                        VARCHAR,
    hospital_flag                                                     VARCHAR,
    manufacturer_of_goods                                             VARCHAR,
    veterinary_hospital                                               VARCHAR,
    hispanic_servicing_institution                                    VARCHAR,
    receives_contracts                                                VARCHAR,
    receives_financial_assistance                                     VARCHAR,
    receives_contracts_and_financial_assistance                       VARCHAR,
    airport_authority                                                 VARCHAR,
    council_of_governments                                            VARCHAR,
    housing_authorities_public_tribal                                 VARCHAR,
    interstate_entity                                                 VARCHAR,
    planning_commission                                               VARCHAR,
    port_authority                                                    VARCHAR,
    transit_authority                                                 VARCHAR,
    subchapter_scorporation                                           VARCHAR,
    limited_liability_corporation                                     VARCHAR,
    foreign_owned                                                     VARCHAR,
    for_profit_organization                                           VARCHAR,
    nonprofit_organization                                            VARCHAR,
    other_not_for_profit_organization                                 VARCHAR,
    the_ability_one_program                                           VARCHAR,
    private_university_or_college                                     VARCHAR,
    state_controlled_institution_of_higher_learning                   VARCHAR,
    land_grant_college_1862                                           VARCHAR,
    land_grant_college_1890                                           VARCHAR,
    land_grant_college_1994                                           VARCHAR,
    minority_institution                                              VARCHAR,
    historically_black_college                                        VARCHAR,
    tribal_college                                                    VARCHAR,
    alaskan_native_servicing_institution                              VARCHAR,
    native_hawaiian_servicing_institution                             VARCHAR,
    school_of_forestry                                                VARCHAR,
    veterinary_college                                                VARCHAR,
    dot_certified_disadvantage                                        VARCHAR,
    self_certified_small_disadvantaged_business                       VARCHAR,
    small_disadvantaged_business                                      VARCHAR,
    c8a_program_participant                                           VARCHAR,
    historically_underutilized_business_zone_hubzone_firm             VARCHAR,
    sba_certified_8a_joint_venture                                    VARCHAR,
    highly_compensated_officer_1_name                                 VARCHAR,
    highly_compensated_officer_1_amount                               VARCHAR,
    highly_compensated_officer_2_name                                 VARCHAR,
    highly_compensated_officer_2_amount                               VARCHAR,
    highly_compensated_officer_3_name                                 VARCHAR,
    highly_compensated_officer_3_amount                               VARCHAR,
    highly_compensated_officer_4_name                                 VARCHAR,
    highly_compensated_officer_4_amount                               VARCHAR,
    highly_compensated_officer_5_name                                 VARCHAR,
    highly_compensated_officer_5_amount                               VARCHAR,
    usaspending_permalink                                             VARCHAR,
    initial_report_date                                               VARCHAR,
    last_modified_date                                                VARCHAR
);

-- ── INDIANA GATEWAY - NEW BULK TABLES (added 2026-06-08) ─────────────────────

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_CAP_ASSETS (
    year                        VARCHAR,
    cnty_description            VARCHAR,
    cnty_cd                     VARCHAR,
    budget_unit_type            VARCHAR,
    unit_code                   VARCHAR,
    unit_name                   VARCHAR,
    afr_unit_type               VARCHAR,
    cap_a_id                    VARCHAR,
    ent_id                      VARCHAR,
    ent_name                    VARCHAR,
    capital_assets_type_name    VARCHAR,
    beginning_balance           VARCHAR,
    additions                   VARCHAR,
    reductions                  VARCHAR,
    ending_balance              VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_FORM4A (
    year                        VARCHAR,
    cnty_description            VARCHAR,
    cnty_cd                     VARCHAR,
    unit_type                   VARCHAR,
    unit_code                   VARCHAR,
    unit_name                   VARCHAR,
    fund_description            VARCHAR,
    department_label            VARCHAR,
    category_type_id_string     VARCHAR,
    category                    VARCHAR,
    amount_published            VARCHAR,
    amount_approved             VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_FORM4B (
    year                                        VARCHAR,
    cnty_description                            VARCHAR,
    cnty_cd                                     VARCHAR,
    unit_type                                   VARCHAR,
    unit_code                                   VARCHAR,
    unit_name                                   VARCHAR,
    fund_cd                                     VARCHAR,
    fund_description                            VARCHAR,
    total_budget_estimate_published             VARCHAR,
    total_budget_estimate_adopted               VARCHAR,
    necessary_expenditures_published            VARCHAR,
    necessary_expenditures_adopted              VARCHAR,
    additional_appropriation_adopted            VARCHAR,
    additional_appropriation_published          VARCHAR,
    outstanding_temp_loans_paid_published       VARCHAR,
    outstanding_temp_loans_paid_adopted         VARCHAR,
    outstanding_temp_loans_not_repaid_published VARCHAR,
    outstanding_temp_loans_not_repaid_adopted   VARCHAR,
    total_funds_reqd_published                  VARCHAR,
    total_funds_reqd_adopted                    VARCHAR,
    actual_cash_balance_published               VARCHAR,
    actual_cash_balance_adopted                 VARCHAR,
    taxes_to_be_collected_published             VARCHAR,
    taxes_to_be_collected_adopted               VARCHAR,
    misc_revenue_form2_cola_published           VARCHAR,
    misc_revenue_form2_cola_adopted             VARCHAR,
    misc_revenue_form2_colb_published           VARCHAR,
    misc_revenue_form2_colb_adopted             VARCHAR,
    total_funds_published                       VARCHAR,
    total_funds_adopted                         VARCHAR,
    operating_balance_published                 VARCHAR,
    operating_balance_adopted                   VARCHAR,
    prop_tax_repl_cred_published                VARCHAR,
    prop_tax_repl_cred_adopted                  VARCHAR,
    operating_loit_published                    VARCHAR,
    operating_loit_adopted                      VARCHAR,
    net_amt_to_be_raised_published              VARCHAR,
    net_amt_to_be_raised_adopted                VARCHAR,
    levy_excess_fund_published                  VARCHAR,
    levy_excess_fund_adopted                    VARCHAR,
    net_amount_to_be_raised_published           VARCHAR,
    net_amount_to_be_raised_adopted             VARCHAR,
    net_tax_rate_published                      VARCHAR,
    net_tax_rate_adopted                        VARCHAR,
    property_tax_cap_published                  VARCHAR,
    property_tax_cap_adopted                    VARCHAR,
    net_assessed_valuation                      VARCHAR,
    net_to_be_raised_for_expenses_published     VARCHAR,
    net_to_be_raised_for_expenses_adopted       VARCHAR,
    amt_to_be_raised_taxlevy_published          VARCHAR,
    amt_to_be_raised_taxlevy_adopted            VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_GRANTS (
    year                    VARCHAR,
    cnty_description        VARCHAR,
    cnty_cd                 VARCHAR,
    budget_unit_type        VARCHAR,
    unit_code               VARCHAR,
    unit_name               VARCHAR,
    afr_unit_type           VARCHAR,
    cfda_no                 VARCHAR,
    agency_name             VARCHAR,
    grant_program_title     VARCHAR,
    local_project_name      VARCHAR,
    pass_through_agency     VARCHAR,
    award_name              VARCHAR,
    award_number            VARCHAR,
    local_unit_fund_number  VARCHAR,
    local_unit_fund_name    VARCHAR,
    grant_type_code         VARCHAR,
    grant_type_description  VARCHAR,
    receipts                VARCHAR,
    disbursements           VARCHAR,
    subrecipients           VARCHAR,
    loans_outstanding       VARCHAR,
    noncash_assistance      VARCHAR,
    insurance               VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_NONGOV_ENTITIES (
    year                VARCHAR,
    cnty_description    VARCHAR,
    county_cd_fk        VARCHAR,
    budget_unit_type    VARCHAR,
    unit_code           VARCHAR,
    unit_name           VARCHAR,
    afr_unit_type       VARCHAR,
    nongov_type_code    VARCHAR,
    nongov_type         VARCHAR,
    nongov_name         VARCHAR,
    federal_id          VARCHAR,
    address_l1          VARCHAR,
    address_l2          VARCHAR,
    city                VARCHAR,
    state               VARCHAR,
    entity_cnty         VARCHAR,
    entity_cnty_desc    VARCHAR,
    operating_officer   VARCHAR,
    phone_number        VARCHAR,
    nongov_description  VARCHAR,
    amount              VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_TA7 (
    year                VARCHAR,
    cnty_description    VARCHAR,
    cnty_cd             VARCHAR,
    budget_unit_type    VARCHAR,
    unit_code           VARCHAR,
    unit_name           VARCHAR,
    afr_unit_type       VARCHAR,
    question1           VARCHAR,
    question2a          VARCHAR,
    question2b          VARCHAR,
    question2c          VARCHAR,
    question2ci         VARCHAR,
    question2cii        VARCHAR,
    question3           VARCHAR,
    question4           VARCHAR,
    question5a          VARCHAR,
    question5ai         VARCHAR,
    question5b          VARCHAR,
    question6i          VARCHAR,
    question6ii         VARCHAR,
    question6iii        VARCHAR,
    question7a          VARCHAR,
    question7ai         VARCHAR,
    question7b          VARCHAR,
    question8ai         VARCHAR,
    question8aii        VARCHAR,
    question8aiii       VARCHAR,
    question9a          VARCHAR,
    question9ai         VARCHAR,
    question9b          VARCHAR,
    question10i         VARCHAR,
    question10ii        VARCHAR,
    question10iii       VARCHAR,
    question11a         VARCHAR,
    question11ai        VARCHAR,
    question11b         VARCHAR,
    question12i         VARCHAR,
    question12ii        VARCHAR,
    question12iii       VARCHAR,
    question13          VARCHAR,
    question14a         VARCHAR,
    question14bi        VARCHAR,
    question14bii       VARCHAR,
    question15a         VARCHAR,
    question15b         VARCHAR,
    question15ci        VARCHAR,
    question15cii       VARCHAR,
    question15ciii      VARCHAR,
    question16a         VARCHAR,
    question16b         VARCHAR,
    question17          VARCHAR,
    question18          VARCHAR,
    question19i         VARCHAR,
    question19ii        VARCHAR,
    question19iii       VARCHAR,
    question20a         VARCHAR,
    question20b         VARCHAR,
    question20c         VARCHAR,
    question21          VARCHAR,
    question22a         VARCHAR,
    question22b         VARCHAR,
    question23a         VARCHAR,
    question23b         VARCHAR,
    question24ai        VARCHAR,
    question24aii       VARCHAR,
    question24b         VARCHAR,
    question25          VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_DETAILED_REVENUE (
    year                        VARCHAR,
    cnty_description            VARCHAR,
    cnty_cd                     VARCHAR,
    unit_type                   VARCHAR,
    unit_code                   VARCHAR,
    unit_name                   VARCHAR,
    fund_cd                     VARCHAR,
    fund_description            VARCHAR,
    expenditure_cat_id          VARCHAR,
    expenditure_cat_description VARCHAR,
    item_ref_code               VARCHAR,
    item_description            VARCHAR,
    adopted_amount              VARCHAR,
    adopted_amt_pc              VARCHAR,
    pop2010                     VARCHAR
);

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_CASH_INV_COMBINED (
    year                VARCHAR,
    cnty_description    VARCHAR,
    cnty_cd             VARCHAR,
    budget_unit_type    VARCHAR,
    unit_code           VARCHAR,
    unit_name           VARCHAR,
    afr_unit_type       VARCHAR,
    fund_code           VARCHAR,
    unit_fund_number    VARCHAR,
    unit_fund_name      VARCHAR,
    ent_id              VARCHAR,
    ent_name            VARCHAR,
    beg_cash_inv        VARCHAR,
    r_bal               VARCHAR,
    d_bal               VARCHAR,
    cash_bal            VARCHAR
);

-- ── DLGF TOWNSHIP CODE REFERENCE ─────────────────────────────────────────────
-- Source: in.gov/dlgf/files/Townships-by-County.pdf (DLGF Data Analysis Division, May 2023)
-- 1,002 rows — all Indiana townships with state-assigned township numbers
-- Joins GATEWAY_PARCEL.township_number to township names statewide
-- Loader: scripts/load_snowflake_parcel.py (also loads this table)

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.DLGF_TOWNSHIP_CODES (
    county_number    VARCHAR,
    county_name      VARCHAR,
    township_number  VARCHAR,
    township_name    VARCHAR
);

-- ── GATEWAY REAL PROPERTY PARCEL (KAN-128) ───────────────────────────────────
-- Source: gateway.ifionline.org → Property Files → Real Property → PARCEL
-- Format: fixed-width (1,286 bytes/record, 50 IAC 26-20-4)
-- Parser: scripts/parse_gateway_parcel.py → parcel_<cnty>_<yr>p<yr>.csv
-- Coverage: 2022p2023 (pre-SEA-1 baseline) + 2024p2025 (current); ~3.5-4M rows/year
-- Key use: homestead AV share by township for SEA-1 fire fund impact model

CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.GATEWAY_PARCEL (
    assessment_year              VARCHAR,  -- injected from HEADER record
    pay_year                     VARCHAR,  -- injected from HEADER record
    county_number                VARCHAR,  -- injected from HEADER record
    county_description           VARCHAR,  -- injected from HEADER record
    parcel_number                VARCHAR,  -- 1-25
    local_assessor_parcel        VARCHAR,  -- 26-50
    township_number              VARCHAR,  -- 51-54; joins to CERT_NAV
    local_district_number        VARCHAR,  -- 55-57
    state_district_number        VARCHAR,  -- 58-60
    property_address             VARCHAR,  -- 94-153
    property_city                VARCHAR,  -- 154-183
    property_zip                 VARCHAR,  -- 184-193
    property_class_code          VARCHAR,  -- 194-196
    av_total_land                VARCHAR,  -- 469-480
    av_total_improvements        VARCHAR,  -- 481-492
    av_total_land_and_impr       VARCHAR,  -- 493-504
    av_land_1pct                 VARCHAR,  -- 541-552; homestead-eligible land
    av_impr_1pct                 VARCHAR,  -- 553-564; homestead-eligible improvements
    av_nonhs_res_land_2pct       VARCHAR,  -- 565-576
    av_nonhs_res_impr_2pct       VARCHAR,  -- 577-588
    av_apt_land_2pct             VARCHAR,  -- 589-600
    av_apt_impr_2pct             VARCHAR,  -- 601-612
    av_ltc_land_2pct             VARCHAR,  -- 613-624
    av_ltc_impr_2pct             VARCHAR,  -- 625-636
    av_farmland_2pct             VARCHAR,  -- 637-648
    av_mobile_home_land_2pct     VARCHAR,  -- 649-660
    av_land_3pct                 VARCHAR,  -- 661-672
    av_impr_3pct                 VARCHAR,  -- 673-684
    av_classified_land           VARCHAR,  -- 685-696
    legally_deeded_acreage       VARCHAR,  -- 697-708
    prior_av_total_land          VARCHAR,  -- 721-732
    prior_av_total_impr          VARCHAR   -- 733-744
    -- current_av fields (1251-1286) absent from Gateway-distributed files
);

-- ============================================================
-- DATA RETENTION (7-day Time Travel on Standard tier)
-- Snowflake default is 1 day. Run once after initial load.
-- Safe to re-run — SET is idempotent.
-- ============================================================

ALTER TABLE HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE         SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LEGISCAN_BILLS                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LEGISCAN_PEOPLE                 SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LEGISCAN_ROLLCALLS              SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LEGISCAN_VOTES                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LEGISCAN_SPONSORS               SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LOBBYING_EMPLOYER               SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.LOBBYING_COMPENSATED            SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.STATE_EXPENDITURES              SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.VENDOR_EXPENDITURES             SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.FEDERAL_CONTRACTS               SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS           SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_LEGACY    SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_RECEIPTS                SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_LEGACY         SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_TOWNSHIP_VENDOR         SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_TOWNSHIP_VENDOR_LEGACY  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_ECA_EXPENDITURES        SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_ECA_RECEIPTS            SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_ECA_BALANCES            SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_TAX_DISTRIBUTIONS       SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_ENTITY_FUNDS            SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_DISBURSEMENTS_DETAIL    SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_RECEIPTS_DETAIL         SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_FORM22                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_CERT_NAV                SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_CAP_ASSETS              SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_FORM4A                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_FORM4B                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_GRANTS                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_NONGOV_ENTITIES         SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_TA7                     SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_DETAILED_REVENUE        SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_CASH_INV_COMBINED       SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.DLGF_TOWNSHIP_CODES             SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER TABLE HOOSIER_DATA.RAW.GATEWAY_PARCEL                  SET DATA_RETENTION_TIME_IN_DAYS = 7;
