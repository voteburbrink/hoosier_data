# Trustee-Race Fire Targeting Table (KAN-161)

**Purpose.** Prioritize where the VFD/LIT outreach push lands, by overlaying two
signals per township:

1. **Fire need** — what SEA-1 takes and the projected operating shortfall, from
   `ANALYTICS.SEA1_FIRE_IMPACT_SUMMARY` (verified) and `ANALYTICS.FIRE_COST_TREND`
   (full 2011–2024 history, KAN-139).
2. **Political opening** — the 2026 township trustee race: an open seat (no
   primary filing) is the best opportunity to seat a fire-supportive trustee who
   will carry the LIT resolution (IC 6-3.6-6-4.5); the council still votes the
   county-wide rate, but the township must adopt a resolution to be named.

Pairs with **KAN-162** (the per-county `county_config/<county>.json` holds
`trustee_races`) and feeds the packet's targeting.

**Provenance.** Fire-need columns are verified warehouse figures (query
2026-06-12). Trustee-race status comes from `county_config` / county election
results; most rows are **TBD pending 2026 candidate-data collection** — that
collection IS the open half of KAN-161. The **Priority** column is a *proposed*
heuristic (see below), not a final call.

**Proposed priority heuristic** (refine with Josh):
`Need tier` from projected 2027 net gap — High > $100K, Med $25–100K, Low < $25K/neg.
`Opening` — Open seat (no filing) > Contested > Incumbent-uncontested > TBD.
Top targets = High/Med need **and** an open or winnable seat.

---

## Bartholomew County (first researched county)

Net gap and SEA-1 loss in dollars/year. SD-041 county-wide (Walker/Davis on the
ballot). "Open seat" = no 2026 primary filing (KAN-161 election-results pull).

| Township | HD | SEA-1 loss (2031) | Proj. net gap (2027) | Cost conf. | 2026 trustee race | Need | Opening | Priority (proposed) |
|---|---|---:|---:|---|---|---|---|---|
| Harrison | 059 | $21,870 | $241,612 | OK | **TBD** | High | TBD | **Top — confirm race** |
| Ohio | 059 | $9,106 | $155,310 | OK | **TBD** | High | TBD | **Top — confirm race** |
| Columbus | 059 | $505,214 | $117,950 | OK | **TBD** | High | TBD | High need — *municipal* (Columbus city fire); city path, not township LIT |
| Clay | 073 | $9,286 | $43,874 | OK | **TBD** | Med | TBD | Confirm race |
| Hawcreek | 073 | $63,114 | $27,457 | OK | **Open seat** (no filing) | Med | Open | **High — open seat + need** |
| Sandcreek | 073 | $4,153 | $10,943 | OK | **Open seat** (no filing) | Low | Open | Medium — open seat, modest need |
| Clifty | 073 | $2,205 | $1,152 | OK | **TBD** | Low | TBD | Lower |
| German | 059 | $16,766 | −$53,026 | OK | **TBD** | Low/none | TBD | Lower |
| Flatrock | 073 | $7,556 | −$21,429 | OK | **TBD** | Low/none | TBD | Lower |
| Rockcreek | 073 | $5,827 | −$26,599 | OK | **TBD** | Low/none | TBD | Lower |
| Wayne | 059 / 069 (split) | $11,320 | −$81,370 | LOW_CONFIDENCE (2024 collapse vs median) | **TBD** | Data caveat | TBD | Verify — fire service appears relocated |
| Jackson | 059 | $0 | n/a | LOW_CONFIDENCE (no 2024 actual) | **TBD** | Data gap | TBD | Resolve cost data first |

**Reading it:** Harrison and Ohio are the clearest "high need" departments; their
2026 trustee races need confirming. **Hawcreek is the standout actionable target** —
real need *and* an open seat. Columbus dominates the SEA-1-loss column but is the
municipal (city) department, a different funding path. Wayne and Jackson carry
data caveats to resolve before making cost claims.

---

## Remaining packet counties — TBD

One block per county once its `county_config` and 2026 trustee data are
collected (KAN-162 #3 + KAN-161 collection). Until then, fire-need figures can
still be pulled from `SEA1_FIRE_IMPACT_SUMMARY` for any county; only the
trustee-race / opening column needs field research.

| County | Status |
|---|---|
| Bartholomew | Researched (above) |
| *(12 queued counties)* | Pending `county_config` + 2026 trustee candidate data |

## Data-collection checklist (KAN-161)

- [ ] Pull 2026 township-trustee primary results per county (open seats / contested / incumbents).
- [ ] Record current trustee name + contact in each `county_config/<county>.json` `trustee_races.current_trustee`.
- [ ] Regenerate this table's fire-need columns per county from `SEA1_FIRE_IMPACT_SUMMARY`.
- [ ] Confirm Bartholomew trustee names for the 10 non-open-seat townships.
- [ ] Resolve Wayne (service relocation?) and Jackson (no 2024 cost data) caveats.
