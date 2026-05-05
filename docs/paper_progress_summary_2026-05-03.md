# Paper progress summary

Date: 2026-05-03

## Current paper line

The paper should keep the main argument focused on electoral capture through executive-race vote concentration. The strongest and cleanest mechanism is:

- militia territorial entry compresses mayoral competition;
- votes concentrate around viable/winning candidates;
- campaign spending evidence suggests votes shift toward better-financed candidates and become more vote-efficient;
- drug-faction entry and city-council races do not show comparable patterns.

The paper should not claim an ideological mechanism. Using the Colonnelli, Pinho Neto, and Teso (2025) left/center/right classification, aggregate ideology outcomes are null in the preferred not-yet-treated estimator.

## Organization completed

- Cleaned and reorganized the project folder so the active material is concentrated in `paper/`, `replication_package/`, and `literatura/`.
- Moved older or superseded material to `legado/`.
- Kept the replication package as the active computational source for new results.
- Regenerated file manifests and SHA-256 checksums after new data/results/docs were added.

## Paper edits completed

- Simplified the title to `Armed Factions and Local Electoral Competition`.
- Added the Colonnelli, Pinho Neto, and Teso (2025) citation to the paper bibliographies.
- Kept economic-outcome mechanisms out of the current paper direction.
- Added the new mayoral and city-council mechanism tables and coefficient-plot figures to `paper/main.tex`.
- Compiled the updated paper PDF at `paper/main.pdf`.

## Economic data audit

We audited the Data.Rio idea for georeferenced economic outcomes. The economic mechanism was then put aside by decision. Nothing from this line should enter the current paper draft, except possibly a short internal note that we considered and parked economic outcomes because the main next step became political profiles and campaign spending.

## Political-profile outcomes created

Script:

- `code/93_political_profile_outcomes.R`

Derived data:

- `data/candidate_profile_by_location.csv`
- `data/party_bloc_by_location.csv`
- `data/party_specific_by_location.csv`

Result tables:

- `results/tab93_political_profile_overall.csv`
- `results/tab93_political_profile_es.csv`
- `results/tab93_party_classification_coverage.csv`

Constructed outcomes:

- candidate viability and concentration: `elected_vote_share`, `n_competitive_candidates_1pct`, `top_candidate_share`, `top3_candidate_share`;
- candidate profile: age, education, college, low education, security occupation, public administration occupation, gender, race;
- ideology aggregates: `left_share`, `right_share`, `ideology_score_vote_weighted`.

Party-specific PT versus PL/PR checks were created but should not be used in the paper. They are parked because the agreed paper line is the aggregate ideology null.

## Political-profile results to use

Preferred estimator: CS-DID with not-yet-treated controls.

Main mechanism table should focus on `Militia x Prefeito`:

- `elected_vote_share`: +0.0448, p < 0.001.
- `n_competitive_candidates_1pct`: -0.5622, p < 0.001.
- `top_candidate_share`: +0.0457, p < 0.001.
- `top3_candidate_share`: +0.0290, p < 0.001.
- `share_public_admin_occupation`: +0.0478, p < 0.001.
- `share_female`: -0.0243, p < 0.001.
- `share_black_pardo`: about -0.0082, p < 0.01.
- `education_score_vote_weighted`: about +0.0370, p < 0.05.

Interpretation for paper:

- The evidence reinforces the main electoral-compression result.
- Militia entry shifts votes toward electorally viable candidates and candidates who ultimately win.
- The mechanism looks like coordination/selection around viable executive candidates, not broad political disengagement.

## Ideology result

Classification:

- Use Colonnelli, Pinho Neto, and Teso (2025), Table A1.
- Classify by party acronym and map direct aliases/successor labels where appropriate.
- Coverage is complete for 2008-2020 and high in 2024; the remaining unclassified party is PRD.

Result to report:

- `Militia x Prefeito`, `ideology_score_vote_weighted`: -0.0112, p = 0.565.

Interpretation for paper:

- No aggregate ideology effect.
- This should appear as a null mechanism/diagnostic result, not as a central table unless space allows.

## Campaign-finance outcomes created

Scripts:

- `code/download_campaign_finance.ps1`
- `code/94_campaign_finance_outcomes.R`

Raw TSE campaign-finance archives downloaded:

- 2008, 2012, 2016, 2020, and 2024.

Derived data:

- `data/campaign_finance_by_candidate.csv`
- `data/campaign_finance_by_location.csv`
- `data/ipca_deflator_2024.csv`

Result tables:

- `results/tab94_campaign_finance_availability.csv`
- `results/tab94_campaign_finance_match_quality.csv`
- `results/tab94_campaign_finance_overall.csv`
- `results/tab94_campaign_finance_es.csv`

Match quality:

- Prefeito: vote-level match is roughly 96.1% to 99.3% across years.
- Vereador: vote-level match is roughly 90.4% to 99.9% across years.

## Campaign-finance results to use

Main table should focus on `Militia x Prefeito`. Monetary outcomes are in
2024 reais, deflated using IPCA from Banco Central do Brasil SGS series 433:

- `expenses_vote_weighted`: +427,981, p = 0.044.
- `revenue_vote_weighted`: +750,328, p = 0.009.
- `expenses_per_vote_weighted`: -0.552, p = 0.033.
- `high_expense_vote_share`: +0.0158, p = 0.012.
- `finance_vote_match_share`: null.

Interpretation for paper:

- In militia-controlled mayoral races, votes shift toward candidates with higher real campaign spending and revenue.
- Real spending per vote falls, which suggests greater vote efficiency rather than simply more expensive campaigning.
- This complements the political-profile mechanism: militia control concentrates votes around viable and better-financed mayoral candidates.

## Results for appendix

Good appendix material:

- `Militia x Vereador` political-profile outcomes: some candidate-profile shifts, but no comparable competition/concentration mechanism.
- `Drug x Prefeito` and `Drug x Vereador`: mostly null or weaker results, useful for contrast.
- Campaign-finance results for vereador and drug-faction specifications.
- Ideology coverage and classification details.

## What should go into the paper now

Main text:

1. Keep the existing main CS-DID competition results as the core.
2. Add a mechanism table for `Militia x Prefeito` political-profile outcomes: elected vote share, top candidate share, top-three share, competitive candidates, and maybe public-administration occupation.
3. Add a compact campaign-finance mechanism table for `Militia x Prefeito`: real spending, real revenue, real spending per vote, high-spending vote share.
4. Add one paragraph saying aggregate ideology does not move under Colonnelli et al. classification.

Implemented in the current PDF:

- `Table 6`: mechanism outcomes in mayoral races.
- `Figure 3`: panel coefficient plot for mayoral mechanisms.
- `Table 8`: mechanism outcomes in city-council races.
- `Figure 5`: panel coefficient plot for city-council mechanisms.

Appendix:

1. Full political-profile table for all faction-office combinations.
2. Full campaign-finance table for all faction-office combinations.
3. Event-study versions of the new mechanism outcomes.
4. Party classification and match-quality audits.

Do not include:

- Data.Rio/economic-outcome mechanisms.
- PT versus PL/PR party-specific claims.
- A strong ideological interpretation.
