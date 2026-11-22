# W14_exposicao_influencia.R — robustez: tratamento pela união das camadas "controle" e "influência" dos mapas do
# Fogo Cruzado (o mapa publicado traz as duas classificações; o pipeline usa só controle).
# Regra: o local entra no 1º ano em que está dentro de um polígono de controle OU de influência; facção na entrada =
# a do polígono de controle se estiver dentro de um, senão a do polígono de influência (1º polígono que contém o ponto,
# como no pipeline). Resto igual ao pipeline: coorte = 1ª eleição com entrada <= Y-1; sempre tratados = já expostos em
# 2007 (excluídos); ITT; nunca tratados = nunca dentro de nenhuma das duas camadas. Amostra de comparação: nunca tratados
# a até 1 km do envelope da facção, agora medido sobre controle ∪ influência.
# Checagem: só a camada de controle reproduz o tratamento do pipeline.
# Saída: resultados/W14_exposicao_influencia.csv, W14_contagens.csv, W14_checagem.csv

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
le <- function(a, camada) {
  g <- st_make_valid(st_transform(st_make_valid(st_read(file.path(MAPS, sprintf("%d_%s.geojson", a, camada)), quiet = TRUE)), 31983))
  fe <- g[[grep("Grupo", names(g))[1]]]
  g$faccao <- ifelse(grepl("^Mil", fe), "milicia", ifelse(fe %in% c("CV", "TCP", "ADA"), "trafico", NA))
  g[!is.na(g$faccao), "faccao"]
}
dentro <- function(G) {                                   # facção do 1º polígono que contém cada local (NA se nenhum)
  j <- as.data.table(st_drop_geometry(st_join(P, G, join = st_within, left = TRUE)))
  j[!duplicated(place_id)]$faccao
}
EXPO <- list(); DIST <- list()
for (a in 2007:2024) {
  C <- le(a, "controle"); I <- le(a, "influencia")
  EXPO[[length(EXPO) + 1]] <- data.table(place_id = P$place_id, ano = a, f_ctrl = dentro(C), f_infl = dentro(I))
  for (f in c("milicia", "trafico")) {                    # distância ao território (controle ∪ influência) da facção
    u <- st_union(rbind(C[C$faccao == f, ], I[I$faccao == f, ]))
    DIST[[length(DIST) + 1]] <- data.table(place_id = P$place_id, faccao = f, dist = as.numeric(st_distance(P, u)))
  }
  cat(a, "")
}
cat("\n")
E <- rbindlist(EXPO); setorder(E, place_id, ano)
DE <- dcast(rbindlist(DIST)[, .(d = min(dist)), by = .(place_id, faccao)], place_id ~ faccao, value.var = "d")
setnames(DE, c("milicia", "trafico"), c("dist_env_milicia_m", "dist_env_trafico_m"))

monta <- function(com_influencia) {
  e <- copy(E)[, f := if (com_influencia) fifelse(!is.na(f_ctrl), f_ctrl, f_infl) else f_ctrl]
  t <- e[, { k <- which(!is.na(f)); list(entrada = if (length(k)) ano[k[1]] else NA_integer_,
                                          faccao_entrada = if (length(k)) f[k[1]] else NA_character_) }, by = place_id]
  t[, `:=`(sempre_tratado = !is.na(entrada) & entrada == 2007, nunca_tratado = is.na(entrada))]
  t[, g_lag := vapply(entrada, function(x) { if (is.na(x)) NA_integer_ else { k <- ELEI[ELEI >= x + 1]; if (length(k)) k[1] else NA_integer_ } }, integer(1))]
  t[, trat_pos_painel := !is.na(entrada) & is.na(g_lag)]
  t[]
}
# checagem: só controle reproduz o pipeline
t0 <- monta(FALSE)
ck <- merge(t0, TP[, .(place_id, f_pipe = faccao_entrada, g_pipe = g_mun_lag, s_pipe = sempre_tratado, n_pipe = nunca_tratado)], by = "place_id")
CK <- data.table(item = c("locais", "faccao igual", "coorte igual", "sempre tratado igual", "nunca tratado igual"),
                 n = c(nrow(ck), ck[, sum((!is.na(faccao_entrada) & !is.na(f_pipe) & faccao_entrada == f_pipe) | (is.na(faccao_entrada) & is.na(f_pipe)))],   # linha a linha
                       ck[, sum((g_lag == g_pipe) | (is.na(g_lag) & (is.na(g_pipe) | g_pipe == 0)), na.rm = TRUE)],
                       ck[, sum(sempre_tratado == s_pipe)], ck[, sum(nunca_tratado == n_pipe)]))
fwrite(CK, file.path(OUT, "W14_checagem.csv")); print(CK)
stopifnot(all(CK$n == nrow(ck)))

t1 <- monta(TRUE)
# o que muda com a influência: locais tratados no painel, por facção e origem da mudança
cmp <- merge(t0[, .(place_id, f0 = faccao_entrada, g0 = g_lag, s0 = sempre_tratado)],
             t1[, .(place_id, f1 = faccao_entrada, g1 = g_lag, s1 = sempre_tratado)], by = "place_id")
cmp[, situacao := fcase(s1, "sempre tratado com influência (excluído)",
                        is.na(g1), "fora do painel nas duas versões",
                        is.na(g0) & !s0, "novo tratado (só influência)",
                        s0 & !s1, "erro",
                        f0 != f1, "facção muda",
                        g1 < g0, "entra antes",
                        g1 == g0, "igual", default = "outro")]
CN <- cmp[!is.na(g1) & !s1, .N, by = .(faccao = f1, situacao)][order(faccao, situacao)]
fwrite(CN, file.path(OUT, "W14_contagens.csv")); print(CN)

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
ALVOS <- list(trafico = c("hhi_pref", "margin_pref", "enc_pref", "comparecimento_taxa"), milicia = c("saldo_ver", "s_dir_ver", "s_esq_ver"))
res <- list()
for (versao in c("controle", "controle_influencia")) {
  t <- if (versao == "controle") t0 else t1
  dist_env <- if (versao == "controle") TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)] else DE
  # as distâncias ao envelope já existentes no painel (só controle) são removidas para que aplica_tratamento use as da
  # versão (com influência, a fronteira de 1 km é medida no envelope de controle ∪ influência)
  PMv <- copy(PM)[, c("dist_env_milicia_m", "dist_env_trafico_m") := NULL]
  W <- aplica_tratamento(PMv, t[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag)], "mun", dist_env)
  for (f in names(ALVOS)) {
    d0 <- W[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
    for (yv in ALVOS[[f]]) {
      fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
      r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(versao, f, yv)), error = function(e) { cat("ERRO", versao, f, yv, conditionMessage(e), "\n"); NULL })
      if (is.null(r)) next
      g <- r$overall[tipo == "group"]
      res[[paste(versao, f, yv)]] <- data.table(versao = versao, faccao = f, outcome = yv, att = g$att, se = r$se_group_crve,
                                               p = 2 * pnorm(-abs(g$att / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                               tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades)
      cat(sprintf("%-20s %-8s %-20s ATT %+.4f (%.4f) p %.3f pré %.3f trat %d\n", versao, f, yv, g$att, r$se_group_crve,
                  res[[paste(versao, f, yv)]]$p, r$wald_pre_crve$p, res[[paste(versao, f, yv)]]$tratados))
    }
  }
}
fwrite(rbindlist(res), file.path(OUT, "W14_exposicao_influencia.csv")); cat("OK W14\n")
