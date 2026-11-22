# 12_f6_blocos.R — decomposição da F6 por bloco partidário (exploratória)
# Shares dos votos nominais do local (vereador e prefeito) por bloco; os blocos de cada lado somam s_dir / s_esq do 11.
#   direita: evangelica = 10 (PRB/Republicanos) + 20 até 2022 (PSC); pl_psl = 22 + 17; tradicional = 11 + 25 (até 2020)
#            + 44 (2022–2024, União); outras = demais de direita
#   direita x ocupação: dir_pol = candidatos de direita com ocupação policial/militar (lista da F4); dir_nao_pol = demais
#   esquerda: pt = 13; psol = 50; pdt = 12; psb = 40; outras = demais de esquerda
# Saída: EXT_DIR/f6_blocos.parquet (local × ano, colunas <bloco>_<cargo>); CHECK_EXT/12_*.csv

.d <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(.d, "00_config_ext.R"))
cat("12_f6_blocos.R\n")
SUFC <- c("prefeito" = "pref", "vereador" = "ver")
vc <- read_snap("votos_cand_place")[cargo %in% names(SUFC)][versao == "principal" | ano %in% c(2006, 2008)]
vc[, np := substr(numero_candidato, 1, 2)]
CL <- fread(file.path(.d, "ideologia_partidos.csv"), colClasses = list(character = "numero"), encoding = "UTF-8")
CLx <- CL[, .(ano = seq(ano_ini, ano_fim)), by = .(linha = seq_len(nrow(CL)), np = numero, categoria)][, linha := NULL]
vc <- merge(vc, CLx, by = c("np", "ano"), all.x = TRUE)
check(!anyNA(vc$categoria), "voto sem categoria ideológica")
cands <- rbindlist(lapply(list.files(file.path(BD_DIR, "candidatos"), full.names = TRUE), function(f)
  as.data.table(read_parquet(f))[, .(ano, sequencial, ocupacao)]))
cands[, oc := toupper(iconv(ocupacao, "UTF-8", "ASCII//TRANSLIT"))]
POL <- c("POLICIAL MILITAR", "POLICIAL CIVIL", "MILITAR REFORMADO", "BOMBEIRO MILITAR", "MEMBRO DAS FORCAS ARMADAS")
pol <- unique(cands[oc %in% POL, .(ano, sequencial_candidato = sequencial)])[, pol := TRUE]
vc <- merge(vc, pol, by = c("ano", "sequencial_candidato"), all.x = TRUE)[is.na(pol), pol := FALSE]

vc[, bloco_dir := fcase(categoria != "direita", NA_character_,
                        np == "10" | (np == "20" & ano <= 2022), "evangelica",
                        np %in% c("22", "17"), "pl_psl",
                        np == "11" | (np == "25" & ano <= 2020) | (np == "44" & ano >= 2022), "tradicional",
                        default = "outras")]
vc[, bloco_esq := fcase(categoria != "esquerda", NA_character_, np == "13", "pt", np == "50", "psol", np == "12", "pdt",
                        np == "40", "psb", default = "outras")]
K <- c("versao", "ano", "mun", "place_id", "cargo")
B <- vc[, {
  v <- sum(votos)
  list(dir_evangelica = sum(votos[bloco_dir %in% "evangelica"]) / v, dir_pl_psl = sum(votos[bloco_dir %in% "pl_psl"]) / v,
       dir_tradicional = sum(votos[bloco_dir %in% "tradicional"]) / v, dir_outras = sum(votos[bloco_dir %in% "outras"]) / v,
       dir_pol = sum(votos[categoria == "direita" & pol]) / v, dir_nao_pol = sum(votos[categoria == "direita" & !pol]) / v,
       esq_pt = sum(votos[bloco_esq %in% "pt"]) / v, esq_psol = sum(votos[bloco_esq %in% "psol"]) / v,
       esq_pdt = sum(votos[bloco_esq %in% "pdt"]) / v, esq_psb = sum(votos[bloco_esq %in% "psb"]) / v,
       esq_outras = sum(votos[bloco_esq %in% "outras"]) / v, cen = sum(votos[categoria == "centro"]) / v,
       s_dir = sum(votos[categoria == "direita"]) / v, s_esq = sum(votos[categoria == "esquerda"]) / v)
}, by = K]
check(B[, max(abs(dir_evangelica + dir_pl_psl + dir_tradicional + dir_outras - s_dir))] < 1e-12, "blocos de direita não somam")
check(B[, max(abs(dir_pol + dir_nao_pol - s_dir))] < 1e-12, "direita policial + não policial não soma")
check(B[, max(abs(esq_pt + esq_psol + esq_pdt + esq_psb + esq_outras - s_esq))] < 1e-12, "blocos de esquerda não somam")
F6 <- as.data.table(read_parquet(file.path(EXT_DIR, "f6_ideologia.parquet")))
cmp <- merge(B[cargo == "vereador", .(versao, ano, place_id, s_dir)], F6[, .(versao, ano, place_id, s_dir_ver)], by = c("versao", "ano", "place_id"))
check(cmp[, max(abs(s_dir - s_dir_ver))] < 1e-12, "s_dir difere do 11")
B[, suf := SUFC[cargo]]
VARS <- setdiff(names(B), c(K, "suf", "s_dir", "s_esq"))
W <- dcast(B, versao + ano + mun + place_id ~ suf, value.var = VARS, sep = "_")
setorder(W, versao, ano, mun, place_id)
write_ext(W, "f6_blocos")
med <- B[versao == "principal", lapply(.SD, function(z) round(mean(z), 3)), by = .(cargo, ano), .SDcols = VARS][order(cargo, ano)]
fwrite(med, file.path(CHECK_EXT, "12_blocos_medias.csv")); options(width = 250); print(med)
cat("OK 12\n")
