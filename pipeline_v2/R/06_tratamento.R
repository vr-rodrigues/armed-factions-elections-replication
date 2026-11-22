# 06_tratamento.R — exposição anual e coortes de tratamento por local físico
# Camada "controle" dos mapas anuais 2007–2024 (Fogo Cruzado/GENI); coordenada canônica do local físico.
# Regras:
#   entrada  = 1º ano de mapa em que o local está dentro de um polígono de controle (qualquer facção)
#   facção   = facção do polígono NO ANO DE ENTRADA (Milícia vs. tráfico = CV/TCP/ADA), sem informação futura
#   sempre tratado = dentro já no 1º mapa (2007): censurado à esquerda, excluído das estimativas
#   coorte (principal, timing Y-1) = 1ª eleição Y do calendário com entrada <= Y-1
#   coorte (robustez,  timing Y)   = 1ª eleição Y do calendário com entrada <= Y
#   ITT a partir da 1ª entrada; saídas posteriores registradas (para robustez)
#   nunca tratado = nunca dentro de controle 2007–2024 (variante: nem de influência)
# Saída: OUT_DIR/exposicao_anual.parquet, OUT_DIR/tratamento_place.parquet, CHECK_DIR/06_*.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
sf_use_s2(FALSE)
cat("06_tratamento.R\n")
MAPS <- file.path(AFE_DADOS, "mapas_anuais")
ANOS_MAPA <- 2007:2024

P <- as.data.table(read_parquet(file.path(OUT_DIR, "places.parquet")))
P <- P[!is.na(lat)]
pts <- st_transform(st_as_sf(P[, .(place_id, lon, lat)], coords = c("lon", "lat"), crs = 4326), CRS_M)
xy <- st_coordinates(pts); P[, `:=`(x = xy[, 1], y = xy[, 2])]

le_camada <- function(ano, camada) {
  g <- st_read(file.path(MAPS, sprintf("%d_%s.geojson", ano, camada)), quiet = TRUE)
  g <- st_transform(st_make_valid(g), CRS_M)
  g$faccao_esp <- if ("Grupo_Armado_soControle" %in% names(g)) g$Grupo_Armado_soControle else g[[grep("Grupo", names(g))[1]]]
  g[, c("faccao_esp", "mvFeatureId")]
}

expo <- list(); dist_env <- list()
for (a in ANOS_MAPA) {
  ctrl <- le_camada(a, "controle"); infl <- le_camada(a, "influencia")
  j <- st_join(pts, ctrl, join = st_within, left = TRUE)
  j <- as.data.table(st_drop_geometry(j))
  n_pol <- j[!is.na(faccao_esp), .N, by = place_id]
  j <- j[!duplicated(place_id)]
  ji <- as.data.table(st_drop_geometry(st_join(pts, infl, join = st_within, left = TRUE)))[!duplicated(place_id)]
  expo[[as.character(a)]] <- data.table(place_id = j$place_id, ano_mapa = a,
                                        dentro_controle = !is.na(j$faccao_esp), faccao_esp = j$faccao_esp,
                                        poligono_id = as.character(j$mvFeatureId),
                                        dentro_influencia = !is.na(ji$faccao_esp),
                                        n_poligonos = n_pol[match(j$place_id, n_pol$place_id), N])
  # distância ao polígono de controle mais próximo, por tipo de facção
  for (tp in c("milicia", "trafico")) {
    sel <- if (tp == "milicia") ctrl$faccao_esp == "Milícia" else ctrl$faccao_esp %in% c("CV", "TCP", "ADA")
    if (!any(sel)) next
    pol <- ctrl[sel, ]
    idx <- st_nearest_feature(pts, pol)
    dist_env[[paste(a, tp)]] <- data.table(place_id = P$place_id, tipo = tp, ano_mapa = a,
                                           dist = as.numeric(st_distance(pts, pol[idx, ], by_element = TRUE)))
  }
  cat(sprintf("  %d: %d dentro de controle (%d milícia), %d dentro de influência\n", a,
              sum(expo[[as.character(a)]]$dentro_controle), sum(expo[[as.character(a)]]$faccao_esp == "Milícia", na.rm = TRUE),
              sum(expo[[as.character(a)]]$dentro_influencia)))
}
E <- rbindlist(expo)
E[, faccao := fcase(faccao_esp == "Milícia", "milicia", faccao_esp %in% c("CV", "TCP", "ADA"), "trafico", default = NA_character_)]
check(E[, all(is.na(n_poligonos) | n_poligonos >= 1)], "contagem de polígonos inválida")
setorder(E, place_id, ano_mapa)
write_out(E, "exposicao_anual")

# envelope: distância mínima, em qualquer ano, ao território de cada tipo (0 se esteve dentro)
DE <- rbindlist(dist_env)[, .(dist_envelope_m = min(dist)), by = .(place_id, tipo)]
DE <- dcast(DE, place_id ~ tipo, value.var = "dist_envelope_m")
setnames(DE, c("milicia", "trafico"), c("dist_env_milicia_m", "dist_env_trafico_m"))

# ---- coortes ----
coorte <- function(entrada, calendario, defasagem) {
  vapply(entrada, function(e) {
    if (is.na(e)) return(NA_integer_)
    ok <- calendario[calendario - defasagem >= e]
    if (length(ok)) as.integer(min(ok)) else NA_integer_
  }, integer(1))
}
T <- E[, {
  dentro <- which(dentro_controle)
  e <- if (length(dentro)) ano_mapa[dentro[1]] else NA_integer_
  pos <- if (!is.na(e)) which(ano_mapa >= e) else integer(0)
  list(entrada = e,
       faccao_entrada = if (!is.na(e)) faccao[dentro[1]] else NA_character_,
       faccao_esp_entrada = if (!is.na(e)) faccao_esp[dentro[1]] else NA_character_,
       poligono_entrada = if (!is.na(e)) poligono_id[dentro[1]] else NA_character_,
       anos_dentro_pos_entrada = if (length(pos)) sum(dentro_controle[pos]) else NA_integer_,
       anos_pos_entrada = length(pos),
       sai_depois = if (length(pos)) any(!dentro_controle[pos]) else NA,
       troca_faccao_depois = if (length(pos)) any(!is.na(faccao[pos]) & faccao[pos] != faccao[dentro[1]]) else NA,
       ultimo_ano_dentro = if (length(dentro)) max(ano_mapa[dentro]) else NA_integer_,
       sempre_influencia_ou_controle = any(dentro_controle | dentro_influencia))
}, by = place_id]
T[, sempre_tratado := !is.na(entrada) & entrada == min(ANOS_MAPA)]
T[, nunca_tratado := is.na(entrada)]
T[, nunca_tratado_estrito := nunca_tratado & !sempre_influencia_ou_controle]
CAL_M <- ANOS_MUNICIPAIS; CAL_B <- sort(c(ANOS_GERAIS, ANOS_MUNICIPAIS))
T[, `:=`(g_mun_lag  = coorte(entrada, CAL_M, 1L), g_mun_mesmo  = coorte(entrada, CAL_M, 0L),
         g_bien_lag = coorte(entrada, CAL_B, 1L), g_bien_mesmo = coorte(entrada, CAL_B, 0L))]
# entrada depois do fim do painel: tratada fora da janela (controle "ainda não tratado" em toda a janela)
T[, trat_pos_painel := !is.na(entrada) & is.na(g_mun_lag)]

T <- merge(P[, .(place_id, mun, x, y, geocodigo_impreciso, fusao_suspeita, n_anos, anos)], T, by = "place_id")
T <- merge(T, DE, by = "place_id", all.x = TRUE)
T[, `:=`(grade_1km = sprintf("%d_%d", floor(x / 1000), floor(y / 1000)),
         grade_2km = sprintf("%d_%d", floor(x / 2000), floor(y / 2000)),
         grade_5km = sprintf("%d_%d", floor(x / 5000), floor(y / 5000)))]
setorder(T, place_id)
write_out(T, "tratamento_place")

# ---- relatórios ----
tab <- T[, .N, by = .(status = fcase(sempre_tratado, "sempre tratado (2007)", nunca_tratado, "nunca tratado",
                                     trat_pos_painel, "entra após o painel", default = "tratado no painel"),
                      faccao_entrada, g_mun_lag)][order(status, faccao_entrada, g_mun_lag)]
fwrite(tab, file.path(CHECK_DIR, "06_coortes_municipais.csv")); print(tab)
fwrite(T[!is.na(entrada) & !sempre_tratado, .(n = .N, sai_depois = sum(sai_depois), troca_faccao = sum(troca_faccao_depois),
                                             share_anos_dentro = round(sum(anos_dentro_pos_entrada) / sum(anos_pos_entrada), 3)),
         by = faccao_entrada], file.path(CHECK_DIR, "06_trajetoria_pos_entrada.csv"))
cmp <- T[!is.na(g_mun_lag) & !sempre_tratado, .(muda_coorte_timing = sum(g_mun_lag != g_mun_mesmo, na.rm = TRUE), n = .N), by = faccao_entrada]
fwrite(cmp, file.path(CHECK_DIR, "06_timing_lag_vs_mesmo.csv")); print(cmp)
print(fread(file.path(CHECK_DIR, "06_trajetoria_pos_entrada.csv")))
cat("OK 06\n")
