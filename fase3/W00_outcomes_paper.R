# W00_outcomes_paper.R — desfechos adicionais do paper que não estão no pipeline v2
# Constrói as medidas de seleção de candidatos e a decomposição da concentração do voto para prefeito:
#   seleção de candidatos (prefeito e vereador):
#     eleito_share  share dos votos nominais do local em candidatos eleitos no município (resultado "eleito",
#                   "eleito por qp" ou "eleito por media", eleição ordinária, qualquer turno)
#     ncomp1        número de candidatos com pelo menos 1% dos votos nominais do local
#     top3          soma dos três maiores shares do local (top1 já está no painel)
#     pubadm_share  share em candidatos com ocupação de cargo eletivo ou administração pública (mesma regra do paper)
#   decomposição do HHI por bloco ideológico do candidato (Colonnelli, Pinho Neto e Teso 2025, Tabela A1, por número e ano):
#     hhi_<b> = soma dos s_c^2 dos candidatos do bloco b; os blocos somam o HHI do local
#     lider_<b> = share do candidato mais votado no local se ele for do bloco b (zero caso contrário); somam top1
#     b: dir, cen, esq, e dentro da esquerda pt, psol, pdt, psb, esq_outras
#   decomposição do comparecimento (prefeito), por eleitor apto do ano:
#     lider_apt (votos do mais votado no local), outros_apt (demais votos nominais), bn_apt (brancos + nulos);
#     somam comparecimento_taxa (prefeito não tem voto de legenda)
# Entrada: $AFE_DADOS/pipeline_v2 (votos_cand_place, outcomes_place), basedosdados_tse/candidatos, basedosdados_v2/resultados_cand_mun,
#          pipeline_v2/R_ext/ideologia_partidos.csv
# Saída:   $AFE_DADOS/pipeline_v2_ext/w00_outcomes_paper.parquet (local × ano, versão principal)
#          fase3/resultados/W00_checks.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
SNAP <- file.path(AFE_DADOS, "pipeline_v2")
BD   <- file.path(AFE_DADOS, "basedosdados_tse")
BD2  <- file.path(AFE_DADOS, "basedosdados_v2")
EXT  <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT  <- file.path(F3DIR, "resultados"); dir.create(OUT, showWarnings = FALSE)
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)
SUF <- c(prefeito = "pref", vereador = "ver")
chk <- list(); check <- function(ok, msg) { chk[[length(chk) + 1]] <<- data.table(teste = msg, ok = isTRUE(ok)); if (!isTRUE(ok)) stop("FALHOU: ", msg) }

vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo %in% names(SUF)]
vc[, np := substr(numero_candidato, 1, 2)]

# eleitos (eleição ordinária, qualquer turno)
R <- as.data.table(read_parquet(file.path(BD2, "resultados_cand_mun.parquet")))[ano %in% ANOS & tipo_eleicao == "eleicao ordinaria"]
el <- unique(R[resultado %in% c("eleito", "eleito por qp", "eleito por media"), .(ano, mun = id_municipio_tse, cargo, numero_candidato)])[, eleito := TRUE]
nel <- el[, .N, by = .(ano, mun, cargo)]
# Itaguaí (58394) 2024: o prefeito eleito concorreu sub judice e seus votos não estão nos resultados por seção nem na
# tabela de resultados; o município-ano fica sem eleito e eleito_share_pref = NA
sem_eleito <- data.table(ano = 2024L, mun = "58394", cargo = "prefeito")
check(nel[cargo == "prefeito", all(N == 1)] && nrow(nel[cargo == "prefeito"]) == 99 &&
      !nrow(merge(nel, sem_eleito, by = c("ano", "mun", "cargo"))), "um prefeito eleito por município-ano (exceto Itaguaí 2024)")
vc <- merge(vc, el, by = c("ano", "mun", "cargo", "numero_candidato"), all.x = TRUE)[is.na(eleito), eleito := FALSE]

# ocupação de cargo eletivo ou administração pública
cands <- rbindlist(lapply(file.path(BD, "candidatos", sprintf("candidatos_%d.parquet", ANOS)), function(f)
  as.data.table(read_parquet(f))[, .(ano, sequencial, ocupacao)]))
cands[, oc := toupper(iconv(ocupacao, "UTF-8", "ASCII//TRANSLIT"))]
PUB <- paste(c("VEREADOR", "PREFEITO", "DEPUTADO", "SENADOR", "GOVERNADOR", "SERVIDOR PUBLICO", "FUNCIONARIO PUBLICO",
               "MEMBRO DO PODER", "ADMINISTRADOR PUBLICO"), collapse = "|")
pub <- unique(cands[grepl(PUB, oc), .(ano, sequencial_candidato = sequencial)])[, pubadm := TRUE]
vc <- merge(vc, pub, by = c("ano", "sequencial_candidato"), all.x = TRUE)[is.na(pubadm), pubadm := FALSE]
# alguns votos de vereador (2008, 2012, 2024; 0,03% do total) vêm sem sequencial: ocupação desconhecida, pubadm = FALSE
check(vc[, sum(votos[sequencial_candidato == ""]) / sum(votos)] < 1e-3, "votos sem sequencial do candidato < 0,1%")

# blocos ideológicos (mesma tabela e regra do 11/12 do pipeline)
CL <- fread(file.path(F3DIR, "..", "pipeline_v2", "R_ext", "ideologia_partidos.csv"), colClasses = list(character = "numero"), encoding = "UTF-8")
CLx <- CL[, .(ano = seq(ano_ini, ano_fim)), by = .(linha = seq_len(nrow(CL)), np = numero, categoria)][, linha := NULL]
vc <- merge(vc, CLx, by = c("np", "ano"), all.x = TRUE)
check(!anyNA(vc$categoria), "todo voto tem categoria ideológica")
vc[, bloco := fcase(categoria == "direita", "dir", categoria == "centro", "cen", default = "esq")]
vc[, sub_esq := fcase(categoria != "esquerda", NA_character_, np == "13", "pt", np == "50", "psol", np == "12", "pdt",
                      np == "40", "psb", default = "esq_outras")]

K <- c("ano", "mun", "place_id", "cargo")
setorder(vc, ano, mun, place_id, cargo, -votos, numero_candidato)
W <- vc[, {
  v <- sum(votos); s <- votos / v; lid <- 1L                      # ordenado por votos: o 1º é o mais votado no local
  hb <- function(m) sum(s[m]^2)
  lb <- function(m) if (isTRUE(m[lid])) s[lid] else 0
  list(votos_cand_w = v, hhi_w = sum(s^2), top1_w = s[lid],
       eleito_share = sum(s[eleito]), ncomp1 = sum(s >= 0.01), top3 = sum(head(s, 3)), pubadm_share = sum(s[pubadm]),
       hhi_dir = hb(bloco == "dir"), hhi_cen = hb(bloco == "cen"), hhi_esq = hb(bloco == "esq"),
       hhi_pt = hb(sub_esq %in% "pt"), hhi_psol = hb(sub_esq %in% "psol"), hhi_pdt = hb(sub_esq %in% "pdt"),
       hhi_psb = hb(sub_esq %in% "psb"), hhi_esq_outras = hb(sub_esq %in% "esq_outras"),
       lider_dir = lb(bloco == "dir"), lider_cen = lb(bloco == "cen"), lider_esq = lb(bloco == "esq"),
       lider_esq_outras = lb(sub_esq %in% "esq_outras"), lider_votos = votos[lid])
}, by = K]
W[sem_eleito, on = c("ano", "mun", "cargo"), eleito_share := NA_real_]
check(W[, max(abs(hhi_dir + hhi_cen + hhi_esq - hhi_w))] < 1e-12, "blocos somam o HHI")
check(W[, max(abs(hhi_pt + hhi_psol + hhi_pdt + hhi_psb + hhi_esq_outras - hhi_esq))] < 1e-12, "sub-blocos de esquerda somam hhi_esq")
check(W[, max(abs(lider_dir + lider_cen + lider_esq - top1_w))] < 1e-12, "líder por bloco soma top1")

# confere com os outcomes validados do pipeline e monta a decomposição do comparecimento
O <- as.data.table(read_parquet(file.path(SNAP, "outcomes_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo %in% names(SUF)]
W <- merge(W, O[, .(ano, place_id, cargo, hhi, top1, votos_cand, votos_nominais, votos_legenda, votos_brancos, votos_nulos,
                    comparecimento, aptos, comparecimento_taxa)], by = c("ano", "place_id", "cargo"), all.x = TRUE)
check(W[, max(abs(hhi - hhi_w), na.rm = TRUE)] < 1e-12 && W[, max(abs(top1 - top1_w), na.rm = TRUE)] < 1e-12, "HHI e top1 iguais aos do pipeline")
check(W[, all(votos_cand == votos_cand_w, na.rm = TRUE)], "votos de candidatos iguais aos do pipeline")
check(W[cargo == "prefeito", all(votos_legenda == 0, na.rm = TRUE)], "prefeito sem voto de legenda")
W[cargo == "prefeito", `:=`(lider_apt = lider_votos / aptos, outros_apt = (votos_nominais - lider_votos) / aptos,
                            bn_apt = (votos_brancos + votos_nulos) / aptos)]
check(W[cargo == "prefeito", max(abs(lider_apt + outros_apt + bn_apt - comparecimento_taxa), na.rm = TRUE)] < 1e-12,
      "decomposição soma o comparecimento")

VARS <- c("eleito_share", "ncomp1", "top3", "pubadm_share", "hhi_dir", "hhi_cen", "hhi_esq", "hhi_pt", "hhi_psol", "hhi_pdt",
          "hhi_psb", "hhi_esq_outras", "lider_dir", "lider_cen", "lider_esq", "lider_esq_outras", "lider_apt", "outros_apt", "bn_apt")
W[, suf := SUF[cargo]]
L <- dcast(W, ano + mun + place_id ~ suf, value.var = VARS, sep = "_")
L[, versao := "principal"]
emptycols <- names(L)[vapply(L, function(z) all(is.na(z)), logical(1))]
L[, (emptycols) := NULL]                                          # lider_apt_ver etc. (só prefeito)
setorder(L, ano, mun, place_id)
write_parquet(L, file.path(EXT, "w00_outcomes_paper.parquet"))
fwrite(rbindlist(chk), file.path(OUT, "W00_checks.csv"))
med <- W[, lapply(.SD, function(z) round(mean(z, na.rm = TRUE), 3)), by = .(cargo, ano), .SDcols = VARS[1:8]][order(cargo, ano)]
options(width = 220); print(med)
cat(sprintf("OK W00: %d locais-ano, %d colunas\n", nrow(L), ncol(L)))
