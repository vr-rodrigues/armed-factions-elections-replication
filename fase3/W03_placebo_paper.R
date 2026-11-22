# W03_placebo_paper.R — placebo de vizinhança para os desfechos adicionais das tabelas do paper
# Mesma construção do fase2/V04_f6_testes.R (modo placebo): nunca tratados a <= 1 km de um local tratado do mesmo
# município recebem a coorte desse tratado (pseudo-tratados); controles são nunca tratados a > 1,5 km de qualquer
# tratado e a <= 3 km do envelope da facção. Mesma especificação do motor (~ mun + lrenda, reg, NYT + NT, group, CRVE 2 km).
# Saída: resultados/W03_placebo.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados")

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "f6_blocos", "w00_outcomes_paper")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
}
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
YS <- list(trafico = c("margin_pref", "hhi_ver", "margin_ver", "top1_pref", "eleito_share_pref", "lider_apt_pref",
                       "hhi_esq_outras_pref", "lider_esq_outras_pref", "esq_outras_pref"),
           milicia = c("dir_outras_ver", "esq_psol_ver", "dir_nao_pol_ver", "margin_pref", "hhi_ver", "margin_ver"))
res <- list()
XY <- unique(PM[, .(place_id, x, y)])
for (f in names(YS)) {
  trat <- unique(PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE & g > 0, .(place_id, mun, g)])
  trat <- merge(trat, XY, by = "place_id")
  cand <- unique(PM[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)])
  cand <- merge(merge(cand, XY, by = "place_id"), dist, by = "place_id")
  near <- cand[, {
    tt <- trat[mun == .BY$mun]
    dd <- sqrt(outer(x, tt$x, "-")^2 + outer(y, tt$y, "-")^2)
    k <- max.col(-dd, ties.method = "first")
    list(place_id = place_id, d_trat = dd[cbind(seq_len(.N), k)], g_near = tt$g[k])
  }, by = mun]
  cand <- merge(cand, near[, .(place_id, d_trat, g_near)], by = "place_id")
  denv <- cand[[sprintf("dist_env_%s_m", f)]]
  cand[, papel := fifelse(d_trat <= 1000, "pseudo", fifelse(d_trat > 1500 & denv <= 3000, "controle", NA_character_))]
  sel <- cand[!is.na(papel), .(place_id, g_plac = fifelse(papel == "pseudo", g_near, 0L))]
  d0 <- merge(PM[balanceado == TRUE], sel, by = "place_id")[, g := g_plac]
  for (yy in YS[[f]]) {
    fora <- unique(d0$place_id[is.na(d0[[yy]])]); d <- d0[!place_id %in% fora]
    rot <- paste("placebo", f, yy)
    r <- tryCatch(cs_estimar(d, yy, biters = 99, rotulo = rot), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    res[[rot]] <- data.table(faccao = f, outcome = yy, att = g$att, se = r$se_group_crve, p = 2 * pnorm(-abs(g$att / r$se_group_crve)),
                             pre_p = r$wald_pre_crve$p, tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades,
                             clusters = r$n$clusters, pseudo_tratados = sel[g_plac > 0, .N], controles = sel[g_plac == 0, .N])
    cat(sprintf("%-45s %+.4f (%.4f) p %.3f\n", rot, g$att, r$se_group_crve, res[[rot]]$p))
  }
}
fwrite(rbindlist(res), file.path(OUT, "W03_placebo.csv")); cat("OK W03\n")
