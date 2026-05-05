# Party ideology classification

Date: 2026-05-03

Source:

- Colonnelli, Emanuele, Valdemar Pinho Neto, and Edoardo Teso. 2025. "Politics at Work." American Economic Review 115(10): 3367-3414.
- Classification uses Table A1, "Distribution of Party Members, and Left/Center/Right Party Categorization."

Implementation:

- Script: `code/93_political_profile_outcomes.R`
- Output: `data/party_bloc_by_location.csv`
- Coverage audit: `results/tab93_party_classification_coverage.csv`

The script classifies candidate votes by normalized TSE party acronym, not by party number. This avoids misclassifying votes when numbers are reused, renamed, or attached to post-2019 party changes.

Base blocs from Table A1:

- Left: PT, PDT, PSB, PCdoB, PV, PMN, PSOL, SD, PROS, PSTU, PCB, REDE, PCO, UP, PPL.
- Center: PMDB/MDB, PSDB, PTB, AVANTE, PSD.
- Right: PP, DEM, PL, PPS, PSC, PODE, PRB, PATRI, PSL, DC, PTC, PRTB, NOVO, PMB, PRP, PHS.

TSE aliases and successor labels used in the script:

- PMDB -> MDB: Center.
- PR -> PL: Right.
- PSDC -> DC: Right.
- PT do B -> AVANTE: Center.
- PTN -> PODE: Right.
- PRB -> Republicanos: Right.
- PPS -> Cidadania: Right.
- PTC -> AGIR: Right.
- PMN -> MOBILIZA: Left.
- DEM/PSL -> UNIAO: Right.

PRD is left unclassified in 2024 because it combines PTB and Patriota lineages, which are Center and Right respectively in Table A1. The resulting coverage is complete for 2008-2020 and remains high in 2024: 99.7% of prefeito candidate votes and 95.9% of vereador candidate votes.

Substantive implication after rerunning the political-profile results:

- In the preferred NYT estimator, militia control in mayoral races does not produce a statistically meaningful shift in ideology-weighted vote composition.
- `Militia x Prefeito`: `ideology_score_vote_weighted` ATT = -0.0112, p = 0.565.
- The robust mechanism remains vote concentration and candidate viability, not ideology.
