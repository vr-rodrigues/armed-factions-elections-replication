# 03_secao_place.R — mapa seção -> local físico para todos os anos (2006–2024)
# 2010–2024: secao_local (TSE/BD) + place_crosswalk.
# 2008: não há tabela de locais. Regras, em ordem:
#   (1) mesma (mun, zona, seção) em 2010 -> local físico de 2010, aceito se QUALQUER geocódigo da seção em 2008
#       (BD local_secao: "melhor_urbano", majoritariamente Google; "tse_distribuido", de origem TSE)
#       estiver a <= 500 m do local (ou se não houver geocódigo);
#   (2) senão, local físico mais próximo de um geocódigo de 2008, se a <= 100 m;
#   (3) senão, se houver seção de mesmo número em 2010: local de 2010 com marca "secao_2010_nao_validada"
#       (excluída na especificação principal; incluída na robustez);
#   (4) senão, sem local.
# Inspeção manual: das seções rejeitadas por (1) só com "melhor_urbano", a maioria tinha geocódigo
# Google ~900 m errado; a coordenada de origem TSE, quando existe, costuma confirmar o local de 2010.
# 2006 (eleição geral): mesma (mun, zona, seção) em 2008 (já mapeada e validada) -> principal; na falta, mesma
#   seção em 2010 -> "secao_2010_nao_validada" (só na versão robusta, coerente com 2008); sem validação
#   espacial (não há geocódigo de 2006).
# Saída: OUT_DIR/secao_place.parquet, CHECK_DIR/03_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
cat("03_secao_place.R\n")
D_VALID <- 500; D_NEAR <- 100

S  <- as.data.table(read_parquet(file.path(OUT_DIR, "secao_local.parquet")))
X  <- as.data.table(read_parquet(file.path(OUT_DIR, "place_crosswalk.parquet")))
P  <- as.data.table(read_parquet(file.path(OUT_DIR, "places.parquet")))
sp <- merge(S, X, by = c("ano", "mun", "zona", "numero"))[, .(ano, mun, zona, secao, place_id, metodo = "tse_local")]
check(nrow(sp) == nrow(S), "seções 2010–2024 sem local físico")

# universo de seções com votação (detalhes, 1º turno, eleição ordinária)
det <- read_bd("detalhes_votacao_secao")
det <- det[turno == 1 & tipo_eleicao == "eleicao ordinaria" & id_municipio_tse %in% MUN$tse]
secoes <- unique(det[, .(ano, mun = id_municipio_tse, id_municipio, zona = as.integer(zona), secao = as.integer(secao))])

pxy <- P[!is.na(lat)]
pxy[, c("x", "y") := as.data.table(st_coordinates(st_transform(st_as_sf(pxy, coords = c("lon", "lat"), crs = 4326), CRS_M)))]

# ---- 2008 ----
s08 <- secoes[ano == 2008]
geo <- as.data.table(read_parquet(file.path(BD_DIR, "local_secao", "local_secao_2008.parquet")))
geo <- geo[, .(id_municipio, zona = as.integer(zona), secao = as.integer(secao),
                glat = lat_melhor_urbano, glon = lon_melhor_urbano, tlat = lat_tse_distribuido, tlon = lon_tse_distribuido)]
s08 <- merge(s08, geo, by = c("id_municipio", "zona", "secao"), all.x = TRUE)
to_xy <- function(dt, la, lo, nx, ny) {
  dt[, c(nx, ny) := list(NA_real_, NA_real_)]
  ok <- !is.na(dt[[la]])
  if (any(ok)) dt[ok, c(nx, ny) := as.data.table(st_coordinates(st_transform(st_as_sf(dt[ok], coords = c(lo, la), crs = 4326), CRS_M)))]
}
to_xy(s08, "glat", "glon", "gx", "gy")
to_xy(s08, "tlat", "tlon", "tx", "ty")

s08 <- merge(s08, sp[ano == 2010, .(mun, zona, secao, place_2010 = place_id)], by = c("mun", "zona", "secao"), all.x = TRUE)
s08 <- merge(s08, pxy[, .(place_2010 = place_id, px = x, py = y)], by = "place_2010", all.x = TRUE)
s08[, d_google := sqrt((gx - px)^2 + (gy - py)^2)][, d_tse := sqrt((tx - px)^2 + (ty - py)^2)]
s08[, d_2010 := pmin(d_google, d_tse, na.rm = TRUE)]
s08[, metodo := fcase(!is.na(place_2010) & (is.na(d_2010) | d_2010 <= D_VALID), "secao_2010_validada",
                      default = NA_character_)]
s08[metodo == "secao_2010_validada", place_id := place_2010]

# (2) vizinho mais próximo de qualquer geocódigo, dentro do município
nn_de <- function(f, cx, cy) {
  cand <- pxy[mun == f$mun[1]]
  idx <- st_nearest_feature(st_as_sf(f, coords = c(cx, cy), crs = CRS_M), st_as_sf(cand, coords = c("x", "y"), crs = CRS_M))
  data.table(mun = f$mun, zona = f$zona, secao = f$secao, place_nn = cand$place_id[idx],
             d_nn = sqrt((f[[cx]] - cand$x[idx])^2 + (f[[cy]] - cand$y[idx])^2))
}
nn <- rbind(
  rbindlist(lapply(split(s08[is.na(metodo) & !is.na(gx)], by = "mun"), nn_de, "gx", "gy")),
  rbindlist(lapply(split(s08[is.na(metodo) & !is.na(tx)], by = "mun"), nn_de, "tx", "ty")))
if (nrow(nn)) {
  nn <- nn[order(d_nn)][!duplicated(nn[order(d_nn), .(mun, zona, secao)])]
  s08 <- merge(s08, nn, by = c("mun", "zona", "secao"), all.x = TRUE)
  s08[is.na(metodo) & !is.na(d_nn) & d_nn <= D_NEAR, `:=`(place_id = place_nn, metodo = "geocodigo_vizinho_100m")]
}
# (3) casamento por número de seção sem validação espacial (marcado)
s08[is.na(metodo) & !is.na(place_2010), `:=`(place_id = place_2010, metodo = "secao_2010_nao_validada")]
s08[is.na(metodo), metodo := "sem_local"]

# ---- 2006 ----
s06 <- secoes[ano == 2006]
s06 <- merge(s06, s08[metodo %in% c("secao_2010_validada", "geocodigo_vizinho_100m"), .(mun, zona, secao, p08 = place_id)],
             by = c("mun", "zona", "secao"), all.x = TRUE)
s06 <- merge(s06, sp[ano == 2010, .(mun, zona, secao, p10 = place_id)], by = c("mun", "zona", "secao"), all.x = TRUE)
s06[, place_id := fcoalesce(p08, p10)]
s06[, metodo := fcase(!is.na(p08), "secao_2008", !is.na(p10), "secao_2010_nao_validada", default = "sem_local")]  # 2006 via 2010 só por número: robusta (coerente com 2008)

out <- rbind(sp[ano >= 2010],
             s08[, .(ano, mun, zona, secao, place_id, metodo)],
             s06[, .(ano, mun, zona, secao, place_id, metodo)])
# seções com votação 2010–2024 que não estão na tabela de locais
falt_tse <- secoes[ano >= 2010][!out, on = .(ano, mun, zona, secao)]
setorder(out, ano, mun, zona, secao)
check(!anyDuplicated(out[, .(ano, mun, zona, secao)]), "seção duplicada no mapa")
write_out(out, "secao_place")

# ---- relatórios ----
res <- out[, .N, by = .(ano, metodo)][order(ano, metodo)]
fwrite(res, file.path(CHECK_DIR, "03_metodo_por_ano.csv")); print(res)
cat(sprintf("Seções com votação 2010–2024 ausentes da tabela de locais: %d\n", nrow(falt_tse)))
apt <- merge(det[cargo %in% c("prefeito", "governador"), .(aptos = sum(aptos)), by = .(ano, mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao))],
             out[, .(ano, mun, zona, secao, metodo)], by = c("ano", "mun", "zona", "secao"), all.x = TRUE)
cob <- apt[, .(aptos_total = sum(aptos),
               share_aptos_local_principal = sum(aptos[!is.na(metodo) & !metodo %in% c("sem_local", "secao_2010_nao_validada")]) / sum(aptos),
               share_aptos_local_incl_nao_validada = sum(aptos[!is.na(metodo) & metodo != "sem_local"]) / sum(aptos)), by = ano][order(ano)]
fwrite(cob, file.path(CHECK_DIR, "03_cobertura_aptos.csv")); print(cob)
cat("Distância geocódigo 2008 -> local 2010 (seções casadas por zona/seção), quantis (m):\n")
print(round(quantile(s08$d_2010, c(.5, .75, .9, .95, .99), na.rm = TRUE)))
cat("OK 03\n")
