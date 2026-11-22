# 11_f6_ideologia.R — família F6 (exploratória): ideologia do voto no local
# Classificação esquerda/centro/direita: tabela A1 de "Politics at Work", atribuída pelo NÚMERO do partido em cada ano
# (R_ext/ideologia_partidos.csv; regras para partidos fora da tabela fixadas antes de estimar).
# Outcomes por local × ano × cargo (shares dos votos nominais, legenda fora, como no 05):
#   s_dir, s_cen, s_esq (e s_nc, não classificado); saldo = s_dir − s_esq; saldo_rob = idem com o PRD (2024) não classificado
# Cargos: prefeito, vereador (painel municipal); presidente, governador, senador, dep. estadual, dep. federal (painel geral).
# Saída: EXT_DIR/f6_ideologia.parquet (local × ano, colunas <medida>_<cargo>); CHECK_EXT/11_*.csv

source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "00_config_ext.R"))
cat("11_f6_ideologia.R\n")
SUFC <- c("prefeito" = "pref", "vereador" = "ver", "presidente" = "pres", "governador" = "gov", "senador" = "sen",
          "deputado estadual" = "depest", "deputado federal" = "depfed")
vc <- read_snap("votos_cand_place")[cargo %in% names(SUFC)]
vc <- vc[versao == "principal" | ano %in% c(2006, 2008)]
vc[, np := substr(numero_candidato, 1, 2)]

CL <- fread(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "ideologia_partidos.csv"),
            colClasses = list(character = "numero"), encoding = "UTF-8")
CLx <- CL[, .(ano = seq(ano_ini, ano_fim)), by = .(np = numero, categoria, regra)]
check(!anyDuplicated(CLx[, .(np, ano)]), "partido com mais de uma categoria no mesmo ano")
vc <- merge(vc, CLx[, .(np, ano, categoria, regra)], by = c("np", "ano"), all.x = TRUE)
nc <- vc[is.na(categoria), .(votos = sum(votos), partidos = paste(sort(unique(np)), collapse = " ")), by = .(ano, cargo)]
fwrite(nc, file.path(CHECK_EXT, "11_votos_nao_classificados.csv"))
vc[, categoria_rob := fifelse(grepl("^fusão PTB", regra), NA_character_, categoria)]

K <- c("versao", "ano", "mun", "place_id", "cargo")
f6 <- vc[, {
  v <- sum(votos)
  list(s_dir = sum(votos[categoria %in% "direita"]) / v, s_cen = sum(votos[categoria %in% "centro"]) / v,
       s_esq = sum(votos[categoria %in% "esquerda"]) / v, s_nc = sum(votos[is.na(categoria)]) / v,
       saldo_rob = (sum(votos[categoria_rob %in% "direita"]) - sum(votos[categoria_rob %in% "esquerda"])) / v)
}, by = K]
f6[, saldo := s_dir - s_esq]
check(f6[, all(abs(s_dir + s_cen + s_esq + s_nc - 1) < 1e-12)], "shares não somam 1")
f6[, suf := SUFC[cargo]]
W <- dcast(f6, versao + ano + mun + place_id ~ suf, value.var = c("s_dir", "s_cen", "s_esq", "saldo", "saldo_rob"), sep = "_")
setorder(W, versao, ano, mun, place_id)
write_ext(W, "f6_ideologia")

# relatório: médias municipais (todas as seções do local) por ano e cargo, versão principal
vm <- read_snap("votos_cand_mun")[cargo %in% names(SUFC)][, np := substr(numero_candidato, 1, 2)]
vm <- merge(vm, CLx[, .(np, ano, categoria)], by = c("np", "ano"), all.x = TRUE)
med <- vm[, .(direita = sum(votos[categoria %in% "direita"]) / sum(votos), centro = sum(votos[categoria %in% "centro"]) / sum(votos),
              esquerda = sum(votos[categoria %in% "esquerda"]) / sum(votos), nao_classif = sum(votos[is.na(categoria)]) / sum(votos)),
          by = .(cargo, ano)][order(cargo, ano)]
fwrite(med, file.path(CHECK_EXT, "11_shares_regiao.csv"))
options(width = 200); print(med[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)]); print(nc)
cat("OK 11\n")
