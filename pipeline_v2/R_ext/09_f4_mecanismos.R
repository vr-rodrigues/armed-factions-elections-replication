# 09_f4_mecanismos.R — família F4 (quem ganha, com tipos definidos ANTES da eleição)
# Todos os outcomes são "excesso local": share do conjunto de candidatos no local − share no município sem o local
# (todas as seções, leave-one-out, como no 05_outcomes.R). Se o conjunto não tem candidato no município-ano, o share é
# 0 nos dois termos (excesso = 0) e o caso é contado no relatório.
#   gov_pref : candidatos a prefeito do partido do governador ou de coligação que o inclui (tabela `partidos`:
#              mesmos código de coligação, município e ano). Partido do governador pelo NÚMERO (a BD harmoniza as
#              siglas): 15 (PMDB) em 2008–2016, 20 (PSC) em 2020, 22 (PL) em 2024.
#   gov_ver  : candidatos a vereador do partido do governador.
#   inc_pref : candidato a prefeito do partido do prefeito eleito na eleição anterior (vencedor final: "eleito" no
#              1º ou no 2º turno da eleição ordinária; 2004 para 2008). Se o partido não tem candidato, o candidato cuja
#              coligação inclui o partido. A pessoa do incumbente não é identificada (o título eleitoral não é usado),
#              então quem trocou de partido não é captado.
#   pol_<cargo> : candidatos com ocupação declarada policial militar, policial civil, militar reformado, bombeiro militar
#              ou membro das Forças Armadas (lista fixada antes de estimar). Vereador; dep. estadual (dep. federal
#              como complemento).
# Saída: EXT_DIR/f4_mecanismos.parquet (local × ano, colunas por outcome); CHECK_EXT/09_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config_ext.R"))
cat("09_f4_mecanismos.R\n")
CARGOS <- c("prefeito", "vereador", "deputado estadual", "deputado federal")
vc <- read_snap("votos_cand_place")[cargo %in% CARGOS]
vc <- vc[versao == "principal" | ano %in% c(2006, 2008)]
vm <- read_snap("votos_cand_mun")[cargo %in% CARGOS]
vc[, np := substr(numero_candidato, 1, 2)]; vm[, np := substr(numero_candidato, 1, 2)]

# ---- coligações (prefeito e vereador) ----
PC <- read_bd2("partidos_coligacoes")[cargo %in% c("prefeito", "vereador")]
PC[, mun := id_municipio_tse]
PC[, grupo := fcase(tipo_agremiacao == "federacao", paste0("F", numero_federacao),
                    tipo_agremiacao == "coligacao" & !is.na(sequencial_coligacao) & sequencial_coligacao != "", paste0("C", sequencial_coligacao),
                    tipo_agremiacao == "coligacao", paste0("N", nome_coligacao), default = paste0("P", numero))]
PC <- unique(PC[, .(ano, mun, cargo, np = numero, grupo)])
membros <- function(tab_np) {               # tab_np: ano, mun, np_alvo -> partidos (np) no mesmo grupo do prefeito
  g <- merge(PC[cargo == "prefeito"], tab_np, by.x = c("ano", "mun", "np"), by.y = c("ano", "mun", "np_alvo"))[, .(ano, mun, grupo)]
  unique(merge(PC[cargo == "prefeito"], unique(g), by = c("ano", "mun", "grupo"))[, .(ano, mun, np)])
}

# ---- conjuntos ----
GOVN <- data.table(ano = c(2008L, 2012L, 2016L, 2020L, 2024L), np_gov = c("15", "15", "15", "20", "22"))
gov_tab <- CJ(ano = GOVN$ano, mun = MUN$tse)[GOVN, on = "ano"][, .(ano, mun, np_alvo = np_gov)]
gov_pref_np <- membros(gov_tab)
R <- read_bd2("resultados_cand_mun")[cargo == "prefeito" & tipo_eleicao == "eleicao ordinaria" & resultado == "eleito"]
inc <- R[, .(ano = ano + 4L, mun = id_municipio_tse, np_alvo = numero_partido)]
check(!anyDuplicated(inc[, .(ano, mun)]), "mais de um prefeito eleito no mesmo município-ano")
check(nrow(inc[ano %in% ANOS_MUNICIPAIS]) == 5 * 20, "faltam vencedores para definir o incumbente")
inc_col <- membros(inc)
cands <- rbindlist(lapply(list.files(file.path(BD_DIR, "candidatos"), full.names = TRUE), function(f)
  as.data.table(read_parquet(f))[, .(ano, sequencial, ocupacao)]))
cands[, oc := toupper(iconv(ocupacao, "UTF-8", "ASCII//TRANSLIT"))]
POL <- c("POLICIAL MILITAR", "POLICIAL CIVIL", "MILITAR REFORMADO", "BOMBEIRO MILITAR", "MEMBRO DAS FORCAS ARMADAS")
pol_seq <- unique(cands[oc %in% POL, .(ano, sequencial_candidato = sequencial)])[, pol := TRUE]

marca <- function(d) {
  d <- merge(d, GOVN, by = "ano", all.x = TRUE)
  d[, gov_pref := cargo == "prefeito" & paste(ano, mun, np) %in% gov_pref_np[, paste(ano, mun, np)]]
  d[, gov_ver := cargo == "vereador" & !is.na(np_gov) & np == np_gov]
  d <- merge(d, inc[, .(ano, mun, np_inc = np_alvo)], by = c("ano", "mun"), all.x = TRUE)
  # incumbente: partido do eleito; se o partido não tem candidato a prefeito no município-ano, a coligação que o inclui
  tem_partido <- unique(vm[cargo == "prefeito", .(ano, mun, np)])
  d[, inc_partido_concorre := paste(ano, mun, np_inc) %in% tem_partido[, paste(ano, mun, np)]]
  d[, inc_pref := cargo == "prefeito" & !is.na(np_inc) &
                  fifelse(inc_partido_concorre, np == np_inc, paste(ano, mun, np) %in% inc_col[, paste(ano, mun, np)])]
  d <- merge(d, pol_seq, by = c("ano", "sequencial_candidato"), all.x = TRUE)[is.na(pol), pol := FALSE]
  d
}
vc <- marca(vc); vm <- marca(vm)

# ---- excesso local de um conjunto ----
K <- c("versao", "ano", "mun", "cargo", "place_id"); Km <- c("ano", "mun", "cargo")
excesso <- function(flag, cargo_alvo, nome) {
  a <- vc[cargo == cargo_alvo, .(v_set = sum(votos[get(flag)]), v_i = sum(votos)), by = K]
  m <- vm[cargo == cargo_alvo, .(V_set = sum(votos[get(flag)]), V_m = sum(votos)), by = Km]
  a <- merge(a, m, by = Km)
  a[, s := v_set / v_i][, S_loo := fifelse(V_m - v_i > 0, (V_set - v_set) / (V_m - v_i), NA_real_)]
  a[, .(versao, ano, mun, place_id, s, exc = s - S_loo, tem_candidato = V_set > 0)][, outcome := nome]
}
L <- rbindlist(list(excesso("gov_pref", "prefeito", "gov_pref"), excesso("gov_ver", "vereador", "gov_ver"),
                    excesso("inc_pref", "prefeito", "inc_pref"), excesso("pol", "vereador", "pol_ver"),
                    excesso("pol", "deputado estadual", "pol_depest"), excesso("pol", "deputado federal", "pol_depfed")))
check(L[!is.na(exc), all(s >= 0 & s <= 1 & abs(exc) <= 1)], "share fora de [0,1]")
F4 <- dcast(L, versao + ano + mun + place_id ~ outcome, value.var = c("exc", "s"))
setnames(F4, sub("^exc_(.*)$", "\\1_exc", names(F4))); setnames(F4, sub("^s_(.*)$", "\\1_s", names(F4)))
setorder(F4, versao, ano, mun, place_id)
write_ext(F4, "f4_mecanismos")

# ---- relatórios ----
disp <- unique(L[, .(ano, mun, outcome, tem_candidato)])[, .(municipios = .N, com_candidato = sum(tem_candidato)), by = .(outcome, ano)][order(outcome, ano)]
fwrite(disp, file.path(CHECK_EXT, "09_disponibilidade.csv"))
regra_inc <- unique(vm[cargo == "prefeito" & ano %in% ANOS_MUNICIPAIS, .(ano, mun, inc_partido_concorre)])[, .(partido_concorre = sum(inc_partido_concorre), so_coligacao = sum(!inc_partido_concorre)), by = ano]
fwrite(regra_inc, file.path(CHECK_EXT, "09_regra_incumbente.csv"))
mshare <- rbindlist(list(
  vm[cargo == "prefeito", .(s = sum(votos[gov_pref]) / sum(votos)), by = .(ano, mun)][, .(outcome = "gov_pref", media = mean(s)), by = ano],
  vm[cargo == "prefeito", .(s = sum(votos[inc_pref]) / sum(votos)), by = .(ano, mun)][, .(outcome = "inc_pref", media = mean(s)), by = ano],
  vm[cargo == "vereador", .(s = sum(votos[gov_ver]) / sum(votos)), by = .(ano, mun)][, .(outcome = "gov_ver", media = mean(s)), by = ano],
  vm[cargo == "vereador", .(s = sum(votos[pol]) / sum(votos)), by = .(ano, mun)][, .(outcome = "pol_ver", media = mean(s)), by = ano],
  vm[cargo == "deputado estadual", .(s = sum(votos[pol]) / sum(votos)), by = .(ano, mun)][, .(outcome = "pol_depest", media = mean(s)), by = ano]))
fwrite(mshare, file.path(CHECK_EXT, "09_share_municipal_medio.csv"))
options(width = 200); print(disp); print(regra_inc); print(dcast(mshare, ano ~ outcome, value.var = "media"))
cat("OK 09\n")
