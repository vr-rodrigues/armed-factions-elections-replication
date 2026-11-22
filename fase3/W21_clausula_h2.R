# W21_clausula_h2.R — H2 diz que o fechamento só eleva a concentração onde os
# candidatos beneficiados já lideram no local. Teste simples: separar os locais tratados pelo que acontecia na eleição
# anterior à entrada. "Alinhado" = o candidato mais votado no local era o eleito na cidade naquela eleição
# (eleito_share_pref == top1_pref). Cada subgrupo de tratados é comparado com os mesmos controles nunca tratados
# (os tratados do outro subgrupo saem). Saídas: resultados/W21_clausula_h2.csv, W21_alinhados.csv
AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
RAIZ <- normalizePath(file.path(F3DIR, "..")); AQUI <- file.path(F3DIR, "resultados")
source(file.path(RAIZ, "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "w00_outcomes_paper.parquet")))[versao == "principal"]
PM <- merge(PM, X[, .(place_id, ano, eleito_share_pref)], by = c("place_id", "ano"), all.x = TRUE)
d <- PM[amostra_fronteira_trafico_1000 == TRUE & balanceado == TRUE]
fora <- unique(d$place_id[is.na(d$eleito_share_pref)]); d <- d[!place_id %in% fora]
base <- d[g > 0 & ano == g - 4, .(place_id, alinhado = abs(eleito_share_pref - top1_pref) < 1e-9, exc = exc_vencedor_pref)]
cat("tratados:", nrow(base), "| alinhados na eleição anterior à entrada:", sum(base$alinhado), "\n")
fwrite(data.table(tratados = nrow(base), alinhados = sum(base$alinhado)), file.path(AQUI, "W21_alinhados.csv"))
print(merge(unique(d[g > 0, .(place_id, g)]), base, by = "place_id")[, .N, by = .(g, alinhado)][order(g, alinhado)])
res <- list()
for (k in c(TRUE, FALSE)) { ids <- base[alinhado == k, place_id]; dk <- d[g == 0 | place_id %in% ids]
  for (y in c("hhi_pref", "margin_pref", "eleito_share_pref", "top1_pref")) {
    r <- tryCatch(cs_estimar(dk, y, biters = 49, retorna_if = TRUE), error = function(e) { cat("ERRO", k, y, conditionMessage(e), "\n"); NULL }); if (is.null(r)) next
    a <- r$overall[tipo == "group"]$att
    res[[paste(k, y)]] <- data.table(alinhado = k, outcome = y, att = a, se = r$se_group_crve, p = 2 * pnorm(-abs(a / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                     tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades)
  } }
R <- rbindlist(res); fwrite(R, file.path(AQUI, "W21_clausula_h2.csv"))
print(R[, .(alinhado, outcome, att = round(att, 4), se = round(se, 4), p = round(p, 3), pre_p = round(pre_p, 3), tratados, unidades)])
# diferença entre subgrupos (tratados disjuntos; controles comuns, então o teste com soma de variâncias é aproximado)
for (y in unique(R$outcome)) { a <- R[alinhado == TRUE & outcome == y]; b <- R[alinhado == FALSE & outcome == y]
  if (nrow(a) && nrow(b)) cat(sprintf("%-18s alinhado %+.4f | não alinhado %+.4f | dif %+.4f (EP aprox. %.4f)\n", y, a$att, b$att, a$att - b$att, sqrt(a$se^2 + b$se^2))) }
