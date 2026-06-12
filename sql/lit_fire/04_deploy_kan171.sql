-- ============================================================
-- KAN-171: SEA-1 Deduction Parameter Correction
-- Statute-verified reload of RAW.SEA1_DEDUCTION_PARAMS
--
-- Sources verified 2026-06-12:
--   DLGF Commissioner memo (Cockerill), 2025-06-12:
--     in.gov/dlgf/files/2025-memos/250612-Cockerill-Memo-...
--   2025 Indiana Code, IC 6-1.1-12-37.5 (supplemental deduction full text)
--
-- Run as ACCOUNTADMIN. TRUNCATE is safe — views recompute on query;
-- no data is permanently lost. Never CREATE OR REPLACE the table
-- (June 5 2026 incident: dropped ~22M rows across 8 tables).
--
-- Convention: phase_year = PAY year throughout.
-- Pay year = assessment year + 1.
--
-- After running this script:
--   1. Redeploy affected views via apply_view.py (sea1_impact.sql):
--        python scripts/apply_view.py SEA1_HOMESTEAD_LOSS --file sql/analytics/sea1_impact.sql
--        python scripts/apply_view.py SEA1_BPP_LOSS --file sql/analytics/sea1_impact.sql
--        python scripts/apply_view.py SEA1_2PCT_BUCKET_LOSS --file sql/analytics/sea1_impact.sql
--        python scripts/apply_view.py SEA1_FIRE_IMPACT_SUMMARY --file sql/analytics/sea1_impact.sql
--        python scripts/apply_view.py SEA1_FIRE_DISTRICT_IMPACT --file sql/analytics/sea1_impact.sql
--   2. Re-query downstream views; record new Bartholomew loss totals.
--   3. Update Confluence main analysis page headline figures.
-- ============================================================

TRUNCATE TABLE HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS;

INSERT INTO HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
    (mechanism, phase_year, param_name, param_value, old_law_value, verified, source_note)
VALUES

-- ── HOMESTEAD: standard deduction, IC 6-1.1-12-37 (SEA 1 Sec. 44) ───────────
-- New law: flat dollar amount, declining to $0 by pay 2031.
-- Old law counterfactual: LEAST(60% of AV, $48,000) — hardcoded in view logic.
('HOMESTEAD', 2026, 'STD_DED_AMT', 48000, 48000, TRUE,
 'IC 6-1.1-12-37 per SEA 1 s44; DLGF memo 2025-06-12. Pay 2026: flat $48K (60%-lesser-of formula dropped). Old-law LEAST(0.6*AV,48000) hardcoded in view.'),
('HOMESTEAD', 2027, 'STD_DED_AMT', 40000, 48000, TRUE,
 'IC 6-1.1-12-37 per SEA 1 s44; DLGF memo 2025-06-12.'),
('HOMESTEAD', 2028, 'STD_DED_AMT', 30000, 48000, TRUE,
 'IC 6-1.1-12-37 per SEA 1 s44; DLGF memo 2025-06-12.'),
('HOMESTEAD', 2029, 'STD_DED_AMT', 20000, 48000, TRUE,
 'IC 6-1.1-12-37 per SEA 1 s44; DLGF memo 2025-06-12.'),
('HOMESTEAD', 2030, 'STD_DED_AMT', 10000, 48000, TRUE,
 'IC 6-1.1-12-37 per SEA 1 s44; DLGF memo 2025-06-12.'),
('HOMESTEAD', 2031, 'STD_DED_AMT',     0, 48000, TRUE,
 'IC 6-1.1-12-37 per SEA 1 s44; DLGF memo 2025-06-12.'),

-- ── HOMESTEAD: supplemental deduction single rate, IC 6-1.1-12-37.5 (SEA 1 Sec. 45) ──
-- New law: single escalating rate × (AV minus standard), capped at 75% of gross AV.
-- Old-law tier structure (37.5%/27.5%/$600K) is hardcoded in view logic.
('HOMESTEAD', 2026, 'SUPP_RATE', 0.40,  NULL, TRUE,
 'IC 6-1.1-12-37.5(c) per SEA 1 s45; 2025 IC text. Single rate replaces 37.5%/27.5% tiers.'),
('HOMESTEAD', 2027, 'SUPP_RATE', 0.46,  NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2028, 'SUPP_RATE', 0.52,  NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2029, 'SUPP_RATE', 0.57,  NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2030, 'SUPP_RATE', 0.62,  NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2031, 'SUPP_RATE', 0.667, NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),

-- ── HOMESTEAD: supplemental 75% gross AV cap, IC 6-1.1-12-37.5(c) flush ─────
-- Applies all pay years 2026+. Stored once; view reads MAX() across phase_years.
('HOMESTEAD', 2026, 'SUPP_CAP_PCT_GROSS_AV', 0.75, NULL, TRUE,
 'IC 6-1.1-12-37.5(c) flush: deduction may not exceed 75% of gross AV. Applies all pay years 2026+.'),
('HOMESTEAD', 2027, 'SUPP_CAP_PCT_GROSS_AV', 0.75, NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2028, 'SUPP_CAP_PCT_GROSS_AV', 0.75, NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2029, 'SUPP_CAP_PCT_GROSS_AV', 0.75, NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2030, 'SUPP_CAP_PCT_GROSS_AV', 0.75, NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),
('HOMESTEAD', 2031, 'SUPP_CAP_PCT_GROSS_AV', 0.75, NULL, TRUE,
 'IC 6-1.1-12-37.5(c).'),

-- ── 2PCT_BUCKET: statutory phase-in, NEW IC 6-1.1-12-47 (SEA 1 Sec. 52) ──────
-- Applies to non-homestead residential, long-term care, agricultural land (2%-cap property).
-- Applied after all other deductions. Old law: no deduction (0%).
('2PCT_BUCKET', 2026, 'BUCKET_DED_PCT', 0.06,  0, TRUE,
 'IC 6-1.1-12-47(c)(1) per SEA 1 s52; DLGF memo 2025-06-12. Applied after all other deductions.'),
('2PCT_BUCKET', 2027, 'BUCKET_DED_PCT', 0.12,  0, TRUE,
 'IC 6-1.1-12-47(c)(2).'),
('2PCT_BUCKET', 2028, 'BUCKET_DED_PCT', 0.19,  0, TRUE,
 'IC 6-1.1-12-47(c)(3).'),
('2PCT_BUCKET', 2029, 'BUCKET_DED_PCT', 0.25,  0, TRUE,
 'IC 6-1.1-12-47(c)(4).'),
('2PCT_BUCKET', 2030, 'BUCKET_DED_PCT', 0.30,  0, TRUE,
 'IC 6-1.1-12-47(c)(5).'),
('2PCT_BUCKET', 2031, 'BUCKET_DED_PCT', 0.334, 0, TRUE,
 'IC 6-1.1-12-47(c)(6). Statutory text: 33.4%, not 33.33% linear.'),

-- ── BPP: exemption threshold, IC 6-1.1-3-7.2 (SEA 1 Sec. 6 / HEA 1427 Sec. 14) ──
-- HEA 1427 REPEALED the 2025-assessment increase SEA 1 originally enacted ($1M).
-- Verified schedule: $80K through 2025 assessment (pay 2026); $2M from 2026 assessment (pay 2027).
('BPP', 2026, 'BPP_EXEMPTION_THRESHOLD',   80000, 80000, TRUE,
 'IC 6-1.1-3-7.2: HEA 1427 s14 repealed SEA 1 2025-assessment increase. $80K threshold through 2025 assessment = pay 2026. Loss = $0 for pay 2026.'),
('BPP', 2027, 'BPP_EXEMPTION_THRESHOLD', 2000000, 80000, TRUE,
 'IC 6-1.1-3-7.2 per SEA 1 s6 / HEA 1427 s14: $2M threshold from 2026 assessment = pay 2027.'),
('BPP', 2028, 'BPP_EXEMPTION_THRESHOLD', 2000000, 80000, TRUE,
 'IC 6-1.1-3-7.2.'),
('BPP', 2029, 'BPP_EXEMPTION_THRESHOLD', 2000000, 80000, TRUE,
 'IC 6-1.1-3-7.2.'),
('BPP', 2030, 'BPP_EXEMPTION_THRESHOLD', 2000000, 80000, TRUE,
 'IC 6-1.1-3-7.2.'),
('BPP', 2031, 'BPP_EXEMPTION_THRESHOLD', 2000000, 80000, TRUE,
 'IC 6-1.1-3-7.2.');

-- ── Verify the reload ─────────────────────────────────────────────────────────
SELECT mechanism, phase_year, param_name, param_value, verified
FROM HOOSIER_DATA.RAW.SEA1_DEDUCTION_PARAMS
ORDER BY mechanism, phase_year, param_name;
-- Expected: 30 rows total (6 HOMESTEAD STD_DED_AMT + 6 SUPP_RATE + 6 SUPP_CAP + 6 2PCT + 6 BPP)
