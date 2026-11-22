# tabelas_fase6.R — renda do entorno, quem ganha e checagens de H2/H3 (W17–W22).
# Chamado por tabelas_figuras.R depois de tabelas_fase5.R e antes de gravar as macros; usa as funções e objetos
# de lá (row, sgn, put, Wl, pl, bl, v3, f3, LAB15, pfm, ...).
# A especificação principal condiciona no município e na renda do entorno (~ mun + lrenda). Aqui ficam:
#   - a tabela que compara a especificação principal com a versão só com município e com renda e densidade (W17 e W15 mun);
#   - as tabelas de quem ganha (receita em percentil e candidatos policiais, W18);
#   - a tabela do recorte por base eleitoral do candidato (apêndice);
#   - as macros dessas comparações.
# Reescreve tab_militia_delivery.tex (o recorte por base do candidato fica em tab_militia_bases.tex, no apêndice).

W17 <- fread(file.path(F3, "W17_covariaveis_censo.csv")); W17b <- fread(file.path(F3, "W17_balanco_renda.csv"))
W15m <- fread(file.path(F3, "W15_matriz_conjunta_mun.csv")); W18 <- fread(file.path(F3, "W18_receita_percentil.csv"))
W19 <- fread(file.path(F3, "W19_entrada_placebo.csv")); W19f <- fread(file.path(F3, "W19_forma_funcional.csv"))   # checagens de H2 e H3 (W19)
d19 <- function(f, y) pega(W19, faccao == f & outcome == y)
f19 <- function(f, y, e, am = "todas as coortes") pega(W19f, faccao == f & outcome == y & espec == e & amostra == am)
c17 <- function(f, y, e) pega(W17, faccao == f & outcome == y & espec == e)
m15 <- function(f, y) pega(W15m, faccao == f & outcome == y)
w18 <- function(f, y, a = "tratados") pega(W18, faccao == f & outcome == y & amostra == a)
# conferências: o W17 com renda é a especificação principal das tabelas (W01); o W17 só com município é o W15 "mun"
for (i in seq_len(nrow(W15m))) { z <- W15m[i]
  stopifnot(abs(c17(z$faccao, z$outcome, "renda")$att - Wl(z$faccao, z$outcome)$att) < 1e-10,
            abs(c17(z$faccao, z$outcome, "renda")$se - Wl(z$faccao, z$outcome)$se) < 1e-10,
            abs(c17(z$faccao, z$outcome, "mun")$att - z$att) < 1e-10) }

# ---------------- Especificação principal comparada com só município e com renda e densidade ----------------
LAB17 <- c(LAB15, comparecimento_taxa = "Turnout")
cel17 <- function(f, y, e) { x <- c17(f, y, e); d <- if (y == "comparecimento_taxa") 4 else 3; c(paste0(sgn(x$att, d), stars(x$p)), par_se(x$se, d)) }
celm <- function(f, y) { if (y == "comparecimento_taxa") return(c("", "")); x <- m15(f, y); c(paste0(sgn(x$dif), stars(x$p_dif)), par_se(x$se_dif)) }
lin17 <- function(f) unlist(lapply(names(LAB17), function(y) { a <- cel17(f, y, "renda"); b <- cel17(f, y, "renda_dens"); d <- cel17(f, y, "mun"); e <- celm(f, y)
  c(row(paste0("\\quad ", LAB17[[y]]), a[1], b[1], d[1], e[1]), row("", a[2], b[2], d[2], e[2])) }))
t17 <- c("\\begin{table}[H]", "\\centering", "\\caption{Entry Effects under Alternative Conditioning Sets}\\label{tab:income}", "\\footnotesize",
  "\\begin{tabular}{@{}lcccc@{}}", "\\toprule",
  row("", "\\multicolumn{2}{c}{Conditional on income}", "\\multicolumn{2}{c}{Municipality only}"), "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  row("", "Main", "$+$ density", "Entry", "Entry $-$ placebo"), row("", "(1)", "(2)", "(3)", "(4)"), "\\midrule",
  "\\multicolumn{5}{@{}l}{\\textit{Panel A. Drug factions}} \\\\", lin17("trafico"), "\\addlinespace",
  "\\multicolumn{5}{@{}l}{\\textit{Panel B. Militias}} \\\\", lin17("milicia"), "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} CS-DID estimates, same sample as Table~\\ref{tab:matrix}. Column (1): main specification, in which the outcome regression conditions on municipality indicators and on the log of neighborhood income (the average nominal monthly income of household heads in the 2010 census tracts within 500 m of the station, with each tract weighted by its population times the share of its area inside the radius). Column (2) adds the log of the population within 500 m. Columns (3) and (4) drop income and condition on municipality indicators alone: column (3) is the entry estimate and column (4) its difference from the neighbor placebo, with the joint standard error of Table~\\ref{tab:matrix}. HHI, margins, and turnout range from 0 to 1; the right-minus-left balance ranges from $-1$ to 1. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(t17, "tab_income.tex")

# ---------------- Corpo: quem ganha após a entrada do tráfico (prefeito) ----------------
# com a diferença entrada − placebo do W19 (confere que a entrada e o placebo do W19 são os da tabela)
lin_g3 <- function(lab, a, b, w, d = 2) { stopifnot(abs(100 * w$att - a$att) < 1e-8, abs(100 * w$plac - b$att) < 1e-8)
  c(row(lab, paste0(sgn(a$att, d), stars(a$p)), paste0(sgn(b$att, d), stars(b$p)), paste0(sgn(100 * w$dif, d), stars(w$p_dif))),
    row("", par_se(a$se, d), par_se(b$se, d), par_se(100 * w$se_dif, d))) }
lin_g <- function(lab, a, b, d = 2) c(row(lab, paste0(sgn(a$att, d), stars(a$p)), paste0(sgn(b$att, d), stars(b$p))), row("", par_se(a$se, d), par_se(b$se, d)))
ppd <- function(x) data.table(att = 100 * x$att, se = 100 * x$se, p = x$p)
tdg <- c("\\begin{table}[H]", "\\centering", "\\caption{Who Gains in Mayoral Races after Drug-Faction Entry}\\label{tab:drug_gains}", "\\footnotesize",
  "\\begin{tabular}{@{}lccc@{}}", "\\toprule", row("", "Drug-faction entry", "Neighbor placebo", "Entry $-$ placebo"), row("", "(1)", "(2)", "(3)"), "\\midrule",
  lin_g3("Vote share of the candidate leading at the station (pp)", ppd(Wl("trafico", "top1_pref")), ppd(pl("trafico", "top1_pref")), d19("trafico", "top1_pref")),
  lin_g3("Vote share of the candidate elected citywide (pp)", ppd(Wl("trafico", "eleito_share_pref")), ppd(pl("trafico", "eleito_share_pref")), d19("trafico", "eleito_share_pref")),
  lin_g3("Campaign-revenue percentile of the station's vote (points)", ppd(w18("trafico", "vw_pctrec_pref")), ppd(w18("trafico", "vw_pctrec_pref", "placebo")), d19("trafico", "vw_pctrec_pref")),
  "\\bottomrule", "\\end{tabular}",
  sprintf("\\tabnotes{\\textit{Notes:} \\emph{Prefeito} races. Column (1): CS-DID estimates of drug-faction entry, same specification as Table~\\ref{tab:csdid_main} ($N=%s$ treated stations). Column (2): neighbor placebo built as in Table~\\ref{tab:matrix} ($N=%s$ pseudo-treated stations). Column (3): difference between the entry estimate and the placebo, with the joint standard error of Table~\\ref{tab:matrix}. The campaign-revenue percentile of the station's vote is the average, weighted by the station's votes, of each candidate's percentile in the ranking of that municipality's mayoral candidates by financial campaign revenue in that election (0 to 100; in-kind donations excluded); candidates without a campaign-finance record are left out of the ranking and of the average. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
          int(Ntr("trafico")), int(pl("trafico", "top1_pref")$pseudo_tratados)), "\\end{table}")
escreve(tdg, "tab_drug_gains.tex")

# ---------------- Corpo: quem ganha após a entrada da milícia (vereador) ----------------
blp <- function(y) { z <- bl("milicia", y); data.table(att = 100 * z$att, se = 100 * z$se, p = z$p) }
v3p <- function(y) { z <- v3("milicia", y); data.table(att = 100 * z$att_group, se = 100 * z$se_group, p = z$p_group) }
plp <- function(y) { z <- pl("milicia", y); data.table(att = 100 * z$att, se = 100 * z$se, p = z$p) }
stopifnot(abs(w18("milicia", "dir_pol_ver")$att - bl("milicia", "dir_pol_ver")$att) < 1e-10,
          abs(w18("milicia", "dir_nao_pol_ver", "placebo")$att - pl("milicia", "dir_nao_pol_ver")$att) < 1e-10)
tmd2 <- c("\\begin{table}[H]", "\\centering", "\\caption{Who Gains in City-Council Races after Militia Entry}\\label{tab:militia_delivery}",
  "\\footnotesize", "\\begin{tabular}{@{}lccc@{}}", "\\toprule", row("", "Militia entry", "Neighbor placebo", "Entry $-$ placebo"), row("", "(1)", "(2)", "(3)"), "\\midrule",
  "\\multicolumn{4}{@{}l}{\\textit{Share of the council nominal vote (pp)}} \\\\",
  lin_g3("\\quad Right-wing parties", v3p("s_dir_ver"), plp("s_dir_ver"), d19("milicia", "s_dir_ver")), lin_g3("\\quad Left-wing parties", v3p("s_esq_ver"), plp("s_esq_ver"), d19("milicia", "s_esq_ver")),
  lin_g3("\\quad Small right-wing parties", blp("dir_outras_ver"), plp("dir_outras_ver"), d19("milicia", "dir_outras_ver")),
  lin_g3("\\quad Right-wing candidates with a police or military occupation", blp("dir_pol_ver"), ppd(w18("milicia", "dir_pol_ver", "placebo")), d19("milicia", "dir_pol_ver")),
  lin_g3("\\quad Right-wing candidates without one", blp("dir_nao_pol_ver"), plp("dir_nao_pol_ver"), d19("milicia", "dir_nao_pol_ver")),
  lin_g3("\\quad Top-quartile fundraisers", ppd(f3(W12, "milicia", "s_q4rec_ver")), ppd(f3(W12, "milicia", "s_q4rec_ver", "placebo")), d19("milicia", "s_q4rec_ver")),
  "\\addlinespace", lin_g3("Campaign-revenue percentile of the station's vote (points)", ppd(w18("milicia", "vw_pctrec_ver")), ppd(w18("milicia", "vw_pctrec_ver", "placebo")), d19("milicia", "vw_pctrec_ver")),
  "\\bottomrule", "\\end{tabular}",
  sprintf("\\tabnotes{\\textit{Notes:} \\emph{Vereador} races. Column (1): CS-DID estimates of militia entry, same specification as Table~\\ref{tab:csdid_main} ($N=%s$ treated stations). Column (2): neighbor placebo built as in Table~\\ref{tab:matrix} ($N=%s$ pseudo-treated stations). Column (3): difference between the entry estimate and the placebo, with the joint standard error of Table~\\ref{tab:matrix}. Small right-wing parties exclude the traditional right, the evangelical right, PL, and PSL. Police or military occupation: candidates who declared their occupation as military police, civil police, retired military, military firefighter, or member of the armed forces. Top-quartile fundraisers: council candidates in the top quarter of financial campaign revenue in the municipality and election. The campaign-revenue percentile is defined as in Table~\\ref{tab:drug_gains}. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
          int(Ntr("milicia")), int(pl("milicia", "saldo_ver")$pseudo_tratados)), "\\end{table}")
escreve(tmd2, "tab_militia_delivery.tex")

# ---------------- Apêndice: base eleitoral dos candidatos ----------------
w11p <- function(y, a = "tratados") ppd(f3(W11b, "milicia", y, a))
tbase <- c("\\begin{table}[H]", "\\centering", "\\caption{Militia Entry and the Location of Candidates' Electoral Bases}\\label{tab:militia_bases}",
  "\\footnotesize", "\\begin{tabular}{@{}lcc@{}}", "\\toprule", row("Share of the council nominal vote (pp)", "Militia entry", "Neighbor placebo"), row("", "(1)", "(2)"), "\\midrule",
  lin_g("Small right-wing parties, candidates based within 3 km", w11p("s_dirout_local"), w11p("s_dirout_local", "placebo")),
  lin_g("Small right-wing parties, candidates based farther away", w11p("s_dirout_naolocal"), w11p("s_dirout_naolocal", "placebo")),
  lin_g("Right-wing candidates based within 3 km", w11p("s_dir_local"), w11p("s_dir_local", "placebo")),
  lin_g("Right-wing candidates based farther away", w11p("s_dir_naolocal"), w11p("s_dir_naolocal", "placebo")),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} \\emph{Vereador} races, same specification and placebo as Table~\\ref{tab:militia_delivery}. A candidate's base is the physical polling station where the candidate received the most votes in the municipality in that election; candidates based within 3 km are those whose base lies within 3 km of the polling station. Because the base is defined by the same election's votes, its location can itself respond to entry. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
  "\\end{table}")
escreve(tbase, "tab_militia_bases.tex")

# ---------------- macros ----------------
# especificação só com município, para a comparação no texto
x <- c17("trafico", "hhi_pref", "mun"); put("MunDrugHHI", num(x$att)); put("MunDrugHHIse", num(x$se)); put("MunDrugHHIp", pfm(x$p))
put("MunDrugHHIpct", pct(x$att, bmt("trafico", "hhi_pref")))
x <- c17("trafico", "margin_pref", "mun"); put("MunDrugMargPP", pp(x$att)); put("MunDrugMargsePP", pp(x$se)); put("MunDrugMargp", pfm(x$p))
x <- c17("trafico", "saldo_pref", "mun"); put("MunDrugPrefBalPP", sgnt(100 * x$att, 1)); put("MunDrugPrefBalsePP", pp(x$se)); put("MunDrugPrefBalp", pfm(x$p))
x <- c17("trafico", "hhi_ver", "mun"); put("MunDrugVerHHI", num(x$att))
x <- c17("milicia", "saldo_ver", "mun"); put("MunMilBalPP", pp(x$att)); put("MunMilBalsePP", pp(x$se)); put("MunMilBalp", pfm(x$p))
x <- c17("milicia", "saldo_pref", "mun"); put("MunMilPrefBalPP", sgnt(100 * x$att, 1))
x <- m15("trafico", "hhi_pref"); put("MunDifDrugHHI", num(x$dif)); put("MunDifDrugHHIp", pfm(x$p_dif)); put("MunMaxtDrugHHIp", pfm(x$p_maxt)); put("MunBHDrugHHIq", num(x$q_bh))
x <- m15("milicia", "saldo_ver"); put("MunDifMilBalPP", pp(x$dif)); put("MunDifMilBalp", pfm(x$p_dif)); put("MunMaxtMilBalp", pfm(x$p_maxt)); put("MunBHMilBalq", num(x$q_bh))
# com renda e densidade
x <- c17("trafico", "hhi_pref", "renda_dens"); put("IncDensDrugHHI", num(x$att)); put("IncDensDrugHHIp", pfm(x$p))
x <- c17("milicia", "saldo_ver", "renda_dens"); put("IncDensMilBalPP", pp(x$att)); put("IncDensMilBalp", pfm(x$p))
# balanço de renda
bw <- function(f, v) pega(W17b, faccao == f & variavel == v)
x <- bw("trafico", "lrenda"); put("IncGapDrugLog", num(abs(x$dif), 2)); put("IncGapDrugPct", formatC(100 * (1 - exp(x$dif)), format = "f", digits = 0)); put("IncGapDrugp", pfm(x$p))
x <- bw("milicia", "lrenda"); put("IncGapMilLog", num(abs(x$dif), 2)); put("IncGapMilPct", formatC(100 * (1 - exp(x$dif)), format = "f", digits = 0)); put("IncGapMilp", pfm(x$p))
# receita em percentil
x <- w18("trafico", "vw_pctrec_pref"); put("PctRecDrugPP", pp(x$att)); put("PctRecDrugsePP", pp(x$se)); put("PctRecDrugp", pfm(x$p))
put("PctRecDrugBase", formatC(100 * x$media_2008, format = "f", digits = 0))
x <- w18("trafico", "vw_pctrec_pref", "placebo"); put("PlacPctRecDrugPP", pp(x$att))
x <- w18("milicia", "vw_pctrec_ver"); put("PctRecMilPP", pp(x$att)); put("PctRecMilsePP", pp(x$se)); put("PctRecMilp", pfm(x$p))
# faixa do efeito do tráfico no HHI de prefeito entre a especificação principal e as três alternativas
vals <- c(principal = Wl("trafico", "hhi_pref")$att, base_anterior = g13("trafico", "hhi_pref")$att_base_g8, captacao = cap_drug$att_grp, so_municipio = c17("trafico", "hhi_pref", "mun")$att)
put("DrugMinHHI", num(min(vals))); put("DrugMinHHIpct", pct(min(vals), bmt("trafico", "hhi_pref")))
put("DrugMaxHHI", num(max(vals))); put("DrugMaxHHIpct", pct(max(vals), bmt("trafico", "hhi_pref")))
cat("faixa do HHI do tráfico:", paste(names(vals), round(vals, 4), collapse = " | "), "\n")

# ---------------- macros de texto ----------------
put("DrugMargp", pfm(Wl("trafico", "margin_pref")$p))
put("MilHHIpre", pfm(Wl("milicia", "hhi_pref")$pre_p))
put("SpDrugMaxp", pfm(spd$p)); put("SpMilMaxp", pfm(spm$p)); put("SpDrugMaxVar", NOMEV[[spd$variancia]]); put("SpMilMaxVar", NOMEV[[spm$variancia]])
x <- m15("milicia", "hhi_pref"); put("MunMilHHI", num(x$att)); put("MunPlacMilHHI", num(x$plac)); put("MunPlacMilHHIp", pfm(x$p_plac))
x <- pega(W05, faccao == "milicia" & outcome == "fem"); put("CompWomenMilPP", pp(x$att)); put("CompWomenMilp", pfm(x$p))
x <- Wl("trafico", "eleito_share_pref"); put("DrugWinEzeroPP", pp(x$e0)); put("DrugWinEthreePP", pp(W("trafico", "eleito_share_pref")$event[e == 12]$att))
x <- w8("trafico", "hhi_pref", "c"); put("BaseCDrugHHIp", pfm(x$p))
x <- w8("trafico", "hhi_pref", "b"); put("BaseBDrugHHIp", pfm(x$p_dyn))
x <- w8("milicia", "saldo_ver", "b"); put("BaseBMilBalp", pfm(x$p_dyn))
x <- g13("trafico", "hhi_pref"); put("GFourDynDrugHHIp", pfm(x$p_dyn_base_g4)); put("GEightDrugValep", pfm(2 * pnorm(-abs(x$vale / x$se_vale))))
x <- g13("milicia", "saldo_ver"); put("GFourDynMilBalp", pfm(x$p_dyn_base_g4))
x <- b9("trafico", "hhi_pref", 250); put("BufDrugTwop", pfm(x$p)); x <- b9("trafico", "hhi_pref", 500); put("BufDrugFivep", pfm(x$p))
put("CapDrugp", pfm(2 * pnorm(-abs(cap_drug$att_grp / cap_drug$se_grp)))); put("CapMilp", pfm(cap_mil$p_group))
put("MilBalCapsePP", pp(cap_mil$se_group))
x <- pega(fread(file.path(F3, "W02_honestdid_breakdown.csv")), faccao == "milicia" & outcome == "saldo_ver" & versao == "plano")
put("HDMilLo", num(x$ic_lb)); put("HDMilHi", num(x$ic_ub))
x <- pega(fread(file.path(F3, "W02_honestdid_breakdown.csv")), faccao == "trafico" & outcome == "hhi_pref" & versao == "plano")
put("HDDrugLo", sgnt(x$ic_lb)); put("HDDrugHi", num(x$ic_ub)); put("HDDrugAvg", num(x$alvo))
x <- j15("trafico", "hhi_pref"); put("BHDrugHHIq", num(x$q_bh))
put("HDMilNoSixteen", num(W08h[faccao == "milicia" & outcome == "saldo_ver" & versao == "sem e=-16"]$mbar_rm, 1))
# H2 prevê quem ganha também no voto para vereador; macros do teste no tráfico
x <- Wl("trafico", "eleito_share_ver"); put("DrugVerWinPP", pp(x$att)); put("DrugVerWinsePP", pp(x$se))
x <- f3(W12, "trafico", "s_q4rec_ver"); put("DrugVerQFourPP", pp(x$att)); put("DrugVerQFoursePP", pp(x$se))
x <- w18("trafico", "vw_pctrec_ver"); put("PctRecDrugVerPP", sgnt(100 * x$att, 1)); put("PctRecDrugVersePP", pp(x$se))
# ---------------- macros das checagens de H2 e H3 ----------------
pp2 <- function(x) formatC(100 * abs(x), format = "f", digits = 2)
x <- d19("trafico", "eleito_share_pref"); put("DifDrugWinPP", pp(x$dif)); put("DifDrugWinsePP", pp(x$se_dif)); put("DifDrugWinp", pfm(x$p_dif))
x <- d19("trafico", "vw_pctrec_pref"); put("DifPctRecDrugPP", pp(x$dif)); put("DifPctRecDrugsePP", pp(x$se_dif)); put("DifPctRecDrugp", pfm(x$p_dif))
x <- d19("milicia", "s_dir_ver"); put("DifMilRightPP", pp(x$dif)); put("DifMilRightp", pfm(x$p_dif))
x <- d19("milicia", "dir_outras_ver"); put("DifMilSmallRightPP", pp(x$dif)); put("DifMilSmallRightp", pfm(x$p_dif))
x <- d19("milicia", "dir_nao_pol_ver"); put("DifMilNonPolPP", pp(x$dif)); put("DifMilNonPolp", pfm(x$p_dif))
# forma funcional da renda e coortes de 2016-2024 (para as quais o Censo de 2010 é anterior à entrada)
x <- f19("trafico", "hhi_pref", "quadratica"); put("QuadDrugHHI", num(x$att)); put("QuadDrugHHIp", pfm(x$p))
x <- f19("trafico", "hhi_pref", "quartis"); put("QuartDrugHHI", num(x$att)); put("QuartDrugHHIp", pfm(x$p))
x <- f19("trafico", "hhi_pref", "linear", "coortes 2016-2024"); put("LateDrugHHI", num(x$att)); put("LateDrugHHIse", num(x$se)); put("LateDrugHHIp", pfm(x$p)); put("NDrugLate", int(x$tratados))
x <- f19("trafico", "eleito_share_pref", "quadratica"); put("QuadDrugWinPP", pp(x$att)); x <- f19("trafico", "eleito_share_pref", "quartis"); put("QuartDrugWinPP", pp(x$att))
x <- f19("trafico", "eleito_share_pref", "linear", "coortes 2016-2024"); put("LateDrugWinPP", pp(x$att)); put("LateDrugWinp", pfm(x$p))
x <- f19("trafico", "vw_pctrec_pref", "quadratica"); put("QuadPctRecDrugPP", pp(x$att)); x <- f19("trafico", "vw_pctrec_pref", "quartis"); put("QuartPctRecDrugPP", pp(x$att))
x <- f19("trafico", "vw_pctrec_pref", "linear", "coortes 2016-2024"); put("LatePctRecDrugPP", pp(x$att)); put("LatePctRecDrugp", pfm(x$p))
x <- f19("milicia", "saldo_ver", "quadratica"); put("QuadMilBalPP", pp(x$att)); x <- f19("milicia", "saldo_ver", "quartis"); put("QuartMilBalPP", pp(x$att))
x <- f19("milicia", "saldo_ver", "linear", "coortes 2016-2024"); put("LateMilBalPP", pp(x$att)); put("LateMilBalsePP", pp(x$se)); put("LateMilBalp", pfm(x$p)); put("NMilLate", int(x$tratados))
# o W19 linear com todas as coortes é a especificação principal
stopifnot(abs(f19("trafico", "hhi_pref", "linear")$att - Wl("trafico", "hhi_pref")$att) < 1e-10, abs(f19("milicia", "saldo_ver", "linear")$att - Wl("milicia", "saldo_ver")$att) < 1e-10)
# comparecimento em pontos percentuais, com duas casas, e efeito mínimo detectável
x <- Wl("trafico", "comparecimento_taxa"); put("DrugTurnPP", sgnt(100 * x$att, 2)); put("DrugTurnsePP", pp2(x$se)); put("DrugTurnMDEPP", pp(2.8 * x$se))
x <- Wl("milicia", "comparecimento_taxa"); put("MilTurnPP", sgnt(100 * x$att, 2)); put("MilTurnsePP", pp2(x$se)); put("MilTurnMDEPP", pp(2.8 * x$se))
# PL e PSL no voto para vereador após a entrada do tráfico
x <- bl("trafico", "dir_pl_psl_ver"); put("DrugVerPLPP", pp(x$att)); put("DrugVerPLsePP", pp(x$se)); put("DrugVerPLp", pfm(x$p))
# ---------------- macros das checagens de H2 e H3 (continuação) ----------------
W20 <- fread(file.path(F3, "W20_h2_exposicao.csv")); W21 <- fread(file.path(F3, "W21_clausula_h2.csv")); W21a <- fread(file.path(F3, "W21_alinhados.csv"))
e20 <- function(v, y) pega(W20, versao == v & outcome == y)
stopifnot(abs(e20("principal", "eleito_share_pref")$att - Wl("trafico", "eleito_share_pref")$att) < 1e-10,
          abs(e20("captacao", "hhi_pref")$att - cap_drug$att_grp) < 1e-10, abs(e20("raio_250", "hhi_pref")$att - b9("trafico", "hhi_pref", 250)$att) < 1e-10,
          abs(e20("influencia", "hhi_pref")$att - b14("trafico", "hhi_pref")$att) < 1e-10)
for (z in list(c("Cap", "captacao"), c("Infl", "influencia"), c("BufTwo", "raio_250"), c("BufFive", "raio_500"))) {
  x <- e20(z[2], "eleito_share_pref"); put(paste0(z[1], "DrugWinPP"), pp(x$att)); put(paste0(z[1], "DrugWinp"), pfm(x$p))
  x <- e20(z[2], "vw_pctrec_pref"); put(paste0(z[1], "PctRecDrugPP"), pp(x$att)); put(paste0(z[1], "PctRecDrugp"), pfm(x$p)) }
# voto no eleito nas duas bases, coortes de 2016-2024 (W08)
x <- w8("trafico", "eleito_share_pref", "b"); put("BaseBDrugWinPP", pp(x$att_dyn)); put("BaseBDrugWinsePP", pp(x$se_dyn))
x <- w8("trafico", "eleito_share_pref", "c"); put("BaseCDrugWinPP", pp(x$att)); put("BaseCDrugWinsePP", pp(x$se)); put("BaseCDrugWinp", pfm(x$p))
x <- w8("milicia", "saldo_ver", "c"); put("BaseCMilBalPP", pp(x$att)); put("BaseCMilBalsePP", pp(x$se))
# igualdade entre os grupos no voto do eleito e no percentil de receita (prefeito)
x <- eq("eleito_share_pref"); put("EqWinp", pfm(x$p)); put("MilWinPP", pp(Wl("milicia", "eleito_share_pref")$att)); put("MilWinp", pfm(Wl("milicia", "eleito_share_pref")$p))
a <- w18("milicia", "vw_pctrec_pref"); b <- w18("trafico", "vw_pctrec_pref")
put("EqPctRecp", pfm(2 * pnorm(-abs((a$att - b$att) / sqrt(a$se^2 + b$se^2))))); put("PctRecMilPrefPP", pp(a$att)); put("PctRecMilPrefp", pfm(a$p))
# locais em que o eleito na cidade já liderava no local na eleição anterior à entrada (W21)
put("NDrugAligned", int(W21a$alinhados)); put("NDrugNotAligned", int(W21a$tratados - W21a$alinhados)); put("NDrugAlignedBase", int(W21a$tratados))
put("AlignedDrugHHI", num(pega(W21, alinhado == TRUE & outcome == "hhi_pref")$att)); put("NotAlignedDrugHHI", num(pega(W21, alinhado == FALSE & outcome == "hhi_pref")$att))
# variação do HHI implicada por um ganho do tamanho estimado para o candidato que lidera, tirado dos demais em proporção
s1 <- bmt("trafico", "top1_pref"); h0 <- bmt("trafico", "hhi_pref"); dl <- Wl("trafico", "eleito_share_pref")$att
put("ImpliedDrugHHI", num((s1 + dl)^2 + (h0 - s1^2) * ((1 - s1 - dl) / (1 - s1))^2 - h0)); put("BaseDrugTopPct", formatC(100 * s1, format = "f", digits = 0))
# fatias de base dos candidatos de direita com e sem ocupação policial ou militar (média da amostra em 2008)
put("PolBaseMilPct", formatC(100 * w18("milicia", "dir_pol_ver")$media_2008, format = "f", digits = 1))
put("NonPolBaseMilPct", formatC(100 * w18("milicia", "dir_nao_pol_ver")$media_2008, format = "f", digits = 1))
# menor p de pré-tendência entre os desfechos das duas tabelas de quem ganha
put("MinPreDrugGains", num(min(W19[faccao == "trafico" & outcome %in% c("top1_pref", "eleito_share_pref", "vw_pctrec_pref")]$pre_p), 2))
put("MinPreMilGains", num(min(W19[faccao == "milicia" & outcome != "saldo_ver"]$pre_p), 2))
put("BalTrendDrugMargPP", pp(pega(W07, faccao == "trafico" & outcome == "margin_pref")$tend_0812_dif))
# o texto cita um único valor ajustado para os dois resultados principais: confere que são iguais
stopifnot(mac[["BHMilBalq"]] == mac[["BHDrugHHIq"]], mac[["MaxtMilBalp"]] == mac[["MaxtDrugHHIp"]])
put("EqVerHHIp", pfm(eq("hhi_ver")$p))   # os grupos diferem na concentração do voto para vereador
# ---------------- sensibilidade do percentil de receita aos candidatos sem prestação de contas (W22) ----------------
W22 <- fread(file.path(F3, "W22_receita_sensibilidade.csv")); W22c <- fread(file.path(F3, "W22_contagens.csv"))
s22 <- function(v) pega(W22, versao == v); c22 <- function(it) pega(W22c, item == it)$valor
stopifnot(abs(s22("principal")$att - w18("trafico", "vw_pctrec_pref")$att) < 1e-10)
x <- s22("zero"); put("PctRecZeroPP", pp(x$att)); put("PctRecZerop", pfm(x$p))
x <- s22("sem_mun"); put("PctRecDropPP", pp(x$att)); put("PctRecDropsePP", pp(x$se)); put("PctRecDropp", pfm(x$p)); put("NDrugPctRecDrop", int(x$tratados))
put("NCandNoRec", int(c22("candidato_eleicao_sem_registro"))); put("NMunElNoRec", int(c22("municipio_eleicao_com_sem_registro_10pct"))); put("NMunPctRecDrop", int(c22("municipios_fora")))
put("LinkTreatPct", formatC(100 * c22("voto_ligado_2020_tratados"), format = "f", digits = 0)); put("LinkCompPct", formatC(100 * c22("voto_ligado_2020_comparacao"), format = "f", digits = 0))
