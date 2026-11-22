# Armed Groups and the Local Vote: Evidence from Rio de Janeiro

Replication code for the paper. The code builds the polling-station panel of metropolitan Rio de Janeiro from public
electoral and census data and annual maps of armed-group territory, estimates every result reported in the paper, and
writes all tables, figures and in-text numbers. No number in the paper is typed by hand: `paper_v2/tables/numbers.tex`
defines a LaTeX macro for each number cited in the text.

Data are not tracked in this repository. See [`data/README.md`](data/README.md) for how to obtain them.

## Pipeline

| Stage | Code | What it does |
|---|---|---|
| `extract` | `base_dados_bd/` (Python) | Queries Base dos Dados (BigQuery): TSE electoral returns, candidates, polling places and section geocodes, campaign revenue, voter profiles, 2010 and 2022 census tracts, municipal boundaries |
| `base` | `pipeline_v2/run_all.R` | Polling places by year, crosswalk of physical polling places across elections, section-to-place links, votes and outcomes by place, treatment from the annual maps, analysis panels; tests of the CS-DID engine on simulated data |
| `ext` | `pipeline_v2/run_ext.R` | Open-list concentration (party and within-party), candidate-type outcomes, catchment-area exposure (Voronoi cells and census-tract population), party ideology and party blocs |
| `inputs` | `fase3/W00`, `fase3/W17` | Outcomes used in the paper; log income of household heads within 500 m of each polling place (2010 census), the covariate of the main specification |
| `estimates` | `fase1/`, `fase2/`, `fase3/` | All estimates (below) |
| `tables` | `paper_v2/R/tabelas_figuras.R` | `paper_v2/tables/*.tex`, `paper_v2/figures/*.pdf` |

All difference-in-differences estimates use the Callaway and Sant'Anna (2021) estimator from the R package `did`,
called through `pipeline_v2/R/cs_engine.R`: outcome regression conditioning on municipality and log neighborhood
income, not-yet-treated and never-treated stations as controls, a universal base period, and standard errors
clustered by 2-km grid cell (cluster-robust variance computed from the influence functions).

| Script | Results |
|---|---|
| `fase3/W01_estimativas_paper.R` | Main estimates and event studies by armed group, office and outcome |
| `fase3/W03_placebo_paper.R`, `fase3/W15_inferencia_conjunta.R` | Uncontrolled-neighbor placebo; entry minus placebo with joint variance; Holm, Benjamini-Hochberg and max-t adjustments |
| `fase3/W02_honestdid_curvas.R`, `fase3/W08_antecipacao.R` | HonestDiD sensitivity (Rambachan and Roth 2023); pre-entry dip and anticipation |
| `fase2/V02_curva.R` | Specification curves |
| `fase2/V03_f6.R`, `fase2/V04_f6_testes.R` | Right-minus-left balance by point and catchment exposure; randomization inference and placebo tests |
| `fase1/F01_principal.R`, `fase1/F02_robustez.R` | Concentration outcomes in the municipal and general-election panels; robustness to sample and control choices |
| `fase3/W04` to `W14`, `W16` | Municipal aggregation, electorate composition, spatial inference, balance, buffer exposure, beneficiaries, local candidates, campaign revenue, the 2004 election, the influence layer, state and federal legislative races |
| `fase3/W17` to `W22` | Census-income covariate and balance; revenue percentile; who gains under the drug-faction hypothesis and its checks |

## Requirements

- R 4.5 with the packages in `r-packages.txt` (versions used for the paper). Spatial results depend on GEOS through
  `sf`; the paper used GEOS 3.13.1.
- Bash (Git Bash on Windows) to run `run_replication.sh`.
- For the extraction only: Python 3.10 or later with `requirements.txt`, and a Google Cloud project with BigQuery
  (see `data/README.md`).
- About 500 MB of disk for data, intermediate files and results.

## Running

From the repository root:

```bash
export AFE_DADOS=/path/to/data                              # default: ./data
GCP_PROJECT=<your-project> bash run_replication.sh extract  # once; or place the extracted files yourself
# copy the armed-group maps to $AFE_DADOS/mapas_anuais (data/README.md, Section 2)
MAX_JOBS=8 bash run_replication.sh                          # base, ext, inputs, estimates, tables
```

Stages can also be run one at a time, in order (`bash run_replication.sh estimates tables`). Each job writes
`logs/<job>.log`, and `logs/progress.txt` records the exit code of every job. On a 16-core Windows machine with
`MAX_JOBS=12`, the whole pipeline after the extraction took 3 hours and 45 minutes: 3 minutes for `base`, 2 hours and
55 minutes for `ext` (almost all of it the catchment-area exposure, which runs on one core), and 46 minutes for the
inputs, estimates and tables.

Results go to `fase1/resultados`, `fase2/resultados` and `fase3/resultados` (CSV), tables and the number macros to
`paper_v2/tables`, and figures to `paper_v2/figures`. All random draws use fixed seeds. Run from scratch on the input
files listed in `data/input_files.csv`, the code reproduces byte for byte every intermediate data file, every result
file, every table and every number macro of the paper.

## Notes on the code

Comments and variable names are in Portuguese. A short glossary: *local* (polling place), *seção* (polling section),
*prefeito* (mayor), *vereador* (city council member), *milícia* (militia), *tráfico* (drug-trafficking faction),
*tratamento* (treatment), *captação* (catchment area), *renda* (income), *placebo de vizinhos* (uncontrolled-neighbor
placebo), *saldo direita - esquerda* (right-minus-left balance), *receita* (campaign revenue), *eleito* (winner).

The folder names `fase1`, `fase2` and `fase3` group the estimation scripts and do not correspond to sections of the
paper.
