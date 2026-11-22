# W18_receita_percentil.R — dinheiro de campanha sem transformação log(1 + x), e placebo dos candidatos policiais
# Preocupação: o desfecho de receita do W12 é a média do log(1 + receita) ponderada pelo voto. O "+1" é arbitrário e o
# coeficiente não tem unidade interpretável. Aqui o desfecho é o percentil de receita do candidato entre os candidatos
# do mesmo município, ano e cargo (de 0 a 1; maior = arrecadou mais), ponderado pelo voto do local. O coeficiente é
# lido em pontos de percentil: quanto o voto do local subiu na ordenação dos candidatos por receita.
#   vw_pctrec_pref, vw_pctrec_ver = média do percentil de receita, ponderada pelo voto (só candidatos ligados)
# Também estima o placebo de vizinhança de dir_pol_ver e dir_nao_pol_ver (candidatos de direita com e sem ocupação
# policial ou militar), que entram na tabela de quem ganha após a entrada da milícia.
# Mesma especificação do motor e mesma construção de placebo do W12/W03. Saída: resultados/W18_receita_percentil.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados"); ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

R <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v3/receitas_candidato_agregado.parquet")))
R <- R[, .(receita = sum(receita_financeira)), by = .(ano, mun = id_municipio_tse, cargo, sequencial_candidato)]
vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo %in% c("prefeito", "vereador")]
vc <- merge(vc, R, by = c("ano", "mun", "cargo", "sequencial_candidato"), all.x = TRUE)
cm <- unique(vc[, .(ano, mun, cargo, sequencial_candidato, receita)])
cm[!is.na(receita), pct := (frank(receita, ties.method = "average") - 0.5) / .N, by = .(ano, mun, cargo)]
vc <- merge(vc, cm[, .(ano, mun, cargo, sequencial_candidato, pct)], by = c("ano", "mun", "cargo", "sequencial_candidato"))
B <- vc[, { s <- votos / sum(votos); ok <- !is.na(pct)
  list(vw_pctrec = if (any(ok)) sum(s[ok] * pct[ok]) / sum(s[ok]) else NA_real_) }, by = .(ano, place_id, cargo)]
B[, suf := fifelse(cargo == "prefeito", "pref", "ver")]
W <- dcast(B, ano + place_id ~ suf, value.var = "vw_pctrec", sep = "_"); setnames(W, c("pref", "ver"), c("vw_pctrec_pref", "vw_pctrec_ver"))

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
PM <- merge(PM, W, by = c("place_id", "ano"), all.x = TRUE)
BLc <- as.data.table(read_parquet(file.path(EXT, "f6_blocos.parquet")))[versao == "principal", .(place_id, ano, dir_pol_ver, dir_nao_pol_ver)]
PM <- merge(PM, BLc, by = c("place_id", "ano"), all.x = TRUE)
YS <- list(trafico = c("vw_pctrec_pref", "vw_pctrec_ver"), milicia = c("vw_pctrec_pref", "vw_pctrec_ver", "dir_pol_ver", "dir_nao_pol_ver"))
TPd <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
XY <- unique(PM[, .(place_id, x, y)])
placebo_amostra <- function(f) {
  trat <- merge(unique(PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE & g > 0, .(place_id, mun, g)]), XY, by = "place_id")
  cand <- merge(merge(unique(PM[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)]), XY, by = "place_id"), TPd, by = "place_id")
  near <- cand[, { tt <- trat[mun == .BY$mun]; dd <- sqrt(outer(x, tt$x, "-")^2 + outer(y, tt$y, "-")^2); k <- max.col(-dd, ties.method = "first")
                   list(place_id = place_id, d_trat = dd[cbind(seq_len(.N), k)], g_near = tt$g[k]) }, by = mun]
  cand <- merge(cand, near[, .(place_id, d_trat, g_near)], by = "place_id")
  denv <- cand[[sprintf("dist_env_%s_m", f)]]
  cand[, papel := fifelse(d_trat <= 1000, "pseudo", fifelse(d_trat > 1500 & denv <= 3000, "controle", NA_character_))]
  sel <- cand[!is.na(papel), .(place_id, g_plac = fifelse(papel == "pseudo", g_near, 0L))]
  merge(PM[balanceado == TRUE], sel, by = "place_id")[, g := g_plac]
}
res <- list()
for (f in names(YS)) {
  am <- list(tratados = PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE], placebo = placebo_amostra(f))
  for (a in names(am)) for (yv in YS[[f]]) {
    d0 <- am[[a]]; fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
    r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(f, a, yv)), error = function(e) { cat("ERRO", f, a, yv, conditionMessage(e), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    res[[paste(f, a, yv)]] <- data.table(faccao = f, amostra = a, outcome = yv, att = g$att, se = r$se_group_crve,
                                         p = 2 * pnorm(-abs(g$att / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                         media_2008 = d[ano == 2008, mean(get(yv))], tratados = sum(r$n$por_coorte[u_g > 0]$N), excluidos_na = length(fora))
    cat(sprintf("%-8s %-9s %-18s ATT %+.4f (%.4f) p %.3f pré %.3f | média 2008 %.3f\n", f, a, yv, g$att, r$se_group_crve,
                res[[paste(f, a, yv)]]$p, r$wald_pre_crve$p, res[[paste(f, a, yv)]]$media_2008))
  }
}
fwrite(rbindlist(res), file.path(OUT, "W18_receita_percentil.csv")); cat("OK W18\n")
