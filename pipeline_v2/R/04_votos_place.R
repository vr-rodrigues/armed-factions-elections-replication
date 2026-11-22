# 04_votos_place.R — agrega votos e comparecimento das seções para local físico × ano × cargo
# 1º turno, eleições ordinárias (exclui a suplementar de Magé 2008), 20 municípios.
# Duas versões do mapa seção -> local (diferem só em 2008):
#   principal: exclui seções "sem_local" e "secao_2010_nao_validada"
#   robusta:   inclui "secao_2010_nao_validada"
# Saída: OUT_DIR/votos_cand_place.parquet (local × ano × cargo × candidato)
#        OUT_DIR/votos_cand_mun.parquet   (município × ano × cargo × candidato, TODAS as seções: referência municipal de F2)
#        OUT_DIR/detalhes_place.parquet   (local × ano × cargo: aptos, comparecimento, nominais, legenda, brancos, nulos)

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
cat("04_votos_place.R\n")

sp <- as.data.table(read_parquet(file.path(OUT_DIR, "secao_place.parquet")))
mapa <- rbind(
  sp[!metodo %in% c("sem_local", "secao_2010_nao_validada"), .(ano, mun, zona, secao, place_id, versao = "principal")],
  sp[metodo != "sem_local", .(ano, mun, zona, secao, place_id, versao = "robusta")])

anos <- c(ANOS_GERAIS, ANOS_MUNICIPAIS)
vc <- list(); dd <- list(); vm <- list()
for (a in sort(anos)) {
  rc <- read_bd("resultados_candidato_secao", a)
  rc <- rc[turno == 1 & tipo_eleicao == "eleicao ordinaria" & id_municipio_tse %in% MUN$tse,
           .(ano, mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), cargo,
             numero_candidato, sequencial_candidato, sigla_partido, votos)]
  # referência municipal com todas as seções (inclusive as sem local físico), igual para as duas versões
  vm[[as.character(a)]] <- rc[, .(votos = sum(votos)), by = .(ano, mun, cargo, numero_candidato, sequencial_candidato, sigla_partido)]
  rc <- merge(rc, mapa[ano == a], by = c("ano", "mun", "zona", "secao"), allow.cartesian = TRUE)
  vc[[as.character(a)]] <- rc[, .(votos = sum(votos)),
                              by = .(versao, ano, mun, place_id, cargo, numero_candidato, sequencial_candidato, sigla_partido)]

  de <- read_bd("detalhes_votacao_secao", a)
  de <- de[turno == 1 & tipo_eleicao == "eleicao ordinaria" & id_municipio_tse %in% MUN$tse,
           .(ano, mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), cargo,
             aptos, comparecimento, votos_nominais, votos_legenda, votos_brancos, votos_nulos)]
  # checagem contábil por seção (Senado com 2 vagas em 2010 e 2018: 2 votos por eleitor)
  de[, votos_por_eleitor := fifelse(cargo == "senador" & ano %in% c(2010, 2018), 2L, 1L)]
  check(de[, all(votos_por_eleitor * comparecimento == votos_nominais + votos_legenda + votos_brancos + votos_nulos, na.rm = TRUE)],
        sprintf("%d: comparecimento x votos por eleitor != nominais + legenda + brancos + nulos", a))
  de[, votos_por_eleitor := NULL]
  de <- merge(de, mapa[ano == a], by = c("ano", "mun", "zona", "secao"), allow.cartesian = TRUE)
  dd[[as.character(a)]] <- de[, lapply(.SD, sum), by = .(versao, ano, mun, place_id, cargo),
                              .SDcols = c("aptos", "comparecimento", "votos_nominais", "votos_legenda", "votos_brancos", "votos_nulos")]
  cat(sprintf("  %d: %d linhas candidato-local, %d linhas local-cargo\n", a, nrow(vc[[as.character(a)]]), nrow(dd[[as.character(a)]])))
  rm(rc, de); gc(verbose = FALSE)
}
vc <- rbindlist(vc); dd <- rbindlist(dd); vm <- rbindlist(vm)

# checagem: soma dos votos de candidatos = votos nominais, por local-ano-cargo
chk <- merge(vc[, .(cand = sum(votos)), by = .(versao, ano, place_id, cargo)],
             dd[, .(versao, ano, place_id, cargo, votos_nominais)], by = c("versao", "ano", "place_id", "cargo"))
check(chk[, all(cand == votos_nominais)], "votos de candidatos != votos nominais em algum local-ano-cargo")

setorder(vc, versao, ano, mun, place_id, cargo, numero_candidato)
setorder(dd, versao, ano, mun, place_id, cargo)
write_out(vc, "votos_cand_place")
write_out(dd, "detalhes_place")
setorder(vm, ano, mun, cargo, numero_candidato)
write_out(vm, "votos_cand_mun")

res <- dd[versao == "principal" & cargo %in% c("prefeito", "governador"),
          .(locais = uniqueN(place_id), aptos = sum(aptos), comparecimento = round(sum(comparecimento) / sum(aptos), 3)), by = ano][order(ano)]
fwrite(res, file.path(CHECK_DIR, "04_resumo.csv")); print(res)
cat("OK 04\n")
