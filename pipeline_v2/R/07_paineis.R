# 07_paineis.R — painéis de análise
# Painel municipal: local físico × eleição municipal (2008–2024), prefeito e vereador lado a lado.
# Painel geral:     local físico × eleição geral (2006–2022), governador e dep. estadual (e senador/dep. federal).
# Tratamento e amostras ficam como colunas; a seleção da amostra é feita no motor de estimação.
#   peso = aptos do local na 1ª eleição observada do calendário NA VERSÃO PRINCIPAL (pré-determinado, fixo no
#          tempo e igual nas duas versões, para que a robustez mude só as linhas da amostra, não os pesos)
#   balanceado = local observado em todas as eleições do calendário (versão principal)
#   amostra_fronteira_<f>_<d> = local tratado pela facção f no painel, ou controle a <= d m do envelope de f,
#                               em município com pelo menos um local tratado por f. Controle = nunca tratado,
#                               ou da própria facção f com entrada depois da janela (ainda não tratado em toda a
#                               janela). Locais de OUTRA facção nunca entram como controle.
#   sempre_tratado_mesmo = tratado no 1º período sob o timing de robustez (mapa do próprio ano): excluir nessa robustez
# Saída: OUT_DIR/painel_municipal.parquet, OUT_DIR/painel_geral.parquet, CHECK_DIR/07_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config.R"))
cat("07_paineis.R\n")

O <- as.data.table(read_parquet(file.path(OUT_DIR, "outcomes_place.parquet")))
T <- as.data.table(read_parquet(file.path(OUT_DIR, "tratamento_place.parquet")))
VARS <- c("hhi", "enc", "margin", "top1", "dissim", "exc_hhi", "exc_hhi_loo", "exc_vencedor",
          "brancos_nulos", "legenda_share", "n_cand_votados")

monta <- function(cal, cargos, nomes, gcol_lag, gcol_mesmo) {
  o <- O[ano %in% cal & cargo %in% cargos]
  o[, cargo := nomes[match(cargo, cargos)]]
  w <- dcast(o, versao + ano + mun + place_id ~ cargo, value.var = VARS)
  # comparecimento e aptos são do local-ano (iguais entre cargos do mesmo pleito; pega o 1º cargo)
  base <- o[cargo == nomes[1], .(versao, ano, place_id, aptos, comparecimento, comparecimento_taxa)]
  w <- merge(w, base, by = c("versao", "ano", "place_id"), all.x = TRUE)
  w <- merge(w, T, by = c("place_id", "mun"), all.x = FALSE)       # só locais com coordenada/tratamento
  w[, g := get(gcol_lag)][, g_mesmo := get(gcol_mesmo)]
  # peso: aptos na 1ª eleição observada (versão principal)
  pw <- w[versao == "principal"][order(ano), .(peso = aptos[1], ano_peso = ano[1]), by = place_id]
  w <- merge(w, pw, by = "place_id", all.x = TRUE)
  nb <- w[versao == "principal", .(n_obs = uniqueN(ano)), by = place_id]
  w <- merge(w, nb, by = "place_id", all.x = TRUE)
  w[, balanceado := n_obs == length(cal)]
  for (f in c("milicia", "trafico")) {
    mun_f <- unique(w[faccao_entrada == f & !sempre_tratado & !is.na(g), mun])
    dcol <- paste0("dist_env_", f, "_m")
    for (d in c(500, 1000, 2000)) {
      nm <- sprintf("amostra_fronteira_%s_%d", f, d)
      w[, (nm) := mun %in% mun_f & !sempre_tratado &
                  ((faccao_entrada == f & !is.na(g)) | ((nunca_tratado | (trat_pos_painel & faccao_entrada == f)) & get(dcol) <= d))]
    }
    w[, (sprintf("amostra_nyt_%s", f)) := faccao_entrada == f & !sempre_tratado & (!is.na(g) | trat_pos_painel)]
    w[, (sprintf("amostra_todos_%s", f)) := mun %in% mun_f & !sempre_tratado &
                                            ((faccao_entrada == f & !is.na(g)) | nunca_tratado | (trat_pos_painel & faccao_entrada == f))]
  }
  # g = 0 para quem não é tratado dentro da janela (convenção do did)
  w[is.na(g) | trat_pos_painel, g := 0L][is.na(g_mesmo), g_mesmo := 0L]
  w[, sempre_tratado_mesmo := g_mesmo > 0 & g_mesmo <= min(cal)]
  setorder(w, versao, place_id, ano)
  w
}

PM <- monta(ANOS_MUNICIPAIS, c("prefeito", "vereador"), c("pref", "ver"), "g_mun_lag", "g_mun_mesmo")
PG <- monta(ANOS_GERAIS, c("governador", "deputado estadual", "senador", "deputado federal"),
            c("gov", "depest", "sen", "depfed"), "g_bien_lag", "g_bien_mesmo")
# no painel geral, a coorte usa o calendário bienal; para estimar só com eleições gerais, mapeia-se para
# a 1ª eleição geral >= coorte bienal
prox_geral <- function(v) vapply(v, function(x) { e <- ANOS_GERAIS[ANOS_GERAIS >= x]; if (length(e)) as.integer(min(e)) else 0L }, integer(1))
PG[g > 0, g := prox_geral(g)][g_mesmo > 0, g_mesmo := prox_geral(g_mesmo)]   # coorte depois de 2022 -> 0 (fora da janela)
PG[, sempre_tratado_mesmo := g_mesmo > 0 & g_mesmo <= min(ANOS_GERAIS)]
check(!anyNA(PG$g) & !anyNA(PG$g_mesmo), "coorte NA no painel geral")
check(!anyNA(PM$g) & !anyNA(PM$g_mesmo), "coorte NA no painel municipal")

check(!anyDuplicated(PM[, .(versao, place_id, ano)]), "painel municipal com chave duplicada")
check(!anyDuplicated(PG[, .(versao, place_id, ano)]), "painel geral com chave duplicada")
check(PM[sempre_tratado == TRUE, all(!amostra_fronteira_milicia_1000 & !amostra_fronteira_trafico_1000)], "sempre tratado em amostra")
check(PM[, all(peso > 0, na.rm = TRUE)], "peso não positivo")

write_out(PM, "painel_municipal"); write_out(PG, "painel_geral")

# ---- relatórios: N por amostra e coorte (versão principal) ----
rel <- rbindlist(lapply(c("milicia", "trafico"), function(f) rbindlist(lapply(
  c(sprintf("amostra_fronteira_%s_1000", f), sprintf("amostra_fronteira_%s_500", f), sprintf("amostra_fronteira_%s_2000", f),
    sprintf("amostra_nyt_%s", f), sprintf("amostra_todos_%s", f)), function(a) {
  s <- unique(PM[versao == "principal" & get(a) == TRUE, .(place_id, g, balanceado, mun)])
  data.table(faccao = f, amostra = a, locais = nrow(s), locais_balanceados = sum(s$balanceado),
             controles_g0 = sum(s$g == 0), g2012 = sum(s$g == 2012), g2016 = sum(s$g == 2016),
             g2020 = sum(s$g == 2020), g2024 = sum(s$g == 2024),
             tratados_balanceados = sum(s$g > 0 & s$balanceado), municipios = uniqueN(s$mun),
             clusters_2km = uniqueN(PM[versao == "principal" & get(a) == TRUE, grade_2km]))
}))))
fwrite(rel, file.path(CHECK_DIR, "07_amostras_municipal.csv")); print(rel)
cat("OK 07\n")
