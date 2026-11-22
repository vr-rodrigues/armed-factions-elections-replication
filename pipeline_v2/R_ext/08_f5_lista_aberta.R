# 08_f5_lista_aberta.R — família F5: concentração na lista aberta
# Cargos: vereador (painel municipal), deputado estadual e deputado federal (painel geral).
# Notação: s_k = share do candidato k nos votos nominais do local (legenda fora, como no 05_outcomes.R);
#          partido p = dois primeiros dígitos do número do candidato (consistente com a sigla em todos os anos-cargos;
#          cobre os 0,07% de votos sem sigla na base);
#          S_p = soma de s_k no partido; I_p = soma de (s_k/S_p)^2 no partido.
# Identidade: hhi_cand = sum_p S_p^2 I_p (checada).
# Outcomes:
#   hhi_part     = sum_p S_p^2                         (concentração entre partidos; primário)
#   intra_part   = hhi_cand / hhi_part                 (média de I_p ponderada por S_p^2; primário)
#   exc_top_local = s(k*) - S_{m,-i}(k*), k* = mais votado NO LOCAL (desempate: mais votos no município, depois o
#                   identificador do candidato); S_{m,-i} = share no município sem o local (todas as seções, como no 05)
#   robustez "agremiação": tipo = coligação (2006–2018) ou federação (2022–2024) do partido, em vez do partido
#   robustez "legenda": S_p inclui os votos de legenda do partido no local (I_p continua com votos nominais)
# Saída: EXT_DIR/f5_lista_aberta.parquet; CHECK_EXT/08_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config_ext.R"))
cat("08_f5_lista_aberta.R\n")
CARGOS <- c("vereador", "deputado estadual", "deputado federal")

vc <- read_snap("votos_cand_place")[cargo %in% CARGOS]
vc <- vc[versao == "principal" | ano %in% c(2006, 2008)]                    # mesma regra do 05
vm <- read_snap("votos_cand_mun")[cargo %in% CARGOS]
vc[, cand := paste(numero_candidato, sequencial_candidato)]; vm[, cand := paste(numero_candidato, sequencial_candidato)]
vc[, np := substr(numero_candidato, 1, 2)]
chk_sig <- unique(vc[sigla_partido != "", .(ano, cargo, np, sigla_partido)])[, .N, by = .(ano, cargo, np)]
check(chk_sig[, all(N == 1)], "prefixo do número do candidato com mais de uma sigla no mesmo ano-cargo")

# ---- agremiação (coligação ou federação) ----
PC <- read_bd2("partidos_coligacoes")[cargo %in% CARGOS]
# partido isolado = a própria agremiação (em 2006–2010 o código de coligação vem vazio para os isolados)
PC[, agrem := fcase(tipo_agremiacao == "federacao", paste0("F", numero_federacao),
                    tipo_agremiacao == "coligacao" & !is.na(sequencial_coligacao) & sequencial_coligacao != "", paste0("C", sequencial_coligacao),
                    tipo_agremiacao == "coligacao", paste0("N", nome_coligacao),
                    default = paste0("P", numero))]
PC[, mun := fifelse(is.na(id_municipio_tse) | id_municipio_tse == "", "UF", id_municipio_tse)]
PC <- unique(PC[, .(ano, cargo, mun, np = numero, agrem)])
check(!anyDuplicated(PC[, .(ano, cargo, mun, np)]), "partido com mais de uma agremiação no mesmo ano-cargo-município")
vc[, mun_ag := fifelse(cargo == "vereador", mun, "UF")]
vc <- merge(vc, PC, by.x = c("ano", "cargo", "mun_ag", "np"), by.y = c("ano", "cargo", "mun", "np"), all.x = TRUE)
sem_ag <- vc[is.na(agrem), .(votos = sum(votos)), by = .(ano, cargo)]
fwrite(sem_ag, file.path(CHECK_EXT, "08_votos_sem_agremiacao.csv"))
vc[is.na(agrem), agrem := paste0("P", np)]                                   # sem registro: o próprio partido

# ---- shares e referência municipal (igual ao 05) ----
K <- c("versao", "ano", "mun", "cargo", "place_id"); Km <- c("ano", "mun", "cargo")
vc[, v_i := sum(votos), by = K][, s := votos / v_i]
ref <- vm[, .(V_mk = sum(votos)), by = c(Km, "cand")][, V_m := sum(V_mk), by = Km]
vc <- merge(vc, ref, by = c(Km, "cand"), all.x = TRUE)
check(!anyNA(vc$V_mk), "candidato do local ausente da referência municipal")
vc[, S_loo := fifelse(V_m - v_i > 0, (V_mk - votos) / (V_m - v_i), NA_real_)]

# ---- legenda por partido e local (robustez): resultados_partido_secao -> local, mesma regra do 04 ----
sp <- read_snap("secao_place")
mapa <- rbind(sp[!metodo %in% c("sem_local", "secao_2010_nao_validada"), .(ano, mun, zona, secao, place_id, versao = "principal")],
              sp[metodo != "sem_local", .(ano, mun, zona, secao, place_id, versao = "robusta")])
leg <- rbindlist(lapply(sort(unique(vc$ano)), function(a) {
  rp <- read_bd("resultados_partido_secao", a)
  rp <- rp[turno == 1 & tipo_eleicao == "eleicao ordinaria" & id_municipio_tse %in% MUN$tse & cargo %in% CARGOS,
           .(ano, mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), cargo, np = numero_partido, votos_legenda)]
  rp <- merge(rp, mapa[ano == a], by = c("ano", "mun", "zona", "secao"), allow.cartesian = TRUE)
  rp[, .(legenda = sum(votos_legenda)), by = .(versao, ano, mun, place_id, cargo, np)]
}))
leg <- leg[versao == "principal" | ano %in% c(2006, 2008)]
# conferência: soma da legenda por local = votos_legenda do detalhes_place (pipeline v2)
dp <- read_snap("detalhes_place")[cargo %in% CARGOS]
cl <- merge(leg[, .(leg = sum(legenda)), by = .(versao, ano, place_id, cargo)], dp[, .(versao, ano, place_id, cargo, votos_legenda)],
            by = c("versao", "ano", "place_id", "cargo"))
check(cl[, all(leg == votos_legenda)], "legenda por partido não soma a legenda do local")

# ---- medidas por local ----
part <- vc[, .(S = sum(s), I = sum((s / sum(s))^2), nom = sum(votos)), by = c(K, "np")]
part <- merge(part, leg, by = c(K, "np"), all = TRUE)
part <- part[paste(versao, ano, place_id, cargo) %in% vc[, unique(paste(versao, ano, place_id, cargo))]]
part[is.na(legenda), legenda := 0L]
part[is.na(nom), `:=`(nom = 0L, I = 0)]   # partido só com legenda no local: entra no S_leg, sem candidato (I = 0)
part[, `:=`(V_nom = sum(nom), V_leg = sum(legenda)), by = K][, S_leg := (nom + legenda) / (V_nom + V_leg)]
agr <- vc[, .(S = sum(s), I = sum((s / sum(s))^2)), by = c(K, "agrem")]
cand <- vc[, {
  o <- order(-s, -V_mk, cand); k <- o[1]
  list(hhi_cand = sum(s^2), n_cand = .N, exc_top_local = s[k] - S_loo[k], s_top_local = s[k], top_local = cand[k])
}, by = K]
f5 <- merge(cand, part[, .(hhi_part = sum(S^2, na.rm = TRUE), soma_S2I = sum(S^2 * I, na.rm = TRUE), n_partidos = sum(!is.na(S)),
                           hhi_part_leg = sum(S_leg^2), soma_SL2I = sum(S_leg^2 * I)), by = K], by = K)
f5 <- merge(f5, agr[, .(hhi_agrem = sum(S^2), soma_A2I = sum(S^2 * I), n_agrem = .N), by = K], by = K)
check(f5[, max(abs(hhi_cand - soma_S2I))] < 1e-12, "identidade hhi_cand = sum S_p^2 I_p")
check(f5[, max(abs(hhi_cand - soma_A2I))] < 1e-12, "identidade com agremiação")
f5[, `:=`(intra_part = hhi_cand / hhi_part, intra_agrem = hhi_cand / hhi_agrem, intra_part_leg = soma_SL2I / hhi_part_leg)]
f5[, c("soma_S2I", "soma_A2I", "soma_SL2I") := NULL]
check(f5[, all(intra_part > 0 & intra_part <= 1 + 1e-12 & hhi_part >= hhi_cand - 1e-12)], "intra_part fora de (0,1]")
check(f5[, all(hhi_agrem >= hhi_part - 1e-12)], "HHI de agremiação menor que o de partido")

# o HHI dos candidatos tem de ser o mesmo do 05_outcomes (pipeline v2)
op <- read_snap("outcomes_place")[cargo %in% CARGOS, .(versao, ano, place_id, cargo, hhi)]
cmp <- merge(f5[, .(versao, ano, place_id, cargo, hhi_cand)], op, by = c("versao", "ano", "place_id", "cargo"))
check(nrow(cmp) == nrow(f5) && cmp[, max(abs(hhi_cand - hhi))] < 1e-12, "hhi_cand difere do outcomes_place")

setorder(f5, versao, ano, mun, place_id, cargo)
write_ext(f5, "f5_lista_aberta")
res <- f5[versao == "principal", .(locais = .N, hhi_cand = round(mean(hhi_cand), 3), hhi_part = round(mean(hhi_part), 3),
                                    intra_part = round(mean(intra_part), 3), hhi_agrem = round(mean(hhi_agrem), 3),
                                    intra_agrem = round(mean(intra_agrem), 3), hhi_part_leg = round(mean(hhi_part_leg), 3),
                                    exc_top_local = round(mean(exc_top_local), 3), partidos = as.numeric(median(n_partidos))),
          by = .(cargo, ano)][order(cargo, ano)]
fwrite(res, file.path(CHECK_EXT, "08_f5_medias.csv")); options(width = 200); print(res)
print(sem_ag)
cat("OK 08\n")
