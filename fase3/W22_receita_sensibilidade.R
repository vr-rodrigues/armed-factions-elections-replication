# W22_receita_sensibilidade.R — sensibilidade do percentil de receita de campanha (W18) ao
# tratamento dos candidatos sem prestação de contas ligada. No W18 eles ficam fora do ranking e da média do local.
# Alguns tiveram muitos votos, e os locais tratados têm menos voto ligado do que os de comparação em 2020.
# Versões (prefeito, tráfico, especificação principal):
#   principal : como no W18 (sem registro fica fora)
#   zero      : candidato sem registro entra no ranking com receita zero
#   sem_mun   : sem os municípios em que, em alguma eleição, um candidato sem registro teve 10% ou mais do voto da cidade
# Também verifica se os setores do Censo de Paracambi ficam onde os locais ficam.
# Saídas: resultados/W22_receita_sensibilidade.csv, W22_contagens.csv, W22_paracambi.csv
AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); OUT <- file.path(F3DIR, "resultados")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

R <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v3/receitas_candidato_agregado.parquet")))
R <- R[, .(receita = sum(receita_financeira)), by = .(ano, mun = id_municipio_tse, cargo, sequencial_candidato)]
vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo == "prefeito"]
vc <- merge(vc, R, by = c("ano", "mun", "cargo", "sequencial_candidato"), all.x = TRUE)
cm <- vc[, .(votos = sum(votos), receita = receita[1]), by = .(ano, mun, sequencial_candidato)]
cm[, share_mun := votos / sum(votos), by = .(ano, mun)]
semreg <- cm[is.na(receita)]
mun_fora <- unique(semreg[share_mun >= 0.10, mun])
cont <- data.table(item = c("candidato_eleicao_sem_registro", "municipio_eleicao_com_sem_registro_10pct", "municipios_fora", "maior_share_sem_registro"),
                   valor = c(nrow(semreg), nrow(unique(semreg[share_mun >= 0.10, .(ano, mun)])), length(mun_fora), max(semreg$share_mun)))
cm[!is.na(receita), pct := (frank(receita, ties.method = "average") - 0.5) / .N, by = .(ano, mun)]
cm[, rec0 := fifelse(is.na(receita), 0, receita)][, pct0 := (frank(rec0, ties.method = "average") - 0.5) / .N, by = .(ano, mun)]
vc <- merge(vc, cm[, .(ano, mun, sequencial_candidato, pct, pct0)], by = c("ano", "mun", "sequencial_candidato"))
B <- vc[, { s <- votos / sum(votos); ok <- !is.na(pct)
  list(vw_pct = if (any(ok)) sum(s[ok] * pct[ok]) / sum(s[ok]) else NA_real_, vw_pct0 = sum(s * pct0), ligado = sum(s[ok])) }, by = .(ano, place_id)]
PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
PM <- merge(PM, B, by = c("place_id", "ano"), all.x = TRUE)
d0 <- PM[amostra_fronteira_trafico_1000 == TRUE & balanceado == TRUE]
lig <- d0[ano == 2020, .(ligado = weighted.mean(ligado, peso), minimo = min(ligado)), by = .(tratado = g > 0)]
cont <- rbind(cont, data.table(item = c("voto_ligado_2020_tratados", "voto_ligado_2020_comparacao", "tratados_nos_municipios_fora"),
                               valor = c(lig[tratado == TRUE]$ligado, lig[tratado == FALSE]$ligado, uniqueN(d0[g > 0 & mun %in% mun_fora]$place_id))))
fwrite(cont, file.path(OUT, "W22_contagens.csv")); print(cont)
est <- function(d, y, rot) { fora <- unique(d$place_id[is.na(d[[y]])]); d <- d[!place_id %in% fora]; r <- cs_estimar(d, y, biters = 49, rotulo = rot); a <- r$overall[tipo == "group"]$att
  data.table(versao = rot, att = a, se = r$se_group_crve, p = 2 * pnorm(-abs(a / r$se_group_crve)), pre_p = r$wald_pre_crve$p, tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades) }
S <- rbind(est(d0, "vw_pct", "principal"), est(d0, "vw_pct0", "zero"), est(d0[!mun %in% mun_fora], "vw_pct", "sem_mun"))
fwrite(S, file.path(OUT, "W22_receita_sensibilidade.csv")); print(S)

# Paracambi: os setores do Censo extraídos para o município ficam onde os locais ficam? (código IBGE 3303609)
PL <- as.data.table(read_parquet(file.path(SNAP, "places.parquet")))[mun == "58718" & !is.na(lat)]
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))[mun == "58718"]
CV <- as.data.table(read_parquet(file.path(AFE_DADOS, "pipeline_v2_ext/censo2010_local.parquet")))
SET <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v2/setores_2010.parquet")))[id_municipio == "3303609"]
cen <- function(w) { x <- as.numeric(unlist(regmatches(w, gregexpr("-?[0-9]+\\.[0-9]+", w)))); c(lon = mean(x[seq(1, length(x), 2)]), lat = mean(x[seq(2, length(x), 2)])) }
cs <- t(sapply(SET$wkt[seq_len(min(80, nrow(SET)))], cen))
PCB <- data.table(item = c("locais_58718", "lon_media_locais", "lat_media_locais", "setores_3303609", "lon_media_setores", "lat_media_setores",
                           "locais_58718_com_entrada", "locais_58718_sem_renda", "locais_sem_renda_total", "locais_sem_renda_na_amostra_trafico", "locais_sem_renda_na_amostra_milicia"),
                  valor = c(nrow(PL), mean(PL$lon), mean(PL$lat), nrow(SET), mean(cs[, "lon"]), mean(cs[, "lat"]), TP[!is.na(entrada), .N],
                            CV[place_id %in% PL$place_id & is.na(renda), .N], CV[is.na(renda) | renda <= 0, .N],
                            uniqueN(PM[amostra_fronteira_trafico_1000 == TRUE & balanceado == TRUE & place_id %in% CV[is.na(renda) | renda <= 0]$place_id]$place_id),
                            uniqueN(PM[amostra_fronteira_milicia_1000 == TRUE & balanceado == TRUE & place_id %in% CV[is.na(renda) | renda <= 0]$place_id]$place_id)))
fwrite(PCB, file.path(OUT, "W22_paracambi.csv")); print(PCB)
cat("OK W22\n")
