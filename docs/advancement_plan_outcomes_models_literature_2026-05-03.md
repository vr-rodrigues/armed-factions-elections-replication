# Advancement plan: candidate, campaign, and economic extensions

Date: 2026-05-03

## Goal

Extend the paper without changing its core identity. The main paper remains about armed factions and local electoral competition. The next work should add mechanism evidence on candidate selection, campaign finance, ideology, and local economic organization.

## Current empirical base

Current unit:

- `loc_id x election_year x DS_CARGO`

Current treatment data:

- `locais_votacao_treatment_annual.csv`
- `loc_faction_changes.csv`
- `loc_to_territory.csv`
- `territory_to_cluster.csv`

Current outcome data:

- `electoral_competition_measures.csv`
- `qt_aptos_by_location.csv`
- `ideology_share_by_location.csv`

Current main outcomes:

- `hhi`
- `enc`
- `margin_victory`
- `turnout`
- turnout decomposition outcomes in `90_turnout_decomposition.R`

Preferred current estimator:

- Callaway and Sant'Anna staggered DiD with not-yet-treated controls.

## Workstream A: Candidate profile outcomes

Priority: very high.

Reason: closest to the coauthor request and easiest to integrate with the current paper.

### Data

Source:

- TSE candidate files: https://dadosabertos.tse.jus.br/dataset/candidatos-2024
- Historical candidate files for 2008, 2012, 2016, 2020, 2024.

Inputs to collect or reconstruct:

- `consulta_cand_2008_RJ.csv`
- `consulta_cand_2012_RJ.csv`
- `consulta_cand_2016_RJ.csv`
- `consulta_cand_2020_RJ.csv`
- `consulta_cand_2024_RJ.csv`
- candidate identifiers compatible with section-level vote files.

Key fields:

- candidate id: `SQ_CANDIDATO` or stable election-year candidate key.
- candidate name: `NM_CANDIDATO`, `NM_URNA_CANDIDATO`.
- party: `SG_PARTIDO`.
- office: `DS_CARGO`.
- municipality: `CD_MUNICIPIO`, `NM_MUNICIPIO`.
- age or birth date: `NR_IDADE_DATA_POSSE`, `DT_NASCIMENTO`.
- education: `DS_GRAU_INSTRUCAO`.
- occupation: `DS_OCUPACAO`.
- gender/race if consistently available.
- elected status: `DS_SIT_TOT_TURNO` or comparable result variable.

### Variables

Candidate-weighted local profile:

- `age_vote_weighted`: sum of candidate age times local candidate vote share.
- `education_years_vote_weighted`: sum of education score times local candidate vote share.
- `share_low_education`: vote share going to candidates below completed secondary education.
- `share_college`: vote share going to candidates with completed higher education or more.
- `occupation_security_share`: vote share going to police, military, security, armed forces, or law-enforcement occupations.
- `occupation_public_admin_share`: vote share going to public administrators, civil servants, and elected officials.
- `share_incumbent_or_prior_office`: if incumbent/prior-office status can be reconstructed.

Elected-candidate profile:

- `elected_vote_share`: share of local votes going to candidates who are elected.
- `elected_age_vote_weighted`.
- `elected_education_vote_weighted`.
- `elected_security_occupation_share`.

Candidate supply:

- `n_candidates_local_votes`: number of candidates receiving at least one vote in the local unit.
- `n_competitive_candidates_1pct`: number of candidates receiving at least 1 percent of local valid votes.
- `n_competitive_candidates_5pct`: number of candidates receiving at least 5 percent of local valid votes.
- `top3_share`: share of local votes going to top three candidates.

### Models

Primary:

- Same CS-DID framework as current main tables.
- Outcome unit: `loc_id x election_year x DS_CARGO`.
- Estimate separately for `Prefeito` and `Vereador`.
- Preferred control group: not-yet-treated.

Secondary:

- Event-study plots for high-priority outcomes.
- Never-treated controls as appendix/robustness.

### Deliverables

- `data/candidate_profile_by_location.csv`
- `code/93_candidate_profile_outcomes.R`
- `results/tab93_candidate_profile_overall.csv`
- `results/tab93_candidate_profile_es.csv`
- selected figure for event study, only if readable.

## Workstream B: Ideology and party bloc outcomes

Priority: high, but depends on classification quality.

Reason: already partially present in `ideology_share_by_location.csv`, but should be expanded and documented.

### Data

Sources:

- TSE candidate and result files.
- Existing `ideology_share_by_location.csv`.
- Party ideology classification from literature or external coding.

Potential ideology sources:

- Power and Zucco party ideology surveys.
- Brazilian party ideology classifications used in political economy papers.
- Manifesto/proposal text for mayoral races only, if classification is feasible.
- Simpler bloc coding: left, center, right, evangelical/conservative, law-and-order.

### Variables

Core:

- `left_share`
- `right_share`
- `center_share`
- `ideology_score_vote_weighted`
- `ideology_abs_extreme_share`
- `law_order_candidate_share`, based on party, occupation, or explicit coding.

Auxiliary:

- `party_fragmentation_hhi`
- `n_parties_with_votes`
- `party_top1_share`
- `party_top3_share`

### Models

Primary:

- CS-DID at `loc_id x election_year x DS_CARGO`.

Secondary:

- Event study only for `ideology_score_vote_weighted`, `right_share`, and `law_order_candidate_share`.
- Family-wise grouping of ideology outcomes to avoid kitchen-sink interpretation.

### Deliverables

- expand or replace `data/ideology_share_by_location.csv`.
- `code/94_ideology_party_bloc_outcomes.R`
- `results/tab94_ideology_overall.csv`
- appendix table documenting party classification.

## Workstream C: Campaign finance and vote efficiency

Priority: high.

Reason: speaks directly to whether armed groups lower campaign costs, redirect spending, or substitute coercive brokerage for normal campaigning.

### Data

Sources:

- TSE campaign finance group: https://dadosabertos.tse.jus.br/dataset/?groups=prestacao-de-contas-eleitorais
- Historical files for municipal elections 2008, 2012, 2016, 2020, 2024.

Inputs:

- candidate expenses.
- candidate revenues.
- supplier records if usable.
- candidate CNPJ campaign identifiers.

Key fields:

- candidate id or campaign CNPJ.
- election year.
- office.
- municipality.
- total expenses.
- total revenues.
- expense categories.
- donor/supplier geography if available and reliable.

### Variables

Candidate-level measures:

- `candidate_total_expenses`.
- `candidate_total_revenues`.
- `candidate_expenses_per_vote_municipal`.
- `candidate_self_finance_share`.
- `candidate_party_transfer_share`.
- `candidate_business_supplier_share`, if available and legally/ethically usable.

Local vote-weighted outcomes:

- `expenses_vote_weighted`: sum of candidate spending times local vote share.
- `revenues_vote_weighted`.
- `expenses_per_vote_weighted`.
- `share_votes_high_spending_candidates`: local vote share to top spending quartile.
- `share_votes_low_spending_candidates`: local vote share to bottom spending quartile.
- `vote_efficiency_top1`: local top candidate votes divided by that candidate's total spending.

### Models

Primary:

- CS-DID for vote-weighted campaign outcomes at `loc_id x election_year x DS_CARGO`.

Secondary:

- Candidate-level model: candidate vote share in local unit as outcome, with candidate fixed effects where feasible.
- Triple interaction: `militia treated x post x high-spending candidate`.

Suggested candidate-level specification:

`vote_share_candidate_loc_year = beta * militia_post_loc_year * high_spending_candidate_year + candidate_year FE + loc FE + election_year FE + error`

Use this only as mechanism evidence, not as the main estimator.

### Deliverables

- `data/campaign_finance_by_candidate.csv`
- `data/campaign_finance_by_location.csv`
- `code/95_campaign_finance_outcomes.R`
- `results/tab95_campaign_finance_overall.csv`

## Workstream D: Economic mechanism pilot

Priority: medium-high, with a strict feasibility gate.

Reason: potentially valuable, but geography and timing may not support main-text causal claims.

### Data

Primary sources:

- Data.Rio: https://www.data.rio/
- Rio datalake: https://www.dados.rio/datalake
- BCadastro CNPJ catalog: https://data-catalog.iplan.dados.rio/api_bcadastro/
- Receita Federal CNPJ public layout: https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/convenios-e-transferencias/compartilhamento-de-bases-de-dados-2013-decreto-no-8-789-2016/leiaute-das-bases/dados-da-base-cnpj

Candidate tables:

- BCadastro/CNPJ mart.
- SICOP or urban licensing tables.
- Divida Ativa.
- Mais-Valia.

### Feasibility audit

Before estimating effects, report:

- number of records by year.
- share with usable date.
- share with usable address.
- share geocoded.
- share matched to armed-group geography.
- share matched to election geography.
- address quality by source and year.
- whether pre-treatment years exist for enough treated units.

### Variables

CNPJ/business outcomes:

- `n_active_firms_area_year`.
- `n_new_firms_area_year`.
- `n_inactive_or_closed_firms_area_year`.
- `net_entry_area_year`.
- `mean_capital_social`.
- `median_capital_social`.
- `share_mei_or_micro`.
- `share_small_business`.
- `sector_share_exposed`.
- `sector_hhi_area_year`.
- `n_active_firms_exposed_sector`.

Exposed sectors:

- construction.
- real estate.
- local transport.
- gas and household utilities.
- telecom/internet.
- private security.
- household and neighborhood services.
- local retail.

Licensing outcomes:

- `n_licenses_area_year`.
- `licensed_area_m2`.
- `n_units_licensed`.
- `share_residential_use`.
- `share_commercial_use`.
- `construction_license_intensity`.

Fiscal/real-estate exploratory outcomes:

- `n_divida_ativa_records`.
- `value_divida_ativa`.
- `n_iptu_linked_records`.
- `n_mais_valia_records`.
- `value_mais_valia`.
- `payment_or_regularization_status`.

### Geography

Do not force polling-station geography if the data do not support it.

Candidate units:

- `bairro x year`.
- `grid_cell x year`, e.g. 250m or 500m grid.
- `territory x year`.
- `buffer around polling station x year`, only if geocoding is precise.
- `area x CNAE x year` for sectoral models.

### Models

Feasibility gate:

- If geocoding/match rate is low or uneven over time, keep this as descriptive appendix.
- If geography and timing are strong, estimate mechanisms.

Primary economic model:

- Event-study or CS-DID at area-year level.
- Treatment: first year of militia or drug-faction control in area.
- Compare militia and drug factions separately.

Triple-difference model:

`outcome_area_sector_year = beta * militia_area_post x exposed_sector + area_sector FE + year FE + error`

Interpretation:

- Militia as predatory regulator of local legal and para-legal markets.
- Drug faction as risk/disruption shock with less formal sectoral organization.

Secondary:

- Spatial buffer DiD around boundaries.
- Matched event study using pre-treatment economic trends.
- Placebo sectors less dependent on territorial control.

### Deliverables

- `docs/data_rio_feasibility_report.md`
- `data/economic_area_year_panel.csv`
- `data/economic_area_sector_year_panel.csv`
- `code/96_data_rio_feasibility.R`
- `code/97_economic_mechanism_pilot.R`
- `results/tab96_data_rio_match_quality.csv`
- `results/tab97_economic_mechanism_overall.csv`

## Workstream E: Synthesis and paper integration

Priority: high after A-C are complete.

### Main text placement

Main text:

- candidate profile outcomes.
- campaign finance/vote efficiency outcomes.
- one compact mechanism table.

Appendix:

- full ideology classifications.
- full candidate profile table.
- campaign-finance robustness.
- economic feasibility and exploratory results.

### Suggested main paper mechanism section

Possible structure:

1. "Candidate Entry and Selection"
2. "Campaign Finance and Vote Efficiency"
3. "Local Economic Organization"

Only section 3 should enter the main text if the data quality audit is strong.

## Econometric guardrails

Outcome families:

- competition.
- turnout/mobilization.
- candidate selection.
- ideology/party blocs.
- campaign finance.
- economic mechanisms.

Rules:

- avoid adding many outcomes without family grouping.
- report standardized effects for secondary outcomes.
- use sharpened q-values or at least discuss multiple testing.
- keep preferred estimator fixed before looking at results.
- use not-yet-treated as main control group for comparability.
- put never-treated and municipality clustering in robustness.
- do not overinterpret economic outcomes if geocoding quality is uneven.

## Literature map

Core organized crime and elections:

- Acemoglu, De Feo, and De Luca, "Weak States: Causes and Consequences of the Sicilian Mafia."
- De Feo and De Luca, "Mafia in the Ballot Box."
- Acemoglu, Robinson, and Santos, "The Monopoly of Violence: Evidence from Colombia."
- Alesina, Piccolo, and Pinotti, "Organized Crime, Violence, and Politics."
- Trudeau, "How Criminal Governance Undermines Elections."

Rio and criminal governance:

- Monteiro and coauthors, "Criminal Enterprises: Evidence from Rio de Janeiro."
- Magaloni, Franco-Vivanco, and Melo, "Killing in the Slums."
- Blattman and coauthors, "Gang Rule."
- "Policy enforcement in the presence of organized crime: Evidence from Rio de Janeiro."
- "Regaining the Monopoly of Violence."

Political brokerage and campaign mechanisms:

- Nichter, "Vote Buying or Turnout Buying?"
- Finan and Schechter, "Vote-Buying and Reciprocity."
- Novaes, "Disloyal Brokers and Weak Parties."
- Carey and Shugart, "Incentives to Cultivate a Personal Vote."

Candidate ideology and law-and-order politics:

- Novaes and coauthors, "The Violence of Law-and-Order Politics."
- Power and Zucco ideology measures for Brazilian parties, if used.
- Brazilian party ideology/classification literature for party blocs.

Economic mechanisms:

- De Feo and De Luca on mafia and construction.
- Acemoglu, De Feo, and De Luca on weak states and public goods.
- Blattman et al. on gangs, firms, extortion, and criminal governance.
- Monteiro and coauthors on criminal-enterprise diversification in Rio.
- Urban economics/crime papers on firms, extortion, and local market structure, to be added after the Data.Rio feasibility audit.

## Execution order

1. Candidate profile module.
2. Ideology/party bloc module.
3. Campaign finance module.
4. Data.Rio feasibility audit.
5. Economic mechanism pilot, only if feasibility is adequate.
6. Paper integration and appendix cleanup.

## Decision points

After Workstream A:

- If candidate profile effects are informative, add to main mechanism section.
- If not, keep in appendix and emphasize turnout/vote concentration mechanisms.

After Workstream C:

- If spending per vote falls under militia control, interpret as evidence of coercive/electoral brokerage efficiency.
- If spending rises, interpret as protected candidates investing more or rivals needing more to compete.
- If no effect, avoid campaign-finance mechanism claims.

After Workstream D:

- If CNPJ/licensing data geocode well and show sectoral militia effects, add economic mechanism table.
- If not, keep economic results as exploratory and do not expand the main paper around them.
