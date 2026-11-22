# V03b_tabelas.R — junta as saídas do V03_f6.R (F6, ideologia; exploratório) e aplica os critérios (i)–(iv).
# q-values: sobre todos os outcomes da F6 do painel (critério i, conservador, como no F01) e só sobre os primários.
# O critério (v) (sinal em >= 80% das especificações dentro do município) depende da curva de especificações.
# Saída: resultados/V03_todas_estimativas.csv, V03_event_study.csv, V03_criterios.csv, V03_robustez_medida.csv
suppressPackageStartupMessages(library(data.table))
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F2DIR <- dirname(normalizePath(.f))
source(file.path(F2DIR, "util_v2.R"))
OUT <- file.path(F2DIR, "resultados")
arqs <- function(tipo) list.files(OUT, sprintf("^V03_(mun|geral)_(milicia|trafico)_(ponto|captacao)(_p[0-9]+de[0-9]+)?_%s[.]csv$", tipo), full.names = TRUE)
R <- rbindlist(lapply(arqs("estimativas"), fread), fill = TRUE); E <- rbindlist(lapply(arqs("event"), fread), fill = TRUE)
R[, erro := as.character(erro)][is.na(erro), erro := ""]
stopifnot(!anyDuplicated(R[, .(painel, faccao, tratamento, amostra, outcome)]))
fwrite(R, file.path(OUT, "V03_todas_estimativas.csv")); fwrite(E, file.path(OUT, "V03_event_study.csv"))
FAM <- rbind(fread(file.path(OUT, "V03_mun_familias.csv"))[, painel := "mun"], fread(file.path(OUT, "V03_geral_familias.csv"))[, painel := "geral"])

A <- merge(R[amostra == "a" & erro == ""], FAM, by = c("painel", "outcome"))
A[, q_familia := bky_q(p_group), by = .(painel, faccao, tratamento, familia)]
A[papel == "primario", q_primarios := bky_q(p_group), by = .(painel, faccao, tratamento)]
sinais <- R[erro == "" & outcome %in% FAM$outcome, .(sinal_igual = uniqueN(sign(att_group)) == 1, amostras = paste(sort(amostra), collapse = "")),
            by = .(painel, faccao, tratamento, outcome)]
A <- merge(A, sinais, by = c("painel", "faccao", "tratamento", "outcome"))
A[, `:=`(c_i = p_group < 0.05 & q_familia < 0.10, c_ii = wald_pre_p >= 0.10, c_iii = mbar_rm >= 1, c_iv = sinal_igual)]
A[, robusto_i_iv := c_i & c_ii & c_iii & c_iv]
fwrite(A, file.path(OUT, "V03_criterios.csv"))

options(width = 250)
fmt <- A[, .(painel, familia, outcome, faccao, tratamento,
             cel = sprintf("%+.4f (%.4f) p=%.3f q=%.2f pré=%.2f M̄=%.1f SD0=[%+.3f,%+.3f] %s%s", att_group, se_group, p_group, q_familia,
                           wald_pre_p, mbar_rm, sd_ic0_lb, sd_ic0_ub, amostras, ifelse(robusto_i_iv, " ROBUSTO", "")))]
cat("=== F5 e F4, amostra (a): ponto x captação ===\n")
print(dcast(fmt, painel + familia + outcome + faccao ~ tratamento, value.var = "cel")[order(painel, faccao, familia, outcome)])
ROB <- R[amostra == "a" & erro == "" & !outcome %in% FAM$outcome,
         .(painel, faccao, tratamento, outcome, att = round(att_group, 4), se = round(se_group, 4), p = round(p_group, 3), pre_p = round(wald_pre_p, 3))]
fwrite(ROB, file.path(OUT, "V03_robustez_medida.csv"))
cat("\n=== Variantes de medida (agremiação, legenda) e dep. federal ===\n"); print(ROB[order(painel, faccao, outcome, tratamento)])
cat("\nNão identificadas:\n"); print(unique(R[erro != "", .(painel, faccao, tratamento, amostra, motivo = substr(erro, 1, 80))]))
cat("\nOK V03b\n")
