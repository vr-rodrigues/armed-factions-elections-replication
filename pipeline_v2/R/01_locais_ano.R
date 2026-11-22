# 01_locais_ano.R — locais de votação por ano (2010–2024) e mapa seção → local
# Entrada: BD perfil_eleitorado_local_votacao (1º turno)
# Saída:   OUT_DIR/locais_ano.parquet, OUT_DIR/secao_local.parquet, CHECK_DIR/01_locais_ano.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
cat("01_locais_ano.R\n")

pl <- read_bd("perfil_eleitorado_local_votacao")
pl <- pl[turno == 1 & id_municipio_tse %in% MUN$tse]
pl[, `:=`(mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), numero = as.integer(numero))]
check(!anyNA(pl[, .(zona, secao, numero)]), "zona/seção/número com NA ou não numéricos")

# Coordenadas válidas: dentro de uma caixa ampla do estado do RJ
pl[, coord_ok := !is.na(latitude) & !is.na(longitude) &
                 latitude > -23.5 & latitude < -20.7 & longitude > -45.0 & longitude < -40.9]
pl[!(coord_ok), `:=`(latitude = NA_real_, longitude = NA_real_)]

# Seção → local (cada seção deve estar em um único local por ano)
secao_local <- unique(pl[, .(ano, mun, zona, secao, numero, tipo_secao_agregada)])
dup <- secao_local[, .N, by = .(ano, mun, zona, secao)][N > 1]
check(nrow(dup) == 0, sprintf("%d seções aparecem em mais de um local no mesmo ano", nrow(dup)))

moda <- function(x) { x <- x[!is.na(x) & nzchar(x)]; if (!length(x)) NA_character_ else names(sort(table(x), decreasing = TRUE))[1] }
# coordenada do local-ano = par (lat, lon) mais frequente entre as seções (desempate: menor lat, depois menor lon);
# evita o artefato de ponto médio da mediana por eixo quando as seções têm coordenadas diferentes
coord_moda <- function(la, lo) {
  ok <- !is.na(la); if (!any(ok)) return(list(NA_real_, NA_real_))
  t <- data.table(la = la[ok], lo = lo[ok])[, .N, by = .(la, lo)][order(-N, la, lo)]
  list(t$la[1], t$lo[1])
}
locais <- pl[, .(nome = moda(nome), endereco = moda(endereco), bairro = moda(bairro),
                 lat = coord_moda(latitude, longitude)[[1]], lon = coord_moda(latitude, longitude)[[2]],
                 n_coord_distintas = uniqueN(paste(round(latitude, 5), round(longitude, 5))[!is.na(latitude)]),
                 n_secoes = .N, eleitores = sum(eleitores_secao, na.rm = TRUE)),
             by = .(ano, mun, zona, numero)]
locais[is.nan(lat), `:=`(lat = NA_real_, lon = NA_real_)]
locais[, nome_n := norm_nome(nome)]
setorder(locais, ano, mun, zona, numero)
setorder(secao_local, ano, mun, zona, secao)
check(!anyDuplicated(locais[, .(ano, mun, zona, numero)]), "chave de local duplicada")

write_out(locais, "locais_ano")
write_out(secao_local, "secao_local")

resumo <- locais[, .(locais = .N, secoes = sum(n_secoes), eleitores = sum(eleitores),
                     sem_coord = sum(is.na(lat)), coord_multiplas = sum(n_coord_distintas > 1)), by = ano]
fwrite(resumo, file.path(CHECK_DIR, "01_locais_ano.csv"))
print(resumo)
cat("OK 01\n")
