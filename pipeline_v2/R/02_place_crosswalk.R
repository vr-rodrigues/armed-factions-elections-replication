# 02_place_crosswalk.R — identificador de local físico (place_id) ligando locais entre anos (2010–2024)
# Regra de ligação entre dois registros local-ano do mesmo município (coordenada,
# nome e endereço). As condições evitam os erros vistos na revisão manual de 100 ligações de uma regra mais
# simples (~10%: prédios distintos com coordenada idêntica imprecisa; agências bancárias homônimas; escola
# estadual x municipal homônimas). sim_n = Jaccard de nomes; sim_e = Jaccard de endereços normalizados;
# conflito = um nome é de escola municipal e o outro de estadual.
#   Anos diferentes:
#     (a1) d <= 30 m, sim_n >= 0.3, sim_e >= 0.3 e sem conflito
#     (a2) d <= 30 m, cada registro é o ÚNICO local naquele ponto no seu ano e sim_e >= 0.6
#          -> mesmo prédio renomeado, mesmo endereço (ex.: "COLEGIO MV1" -> "ZEROHUM", mesmo número)
#     (b)  30 m < d <= 150 m, sim_n >= 0.5, sim_e >= 0.3 e sem conflito
#   Mesmo ano:
#     (s)  d <= 30 m, sim_n >= 0.5, sim_e >= 0.5 e sem conflito -> mesmo prédio servindo duas zonas
#     (a3) d <= 30 m, sim_n >= 0.8, nome distintivo (>= 2 tokens fora da lista genérica: bancos, igreja...)
#          e sem conflito, mesmo com endereço escrito de forma diferente
#   Endereço ausente em um dos registros: exige sim_n >= 0.8 no lugar da condição de endereço.
# Marca coord_possivelmente_herdada: registro cuja coordenada coincide (<= 30 m) com a de OUTRO local físico
#   que usou o mesmo (zona, número) em outro ano -> coordenada antiga provavelmente preenchida com a do prédio novo.
#   Sem coordenada:
#     (c)  mesmo (zona, número) em outro ano e sim_n >= 0.5
# Locais diferentes que compartilham um geocódigo impreciso (mesmo ponto, nomes diferentes, mesmo ano)
# NÃO são ligados; o ponto é marcado como geocódigo impreciso (>= 3 locais no mesmo ano).
# IDs reutilizados para prédios diferentes (mesmo número, > 150 m ou nomes diferentes) NÃO são ligados.
# Saída: OUT_DIR/place_crosswalk.parquet, OUT_DIR/places.parquet, CHECK_DIR/02_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
suppressPackageStartupMessages(library(igraph))
cat("02_place_crosswalk.R\n")

D_SAME <- 30; D_MAX <- 150; SIM_MIN <- 0.5

L <- as.data.table(read_parquet(file.path(OUT_DIR, "locais_ano.parquet")))
setorder(L, ano, mun, zona, numero)
L[, rec := .I]
L[, c("x", "y") := {
  ok <- !is.na(lat)
  xy <- matrix(NA_real_, .N, 2)
  if (any(ok)) xy[ok, ] <- st_coordinates(st_transform(st_as_sf(data.frame(lon = lon[ok], lat = lat[ok]), coords = c("lon", "lat"), crs = 4326), CRS_M))
  list(xy[, 1], xy[, 2])
}]

# --- pares candidatos por proximidade (dentro do município) ---
pares <- rbindlist(lapply(unique(L$mun), function(m) {
  s <- L[mun == m & !is.na(x)]
  if (nrow(s) < 2) return(NULL)
  pts <- st_as_sf(s, coords = c("x", "y"), crs = CRS_M)
  nb <- st_is_within_distance(pts, pts, dist = D_MAX)
  i <- rep(seq_along(nb), lengths(nb)); j <- unlist(nb)
  keep <- i < j
  data.table(a = s$rec[i[keep]], b = s$rec[j[keep]])
}))
L[, end_n := norm_endereco(endereco)]
L[, tipo_escola := tipo_escola(nome)]
GENERICOS <- c("BANCO", "ITAU", "BRADESCO", "CAIXA", "ECONOMICA", "SANTANDER", "BRASIL", "AGENCIA", "HSBC",
               "REAL", "UNIBANCO", "IGREJA", "CATOLICA", "PAROQUIA", "CLUBE", "ASSOCIACAO", "SOCIEDADE", "SA",
               "S", "LTDA", "NSC", "CR", "SC")
L[, nome_distintivo := vapply(strsplit(nome_n, " ", fixed = TRUE), function(t) sum(nzchar(t) & !t %in% GENERICOS & !grepl("^[0-9]+$", t)) >= 2, logical(1))]
pares[, d := sqrt((L$x[a] - L$x[b])^2 + (L$y[a] - L$y[b])^2)]
pares[, sim := jaccard(L$nome_n[a], L$nome_n[b])]
pares[, sim_e := jaccard(L$end_n[a], L$end_n[b])]
pares[, conflito := !is.na(L$tipo_escola[a]) & !is.na(L$tipo_escola[b]) & L$tipo_escola[a] != L$tipo_escola[b]]
pares[, mesmo_ano := L$ano[a] == L$ano[b]]

# nº de OUTROS locais do mesmo ano a <= 30 m de cada registro (geocódigo compartilhado)
viz <- pares[mesmo_ano == TRUE & d <= D_SAME, .(rec = c(a, b))][, .N, by = rec]
L[, n_viz30_mesmo_ano := 0L][viz, n_viz30_mesmo_ano := i.N, on = "rec"]
L[, geocodigo_impreciso := n_viz30_mesmo_ano >= 2]   # >= 3 locais distintos no mesmo ponto

simok <- function(s, m) !is.na(s) & s >= m
pares[, unico_a := L$n_viz30_mesmo_ano[a] == 0L][, unico_b := L$n_viz30_mesmo_ano[b] == 0L]
# condição de endereço: Jaccard >= limiar; se faltar endereço, exige nome muito parecido
end_ok <- function(se, sn, lim) fifelse(is.na(se), simok(sn, 0.8), se >= lim)
pares[, regra := fcase(
  !mesmo_ano & d <= D_SAME & simok(sim, 0.3) & end_ok(sim_e, sim, 0.3) & !conflito,     "a1_dist30_nome_end",
  !mesmo_ano & d <= D_SAME & unico_a & unico_b & !is.na(sim_e) & sim_e >= 0.6,          "a2_dist30_unico_end",
  !mesmo_ano & d <= D_SAME & simok(sim, 0.8) & L$nome_distintivo[a] & L$nome_distintivo[b] & !conflito, "a3_dist30_nome_forte",
  !mesmo_ano & d > D_SAME & simok(sim, SIM_MIN) & end_ok(sim_e, sim, 0.3) & !conflito,  "b_dist150_nome_end",
  mesmo_ano & d <= D_SAME & simok(sim, SIM_MIN) & end_ok(sim_e, sim, 0.5) & !conflito,  "s_mesmo_ano_mesmo_predio",
  default = NA_character_)]
arestas <- pares[!is.na(regra), .(a, b, regra, d, sim)]

# --- registros sem coordenada: mesmo (mun, zona, numero) em outro ano, nome parecido ---
sc <- L[is.na(x)]
if (nrow(sc)) {
  e_sc <- merge(sc[, .(a = rec, mun, zona, numero, nome_n)], L[, .(b = rec, mun, zona, numero, nome_n2 = nome_n)],
                by = c("mun", "zona", "numero"), allow.cartesian = TRUE)[a != b]
  e_sc[, sim := jaccard(nome_n, nome_n2)]
  e_sc <- e_sc[!is.na(sim) & sim >= SIM_MIN, .(a = pmin(a, b), b = pmax(a, b), regra = "c_sem_coord_id_nome", d = NA_real_, sim)]
  arestas <- unique(rbind(arestas, e_sc), by = c("a", "b"))
}

g <- make_graph(as.vector(t(as.matrix(arestas[, .(a, b)]))), n = nrow(L), directed = FALSE)
L[, comp := components(g)$membership]

# place_id estável: município + menor (ano, zona, número) do componente
L[, place_id := {
  o <- order(ano, zona, numero)
  sprintf("%s_%d_%d_%d", mun[1], ano[o][1], zona[o][1], numero[o][1])
}, by = comp]

# --- diagnósticos por local físico ---
P <- L[, {
  ok <- !is.na(x)
  diam <- if (sum(ok) > 1) max(dist(cbind(x[ok], y[ok]))) else 0
  recente <- which(ok)[order(-ano[ok])][1]
  list(mun = mun[1], n_registros = .N, anos = paste(sort(unique(ano)), collapse = ","),
       n_anos = uniqueN(ano), max_reg_por_ano = max(table(ano)), diametro_m = diam,
       n_nomes = uniqueN(nome_n[nzchar(nome_n)]),
       geocodigo_impreciso = any(geocodigo_impreciso),
       lat = if (is.na(recente)) NA_real_ else lat[recente], lon = if (is.na(recente)) NA_real_ else lon[recente],
       nome = nome[order(-ano)][1], endereco = endereco[order(-ano)][1])
}, by = place_id]

# Fusões suspeitas: no mesmo ano, registros de um mesmo local físico com nomes diferentes (encadeamento)
fus <- L[, if (.N > 1) {
  cb <- combn(.N, 2)
  list(min_sim = min(jaccard(nome_n[cb[1, ]], nome_n[cb[2, ]]), na.rm = TRUE), n = .N)
}, by = .(place_id, ano)]
fus <- fus[is.finite(min_sim) & min_sim < SIM_MIN]
fwrite(merge(fus, L[, .(place_id, ano, zona, numero, nome)], by = c("place_id", "ano")),
       file.path(CHECK_DIR, "02_fusoes_suspeitas.csv"))

# Inspeção manual: as fusões suspeitas são quase sempre prédios do mesmo complexo ou contíguos
# (blocos de universidade, CIEP + escola vizinha, agências bancárias lado a lado). Mantidas e marcadas.
P[, fusao_suspeita := place_id %in% fus$place_id]

# Coordenada possivelmente herdada: mesmo (zona, número) em anos diferentes, locais físicos diferentes,
# coordenadas a <= 30 m -> marca o local físico do registro MAIS ANTIGO (coordenada preenchida retroativamente)
her <- merge(L[!is.na(x), .(mun, zona, numero, ano, place_id, x, y)],
             L[!is.na(x), .(mun, zona, numero, ano2 = ano, place2 = place_id, x2 = x, y2 = y)],
             by = c("mun", "zona", "numero"), allow.cartesian = TRUE)[ano < ano2 & place_id != place2]
her <- her[sqrt((x - x2)^2 + (y - y2)^2) <= D_SAME]
P[, coord_possivelmente_herdada := place_id %in% her$place_id]
cat(sprintf("Locais com coordenada possivelmente herdada: %d\n", sum(P$coord_possivelmente_herdada)))

check(!anyDuplicated(L$rec), "registro duplicado")
check(all(P$mun == substr(P$place_id, 1, 5)), "local físico atravessando municípios")

xwalk <- L[, .(ano, mun, zona, numero, place_id)]
setorder(xwalk, ano, mun, zona, numero); setorder(P, place_id)
write_out(xwalk, "place_crosswalk")
write_out(P, "places")

# --- relatórios ---
anos_m <- c("2012", "2016", "2020", "2024")
P[, todos_munic_2012_2024 := vapply(strsplit(anos, ","), function(a) all(anos_m %in% a), logical(1))]
L[, loc_key := paste(mun, zona, numero)]
ids_presentes <- L[ano %in% as.integer(anos_m), .(n = uniqueN(ano)), by = loc_key]
res <- data.table(
  registros_local_ano = nrow(L), locais_fisicos = nrow(P),
  ids_distintos_2010_2024 = uniqueN(L$loc_key),
  arestas_a1 = sum(arestas$regra == "a1_dist30_nome_end"), arestas_a2 = sum(arestas$regra == "a2_dist30_unico_end"),
  arestas_a3 = sum(arestas$regra == "a3_dist30_nome_forte"),
  arestas_b = sum(arestas$regra == "b_dist150_nome_end"), arestas_s = sum(arestas$regra == "s_mesmo_ano_mesmo_predio"),
  arestas_c = sum(arestas$regra == "c_sem_coord_id_nome"),
  locais_geocodigo_impreciso = sum(P$geocodigo_impreciso),
  ids_presentes_2012_2024 = sum(ids_presentes$n == 4),
  locais_fisicos_presentes_2012_2024 = sum(P$todos_munic_2012_2024),
  locais_diametro_maior_150m = sum(P$diametro_m > D_MAX),
  locais_com_mais_de_1_registro_no_ano = sum(P$max_reg_por_ano > 1),
  locais_mais_de_2_nomes = sum(P$n_nomes > 2),
  local_ano_fusao_suspeita = nrow(fus), locais_fusao_suspeita = uniqueN(fus$place_id))
fwrite(res, file.path(CHECK_DIR, "02_resumo.csv"))
print(t(res))
fwrite(P[diametro_m > D_MAX | n_nomes > 2][order(-diametro_m)], file.path(CHECK_DIR, "02_locais_suspeitos.csv"))

# mesmo ID, prédios diferentes (não ligados): reutilização de número
reuso <- merge(L[, .(loc_key, ano, place_id, nome)], L[, .(loc_key, ano2 = ano, place_id2 = place_id, nome2 = nome)],
               by = "loc_key", allow.cartesian = TRUE)[ano < ano2 & place_id != place_id2]
fwrite(unique(reuso, by = c("loc_key", "place_id", "place_id2")), file.path(CHECK_DIR, "02_ids_reutilizados.csv"))
cat(sprintf("IDs reutilizados para locais físicos diferentes: %d\n", uniqueN(reuso$loc_key)))

# amostra para validação manual: ligações entre IDs diferentes
set.seed(20261009)
lig <- arestas[L$loc_key[a] != L$loc_key[b]]
amostra <- lig[sample(.N, min(100, .N))]
amostra <- cbind(amostra, L[amostra$a, .(ano_a = ano, id_a = loc_key, nome_a = nome, end_a = endereco)],
                 L[amostra$b, .(ano_b = ano, id_b = loc_key, nome_b = nome, end_b = endereco)])
amostra[, ok_manual := NA]
fwrite(amostra, file.path(CHECK_DIR, "02_amostra_validacao_manual.csv"))
cat("OK 02\n")
