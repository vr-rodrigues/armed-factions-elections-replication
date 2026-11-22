# V02b_curva_resumo.R — resume a curva de especificações (V02_curva.R) e aplica o critério (v):
# mesmo sinal da especificação principal em >= 80% das especificações DENTRO do município (~ mun).
# Saída: resultados/V02_resumo.csv, resultados/V02_curva_<outcome>.png
suppressPackageStartupMessages({ library(data.table); library(ggplot2); library(patchwork) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F2DIR <- dirname(normalizePath(.f))
OUT <- file.path(F2DIR, "resultados")
C <- rbindlist(lapply(list.files(file.path(OUT, "curva"), "^V02_.*[.]csv$", full.names = TRUE), fread), fill = TRUE)
C <- rbind(C[identificado == TRUE, .(faccao_alvo, outcome, tratamento, tempo, faccao, amostra, painel, x, agregacao = "group", att = att_grp, se = se_grp, pre = wald_pre_p)],
           C[identificado == TRUE, .(faccao_alvo, outcome, tratamento, tempo, faccao, amostra, painel, x, agregacao = "dynamic", att = att_dyn, se = se_dyn, pre = wald_pre_p)])
NI <- rbindlist(lapply(list.files(file.path(OUT, "curva"), "^V02_.*[.]csv$", full.names = TRUE), fread), fill = TRUE)[, .(combos = .N, identificadas = sum(identificado %in% TRUE)), by = .(faccao_alvo, outcome)]
C[, `:=`(p = 2 * pnorm(-abs(att / se)), principal = tratamento == "ponto" & tempo == "Y-1" & faccao == "entrada" & amostra == "fronteira_1000" &
                                          painel == "bal" & x == "mun" & agregacao == "group")]
P <- C[principal == TRUE, .(faccao_alvo, outcome, att_principal = att, p_principal = p)]
C <- merge(C, P, by = c("faccao_alvo", "outcome"))
res <- C[, .(especificacoes = .N,
             dentro_mun = sum(x == "mun"),
             mesmo_sinal_dentro = mean(sign(att[x == "mun"]) == sign(att_principal[1])),
             sig5_mesmo_sinal_dentro = mean(sign(att[x == "mun"]) == sign(att_principal[1]) & p[x == "mun"] < 0.05),
             mediana_dentro = median(att[x == "mun"]), min_dentro = min(att[x == "mun"]), max_dentro = max(att[x == "mun"]),
             mesmo_sinal_todas = mean(sign(att) == sign(att_principal[1])),
             pre_rejeita10_dentro = mean(pre[x == "mun"] < 0.10, na.rm = TRUE),
             sig5_pre_ok_dentro = mean((sign(att) == sign(att_principal[1]) & p < 0.05 & pre >= 0.10)[x == "mun"], na.rm = TRUE),
             att_principal = att_principal[1], p_principal = p_principal[1]), by = .(faccao_alvo, outcome)]
res <- merge(res, NI, by = c("faccao_alvo", "outcome"))
res[, criterio_v := mesmo_sinal_dentro >= 0.80]
fwrite(res, file.path(OUT, "V02_resumo.csv"))
options(width = 250); print(res[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)][order(outcome, faccao_alvo)])

# figuras: curva ordenada (dentro do município em destaque) e painel de escolhas
for (y in unique(C$outcome)) {
  d <- C[outcome == y][order(faccao_alvo, att)][, rk := seq_len(.N), by = faccao_alvo]
  d[, comparacao := ifelse(x == "mun", "dentro do município", "entre municípios")]
  g1 <- ggplot(d, aes(rk, att, colour = comparacao)) + geom_hline(yintercept = 0, linewidth = 0.3) +
    geom_linerange(aes(ymin = att - 1.96 * se, ymax = att + 1.96 * se), alpha = 0.25) + geom_point(size = 0.7) +
    geom_point(data = d[principal == TRUE], colour = "black", size = 2.2, shape = 21, fill = "gold") +
    facet_wrap(~ faccao_alvo, scales = "free") + labs(x = NULL, y = "ATT (IC 95%, CRVE)", colour = NULL, title = y) +
    theme_minimal(base_size = 9) + theme(legend.position = "top")
  dl <- melt(d[, .(faccao_alvo, rk, tratamento, tempo, faccao, amostra, painel, x, agregacao)], id.vars = c("faccao_alvo", "rk"))
  dl[, nivel := paste(variable, value, sep = ": ")]
  g2 <- ggplot(dl, aes(rk, nivel)) + geom_point(size = 0.25, shape = 15) + facet_wrap(~ faccao_alvo, scales = "free_x") +
    labs(x = "especificações ordenadas pelo ATT", y = NULL) + theme_minimal(base_size = 7)
  ggsave(file.path(OUT, sprintf("V02_curva_%s.png", y)), g1 / g2 + plot_layout(heights = c(1, 1.3)), width = 11, height = 8, dpi = 130)
}
cat("OK V02b\n")
