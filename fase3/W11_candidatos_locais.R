# W11_candidatos_locais.R — candidatos locais e intermediação de votos.
# Sem lista de nomes (risco jurídico), procura o rastro da entrega de votos no voto para vereador:
# o ganho vai para candidatos com base no próprio bairro ou para candidatos de fora dele?
#   Base de um candidato (município × ano): o local físico onde ele teve mais votos.
#   Candidato "local" para o local i: a base dele fica a até 1 km de i.
#   Desfechos (shares do voto nominal de vereador no local): s_local, s_naolocal; por bloco: direita local/não local,
#   partidos pequenos de direita local/não local, esquerda local/não local.
# Entrega coordenada por uma organização territorial deve se concentrar em candidatos locais; uma mudança difusa de
# preferência partidária deve beneficiar também candidatos de fora do bairro.
# Especificação principal + placebo de vizinhança (como W03). Saída: resultados/W11_candidatos_locais.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); OUT <- file.path(F3DIR, "resultados")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)
RAIO <- if (length(commandArgs(TRUE))) as.numeric(commandArgs(TRUE)[1]) else 1000   # raio da "base" do candidato, em metros

vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo == "vereador"]
vc[, np := substr(numero_candidato, 1, 2)]
CL <- fread(file.path(F3DIR, "..", "pipeline_v2", "R_ext", "ideologia_partidos.csv"), colClasses = list(character = "numero"), encoding = "UTF-8")
CLx <- CL[, .(ano = seq(ano_ini, ano_fim)), by = .(linha = seq_len(nrow(CL)), np = numero, categoria)][, linha := NULL]
vc <- merge(vc, CLx, by = c("np", "ano"), all.x = TRUE)
stopifnot(!anyNA(vc$categoria))
# partidos pequenos de direita: mesma regra do 12_f6_blocos.R
vc[, dir_outras := categoria == "direita" & !(np == "10" | (np == "20" & ano <= 2022) | np %in% c("22", "17") |
                                               np == "11" | (np == "25" & ano <= 2020) | (np == "44" & ano >= 2022))]
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))[, .(place_id, x, y)]
vc <- merge(vc, TP, by = "place_id")
base <- vc[order(-votos)][, .SD[1], by = .(ano, mun, numero_candidato)][, .(ano, mun, numero_candidato, bx = x, by = y)]
vc <- merge(vc, base, by = c("ano", "mun", "numero_candidato"))
vc[, local := sqrt((x - bx)^2 + (y - by)^2) <= RAIO]
B <- vc[, { v <- sum(votos)
  list(s_local = sum(votos[local]) / v, s_naolocal = sum(votos[!local]) / v,
       s_dir_local = sum(votos[local & categoria == "direita"]) / v, s_dir_naolocal = sum(votos[!local & categoria == "direita"]) / v,
       s_dirout_local = sum(votos[local & dir_outras]) / v, s_dirout_naolocal = sum(votos[!local & dir_outras]) / v,
       s_esq_local = sum(votos[local & categoria == "esquerda"]) / v, s_esq_naolocal = sum(votos[!local & categoria == "esquerda"]) / v) },
  by = .(ano, place_id)]
cat("médias por ano:\n"); print(B[, lapply(.SD, function(z) round(mean(z), 3)), by = ano, .SDcols = c("s_local", "s_dir_local", "s_dirout_local")][order(ano)])

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
PM <- merge(PM, B, by = c("place_id", "ano"), all.x = TRUE)
YS <- c("s_local", "s_naolocal", "s_dir_local", "s_dir_naolocal", "s_dirout_local", "s_dirout_naolocal", "s_esq_local", "s_esq_naolocal")
TPd <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
XY <- unique(PM[, .(place_id, x, y)])
placebo_amostra <- function(f) {
  trat <- merge(unique(PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE & g > 0, .(place_id, mun, g)]), XY, by = "place_id")
  cand <- merge(merge(unique(PM[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)]), XY, by = "place_id"), TPd, by = "place_id")
  near <- cand[, { tt <- trat[mun == .BY$mun]; dd <- sqrt(outer(x, tt$x, "-")^2 + outer(y, tt$y, "-")^2); k <- max.col(-dd, ties.method = "first")
                   list(place_id = place_id, d_trat = dd[cbind(seq_len(.N), k)], g_near = tt$g[k]) }, by = mun]
  cand <- merge(cand, near[, .(place_id, d_trat, g_near)], by = "place_id")
  denv <- cand[[sprintf("dist_env_%s_m", f)]]
  cand[, papel := fifelse(d_trat <= 1000, "pseudo", fifelse(d_trat > 1500 & denv <= 3000, "controle", NA_character_))]
  sel <- cand[!is.na(papel), .(place_id, g_plac = fifelse(papel == "pseudo", g_near, 0L))]
  merge(PM[balanceado == TRUE], sel, by = "place_id")[, g := g_plac]
}
res <- list()
for (f in c("milicia", "trafico")) {
  am <- list(tratados = PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE], placebo = placebo_amostra(f))
  for (a in names(am)) for (yv in YS) {
    d0 <- am[[a]]; fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
    r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(f, a, yv)), error = function(e) { cat("ERRO", f, a, yv, conditionMessage(e), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    res[[paste(f, a, yv)]] <- data.table(faccao = f, amostra = a, outcome = yv, att = g$att, se = r$se_group_crve,
                                         p = 2 * pnorm(-abs(g$att / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                         media_2008 = d[ano == 2008, mean(get(yv))], tratados = sum(r$n$por_coorte[u_g > 0]$N))
    cat(sprintf("%-8s %-9s %-18s ATT %+.4f (%.4f) p %.3f pré %.3f | média 2008 %.3f\n", f, a, yv, g$att, r$se_group_crve,
                res[[paste(f, a, yv)]]$p, r$wald_pre_crve$p, res[[paste(f, a, yv)]]$media_2008))
  }
}
fwrite(rbindlist(res)[, raio_m := RAIO], file.path(OUT, if (RAIO == 1000) "W11_candidatos_locais.csv" else sprintf("W11_candidatos_locais_%dm.csv", RAIO))); cat("OK W11\n")
