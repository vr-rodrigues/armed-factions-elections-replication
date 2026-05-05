# Data Collection Notes

This folder is intentionally not populated in the public GitHub repository. The replication scripts expect the files listed below after the user has collected or been authorized to use the data.

## 1. Public electoral data from TSE

Source: Tribunal Superior Eleitoral, Repositorio de Dados Eleitorais  
URL: <https://dadosabertos.tse.jus.br/>

Download:

- `votacao_secao_RJ_2008.csv`
- `votacao_secao_RJ_2012.csv`
- `votacao_secao_RJ_2016.csv`
- `votacao_secao_RJ_2020.csv`
- `votacao_secao_RJ_2024.csv`
- `consulta_cand_2008_RJ.csv`
- `consulta_cand_2012_RJ.csv`
- `consulta_cand_2016_RJ.csv`
- `consulta_cand_2020_RJ.csv`
- `consulta_cand_2024_RJ.csv`
- `locais_votacao_RJ_2010.csv`
- `locais_votacao_RJ_2012.csv`
- `locais_votacao_RJ_2014.csv`
- `locais_votacao_RJ_2016.csv`
- `locais_votacao_RJ_2018.csv`
- `locais_votacao_RJ_2020.csv`
- `locais_votacao_RJ_2022.csv`
- `locais_votacao_RJ_2024.csv`

The paper uses five municipal elections, 2008-2024. Voting-location files from national-election years are used to recover geocoding continuity for locations not observed in a municipal-year file.

Recommended local raw-data layout:

```text
data/raw/tse/votacao_secao/
data/raw/tse/candidatos/
data/raw/tse/locais_votacao/
data/raw/tse/prestacao_contas/
```

Campaign-finance archives are used only by optional mechanism scripts. The
expected official TSE resources are:

- `prestacao_contas_2008.zip`
- `prestacao_final_2012.zip`
- `prestacao_contas_final_2016.zip`
- `prestacao_de_contas_eleitorais_candidatos_2020.zip`
- `prestacao_de_contas_eleitorais_candidatos_2024.zip`

Use `code/94_campaign_finance_outcomes.R --download` to fetch these archives
into `data/raw/tse/prestacao_contas/` before processing campaign spending.
The processing script deflates monetary values to 2024 reais using IPCA from
Banco Central do Brasil SGS series 433 and writes `data/ipca_deflator_2024.csv`.

## 2. Fogo Cruzado territory maps

Source: Fogo Cruzado Institute  
Official repository: <https://github.com/fogocruzadoapp/mapafc>

Requested data:

- annual armed-faction territory polygons for metropolitan Rio de Janeiro;
- annual coverage from 2007 through 2024;
- faction-type labels distinguishing militia and drug-faction control where available;
- metadata sufficient to identify polygon vintage and source year.

Redistribution note: original polygons are subject to the provider's data-use terms. If redistribution is not permitted, obtain the data directly from Fogo Cruzado and place authorized copies in the local raw-data directory before running the scripts.

Recommended local raw-data layout:

```text
data/raw/fogo_cruzado/
```

## 3. Derived analysis files expected by the scripts

The current analysis scripts expect the following processed files in `data/`:

- `electoral_competition_measures.csv`
- `qt_aptos_by_location.csv`
- `locais_votacao_treatment_annual.csv`
- `loc_faction_changes.csv`
- `loc_to_territory.csv`
- `candidate_profile_by_location.csv`
- `party_bloc_by_location.csv`
- `party_specific_by_location.csv`
- `campaign_finance_by_candidate.csv`
- `campaign_finance_by_location.csv`
- `ipca_deflator_2024.csv`
- `territory_to_cluster.csv`
- `territory_treatment.csv`
- `territory_panel_final.csv`
- `municipios_crosswalk.csv`
- `municipios_rj.geojson`
- `annual/*.geojson`
- `mgarj_*_polygons.geojson`
- `mgarj_*_poligonos_table.csv`

The scripts in `code/01_*` through `code/47_*` construct these files from the raw data. The scripts in `code/70_*` onward reproduce the paper tables and figures from the processed analysis files.

## 4. Files excluded from git

The public repository does not track:

- raw TSE vote-section CSVs;
- Fogo Cruzado original polygons unless redistribution is authorized;
- processed analysis CSV/GeoJSON files;
- generated figures and tables;
- local logs and temporary files.

This keeps the GitHub repository focused on code and documentation while preserving a clear path for researchers to collect the data.
