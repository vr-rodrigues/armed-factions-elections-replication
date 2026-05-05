# Political outcomes and campaign spending status

Date: 2026-05-03

## What was implemented

New political-results script:

- `code/93_political_profile_outcomes.R`

New campaign-finance preparation script:

- `code/94_campaign_finance_outcomes.R`
- `code/download_campaign_finance.ps1`

New derived data:

- `data/candidate_profile_by_location.csv`
- `data/party_bloc_by_location.csv`
- `data/party_specific_by_location.csv`
- `data/ipca_deflator_2024.csv`

New result tables:

- `results/tab93_political_profile_overall.csv`
- `results/tab93_political_profile_es.csv`
- `results/tab93_party_classification_coverage.csv`
- `results/tab94_campaign_finance_availability.csv`
- `results/tab94_campaign_finance_match_quality.csv`
- `results/tab94_campaign_finance_overall.csv`
- `results/tab94_campaign_finance_es.csv`

## Political outcomes constructed

Unit:

- `loc_id x election_year x DS_CARGO`

Candidate profile:

- `elected_vote_share`
- `age_vote_weighted`
- `education_score_vote_weighted`
- `share_college`
- `share_low_education`
- `share_security_occupation`
- `share_public_admin_occupation`
- `share_female`
- `share_black_pardo`

Candidate competition:

- `n_candidates_with_votes`
- `n_competitive_candidates_1pct`
- `n_competitive_candidates_5pct`
- `top_candidate_share`
- `top3_candidate_share`

Party/ideology:

- `left_share`
- `center_share`
- `right_share`
- `ideology_score_vote_weighted`
- `pt_share`
- `pl_pr_share`
- `pl_pr_minus_pt_share`

Party ideology follows Table A1 in Colonnelli, Pinho Neto, and Teso (2025),
`Politics at Work`, with left/center/right mapped by party acronym. The script
also maps direct TSE aliases and post-2019 renamed/merged labels where the Table
A1 party has a clear continuation: PMDB/MDB, PR/PL, PSDC/DC, PT do B/AVANTE,
PTN/PODE, PRB/Republicanos, PPS/Cidadania, PTC/AGIR, PMN/MOBILIZA, and
DEM/PSL/UNIAO. PRD is left unclassified because it combines PTB and Patriota
lineages, which belong to different Table A1 blocs.

Classification coverage is audited in
`results/tab93_party_classification_coverage.csv`. All candidate votes are
classified from 2008 through 2020. In 2024, classification coverage is 99.7%
for prefeito and 95.9% for vereador; the remaining unclassified votes are PRD.

Party-specific PT versus PL/PR outcomes are candidate-party vote shares, not
coalition shares. `pl_pr_share` treats the historical PR label as the same
party lineage as PL. After review, these party-specific checks should not be
used in the paper; the paper should report the aggregate ideology result as a
null effect.

Raw data used:

- `votacao_secao_RJ_{2008,2012,2016,2020,2024}.csv`
- `consulta_cand_{2008,2012,2016,2020,2024}_RJ.csv`

The script found these files in:

- `../legado/01_workspace_pre_replication/dados/tse`

## Main political results so far

Estimator emphasized here:

- CS-DID with not-yet-treated controls, matching the preferred specification in the paper.

### Militia, prefeito

This is the strongest new mechanism table.

- `elected_vote_share`: +0.0448, p < 0.001.
- `n_competitive_candidates_1pct`: -0.5622, p < 0.001.
- `top_candidate_share`: +0.0457, p < 0.001.
- `top3_candidate_share`: +0.0290, p < 0.001.
- `share_public_admin_occupation`: +0.0478, p < 0.001.
- `share_female`: -0.0243, p < 0.001.
- `share_black_pardo`: -0.0082, p = 0.008.
- `education_score_vote_weighted`: +0.0370, p = 0.026.
- `ideology_score_vote_weighted`: -0.0112, p = 0.565.
- `pt_share`: +0.0310, p = 0.001.
- `pl_pr_share`: -0.0049, p = 0.455.
- `pl_pr_minus_pt_share`: -0.0359, p = 0.017.

Interpretation:

- The new outcomes reinforce the paper's core result: militia control concentrates mayoral vote around electorally viable/local winners.
- The mechanism looks less like general political withdrawal and more like selection/concentration toward candidates who are already viable or institutionally embedded.
- With the Colonnelli et al. classification, the preferred NYT estimates do not support an ideological-composition mechanism.
- The PT versus PL/PR split is parked and should not be part of the paper's substantive claim. We keep the aggregate ideology null.

### Militia, vereador

- `share_college`: +0.0268, p = 0.0067.
- `share_female`: -0.0264, p < 0.001.
- `pt_share`: +0.0071, p = 0.035.
- `pl_pr_minus_pt_share`: -0.0044, p = 0.373.
- Most concentration outcomes are small and statistically weak.

Interpretation:

- This is consistent with the existing paper: the strong competition effect is mainly in mayoral races, not council races.
- Candidate-profile shifts may still be useful as appendix evidence.

### Drug factions

For drug factions, most competition/profile outcomes are weaker or null under the preferred not-yet-treated estimator.

Prefeito:

- `share_female`: -0.0407, p = 0.033.
- `share_black_pardo`: +0.0532, p = 0.013.
- Concentration and ideology outcomes are mostly null.

Vereador:

- Most outcomes are statistically weak under NYT.

Interpretation:

- The contrast with militia remains useful: militia shows a clear mayoral candidate-selection/concentration signature; drug factions do not.

## Campaign finance status and results

The campaign finance archives were downloaded from the official TSE resources
and processed into candidate-level and location-level spending outcomes.
Monetary values are deflated to 2024 reais using IPCA from Banco Central do
Brasil SGS series 433.

Official TSE resources identified:

- 2008: `prestacao_contas_2008.zip`
- 2012: `prestacao_final_2012.zip`
- 2016: `prestacao_contas_final_2016.zip`
- 2020: `prestacao_de_contas_eleitorais_candidatos_2020.zip`
- 2024: `prestacao_de_contas_eleitorais_candidatos_2024.zip`

Current local status:

- All five archives are present under `data/raw/tse/prestacao_contas`.

The downloader/resumer is:

```powershell
.\code\download_campaign_finance.ps1
```

The processing script is:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" code\94_campaign_finance_outcomes.R
```

Derived data:

- `data/campaign_finance_by_candidate.csv`
- `data/campaign_finance_by_location.csv`
- `data/ipca_deflator_2024.csv`

Match quality:

- Prefeito: mean vote-level match ranges from about 96.1% in 2008 to 99.3% in 2024.
- Vereador: mean vote-level match ranges from about 90.4% in 2008 to 99.9% in 2024.

Main CS-DID results, preferred NYT estimator:

### Militia, prefeito

- `expenses_vote_weighted`: +427,981, p = 0.044.
- `revenue_vote_weighted`: +750,328, p = 0.009.
- `expenses_per_vote_weighted`: -0.552, p = 0.033.
- `high_expense_vote_share`: +0.0158, p = 0.012.
- `finance_vote_match_share`: -0.0003, p = 0.734.

Interpretation:

- In militia-controlled mayoral races, local votes shift toward candidates with higher real campaign spending/revenue.
- At the same time, real spending per vote falls, suggesting greater vote efficiency rather than simply more expensive campaigning.
- This aligns with the main mechanism: militia control concentrates votes around viable candidates and may make vote production more efficient.

### Militia, vereador

- `expenses_vote_weighted`: +2,277, p = 0.719.
- `revenue_vote_weighted`: +8,068, p = 0.196.
- `high_expense_vote_share`: +0.0226, p = 0.026.
- `expenses_per_vote_weighted`: -0.238, p = 0.436.

Interpretation:

- Some evidence that votes shift toward high-spending council candidates, but real spending and revenue levels do not move detectably.

### Drug factions

- Most spending outcomes are statistically weak under the preferred NYT estimator.
- Drug/prefeito has no detectable effect on real spending, high-spending vote share, or spending per vote.

Interpretation:

- The finance mechanism appears more specific to militia control than to armed-group presence in general.

## Recommended next step

For writing the paper now:

1. Use the `Militia x Prefeito` political-profile results as the next mechanism table.
2. Keep `Vereador` and `Drug` results in an appendix or robustness-style mechanism table.
3. Add one short paragraph: militia control increases vote concentration not only mechanically via HHI/top share, but also by increasing the share of votes going to candidates who ultimately win.
4. Report ideology only in aggregate, using the Colonnelli et al. classification, as a null result.

For campaign finance:

1. Present campaign finance in 2024 reais.
2. Add a compact main-text mechanism table for mayoral races.
3. Keep council and drug-faction estimates in appendix.
4. Add a short data note on match quality and candidate identifiers.
