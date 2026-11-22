# Data

The repository tracks no data. The code reads every input from one folder, set by the environment variable
`AFE_DADOS` (default: this `data/` folder), and writes intermediate files to the same folder:

```text
$AFE_DADOS/
  basedosdados_tse/   inputs, written by base_dados_bd/extrair_bd.py
  basedosdados_v2/    inputs, written by base_dados_bd/extrair_bd_v2.py
  basedosdados_v3/    inputs, written by base_dados_bd/extrair_bd_v3.py
  basedosdados_v4/    inputs, written by base_dados_bd/extrair_bd_v4.py
  mapas_anuais/       inputs, armed-group maps (Section 2 below)
  pipeline_v2/        written by pipeline_v2/run_all.R
  pipeline_v2_ext/    written by pipeline_v2/run_ext.R and fase3/W00, W17
```

`input_files.csv` lists every input file with the number of rows (parquet) or polygons (maps) in the files used for
the paper, so that a new extraction can be checked against ours.

## 1. Electoral and census data: Base dos Dados

[Base dos Dados](https://basedosdados.org) publishes the official files of the Superior Electoral Court (TSE) and of
the Brazilian Institute of Geography and Statistics (IBGE) as public BigQuery tables. The four scripts in
`base_dados_bd/` query them for the 20 municipalities of metropolitan Rio de Janeiro used in the paper and save parquet
files. No personal data are selected (candidate tax IDs, e-mail addresses and voter registration numbers are left out).

| Script | Base dos Dados tables | Years |
|---|---|---|
| `extrair_bd.py` | `br_tse_eleicoes`: `resultados_candidato_secao`, `resultados_partido_secao`, `detalhes_votacao_secao`, `perfil_eleitorado_local_votacao`, `local_secao`, `candidatos` | elections 2006-2024 |
| `extrair_bd_v2.py` | `br_tse_eleicoes.partidos`, `br_tse_eleicoes.resultados_candidato_municipio`, `br_geobr_mapas.setor_censitario_2010`, `br_ibge_censo_2022.setor_censitario`, `br_geobr_mapas.municipio` | 2004-2024; census 2010 and 2022 |
| `extrair_bd_v3.py` | `br_tse_eleicoes.perfil_eleitorado_secao` (aggregated by section), `br_tse_eleicoes.receitas_candidato` (aggregated by candidate), and the 2004 election by section | 2004-2024 |
| `extrair_bd_v4.py` | `br_ibge_censo_demografico.setor_censitario_basico_2010` | census 2010 |

To run them you need a Google Cloud project with the BigQuery API enabled, which is billed for the queries, and
Application Default Credentials:

```bash
pip install -r requirements.txt
gcloud auth application-default login
python base_dados_bd/extrair_bd.py --project <your-project> --dry-run   # bytes to be processed, no cost
GCP_PROJECT=<your-project> bash run_replication.sh extract              # all four scripts
```

The full extraction processes about 10 GB, within BigQuery's monthly free tier at the time of writing. The paper
uses extractions made in October and November 2026. Base dos Dados updates its tables, so a later extraction can
differ slightly from ours; compare it with `input_files.csv`.

## 2. Armed-group maps: Fogo Cruzado and GENI/UFF

Treatment comes from the *Mapa Histórico dos Grupos Armados do Rio de Janeiro*, produced by the Grupo de Estudos dos
Novos Ilegalismos (GENI/UFF) and the Instituto Fogo Cruzado from reports to the Disque-Denúncia hotline. It has two
annual layers for 2007-2024: areas under armed territorial control and areas under armed territorial influence. The
paper uses the vector polygons collected on 10 March 2026 from <https://fogocruzado.org.br/mapadosgruposarmados/>.
The site has since moved to displaying the maps as images. The polygons are subject to Fogo Cruzado's data-use terms
and are not redistributed here; requests for the vector files should be addressed to Fogo Cruzado.

Place them in `$AFE_DADOS/mapas_anuais/`, one GeoJSON file per year and layer (WGS 84):

| File | Attribute naming the armed group |
|---|---|
| `<year>_controle.geojson`, 2007-2024 | `Grupo_Armado_soControle` |
| `<year>_influencia.geojson`, 2007-2024 | `Grupo_Armado_soFlexivel` |

Group values are `Milícia` (militias) and `CV`, `TCP` and `ADA` (drug-trafficking factions). Each polygon also carries
`mvFeatureId`. The number of polygons per file is in `input_files.csv`.

## 3. Files included in the repository

- `pipeline_v2/R_ext/ideologia_partidos.csv`: left, center or right classification of parties by party number and
  period, following Table A1 of Colonnelli, Pinho Neto and Teso (2025), "Politics at Work", *American Economic Review*
  115(10): 3367-3414.
- `pipeline_v2/R_ext/00_config_ext.R`: party of the state governor at each municipal election.
