# 10_captacao.R — tratamento pela área de captação do local de votação
# 1. Para cada eleição municipal Y (2008–2024): Voronoi dos locais físicos ativos em Y (com coordenada canônica),
#    por município, recortado pelo limite municipal (geobr). Locais no mesmo ponto dividem a mesma célula.
# 2. População do setor censitário repartida entre as células pela área de interseção (densidade uniforme no setor):
#    Censo 2010 (principal) e Censo 2022 (robustez).
# 3. Exposição do local i ao mapa anual m (camada "controle", 2007–2024), por tipo de facção = share da população da
#    célula dentro de polígonos de controle daquele tipo. O mapa m usa a célula da 1ª eleição municipal > m em que o
#    local está ativo (m = 2024: eleição de 2024); se o local não está ativo nela, a eleição ativa mais próxima.
#    Robustez sem população: share da ÁREA de um raio de 500 m em volta do local.
# 4. Entrada = 1º mapa com exposição (qualquer facção) >= limiar (0,5 principal; 0,25 e 0,75 robustez);
#    facção na entrada = a de maior exposição naquele mapa; demais regras iguais ao 06 (Y−1, ITT, sempre tratado se
#    entra em 2007, nunca tratado se nunca atinge o limiar, coortes municipais e bienais).
# Saída: EXT_DIR/captacao_exposicao.parquet, EXT_DIR/captacao_tratamento.parquet; CHECK_EXT/10_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config_ext.R"))
sf_use_s2(FALSE)
cat("10_captacao.R\n")
ANOS_MAPA <- 2007:2024
ELEI <- ANOS_MUNICIPAIS

P <- read_snap("places")[!is.na(lat)]
pts <- st_transform(st_as_sf(P[, .(place_id, mun, lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_M)
xy <- st_coordinates(pts); P[, `:=`(x = round(xy[, 1], 1), y = round(xy[, 2], 1))]
ativos <- unique(read_snap("detalhes_place")[versao == "principal" & ano %in% ELEI & aptos > 0, .(ano, place_id)])
ativos <- merge(ativos, P[, .(place_id, mun, x, y)], by = "place_id")

MG <- read_bd2("municipios_geo")
MG <- st_make_valid(st_transform(st_make_valid(st_as_sf(MG, wkt = "wkt", crs = 4326)), CRS_M))   # válido de novo após reprojetar
MG$tse <- MUN$tse[match(MG$id_municipio, MUN$ibge)]
check(all(MUN$tse %in% MG$tse), "limite municipal ausente")

le_setores <- function(nome) {
  s <- read_bd2(nome)[!is.na(wkt)]
  s <- st_make_valid(st_transform(st_make_valid(st_as_sf(s, wkt = "wkt", crs = 4326)), CRS_M))
  s <- s[!st_is_empty(s), ]
  s$area_setor <- as.numeric(st_area(s)); s$populacao[is.na(s$populacao)] <- 0
  s$tse <- MUN$tse[match(s$id_municipio, MUN$ibge)]
  s[, c("id_setor_censitario", "tse", "populacao", "area_setor")]
}
SET <- list(c2010 = le_setores("setores_2010"), c2022 = le_setores("setores_2022"))
pop_tot <- rbindlist(lapply(names(SET), function(k) data.table(censo = k, tse = SET[[k]]$tse, pop = SET[[k]]$populacao))
                     )[, .(pop = sum(pop)), by = .(censo, tse)]
fwrite(dcast(pop_tot, tse ~ censo, value.var = "pop"), file.path(CHECK_EXT, "10_populacao_por_municipio.csv"))

# ---- células de Voronoi por eleição e município ----
voronoi_mun <- function(a, m) {
  g <- unique(ativos[ano == a & mun == m, .(x, y)])
  lim <- MG[MG$tse == m, ]
  if (nrow(g) == 1) { cel <- st_sf(geometry = st_geometry(lim)); cel$x <- g$x; cel$y <- g$y; return(cel) }
  mp <- st_multipoint(as.matrix(g[, .(x, y)]))
  env <- st_as_sfc(st_bbox(st_buffer(st_geometry(lim), 5000)))
  v <- st_collection_extract(st_voronoi(st_sfc(mp, crs = CRS_M), envelope = env), "POLYGON")
  v <- st_sf(geometry = v)
  gp <- st_as_sf(g, coords = c("x", "y"), crs = CRS_M, remove = FALSE)
  v <- st_join(v, gp, join = st_contains)
  check(!anyNA(v$x) && nrow(v) == nrow(g), sprintf("Voronoi %d %s: células sem gerador", a, m))
  st_make_valid(suppressWarnings(st_intersection(v, st_geometry(lim))))
}
CEL <- list()
for (a in ELEI) {
  cs <- do.call(rbind, lapply(sort(unique(ativos[ano == a, mun])), function(m) { v <- voronoi_mun(a, m); v$tse <- m; v }))
  cs$ano <- a; CEL[[as.character(a)]] <- cs
  cat(sprintf("  %d: %d células\n", a, nrow(cs)))
}

# pedaços célula x setor com população (para cada censo)
pedacos <- function(cel, setores) {
  out <- list()
  for (m in unique(cel$tse)) {
    pz <- suppressWarnings(st_intersection(cel[cel$tse == m, c("x", "y")], setores[setores$tse == m, ]))
    pz <- pz[st_dimension(pz) == 2, ]
    if (!nrow(pz)) next
    pz$pop <- pz$populacao * as.numeric(st_area(pz)) / pz$area_setor
    out[[m]] <- pz[, c("x", "y", "pop")]
  }
  do.call(rbind, out)
}

# camadas de controle por ano e tipo de facção (como no 06)
le_ctrl <- function(a) {
  g <- st_read(file.path(MAPS_ANUAIS, sprintf("%d_controle.geojson", a)), quiet = TRUE)
  g <- st_make_valid(st_transform(st_make_valid(g), CRS_M))
  fe <- if ("Grupo_Armado_soControle" %in% names(g)) g$Grupo_Armado_soControle else g[[grep("Grupo", names(g))[1]]]
  tp <- ifelse(fe == "Milícia", "milicia", ifelse(fe %in% c("CV", "TCP", "ADA"), "trafico", NA))
  list(milicia = st_make_valid(st_union(st_geometry(g)[tp %in% "milicia"])), trafico = st_make_valid(st_union(st_geometry(g)[tp %in% "trafico"])))
}
CTRL <- setNames(lapply(ANOS_MAPA, le_ctrl), ANOS_MAPA)

# share (populacional) de cada célula dentro de um polígono
expo_pedacos <- function(pz, pol) {
  base <- as.data.table(st_drop_geometry(pz))[, .(pop_tot = sum(pop)), by = .(x, y)]
  if (length(pol) == 0 || st_is_empty(pol)) return(base[, .(x, y, pop_tot, expo = 0)])
  hit <- lengths(st_intersects(pz, pol)) > 0
  dentro <- data.table(x = numeric(0), y = numeric(0), pop_in = numeric(0))
  if (any(hit)) {
    q <- pz[hit, ]; q$area_q <- as.numeric(st_area(q))
    qi <- suppressWarnings(st_intersection(q, pol))
    qi <- qi[st_dimension(qi) == 2, ]
    if (nrow(qi)) dentro <- as.data.table(st_drop_geometry(qi))[, .(x, y, pop_in = pop * as.numeric(st_area(qi)) / area_q)][, .(pop_in = sum(pop_in)), by = .(x, y)]
  }
  r <- merge(base, dentro, by = c("x", "y"), all.x = TRUE)[is.na(pop_in), pop_in := 0]
  r[, .(x, y, pop_tot, expo = fifelse(pop_tot > 0, pmin(pop_in / pop_tot, 1), NA_real_))]
}

# eleição cuja célula vale para o mapa m: 1ª eleição municipal > m (m = 2024 -> 2024)
eleicao_do_mapa <- function(m) if (m >= 2024) 2024L else as.integer(min(ELEI[ELEI > m]))
# de ponto da célula (x, y) para local; local inativo na eleição da célula -> eleição ativa mais próxima
mapa_local <- ativos[, .(place_id, ano, x, y)]
todos <- CJ(place_id = unique(ativos$place_id), ano_mapa = ANOS_MAPA)
todos[, eleicao_alvo := vapply(ano_mapa, eleicao_do_mapa, integer(1))]
at <- unique(ativos[, .(place_id, ano)])
todos <- merge(todos, at[, .(anos_ativos = list(sort(ano))), by = place_id], by = "place_id")
todos[, eleicao_celula := mapply(function(alvo, aa) { aa <- unlist(aa); aa[order(abs(aa - alvo), -aa)][1] }, eleicao_alvo, anos_ativos)]
todos[, anos_ativos := NULL]
todos <- merge(todos, mapa_local, by.x = c("place_id", "eleicao_celula"), by.y = c("place_id", "ano"))
EX <- list()
for (k in names(SET)) {
  PZ <- setNames(lapply(ELEI, function(a) pedacos(CEL[[as.character(a)]], SET[[k]])), ELEI)
  for (m in ANOS_MAPA) for (a in sort(unique(todos[ano_mapa == m, eleicao_celula]))) {
    # a = eleição da célula: a 1ª eleição > m, ou a eleição ativa mais próxima para quem não estava ativo nela
    for (tp in c("milicia", "trafico")) {
      e <- expo_pedacos(PZ[[as.character(a)]], CTRL[[as.character(m)]][[tp]])
      EX[[paste(k, m, a, tp)]] <- e[, `:=`(medida = k, ano_mapa = m, eleicao_celula = a, tipo = tp)]
    }
  }
  cat(sprintf("  exposição (%s) pronta\n", k))
}
EX <- rbindlist(EX)
EXP <- rbindlist(lapply(c("c2010", "c2022"), function(k) {
  e <- dcast(EX[medida == k], x + y + ano_mapa + eleicao_celula ~ tipo, value.var = "expo")
  merge(todos, e, by = c("x", "y", "ano_mapa", "eleicao_celula"), all.x = TRUE)[, medida := k]
}))

# robustez: share da área de um raio de 500 m dentro do polígono (sem população)
buf <- st_buffer(pts, 500); buf$area_b <- as.numeric(st_area(buf))
EB <- rbindlist(lapply(ANOS_MAPA, function(m) {
  r <- data.table(place_id = buf$place_id, ano_mapa = m)
  for (tp in c("milicia", "trafico")) {
    pol <- CTRL[[as.character(m)]][[tp]]; v <- rep(0, nrow(buf))
    if (length(pol) && !st_is_empty(pol)) {
      hit <- which(lengths(st_intersects(buf, pol)) > 0)
      if (length(hit)) { qi <- suppressWarnings(st_intersection(buf[hit, ], pol)); v[match(qi$place_id, buf$place_id)] <- as.numeric(st_area(qi)) / qi$area_b }
    }
    set(r, j = tp, value = pmin(v, 1))
  }
  r
}))[, medida := "buffer500"]
EXP <- rbind(EXP[, .(place_id, ano_mapa, medida, milicia, trafico, eleicao_celula)],
             EB[, .(place_id, ano_mapa, medida, milicia, trafico, eleicao_celula = NA_integer_)])
check(EXP[!is.na(milicia), all(milicia >= 0 & milicia <= 1 & trafico >= 0 & trafico <= 1)], "exposição fora de [0,1]")
na_exp <- EXP[, .(linhas = .N, sem_exposicao = sum(is.na(milicia)), locais_sem_nenhuma = sum(tapply(is.na(milicia), place_id, all))), by = medida]
fwrite(na_exp, file.path(CHECK_EXT, "10_exposicao_ausente.csv")); print(na_exp)   # ausente = célula sem população ou fora do limite
setorder(EXP, medida, place_id, ano_mapa)
write_ext(EXP, "captacao_exposicao")

# ---- entrada, facção e coortes (mesmas regras do 06) ----
coorte <- function(entrada, calendario, defasagem) vapply(entrada, function(e) {
  if (is.na(e)) return(NA_integer_); ok <- calendario[calendario - defasagem >= e]
  if (length(ok)) as.integer(min(ok)) else NA_integer_ }, integer(1))
CAL_B <- sort(c(ANOS_GERAIS, ANOS_MUNICIPAIS))
TRT <- rbindlist(lapply(c("c2010", "c2022", "buffer500"), function(k) rbindlist(lapply(c(0.25, 0.5, 0.75), function(t) {
  e <- EXP[medida == k][order(place_id, ano_mapa)]
  e[, ex := pmax(milicia, trafico, na.rm = TRUE)]
  e[, {
    d <- which(!is.na(ex) & ex >= t); en <- if (length(d)) ano_mapa[d[1]] else NA_integer_
    list(entrada = en, faccao_entrada = if (length(d)) (if (milicia[d[1]] >= trafico[d[1]]) "milicia" else "trafico") else NA_character_,
         expo_max = max(ex, na.rm = TRUE), anos_sem_expo = sum(is.na(ex)))
  }, by = place_id][, `:=`(medida = k, limiar = t)]
}))))
TRT[, sempre_tratado := !is.na(entrada) & entrada == min(ANOS_MAPA)]
TRT[, nunca_tratado := is.na(entrada)]
TRT[, `:=`(g_mun_lag = coorte(entrada, ELEI, 1L), g_bien_lag = coorte(entrada, CAL_B, 1L))]
TRT[, trat_pos_painel := !is.na(entrada) & is.na(g_mun_lag)]
setorder(TRT, medida, limiar, place_id)
write_ext(TRT, "captacao_tratamento")

# ---- relatório: captação (principal) x ponto (06) ----
T6 <- read_snap("tratamento_place")[, .(place_id, faccao_ponto = faccao_entrada, g_ponto = g_mun_lag, sempre_ponto = sempre_tratado, nunca_ponto = nunca_tratado)]
cmp <- merge(TRT[medida == "c2010" & limiar == 0.5], T6, by = "place_id")
cmp[, status_ponto := fcase(sempre_ponto, "sempre", nunca_ponto, "nunca", !is.na(g_ponto), paste(faccao_ponto, g_ponto), default = paste(faccao_ponto, "pos"))]
cmp[, status_capt := fcase(sempre_tratado, "sempre", nunca_tratado, "nunca", !is.na(g_mun_lag), paste(faccao_entrada, g_mun_lag), default = paste(faccao_entrada, "pos"))]
tab <- cmp[, .N, by = .(status_ponto, status_capt)][order(status_ponto, -N)]
fwrite(tab, file.path(CHECK_EXT, "10_ponto_x_captacao.csv"))
res <- cmp[, .(locais = .N, mesmo_status = sum(status_ponto == status_capt)), by = .(faccao_ponto)]
fwrite(res, file.path(CHECK_EXT, "10_concordancia.csv"))
dist <- TRT[limiar == 0.5, .(locais = .N, tratados_painel = sum(!is.na(g_mun_lag) & !sempre_tratado), sempre = sum(sempre_tratado),
                             nunca = sum(nunca_tratado), expo_max_media = round(mean(expo_max), 3)), by = medida]
fwrite(dist, file.path(CHECK_EXT, "10_resumo_por_medida.csv"))
options(width = 200); print(dcast(pop_tot, tse ~ censo, value.var = "pop")); print(dist); print(res)
print(tab[N >= 10])
cat("OK 10\n")
