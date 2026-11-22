# W09_exposicao_buffer.R — exposição por raio em torno dos polígonos de controle.
# Tratamento por raio: o local entra no ano em que fica a até D metros de um polígono de controle (D = 0, 250, 500);
# facção na entrada = a do polígono mais próximo naquele ano; mesma regra do pipeline para o resto (coorte = 1ª eleição
# com entrada <= Y-1; sempre tratados = já expostos em 2007, excluídos; ITT; nunca tratados = nunca a até D m de controle).
# D = 0 deve reproduzir o tratamento do pipeline (checado). Amostra de comparação: nunca tratados a até 1 km do envelope
# da facção (D = 0 e 250) ou 2 km (D = 500), para manter uma faixa de comparação fora do raio.
# Saída: resultados/W09_exposicao_buffer.csv, W09_checagem_D0.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(sf) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
source(file.path(F3DIR, "..", "fase2", "util_v2.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
MAPS <- file.path(AFE_DADOS, "mapas_anuais")
OUT <- file.path(F3DIR, "resultados")
sf_use_s2(FALSE)
ELEI <- c(2008L, 2012L, 2016L, 2020L, 2024L)

TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
P <- st_as_sf(TP[, .(place_id, x, y)], coords = c("x", "y"), crs = 31983)
le <- function(a) {
  g <- st_make_valid(st_transform(st_make_valid(st_read(file.path(MAPS, sprintf("%d_controle.geojson", a)), quiet = TRUE)), 31983))
  fe <- if ("Grupo_Armado_soControle" %in% names(g)) g$Grupo_Armado_soControle else g[[grep("Grupo", names(g))[1]]]
  g$faccao <- ifelse(grepl("^Mil", fe), "milicia", ifelse(fe %in% c("CV", "TCP", "ADA"), "trafico", NA))
  g[!is.na(g$faccao), "faccao"]
}
# distância de cada local ao polígono de controle de cada facção, por ano
DIST <- rbindlist(lapply(2007:2024, function(a) {
  G <- le(a)
  rbindlist(lapply(c("milicia", "trafico"), function(f) {
    u <- st_union(G[G$faccao == f, ])
    data.table(place_id = P$place_id, ano = a, faccao = f, dist = as.numeric(st_distance(P, u)))
  }))
}))
monta <- function(D) {
  x <- DIST[dist <= D][order(place_id, ano, dist)]
  ent <- x[, .(entrada = min(ano)), by = place_id]
  fac <- merge(x, ent, by.x = c("place_id", "ano"), by.y = c("place_id", "entrada"))[, .SD[1], by = place_id][, .(place_id, faccao_entrada = faccao)]
  t <- merge(merge(TP[, .(place_id)], ent, by = "place_id", all.x = TRUE), fac, by = "place_id", all.x = TRUE)
  t[, `:=`(sempre_tratado = !is.na(entrada) & entrada == 2007, nunca_tratado = is.na(entrada))]
  t[, g_lag := vapply(entrada, function(e) { if (is.na(e)) NA_integer_ else { k <- ELEI[ELEI >= e + 1]; if (length(k)) k[1] else NA_integer_ } }, integer(1))]
  t[, trat_pos_painel := !is.na(entrada) & is.na(g_lag)]
  t[]
}
# checagem: D = 0 reproduz o pipeline
t0 <- monta(0)
ck <- merge(t0, TP[, .(place_id, f_pipe = faccao_entrada, g_pipe = g_mun_lag, s_pipe = sempre_tratado, n_pipe = nunca_tratado)], by = "place_id")
CK <- data.table(item = c("locais", "faccao igual", "coorte igual", "sempre tratado igual", "nunca tratado igual"),
                 n = c(nrow(ck), ck[, sum(faccao_entrada %in% f_pipe | (is.na(faccao_entrada) & is.na(f_pipe)))],
                       ck[, sum((g_lag == g_pipe) | (is.na(g_lag) & (is.na(g_pipe) | g_pipe == 0)), na.rm = TRUE)],
                       ck[, sum(sempre_tratado == s_pipe)], ck[, sum(nunca_tratado == n_pipe)]))
fwrite(CK, file.path(OUT, "W09_checagem_D0.csv")); print(CK)

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
dist_env <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
ALVOS <- list(trafico = c("hhi_pref", "margin_pref", "enc_pref"), milicia = c("saldo_ver", "s_dir_ver", "s_esq_ver"))
FRONT <- c(`0` = 1000, `250` = 1000, `500` = 2000)
res <- list()
for (D in c(0, 250, 500)) {
  t <- monta(D)
  W <- aplica_tratamento(PM, t[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag)], "mun", dist_env)
  for (f in names(ALVOS)) {
    d0 <- W[get(sprintf("amostra_fronteira_%s_%d", f, FRONT[[as.character(D)]])) == TRUE & balanceado == TRUE]
    for (yv in ALVOS[[f]]) {
      fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
      r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(D, f, yv)), error = function(e) { cat("ERRO", D, f, yv, conditionMessage(e), "\n"); NULL })
      if (is.null(r)) next
      g <- r$overall[tipo == "group"]
      res[[paste(D, f, yv)]] <- data.table(raio_m = D, faccao = f, outcome = yv, att = g$att, se = r$se_group_crve,
                                           p = 2 * pnorm(-abs(g$att / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                           tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades)
      cat(sprintf("D=%3d %-8s %-12s ATT %+.4f (%.4f) p %.3f pré %.3f trat %d\n", D, f, yv, g$att, r$se_group_crve,
                  res[[paste(D, f, yv)]]$p, r$wald_pre_crve$p, res[[paste(D, f, yv)]]$tratados))
    }
  }
}
fwrite(rbindlist(res), file.path(OUT, "W09_exposicao_buffer.csv")); cat("OK W09\n")
