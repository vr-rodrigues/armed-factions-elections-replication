# W04_agregacao_municipal.R — agregação municipal: quanto os efeitos estimados no local de
# votação movem o resultado da cidade.
# Conta de agregação (não é uma nova estimação): aplica o ATT estimado aos locais tratados de cada município-ano e
# compara o deslocamento implícito com o resultado municipal.
#   Prefeito (tráfico): votos deslocados para o eleito = ATT(eleito_share_pref) x votos nominais do local, somados nos
#     locais após a entrada. Comparado com a margem municipal do 1º turno (1º menos 2º, % dos votos nominais).
#     "Fluxo": só locais que entram no território na janela (onde o ATT foi estimado).
#     "Estoque" (limite superior): soma os locais dentro do território desde 2007, supondo o mesmo efeito.
#   Vereador (milícia): votos deslocados para partidos pequenos de direita = ATT(dir_outras_ver) x votos nominais de
#     vereador do local; em cadeiras-equivalentes = votos / quociente eleitoral (votos válidos / cadeiras).
# Saída: resultados/W04_agregacao_prefeito.csv, W04_agregacao_vereador.csv, W04_resumo.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); BD2 <- file.path(AFE_DADOS, "basedosdados_v2")
OUT <- file.path(F3DIR, "resultados")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

O <- as.data.table(read_parquet(file.path(SNAP, "outcomes_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo %in% c("prefeito", "vereador")]
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))[, .(place_id, faccao_entrada, g_mun_lag, sempre_tratado, trat_pos_painel)]
O <- merge(O, TP, by = "place_id", all.x = TRUE)
O[, `:=`(fluxo_tr = faccao_entrada %in% "trafico" & !sempre_tratado & !trat_pos_painel & !is.na(g_mun_lag) & ano >= g_mun_lag,
         estoque_tr = faccao_entrada %in% "trafico" & (sempre_tratado | (!trat_pos_painel & !is.na(g_mun_lag) & ano >= g_mun_lag)),
         fluxo_mi = faccao_entrada %in% "milicia" & !sempre_tratado & !trat_pos_painel & !is.na(g_mun_lag) & ano >= g_mun_lag,
         estoque_mi = faccao_entrada %in% "milicia" & (sempre_tratado | (!trat_pos_painel & !is.na(g_mun_lag) & ano >= g_mun_lag)))]
O[is.na(fluxo_tr), `:=`(fluxo_tr = FALSE, estoque_tr = FALSE, fluxo_mi = FALSE, estoque_mi = FALSE)]

# efeitos estimados (especificação principal)
w <- function(f, y) readRDS(file.path(OUT, "rds", sprintf("W01_%s_a_%s.rds", f, y)))$linha
ef_win <- w("trafico", "eleito_share_pref")
BL <- fread(file.path(F3DIR, "..", "fase2", "resultados", "V04_blocos.csv"))
ef_sr <- BL[faccao == "milicia" & tratamento == "ponto" & outcome == "dir_outras_ver"]
stopifnot(nrow(ef_sr) == 1)

# ---- prefeito: margem municipal do 1º turno ----
VM <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_mun.parquet")))[ano %in% ANOS & cargo == "prefeito"]
mg <- VM[order(-votos), .(V = sum(votos), m1 = votos[1], m2 = votos[2]), by = .(ano, mun)][, margem_pp := 100 * (m1 - m2) / V]
R <- as.data.table(read_parquet(file.path(BD2, "resultados_cand_mun.parquet")))[ano %in% ANOS & cargo == "prefeito" & tipo_eleicao == "eleicao ordinaria"]
seg <- unique(R[turno == 2, .(ano, mun = id_municipio_tse)])[, segundo_turno := TRUE]
P <- O[cargo == "prefeito", .(nom_mun_mapeado = sum(votos_nominais, na.rm = TRUE),
                              nom_fluxo = sum(votos_nominais[fluxo_tr], na.rm = TRUE), nom_estoque = sum(votos_nominais[estoque_tr], na.rm = TRUE)),
       by = .(ano, mun)]
P <- merge(merge(P, mg, by = c("ano", "mun")), seg, by = c("ano", "mun"), all.x = TRUE)[is.na(segundo_turno), segundo_turno := FALSE]
for (k in c("fluxo", "estoque")) {
  sh <- P[[paste0("nom_", k)]] / P$nom_mun_mapeado
  set(P, j = paste0("share_", k), value = sh)
  set(P, j = paste0("dwin_", k, "_pp"), value = 100 * ef_win$att * sh)
  set(P, j = paste0("dwin_", k, "_ub_pp"), value = 100 * (ef_win$att + 1.96 * ef_win$se) * sh)
}
P[, `:=`(pivo_fluxo = dwin_fluxo_ub_pp > margem_pp / 2, pivo_estoque = dwin_estoque_ub_pp > margem_pp / 2)]

# ---- vereador: cadeiras-equivalentes deslocadas para partidos pequenos de direita (milícia) ----
Rv <- as.data.table(read_parquet(file.path(BD2, "resultados_cand_mun.parquet")))[ano %in% ANOS & cargo == "vereador" & tipo_eleicao == "eleicao ordinaria"]
cad <- Rv[resultado %in% c("eleito", "eleito por qp", "eleito por media"), .(cadeiras = uniqueN(numero_candidato)), by = .(ano, mun = id_municipio_tse)]
Vv <- O[cargo == "vereador", .(validos_mapeado = sum(votos_nominais + votos_legenda, na.rm = TRUE),
                               nom_fluxo = sum(votos_nominais[fluxo_mi], na.rm = TRUE), nom_estoque = sum(votos_nominais[estoque_mi], na.rm = TRUE)),
        by = .(ano, mun)]
Vv <- merge(Vv, cad, by = c("ano", "mun"))[, quociente := validos_mapeado / cadeiras]
for (k in c("fluxo", "estoque")) {
  set(Vv, j = paste0("votos_sr_", k), value = ef_sr$att * Vv[[paste0("nom_", k)]])
  set(Vv, j = paste0("cadeiras_eq_", k), value = ef_sr$att * Vv[[paste0("nom_", k)]] / Vv$quociente)
  set(Vv, j = paste0("cadeiras_eq_", k, "_ub"), value = (ef_sr$att + 1.96 * ef_sr$se) * Vv[[paste0("nom_", k)]] / Vv$quociente)
}

fwrite(P, file.path(OUT, "W04_agregacao_prefeito.csv")); fwrite(Vv, file.path(OUT, "W04_agregacao_vereador.csv"))
pos <- P[ano > 2008]
S <- rbind(
  data.table(item = "prefeito: municípios-ano com local de tráfico tratado (fluxo)", valor = pos[nom_fluxo > 0, .N]),
  data.table(item = "prefeito: share médio dos votos da cidade em locais tratados (fluxo, onde > 0), %", valor = round(100 * pos[nom_fluxo > 0, mean(share_fluxo)], 2)),
  data.table(item = "prefeito: share máximo (fluxo), %", valor = round(100 * pos[, max(share_fluxo)], 2)),
  data.table(item = "prefeito: deslocamento médio p/ eleito (fluxo, onde > 0), pp da cidade", valor = round(pos[nom_fluxo > 0, mean(dwin_fluxo_pp)], 3)),
  data.table(item = "prefeito: deslocamento máximo p/ eleito (fluxo), pp", valor = round(pos[, max(dwin_fluxo_pp)], 3)),
  data.table(item = "prefeito: deslocamento máximo, limite superior do IC (fluxo), pp", valor = round(pos[, max(dwin_fluxo_ub_pp)], 3)),
  data.table(item = "prefeito: share médio dos votos da cidade em locais de tráfico (estoque, onde > 0), %", valor = round(100 * pos[nom_estoque > 0, mean(share_estoque)], 2)),
  data.table(item = "prefeito: deslocamento máximo (estoque, limite sup. do IC), pp", valor = round(pos[, max(dwin_estoque_ub_pp)], 3)),
  data.table(item = "prefeito: eleições (mun-ano) em que o lim. sup. (fluxo) > metade da margem", valor = pos[, sum(pivo_fluxo)]),
  data.table(item = "prefeito: eleições em que o lim. sup. (estoque) > metade da margem", valor = pos[, sum(pivo_estoque)]),
  data.table(item = "prefeito: eleições municipais 2012-2024 (total)", valor = nrow(pos)),
  data.table(item = "vereador: cadeiras-equivalentes p/ partidos pequenos de direita, soma 2012-2024 (fluxo)", valor = round(Vv[ano > 2008, sum(cadeiras_eq_fluxo)], 2)),
  data.table(item = "vereador: idem, limite superior do IC (fluxo)", valor = round(Vv[ano > 2008, sum(cadeiras_eq_fluxo_ub)], 2)),
  data.table(item = "vereador: idem, estoque (limite superior)", valor = round(Vv[ano > 2008, sum(cadeiras_eq_estoque_ub)], 2)),
  data.table(item = "vereador: máximo por município-ano (fluxo)", valor = round(Vv[ano > 2008, max(cadeiras_eq_fluxo)], 2)),
  data.table(item = "vereador: cadeiras em disputa 2012-2024 (soma)", valor = Vv[ano > 2008, sum(cadeiras)]))
fwrite(S, file.path(OUT, "W04_resumo.csv"))
options(width = 200); print(S)
cat("\nPrefeito, municípios-ano com maior deslocamento (fluxo):\n")
print(pos[order(-dwin_fluxo_pp)][1:8, .(ano, mun, share_fluxo = round(100 * share_fluxo, 1), dwin_pp = round(dwin_fluxo_pp, 2),
                                         dwin_ub = round(dwin_fluxo_ub_pp, 2), margem_pp = round(margem_pp, 1), segundo_turno)])
cat("OK W04\n")
