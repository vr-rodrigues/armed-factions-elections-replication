# V04b_ri_resumo.R — p-valores da inferência por randomização dentro do município (V04_f6_testes.R ri)
# p bicaudal = fração das permutações identificadas com |estatística| >= |observada| (estatística t com CRVE e o ATT)
suppressPackageStartupMessages({ library(data.table); library(ggplot2) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F2DIR <- dirname(normalizePath(.f))
OUT <- file.path(F2DIR, "resultados")
R <- rbindlist(lapply(list.files(file.path(OUT, "ri"), "^V04_ri_.*[.]csv$", full.names = TRUE), fread))
stopifnot(!anyDuplicated(R[, .(faccao, outcome, versao_ri, perm)]))
R[, `:=`(t = att / se, t_obs = att_obs / se_obs)]
S <- R[, .(permutacoes = .N, identificadas = sum(identificado), att_obs = att_obs[1], t_obs = t_obs[1],
           p_t = mean(abs(t[identificado]) >= abs(t_obs[1])), p_att = mean(abs(att[identificado]) >= abs(att_obs[1])),
           p_crve = 2 * pnorm(-abs(t_obs[1])), att_perm_media = mean(att[identificado]), att_perm_dp = sd(att[identificado])),
       by = .(faccao, outcome, versao_ri)][order(faccao, outcome, versao_ri)]
fwrite(S, file.path(OUT, "V04_ri_resumo.csv"))
options(width = 200); print(S[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 4) else z)])
g <- ggplot(R[identificado == TRUE], aes(att)) + geom_histogram(bins = 40, fill = "grey70") +
  geom_vline(aes(xintercept = att_obs), colour = "firebrick") + facet_wrap(~ faccao + outcome + versao_ri, scales = "free", ncol = 4) +
  labs(x = "ATT nas permutações (linha: observado)", y = NULL) + theme_minimal(base_size = 8)
ggsave(file.path(OUT, "V04_ri.png"), g, width = 11, height = 6, dpi = 130)
cat("OK V04b\n")
