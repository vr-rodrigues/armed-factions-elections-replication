# tabelas_figuras.R — gera as tabelas (.tex), figuras (.pdf) e os números citados no texto (tables/numbers.tex) de
# "Armed Factions and Local Electoral Competition".
# Nenhum número do texto ou das tabelas é digitado à mão: tudo sai dos resultados salvos.
# Insumos: fase1/resultados (F01, F02), fase2/resultados (V01–V04), fase3/resultados (W01–W03), saídas do pipeline v2 e da extensão.
# Uso (de qualquer pasta): Rscript paper_v2/R/tabelas_figuras.R
AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(ggplot2); library(sf) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); PDIR <- normalizePath(file.path(dirname(normalizePath(.f)), ".."))
RV <- normalizePath(file.path(PDIR, ".."))
F1 <- file.path(RV, "fase1", "resultados"); F2 <- file.path(RV, "fase2", "resultados"); F3 <- file.path(RV, "fase3", "resultados")
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
MAPS <- file.path(AFE_DADOS, "mapas_anuais")
TAB <- file.path(PDIR, "tables"); FIG <- file.path(PDIR, "figures")
dir.create(TAB, showWarnings = FALSE); dir.create(FIG, showWarnings = FALSE)
sf_use_s2(FALSE)

# ---------------- dispositivo das figuras ----------------
# O pdf() padrão desenha todo hífen como sinal de menos ("Right−wing"). Com cairo_pdf o hífen sai certo; os números
# negativos dos eixos recebem o sinal de menos (U+2212) pela mesma formatação padrão do ggplot. O ggplot procura as escalas
# padrão neste ambiente, então as redefinições abaixo valem também para eixos sem escala explícita (e para tabelas_fase3.R).
ggsave <- function(..., device = cairo_pdf) ggplot2::ggsave(..., device = device)
lab_menos <- function(x) gsub("-", "−", format(x, trim = TRUE, justify = "left"), fixed = TRUE)
scale_x_continuous <- function(..., labels = lab_menos) ggplot2::scale_x_continuous(..., labels = labels)
scale_y_continuous <- function(..., labels = lab_menos) ggplot2::scale_y_continuous(..., labels = labels)

# ---------------- formatação ----------------
num <- function(x, d = 3) ifelse(is.na(x), "", formatC(x, format = "f", digits = d))
sgn <- function(x, d = 3) ifelse(is.na(x), "", paste0(ifelse(round(x, d) < 0, "$-$", "$+$"), formatC(abs(x), format = "f", digits = d)))   # zero arredondado sem sinal de menos
sgnt <- function(x, d = 3) ifelse(is.na(x), "", paste0(ifelse(round(x, d) < 0, "$-$", ""), formatC(abs(x), format = "f", digits = d)))  # texto, sem "+"  # texto, sem "+"
stars <- function(p) ifelse(is.na(p), "", ifelse(p < 0.01, "$^{***}$", ifelse(p < 0.05, "$^{**}$", ifelse(p < 0.10, "$^{*}$", ""))))
pv <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "$<$0.001", formatC(p, format = "f", digits = 3)))
br <- function(p) paste0("[", pv(p), "]")
int <- function(x) formatC(x, format = "d", big.mark = ",")
row <- function(...) paste0(paste(c(...), collapse = " & "), " \\\\")
par_se <- function(se, d = 3) paste0("(", num(se, d), ")")
escreve <- function(linhas, nome) { writeLines(linhas, file.path(TAB, nome)); cat("tabela:", nome, "\n") }
pega <- function(D, cond) { k <- eval(substitute(cond), D, parent.frame()); x <- D[which(k)]; if (nrow(x) != 1) stop("pega: ", nrow(x), " linhas"); x }
pc <- function(x) paste0(formatC(100 * x, format = "f", digits = 0), "\\%")

# ---------------- insumos ----------------
RDS <- file.path(F3, "rds")
W <- function(f, y, s = "a") readRDS(file.path(RDS, sprintf("W01_%s_%s_%s.rds", f, s, y)))
Wl <- function(f, y, s = "a") W(f, y, s)$linha
R2 <- fread(file.path(F1, "F02_todas_estimativas.csv"))
V3 <- fread(file.path(F2, "V03_todas_estimativas.csv"))[amostra == "a"]
BL <- fread(file.path(F2, "V04_blocos.csv")); PL <- rbind(fread(file.path(F2, "V04_placebo.csv")), fread(file.path(F3, "W03_placebo.csv")))
RI <- fread(file.path(F2, "V04_ri_resumo.csv")); CS <- fread(file.path(F2, "V02_resumo.csv"))
CR <- rbindlist(lapply(list.files(file.path(F2, "curva"), "^V02_.*[.]csv$", full.names = TRUE), fread), fill = TRUE)
HB <- fread(file.path(F3, "W02_honestdid_breakdown.csv")); HC <- fread(file.path(F3, "W02_honestdid_curvas.csv"))
v3 <- function(f, y, tr = "ponto") pega(V3, painel == "mun" & faccao == f & tratamento == tr & outcome == y)
bl <- function(f, y, tr = "ponto") pega(BL, faccao == f & tratamento == tr & outcome == y)
pl <- function(f, y) pega(PL, faccao == f & outcome == y)
# fase 3: beneficiários (W10), candidatos locais (W11), finanças (W12)
W10 <- fread(file.path(F3, "W10_beneficiarios.csv")); W12 <- fread(file.path(F3, "W12_financas.csv"))
W11a <- fread(file.path(F3, "W11_candidatos_locais.csv")); W11b <- fread(file.path(F3, "W11_candidatos_locais_3000m.csv"))
f3 <- function(D, f, y, a = "tratados") { z <- pega(D, faccao == f & amostra == a & outcome == y); data.table(att = z$att, se = z$se, p = z$p) }

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "w00_outcomes_paper")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
}
PG <- as.data.table(read_parquet(file.path(SNAP, "painel_geral.parquet")))[versao == "principal"]
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
PL0 <- as.data.table(read_parquet(file.path(SNAP, "places.parquet")))
amostra <- function(P, f) P[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
base_mean <- function(P, f, yv) { d <- amostra(P, f); d <- d[ano == min(ano) & g == 0]; d <- d[!is.na(d[[yv]])]; weighted.mean(d[[yv]], d$peso) }
NM <- c(milicia = "Militia", trafico = "Drug Factions")
Ntr <- function(f) Wl(f, "hhi_pref")$tratados

# =============== Tabela 2: linhas de base pré-tratamento ===============
bal <- PM[balanceado == TRUE]
grupos <- list(nunca = bal[nunca_tratado == TRUE],
               milicia = amostra(PM, "milicia")[g > 0 & ano < g],
               trafico = amostra(PM, "trafico")[g > 0 & ano < g])
ms <- function(d, v, dg = 3) { z <- d[[v]]; z <- z[!is.na(z)]; paste0(formatC(mean(z), format = "f", digits = dg), " (", formatC(sd(z), format = "f", digits = dg), ")") }
lin_b <- function(lab, v, dg = 3) row(lab, sapply(grupos, ms, v = v, dg = dg))
nloc <- sapply(grupos, function(d) int(uniqueN(d$place_id)))
tb <- c("\\begin{table}[H]", "\\centering", "\\caption{Descriptive Statistics: Pre-Treatment Baselines}\\label{tab:sumstats}", "\\scriptsize",
  "\\begin{tabular}{@{}lccc@{}}", "\\toprule", row("", "Never treated", "Militia (pre)", "Drug (pre)"), "\\midrule",
  "\\multicolumn{4}{@{}l}{\\textit{Panel A: Prefeito (mayoral) races}} \\\\", row("$N$ polling stations", nloc),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Electoral competition}} \\\\",
  lin_b("HHI", "hhi_pref"), lin_b("ENC", "enc_pref", 2), lin_b("Margin of victory", "margin_pref"),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Participation}} \\\\", lin_b("Turnout", "comparecimento_taxa"),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Candidate selection}} \\\\",
  lin_b("Winning candidate vote share", "eleito_share_pref"), lin_b("Competitive candidates at 1 pp", "ncomp1_pref", 2),
  lin_b("Top candidate vote share", "top1_pref"), lin_b("Top-3 candidates vote share", "top3_pref"), lin_b("Public-admin occupation share", "pubadm_share_pref"),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Partisan composition}} \\\\",
  lin_b("Right-wing vote share", "s_dir_pref"), lin_b("Left-wing vote share", "s_esq_pref"),
  "\\addlinespace[4pt]", "\\multicolumn{4}{@{}l}{\\textit{Panel B: Vereador (city-council) races}} \\\\", row("$N$ polling stations", nloc),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Electoral competition}} \\\\",
  lin_b("HHI", "hhi_ver"), lin_b("ENC", "enc_ver", 2), lin_b("Margin of victory", "margin_ver"),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Candidate selection}} \\\\",
  lin_b("Winning candidate vote share", "eleito_share_ver"), lin_b("Competitive candidates at 1 pp", "ncomp1_ver", 2),
  lin_b("Top candidate vote share", "top1_ver"), lin_b("Top-3 candidates vote share", "top3_ver"), lin_b("Public-admin occupation share", "pubadm_share_ver"),
  "\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{Partisan composition}} \\\\",
  lin_b("Right-wing vote share", "s_dir_ver"), lin_b("Left-wing vote share", "s_esq_ver"), lin_b("Right-minus-left balance", "saldo_ver"),
  "\\bottomrule", "\\end{tabular}",
  "\\tabnotes{\\textit{Notes:} Cells report means and standard deviations in parentheses, computed over baseline observations of the balanced panel of physical polling stations. For militia and drug-treated stations, the baseline sample restricts to station-election observations before the first election after the station enters faction territory, among the treated stations of the main estimation sample (1-km frontier). Never-treated stations are all balanced-panel stations that never fall inside any annual control polygon from 2007 to 2024, in all five municipal elections. Vote shares are computed on nominal votes, excluding blank, null, and party-label votes. Parties are classified as right, center, or left following \\citet{colonnelli2025politics}. Vote shares, turnout, HHI, and the margin of victory are reported on the 0--1 scale. Outcomes are defined in Table~\\ref{tab:outcomes}.}",
  "\\end{table}")
escreve(tb, "tab83_sumstats_baseline.tex")

# =============== Tabelas 3 e 8: CS-DID principal, prefeito e vereador ===============
cel <- function(x, d = 3) paste0(sgn(x$att, d), stars(x$p))
dig <- function(y) ifelse(y == "comparecimento_taxa", 4, 3)   # comparecimento com quatro casas
tab_main <- function(ys, labs, cap, lab, nota, s = "a") {
  k <- length(ys)
  L <- lapply(c("trafico", "milicia"), function(f) lapply(ys, function(y) Wl(f, y, s)))   # tráfico primeiro, como na matriz
  c("\\begin{table}[H]", "\\centering", sprintf("\\caption{%s}\\label{%s}", cap, lab), "\\footnotesize",
    sprintf("\\begin{tabular}{@{}l %s %s@{}}", strrep("c", k), strrep("c", k)), "\\toprule",
    row("", sprintf("\\multicolumn{%d}{c}{Drug factions ($N = %s$)}", k, int(L[[1]][[1]]$tratados)),
        sprintf("\\multicolumn{%d}{c}{Militias ($N = %s$)}", k, int(L[[2]][[1]]$tratados))),
    sprintf("\\cmidrule(lr){2-%d} \\cmidrule(lr){%d-%d}", k + 1, k + 2, 2 * k + 1),
    row("", labs, labs), "\\midrule",
    row("Inside territory", mapply(cel, L[[1]], dig(ys)), mapply(cel, L[[2]], dig(ys))),
    row("", mapply(function(x, d) par_se(x$se, d), L[[1]], dig(ys)), mapply(function(x, d) par_se(x$se, d), L[[2]], dig(ys))),
    row("Wald $p$", sapply(L[[1]], function(x) br(x$pre_p)), sapply(L[[2]], function(x) br(x$pre_p))),
    "\\bottomrule", "\\end{tabular}", sprintf("\\tabnotes{%s}", nota), "\\end{table}")
}
NOTA_CS <- "\\textit{Notes:} \\citet{callaway2021did} estimator, outcome-regression version with municipality indicators and the log of neighborhood income in the 2010 census, so that each entering station is compared with stations of the same municipality and similar neighborhood income. Each coefficient reports the aggregate $\\widehat{ATT}$ ($\\theta$, average across entry cohorts of the post-entry effects) on the listed outcome from a polling station's entry into a faction territory. Comparison stations are not-yet-treated stations of the same faction type and never-treated stations within 1 km of that faction's territory; stations controlled by the other faction type never serve as controls. %s $N$ is the number of treated polling stations. Standard errors in parentheses clustered by 2-km grid cells, computed from the influence functions. Wald $p$-values for the joint pre-trends test in brackets. Universal base period (the election before entry), balanced panel of physical polling stations, observations weighted by registered voters in the first election. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$."
escreve(tab_main(c("hhi_pref", "enc_pref", "margin_pref", "comparecimento_taxa"), c("HHI", "ENC", "Margin", "Turnout"),
                 "CS-DID: Mayoral Electoral Outcomes", "tab:csdid_main",
                 sprintf(NOTA_CS, "Outcomes are measured on \\emph{prefeito} mayoral races. Turnout is a station-election participation measure, defined as total votes including blank and null divided by registered voters.")),
        "tab_csdid_main.tex")
escreve(tab_main(c("hhi_ver", "enc_ver", "margin_ver"), c("HHI", "ENC", "Margin"),
                 "CS-DID: City-Council (\\emph{Vereador}) Outcomes", "tab:csdid_vereador",
                 sprintf(NOTA_CS, "HHI, ENC, and margin are computed on candidate nominal votes in \\emph{vereador} city-council races.")),
        "tab_csdid_vereador.tex")
escreve(tab_main(c("hhi_pref", "enc_pref", "margin_pref", "comparecimento_taxa"), c("HHI", "ENC", "Margin", "Turnout"),
                 "CS-DID: Mayoral Electoral Outcomes, Broad Control Benchmark", "tab:csdid_main_nt",
                 "\\textit{Notes:} Same estimator and conventions as Table~\\ref{tab:csdid_main}, but the comparison group contains all never-treated stations in the municipalities where the faction enters, regardless of distance to the faction's territory, together with not-yet-treated stations of the same faction type. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.", s = "c"),
        "tab_csdid_main_nt.tex")
escreve(tab_main(c("hhi_ver", "enc_ver", "margin_ver"), c("HHI", "ENC", "Margin"),
                 "CS-DID: City-Council (\\emph{Vereador}) Competition, Broad Control Benchmark", "tab:csdid_vereador_nt",
                 "\\textit{Notes:} Broad control benchmark described in Appendix~\\ref{app:nt}. Outcomes on \\emph{vereador} city-council races. Conventions as in Table~\\ref{tab:csdid_main_nt}. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.", s = "c"),
        "tab_csdid_vereador_nt.tex")

# =============== Tabela 4: decomposição do comparecimento (prefeito) ===============
td <- list(c("Total turnout", "comparecimento_taxa"), c("Votes for the candidate leading at the station", "lider_apt_pref"),
           c("Votes for the other candidates", "outros_apt_pref"), c("Blank and null votes", "bn_apt_pref"))
tt <- c("\\begin{table}[H]", "\\centering", "\\caption{Turnout Decomposition in Mayoral Races}\\label{tab:turnout_decomp}", "\\footnotesize",
        "\\begin{tabular}{@{}lcc@{}}", "\\toprule", row("", "Drug factions", "Militias"), "\\midrule",
        unlist(lapply(td, function(z) { a <- Wl("trafico", z[2]); b <- Wl("milicia", z[2])
          c(row(z[1], cel(a, 4), cel(b, 4)), row("", par_se(a$se, 4), par_se(b$se, 4))) })),
        "\\bottomrule", "\\end{tabular}",
        sprintf("\\tabnotes{\\textit{Notes:} CS-DID estimates for \\emph{prefeito} races, same specification as Table~\\ref{tab:csdid_main}. Each outcome is measured per registered voter of the election year. Votes for the candidate leading at the station are votes for the candidate with the highest vote share at the polling station. Votes for the other candidates aggregate all remaining candidates. Mayoral races have no party-label votes, so the three components sum exactly to total turnout. Standard errors in parentheses clustered by 2-km grid cells. $N=%s$ militia-treated polling stations and $N=%s$ drug-trafficking-faction-treated polling stations. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}", int(Ntr("milicia")), int(Ntr("trafico"))),
        "\\end{table}")
escreve(tt, "tab_turnout_decomp.tex")

# =============== Tabela 5: duração da exposição (e = 0 e e = +4) ===============
dur <- list(c("HHI", "hhi_pref"), c("ENC", "enc_pref"), c("Margin of victory", "margin_pref"), c("Turnout", "comparecimento_taxa"))
pz <- function(b, se) 2 * pnorm(-abs(b / se))
lin_dur <- function(f) unlist(lapply(seq_along(dur), function(i) { x <- Wl(f, dur[[i]][2])
  c(row(if (i == 1) c(Militia = "Militia", Drug = "Drug")[[if (f == "milicia") 1 else 2]] else "", dur[[i]][1],
        paste0(sgn(x$e0), stars(pz(x$e0, x$se_e0))), paste0(sgn(x$e4), stars(pz(x$e4, x$se_e4))), paste0(sgn(x$dif_e4_e0), stars(pz(x$dif_e4_e0, x$se_dif)))),
    row("", "", par_se(x$se_e0), par_se(x$se_e4), par_se(x$se_dif))) }))
tdur <- c("\\begin{table}[H]", "\\centering", "\\caption{Exposure Duration in Mayoral Races}\\label{tab:duration}", "\\footnotesize",
          "\\begin{tabular}{@{}llccc@{}}", "\\toprule", row("Faction", "Outcome", "Entry election", "One cycle later", "Later minus entry"), "\\midrule",
          lin_dur("milicia"), "\\midrule", lin_dur("trafico"), "\\bottomrule", "\\end{tabular}",
          sprintf("\\tabnotes{\\textit{Notes:} CS-DID event-study estimates for \\emph{prefeito} races, same specification as Table~\\ref{tab:csdid_main}. Entry election is event time $e=0$. One cycle later is event time $e=+4$ years. The final column reports the difference between the two dynamic effects, with its standard error computed from the clustered covariance of the event-study influence functions. Standard errors in parentheses. $N=%s$ militia-treated polling stations and $N=%s$ drug-trafficking-faction-treated polling stations. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}", int(Ntr("milicia")), int(Ntr("trafico"))),
          "\\end{table}")
escreve(tdur, "tab_duration.tex")

# =============== Tabelas 6 e 10 e Figuras 3 e 5: mecanismos ===============
# coeficientes em pontos percentuais para shares; contagens na unidade original
mec <- function(f, y, fonte, fator) {
  x <- switch(fonte, W = { z <- Wl(f, y); data.table(att = z$att, se = z$se, p = z$p) },
              V3 = { z <- v3(f, y); data.table(att = z$att_group, se = z$se_group, p = z$p_group) },
              BL = { z <- bl(f, y); data.table(att = z$att, se = z$se, p = z$p) },
              W10 = f3(W10, f, y), W12 = f3(W12, f, y), W11 = f3(W11b, f, y))
  x[, `:=`(att = att * fator, se = se * fator)][]
}
MEC_P <- data.table(painel = c(rep("Panel A. Candidate selection", 5), rep("Panel B. Incumbency and campaign revenue", 3), rep("Panel C. Partisan composition", 5)),
  rot = c("Winning candidate vote share (pp)", "Competitive candidates at 1 pp (count)", "Top candidate vote share (pp)",
          "Top-3 candidates vote share (pp)", "Public-admin occupation share (pp)",
          "Sitting mayor running: vote share (pp)", "Top fundraiser: vote share (pp)", "Vote-weighted log campaign revenue (log points)",
          "Right-wing vote share (pp)", "Center vote share (pp)", "Left-wing vote share (pp)",
          "\\quad of which: other left-wing parties (pp)", "Right-minus-left balance (pp)"),
  y = c("eleito_share_pref", "ncomp1_pref", "top1_pref", "top3_pref", "pubadm_share_pref", "s_prefocc", "s_toprec_pref", "vw_logrec_pref",
        "s_dir_pref", "s_cen_pref", "s_esq_pref", "esq_outras_pref", "saldo_pref"),
  fonte = c(rep("W", 5), "W10", "W12", "W12", "V3", "V3", "V3", "BL", "V3"), fator = c(100, 1, 100, 100, 100, 100, 100, 1, 100, 100, 100, 100, 100))
MEC_V <- data.table(painel = c(rep("Panel A. Candidate selection", 5), rep("Panel B. Money", 2), rep("Panel C. Partisan blocs", 12)),
  rot = c("Winning candidate vote share (pp)", "Competitive candidates at 1 pp (count)", "Top candidate vote share (pp)",
          "Top-3 candidates vote share (pp)", "Public-admin occupation share (pp)",
          "Top-quartile fundraisers: vote share (pp)", "Vote-weighted log campaign revenue (log points)",
          "Small right-wing parties (pp)", "Traditional right: PP, DEM, Uni\\~ao (pp)", "Evangelical right: PRB/Republicanos, PSC (pp)", "PL and PSL (pp)",
          "Right, police or military candidates (pp)", "Right, other candidates (pp)",
          "PSOL (pp)", "PT (pp)", "PSB (pp)", "PDT (pp)", "Other left-wing parties (pp)", "Center parties (pp)"),
  y = c("eleito_share_ver", "ncomp1_ver", "top1_ver", "top3_ver", "pubadm_share_ver", "s_q4rec_ver", "vw_logrec_ver",
        paste0(c("dir_outras", "dir_tradicional", "dir_evangelica", "dir_pl_psl", "dir_pol", "dir_nao_pol", "esq_psol", "esq_pt", "esq_psb", "esq_pdt", "esq_outras", "cen"), "_ver")),
  fonte = c(rep("W", 5), "W12", "W12", rep("BL", 12)), fator = c(100, 1, 100, 100, 100, 100, 1, rep(100, 12)))
tab_mec <- function(M, cap, lab, nota) {
  out <- c("\\begin{table}[H]", "\\centering", sprintf("\\caption{%s}\\label{%s}", cap, lab), "\\footnotesize", "\\begin{tabular}{@{}lcc@{}}", "\\toprule",
           row("", sprintf("\\textbf{Militia} ($N = %s$)", int(Ntr("milicia"))), sprintf("\\textbf{Drug Factions} ($N = %s$)", int(Ntr("trafico")))), "\\midrule")
  for (pn in unique(M$painel)) {
    if (pn != M$painel[1]) out <- c(out, "\\midrule")
    out <- c(out, sprintf("\\multicolumn{3}{@{}l}{\\textit{%s}} \\\\", pn))
    for (i in which(M$painel == pn)) {
      a <- mec("milicia", M$y[i], M$fonte[i], M$fator[i]); b <- mec("trafico", M$y[i], M$fonte[i], M$fator[i])
      out <- c(out, row(M$rot[i], paste0(sgn(a$att, 2), stars(a$p)), paste0(sgn(b$att, 2), stars(b$p))), row("", par_se(a$se, 2), par_se(b$se, 2)))
    }
  }
  c(out, "\\bottomrule", "\\end{tabular}", sprintf("\\tabnotes{%s}", nota), "\\end{table}")
}
NOTA_MEC <- "\\textit{Notes:} CS-DID estimates, same specification as Table~\\ref{tab:csdid_main}. Each coefficient is the aggregate ATT after a polling station enters faction territory. %s Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$."
escreve(tab_mec(MEC_P, "Mechanism Outcomes in Mayoral Races", "tab:mechanisms_prefeito",
                sprintf(NOTA_MEC, paste0("Winning candidates are those elected in the municipality (final round). Sitting mayor: candidates who declared their occupation as mayor. Top fundraiser: the candidate with the largest financial campaign revenue in the municipality and election (revenue declared to TSE, excluding in-kind donations); the log-revenue outcome averages $\\log(1+\\text{revenue})$ across candidates weighted by their local vote shares. Party blocs follow \\citet{colonnelli2025politics} (Appendix Table~\\ref{tab:parties}); other left-wing parties are left-wing parties other than PT, PSOL, PDT, and PSB. The winning-candidate outcome excludes the municipality of Itagua\\'{\\i}, where the 2024 winner ran \\emph{sub judice} and has no recorded votes; for that outcome the militia sample has ", int(Wl("milicia", "eleito_share_pref")$tratados), " treated stations."))),
        "tab95_mechanisms_prefeito.tex")
escreve(tab_mec(MEC_V, "Mechanism Outcomes in City-Council Races", "tab:mechanisms_vereador",
                sprintf(NOTA_MEC, "Winning candidates are those elected to the council by the party quotient or by remainders. Panel B: top-quartile fundraisers are council candidates in the top quarter of financial campaign revenue in the municipality and election (excluding in-kind donations); the log-revenue outcome averages $\\log(1+\\text{revenue})$ across candidates weighted by their local vote shares. Panel C reports the share of the council nominal vote going to each bloc; right-wing blocs sum to the right-wing share and left-wing blocs to the left-wing share. Traditional right: PP, DEM (until 2020), and Uni\\~ao Brasil (from 2022). Police or military occupation: candidates who declared their occupation as military police, civil police, retired military, military firefighter, or member of the armed forces.")),
        "tab95_mechanisms_vereador.tex")
fig_mec <- function(M, arq, altura) {
  D <- rbindlist(lapply(seq_len(nrow(M)), function(i) rbind(
    cbind(M[i], faccao = "Militia", mec("milicia", M$y[i], M$fonte[i], M$fator[i])),
    cbind(M[i], faccao = "Drug factions", mec("trafico", M$y[i], M$fonte[i], M$fator[i])))))
  D[, rot := gsub("\\\\quad ", "   ", gsub("\\\\~a", "\u00e3", rot))]
  D[, rot := factor(rot, levels = rev(unique(rot)))]; D[, faccao := factor(faccao, levels = c("Militia", "Drug factions"))]
  g <- ggplot(D, aes(att, rot, colour = faccao, shape = faccao)) + geom_vline(xintercept = 0, colour = "grey55") +
    geom_errorbar(aes(xmin = att - 1.96 * se, xmax = att + 1.96 * se), width = 0, orientation = "y", position = position_dodge(width = 0.55)) +
    geom_point(size = 2.2, position = position_dodge(width = 0.55)) +
    scale_colour_manual(values = c("Militia" = "black", "Drug factions" = "grey50"), name = NULL) +
    scale_shape_manual(values = c("Militia" = 16, "Drug factions" = 17), name = NULL) +
    facet_grid(painel ~ ., scales = "free_y", space = "free_y", labeller = label_wrap_gen(width = 14)) +
    labs(x = "CS-DID ATT (outcome units shown in labels)", y = NULL) +
    theme_minimal(base_size = 9) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
                                         strip.text.y = element_text(angle = 0, hjust = 0, face = "bold"),
                                         strip.background = element_rect(fill = "grey92", colour = NA))
  ggsave(file.path(FIG, arq), g, width = 7, height = altura); cat("figura:", arq, "\n")
}
fig_mec(MEC_P, "fig95_mechanisms_prefeito.pdf", 5.2)
fig_mec(MEC_V, "fig95_mechanisms_vereador.pdf", 7.2)

# =============== Tabela 7: concentração local e identidade partidária (tráfico; tratados x placebo de vizinhança) ===============
CI <- list(
  list("Mayoral HHI", "W", "hhi_pref", 1), list("Margin of victory", "W", "margin_pref", 1),
  list("Top candidate vote share", "W", "top1_pref", 1), list("Votes for the leading candidate per registered voter", "W", "lider_apt_pref", 1),
  list("Winning candidate vote share", "W", "eleito_share_pref", 1),
  list("Other left-wing parties: vote share", "BL", "esq_outras_pref", 1), list("Other left-wing parties: contribution to HHI", "W", "hhi_esq_outras_pref", 1),
  list("Other left-wing parties: local leader's share", "W", "lider_esq_outras_pref", 1), list("Right-minus-left balance", "W", "saldo_pref", 1),
  list("Local leader has a public-admin occupation: leader's share", "W10", "lider_pub", 1),
  list("Sitting mayor running: vote share", "W10", "s_prefocc", 1),
  list("Vote-weighted log campaign revenue", "W12", "vw_logrec_pref", 1))
# placebo: amostra "placebo" de W10/W11/W12 para os desfechos desses scripts; W03/V04 para os demais
plc <- function(f, y, fonte) switch(fonte, W10 = f3(W10, f, y, "placebo"), W12 = f3(W12, f, y, "placebo"), W11 = f3(W11b, f, y, "placebo"),
                                    { z <- pl(f, y); data.table(att = z$att, se = z$se, p = z$p) })
lin_ci <- function(z) {
  a <- mec("trafico", z[[3]], z[[2]], 1); b <- plc("trafico", z[[3]], z[[2]])
  c(row(z[[1]], paste0(sgn(a$att), stars(a$p)), paste0(sgn(b$att), stars(b$p))), row("", par_se(a$se), par_se(b$se)))
}
pl_n <- pl("trafico", "hhi_pref")
tci <- c("\\begin{table}[H]", "\\centering", "\\caption{Local Concentration, Beneficiaries, and Partisan Identity: Drug-Faction Entry and Neighbor Placebo}\\label{tab:concentration_identity}",
         "\\footnotesize", "\\begin{tabular}{@{}lcc@{}}", "\\toprule", row("", "Drug-faction entry", "Neighbor placebo"), row("", "(1)", "(2)"), "\\midrule",
         "\\multicolumn{3}{@{}l}{\\textit{Panel A. Concentration on the leading candidate}} \\\\", unlist(lapply(CI[1:5], lin_ci)), "\\midrule",
         "\\multicolumn{3}{@{}l}{\\textit{Panel B. Who gains: career, incumbency, and campaign revenue}} \\\\", unlist(lapply(CI[10:12], lin_ci)), "\\midrule",
         "\\multicolumn{3}{@{}l}{\\textit{Panel C. Partisan identity of the vote}} \\\\", unlist(lapply(CI[6:9], lin_ci)),
         "\\bottomrule", "\\end{tabular}",
         sprintf("\\tabnotes{\\textit{Notes:} \\emph{Prefeito} races. Column (1): CS-DID estimates of drug-faction entry, same specification as Table~\\ref{tab:csdid_main} ($N=%s$ treated stations). Column (2): neighbor placebo. Never-treated stations within 1 km of a drug-treated station in the same municipality receive that station's entry cohort ($N=%s$ pseudo-treated stations); the comparison group contains never-treated stations more than 1.5 km from any treated station and within 3 km of the drug-faction envelope ($N=%s$). The contribution of a bloc to the HHI is the sum of its candidates' squared vote shares, so the bloc contributions add up to the HHI. The local leader's share for a bloc or type equals the vote share of the candidate leading at the polling station if that candidate belongs to the bloc or type and zero otherwise. Public-admin occupation: declared occupation of elected office or public administration. Sitting mayor: candidates who declared their occupation as mayor. Campaign revenue: financial revenue declared to TSE, excluding in-kind donations; the outcome is the average of $\\log(1+\\text{revenue})$ across candidates weighted by their local vote shares. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
                 int(Ntr("trafico")), int(pl_n$pseudo_tratados), int(pl_n$controles)),
         "\\end{table}")
escreve(tci, "tab_concentration_identity.tex")

# =============== Tabela 9: milícias, composição partidária do voto para vereador ===============
d3 <- list(v3("milicia", "saldo_ver"), v3("milicia", "s_dir_ver"), v3("milicia", "s_esq_ver"),
           v3("milicia", "saldo_ver", "captacao"), v3("milicia", "s_dir_ver", "captacao"), v3("milicia", "s_esq_ver", "captacao"))
bm3 <- rep(c(base_mean(PM, "milicia", "saldo_ver"), base_mean(PM, "milicia", "s_dir_ver"), base_mean(PM, "milicia", "s_esq_ver")), 2)
t3 <- c("\\begin{table}[H]", "\\centering", "\\caption{Militia Entry and the Partisan Composition of the City-Council Vote}\\label{tab:militia_ideology}", "\\footnotesize",
        "\\begin{tabular}{@{}lcccccc@{}}", "\\toprule",
        row("", "\\multicolumn{3}{c}{Station coordinates}", "\\multicolumn{3}{c}{Catchment population}"),
        "\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}",
        row("", "Right $-$ left", "Right share", "Left share", "Right $-$ left", "Right share", "Left share"),
        row("", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)"), "\\midrule",
        row("Inside militia territory", sapply(d3, function(x) paste0(sgn(x$att_group), stars(x$p_group)))),
        row("", sapply(d3, function(x) par_se(x$se_group))),
        row("Wald $p$", sapply(d3, function(x) br(x$wald_pre_p))),
        row("Comparison mean, 2008", sgnt(bm3)),
        row("Treated polling stations", sapply(d3, function(x) int(x$tratados))),
        "\\bottomrule", "\\end{tabular}",
        "\\tabnotes{\\textit{Notes:} CS-DID estimates for \\emph{vereador} races, same specification as Table~\\ref{tab:csdid_main}. Outcomes are shares of the council nominal vote at the polling station going to right-wing and left-wing parties, classified following \\citet{colonnelli2025politics} by party number and year (Appendix Table~\\ref{tab:parties}), and their difference. Columns 1--3 assign treatment by the station's coordinates. Columns 4--6 assign treatment by the share of the 2010 census population of the station's Voronoi catchment living inside militia territory (at least one half). The comparison mean is the registered-voter-weighted mean in 2008 among the comparison stations of the coordinate-based sample, in all columns. Standard errors in parentheses clustered by 2-km grid cells; Wald $p$-values for the joint pre-trends test in brackets. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
        "\\end{table}")
escreve(t3, "tab_militia_ideology.tex")

# =============== Tabela 11: robustez dos dois resultados ===============
cs <- function(f, y) pega(CS, faccao_alvo == f & outcome == y)
ri <- function(f, y, v) pega(RI, faccao == f & outcome == y & versao_ri == v)
cap_drug <- pega(CR, faccao_alvo == "trafico" & outcome == "hhi_pref" & tratamento == "captacao" & tempo == "Y-1" & faccao == "entrada" & amostra == "fronteira_1000" & painel == "bal" & x == "mun")
cap_mil <- v3("milicia", "saldo_ver", "captacao")
main_drug <- Wl("trafico", "hhi_pref"); main_mil <- Wl("milicia", "saldo_ver")
t5 <- c("\\begin{table}[H]", "\\centering", "\\caption{Robustness of the Two Main Estimates}\\label{tab:robustness}", "\\footnotesize",
        "\\begin{tabular}{@{}lcc@{}}", "\\toprule", row("", "Drug factions:", "Militia:"), row("", "mayoral HHI", "council right $-$ left"), "\\midrule",
        row("Main estimate", paste0(sgn(main_drug$att), stars(main_drug$p)), paste0(sgn(main_mil$att), stars(main_mil$p))),
        row("", par_se(main_drug$se), par_se(main_mil$se)), "\\addlinespace",
        "\\multicolumn{3}{@{}l}{\\textit{Specification curve: 128 within-municipality specifications}} \\\\",
        row("\\quad Same sign as the main estimate", pc(cs("trafico", "hhi_pref")$mesmo_sinal_dentro), pc(cs("milicia", "saldo_ver")$mesmo_sinal_dentro)),
        row("\\quad Significant at 5\\%", pc(cs("trafico", "hhi_pref")$sig5_mesmo_sinal_dentro), pc(cs("milicia", "saldo_ver")$sig5_mesmo_sinal_dentro)),
        row("\\quad Significant at 5\\% with pre-trend $p \\geq 0.10$", pc(cs("trafico", "hhi_pref")$sig5_pre_ok_dentro), pc(cs("milicia", "saldo_ver")$sig5_pre_ok_dentro)),
        row("\\quad Range of estimates", paste0("[", sgnt(cs("trafico", "hhi_pref")$min_dentro), ", ", sgnt(cs("trafico", "hhi_pref")$max_dentro), "]"),
            paste0("[", sgnt(cs("milicia", "saldo_ver")$min_dentro), ", ", sgnt(cs("milicia", "saldo_ver")$max_dentro), "]")), "\\addlinespace",
        "\\multicolumn{3}{@{}l}{\\textit{Randomization inference within municipality, $p$-value (1,000 permutations)}} \\\\",
        row("\\quad Permuting entry cohorts across polling stations", pv(ri("trafico", "hhi_pref", "R0")$p_t), pv(ri("milicia", "saldo_ver", "R0")$p_t)),
        "\\addlinespace",
        "\\multicolumn{3}{@{}l}{\\textit{Neighbor placebo: never-treated stations within 1 km of a treated station}} \\\\",
        row("\\quad Placebo estimate", paste0(sgn(pl("trafico", "hhi_pref")$att), stars(pl("trafico", "hhi_pref")$p)), paste0(sgn(pl("milicia", "saldo_ver")$att), stars(pl("milicia", "saldo_ver")$p))),
        row("", par_se(pl("trafico", "hhi_pref")$se), par_se(pl("milicia", "saldo_ver")$se)), "\\addlinespace",
        "\\multicolumn{3}{@{}l}{\\textit{Treatment measured by catchment population}} \\\\",
        row("\\quad Estimate", paste0(sgn(cap_drug$att_grp), stars(2 * pnorm(-abs(cap_drug$att_grp / cap_drug$se_grp)))), paste0(sgn(cap_mil$att_group), stars(cap_mil$p_group))),
        row("", par_se(cap_drug$se_grp), par_se(cap_mil$se_group)),
        "\\bottomrule", "\\end{tabular}",
        "\\tabnotes{\\textit{Notes:} Main estimates from Tables~\\ref{tab:csdid_main} and~\\ref{tab:militia_ideology}. The specification curve crosses seven binary choices (treatment by coordinates or catchment; map of the year before or of the election year; faction at entry or modal faction; 1-km frontier or all controls; balanced or unbalanced panel; cohort or event-time aggregation; with or without municipality indicators) and reports the 128 specifications that compare stations within municipalities. Randomization inference permutes entry cohorts within municipality and uses the $t$-statistic \\citep{young2019channeling}; the block version permutes cohorts across 1-km grid cells. The neighbor placebo is described in Table~\\ref{tab:matrix}. The catchment treatment assigns entry when at least half of the 2010 census population of the station's Voronoi catchment lives inside the faction's territory. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
        "\\end{table}")
escreve(t5, "tab_robustness.tex")

# =============== Apêndice: testes de igualdade e MDE ===============
eq <- function(y, src = "W") {
  if (src == "W") { a <- Wl("milicia", y); b <- Wl("trafico", y) } else { a0 <- v3("milicia", y); b0 <- v3("trafico", y)
    a <- data.table(att = a0$att_group, se = a0$se_group); b <- data.table(att = b0$att_group, se = b0$se_group) }
  data.table(ma = a$att, da = b$att, p = 2 * pnorm(-abs((a$att - b$att) / sqrt(a$se^2 + b$se^2))), mmde = 2.80 * a$se, dmde = 2.80 * b$se)
}
lin_eq <- function(lab, y, src = "W", d = 3) { e <- eq(y, src); row(lab, sgn(e$ma, d), sgn(e$da, d), num(e$p), num(e$mmde, d), num(e$dmde, d)) }
tmde <- c("\\begin{table}[H]", "\\centering", "\\caption{Militia-Drug Equality Tests and Minimum Detectable Effects}\\label{tab:mde}", "\\footnotesize",
          "\\begin{tabular}{@{}lrrrrr@{}}", "\\toprule", row("Outcome", "Militia ATT", "Drug ATT", "Equality $p$", "Militia MDE", "Drug MDE"), "\\midrule",
          "\\multicolumn{6}{@{}l}{\\textit{Panel A: Prefeito (mayoral) races}} \\\\[2pt]",
          lin_eq("HHI", "hhi_pref"), lin_eq("ENC", "enc_pref"), lin_eq("Margin of victory", "margin_pref"), lin_eq("Turnout", "comparecimento_taxa"),
          lin_eq("Right-minus-left balance", "saldo_pref"), lin_eq("Vote share of the citywide winner", "eleito_share_pref"), "\\midrule",
          "\\multicolumn{6}{@{}l}{\\textit{Panel B: Vereador (city-council) races}} \\\\[2pt]",
          lin_eq("HHI", "hhi_ver"), lin_eq("ENC", "enc_ver"), lin_eq("Margin of victory", "margin_ver"), lin_eq("Right-minus-left balance", "saldo_ver"),
          "\\bottomrule", "\\end{tabular}",
          "\\tabnotes{\\textit{Notes:} Equality tests use the CS-DID estimates of Tables~\\ref{tab:csdid_main}, \\ref{tab:matrix}, and~\\ref{tab:militia_ideology}. ``Drug'' refers to drug-trafficking factions; the abbreviation is used in tables for compactness. The test treats the two estimates as independent. The treated stations of the two designs are disjoint, but some never-treated stations near both territories serve as controls in both, so the test is approximate. MDE is the minimum detectable effect at 80\\% power and two-sided $\\alpha=0.05$, computed as $2.80 \\times \\widehat{SE}$.}",
          "\\end{table}")
escreve(tmde, "tab_mde.tex")

# =============== Apêndice: HonestDiD ===============
HN <- data.table(faccao = c("trafico", "trafico", "trafico", "trafico", "milicia"), outcome = c("hhi_pref", "enc_pref", "margin_pref", "hhi_ver", "saldo_ver"),
                 rot = c("Drug, mayoral HHI", "Drug, mayoral ENC", "Drug, mayoral margin", "Drug, council HHI", "Militia, council right $-$ left"))
lin_hd <- function(i) {
  a <- pega(HB, faccao == HN$faccao[i] & outcome == HN$outcome[i] & versao == "plano"); b <- pega(HB, faccao == HN$faccao[i] & outcome == HN$outcome[i] & versao == "paper")
  row(HN$rot[i], sgn(a$alvo), paste0("[", sgnt(a$ic_lb), ", ", sgnt(a$ic_ub), "]"), num(a$mbar_rm, 2),
      sgn(b$alvo), paste0("[", sgnt(b$ic_lb), ", ", sgnt(b$ic_ub), "]"), num(b$mbar_rm, 2))
}
thd <- c("\\begin{table}[H]", "\\centering", "\\caption{Honest-DiD Breakdown $\\overline{M}$}\\label{tab:honest_did}", "\\scriptsize",
         "\\begin{tabular}{@{}lcccccc@{}}", "\\toprule",
         row("", "\\multicolumn{3}{c}{Average post-entry effect, all pre-periods}", "\\multicolumn{3}{c}{Entry-election effect, one pre-period}"),
         "\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}",
         row("Outcome", "ATT", "Original 95\\% CI", "Breakdown $\\overline{M}$", "ATT", "Original 95\\% CI", "Breakdown $\\overline{M}$"), "\\midrule",
         sapply(seq_len(nrow(HN)), lin_hd), "\\bottomrule", "\\end{tabular}",
         "\\tabnotes{\\textit{Notes:} Relative-magnitudes sensitivity following \\citet{rambachan2023honest}, applied to the event-study estimates of the main specification with the clustered covariance matrix. Columns 1--3 target the average of the post-entry coefficients and use all pre-entry coefficients ($e=-16,-12,-8$, reference $e=-4$). Columns 4--6 target the entry-election coefficient ($e=0$) in a short window with one pre-period ($e=-8$), reference $e=-4$, and two post-periods ($e=0,+4$). $\\overline{M}$ is the largest value on the grid $\\{0, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2\\}$ at which the 95\\% robust confidence set still excludes zero; 0 means that the set includes zero already at $\\overline{M}=0.1$ or that the original interval includes zero. Implementation via the \\texttt{HonestDiD} R package, with outcomes rescaled for numerical stability.}",
         "\\end{table}")
escreve(thd, "tab_honest_did.tex")
for (i in seq_len(nrow(HN))) {
  d <- HC[faccao == HN$faccao[i] & outcome == HN$outcome[i] & metodo %in% c("original", "RM")]
  d[, xl := ifelse(metodo == "original", "Original", formatC(M, format = "fg"))]
  d[, xl := factor(xl, levels = c("Original", formatC(sort(unique(d[metodo == "RM"]$M)), format = "fg")))]
  d[, serie := factor(ifelse(versao == "plano", "Average post-entry effect, all pre-periods", "Entry-election effect, one pre-period"),
                      levels = c("Average post-entry effect, all pre-periods", "Entry-election effect, one pre-period"))]
  g <- ggplot(d, aes(xl, ymin = lb, ymax = ub, colour = serie)) + geom_hline(yintercept = 0, linetype = "dashed", colour = "grey55") +
    geom_errorbar(width = 0.3, linewidth = 0.6, position = position_dodge(width = 0.55)) +
    scale_colour_manual(values = c("black", "grey55"), name = NULL) +
    labs(x = expression(bar(M)), y = "95% robust confidence set") + theme_classic(base_size = 10) +
    theme(legend.position = "bottom", legend.direction = "vertical", legend.text = element_text(size = 8))
  arq <- sprintf("fig80_honest_%s_%s.pdf", HN$faccao[i], HN$outcome[i]); ggsave(file.path(FIG, arq), g, width = 4.6, height = 3.6); cat("figura:", arq, "
")
}

# =============== Apêndice: eleições gerais, amostras alternativas, partidos ===============
geral <- function(f, y) pega(R2, painel == "geral" & faccao == f & amostra == "a" & outcome == y)
GE <- list(c("Governor HHI", "hhi_gov"), c("Governor margin of victory", "margin_gov"), c("State-assembly HHI", "hhi_depest"), c("Federal-deputy HHI", "hhi_depfed"))
tge <- c("\\begin{table}[H]", "\\centering", "\\caption{Statewide Races in General Elections}\\label{tab:statewide}", "\\footnotesize",
         "\\begin{tabular}{@{}lcccc@{}}", "\\toprule", row("", "\\multicolumn{2}{c}{\\textbf{Militia}}", "\\multicolumn{2}{c}{\\textbf{Drug Factions}}"),
         "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}", row("Outcome", "ATT", "Wald $p$", "ATT", "Wald $p$"), "\\midrule",
         unlist(lapply(GE, function(z) { a <- geral("milicia", z[2]); b <- geral("trafico", z[2])
           c(row(z[1], paste0(sgn(a$att_group), stars(a$p_group)), br(a$wald_pre_p), paste0(sgn(b$att_group), stars(b$p_group)), br(b$wald_pre_p)),
             row("", par_se(a$se_group), "", par_se(b$se_group), "")) })),
         row("Treated polling stations", int(geral("milicia", "hhi_gov")$tratados), "", int(geral("trafico", "hhi_gov")$tratados), ""),
         "\\bottomrule", "\\end{tabular}",
         "\\tabnotes{\\textit{Notes:} CS-DID estimates on the panel of general elections (2006, 2010, 2014, 2018, 2022), same specification as Table~\\ref{tab:csdid_main}. Entry is dated by the first general election after the station enters faction territory (map of the preceding year). Standard errors in parentheses clustered by 2-km grid cells; Wald $p$-values for the joint pre-trends test in brackets. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
         "\\end{table}")
escreve(tge, "tab_statewide.tex")
amos <- c(a = "Main sample (1-km frontier)", fr500 = "500-m frontier", fr2000 = "2-km frontier",
          sem_flags = "Excluding flagged coordinates", rio = "City of Rio de Janeiro", fora_rio = "Other municipalities")
celA4 <- function(am, y) { x <- pega(R2, painel == "mun" & faccao == "trafico" & amostra == am & outcome == y)
  c(paste0(sgn(x$att_group), stars(x$p_group), " (", num(x$se_group), ")"), pv(x$wald_pre_p), int(x$tratados), int(x$unidades)) }
ta4 <- c("\\begin{table}[H]", "\\centering", "\\caption{Drug-Faction Entry and Vote Concentration in Alternative Samples}\\label{tab:drug_samples}", "\\footnotesize",
         "\\begin{tabular}{@{}lcccccc@{}}", "\\toprule",
         row("", "Mayoral HHI", "Wald $p$", "Council HHI", "Wald $p$", "Treated", "Stations"), "\\midrule",
         sapply(names(amos), function(am) { h <- celA4(am, "hhi_pref"); v <- celA4(am, "hhi_ver"); row(amos[[am]], h[1], h[2], v[1], v[2], h[3], h[4]) }),
         "\\bottomrule", "\\end{tabular}",
         "\\tabnotes{\\textit{Notes:} CS-DID estimates of drug-faction entry, same specification as Table~\\ref{tab:csdid_main}, in alternative samples. Flagged coordinates: stations at imprecise geocodes (three or more stations within 30 m in the same year), suspected mergers of adjacent buildings, and stations whose early-year coordinates may have been inherited from a later building with the same TSE number. Standard errors in parentheses clustered by 2-km grid cells. $^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}",
         "\\end{table}")
escreve(ta4, "tab_drug_samples.tex")
CL <- fread(file.path(RV, "pipeline_v2", "R_ext", "ideologia_partidos.csv"), colClasses = list(character = "numero"), encoding = "UTF-8")
CL[, cat_en := c(direita = "Right", centro = "Center", esquerda = "Left")[categoria]]
esc <- function(s) gsub("&", "\\\\&", s)
ta3 <- c("\\begin{table}[H]", "\\centering", "\\caption{Party Classification}\\label{tab:parties}", "\\scriptsize",
         "\\begin{tabular}{@{}rlll@{}}", "\\toprule", row("Number", "Years", "Party label(s)", "Bloc"), "\\midrule",
         CL[, row(numero, paste0(ano_ini, "--", ano_fim), esc(siglas_na_base), cat_en), by = seq_len(nrow(CL))]$V1,
         "\\bottomrule", "\\end{tabular}",
         "\\tabnotes{\\textit{Notes:} Classification of \\citet[Table A1]{colonnelli2025politics}, assigned by the party's ballot number and election year; renamed or merged parties keep the bloc of the original label.}",
         "\\end{table}")
escreve(ta3, "tab_parties.tex")

# =============== Apêndice: construção da amostra ===============
nobs <- PM[, .(k = sum(!is.na(hhi_pref))), by = place_id][, .N, by = k][order(-k)]
tot <- sum(nobs$N)
lin_pb <- sapply(5:1, function(kk) { n <- nobs[k == kk]$N; row(if (kk == 5) "5 (balanced)" else as.character(kk), int(n), paste0(formatC(100 * n / tot, format = "f", digits = 1), "\\%")) })
tpb <- c("\\begin{table}[H]", "\\centering", "\\caption{Panel Balance: Elections per Station (\\emph{Prefeito})}\\label{tab:panel_balance}", "\\footnotesize",
         "\\begin{tabular}{@{}c r r@{}}", "\\toprule", row("Elections observed", "Stations", "Share"), "\\midrule", lin_pb, "\\midrule",
         row("\\textit{Total}", int(tot), "100\\%"), "\\bottomrule", "\\end{tabular}",
         "\\tabnotes{\\textit{Notes:} Count of municipal elections (2008, 2012, 2016, 2020, 2024) in which each physical polling station appears with a valid \\emph{prefeito} outcome. Physical stations link TSE voting-location records across elections by location, name, and address (Appendix~\\ref{app:sample}). The main estimation sample uses the balanced stations.}",
         "\\end{table}")
escreve(tpb, "tab_panel_balance.tex")
`%s%` <- function(a, b) paste0(a, b)
cls <- function(f) {
  t <- TP[faccao_entrada %in% f]
  data.table(janela = t[sempre_tratado == FALSE & trat_pos_painel == FALSE, .N], sempre = t[sempre_tratado == TRUE, .N], pos = t[trat_pos_painel == TRUE, .N],
             coortes = paste(t[sempre_tratado == FALSE & trat_pos_painel == FALSE, .N, by = g_mun_lag][order(g_mun_lag), N], collapse = " / "),
             sai = t[sempre_tratado == FALSE, sum(sai_depois, na.rm = TRUE)], troca = t[sempre_tratado == FALSE, sum(troca_faccao_depois, na.rm = TRUE)],
             entram = t[sempre_tratado == FALSE, .N], amostra = Ntr(f))
}
cm <- cls("milicia"); ct <- cls("trafico")
tsw <- c("\\begin{table}[H]", "\\centering", "\\caption{Treatment Classification}\\label{tab:switchers}", "\\footnotesize",
         "\\begin{tabular}{@{}lrr@{}}", "\\toprule", row("", "Militia", "Drug"), "\\midrule",
         row("Stations inside territory since the first map (2007), excluded", int(cm$sempre), int(ct$sempre)),
         row("Stations entering territory, 2008--2024 election window", int(cm$janela), int(ct$janela)),
         row("\\quad by first election after entry: 2012 / 2016 / 2020 / 2024", cm$coortes, ct$coortes),
         row("Stations entering after the last election (controls until entry)", int(cm$pos), int(ct$pos)),
         row("Entering stations that later leave the territory", paste0(int(cm$sai), " of ", int(cm$entram)), paste0(int(ct$sai), " of ", int(ct$entram))),
         row("Entering stations later controlled by the other faction type", paste0(int(cm$troca), " of ", int(cm$entram)), paste0(int(ct$troca), " of ", int(ct$entram))),
         row("Treated stations in the main estimation sample", int(cm$amostra), int(ct$amostra)), "\\midrule",
         row("Never-treated stations (outside any control polygon, 2007--2024)", "\\multicolumn{2}{c}{" %s% int(TP[nunca_tratado == TRUE, .N]) %s% "}"),
         "\\bottomrule", "\\end{tabular}",
         "\\tabnotes{\\textit{Notes:} Physical polling stations with coordinates. Entry is the first year in which the station falls inside a control polygon of the Fogo Cruzado maps; the faction type is the one controlling the polygon in that year, and the cohort is the first municipal election held at least one year after entry. Treatment is coded as absorbing from the first entry (intention to treat). The main estimation sample keeps treated stations observed with valid outcomes in all five municipal elections, in municipalities where the faction enters.}",
         "\\end{table}")
escreve(tsw, "tab_switchers.tex")

# =============== Figuras: event studies ===============
plot_es <- function(f, y, arq) {
  ev <- copy(W(f, y)$event)[, k := e / 4]
  ev[, ref := e == -4]
  g <- ggplot(ev, aes(k, att)) + geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.3) +
    geom_vline(xintercept = -0.5, linetype = "dashed", colour = "grey60", linewidth = 0.3) +
    geom_errorbar(data = ev[ref == FALSE], aes(ymin = att - 1.96 * se, ymax = att + 1.96 * se), width = 0.12, linewidth = 0.4) +
    geom_point(data = ev[ref == FALSE], size = 2) + geom_point(data = ev[ref == TRUE], size = 2, shape = 21, fill = "white") +
    scale_x_continuous(breaks = ev$k) + labs(x = "Elections Relative to Treatment", y = "ATT") + theme_classic(base_size = 11)
  ggsave(file.path(FIG, arq), g, width = 4.6, height = 3.2); cat("figura:", arq, "\n")
}
for (z in list(c("hhi_pref", "hhi"), c("enc_pref", "enc"), c("margin_pref", "margin_victory"), c("comparecimento_taxa", "turnout")))
  plot_es("trafico", z[1], sprintf("fig79_es_drug_prefeito_%s.pdf", z[2]))
for (z in list(c("hhi_ver", "hhi"), c("enc_ver", "enc"), c("margin_ver", "margin_victory")))
  plot_es("trafico", z[1], sprintf("fig79_es_drug_vereador_%s.pdf", z[2]))
for (z in list(c("saldo_ver", "balance"), c("s_dir_ver", "right"), c("s_esq_ver", "left")))
  plot_es("milicia", z[1], sprintf("fig79_es_militia_vereador_%s.pdf", z[2]))
for (z in list(c("hhi_pref", "hhi"), c("margin_pref", "margin_victory")))
  plot_es("milicia", z[1], sprintf("fig79_es_militia_prefeito_%s.pdf", z[2]))

# =============== Figura: curvas de especificação ===============
curva <- function(f, y) {
  d <- CR[faccao_alvo == f & outcome == y & identificado == TRUE]
  d <- rbind(d[, .(att = att_grp, se = se_grp, x)], d[, .(att = att_dyn, se = se_dyn, x)])
  d[, comp := ifelse(x == "mun", "Within municipality", "Across municipalities")][order(att)][, rk := seq_len(.N)][]
}
CC <- rbind(curva("trafico", "hhi_pref")[, painel := "A. Drug factions: mayoral HHI"],
            curva("milicia", "saldo_ver")[, painel := "B. Militia: council right minus left"])
g3 <- ggplot(CC, aes(rk, att, colour = comp)) + geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_linerange(aes(ymin = att - 1.96 * se, ymax = att + 1.96 * se), alpha = 0.25, linewidth = 0.4) + geom_point(size = 0.6) +
  scale_colour_manual(values = c("Within municipality" = "black", "Across municipalities" = "grey65"), name = NULL) +
  facet_wrap(~ painel, scales = "free") + labs(x = "Specifications, ordered by estimate", y = "Estimate and 95% CI") +
  theme_classic(base_size = 10) + theme(legend.position = "bottom", strip.background = element_blank(), strip.text = element_text(hjust = 0, face = "bold"))
ggsave(file.path(FIG, "fig_spec_curves.pdf"), g3, width = 7.5, height = 3.4); cat("figura: fig_spec_curves.pdf\n")

# =============== Figura: distribuições da randomização ===============
RR <- rbindlist(lapply(list.files(file.path(F2, "ri"), "^V04_ri_.*[.]csv$", full.names = TRUE), fread))
RR <- RR[identificado == TRUE & versao_ri == "R0" & ((faccao == "trafico" & outcome == "hhi_pref") | (faccao == "milicia" & outcome == "saldo_ver"))]   # só R0 (locais); R1 (blocos de 1 km) fica fora
RR[, painel := paste0(ifelse(faccao == "trafico", "Drug factions: mayoral HHI", "Militia: council right minus left"), " | ",
                      ifelse(versao_ri == "R0", "polling stations", "1-km blocks"))]
gA1 <- ggplot(RR, aes(att / se)) + geom_histogram(bins = 40, fill = "grey70", colour = "grey70", linewidth = 0.1) +
  geom_vline(aes(xintercept = att_obs / se_obs), colour = "black", linewidth = 0.7) + facet_wrap(~ painel, ncol = 2) +
  labs(x = "t-statistic under permuted entry cohorts (line: observed)", y = "Permutations") +
  theme_classic(base_size = 9) + theme(strip.background = element_blank(), strip.text = element_text(hjust = 0))
ggsave(file.path(FIG, "fig_randomization.pdf"), gA1, width = 7, height = 2.6); cat("figura: fig_randomization.pdf\n")

# =============== Figura 1: territórios e locais de votação, 2008 e 2024 (um arquivo, dois painéis) ===============
# Recorte na área dos locais dentro de território (+3,5 km); milícia em azul com triângulos, tráfico em vermelho com círculos
# (legível em preto e branco); local dentro dos dois tipos de polígono conta como milícia.
MG <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v2/municipios_geo.parquet")))
MG <- st_make_valid(st_transform(st_as_sf(MG, wkt = "wkt", crs = 4326), 31983))
LG <- c("Militia territory", "Drug-faction territory", "Polling station, militia territory", "Polling station, drug-faction territory", "Other polling station")
le <- function(a) {
  g <- st_make_valid(st_transform(st_make_valid(st_read(file.path(MAPS, sprintf("%d_controle.geojson", a)), quiet = TRUE)), 31983))
  fe <- if ("Grupo_Armado_soControle" %in% names(g)) g$Grupo_Armado_soControle else g[[grep("Grupo", names(g))[1]]]
  g$tipo <- ifelse(grepl("^Mil", fe), LG[1], ifelse(fe %in% c("CV", "TCP", "ADA"), LG[2], NA))
  g <- g[!is.na(g$tipo), "tipo"]
  st_intersection(aggregate(g, by = list(tipo = g$tipo), FUN = function(z) z[1])[, "tipo"], st_union(MG))
}
GG <- list(); PP <- list()
for (a in c(2008, 2024)) {
  G <- le(a)
  P <- st_as_sf(unique(PM[ano == a & !is.na(hhi_pref), .(place_id, x, y)]), coords = c("x", "y"), crs = 31983)
  dentro <- st_intersects(P, G)
  P$tipo <- vapply(dentro, function(ix) if (!length(ix)) LG[5] else if (any(G$tipo[ix] == LG[1])) LG[3] else LG[4], "")
  n <- table(factor(P$tipo, LG[3:5]))
  G$painel <- P$painel <- sprintf("%d: %s polling stations; %d in militia and %d in drug-faction territory", a, format(nrow(P), big.mark = ","), n[[1]], n[[2]])
  GG[[length(GG) + 1]] <- G[, c("tipo", "painel")]; PP[[length(PP) + 1]] <- P[, c("tipo", "painel")]
}
G <- do.call(rbind, GG); P <- do.call(rbind, PP)
lv <- unique(P$painel); G$painel <- factor(G$painel, lv); P$painel <- factor(P$painel, lv); G$tipo <- factor(G$tipo, LG); P$tipo <- factor(P$tipo, LG)
bb <- st_bbox(st_buffer(st_union(P[P$tipo != LG[5], ]), 3500))
NOMES <- c("3304557" = "Rio de Janeiro", "3303302" = "Niterói", "3304904" = "São Gonçalo", "3301702" = "Duque de Caxias", "3303500" = "Nova Iguaçu",
           "3301900" = "Itaboraí", "3302700" = "Maricá", "3302502" = "Magé", "3302007" = "Itaguaí", "3305554" = "Seropédica",
           "3300456" = "Belford Roxo", "3304144" = "Queimados")
R <- MG[MG$id_municipio %in% names(NOMES), ]; R$nome <- NOMES[R$id_municipio]
R <- suppressWarnings(st_point_on_surface(R)); R$painel <- factor(lv[1], lv)   # nomes só no painel de cima
xy <- st_coordinates(R); R$X <- xy[, 1]; R$Y <- xy[, 2]
aj <- list("Rio de Janeiro" = c(-4000, -9500), "Duque de Caxias" = c(-1000, 3000), "Nova Iguaçu" = c(-2000, 5000), "Magé" = c(0, -3000),
           "Niterói" = c(2500, -2000), "São Gonçalo" = c(2000, -5500), "Belford Roxo" = c(-500, 2500), "Itaboraí" = c(-2000, -3000), "Maricá" = c(0, 2000))
for (k in names(aj)) { i <- R$nome == k; R$X[i] <- R$X[i] + aj[[k]][1]; R$Y[i] <- R$Y[i] + aj[[k]][2] }
E <- data.frame(painel = factor(lv[2], lv), x = bb[["xmax"]] - 14000, y = bb[["ymin"]] + 3000); E$xend <- E$x + 10000   # escala de 10 km
COR <- setNames(c("#9ecae1", "#fdbba4", "#08519c", "#a50f15", "grey65"), LG)
g <- ggplot() +
  geom_sf(data = MG, fill = "grey96", colour = "grey55", linewidth = 0.25) +
  geom_sf(data = G, aes(fill = tipo), colour = NA) +
  geom_sf(data = P[P$tipo == LG[5], ], aes(colour = tipo, shape = tipo), size = 0.12) +
  geom_sf(data = P[P$tipo == LG[4], ], aes(colour = tipo, shape = tipo), size = 0.55) +
  geom_sf(data = P[P$tipo == LG[3], ], aes(colour = tipo, shape = tipo), size = 0.65) +
  geom_label(data = R, aes(X, Y, label = nome), size = 2.1, colour = "grey20", fontface = "italic", fill = scales::alpha("white", 0.75),
             linewidth = 0, label.padding = unit(0.8, "pt"), label.r = unit(0, "pt")) +
  geom_segment(data = E, aes(x = x, xend = xend, y = y, yend = y), linewidth = 0.6) +
  geom_text(data = E, aes(x = (x + xend) / 2, y = y + 1600, label = "10 km"), size = 2.3) +
  scale_fill_manual(values = COR, breaks = LG[1:2], name = NULL) +
  scale_colour_manual(values = COR, breaks = LG[3:5], name = NULL) +
  scale_shape_manual(values = setNames(c(17, 16, 16), LG[3:5]), breaks = LG[3:5], name = NULL) +
  guides(fill = guide_legend(order = 1, nrow = 1, override.aes = list(colour = NA)),
         colour = guide_legend(order = 2, nrow = 1, override.aes = list(size = 1.8)), shape = guide_legend(order = 2, nrow = 1)) +
  facet_wrap(~ painel, ncol = 1) +
  coord_sf(xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], datum = NA, expand = FALSE) +
  theme_void(base_size = 9) +
  theme(legend.position = "bottom", legend.box = "vertical", legend.spacing.y = unit(1, "pt"), legend.key.size = unit(9, "pt"),
        legend.text = element_text(size = 7.5), strip.text = element_text(hjust = 0, face = "bold", size = 8.5, margin = margin(2, 0, 3, 0)),
        panel.border = element_rect(fill = NA, colour = "grey75", linewidth = 0.3), panel.spacing.y = unit(6, "pt"), plot.margin = margin(2, 2, 2, 2))
asp <- (bb[["ymax"]] - bb[["ymin"]]) / (bb[["xmax"]] - bb[["xmin"]])
ggsave(file.path(FIG, "fig71_map.pdf"), g, width = 6.8, height = 2 * 6.8 * asp + 0.9); cat("figura: fig71_map.pdf\n")

# =============== números citados no texto (macros LaTeX) ===============
pp <- function(x, d = 1) formatC(100 * abs(x), format = "f", digits = d)
pct <- function(a, b, d = 0) formatC(100 * abs(a) / abs(b), format = "f", digits = d)
mac <- list()
put <- function(nome, valor) mac[[nome]] <<- valor
bmt <- function(f, y) mean(grupos[[f]][[y]], na.rm = TRUE)       # média pré-tratamento dos tratados (Tabela 2)
x <- Wl("trafico", "hhi_pref"); put("DrugHHI", num(x$att)); put("DrugHHIse", num(x$se)); put("DrugHHIpre", num(x$pre_p, 2))
put("DrugHHIbase", num(bmt("trafico", "hhi_pref"))); put("DrugHHIpct", pct(x$att, bmt("trafico", "hhi_pref")))
x <- Wl("trafico", "enc_pref"); put("DrugENC", sgnt(x$att)); put("DrugENCbase", num(bmt("trafico", "enc_pref"), 2)); put("DrugENCpct", pct(x$att, bmt("trafico", "enc_pref")))
x <- Wl("trafico", "margin_pref"); put("DrugMarg", num(x$att)); put("DrugMargPP", pp(x$att)); put("DrugMargbase", num(bmt("trafico", "margin_pref")))
put("DrugMargPct", pct(x$att, bmt("trafico", "margin_pref")))
x <- Wl("trafico", "comparecimento_taxa"); put("DrugTurn", sgnt(x$att)); put("DrugTurnse", num(x$se))
x <- Wl("trafico", "hhi_ver"); put("DrugVerHHI", num(x$att)); put("DrugVerHHIpct", pct(x$att, bmt("trafico", "hhi_ver")))
x <- Wl("trafico", "margin_ver"); put("DrugVerMargPP", pp(x$att))
x <- Wl("trafico", "enc_ver"); put("DrugVerENC", sgnt(x$att, 2))
put("PlacDrugVerHHI", num(pl("trafico", "hhi_ver")$att)); put("PlacDrugVerHHIp", pv(pl("trafico", "hhi_ver")$p))
put("PlacDrugVerMargPP", pp(pl("trafico", "margin_ver")$att)); put("PlacDrugVerMargp", pv(pl("trafico", "margin_ver")$p))
put("PlacDrugHHI", num(pl("trafico", "hhi_pref")$att)); put("PlacDrugHHIse", num(pl("trafico", "hhi_pref")$se))
put("PlacDrugMarg", num(pl("trafico", "margin_pref")$att)); put("PlacDrugMargp", pv(pl("trafico", "margin_pref")$p))
x <- Wl("milicia", "hhi_pref"); put("MilHHI", num(x$att)); put("MilHHIse", num(x$se)); put("MilHHIp", num(x$p, 2))
x <- Wl("milicia", "margin_pref"); put("MilMarg", num(x$att)); put("MilMargse", num(x$se))
x <- Wl("milicia", "comparecimento_taxa"); put("MilTurn", sgnt(x$att)); put("MilTurnse", num(x$se))
x <- Wl("milicia", "hhi_ver"); put("MilVerHHI", sgnt(x$att)); x <- Wl("milicia", "margin_ver"); put("MilVerMarg", sgnt(x$att))
put("PlacMilHHI", num(pl("milicia", "hhi_pref")$att)); put("PlacMilHHIp", num(pl("milicia", "hhi_pref")$p, 2))
put("CurveMilHHIpre", pc(cs("milicia", "hhi_pref")$pre_rejeita10_dentro))
for (z in list(c("Lead", "lider_apt_pref"), c("Other", "outros_apt_pref"), c("BN", "bn_apt_pref"))) {
  x <- Wl("trafico", z[2]); put(paste0("DrugTD", z[1]), sgnt(x$att)); put(paste0("DrugTD", z[1], "se"), num(x$se)) }
x <- Wl("trafico", "hhi_pref"); put("DrugEzero", num(x$e0)); put("DrugEfour", num(x$e4)); put("DrugEdif", sgnt(x$dif_e4_e0)); put("DrugEdifse", num(x$se_dif))
ed <- W("trafico", "hhi_pref")$event; put("DrugEtwelve", num(ed[e == 12]$att))
x <- Wl("trafico", "margin_pref"); put("DrugMargEzero", num(x$e0)); put("DrugMargEfour", num(x$e4))
for (z in list(c("Win", "eleito_share_pref"), c("Top", "top1_pref"), c("TopThree", "top3_pref"), c("Pub", "pubadm_share_pref"))) {
  x <- Wl("trafico", z[2]); put(paste0("Drug", z[1], "PP"), pp(x$att)); put(paste0("Drug", z[1], "p"), pv(x$p)) }
x <- Wl("trafico", "ncomp1_pref"); put("DrugNcomp", sgnt(x$att, 2)); put("DrugNcompse", num(x$se, 2))
x <- Wl("trafico", "saldo_pref"); put("DrugPrefBalPP", pp(x$att)); put("DrugPrefBalp", pv(x$p))
x <- bl("trafico", "esq_outras_pref"); put("DrugOtherLeftPP", pp(x$att)); put("DrugOtherLeftp", pv(x$p))
put("PlacDrugOtherLeftPP", pp(pl("trafico", "esq_outras_pref")$att)); put("PlacDrugOtherLeftp", pv(pl("trafico", "esq_outras_pref")$p))
x <- Wl("trafico", "hhi_esq_outras_pref"); put("DrugHHIOL", num(x$att)); put("PlacDrugHHIOL", num(pl("trafico", "hhi_esq_outras_pref")$att))
x <- Wl("trafico", "lider_esq_outras_pref"); put("DrugLeadOLPP", pp(x$att)); put("PlacDrugLeadOLPP", pp(pl("trafico", "lider_esq_outras_pref")$att))
put("PlacDrugTopPP", pp(pl("trafico", "top1_pref")$att)); put("PlacDrugLead", sgnt(pl("trafico", "lider_apt_pref")$att))
put("PlacDrugWinPP", pp(pl("trafico", "eleito_share_pref")$att))
put("PlacDrugPrefBalPP", pp(pl("trafico", "saldo_pref")$att)); put("PlacDrugPrefBalp", pv(pl("trafico", "saldo_pref")$p))
x <- Wl("trafico", "hhi_esq_prog_pref"); put("DrugHHIProg", sgnt(x$att))
x <- Wl("trafico", "hhi_esq_pref"); put("DrugHHILeft", num(x$att)); x <- Wl("trafico", "hhi_dir_pref"); put("DrugHHIRight", num(x$att)); put("DrugHHIRightpre", pv(x$pre_p))
x <- Wl("trafico", "hhi_cen_pref"); put("DrugHHICenter", num(x$att))
dg <- geral("trafico", "hhi_gov"); dd <- geral("trafico", "hhi_depest")
put("DrugGov", sgnt(dg$att_group)); put("DrugGovse", num(dg$se_group)); put("DrugDep", sgnt(dd$att_group)); put("DrugDepse", num(dd$se_group))
mb <- d3[[1]]; mr <- d3[[2]]; ml <- d3[[3]]; mbc <- d3[[4]]
put("MilBalPP", pp(mb$att_group)); put("MilBalsePP", pp(mb$se_group)); put("MilBalp", pv(mb$p_group)); put("MilBalPct", pct(mb$att_group, bm3[1]))
put("MilBalbasePP", pp(bm3[1])); put("MilBalCapPP", pp(mbc$att_group)); put("MilRightPP", pp(mr$att_group)); put("MilLeftPP", pp(ml$att_group))
put("MilSmallRightPP", pp(bl("milicia", "dir_outras_ver")$att)); put("MilSmallRightCapPP", pp(bl("milicia", "dir_outras_ver", "captacao")$att))
put("MilNonPolPP", pp(bl("milicia", "dir_nao_pol_ver")$att)); put("MilPolPP", sgnt(100 * bl("milicia", "dir_pol_ver")$att, 1))
put("MilPsolPP", pp(bl("milicia", "esq_psol_ver")$att)); put("MilPsolCapPP", pp(bl("milicia", "esq_psol_ver", "captacao")$att))
put("MilPsbCapPP", pp(bl("milicia", "esq_psb_ver", "captacao")$att))
PB <- merge(amostra(PM, "milicia")[g == 0], as.data.table(read_parquet(file.path(EXT, "f6_blocos.parquet")))[versao == "principal", .(place_id, ano, esq_psol_ver)], by = c("place_id", "ano"))
psol <- PB[!is.na(esq_psol_ver), .(m = weighted.mean(esq_psol_ver, peso)), by = ano]
put("MilPsolBase", pp(psol[ano == 2008]$m)); put("MilPsolEnd", pp(psol[ano == 2024]$m))
x <- Wl("milicia", "saldo_pref"); put("MilPrefBalPP", pp(x$att)); put("MilPrefBalpre", num(x$pre_p, 3))
put("PlacMilPrefPP", pp(pl("milicia", "saldo_pref")$att)); put("PlacMilPrefp", pv(pl("milicia", "saldo_pref")$p))
put("PlacMilBal", sgnt(pl("milicia", "saldo_ver")$att)); put("PlacMilBalse", num(pl("milicia", "saldo_ver")$se))
x <- Wl("milicia", "saldo_ver"); put("MilBalEzero", pp(x$e0))
for (f in c("milicia", "trafico")) { k <- if (f == "milicia") "Mil" else "Drug"
  put(paste0("N", k), int(Ntr(f))); put(paste0("N", k, "Units"), int(Wl(f, "hhi_pref")$unidades)); put(paste0("N", k, "Clus"), int(Wl(f, "hhi_pref")$clusters)) }
put("NPhys", int(nrow(PL0))); put("NPlaces", int(uniqueN(PM$place_id))); put("NPlacesBal", int(uniqueN(PM[balanceado == TRUE]$place_id)))
put("NMun", int(uniqueN(PM$mun))); put("NNever", int(TP[nunca_tratado == TRUE, .N])); put("NFlagInh", int(sum(PL0$coord_possivelmente_herdada, na.rm = TRUE)))
put("NMilEnter", int(cm$entram)); put("NDrugEnter", int(ct$entram)); put("NMilAlways", int(cm$sempre)); put("NDrugAlways", int(ct$sempre))
put("NMilExit", int(cm$sai)); put("NDrugExit", int(ct$sai)); put("NMilSwitch", int(cm$troca)); put("NDrugSwitch", int(ct$troca))
put("NMilNYT", int(cm$janela)); put("NDrugNYT", int(ct$janela))
put("NPlacDrug", int(pl_n$pseudo_tratados)); put("NPlacDrugCtrl", int(pl_n$controles))
put("BalShare", formatC(100 * uniqueN(PM[balanceado == TRUE]$place_id) / uniqueN(PM$place_id), format = "f", digits = 1))
put("CurveDrugSame", pc(cs("trafico", "hhi_pref")$mesmo_sinal_dentro)); put("CurveDrugSig", pc(cs("trafico", "hhi_pref")$sig5_mesmo_sinal_dentro))
put("CurveDrugClean", pc(cs("trafico", "hhi_pref")$sig5_pre_ok_dentro))
put("CurveMilSame", pc(cs("milicia", "saldo_ver")$mesmo_sinal_dentro)); put("CurveMilSig", pc(cs("milicia", "saldo_ver")$sig5_mesmo_sinal_dentro))
put("CurveMilClean", pc(cs("milicia", "saldo_ver")$sig5_pre_ok_dentro))
put("RIDrug", pv(ri("trafico", "hhi_pref", "R0")$p_t)); put("RIDrugBlock", pv(ri("trafico", "hhi_pref", "R1")$p_t))
put("RIMil", pv(ri("milicia", "saldo_ver", "R0")$p_t)); put("RIMilBlock", pv(ri("milicia", "saldo_ver", "R1")$p_t))
put("CapDrug", num(cap_drug$att_grp)); put("CapDrugse", num(cap_drug$se_grp))
hd <- function(f, y, v) pega(HB, faccao == f & outcome == y & versao == v)
put("HDDrugPlan", num(hd("trafico", "hhi_pref", "plano")$mbar_rm, 1)); put("HDDrugPaper", num(hd("trafico", "hhi_pref", "paper")$mbar_rm, 2))
put("HDMilPlan", num(hd("milicia", "saldo_ver", "plano")$mbar_rm, 1)); put("HDMilPaper", num(hd("milicia", "saldo_ver", "paper")$mbar_rm, 2))
put("HDDrugMargPaper", num(hd("trafico", "margin_pref", "paper")$mbar_rm, 2))
eqh <- eq("hhi_pref"); put("EqHHIp", num(eqh$p)); put("MilMDEHHI", num(eqh$mmde)); eqm <- eq("margin_pref"); put("EqMargp", num(eqm$p)); put("MilMDEMargPP", pp(eqm$mmde))
eqb <- eq("saldo_ver"); put("EqBalp", num(eqb$p)); put("DrugMDEBalPP", pp(eqb$dmde))
put("DrugENCabs", num(abs(Wl("trafico", "enc_pref")$att))); put("DrugTDOtherabs", num(abs(Wl("trafico", "outros_apt_pref")$att)))
put("BaseDrugHHI", num(bmt("trafico", "hhi_pref"))); put("BaseDrugENC", num(bmt("trafico", "enc_pref"), 2))
put("BaseDrugMarg", num(bmt("trafico", "margin_pref"), 2)); put("BaseDrugTurn", num(bmt("trafico", "comparecimento_taxa"), 2))
ev_ver <- sapply(grupos, function(d) mean(d$enc_ver, na.rm = TRUE)); put("BaseVerENClo", formatC(floor(min(ev_ver)), format = "d")); put("BaseVerENChi", formatC(ceiling(max(ev_ver)), format = "d"))
cur1 <- function(f, y, pn, fa) pega(CR, faccao_alvo == f & outcome == y & tratamento == "ponto" & tempo == "Y-1" & faccao == fa & amostra == "fronteira_1000" & painel == pn & x == "mun")
z <- cur1("trafico", "hhi_pref", "rc", "entrada"); put("CurveDrugRC", num(z$att_grp)); put("CurveDrugRCse", num(z$se_grp)); put("CurveDrugRCpre", num(z$wald_pre_p))
z <- cur1("milicia", "saldo_ver", "rc", "entrada"); put("CurveMilRCPP", pp(z$att_grp)); put("CurveMilRCsePP", pp(z$se_grp))
z <- cur1("trafico", "hhi_pref", "bal", "estavel"); put("CurveDrugModal", num(z$att_grp)); put("CurveDrugModalse", num(z$se_grp))
z <- cur1("milicia", "saldo_ver", "bal", "estavel"); put("CurveMilModalPP", pp(z$att_grp)); put("CurveMilModalsePP", pp(z$se_grp))
sam <- function(am) pega(R2, painel == "mun" & faccao == "trafico" & amostra == am & outcome == "hhi_pref")
put("DrugRio", num(sam("rio")$att_group)); put("DrugRiopre", pv(sam("rio")$wald_pre_p)); put("DrugRioN", int(sam("rio")$tratados))
put("DrugFora", num(sam("fora_rio")$att_group)); put("DrugForapre", pv(sam("fora_rio")$wald_pre_p))
put("MilPsbCappre", num(bl("milicia", "esq_psb_ver", "captacao")$pre_p))
put("PlacMilBal", sgnt(100 * pl("milicia", "saldo_ver")$att, 1)); put("PlacMilBalse", pp(pl("milicia", "saldo_ver")$se))
put("DrugVerPsolPP", pp(bl("trafico", "esq_psol_ver")$att)); put("DrugVerPsolp", num(bl("trafico", "esq_psol_ver")$p))
# tabelas, figuras e macros da fase 3 (W04–W13)
source(file.path(dirname(normalizePath(.f)), "tabelas_fase3.R"))
# inferência conjunta da matriz (W15) e voto legislativo estadual (W16)
source(file.path(dirname(normalizePath(.f)), "tabelas_fase5.R"))
# renda do entorno no Censo 2010 (W17), receita em percentil e placebo de policiais (W18)
source(file.path(dirname(normalizePath(.f)), "tabelas_fase6.R"))
# p-valores citados no texto: a macro traz a expressão inteira ("$p=0.026$" ou "$p<0.001$")
PNOMES <- c("PlacMilHHIp", "EqHHIp", "EqMargp", "DrugWinp", "DrugTopThreep", "DrugPrefBalp", "DrugOtherLeftp", "PlacMilPrefp",
            "PlacDrugOtherLeftp", "PlacDrugPrefBalp", "PlacDrugVerHHIp", "PlacDrugVerMargp", "MilPsbCappre", "DrugRiopre",
            "DrugForapre", "CurveDrugRCpre", "RIDrug", "RIMil", "DrugVerPsolp", "PlacDrugMargp")
for (k in PNOMES) mac[[k]] <- if (mac[[k]] == "$<$0.001") "$p<0.001$" else paste0("$p=", mac[[k]], "$")
mac <- unlist(mac)
# sinal de menos tipográfico em toda macro numérica negativa
mac <- sub("^-([0-9])", "$-$\\1", mac)
writeLines(sprintf("\\newcommand{\\%s}{%s\\xspace}", names(mac), mac), file.path(TAB, "numbers.tex"))
cat("macros:", length(mac), "\n"); print(mac)
cat("OK tabelas_figuras\n")
