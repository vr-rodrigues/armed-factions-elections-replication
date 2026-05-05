# Data.Rio georeferencing audit

Date: 2026-05-03

## Purpose

This audit checks whether candidate Data.Rio / Rio municipal datasets are spatially usable with the armed-faction areas already in the project. It does not evaluate economic outcomes or estimate effects. The only question is:

> Can records from each dataset be classified inside the armed-group polygons or project territories?

## Scope and sources

Sources inspected:

- Data.Rio portal: https://www.data.rio/
- Rio Datalake page: https://www.dados.rio/datalake
- Data.Rio catalog root: https://data-catalog.iplan.dados.rio/
- BCadastro CNPJ catalog: https://data-catalog.iplan.dados.rio/api_bcadastro/
- Brutos BCadastro catalog: https://data-catalog.iplan.dados.rio/brutos_bcadastro/
- SICOP catalog: https://data-catalog.iplan.dados.rio/brutos_sicop/
- Divida Ativa catalog: https://data-catalog.iplan.dados.rio/divida_ativa/
- Mais-Valia catalog: https://data-catalog.iplan.dados.rio/brutos_mais_valia/
- Plus Codes catalog: https://data-catalog.iplan.dados.rio/plus_codes/

Access note:

- The catalog pages are public and expose metadata/schema.
- Direct BigQuery access was attempted with `bq show`, but returned access denied for `rj-iplanrio:api_bcadastro.cnpj` and `rj-iplanrio:plus_codes.equipamentos`.
- Therefore this is a schema-level/geography-feasibility audit, not a record-level match-rate audit.

## Existing project geography

The project already has the spatial target needed for point-in-polygon classification.

Main area files:

- `data/annual/YYYY_controle.geojson`: annual control polygons, one file per year.
- `data/annual/YYYY_influencia.geojson`: annual influence polygons.
- `data/master_territories.geojson`: master territory polygons with stable `territory_id`.
- `data/territory_treatment.csv`: year-specific treatment panel by `territory_id`.
- `data/loc_to_territory.csv`: existing voting-location-to-territory crosswalk.
- `data/locais_votacao_treatment_annual.csv`: voting-location panel with `lat`, `lon`, treatment status, annual distance, and master territory distance.

Local inspection:

- `master_territories.geojson`: 3,746 MultiPolygon features, CRS84/WGS84.
- `data/annual/2007_controle.geojson`: 1,567 MultiPolygon features.
- `data/annual/2008_controle.geojson`: 1,877 MultiPolygon features.
- annual control files carry group labels such as `Grupo_Armado_soControle` and `year`.
- `locais_votacao_treatment_annual.csv`: 41,800 rows and has voting-location coordinates.

Implication:

- Any external record with reliable latitude/longitude or geometry can be classified directly into annual faction polygons and master territories.
- Any external record with only address fields must first be geocoded.
- Any external record with only bairro/RA/AP should not be treated as point-level classified inside armed areas.

## Classification standard

Use four geographic quality classes.

Class A: direct point/geometry

- Has `geometry`, `latitude`, `longitude`, or equivalent.
- Can be spatially joined directly to `data/annual/YYYY_controle.geojson` and `data/master_territories.geojson`.
- Suitable for main classification after validating CRS and coordinate range.

Class B: full address geocodable

- Has CEP plus logradouro plus numero, or coded street plus number.
- Can be geocoded to a point.
- Suitable for classification if record-level geocoding quality is high.

Class C: partial address / street or CEP centroid

- Has street without number, CEP only, or bairro plus street.
- Can often be approximated, but may be too imprecise near faction boundaries.
- Suitable for sensitivity or aggregated area analysis, not preferred for point-in-polygon treatment assignment.

Class D: bairro/RA/AP/municipality only

- Does not locate the record precisely enough for armed-territory classification.
- Can only support coarse descriptive aggregation unless a separate high-quality spatial crosswalk exists.

## Dataset findings

### 1. BCadastro / CNPJ

Datasets:

- `api_bcadastro.cnpj`
- `brutos_bcadastro.cnpj`

Relevant geography fields:

- `endereco.cep`
- `endereco.uf`
- `endereco.id_municipio`
- `endereco.municipio_nome` or `endereco.municipio`
- `endereco.bairro`
- `endereco.tipo_logradouro`
- `endereco.logradouro`
- `endereco.numero`
- `endereco.complemento`

Relevant time fields:

- `inicio_atividade_data`
- `situacao_cadastral.data`
- extraction/update timestamps.

Observed direct coordinate fields:

- None in the catalog schema.

Geographic verdict:

- Class B: full-address geocodable, not directly georeferenced.
- It can be classified inside the project polygons after geocoding.
- It should not be classified by bairro alone.

Risks:

- Need record-level audit of missing `numero`, malformed addresses, non-RJ addresses, and post-office/office addresses.
- CNPJ current-status snapshots may not provide full historical firm presence unless raw historical/status fields are usable.

Best next step:

- Extract only Rio de Janeiro municipality records with non-missing CEP/logradouro/numero.
- Geocode a sample.
- Report geocode match rate by year and address-quality class.

### 2. SICOP / municipal administrative processes

Dataset:

- `brutos_sicop`

Relevant tables:

- `processo`
- `parte_envolvida`
- `documento`
- `tramitacao_processo`

Relevant geography fields:

- `processo.logradouro`
- `processo.numero_porta`
- `processo.complemento`
- `processo.cep`
- `processo.bairro`
- `parte_envolvida.endereco_parte_envolvida`
- `parte_envolvida.numero_porta_parte_envolvida`
- `parte_envolvida.complemento_parte_envolvida`
- `parte_envolvida.bairro_parte_envolvida`
- `parte_envolvida.cep_parte_envolvida`

Relevant time fields:

- `processo.data_processo`
- `processo.data_alteracao`
- `documento.data_documento`
- `tramitacao_processo.data_despacho`
- `tramitacao_processo.data_saida`

Observed direct coordinate fields:

- None in the catalog schema.

Geographic verdict:

- Class B/C depending on address completeness.
- Potentially classifiable after geocoding, but noisier than CNPJ/BCadastro because the address may refer to the requerente/parte rather than the object/location of the process.

Risks:

- Need to distinguish process-object address from applicant address.
- Need filters by `codigo_assunto` or `descricao_assunto`; otherwise the dataset mixes many administrative process types.
- Street/party addresses may misclassify if they are correspondence addresses.

Best next step:

- Pull a small schema/sample extract with `id_processo`, dates, assunto, logradouro, numero, cep, bairro.
- Check whether addresses refer to the property/object for the process.
- Only use process types where the address clearly corresponds to the physical object.

### 3. Divida Ativa

Dataset:

- `divida_ativa`

Relevant table:

- `certidao_divida_ativa`

Relevant geography fields:

- `possui_imovel_associado`
- `imovel_associado.endereco.codigo_logradouro`
- `imovel_associado.endereco.nome_logradouro`
- `imovel_associado.endereco.numero_porta`
- `imovel_associado.endereco.complemento_endereco`
- `imovel_associado.endereco.bairro`
- `imovel_associado.endereco.cep`

Relevant time fields:

- `ano_de_inscricao_na_divida`
- `data_geracao_cda`
- `data_ultima_alteracao_situacao`
- payment-guide dates in nested `guias_pagamento_associadas`.

Observed direct coordinate fields:

- None in the catalog schema.

Geographic verdict:

- Class B for IPTU CDAs with `imovel_associado`.
- Class D or unusable for CDAs without property-associated address.
- Can be classified inside armed areas only for records with a property address that geocodes well.

Risks:

- Non-IPTU debt may not have a physical property location.
- Devedor address is not necessarily the affected property.
- Need to filter to `possui_imovel_associado == TRUE` before geocoding.

Best next step:

- Restrict to property-associated CDAs.
- Audit completeness of `codigo_logradouro`, `numero_porta`, `bairro`, and `cep`.
- Geocode only property addresses, not debtor identity records.

### 4. Mais-Valia / contrapartida

Dataset:

- `brutos_mais_valia`

Relevant table:

- `contrapartida_consolidado`
- `parcelas_contrapartida` only after joining to the consolidated table.

Relevant geography fields:

- `inscricao_iptu`
- `codigo_logradouro`
- `codigo_logradouro_smf`
- `tipo_logradouro`
- `nome_logradouro`
- `numero_porta`
- `complemento_porta`
- `unidade`
- `numero_pal`
- `lote`
- `quadra`
- `codigo_bairro`
- `bairro`
- `area_planejamento`
- `regiao_administrativa`

Relevant time fields:

- `ano`
- `ano_requerimento`
- `parcelas_contrapartida.data_emissao`
- `parcelas_contrapartida.data_vencimento`
- `parcelas_contrapartida.data_pagamento`

Observed direct coordinate fields:

- None in the catalog schema.

Geographic verdict:

- Class B if logradouro/numero or IPTU can be resolved to point coordinates.
- Class C/D if only bairro/AP/RA are used.
- This is likely one of the better municipal tables for address-based geocoding because it has property-oriented identifiers, street codes, and IPTU fields.

Risks:

- `inscricao_iptu` is entered as filled by the applicant, so it needs validation.
- `codigo_bairro` and `bairro` are not enough for armed-area classification.
- Need an IPTU/logradouro reference table if possible.

Best next step:

- Prioritize rows with `inscricao_iptu` or `codigo_logradouro` plus `numero_porta`.
- Test whether `codigo_logradouro_smf` can join to an official street/property reference.

### 5. Plus Codes / municipal equipment tables

Dataset:

- `plus_codes`

Relevant tables:

- `codes`
- `equipamentos`
- equipment-specific subtables.

Relevant geography fields:

- `geometry` as `GEOGRAPHY`
- `latitude`
- `longitude`
- `plus11`, `plus10`, `plus8`, `plus6`
- `endereco.logradouro`
- `endereco.numero`
- `endereco.bairro`
- `endereco.cep`
- `bairro.id_bairro`

Relevant time fields:

- `vigencia_inicio`
- `vigencia_fim`
- `updated_at`
- `ingestion_timestamp`

Observed direct coordinate fields:

- Yes.

Geographic verdict:

- Class A: directly georeferenced.
- Can be classified inside armed areas immediately if records are accessible.
- This is not necessarily an economic dataset, but it is useful as proof that some Data.Rio tables are natively spatial.

Risks:

- Mostly public equipment/service locations, not business or economic outcomes.
- It may be useful for controls, service-access checks, or geocoding reference, but not for the coauthor's economic mechanism unless a relevant equipment subset is theoretically justified.

Best next step:

- If access is granted, run direct point-in-polygon classification as a pipeline test.

## Overall verdict

No inspected economic candidate table appears to be natively georeferenced with latitude/longitude or geometry, except `plus_codes`, which is not mainly an economic-business table.

However, the main economic candidate tables are geocodable:

- BCadastro/CNPJ: strong candidate for address geocoding.
- Mais-Valia: strong candidate because it is property-oriented and has street/IPTU identifiers.
- Divida Ativa: usable only for property-associated/IPTU records.
- SICOP: usable only after filtering to process types where the address is the object location, not merely the applicant address.

The project has the spatial infrastructure to classify points once coordinates exist.

## Can these data be classified into our areas?

Yes, conditionally.

Direct classification is possible if a dataset has point coordinates:

1. Normalize CRS to WGS84.
2. Spatial-join each point to `data/annual/YYYY_controle.geojson` by year.
3. Spatial-join each point to `data/master_territories.geojson`.
4. Join `territory_id` to `data/territory_treatment.csv`.
5. Export fields:
   - `inside_controle`
   - `faction_type`
   - `faction_group`
   - `territory_id`
   - `distance_to_boundary_m`
   - `geocode_quality`
   - `source_dataset`
   - `source_record_id`

Address-based classification is possible only after geocoding:

1. Standardize address fields.
2. Keep original address strings.
3. Geocode to WGS84 points.
4. Assign quality classes A/B/C/D.
5. Use A/B geocodes for main polygon classification.
6. Use C only for sensitivity or coarse aggregation.
7. Drop D from polygon-level analysis.

## Required record-level audit before any analysis

For each dataset extract, produce:

- number of records.
- number of records with usable date.
- number with CEP.
- number with logradouro.
- number with numero.
- number with bairro.
- number with latitude/longitude or geometry.
- geocoding match rate.
- match rate by year.
- match rate by municipality/bairro.
- share assigned to an annual faction polygon.
- share assigned to a master territory.
- share within 50m / 100m / 250m of faction boundaries.
- share classified only from low-precision bairro/centroid.

Boundary-distance diagnostics are important because imprecise geocoding is most dangerous near the borders of faction polygons.

## Recommended next implementation

Do not estimate outcomes yet. The next implementation should be a pure geography audit pipeline:

1. Obtain/export small samples from:
   - `api_bcadastro.cnpj`
   - `brutos_mais_valia.contrapartida_consolidado`
   - `divida_ativa.certidao_divida_ativa`
   - optionally `brutos_sicop.processo`
2. Build address completeness tables.
3. Geocode a sample from each dataset.
4. Spatial-join geocoded points to annual control polygons.
5. Report match quality before any substantive interpretation.

Minimum output files:

- `results/tab96_data_rio_georef_schema_audit.csv`
- `results/tab96_data_rio_geocode_quality.csv`
- `results/tab96_data_rio_polygon_assignment.csv`
- `docs/data_rio_georef_record_audit.md`

## Bottom line

The Data.Rio economic data are probably usable for classification into armed-group areas, but not directly. The safe statement is:

> The economic candidate datasets are mostly address-geocodable rather than already georeferenced. Once geocoded, they can be classified inside our annual armed-faction polygons and master territories. The feasibility depends on record-level address completeness and geocoding accuracy, especially near polygon boundaries.

