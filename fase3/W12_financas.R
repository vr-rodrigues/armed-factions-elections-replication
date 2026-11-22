# W12_financas.R — finanças de campanha: a concentração vai para candidatos com mais dinheiro?
# Receita financeira de campanha por candidato (sem doações estimáveis; basedosdados_v3/receitas_candidato_agregado,
# extrair_bd_v3.py), ligada aos votos pelo SEQUENCIAL do candidato (evita a duplicação de votos de
# candidatos substitutos). Não há deflator: os desfechos são relativos ao município-ano, e a
# comparação dentro do município remove o nível de cada ano.
#   prefeito: s_toprec  = share do voto no candidato que mais arrecadou no município-ano;
#             lider_toprec = share do líder local se ele for o que mais arrecadou (0 caso contrário);
#             vw_logrec = média do log(1 + receita) dos candidatos, ponderada pelo voto do local (só candidatos ligados)
#   vereador: s_q4rec   = share do voto em candidatos do quartil superior de receita do município-ano;
#             vw_logrec = idem
# Especificação principal + placebo de vizinhança (como W03). Saída: resultados/W12_financas.csv, W12_ligacao.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); OUT <- file.path(F3DIR, "resultados")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

R <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v3/receitas_candidato_agregado.parquet")))
R <- R[, .(receita = sum(receita_financeira)), by = .(ano, mun = id_municipio_tse, cargo, sequencial_candidato)]
vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo %in% c("prefeito", "vereador")]
vc <- merge(vc, R, by = c("ano", "mun", "cargo", "sequencial_candidato"), all.x = TRUE)
lig <- vc[, .(votos_ligados = sum(votos[!is.na(receita)]) / sum(votos)), by = .(cargo, ano)]
fwrite(lig, file.path(OUT, "W12_ligacao.csv")); cat("share dos votos com receita ligada:\n"); print(lig[order(cargo, ano)])
# candidato que mais arrecadou (prefeito) e quartil superior (vereador), entre os candidatos com votos no município-ano
cm <- unique(vc[, .(ano, mun, cargo, sequencial_candidato, receita)])
cm[, rk := frank(-fifelse(is.na(receita), -Inf, receita), ties.method = "first"), by = .(ano, mun, cargo)]
cm[, q4 := !is.na(receita) & receita >= quantile(receita, 0.75, na.rm = TRUE), by = .(ano, mun, cargo)]
vc <- merge(vc, cm[, .(ano, mun, cargo, sequencial_candidato, top = rk == 1, q4)], by = c("ano", "mun", "cargo", "sequencial_candidato"))
setorder(vc, ano, mun, place_id, cargo, -votos, numero_candidato)
B <- vc[, { v <- sum(votos); s <- votos / v; ok <- !is.na(receita)
  list(s_toprec = sum(s[top]), lider_toprec = if (top[1]) s[1] else 0, s_q4rec = sum(s[q4]),
       vw_logrec = if (any(ok)) sum(s[ok] * log1p(receita[ok])) / sum(s[ok]) else NA_real_) }, by = .(ano, place_id, cargo)]
B[, suf := fifelse(cargo == "prefeito", "pref", "ver")]
W <- dcast(B, ano + place_id ~ suf, value.var = c("s_toprec", "lider_toprec", "s_q4rec", "vw_logrec"), sep = "_")

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
PM <- merge(PM, W, by = c("place_id", "ano"), all.x = TRUE)
YS <- list(trafico = c("s_toprec_pref", "lider_toprec_pref", "vw_logrec_pref", "s_q4rec_ver", "vw_logrec_ver"),
           milicia = c("s_toprec_pref", "lider_toprec_pref", "vw_logrec_pref", "s_q4rec_ver", "vw_logrec_ver"))
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
fwrite(rbindlist(res), file.path(OUT, "W12_financas.csv")); cat("OK W12\n")
