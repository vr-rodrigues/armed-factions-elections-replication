# Proposal for coauthor extensions

Date: 2026-05-03

## Immediate title change

The title should be shortened to:

> Armed Factions and Local Electoral Competition

This removes the subtitle after the colon and keeps the paper framed around the main contribution.

## Recommendation

The paper should stay primarily an electoral paper. The strongest extension is to add candidate-level and campaign-finance electoral outcomes, because they speak directly to the existing mechanism: armed groups reshape entry, campaigning, vote concentration, and representation.

Economic outcomes should be treated as a mechanism or validation exercise, not as a second main paper. The best path is a pilot using Data.Rio and Receita/CNPJ-style data to see whether militia control leaves a local economic signature in business entry, sectoral composition, and urban licensing.

## Data.Rio feasibility

Most promising sources:

- Data.Rio catalog and datalake: https://www.data.rio/ and https://www.dados.rio/datalake
- BCadastro CNPJ mart: https://data-catalog.iplan.dados.rio/api_bcadastro/
- Urban licensing/SICOP tables in the municipal catalog, if accessible through the datalake.
- Divida ativa and Mais-Valia tables, useful as exploratory fiscal/real-estate outcomes.

Most useful economic outcomes:

- Number of active CNPJs by area, year, and broad CNAE.
- Business entry and exit/inactivity by area-year.
- Capital social, porte, and sectoral composition.
- Concentration by CNAE-area, especially in sectors that can be territorially monopolized.
- Licenses issued, licensed area, number of units, and use type.
- Divida ativa values and counts, ideally IPTU-linked where address information is available.
- Mais-Valia records, values, payment status, and IPTU-linked geography.

Granularity assessment:

- The CNPJ source has address fields such as CEP, municipality, bairro, logradouro, numero, complemento, CNAE, opening date, cadastral status, capital social, porte, and legal nature.
- This is promising but not automatically equivalent to the electoral geography. It likely requires geocoding and a match-quality audit.
- The cleanest empirical unit for the economic pilot is probably area-year or area-CNAE-year, using bairro, grid, buffer, or polygons matched to armed-group territories.
- Only after that should it be merged back to local electoral units.

## Literature support

The cited literature supports three extensions.

Economic mechanism:

- De Feo and De Luca, "Mafia in the Ballot Box", connects mafia political control to economic advantages in construction.
- Acemoglu, De Feo, and De Luca, "Weak States", links criminal-political power to long-run public goods and development.
- Monteiro and collaborators on criminal enterprises in Rio support the idea that armed groups diversify into legal and para-legal markets.
- Work on policy enforcement in Rio links criminal control to state enforcement and local market governance.
- "Gang Rule" and "Killing in the Slums" motivate extortion, business taxation, and criminal governance of residents and firms.

Electoral/candidate mechanism:

- "How Criminal Governance Undermines Elections" supports candidate gatekeeping, vote corralling, and alignment between armed groups and candidates.
- "Organized Crime, Violence, and Politics" supports outcomes on candidates, campaign activity, violence, and spending.
- "The Monopoly of Violence" supports ideological/political alignment and executive vote outcomes.
- "The Violence of Law-and-Order Politics" supports candidate ideology/classification using candidate traits, occupations, and platforms.
- Broker and turnout-buying papers support outcomes such as campaign spending, vote efficiency, and turnout-oriented mobilization.

## Proposed electoral additions

High priority:

- Education of candidates, weighted by votes at the local electoral unit.
- Age of candidates, weighted by votes.
- Education and age of elected candidates receiving votes in the area.
- Vote share for candidates who are ultimately elected.
- Ideology score of candidates or parties, weighted by local vote share.
- Campaign spending weighted by local votes.
- Spending per vote or votes per real spent, measured locally when possible.
- Vote share going to high-spending candidates.
- Number of competitive candidates, not just total candidates.

Lower priority or appendix:

- Occupation-based candidate types, including police, military, security, public administration, and law-and-order profiles.
- Gender/race composition of candidate vote shares if data quality is good.
- Party-level blocs such as left, center, right, evangelical/conservative, and law-and-order.

## Proposed economic pilot

Core pilot:

1. Build CNPJ area-year and area-CNAE-year panels.
2. Build licensing area-year panels, especially for construction, area, units, and use type.
3. Estimate event-study/CS-DID style effects around changes in armed control.
4. Compare militia effects with drug-faction effects.
5. Report a match-quality table before any causal table.

Main hypotheses:

- Militia control reduces independent business entry in sectors vulnerable to territorial extortion.
- Militia control increases concentration in locally monopolizable sectors.
- Militia control has a stronger signature in construction, licenses, real-estate regularization, and recurrent local services.
- Drug factions should look more like a risk/disruption shock, with less evidence of formal urban-market organization.

Best triple-difference:

`militia area x post control x exposed sector`

Exposed sectors should include construction, local transport, gas, telecom/internet, security, household services, and neighborhood commerce. Placebo sectors should be less dependent on territorial access and recurrent local payments.

## Econometric guardrails

- Pre-specify families of outcomes and adjust for multiple testing or report sharpened q-values.
- Keep the main estimand aligned with the current CS-DID framework when possible.
- For economic data, do not force polling-station precision if addresses only support bairro/grid precision.
- Include geocoding rate, match rate, and unmatched-address diagnostics.
- Separate "mechanism evidence" from "new main outcome" in the writing.
- Treat Divida Ativa and Mais-Valia as exploratory unless timing and geography prove clean.

## Final proposal to coauthor

I would reply that we should accept the title suggestion immediately. For the substantive expansion, we should first add electoral outcomes that use already compatible TSE data: candidate age, education, ideology/party bloc, elected-candidate vote share, and campaign spending weighted by local votes. These fit the current paper and can speak directly to mechanisms of candidate selection, campaign efficiency, and representation.

In parallel, we should run a short Data.Rio pilot. The most promising economic mechanism is not generic income or GDP, but local business and urban-market reorganization: CNPJ entry/exit by sector, business composition, construction licenses, area/units licensed, Divida Ativa, and Mais-Valia. If the geocoding and timing are good, this can become a mechanism table or appendix. If not, we can still mention that the pilot was checked and keep the paper focused on electoral competition.
