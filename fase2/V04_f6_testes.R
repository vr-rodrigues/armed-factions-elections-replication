# V04_f6_testes.R — testes do achado exploratório da F6
# Modos:
#   blocos                      decomposição por bloco partidário (vereador, prefeito), ponto e captação, amostra (a)
#   ri <faccao> <outcome> <R0|R1> <k/n>
#                               inferência por randomização dentro do município (parte k de n das 1.000 permutações);
#                               R1 = blocos de 1 km (coorte da célula = a mais cedo entre os seus locais), R0 = locais
#   placebo                     placebo de vizinhança (nunca tratados a <= 1 km de um tratado recebem a coorte dele;
#                               controles: nunca tratados a > 1,5 km de qualquer tratado e a <= 3 km do envelope)
# Especificação principal (fronteira 1 km, balanceado, ~ mun + lrenda, reg, NYT + NT, Y−1, group, CRVE 2 km), tratamento por ponto
# (e captação no modo blocos). Saída: resultados/V04_*.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F2DIR <- dirname(normalizePath(.f))
source(file.path(F2DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
source(file.path(F2DIR, "util_v2.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F2DIR, "resultados"); dir.create(file.path(OUT, "ri"), showWarnings = FALSE, recursive = TRUE)
SEED <- 20261009L
a <- commandArgs(TRUE); modo <- a[1]

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "f6_blocos")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
}
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
amostra_a <- function(W, f) W[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
linha <- function(r, y) {
  g <- r$overall[tipo == "group"]
  data.table(outcome = y, att = g$att, se = r$se_group_crve, p = 2 * pnorm(-abs(g$att / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
             tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades, clusters = r$n$clusters)
}

if (modo == "blocos") {
  BL <- c("dir_evangelica", "dir_pl_psl", "dir_tradicional", "dir_outras", "dir_pol", "dir_nao_pol",
          "esq_pt", "esq_psol", "esq_pdt", "esq_psb", "esq_outras", "cen", "s_dir", "s_esq", "saldo")
  ys <- c(paste0(BL, "_ver"), paste0(BL, "_pref"))
  TC <- as.data.table(read_parquet(file.path(EXT, "captacao_tratamento.parquet")))[medida == "c2010" & limiar == 0.5]
  WC <- aplica_tratamento(PM, TC[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag = g_mun_lag)], "mun", dist)
  res <- list()
  for (f in c("milicia", "trafico")) for (trat in c("ponto", "captacao")) {
    d <- amostra_a(if (trat == "ponto") PM else WC, f)
    for (y in ys) {
      rot <- paste("blocos", f, trat, y)
      r <- tryCatch(cs_estimar(d, y, biters = 99, rotulo = rot), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); NULL })
      if (!is.null(r)) res[[rot]] <- cbind(faccao = f, tratamento = trat, linha(r, y))
    }
    cat("ok", f, trat, "\n")
  }
  fwrite(rbindlist(res), file.path(OUT, "V04_blocos.csv")); cat("OK V04 blocos\n")
}

if (modo == "ri") {
  f <- a[2]; y <- a[3]; ver <- a[4]; parte <- as.integer(strsplit(a[5], "/")[[1]])
  NPERM <- 1000L; idx <- seq_len(NPERM); idx <- idx[(idx - 1) %% parte[2] == parte[1] - 1]
  d0 <- amostra_a(PM, f)[, g_ponte := g]
  obs <- estima(d0, y, ~ mun + lrenda, "bal", "obs")
  stopifnot(isTRUE(obs$identificado))
  base <- unique(d0[, .(place_id, mun, g, grade_1km)])
  if (ver == "R1") cel <- base[, .(g_cel = if (any(g > 0)) min(g[g > 0]) else 0L), by = .(mun, grade_1km)]
  res <- vector("list", length(idx))
  for (j in seq_along(idx)) {
    set.seed(SEED + idx[j])
    if (ver == "R0") {
      pg <- base[, .(place_id, g_perm = g[sample.int(.N)]), by = mun]
    } else {
      cp <- cel[, .(grade_1km, g_perm = g_cel[sample.int(.N)]), by = mun]
      pg <- merge(base[, .(place_id, mun, grade_1km)], cp, by = c("mun", "grade_1km"))
    }
    dp <- merge(d0[, !"g_ponte"], pg[, .(place_id, g_ponte = g_perm)], by = "place_id")
    r <- tryCatch(estima(dp, y, ~ mun + lrenda, "bal", "perm"), error = function(e) data.table(identificado = FALSE, motivo = conditionMessage(e)))
    res[[j]] <- data.table(perm = idx[j], identificado = isTRUE(r$identificado),
                           att = if (isTRUE(r$identificado)) r$att_grp else NA_real_, se = if (isTRUE(r$identificado)) r$se_grp else NA_real_)
  }
  R <- rbindlist(res)[, `:=`(faccao = f, outcome = y, versao_ri = ver, att_obs = obs$att_grp, se_obs = obs$se_grp)]
  fwrite(R, file.path(OUT, "ri", sprintf("V04_ri_%s_%s_%s_p%dde%d.csv", f, y, ver, parte[1], parte[2])))
  cat(sprintf("OK V04 ri %s %s %s parte %d/%d: %d permutações, %d identificadas\n", f, y, ver, parte[1], parte[2], nrow(R), sum(R$identificado)))
}

if (modo == "placebo") {
  res <- list()
  XY <- unique(PM[, .(place_id, x, y)])
  for (f in c("milicia", "trafico")) {
    trat <- unique(amostra_a(PM, f)[g > 0, .(place_id, mun, g)])
    trat <- merge(trat, XY, by = "place_id")
    cand <- unique(PM[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)])
    cand <- merge(merge(cand, XY, by = "place_id"), dist, by = "place_id")
    # tratado mais próximo (mesmo município) e sua coorte
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
    d <- merge(PM[balanceado == TRUE], sel, by = "place_id")[, g := g_plac]
    ys <- c("saldo_ver", "saldo_pref", "hhi_pref", "s_dir_ver", "s_esq_ver")
    for (yy in ys) {
      rot <- paste("placebo", f, yy)
      r <- tryCatch(cs_estimar(d, yy, biters = 99, rotulo = rot), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); NULL })
      if (!is.null(r)) res[[rot]] <- cbind(faccao = f, linha(r, yy), pseudo_tratados = sel[g_plac > 0, .N], controles = sel[g_plac == 0, .N])
    }
  }
  fwrite(rbindlist(res), file.path(OUT, "V04_placebo.csv")); cat("OK V04 placebo\n")
}
