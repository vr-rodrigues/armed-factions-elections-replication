# W20_h2_exposicao.R — os desfechos de "quem ganha" de H2 (voto no eleito, percentil de receita) nas definições
# alternativas de exposição da Seção 5.3 (as mesmas usadas para o HHI): população da área de captação, raios de
# 250 m e 500 m, e camada de influência. Construções copiadas de fase2/V03_f6.R, fase3/W09 e fase3/W14.
# Saída: resultados/W20_h2_exposicao.csv
AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(sf) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
RAIZ <- normalizePath(file.path(F3DIR, "..")); AQUI <- file.path(F3DIR, "resultados")
source(file.path(RAIZ, "pipeline_v2", "R", "cs_engine.R")); source(file.path(RAIZ, "fase2", "util_v2.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
MAPS <- file.path(AFE_DADOS, "mapas_anuais")
sf_use_s2(FALSE); ELEI <- c(2008L, 2012L, 2016L, 2020L, 2024L)

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "w00_outcomes_paper.parquet")))[versao == "principal"]
PM <- merge(PM, X[, .(place_id, ano, eleito_share_pref)], by = c("place_id", "ano"), all.x = TRUE)
R <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v3/receitas_candidato_agregado.parquet")))
R <- R[, .(receita = sum(receita_financeira)), by = .(ano, mun = id_municipio_tse, cargo, sequencial_candidato)]
vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ELEI & cargo == "prefeito"]
vc <- merge(vc, R, by = c("ano", "mun", "cargo", "sequencial_candidato"), all.x = TRUE)
cm <- unique(vc[, .(ano, mun, sequencial_candidato, receita)]); cm[!is.na(receita), pct := (frank(receita, ties.method = "average") - 0.5) / .N, by = .(ano, mun)]
vc <- merge(vc, cm[, .(ano, mun, sequencial_candidato, pct)], by = c("ano", "mun", "sequencial_candidato"))
B <- vc[, { s <- votos / sum(votos); ok <- !is.na(pct); list(vw_pctrec_pref = if (any(ok)) sum(s[ok] * pct[ok]) / sum(s[ok]) else NA_real_) }, by = .(ano, place_id)]
PM <- merge(PM, B, by = c("place_id", "ano"), all.x = TRUE)
YS <- c("hhi_pref", "eleito_share_pref", "vw_pctrec_pref")

TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
dist0 <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
P <- st_as_sf(TP[, .(place_id, x, y)], coords = c("x", "y"), crs = 31983)
le <- function(a, camada) { g <- st_make_valid(st_transform(st_make_valid(st_read(file.path(MAPS, sprintf("%d_%s.geojson", a, camada)), quiet = TRUE)), 31983))
  fe <- if ("Grupo_Armado_soControle" %in% names(g)) g$Grupo_Armado_soControle else g[[grep("Grupo", names(g))[1]]]
  g$faccao <- ifelse(grepl("^Mil", fe), "milicia", ifelse(fe %in% c("CV", "TCP", "ADA"), "trafico", NA)); g[!is.na(g$faccao), "faccao"] }
dentro <- function(G) { j <- as.data.table(st_drop_geometry(st_join(P, G, join = st_within, left = TRUE))); j[!duplicated(place_id)]$faccao }
coorte <- function(entrada) vapply(entrada, function(e) { if (is.na(e)) NA_integer_ else { k <- ELEI[ELEI >= e + 1]; if (length(k)) k[1] else NA_integer_ } }, integer(1))
DIST <- list(); EXPO <- list(); DI <- list()
for (a in 2007:2024) { C <- le(a, "controle"); I <- le(a, "influencia")
  EXPO[[length(EXPO) + 1]] <- data.table(place_id = P$place_id, ano = a, f_ctrl = dentro(C), f_infl = dentro(I))
  for (f in c("milicia", "trafico")) {
    DIST[[length(DIST) + 1]] <- data.table(place_id = P$place_id, ano = a, faccao = f, dist = as.numeric(st_distance(P, st_union(C[C$faccao == f, ]))))
    DI[[length(DI) + 1]] <- data.table(place_id = P$place_id, faccao = f, dist = as.numeric(st_distance(P, st_union(rbind(C[C$faccao == f, ], I[I$faccao == f, ])))))
  } }
DIST <- rbindlist(DIST); E <- rbindlist(EXPO); setorder(E, place_id, ano)
DE <- dcast(rbindlist(DI)[, .(d = min(dist)), by = .(place_id, faccao)], place_id ~ faccao, value.var = "d"); setnames(DE, c("milicia", "trafico"), c("dist_env_milicia_m", "dist_env_trafico_m"))
fecha <- function(t) { t[, `:=`(sempre_tratado = !is.na(entrada) & entrada == 2007, nunca_tratado = is.na(entrada))]; t[, g_lag := coorte(entrada)]
  t[, trat_pos_painel := !is.na(entrada) & is.na(g_lag)]; t[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag)] }
raio <- function(D) { x <- DIST[dist <= D][order(place_id, ano, dist)]; ent <- x[, .(entrada = min(ano)), by = place_id]
  fac <- merge(x, ent, by.x = c("place_id", "ano"), by.y = c("place_id", "entrada"))[, .SD[1], by = place_id][, .(place_id, faccao_entrada = faccao)]
  fecha(merge(merge(TP[, .(place_id)], ent, by = "place_id", all.x = TRUE), fac, by = "place_id", all.x = TRUE)) }
influencia <- function() { e <- copy(E)[, f := fifelse(!is.na(f_ctrl), f_ctrl, f_infl)]
  fecha(e[, { k <- which(!is.na(f)); list(entrada = if (length(k)) ano[k[1]] else NA_integer_, faccao_entrada = if (length(k)) f[k[1]] else NA_character_) }, by = place_id]) }
TC <- as.data.table(read_parquet(file.path(EXT, "captacao_tratamento.parquet")))[medida == "c2010" & limiar == 0.5]

VERS <- list(
  principal = list(W = PM, fr = 1000),
  captacao = list(W = aplica_tratamento(PM, TC[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag = g_mun_lag)], "mun", dist0), fr = 1000),
  raio_250 = list(W = aplica_tratamento(PM, raio(250), "mun", dist0), fr = 1000),
  raio_500 = list(W = aplica_tratamento(PM, raio(500), "mun", dist0), fr = 2000),
  influencia = list(W = aplica_tratamento(copy(PM)[, c("dist_env_milicia_m", "dist_env_trafico_m") := NULL], influencia(), "mun", DE), fr = 1000))
res <- list()
for (v in names(VERS)) { d0 <- VERS[[v]]$W[get(sprintf("amostra_fronteira_trafico_%d", VERS[[v]]$fr)) == TRUE & balanceado == TRUE]
  for (y in YS) { fora <- unique(d0$place_id[is.na(d0[[y]])]); d <- d0[!place_id %in% fora]
    r <- tryCatch(cs_estimar(d, y, biters = 49), error = function(e) { cat("ERRO", v, y, conditionMessage(e), "\n"); NULL }); if (is.null(r)) next
    a <- r$overall[tipo == "group"]$att
    res[[paste(v, y)]] <- data.table(versao = v, outcome = y, att = a, se = r$se_group_crve, p = 2 * pnorm(-abs(a / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                     tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades)
    cat(sprintf("%-11s %-18s %+.4f (%.4f) p %.3f pré %.3f trat %d\n", v, y, a, r$se_group_crve, res[[paste(v, y)]]$p, r$wald_pre_crve$p, res[[paste(v, y)]]$tratados)) } }
fwrite(rbindlist(res), file.path(AQUI, "W20_h2_exposicao.csv")); cat("OK W20\n")
