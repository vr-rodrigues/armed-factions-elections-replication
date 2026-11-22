# W06_inferencia_espacial.R — inferência espacial: cluster por território e erros-padrão de Conley.
# Mesmas estimativas da especificação principal; só a variância muda.
# Variâncias, todas a partir das funções de influência do efeito agregado (group) do did:
#   CRVE por grade de 2 km (principal, confere com o motor), grade de 5 km, território e município;
#   Conley com kernel de Bartlett, bandas de 1, 2, 5 e 10 km: V = (1/n^2) sum_i sum_j K(d_ij) psi_i psi_j.
# Território: cada mancha contígua da área já controlada pela facção em algum mapa anual de 2007 a 2024 (camada controle,
#   facção pelo grupo do polígono; manchas a menos de 200 m unidas). Tratados recebem a mancha em que estão; controles da
#   fronteira de 1 km recebem a mancha mais próxima.
# Saída: resultados/W06_inferencia_espacial.csv, W06_territorios.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(sf) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
MAPS <- file.path(AFE_DADOS, "mapas_anuais")
OUT <- file.path(F3DIR, "resultados")
sf_use_s2(FALSE)

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "f6_blocos", "w00_outcomes_paper")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
}

# ---- territórios: manchas contíguas da área já controlada, por facção ----
le <- function(a) {
  g <- st_make_valid(st_transform(st_make_valid(st_read(file.path(MAPS, sprintf("%d_controle.geojson", a)), quiet = TRUE)), 31983))
  fe <- if ("Grupo_Armado_soControle" %in% names(g)) g$Grupo_Armado_soControle else g[[grep("Grupo", names(g))[1]]]
  g$faccao <- ifelse(grepl("^Mil", fe), "milicia", ifelse(fe %in% c("CV", "TCP", "ADA"), "trafico", NA))
  g[!is.na(g$faccao), "faccao"]
}
G <- do.call(rbind, lapply(2007:2024, le))
terr <- do.call(rbind, lapply(c("milicia", "trafico"), function(f) {
  u <- st_union(st_buffer(G[G$faccao == f, ], 100))                     # buffer de 100 m: manchas a < 200 m se unem
  p <- st_cast(st_sf(geometry = u), "POLYGON"); p$faccao <- f; p$territorio <- sprintf("%s_%03d", f, seq_len(nrow(p))); p
}))
fwrite(as.data.table(st_drop_geometry(terr))[, .N, by = faccao], file.path(OUT, "W06_territorios.csv"))

XY <- unique(PM[, .(place_id, x, y, mun, grade_2km, grade_5km)])
atribui <- function(f, ids) {
  P <- st_as_sf(XY[place_id %in% ids], coords = c("x", "y"), crs = 31983, remove = FALSE)
  T <- terr[terr$faccao == f, ]
  k <- st_nearest_feature(P, T)                                         # dentro da mancha => distância 0
  data.table(place_id = P$place_id, territorio = T$territorio[k])
}

amostra <- function(f) PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
ALVOS <- list(trafico = c("hhi_pref", "margin_pref", "enc_pref", "eleito_share_pref", "lider_apt_pref", "hhi_ver"),
              milicia = c("saldo_ver", "s_dir_ver", "s_esq_ver", "dir_outras_ver", "esq_psol_ver", "hhi_pref"))
crve <- function(psi, cl) as.numeric(crossprod(rowsum(psi, cl, reorder = TRUE)) / length(psi)^2)
conley <- function(psi, xy, h) {
  K <- 1 - as.matrix(dist(xy)) / h; K[K < 0] <- 0                        # Bartlett (pmax perderia a dimensão)
  as.numeric(t(psi) %*% K %*% psi) / length(psi)^2
}
res <- list()
for (f in names(ALVOS)) {
  d0 <- amostra(f)
  ter <- atribui(f, unique(d0$place_id))
  for (yv in ALVOS[[f]]) {
    fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
    r <- cs_estimar(d, yv, biters = 99, rotulo = paste(f, yv), retorna_if = TRUE)
    U <- merge(r$unidades[, .(u_id, place_id = u_id_chr)], XY, by = "place_id")
    U <- merge(U, ter, by = "place_id")[order(u_id)]
    stopifnot(nrow(U) == length(r$psi_group))
    psi <- as.numeric(r$psi_group); att <- r$overall[tipo == "group"]$att
    se <- c(grade_2km = sqrt(crve(psi, U$grade_2km)), grade_5km = sqrt(crve(psi, U$grade_5km)),
            territorio = sqrt(crve(psi, U$territorio)), municipio = sqrt(crve(psi, U$mun)),
            conley_1km = sqrt(conley(psi, U[, .(x, y)], 1000)), conley_2km = sqrt(conley(psi, U[, .(x, y)], 2000)),
            conley_5km = sqrt(conley(psi, U[, .(x, y)], 5000)), conley_10km = sqrt(conley(psi, U[, .(x, y)], 10000)))
    stopifnot(abs(se[["grade_2km"]] - r$se_group_crve) < 1e-10)          # confere com o motor
    nclus <- c(grade_2km = uniqueN(U$grade_2km), grade_5km = uniqueN(U$grade_5km), territorio = uniqueN(U$territorio),
               municipio = uniqueN(U$mun), conley_1km = NA, conley_2km = NA, conley_5km = NA, conley_10km = NA)
    ntrat_terr <- uniqueN(U[u_id %in% r$unidades$u_id & place_id %in% d[g > 0, place_id], territorio])
    res[[paste(f, yv)]] <- data.table(faccao = f, outcome = yv, att = att, variancia = names(se), se = as.numeric(se),
                                     p = 2 * pnorm(-abs(att / as.numeric(se))), clusters = as.numeric(nclus),
                                     territorios_com_tratado = ntrat_terr)
    cat(sprintf("%-8s %-18s ATT %+.4f | SE grade2 %.4f grade5 %.4f terr %.4f mun %.4f conley5 %.4f conley10 %.4f\n", f, yv, att,
                se[["grade_2km"]], se[["grade_5km"]], se[["territorio"]], se[["municipio"]], se[["conley_5km"]], se[["conley_10km"]]))
  }
}
fwrite(rbindlist(res), file.path(OUT, "W06_inferencia_espacial.csv"))
cat("OK W06\n")
