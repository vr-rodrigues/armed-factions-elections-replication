# tabelas_fase3.R — tabelas, figuras e macros das análises da fase 3 (W04–W13). Chamado por tabelas_figuras.R
# depois das tabelas principais e antes de gravar as macros; usa as funções e objetos de lá (row, sgn, put, mec, plc, ...).

W04p <- fread(file.path(F3, "W04_agregacao_prefeito.csv")); W04v <- fread(file.path(F3, "W04_agregacao_vereador.csv"))
W05 <- fread(file.path(F3, "W05_composicao.csv")); W06 <- fread(file.path(F3, "W06_inferencia_espacial.csv"))
W07 <- fread(file.path(F3, "W07_balanco.csv")); W08 <- fread(file.path(F3, "W08_antecipacao.csv")); W08h <- fread(file.path(F3, "W08_honest_sem16.csv"))
W09 <- fread(file.path(F3, "W09_exposicao_buffer.csv"))
W14 <- fread(file.path(F3, "W14_exposicao_influencia.csv")); W14c <- fread(file.path(F3, "W14_contagens.csv"))
W13e <- fread(file.path(F3, "W13_2004_estimativas.csv")); W13g <- fread(file.path(F3, "W13_2004_base_g8.csv"))
W13ev <- fread(file.path(F3, "W13_2004_event_study.csv")); W13l <- fread(file.path(F3, "W13_2004_ligacao.csv"))
cel3 <- function(att, se, p, d = 3) c(paste0(sgn(att, d), stars(p)), par_se(se, d))

# =============== Agregação municipal (W04) ===============
pos <- W04p[ano > 2008]; vpos <- W04v[ano > 2008]
vpos[, share_fluxo := nom_fluxo / validos_mapeado]
ta <- c("\\begin{table}[H]", "\\centering", "\\caption{From Local Effects to Municipal Outcomes}\\label{tab:aggregation}", "\\footnotesize",
  "\\begin{tabular}{@{}lr@{}}", "\\toprule",
  "\\multicolumn{2}{@{}l}{\\textit{Panel A. Drug-faction entry and the mayoral race, 2012--2024}} \\\\",
  row("Municipal elections with at least one treated station", int(pos[nom_fluxo > 0, .N])),
  row("Share of the city's mayoral vote cast in treated stations: mean (\\%)", num(100 * pos[nom_fluxo > 0, mean(share_fluxo)], 1)),
  row("\\quad maximum (\\%)", num(100 * pos[, max(share_fluxo)], 1)),
  row("Implied change in the winner's municipal vote share: mean (pp)", num(pos[nom_fluxo > 0, mean(dwin_fluxo_pp)], 2)),
  row("\\quad maximum (pp)", num(pos[, max(dwin_fluxo_pp)], 2)),
  row("\\quad maximum at the upper 95\\% bound of the ATT (pp)", num(pos[, max(dwin_fluxo_ub_pp)], 2)),
  row("Elections where the upper bound exceeds half the first-round margin$^{a}$", paste0(pos[, sum(pivo_fluxo)], " of ", nrow(pos))),
  row("\\quad adding stations controlled since 2007 (upper bound)", paste0(pos[, sum(pivo_estoque)], " of ", nrow(pos))),
  "\\addlinespace", "\\multicolumn{2}{@{}l}{\\textit{Panel B. Militia entry and the council race, 2012--2024}} \\\\",
  row("Municipal elections with at least one treated station", int(vpos[nom_fluxo > 0, .N])),
  row("Share of the city's council vote cast in treated stations: mean (\\%)", num(100 * vpos[nom_fluxo > 0, mean(share_fluxo)], 1)),
  row("Votes moved to small right-wing parties, in council seats: total", num(vpos[, sum(cadeiras_eq_fluxo)], 2)),
  row("\\quad at the upper 95\\% bound of the ATT", num(vpos[, sum(cadeiras_eq_fluxo_ub)], 2)),
  row("\\quad adding stations controlled since 2007 (upper bound)", num(vpos[, sum(cadeiras_eq_estoque_ub)], 2)),
  row("Council seats contested", int(vpos[, sum(cadeiras)])),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Accounting exercise that applies the estimated ATTs to the stations treated in each municipal election. Panel A multiplies the ATT on the winning candidate's local vote share (Table~\\ref{tab:mechanisms_prefeito}) by the nominal mayoral votes cast in stations that entered drug-faction territory before that election, and divides by the city's nominal mayoral votes. The first-round margin is the difference between the two most-voted candidates as a share of the city's nominal votes. $^{a}$Transfer scenario: the comparison with half the margin assumes that the implied shift moves votes from the runner-up to the winner. ``Adding stations controlled since 2007'' applies the same effect to stations already inside the territory in the first map, for which the effect is not estimated. Panel B multiplies the ATT on the small right-wing parties' share of the council vote (Table~\\ref{tab:mechanisms_vereador}) by the nominal council votes cast in militia-treated stations and divides by the electoral quotient (valid votes per seat). Treated stations include all stations that enter the territory, not only those of the balanced estimation sample.}",
  "\\end{table}")
escreve(ta, "tab_aggregation.tex")

# =============== Entrega de votos da milícia (W11 e W12) ===============
MD <- list(list("Right-wing vote share", "V3", "s_dir_ver"), list("Left-wing vote share", "V3", "s_esq_ver"), list("Small right-wing parties", "BL", "dir_outras_ver"),
           list("\\quad candidates based within 3 km", "W11", "s_dirout_local"), list("\\quad candidates based farther away", "W11", "s_dirout_naolocal"),
           list("Right-wing candidates based within 3 km", "W11", "s_dir_local"), list("Right-wing candidates based farther away", "W11", "s_dir_naolocal"),
           list("Top-quartile fundraisers", "W12", "s_q4rec_ver"))
lin_md <- function(z) { a <- mec("milicia", z[[3]], z[[2]], 100); b <- plc("milicia", z[[3]], z[[2]]); b[, `:=`(att = 100 * att, se = 100 * se)]
  c(row(z[[1]], paste0(sgn(a$att, 2), stars(a$p)), paste0(sgn(b$att, 2), stars(b$p))), row("", par_se(a$se, 2), par_se(b$se, 2))) }
plm <- pl("milicia", "saldo_ver")
tmd <- c("\\begin{table}[H]", "\\centering", "\\caption{Who Gains in City-Council Races after Militia Entry: Militia Entry and Neighbor Placebo}\\label{tab:militia_delivery}",
  "\\footnotesize", "\\begin{tabular}{@{}lcc@{}}", "\\toprule", row("Share of the council nominal vote (pp)", "Militia entry", "Neighbor placebo"), row("", "(1)", "(2)"), "\\midrule",
  unlist(lapply(MD, lin_md)), "\\bottomrule", "\\end{tabular}",
  sprintf("\\tabnotes{\\textit{Notes:} \\emph{Vereador} races. Column (1): CS-DID estimates of militia entry, same specification as Table~\\ref{tab:csdid_main} ($N=%s$ treated stations). Column (2): neighbor placebo built as in Table~\\ref{tab:concentration_identity} around militia-treated stations ($N=%s$ pseudo-treated and %s comparison stations). A candidate's base is the physical polling station where the candidate received the most votes in the municipality in that election; candidates based within 3 km are those whose base lies within 3 km of the polling station. Small right-wing parties exclude the traditional right, the evangelical right, PL, and PSL. Top-quartile fundraisers as in Table~\\ref{tab:mechanisms_vereador}. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
          int(Ntr("milicia")), int(plm$pseudo_tratados), int(plm$controles)), "\\end{table}")
escreve(tmd, "tab_militia_delivery.tex")

# =============== Timing: base da comparação e eleição de 2004 (W08 e W13) ===============
TC <- list(c("trafico", "hhi_pref"), c("trafico", "margin_pref"), c("milicia", "saldo_ver"), c("milicia", "s_dir_ver"))
w8 <- function(f, y, v) pega(W08, faccao == f & outcome == y & versao == v)
g13 <- function(f, y) pega(W13g, faccao == f & outcome == y); e13 <- function(f, y) pega(W13e, faccao == f & outcome == y)
lin_t <- function(lab, fun) { x <- lapply(TC, function(z) fun(z[1], z[2])); c(row(lab, sapply(x, `[`, 1)), row("", sapply(x, `[`, 2))) }
tt2 <- c("\\begin{table}[H]", "\\centering", "\\caption{Timing of the Comparison: Base Election and the 2004 Election}\\label{tab:timing}", "\\footnotesize",
  "\\begin{tabular}{@{}lcccc@{}}", "\\toprule",
  row("", "\\multicolumn{2}{c}{Drug factions, mayor}", "\\multicolumn{2}{c}{Militia, council}"), "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  row("", "HHI", "Margin", "Right $-$ left", "Right share"), row("", "(1)", "(2)", "(3)", "(4)"), "\\midrule",
  "\\multicolumn{5}{@{}l}{\\textit{Panel A. Elections 2008--2024, cohorts 2016--2024}} \\\\",
  lin_t("Base: election before entry", function(f, y) { x <- w8(f, y, "b"); cel3(x$att_dyn, x$se_dyn, x$p_dyn) }),
  lin_t("Base: two elections before entry", function(f, y) { x <- w8(f, y, "c"); cel3(x$att, x$se, x$p) }),
  lin_t("\\quad election before entry relative to two before", function(f, y) { x <- w8(f, y, "c"); cel3(x$vale, x$se_vale, 2 * pnorm(-abs(x$vale / x$se_vale))) }),
  "\\addlinespace", "\\multicolumn{5}{@{}l}{\\textit{Panel B. Elections 2004--2024, all cohorts}} \\\\",
  lin_t("Base: election before entry", function(f, y) { x <- g13(f, y); cel3(x$att_dyn_base_g4, x$se_dyn_base_g4, x$p_dyn_base_g4) }),
  row("\\quad pre-trends test, $p$-value", sapply(TC, function(z) br(e13(z[1], z[2])$pre_p))),
  lin_t("Base: two elections before entry", function(f, y) { x <- g13(f, y); cel3(x$att_base_g8, x$se, x$p) }),
  lin_t("\\quad election before entry relative to two before", function(f, y) { x <- g13(f, y); cel3(x$vale, x$se_vale, 2 * pnorm(-abs(x$vale / x$se_vale))) }),
  "\\bottomrule", "\\end{tabular}",
  sprintf("\\tabnotes{\\textit{Notes:} CS-DID estimates, same specification as Table~\\ref{tab:csdid_main} except for the aggregation: every effect is the equal-weighted average of the post-entry event-study coefficients over the same horizons in both bases. ``Base: two elections before entry'' assigns each station's entry one election earlier (one election of anticipation), so the election before entry is treated as possibly affected, the comparison is made against the election two before entry, and stations stop serving as not-yet-treated comparisons one election earlier; the next row reports the coefficient of the election before entry. In Panel A the 2012 cohort has no such base and is excluded. Panel B adds the 2004 municipal election: 2004 sections are linked to physical stations through the same section number in 2008 when the number of registered voters is compatible (ratio between 0.5 and 2), which covers %s percent of the 2004 electorate; parties in 2004 receive their 2006 classification. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
          num(100 * W13l[grepl("validada", item)]$valor, 1)), "\\end{table}")
escreve(tt2, "tab_timing.tex")

# =============== Matriz completa: grupo x cargo x desfecho, entrada e placebo de vizinhança ===============
# Mostra todas as células (concentração e composição partidária, prefeito e vereador, milícia e tráfico), para que os
# dois resultados principais apareçam ao lado das células nulas ou regionais.
MZ <- list(list("HHI", "hhi"), list("Margin of victory", "margin"), list("Right $-$ left balance", "saldo"))
cel_mz <- function(f, y, plac = FALSE) { x <- if (plac) pl(f, y) else Wl(f, y); c(paste0(sgn(x$att), stars(x$p)), par_se(x$se), br(x$pre_p)) }
lin_mz <- function(lab, y) { a <- cel_mz("trafico", y); b <- cel_mz("trafico", y, TRUE); c <- cel_mz("milicia", y); d <- cel_mz("milicia", y, TRUE)
  c(row(paste0("\\quad ", lab), a[1], b[1], c[1], d[1]), row("", a[2], b[2], c[2], d[2]), row("", a[3], b[3], c[3], d[3])) }
plt <- pl("trafico", "hhi_pref"); plmm <- pl("milicia", "saldo_ver")
tmz <- c("\\begin{table}[H]", "\\centering", "\\caption{Armed Entry and the Local Vote: All Groups, Offices, and Outcomes}\\label{tab:matrix}", "\\footnotesize",
  "\\begin{tabular}{@{}lcccc@{}}", "\\toprule",
  row("", "\\multicolumn{2}{c}{Drug factions}", "\\multicolumn{2}{c}{Militias}"), "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  row("", "Entry", "Neighbor placebo", "Entry", "Neighbor placebo"), row("", "(1)", "(2)", "(3)", "(4)"), "\\midrule",
  "\\multicolumn{5}{@{}l}{\\textit{Panel A. Mayoral races}} \\\\", unlist(lapply(MZ, function(z) lin_mz(z[[1]], paste0(z[[2]], "_pref")))),
  "\\addlinespace", "\\multicolumn{5}{@{}l}{\\textit{Panel B. City-council races}} \\\\", unlist(lapply(MZ, function(z) lin_mz(z[[1]], paste0(z[[2]], "_ver")))),
  "\\bottomrule", "\\end{tabular}",
  sprintf("\\tabnotes{\\textit{Notes:} CS-DID estimates, same specification as Table~\\ref{tab:csdid_main}. Columns (1) and (3): entry into the group's territory ($N=%s$ drug-faction and $N=%s$ militia treated stations). Columns (2) and (4): neighbor placebo, in which never-treated stations within 1 km of a treated station of the same municipality receive that station's entry cohort, compared with never-treated stations more than 1.5 km from any treated station and within 3 km of the group's envelope ($N=%s$ and $N=%s$ pseudo-treated stations). HHI and margins range from 0 to 1; the right-minus-left balance ranges from $-1$ to 1. Standard errors in parentheses clustered by 2-km grid cells; Wald $p$-values for the joint pre-trends test in brackets. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
          int(Ntr("trafico")), int(Ntr("milicia")), int(plt$pseudo_tratados), int(plmm$pseudo_tratados)), "\\end{table}")
escreve(tmz, "tab_matrix.tex")

# =============== Robustez (reescreve tab_robustness.tex com raio de exposição e inferência espacial) ===============
b9 <- function(f, y, D) pega(W09, faccao == f & outcome == y & raio_m == D)
b14 <- function(f, y, v = "controle_influencia") pega(W14, faccao == f & outcome == y & versao == v)
sp <- function(f, y) { x <- W06[faccao == f & outcome == y & variancia != "grade_2km"]; x[which.max(se)] }
spd <- sp("trafico", "hhi_pref"); spm <- sp("milicia", "saldo_ver")
NOMEV <- c(grade_5km = "5-km grid", territorio = "territory", municipio = "municipality", conley_1km = "Conley 1 km", conley_2km = "Conley 2 km",
           conley_5km = "Conley 5 km", conley_10km = "Conley 10 km")
t5b <- c(t5[1:(grep("Treatment measured by catchment", t5) - 1)],
  "\\multicolumn{3}{@{}l}{\\textit{Treatment measured by catchment population}} \\\\",
  row("\\quad Estimate", paste0(sgn(cap_drug$att_grp), stars(2 * pnorm(-abs(cap_drug$att_grp / cap_drug$se_grp)))), paste0(sgn(cap_mil$att_group), stars(cap_mil$p_group))),
  row("", par_se(cap_drug$se_grp), par_se(cap_mil$se_group)), "\\addlinespace",
  "\\multicolumn{3}{@{}l}{\\textit{Alternative exposure definitions}} \\\\",
  row("\\quad Within 250 m of a control polygon", cel3(b9("trafico", "hhi_pref", 250)$att, NA, b9("trafico", "hhi_pref", 250)$p)[1], cel3(b9("milicia", "saldo_ver", 250)$att, NA, b9("milicia", "saldo_ver", 250)$p)[1]),
  row("", par_se(b9("trafico", "hhi_pref", 250)$se), par_se(b9("milicia", "saldo_ver", 250)$se)),
  row("\\quad Within 500 m of a control polygon", cel3(b9("trafico", "hhi_pref", 500)$att, NA, b9("trafico", "hhi_pref", 500)$p)[1], cel3(b9("milicia", "saldo_ver", 500)$att, NA, b9("milicia", "saldo_ver", 500)$p)[1]),
  row("", par_se(b9("trafico", "hhi_pref", 500)$se), par_se(b9("milicia", "saldo_ver", 500)$se)),
  row("\\quad Inside a control or influence polygon", cel3(b14("trafico", "hhi_pref")$att, NA, b14("trafico", "hhi_pref")$p)[1], cel3(b14("milicia", "saldo_ver")$att, NA, b14("milicia", "saldo_ver")$p)[1]),
  row("", par_se(b14("trafico", "hhi_pref")$se), par_se(b14("milicia", "saldo_ver")$se)), "\\addlinespace",
  "\\multicolumn{3}{@{}l}{\\textit{Spatial inference: largest standard error across alternatives}} \\\\",
  row("\\quad Standard error", par_se(spd$se), par_se(spm$se)),
  row("\\quad Variance estimator", NOMEV[[spd$variancia]], NOMEV[[spm$variancia]]),
  row("\\quad $p$-value", pv(spd$p), pv(spm$p)),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Main estimates from Tables~\\ref{tab:csdid_main} and~\\ref{tab:militia_ideology}. The specification curve crosses treatment by coordinates or catchment; map of the year before or of the election year; group type at entry, or a sample restricted to stations whose group type is stable across the municipal-election maps; comparison stations within 500 m, 1 km, or 2 km of the group's envelope, or all never-treated stations; balanced or unbalanced panel; cohort or event-time aggregation; and with or without municipality indicators. Every specification conditions on neighborhood income. It reports the 128 specifications that compare stations within municipalities. Randomization inference permutes entry cohorts across polling stations within municipality and uses the $t$-statistic \\citep{young2019channeling}. The neighbor placebo is described in Table~\\ref{tab:matrix}. The catchment treatment assigns entry when at least half of the 2010 census population of the station's Voronoi catchment lives inside the faction's territory. Distance-based exposure assigns entry when the station is within the stated distance of a control polygon; comparison stations are never-treated stations within 1 km (250 m) or 2 km (500 m) of the faction's envelope. The Fogo Cruzado maps distinguish armed territorial control from armed territorial influence; the control-or-influence exposure assigns entry when the station first falls inside a polygon of either layer, with the faction of the control polygon when there is one, and compares with stations never inside either layer within 1 km of the faction's combined envelope. Spatial inference reports the largest standard error among clustering by 5-km grid cells, by territory (contiguous patches of ever-controlled area), and by municipality, and Conley standard errors with a Bartlett kernel and bandwidths of 1, 2, 5, and 10 km (Appendix Table~\\ref{tab:spatial}). $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(t5b, "tab_robustness.tex")

# =============== Apêndice: inferência espacial ===============
SPO <- data.table(faccao = c("trafico", "trafico", "trafico", "trafico", "milicia", "milicia", "milicia", "milicia"),
                  outcome = c("hhi_pref", "margin_pref", "eleito_share_pref", "hhi_ver", "saldo_ver", "s_dir_ver", "dir_outras_ver", "esq_psol_ver"),
                  rot = c("Drug, mayoral HHI", "Drug, mayoral margin", "Drug, winner's vote share", "Drug, council HHI",
                          "Militia, council right $-$ left", "Militia, council right share", "Militia, small right-wing parties", "Militia, PSOL"))
VS <- c("grade_2km", "grade_5km", "territorio", "municipio", "conley_1km", "conley_2km", "conley_5km", "conley_10km")
tsp <- c("\\begin{table}[H]", "\\centering", "\\caption{Standard Errors under Alternative Spatial Dependence}\\label{tab:spatial}", "\\scriptsize", "\\setlength{\\tabcolsep}{3pt}",
  "\\begin{tabular}{@{}lccccccccc@{}}", "\\toprule",
  row("", "", "\\multicolumn{4}{c}{Clusters}", "\\multicolumn{4}{c}{Conley (Bartlett)}"), "\\cmidrule(lr){3-6}\\cmidrule(lr){7-10}",
  row("Outcome", "ATT", "2-km grid", "5-km grid", "Territory", "Municipality", "1 km", "2 km", "5 km", "10 km"), "\\midrule",
  sapply(seq_len(nrow(SPO)), function(i) { x <- W06[faccao == SPO$faccao[i] & outcome == SPO$outcome[i]]; setkey(x, variancia)
    row(SPO$rot[i], sgn(x$att[1]), sapply(VS, function(v) paste0(num(x[v]$se), stars(x[v]$p)))) }),
  row("Clusters (drug; militia)", "", sapply(VS[1:4], function(v) paste0(W06[faccao == "trafico" & outcome == "hhi_pref" & variancia == v]$clusters, "; ",
                                                                          W06[faccao == "milicia" & outcome == "saldo_ver" & variancia == v]$clusters)), "", "", "", ""),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Same point estimates as the main specification; only the variance changes. All variances are computed from the influence functions of the aggregate ATT. Territories are contiguous patches of the area ever controlled by the faction in an annual map from 2007 to 2024 (patches less than 200 m apart are merged); treated stations belong to the patch they are in and comparison stations to the nearest patch. Conley variances weight pairs of stations by a Bartlett kernel in their distance. With only a dozen municipal clusters, the municipality-clustered errors are themselves imprecise. Stars refer to the $p$-value with each standard error. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(tsp, "tab_spatial.tex")

# =============== Apêndice: composição do eleitorado e balanço ===============
COMP <- c(log_aptos = "Log registered voters", fem = "Women (share)", ate24 = "Aged 24 or less (share)", mais60 = "Aged 60 or more (share)",
          ate_fund = "At most primary education (share)", superior = "Some college education (share)")
tco <- c("\\begin{table}[H]", "\\centering", "\\caption{Composition of the Registered Electorate}\\label{tab:composition}", "\\footnotesize",
  "\\begin{tabular}{@{}lcccc@{}}", "\\toprule", row("", "\\multicolumn{2}{c}{Militia}", "\\multicolumn{2}{c}{Drug factions}"), "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  row("Outcome", "ATT", "Wald $p$", "ATT", "Wald $p$"), "\\midrule",
  unlist(lapply(names(COMP), function(v) { a <- pega(W05, faccao == "milicia" & outcome == v); b <- pega(W05, faccao == "trafico" & outcome == v)
    c(row(COMP[[v]], paste0(sgn(a$att, 4), stars(a$p)), br(a$pre_p), paste0(sgn(b$att, 4), stars(b$p)), br(b$pre_p)), row("", par_se(a$se, 4), "", par_se(b$se, 4), "")) })),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} CS-DID estimates, same specification as Table~\\ref{tab:csdid_main}. Outcomes describe the registered electorate of the polling station at each municipal election, from TSE's electorate profile by section aggregated to physical stations: shares by sex, age group, and education, and the log number of registered voters. Standard errors in parentheses clustered by 2-km grid cells; Wald $p$-values for the joint pre-trends test in brackets. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(tco, "tab_composition.tex")
BALV <- c(hhi_pref = "Mayoral HHI", margin_pref = "Mayoral margin of victory", comparecimento_taxa = "Turnout", hhi_ver = "Council HHI",
          saldo_ver = "Council right $-$ left", saldo_pref = "Mayoral right $-$ left", log_aptos = "Log registered voters")
tba <- c("\\begin{table}[H]", "\\centering", "\\caption{Balance and Pre-Entry Trends within Municipalities}\\label{tab:balance}", "\\scriptsize",
  "\\begin{tabular}{@{}lcccc@{}}", "\\toprule", row("", "\\multicolumn{2}{c}{Militia}", "\\multicolumn{2}{c}{Drug factions}"), "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  row("", "Level, 2008", "Change 2008--2012", "Level, 2008", "Change 2008--2012"), "\\midrule",
  unlist(lapply(names(BALV), function(v) { a <- pega(W07, faccao == "milicia" & outcome == v); b <- pega(W07, faccao == "trafico" & outcome == v)
    c(row(BALV[[v]], paste0(sgn(a$dif_dentro_mun), stars(a$p_dentro)), paste0(sgn(a$tend_0812_dif), stars(a$tend_0812_p)),
          paste0(sgn(b$dif_dentro_mun), stars(b$p_dentro)), paste0(sgn(b$tend_0812_dif), stars(b$tend_0812_p))),
      row("", par_se(a$se_dentro), par_se(a$tend_0812_se), par_se(b$se_dentro), par_se(b$tend_0812_se))) })),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Main estimation sample. ``Level, 2008'': difference between treated and comparison stations in 2008, within municipality. ``Change 2008--2012'': among stations not yet treated in 2012, difference between stations that enter later (2016--2024 cohorts) and never-treated stations in the change of the outcome from 2008 to 2012, within municipality. Unweighted; standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(tba, "tab_balance.tex")

# =============== HonestDiD com a terceira versão (sem e = -16) ===============
lin_hd3 <- function(i) {
  a <- pega(HB, faccao == HN$faccao[i] & outcome == HN$outcome[i] & versao == "plano"); b <- pega(HB, faccao == HN$faccao[i] & outcome == HN$outcome[i] & versao == "paper")
  c3 <- W08h[faccao == HN$faccao[i] & outcome == HN$outcome[i] & versao == "sem e=-16"]
  row(HN$rot[i], sgn(a$alvo), paste0("[", sgnt(a$ic_lb), ", ", sgnt(a$ic_ub), "]"), num(a$mbar_rm, 2), if (nrow(c3)) num(c3$mbar_rm, 2) else "",
      sgn(b$alvo), paste0("[", sgnt(b$ic_lb), ", ", sgnt(b$ic_ub), "]"), num(b$mbar_rm, 2))
}
thd3 <- c("\\begin{table}[H]", "\\centering", "\\caption{Honest-DiD Breakdown $\\overline{M}$}\\label{tab:honest_did}", "\\scriptsize",
  "\\begin{tabular}{@{}lccccccc@{}}", "\\toprule",
  row("", "\\multicolumn{4}{c}{Average post-entry effect}", "\\multicolumn{3}{c}{Entry-election effect, one pre-period}"),
  "\\cmidrule(lr){2-5}\\cmidrule(lr){6-8}",
  row("", "", "", "\\multicolumn{2}{c}{Breakdown $\\overline{M}$}", "", "", ""), "\\cmidrule(lr){4-5}",
  row("Outcome", "ATT", "Original 95\\% CI", "All pre", "No $e=-16$", "ATT", "Original 95\\% CI", "Breakdown $\\overline{M}$"), "\\midrule",
  sapply(seq_len(nrow(HN)), lin_hd3), "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Relative-magnitudes sensitivity following \\citet{rambachan2023honest}, applied to the event-study estimates of the main specification with the clustered covariance matrix. Columns 1--4 target the average of the post-entry coefficients, using all pre-entry coefficients ($e=-16,-12,-8$ years relative to entry, with elections four years apart; reference $e=-4$) or dropping $e=-16$, which only the 2024 cohort identifies. Columns 5--7 target the entry-election coefficient ($e=0$) in a short window with one pre-period ($e=-8$), reference $e=-4$, and two post-periods ($e=0,+4$). $\\overline{M}$ is the largest value on the grid $\\{0, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2\\}$ at which the 95\\% robust confidence set still excludes zero; 0.00 is also reported when the set includes zero already at $\\overline{M}=0$. Implementation via the \\texttt{HonestDiD} R package, with outcomes rescaled for numerical stability.}",
  "\\end{table}")
escreve(thd3, "tab_honest_did.tex")

# =============== Figura: event studies com 2004 ===============
EV <- copy(W13ev)[, k := e / 4]
EV[, painel := factor(c(trafico_hhi_pref = "A. Drug factions: mayoral HHI", trafico_margin_pref = "B. Drug factions: mayoral margin",
                        milicia_saldo_ver = "C. Militia: council right minus left", milicia_s_dir_ver = "D. Militia: council right share")[paste(faccao, outcome, sep = "_")],
                      levels = c("A. Drug factions: mayoral HHI", "B. Drug factions: mayoral margin", "C. Militia: council right minus left", "D. Militia: council right share"))]
EV <- EV[!is.na(painel)]
g4 <- ggplot(EV, aes(k, att)) + geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.3) +
  geom_vline(xintercept = -0.5, linetype = "dashed", colour = "grey60", linewidth = 0.3) +
  geom_errorbar(data = EV[e != -4], aes(ymin = att - 1.96 * se, ymax = att + 1.96 * se), width = 0.12, linewidth = 0.4) +
  geom_point(data = EV[e != -4], size = 1.8) + geom_point(data = EV[e == -4], size = 1.8, shape = 21, fill = "white") +
  scale_x_continuous(breaks = sort(unique(EV$k))) + facet_wrap(~ painel, scales = "free_y", ncol = 2) +
  labs(x = "Elections Relative to Treatment", y = "ATT") + theme_classic(base_size = 10) +
  theme(strip.background = element_blank(), strip.text = element_text(hjust = 0, face = "bold"))
ggsave(file.path(FIG, "fig_es_2004.pdf"), g4, width = 7.5, height = 5.4); cat("figura: fig_es_2004.pdf\n")

# =============== macros da fase 3 ===============
put("AggN", int(pos[nom_fluxo > 0, .N])); put("AggShareMean", num(100 * pos[nom_fluxo > 0, mean(share_fluxo)], 1)); put("AggShareMax", num(100 * pos[, max(share_fluxo)], 0))
put("AggShiftMean", num(pos[nom_fluxo > 0, mean(dwin_fluxo_pp)], 2)); put("AggShiftMax", num(pos[, max(dwin_fluxo_pp)], 2)); put("AggShiftUB", num(pos[, max(dwin_fluxo_ub_pp)], 1))
put("AggPivot", int(pos[, sum(pivo_fluxo)])); put("AggPivotStock", int(pos[, sum(pivo_estoque)])); put("AggElections", int(nrow(pos)))
put("AggSeats", num(vpos[, sum(cadeiras_eq_fluxo)], 1)); put("AggSeatsUB", num(vpos[, sum(cadeiras_eq_fluxo_ub)], 2)); put("AggSeatsTotal", int(vpos[, sum(cadeiras)]))
put("AggVerShareMean", num(100 * vpos[nom_fluxo > 0, mean(share_fluxo)], 1))
put("ExcWinPrefPP", pp(pega(fread(file.path(F1, "F01_todas_estimativas.csv")), faccao == "trafico" & amostra == "a" & outcome == "exc_vencedor_pref")$att_group))
put("ExcTopVerPP", pp(pega(fread(file.path(F1, "F01_todas_estimativas.csv")), faccao == "milicia" & amostra == "a" & outcome == "exc_vencedor_ver")$att_group))
put("ExcTopVerp", paste0("$p=", num(pega(fread(file.path(F1, "F01_todas_estimativas.csv")), faccao == "milicia" & amostra == "a" & outcome == "exc_vencedor_ver")$p_group), "$"))
cw <- function(f, v) pega(W05, faccao == f & outcome == v)
put("CompSupDrugPP", pp(cw("trafico", "superior")$att)); put("CompSupDrugBase", num(100 * cw("trafico", "superior")$media_pre_tratados, 1))
put("CompBound", num(2 * abs(cw("trafico", "superior")$att), 3))
put("CompAptosDrugpre", paste0("$p", ifelse(cw("trafico", "log_aptos")$pre_p < 0.001, "<0.001", paste0("=", num(cw("trafico", "log_aptos")$pre_p))), "$"))
put("BalTrendDrugHHI", num(pega(W07, faccao == "trafico" & outcome == "hhi_pref")$tend_0812_dif)); put("BalLevelDrugHHI", sgnt(pega(W07, faccao == "trafico" & outcome == "hhi_pref")$dif_dentro_mun))
x <- w8("trafico", "hhi_pref", "c"); put("BaseCDrugHHI", num(x$att)); put("BaseCDrugHHIse", num(x$se)); put("BaseCDrugVale", sgnt(x$vale))
x <- w8("trafico", "hhi_pref", "b"); put("BaseBDrugHHI", num(x$att_dyn))
x <- g13("trafico", "hhi_pref"); put("GFourDynDrugHHI", num(x$att_dyn_base_g4)); put("GEightDrugHHI", num(x$att_base_g8)); put("GEightDrugHHIse", num(x$se)); put("GEightDrugHHIp", paste0("$p=", num(x$p), "$"))
put("GEightDrugVale", sgnt(x$vale)); put("GEightDrugValese", num(x$se_vale))
x <- g13("trafico", "margin_pref"); put("GFourDynDrugMarg", num(x$att_dyn_base_g4)); put("GEightDrugMarg", num(x$att_base_g8)); put("GEightDrugMargp", paste0("$p=", num(x$p), "$")); put("GEightDrugMargVale", sgnt(x$vale))
x <- g13("milicia", "saldo_ver"); put("GFourDynMilBal", num(x$att_dyn_base_g4)); put("GEightMilBal", num(x$att_base_g8)); put("GEightMilBalp", paste0("$p=", num(x$p), "$"))
x <- g13("milicia", "s_dir_ver"); put("GFourDynMilRight", num(x$att_dyn_base_g4)); put("GEightMilRight", num(x$att_base_g8)); put("GEightMilRightp", paste0("$p=", num(x$p), "$"))
put("FourDrugHHIpre", paste0("$p=", num(e13("trafico", "hhi_pref")$pre_p), "$")); put("FourMilBalpre", paste0("$p=", num(e13("milicia", "saldo_ver")$pre_p), "$"))
put("FourDrugHHI", num(e13("trafico", "hhi_pref")$att)); put("FourMilBal", num(e13("milicia", "saldo_ver")$att))
put("FourCov", num(100 * W13l[grepl("validada", item)]$valor, 1))
put("FourDrugEeight", num(W13ev[faccao == "trafico" & outcome == "hhi_pref" & e == -8]$att)); put("FourDrugEeightse", num(W13ev[faccao == "trafico" & outcome == "hhi_pref" & e == -8]$se))
x <- b9("trafico", "hhi_pref", 250); put("BufDrugTwo", num(x$att)); x <- b9("trafico", "hhi_pref", 500); put("BufDrugFive", num(x$att)); put("BufDrugN", int(x$tratados))
x <- b9("trafico", "margin_pref", 500); put("BufDrugMargFivePP", pp(x$att))
x <- b9("milicia", "saldo_ver", 250); put("BufMilTwoPP", pp(x$att)); put("BufMilTwop", paste0("$p=", num(x$p), "$"))
x <- b9("milicia", "saldo_ver", 500); put("BufMilFivePP", pp(x$att)); put("BufMilFivep", paste0("$p=", num(x$p), "$"))
x <- b9("milicia", "s_dir_ver", 250); put("BufMilRightTwoPP", pp(x$att))
pfmt <- function(p) paste0("$p=", num(p), "$")
x <- b14("trafico", "hhi_pref"); put("InflDrugHHI", num(x$att)); put("InflDrugHHIp", pfmt(x$p)); put("InflDrugN", int(x$tratados))
x <- b14("trafico", "margin_pref"); put("InflDrugMargPP", pp(x$att)); put("InflDrugMargp", pfmt(x$p)); put("InflDrugMargpre", pfmt(x$pre_p))
x <- b14("milicia", "saldo_ver"); put("InflMilBalPP", pp(x$att)); put("InflMilBalp", pfmt(x$p)); put("InflMilN", int(x$tratados))
x <- b14("milicia", "s_dir_ver"); put("InflMilRightPP", pp(x$att)); put("InflMilRightp", pfmt(x$p))
put("InflNewMil", int(W14c[faccao == "milicia" & grepl("novo", situacao)]$N)); put("InflNewDrug", int(W14c[faccao == "trafico" & grepl("novo", situacao)]$N))
put("InflEarlyMil", int(W14c[faccao == "milicia" & situacao == "entra antes"]$N)); put("InflEarlyDrug", int(W14c[faccao == "trafico" & situacao == "entra antes"]$N))
put("SpDrugMaxSE", num(spd$se)); put("SpMilMaxSE", num(spm$se)); put("SpDrugMinT", num(min(abs(W06[faccao == "trafico" & outcome == "hhi_pref"]$att / W06[faccao == "trafico" & outcome == "hhi_pref"]$se)), 1))
put("SpMilMinT", num(min(abs(W06[faccao == "milicia" & outcome == "saldo_ver"]$att / W06[faccao == "milicia" & outcome == "saldo_ver"]$se)), 2))
put("HDDrugNoSixteen", num(W08h[faccao == "trafico" & outcome == "hhi_pref" & versao == "sem e=-16"]$mbar_rm, 1))
x <- f3(W10, "trafico", "lider_pub"); put("PubLeadDrugPP", pp(x$att)); put("PubLeadDrugp", paste0("$p=", num(x$p), "$"))
x <- f3(W10, "trafico", "lider_pub", "placebo"); put("PlacPubLeadDrugPP", pp(x$att)); put("PlacPubLeadDrugp", paste0("$p=", num(x$p), "$"))
x <- f3(W10, "trafico", "s_prefocc"); put("MayorDrugPP", pp(x$att)); put("MayorDrugp", paste0("$p=", num(x$p), "$"))
x <- f3(W10, "trafico", "s_prefocc", "placebo"); put("PlacMayorDrugPP", pp(x$att))
x <- f3(W12, "trafico", "vw_logrec_pref"); put("RevDrug", num(x$att, 2)); put("RevDrugp", paste0("$p=", num(x$p), "$")); put("RevDrugPct", num(100 * (exp(x$att) - 1), 0))
x <- f3(W12, "trafico", "vw_logrec_pref", "placebo"); put("PlacRevDrug", num(x$att, 2))
x <- f3(W12, "milicia", "s_q4rec_ver"); put("QFourMilPP", pp(x$att)); put("QFourMilp", paste0("$p=", num(x$p), "$"))
x <- f3(W12, "milicia", "s_q4rec_ver", "placebo"); put("PlacQFourMilPP", pp(x$att))
lig <- fread(file.path(F3, "W12_ligacao.csv")); put("FinLinkPref", num(100 * lig[cargo == "prefeito", min(votos_ligados)], 0)); put("FinLinkVer", num(100 * lig[cargo == "vereador", min(votos_ligados)], 0))
x <- f3(W11b, "milicia", "s_dirout_local"); put("LocalSRMilPP", pp(x$att)); put("LocalSRMilp", paste0("$p=", num(x$p), "$"))
x <- f3(W11b, "milicia", "s_dirout_naolocal"); put("FarSRMilPP", pp(x$att))
x <- f3(W11b, "milicia", "s_dirout_local", "placebo"); put("PlacLocalSRMilPP", pp(x$att))
x <- f3(W11a, "milicia", "s_dirout_local"); put("LocalOneSRMilPP", pp(x$att)); x <- f3(W11a, "milicia", "s_dirout_naolocal"); put("FarOneSRMilPP", pp(x$att))
cat("OK tabelas_fase3\n")
