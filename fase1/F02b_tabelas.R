# F02b_tabelas.R — junta as saídas do F02_robustez.R (4 blocos) e monta as tabelas de leitura
# Saída: resultados/F02_todas_estimativas.csv, F02_event_study.csv, F02_tab_*.csv (e impressão na tela)
suppressPackageStartupMessages(library(data.table))
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F1DIR <- dirname(normalizePath(.f))
OUT <- Sys.getenv("F02B_DIR", file.path(F1DIR, "resultados"))   # F02B_DIR: só para testar com a saída do teste rápido
# um arquivo por bloco (ou por parte do bloco, quando rodado em paralelo: _p<k>de<n>)
arqs <- function(tipo) list.files(OUT, sprintf("^F02_(mun|geral)_(milicia|trafico)(_p[0-9]+de[0-9]+)?_%s[.]csv$", tipo), full.names = TRUE)
R <- rbindlist(lapply(arqs("estimativas"), fread), fill = TRUE)
E <- rbindlist(lapply(arqs("event"), fread), fill = TRUE)
cat(sprintf("%d arquivos de estimativas, %d linhas\n", length(arqs("estimativas")), nrow(R)))
stopifnot(!anyDuplicated(R[, .(painel, faccao, amostra, outcome)]))
R[, erro := as.character(erro)][is.na(erro), erro := ""]   # arquivo sem erros: o fread lê a coluna vazia como NA
stopifnot(R[erro == "", !anyNA(att_group)])
fwrite(R, file.path(OUT, "F02_todas_estimativas.csv")); fwrite(E, file.path(OUT, "F02_event_study.csv"))
options(width = 250)
est <- function(a, p) sprintf("%+.3f%s", a, fifelse(p < 0.01, "***", fifelse(p < 0.05, "**", fifelse(p < 0.1, "*", ""))))

# q-values sharpened (BKY/Anderson), igual ao F01, por família, na amostra (a) de cada painel (contrastes)
bky_q <- function(p) {
  m <- length(p); q <- rep(1, m); o <- order(p); ps <- p[o]; k <- seq_len(m)
  for (qq in seq(1, 0.001, by = -0.001)) {
    q1 <- qq / (1 + qq); r1 <- max(c(0, k[ps <= k * q1 / m])); q2 <- q1 * m / (m - r1)
    r2 <- max(c(0, k[ps <= k * q2 / m])); if (r2 > 0) q[o[seq_len(r2)]] <- qq
  }
  q
}
FAM <- data.table(outcome = c("margin_contraste", "hhi_contraste", "dissim_contraste", "exc_hhi_contraste",
                              "exc_vencedor_contraste", "comparecimento_taxa", "brancos_nulos_contraste"),
                  familia = c("F1", "F1", "F2", "F2", "F2", "F3", "F3"))
A <- merge(R[amostra == "a" & erro == ""], FAM, by = "outcome", all.x = TRUE)
A[!is.na(familia), q_familia := bky_q(p_group), by = .(painel, faccao, familia)]

# 1. HonestDiD na amostra principal (a), dois painéis
T1 <- A[, .(painel, faccao, familia, outcome, att = round(att_group, 4), se = round(se_group, 4), p = round(p_group, 3),
            q = round(q_familia, 3), pre_p = round(wald_pre_p, 3), media_pos = round(media_pos, 4),
            mbar_rm, sd_ic0 = sprintf("[%+.4f, %+.4f]", sd_ic0_lb, sd_ic0_ub), sd_ref_M = signif(sd_ref_M, 3),
            sd_icref = sprintf("[%+.4f, %+.4f]", sd_icref_lb, sd_icref_ub),
            sd_M_breakdown = signif(sd_M_breakdown, 3), sd_M_razao = round(sd_M_razao, 2))][order(painel, faccao, familia, outcome)]
fwrite(T1, file.path(OUT, "F02_tab_honestdid_principal.csv"))
cat("\n=== 1. HonestDiD na amostra (a): RM (M̄) e suavidade (SD, FLCI) ===\n"); print(T1)

# 2. Robustezes de amostra no painel municipal: ATT (estrelas pelo p CRVE) e p da pré-tendência
ORD <- c("a", "fr500", "fr2000", "sem_herdada", "sem_impreciso", "sem_fusao", "sem_flags", "rio", "fora_rio")
M <- R[painel == "mun" & erro == ""]
M[, cel := sprintf("%s (%.2f)", est(att_group, p_group), wald_pre_p)]
T2 <- dcast(M, faccao + outcome ~ factor(amostra, levels = ORD), value.var = "cel")
fwrite(T2, file.path(OUT, "F02_tab_robustez_municipal.csv"))
N2 <- unique(M[outcome == "hhi_pref", .(faccao, amostra = factor(amostra, levels = ORD), tratados, unidades, clusters, municipios, coortes)])[order(faccao, amostra)]
fwrite(N2, file.path(OUT, "F02_tab_robustez_municipal_n.csv"))
cat("\n=== 2. Painel municipal: ATT group (p da pré-tendência) por amostra ===\n"); print(T2); print(N2)

# 3. Painel geral: (a) contrastes e por cargo; (c) contrastes; (b) registrada como não identificada
G <- merge(R[painel == "geral"], FAM, by = "outcome", all.x = TRUE)
G <- merge(G, A[painel == "geral", .(faccao, amostra, outcome, q_familia)], by = c("faccao", "amostra", "outcome"), all.x = TRUE)
T3 <- G[erro == "", .(faccao, amostra, familia, outcome, att = round(att_group, 4), se = round(se_group, 4), p = round(p_group, 3),
                      q = round(q_familia, 3), pre_p = round(wald_pre_p, 3), mbar_rm, sd_M_breakdown = signif(sd_M_breakdown, 3),
                      tratados, clusters)][order(faccao, amostra, familia, outcome)]
fwrite(T3, file.path(OUT, "F02_tab_painel_geral.csv"))
cat("\n=== 3. Painel geral (governador − dep. estadual) ===\n"); print(T3)
cat("\nNão identificadas:\n"); print(unique(R[erro != "", .(painel, faccao, amostra, motivo = substr(erro, 1, 90))]))
cat("\nOK F02b\n")
