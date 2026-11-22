# tabelas_fase5.R — inferência conjunta da matriz (W15) e voto legislativo estadual (W16).
# Chamado por tabelas_figuras.R depois de tabelas_fase3.R e antes de gravar as macros; usa as funções e objetos de lá
# (row, sgn, put, Wl, pl, cel_mz, MZ, Ntr, ...). Reescreve tab_matrix.tex com a coluna "entrada − placebo".

W15 <- fread(file.path(F3, "W15_matriz_conjunta.csv")); W15c <- fread(file.path(F3, "W15_contagens.csv"))
W16 <- fread(file.path(F3, "W16_legislativo_estadual.csv"))
j15 <- function(f, y) pega(W15, faccao == f & outcome == y)
# as estimativas de entrada e de placebo do W15 são as mesmas das tabelas (W01; V04 e W03)
for (i in seq_len(nrow(W15))) { z <- W15[i]
  stopifnot(abs(z$att - Wl(z$faccao, z$outcome)$att) < 1e-10, abs(z$se - Wl(z$faccao, z$outcome)$se) < 1e-10,
            abs(z$plac - pl(z$faccao, z$outcome)$att) < 1e-10, abs(z$se_plac - pl(z$faccao, z$outcome)$se) < 1e-10) }
pfm <- function(p) if (p < 0.001) "$p<0.001$" else paste0("$p=", num(p), "$")

# =============== Matriz completa com a diferença entre entrada e placebo ===============
cel_d <- function(f, y) { x <- j15(f, y); c(paste0(sgn(x$dif), stars(x$p_dif)), par_se(x$se_dif), "") }
lin_mz5 <- function(lab, y) { a <- cel_mz("trafico", y); b <- cel_mz("trafico", y, TRUE); ab <- cel_d("trafico", y)
  m <- cel_mz("milicia", y); n <- cel_mz("milicia", y, TRUE); mn <- cel_d("milicia", y)
  c(row(paste0("\\quad ", lab), a[1], b[1], ab[1], m[1], n[1], mn[1]), row("", a[2], b[2], ab[2], m[2], n[2], mn[2]), row("", a[3], b[3], ab[3], m[3], n[3], mn[3])) }
tmz5 <- c("\\begin{table}[H]", "\\centering", "\\caption{Armed Entry and the Local Vote: All Groups, Offices, and Outcomes}\\label{tab:matrix}", "\\footnotesize",
  "\\begin{tabular}{@{}lcccccc@{}}", "\\toprule",
  row("", "\\multicolumn{3}{c}{Drug factions}", "\\multicolumn{3}{c}{Militias}"), "\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}",
  row("", "Entry", "Neighbor", "Entry $-$", "Entry", "Neighbor", "Entry $-$"),
  row("", "", "placebo", "placebo", "", "placebo", "placebo"), row("", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)"), "\\midrule",
  "\\multicolumn{7}{@{}l}{\\textit{Panel A. Mayoral races}} \\\\", unlist(lapply(MZ, function(z) lin_mz5(z[[1]], paste0(z[[2]], "_pref")))),
  "\\addlinespace", "\\multicolumn{7}{@{}l}{\\textit{Panel B. City-council races}} \\\\", unlist(lapply(MZ, function(z) lin_mz5(z[[1]], paste0(z[[2]], "_ver")))),
  "\\bottomrule", "\\end{tabular}",
  sprintf("\\tabnotes{\\textit{Notes:} CS-DID estimates, same specification as Table~\\ref{tab:csdid_main}. Columns (1) and (4): entry into the group's territory ($N=%s$ drug-faction and $N=%s$ militia treated stations). Columns (2) and (5): neighbor placebo, in which never-treated stations within 1 km of a treated station of the same municipality receive that station's entry cohort, compared with never-treated stations more than 1.5 km from any treated station and within 3 km of the group's envelope ($N=%s$ and $N=%s$ pseudo-treated stations). Columns (3) and (6): difference between the entry estimate and the placebo; its standard error accounts for the stations and grid cells that the two estimation samples share (cluster sums of the two sets of influence functions). HHI and margins range from 0 to 1; the right-minus-left balance ranges from $-1$ to 1. Standard errors in parentheses clustered by 2-km grid cells; Wald $p$-values for the joint pre-trends test in brackets. Appendix Table~\\ref{tab:joint} adjusts the twelve entry estimates for multiple testing. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
          int(Ntr("trafico")), int(Ntr("milicia")), int(pl("trafico", "hhi_pref")$pseudo_tratados), int(pl("milicia", "saldo_ver")$pseudo_tratados)), "\\end{table}")
escreve(tmz5, "tab_matrix.tex")

# =============== Apêndice: testes múltiplos nas 12 estimativas de entrada ===============
LAB15 <- c(hhi_pref = "Mayoral HHI", margin_pref = "Mayoral margin of victory", saldo_pref = "Mayoral right $-$ left balance",
           hhi_ver = "Council HHI", margin_ver = "Council margin of victory", saldo_ver = "Council right $-$ left balance")
lin_j <- function(f) unlist(lapply(names(LAB15), function(y) { x <- j15(f, y)
  row(paste0("\\quad ", LAB15[[y]]), sgn(x$att), pv(x$p), pv(x$p_holm), pv(x$q_bh), pv(x$p_maxt)) }))
tj <- c("\\begin{table}[H]", "\\centering", "\\caption{Joint Inference for the Twelve Entry Estimates}\\label{tab:joint}", "\\footnotesize",
  "\\begin{tabular}{@{}lccccc@{}}", "\\toprule", row("", "", "", "\\multicolumn{3}{c}{Adjusted for the twelve tests}"), "\\cmidrule(lr){4-6}",
  row("", "Entry estimate", "$p$-value", "Holm", "Benjamini--Hochberg", "Max-$t$"), "\\midrule",
  "\\multicolumn{6}{@{}l}{\\textit{Drug factions}} \\\\", lin_j("trafico"), "\\addlinespace", "\\multicolumn{6}{@{}l}{\\textit{Militias}} \\\\", lin_j("milicia"),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Entry estimates and unadjusted $p$-values from Table~\\ref{tab:matrix}. Holm: family-wise adjusted $p$-values \\citep{holm1979simple}. Benjamini--Hochberg: false-discovery-rate $q$-values \\citep{benjamini1995controlling}. Max-$t$: step-down family-wise adjusted $p$-values \\citep{romano2005stepwise} from 9,999 draws of a multiplier bootstrap that reweights the 2-km grid-cell sums of the influence functions of the twelve estimates with Rademacher weights, which preserves the dependence between outcomes, offices, and groups.}",
  "\\end{table}")
escreve(tj, "tab_joint.tex")

# =============== Apêndice: composição partidária do voto para deputado estadual e federal ===============
l16 <- function(f, y, am) pega(W16, faccao == f & outcome == y & amostra == am)
cel16 <- function(f, y, am) { x <- l16(f, y, am); c(paste0(sgn(100 * x$att, 2), stars(x$p)), par_se(100 * x$se, 2), br(x$pre_p)) }
L16 <- list(c("Right $-$ left balance", "saldo"), c("Right-wing vote share", "s_dir"), c("Left-wing vote share", "s_esq"))
lin16 <- function(lab, y) { a <- cel16("trafico", y, "tratados"); b <- cel16("trafico", y, "placebo"); m <- cel16("milicia", y, "tratados"); n <- cel16("milicia", y, "placebo")
  c(row(paste0("\\quad ", lab), a[1], b[1], m[1], n[1]), row("", a[2], b[2], m[2], n[2]), row("", a[3], b[3], m[3], n[3])) }
t16 <- c("\\begin{table}[H]", "\\centering", "\\caption{Partisan Composition of the Vote for State and Federal Deputies}\\label{tab:legislative}", "\\footnotesize",
  "\\begin{tabular}{@{}lcccc@{}}", "\\toprule",
  row("", "\\multicolumn{2}{c}{Drug factions}", "\\multicolumn{2}{c}{Militias}"), "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  row("Share of the nominal vote (pp)", "Entry", "Neighbor placebo", "Entry", "Neighbor placebo"), row("", "(1)", "(2)", "(3)", "(4)"), "\\midrule",
  "\\multicolumn{5}{@{}l}{\\textit{Panel A. State assembly}} \\\\", unlist(lapply(L16, function(z) lin16(z[1], paste0(z[2], "_depest")))),
  "\\addlinespace", "\\multicolumn{5}{@{}l}{\\textit{Panel B. Federal deputies}} \\\\", unlist(lapply(L16, function(z) lin16(z[1], paste0(z[2], "_depfed")))),
  "\\midrule", row("Treated or pseudo-treated stations", int(l16("trafico", "saldo_depest", "tratados")$tratados), int(l16("trafico", "saldo_depest", "placebo")$pseudo_tratados),
                   int(l16("milicia", "saldo_depest", "tratados")$tratados), int(l16("milicia", "saldo_depest", "placebo")$pseudo_tratados)),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} CS-DID estimates on the panel of general elections (2006, 2010, 2014, 2018, 2022), same specification as Table~\\ref{tab:csdid_main}; both offices are elected by open-list proportional representation in a statewide district. Entry is dated by the first general election after the station enters the group's territory (map of the preceding year). Outcomes are shares of the nominal vote going to right-wing and left-wing parties \\citep{colonnelli2025politics} and their difference, in percentage points. The neighbor placebo is built as in Table~\\ref{tab:matrix}. Standard errors in parentheses clustered by 2-km grid cells; Wald $p$-values for the joint pre-trends test in brackets. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(t16, "tab_legislative.tex")

# =============== macros ===============
x <- j15("trafico", "hhi_pref"); put("DifDrugHHI", num(x$dif)); put("DifDrugHHIse", num(x$se_dif)); put("DifDrugHHIp", pfm(x$p_dif))
put("MaxtDrugHHIp", pfm(x$p_maxt)); put("HolmDrugHHIp", pfm(x$p_holm))
x <- j15("trafico", "margin_pref"); put("DrugMargsePP", pp(x$se)); put("DifDrugMargPP", pp(x$dif)); put("DifDrugMargsePP", pp(x$se_dif)); put("DifDrugMargp", pfm(x$p_dif))
put("MaxtDrugMargp", pfm(x$p_maxt)); put("HolmDrugMargp", pfm(x$p_holm))
x <- j15("milicia", "saldo_ver"); put("DifMilBalPP", pp(x$dif)); put("DifMilBalsePP", pp(x$se_dif)); put("DifMilBalp", pfm(x$p_dif))
put("MaxtMilBalp", pfm(x$p_maxt)); put("HolmMilBalp", pfm(x$p_holm)); put("BHMilBalq", num(x$q_bh)); put("MilBalpfull", pfm(x$p))
x <- j15("trafico", "saldo_ver"); put("DrugVerBalPP", pp(x$att)); put("DrugVerBalsePP", pp(x$se)); put("PlacDrugVerBalPP", pp(x$plac))
put("DifDrugVerBalPP", pp(x$dif)); put("DifDrugVerBalsePP", pp(x$se_dif)); put("DifDrugVerBalp", pfm(x$p_dif))
x <- j15("trafico", "hhi_ver"); put("DifDrugVerHHI", num(x$dif)); put("DifDrugVerHHIse", num(x$se_dif)); put("DifDrugVerHHIp", pfm(x$p_dif))
x <- j15("trafico", "margin_ver"); put("DifDrugVerMargp", pfm(x$p_dif))
x <- j15("milicia", "hhi_pref"); put("DifMilHHI", sgnt(x$dif)); put("DifMilHHIse", num(x$se_dif)); put("DifMilHHIp", pfm(x$p_dif))
x <- j15("milicia", "saldo_pref"); put("DifMilPrefBalp", pfm(x$p_dif))
x <- j15("trafico", "saldo_pref"); put("DifDrugPrefBalp", pfm(x$p_dif))
cnt <- function(f, it) pega(W15c, faccao == f & item == it)$valor
for (f in c("milicia", "trafico")) { k <- if (f == "milicia") "Mil" else "Drug"
  put(paste0("N", k, "TreatClus"), int(cnt(f, "clusters_com_tratados")))
  for (z in list(c("Twelve", "2012"), c("Sixteen", "2016"), c("Twenty", "2020"), c("TwentyFour", "2024")))
    put(paste0("N", k, "Coh", z[1]), int(cnt(f, paste0("tratados_coorte_", z[2]))))
  put(paste0(k, "CohTwelvePct"), formatC(100 * cnt(f, "tratados_coorte_2012") / cnt(f, "tratados"), format = "f", digits = 0)) }
x <- l16("milicia", "saldo_depest", "tratados"); put("MilDepEstBalPP", pp(x$att)); put("MilDepEstBalsePP", pp(x$se)); put("MilDepEstBalp", pfm(x$p)); put("MilDepEstBalpre", pfm(x$pre_p))
put("NMilGeral", int(x$tratados))
x <- l16("milicia", "saldo_depest", "placebo"); put("PlacMilDepEstBalPP", pp(x$att)); put("PlacMilDepEstBalp", pfm(x$p))
x <- l16("milicia", "saldo_depfed", "tratados"); put("MilDepFedBalPP", sgnt(100 * x$att, 1)); put("MilDepFedBalsePP", pp(x$se))
x <- l16("trafico", "saldo_depest", "tratados"); put("DrugDepEstBalPP", pp(x$att)); put("DrugDepEstBalsePP", pp(x$se)); put("NDrugGeral", int(x$tratados))
x <- l16("trafico", "saldo_depfed", "tratados"); put("DrugDepFedBalPP", pp(x$att)); put("DrugDepFedBalsePP", pp(x$se)); put("DrugDepFedBalp", pfm(x$p))
# macros de texto adicionais (mesmas fontes das tabelas existentes; só mudam unidade ou formato)
put("DrugTDLeadPP", pp(Wl("trafico", "lider_apt_pref")$att)); put("DrugTDOtherPP", pp(Wl("trafico", "outros_apt_pref")$att))
x <- w8("trafico", "hhi_pref", "b"); put("BaseBDrugHHIse", num(x$se_dyn))
x <- w8("trafico", "margin_pref", "b"); put("BaseBDrugMargPP", pp(x$att_dyn)); put("BaseBDrugMargsePP", pp(x$se_dyn))
x <- w8("milicia", "saldo_ver", "b"); put("BaseBMilBalPP", pp(x$att_dyn)); put("BaseBMilBalsePP", pp(x$se_dyn))
x <- g13("trafico", "hhi_pref"); put("DrugHHIpctEarly", pct(x$att_base_g8, bmt("trafico", "hhi_pref")))
x <- g13("trafico", "margin_pref"); put("GEightDrugMargPP", pp(x$att_base_g8)); put("GFourDynDrugMargPP", pp(x$att_dyn_base_g4))
x <- g13("milicia", "saldo_ver"); put("GEightMilBalPP", pp(x$att_base_g8)); put("GFourDynMilBalPP", pp(x$att_dyn_base_g4))
x <- g13("milicia", "s_dir_ver"); put("GEightMilRightPP", pp(x$att_base_g8)); put("GFourDynMilRightPP", pp(x$att_dyn_base_g4))
put("CurveDrugLo", sgnt(cs("trafico", "hhi_pref")$min_dentro)); put("CurveDrugHi", sgnt(cs("trafico", "hhi_pref")$max_dentro))
put("CurveMilLoPP", pp(cs("milicia", "saldo_ver")$min_dentro)); put("CurveMilHiPP", pp(cs("milicia", "saldo_ver")$max_dentro))
put("MilVerHHIse", num(Wl("milicia", "hhi_ver")$se)); put("DrugVerHHIse", num(Wl("trafico", "hhi_ver")$se))
put("PlacMilHHIse", num(pl("milicia", "hhi_pref")$se)); put("MilPrefBalsePP", pp(Wl("milicia", "saldo_pref")$se))
x <- pega(W05, faccao == "trafico" & outcome == "log_aptos"); put("CompAptosDrug", num(x$att)); put("CompAptosDrugse", num(x$se))
