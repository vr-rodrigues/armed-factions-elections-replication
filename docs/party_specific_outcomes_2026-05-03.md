# Party-specific outcomes: PT versus PL/PR

Date: 2026-05-03

Script:

- `code/93_political_profile_outcomes.R`

Derived data:

- `data/party_specific_by_location.csv`

Outcomes:

- `pt_share`: share of candidate votes going to candidates from PT.
- `pl_pr_share`: share of candidate votes going to candidates from the PL/PR lineage. PR is included because the party used the PR label before returning to PL.
- `pl_pr_minus_pt_share`: `pl_pr_share - pt_share`.

Important interpretation note:

- These are candidate-party vote shares, not coalition shares and not direct measures of militia alignment.
- For mayoral races, they capture the party of the mayoral candidate receiving votes at the polling station.
- For city-council races, they aggregate all candidates from the target party at the polling station.

Preferred NYT CS-DID results:

| Spec | Office | Outcome | ATT | p-value |
| --- | --- | --- | ---: | ---: |
| Militia | Prefeito | `pt_share` | +0.0310 | 0.001 |
| Militia | Prefeito | `pl_pr_share` | -0.0049 | 0.455 |
| Militia | Prefeito | `pl_pr_minus_pt_share` | -0.0359 | 0.017 |
| Militia | Vereador | `pt_share` | +0.0071 | 0.035 |
| Militia | Vereador | `pl_pr_share` | +0.0028 | 0.392 |
| Militia | Vereador | `pl_pr_minus_pt_share` | -0.0044 | 0.373 |
| Drug | Prefeito | `pt_share` | +0.0185 | 0.150 |
| Drug | Prefeito | `pl_pr_share` | +0.0244 | 0.087 |
| Drug | Prefeito | `pl_pr_minus_pt_share` | +0.0059 | 0.792 |
| Drug | Vereador | `pt_share` | -0.0037 | 0.466 |
| Drug | Vereador | `pl_pr_share` | +0.0058 | 0.495 |
| Drug | Vereador | `pl_pr_minus_pt_share` | +0.0095 | 0.376 |

Main read:

- In militia-controlled mayoral races, there is a statistically detectable increase in PT candidate vote share, not a detectable increase in PL/PR vote share.
- The `PL/PR - PT` contrast falls by about 3.6 percentage points under the preferred NYT estimator.
- This is more specific than the broad left/right classification, where the ideology-weighted estimate remains null. It suggests a party-specific PT pattern rather than a general ideological shift.
- After review, this check is parked and should not enter the paper. The paper should use the aggregate Colonnelli et al. ideology classification and report no aggregate ideology effect.
