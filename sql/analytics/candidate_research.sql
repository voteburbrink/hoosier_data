-- candidate_research.sql
-- Legislator research queries for any Indiana House or Senate district.
-- Run the setup block first to find and set the target legislator.

-- -------------------------------------------------------------------------
-- Setup: find the legislator
-- -------------------------------------------------------------------------

SELECT DISTINCT people_id, name, party, role, district
FROM HOOSIER_DATA.RAW.LEGISCAN_PEOPLE
WHERE district = 'HD-059'        -- change to target district
   OR last_name ILIKE '%Smith%'  -- or search by name
ORDER BY name;

-- Set after finding people_id above
SET target_id = '20210';

-- -------------------------------------------------------------------------
-- 1. Campaign finance summary by contributor type
-- -------------------------------------------------------------------------

SELECT
    contributor_type,
    COUNT(*)                                    AS contributions,
    SUM(TRY_TO_DECIMAL(amount, 18, 2))          AS total_amount
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
WHERE lp.people_id = $target_id
GROUP BY contributor_type
ORDER BY total_amount DESC;

-- -------------------------------------------------------------------------
-- 2. Top 25 donors
-- -------------------------------------------------------------------------

SELECT
    name,
    contributor_type,
    SUM(TRY_TO_DECIMAL(amount, 18, 2))  AS total_amount,
    COUNT(*)                             AS contributions,
    MIN(contribution_date)               AS first_contribution,
    MAX(contribution_date)               AS last_contribution
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
WHERE lp.people_id = $target_id
GROUP BY name, contributor_type
ORDER BY total_amount DESC
LIMIT 25;

-- -------------------------------------------------------------------------
-- 3. PAC donors only
-- -------------------------------------------------------------------------

SELECT
    name,
    SUM(TRY_TO_DECIMAL(amount, 18, 2))  AS total_amount,
    COUNT(*)                             AS contributions
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
WHERE lp.people_id = $target_id
  AND contributor_type ILIKE '%PAC%'
GROUP BY name
ORDER BY total_amount DESC;

-- -------------------------------------------------------------------------
-- 4. Donations by year
-- -------------------------------------------------------------------------

SELECT
    LEFT(contribution_date, 4)          AS year,
    COUNT(*)                             AS contributions,
    SUM(TRY_TO_DECIMAL(amount, 18, 2))  AS total_amount
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
WHERE lp.people_id = $target_id
GROUP BY year
ORDER BY year;

-- -------------------------------------------------------------------------
-- 5. Voting record summary
-- -------------------------------------------------------------------------

SELECT
    vote_desc,
    COUNT(*)                                                       AS votes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)            AS pct
FROM HOOSIER_DATA.RAW.LEGISCAN_VOTES
WHERE people_id = $target_id
GROUP BY vote_desc
ORDER BY votes DESC;

-- -------------------------------------------------------------------------
-- 6. Missed votes (NV or Absent)
-- -------------------------------------------------------------------------

SELECT
    b.bill_number,
    b.title,
    rc.date,
    rc.chamber,
    rc.description,
    v.vote_desc
FROM HOOSIER_DATA.RAW.LEGISCAN_VOTES v
JOIN HOOSIER_DATA.RAW.LEGISCAN_ROLLCALLS rc ON v.roll_call_id = rc.roll_call_id
JOIN HOOSIER_DATA.RAW.LEGISCAN_BILLS b      ON rc.bill_id = b.bill_id
WHERE v.people_id = $target_id
  AND v.vote_desc IN ('NV', 'Absent')
ORDER BY rc.date DESC;

-- -------------------------------------------------------------------------
-- 7. Bills sponsored
-- -------------------------------------------------------------------------

SELECT
    b.bill_number,
    b.title,
    b.status_desc,
    b.last_action_date,
    b.last_action,
    s.position
FROM HOOSIER_DATA.RAW.LEGISCAN_SPONSORS s
JOIN HOOSIER_DATA.RAW.LEGISCAN_BILLS b ON s.bill_id = b.bill_id
WHERE s.people_id = $target_id
ORDER BY b.last_action_date DESC;

-- -------------------------------------------------------------------------
-- 8. Votes by topic keyword
-- -------------------------------------------------------------------------

SELECT
    b.bill_number,
    b.title,
    rc.date,
    v.vote_desc
FROM HOOSIER_DATA.RAW.LEGISCAN_VOTES v
JOIN HOOSIER_DATA.RAW.LEGISCAN_ROLLCALLS rc ON v.roll_call_id = rc.roll_call_id
JOIN HOOSIER_DATA.RAW.LEGISCAN_BILLS b      ON rc.bill_id = b.bill_id
WHERE v.people_id = $target_id
  AND (b.title ILIKE '%EDUCATION%' OR b.description ILIKE '%EDUCATION%')  -- change keyword
ORDER BY rc.date DESC;

-- -------------------------------------------------------------------------
-- 9. PAC donors that also received state contracts
-- -------------------------------------------------------------------------

SELECT
    cf.name                                 AS donor_name,
    SUM(TRY_TO_DECIMAL(cf.amount, 18, 2))   AS donated,
    SUM(TRY_TO_DECIMAL(se.amount, 18, 2))   AS state_payments
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
JOIN HOOSIER_DATA.RAW.STATE_EXPENDITURES se
    ON UPPER(se.vendor_name) ILIKE '%' || UPPER(SPLIT_PART(cf.name, ' ', 1)) || '%'
WHERE lp.people_id = $target_id
  AND cf.contributor_type ILIKE '%PAC%'
GROUP BY cf.name
ORDER BY state_payments DESC;

-- -------------------------------------------------------------------------
-- 10. PAC donors that also received federal contracts
-- -------------------------------------------------------------------------

SELECT
    cf.name                                                         AS donor_name,
    SUM(TRY_TO_DECIMAL(cf.amount, 18, 2))                          AS donated,
    SUM(TRY_TO_DECIMAL(fc.federal_action_obligation, 18, 2))       AS federal_awards
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
JOIN HOOSIER_DATA.RAW.FEDERAL_CONTRACTS fc
    ON UPPER(fc.recipient_name) ILIKE '%' || UPPER(SPLIT_PART(cf.name, ' ', 1)) || '%'
WHERE lp.people_id = $target_id
  AND cf.contributor_type ILIKE '%PAC%'
GROUP BY cf.name
ORDER BY federal_awards DESC;

-- -------------------------------------------------------------------------
-- 11. Out of district donors
-- -------------------------------------------------------------------------

SELECT
    state,
    city,
    COUNT(*)                             AS contributions,
    SUM(TRY_TO_DECIMAL(amount, 18, 2))  AS total_amount
FROM HOOSIER_DATA.RAW.CAMPAIGN_FINANCE_SOURCE cf
JOIN HOOSIER_DATA.RAW.LEGISCAN_PEOPLE lp
    ON UPPER(cf.committee) ILIKE '%' || UPPER(lp.last_name) || '%'
WHERE lp.people_id = $target_id
  AND state != 'IN'
GROUP BY state, city
ORDER BY total_amount DESC;

-- -------------------------------------------------------------------------
-- 12. Active lobbying spend during tenure
-- -------------------------------------------------------------------------

SELECT
    lobbyist,
    SUM(TRY_TO_DECIMAL(grand_totals, 18, 2))    AS total_lobbying_spend,
    COUNT(DISTINCT year)                          AS years_active
FROM HOOSIER_DATA.RAW.LOBBYING_EMPLOYER
GROUP BY lobbyist
ORDER BY total_lobbying_spend DESC
LIMIT 50;

-- -------------------------------------------------------------------------
-- 13. Legislator cross-reference (all external IDs)
-- -------------------------------------------------------------------------

SELECT
    people_id,
    name,
    party,
    role,
    district,
    followthemoney_eid,
    votesmart_id,
    opensecrets_id,
    ballotpedia
FROM HOOSIER_DATA.RAW.LEGISCAN_PEOPLE
WHERE people_id = $target_id
LIMIT 1;
