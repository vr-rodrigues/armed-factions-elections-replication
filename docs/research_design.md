# Facções e Concorrência Eleitoral no Rio de Janeiro
## Research Design Document

---

## 1. Research Question

**Do voting locations within armed-faction territories experience reduced electoral competition compared to those outside faction control?**

Sub-questions:
- Does faction presence reduce the number of effective candidates at a polling station?
- Does it increase vote concentration (HHI)?
- Does it reduce voter turnout or increase null/blank votes?
- Do different faction types (CV, Milícia, TCP, ADA) have heterogeneous effects?
- Are effects stronger for local (vereador/prefeito) vs. state/federal elections?

---

## 2. Theoretical Framework (adapted from Acemoglu et al. 2019)

Acemoglu et al. (2019) document that the Sicilian Mafia reduced political competition through:
1. **Voter intimidation** at polling stations ("uomini di rispetto" loitering near ballot boxes)
2. **Electoral list manipulation** (preventing opposition candidates from registering)
3. **Campaign suppression** (preventing candidates from campaigning in controlled areas)
4. **Vote buying/coercion** (controlling "packages of votes")

The Rio de Janeiro faction context shares key parallels:
- **Weak state presence** in favelas and periphery (parallel to weak Italian state in Sicily)
- **Territorial control** by armed groups (CV, Milícia, TCP, ADA) over neighborhoods
- **Documented interference** in elections: factions have been reported to control which candidates can campaign, enforce votes for allied politicians, and prevent opposition access
- **Polling stations inside territories**: schools and community centers used as polling stations are physically located within faction-controlled areas

**Key difference from Acemoglu**: We observe the treatment (territorial control) directly via GENI maps, whereas Acemoglu had to instrument Mafia presence with rainfall. This is both an advantage (direct measurement) and a challenge (endogeneity of faction location).

---

## 3. Available Data

### 3.1 Faction Territorial Control (GENI/UFF Maps)
- **Source**: Mapa de Grupos Armados do Rio de Janeiro (GENI/UFF)
- **Coverage**: 16 rolling triennia from 2006-2008 to 2021-2023
- **Geography**: ~2,100-3,800 polygons per triennium covering 20 municipalities in metro RJ
- **Variables per polygon**:
  - `Grupo_Armado_Dominante`: CV, Milícia, TCP, ADA, Domínio Indefinido
  - `n_denucias`, `n_controle`, `n_emp_violento`, `n_uso_forca` (violence intensity)
  - `NM_BAIRRO`, `NM_MUNICIP`, `CD_GEOCMU` (geographic identifiers)
  - Full polygon geometries (GeoJSON)
- **Panel**: `mgarj_panel_all_trienios.csv` (53,691 obs)
- **Extraction**: Script `scripts/01_extract_maps.py` extracts all 16 maps

**Summary statistics (all periods)**:
| Faction | Total polygons | Share |
|---------|---------------|-------|
| CV | 28,735 | 53.5% |
| Milícia | 14,842 | 27.6% |
| TCP | 4,373 | 8.1% |
| ADA | 3,293 | 6.1% |
| Domínio Indefinido | 2,361 | 4.4% |

### 3.2 TSE Electoral Data (to be collected)
- **Voting location addresses**: TSE provides the address of every `local de votação` (school, etc.)
- **Electoral results by seção**: votes per candidate per `seção eleitoral` within each `local de votação`
- **Elections to cover**:
  - Municipal: 2008, 2012, 2016, 2020, 2024 (vereador + prefeito)
  - Federal/State: 2006, 2010, 2014, 2018, 2022 (deputado estadual, federal, senador, governador, presidente)
- **Key variables**: votes per candidate, turnout, null votes, blank votes, registered voters, candidate characteristics

### 3.3 Data to Construct
- **Geocoded voting locations**: Match TSE addresses → lat/lon coordinates
- **Spatial join**: voting location points ∩ faction polygon → treatment assignment
- **Electoral competition measures**:
  - HHI of candidate vote shares (per seção or local)
  - Effective number of candidates (1/HHI)
  - Turnout rate
  - Null + blank vote share
  - Margin of victory (top 2 candidates)

---

## 4. Empirical Strategy — Model Comparison

### 4.1 Option A: Spatial Regression Discontinuity (RDD) ★ RECOMMENDED

**Idea**: Compare voting locations just inside vs. just outside faction territory boundaries.

**Model**:
```
Y_i = α + β · Faction_i + f(distance_i) + X_i'γ + ε_i
```
where `distance_i` is the distance from voting location i to the nearest faction boundary, and `Faction_i = 1` if inside.

**Pros**:
- Clean identification: locations near the boundary are similar in observables
- No need for exogenous instrument
- Directly comparable to Dell (2015) on drug trafficking networks
- Can be done cross-sectionally for each election

**Cons**:
- Boundaries may be endogenous (factions expand into areas with certain characteristics)
- Requires precise geocoding of voting locations
- Boundary manipulation concerns (though GENI boundaries are based on police/community reports, not administrative)
- Need sufficient voting locations near boundaries

**Falsification**: Test for discontinuities in pre-treatment covariates (population density, income, infrastructure) at boundaries.

### 4.2 Option B: Difference-in-Differences (DiD) with Territorial Changes

**Idea**: Exploit changes in faction control over time. When a polygon transitions from "no faction" to "faction-controlled" (or switches factions), how does electoral competition at nearby voting locations change?

**Model**:
```
Y_it = α_i + δ_t + β · FactionControl_it + X_it'γ + ε_it
```

**Pros**:
- Controls for time-invariant unobservables via location FEs
- Exploits variation from faction expansion (2006→2023 shows steady growth from 2,118 to 3,829 polygons)
- Can use modern DiD estimators (Callaway-Sant'Anna, etc.)

**Cons**:
- Parallel trends assumption: locations that become faction-controlled may already be on different trajectories
- Overlapping triennia make treatment timing fuzzy
- Faction expansion may be driven by political/electoral factors (reverse causality)

### 4.3 Option C: Instrumental Variables (Acemoglu-style)

**Idea**: Instrument faction presence with an exogenous shock. Candidates:
- **UPP deployment** (2008-2014): Police pacification units created exogenous displacement of factions
- **Gang leader arrests/deaths**: Sudden leadership changes that redistribute territorial control
- **Geographic instruments**: Terrain slope, distance to major roads (affects ease of territorial control)

**Pros**:
- Most directly comparable to Acemoglu 2019
- Addresses endogeneity of faction location

**Cons**:
- UPPs were NOT randomly assigned — targeted high-visibility areas near tourist zones and sports venues (2014 World Cup, 2016 Olympics)
- Gang leader events may affect outcomes through channels other than territorial control
- Terrain instruments may violate exclusion restriction (hills affect many outcomes)

### 4.4 Recommendation

**Primary strategy: Spatial RDD (Option A)** — cleanest identification, most feasible with available data.

**Secondary/robustness: DiD (Option B)** — exploiting temporal variation in faction boundaries for locations that switch treatment status.

**NOT recommended: IV (Option C)** — the available instruments are too weak or violate exclusion restrictions in this context. Acemoglu had an exceptionally clean natural experiment (1893 drought during a unique critical juncture); we don't have an equivalent here.

---

## 5. Pros and Cons of the Research Design

### Strengths
1. **Direct treatment measurement**: Unlike Acemoglu who proxied Mafia with a 0-3 index from a single police inspector's assessment, we have precise polygon boundaries from systematic mapping over 16 periods
2. **Granular outcome data**: TSE provides vote-level data by seção eleitoral (much finer than Acemoglu's municipality-level HHI)
3. **Panel structure**: 16 triennia × multiple elections allows both cross-sectional and panel analysis
4. **Multiple faction types**: Can test heterogeneous effects (Milícia vs. drug factions) — Milícias have closer ties to local politics and security forces, which may amplify or change the mechanism
5. **Contemporary relevance**: Active policy debate in Brazil about faction influence on elections
6. **Rich comparison literature**: Dell (2015) on Mexico, Alesina et al. (2018) on Italy, Fergusson et al. (2013) on Colombia

### Weaknesses / Threats
1. **Endogeneity of faction boundaries**: Factions may expand into areas with already-weak political competition (selection bias). Mitigated by RDD design at boundaries.
2. **Geocoding precision**: TSE addresses may not geocode perfectly; measurement error in treatment assignment. Mitigated by using distance bands rather than sharp cutoffs.
3. **GENI map timing**: Maps are rolling triennia (e.g., 2008-2010), not snapped to election dates. Need to match the closest available map to each election.
4. **Unobserved within-polygon heterogeneity**: A large polygon may contain both faction-controlled and non-controlled sub-areas. Mitigated by using polygons with higher confidence (more denúncias).
5. **SUTVA violations**: Faction effects may spill over to nearby non-faction areas (voters from faction areas may vote at nearby non-faction locations). Can test with donut-hole RDD.
6. **Limited geographic scope**: Only metro RJ (20 municipalities). External validity limited, but this is the most studied case of faction-election interactions in Brazil.

---

## 6. Implementation Plan

### Phase 1: Data Collection and Geocoding
1. **Download TSE data** for all elections 2006-2024 (voting locations + results by seção)
2. **Geocode voting locations**: TSE address → lat/lon (using Google/OSM geocoding APIs or IBGE address databases)
3. **Validate geocoding** against known polling station locations

### Phase 2: Spatial Matching
4. **Spatial join**: For each election, join voting location points to the closest GENI triennium polygon
5. **Compute treatment variables**:
   - Binary: inside any faction polygon (yes/no)
   - Categorical: which faction (CV, Milícia, TCP, ADA, none)
   - Intensity: number of denúncias, violence indicators
   - Distance: meters to nearest faction boundary
6. **Construct outcome variables**: HHI, effective candidates, turnout, null votes per seção/local

### Phase 3: Estimation
7. **Spatial RDD**: Estimate treatment effect at faction boundaries
   - Bandwidth selection (Calonico-Cattaneo-Titiunik optimal bandwidth)
   - Local polynomial regression
   - Falsification: placebo boundaries, covariate balance tests
8. **DiD robustness**: Panel estimation for locations that change faction status
9. **Heterogeneity**: By faction type, election type (local vs. federal), violence intensity

### Phase 4: Writing
10. Draft paper following Acemoglu structure:
    - Historical/institutional context of RJ factions
    - Data description
    - Main results (RDD)
    - Robustness (DiD, placebo tests, alternative specifications)
    - Mechanisms (which elections affected? which factions?)
    - Policy implications

---

## 7. Election-Map Alignment

| Election | Year | Type | Best GENI Map | Triennium |
|----------|------|------|---------------|-----------|
| Municipal | 2008 | Local | mgarj_2007_2009 | 2007-2009 |
| Federal/State | 2010 | Federal | mgarj_2009_2011 | 2009-2011 |
| Municipal | 2012 | Local | mgarj_2011_2013 | 2011-2013 |
| Federal/State | 2014 | Federal | mgarj_2013_2015 | 2013-2015 |
| Municipal | 2016 | Local | mgarj_2015_2017 | 2015-2017 |
| Federal/State | 2018 | Federal | mgarj_2017_2019 | 2017-2019 |
| Municipal | 2020 | Local | mgarj_2019_2021 | 2019-2021 |
| Federal/State | 2022 | Federal | mgarj_2021_2023 | 2021-2023 |

---

## 8. Key References

- **Acemoglu, De Feo & De Luca (2019)**: "Weak States: Causes and Consequences of the Sicilian Mafia" — *Review of Economic Studies*. Main theoretical template.
- **Dell (2015)**: "Trafficking Networks and the Mexican Drug War" — *AER*. Spatial RDD with drug cartel boundaries.
- **Alesina, Piccolo & Pinotti (2018)**: "Organized Crime, Violence, and Politics" — *RES*. Faction effects on political competition in Italy.
- **De Feo & De Luca (2017)**: "Mafia in the Ballot Box" — *AEJ: Economic Policy*. Mafia-party linkages.
- **Fergusson, Vargas & Vela (2013)**: Paramilitary organizations and politics in Colombia.
- **GENI/UFF**: Relatório Mapa de Grupos Armados do Rio de Janeiro.

---

## 9. Next Steps (Immediate)

1. [x] Extract all 16 GENI maps → CSV + GeoJSON (DONE: 53,691 obs)
2. [ ] Download TSE voting location data for RJ municipalities
3. [ ] Geocode voting locations
4. [ ] Perform initial spatial join (voting locations × faction polygons)
5. [ ] Compute descriptive statistics: how many voting locations are inside faction territories?
6. [ ] First-pass RDD estimation for 2012 municipal election (proof of concept)
