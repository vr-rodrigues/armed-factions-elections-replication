# W10_beneficiarios.R — beneficiários: para quem vai a concentração do voto para prefeito após a entrada?
# Tipos de candidato (definidos antes da eleição, sem nomes):
#   prefocc : ocupação declarada "prefeito" (prefeito no cargo concorrendo à reeleição)
#   incpart : candidato do partido do prefeito eleito na eleição anterior (pelo número do partido; sem a regra de
#             coligação do F4, por simplicidade)
#   pub     : ocupação de cargo eletivo ou administração pública (mesma regra do W00)
#   gov     : candidato do partido do governador em exercício (15 em 2008-2016, 20 em 2020, 22 em 2024)
# Desfechos por local × ano: share de votos de cada tipo (s_<tipo>) e share do líder local quando ele é do tipo
# (lider_<tipo>; somado ao complemento dá top1). Especificação principal + placebo de vizinhança (como W03), tráfico e milícia.
# Saída: resultados/W10_beneficiarios.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); BD <- file.path(AFE_DADOS, "basedosdados_tse")
BD2 <- file.path(AFE_DADOS, "basedosdados_v2"); OUT <- file.path(F3DIR, "resultados")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo == "prefeito"]
vc[, np := substr(numero_candidato, 1, 2)]
cands <- rbindlist(lapply(file.path(BD, "candidatos", sprintf("candidatos_%d.parquet", ANOS)), function(f)
  as.data.table(read_parquet(f))[, .(ano, sequencial, ocupacao)]))
cands[, oc := toupper(iconv(ocupacao, "UTF-8", "ASCII//TRANSLIT"))]
PUB <- paste(c("VEREADOR", "PREFEITO", "DEPUTADO", "SENADOR", "GOVERNADOR", "SERVIDOR PUBLICO", "FUNCIONARIO PUBLICO",
               "MEMBRO DO PODER", "ADMINISTRADOR PUBLICO"), collapse = "|")
oc <- unique(cands[, .(ano, sequencial_candidato = sequencial, prefocc = oc == "PREFEITO", pub = grepl(PUB, oc))])
oc <- oc[, .(prefocc = any(prefocc), pub = any(pub)), by = .(ano, sequencial_candidato)]
vc <- merge(vc, oc, by = c("ano", "sequencial_candidato"), all.x = TRUE)[is.na(prefocc), `:=`(prefocc = FALSE, pub = FALSE)]
R <- as.data.table(read_parquet(file.path(BD2, "resultados_cand_mun.parquet")))[cargo == "prefeito" & tipo_eleicao == "eleicao ordinaria" & resultado == "eleito"]
inc <- R[, .(ano = ano + 4L, mun = id_municipio_tse, np_inc = numero_partido)]
vc <- merge(vc, inc, by = c("ano", "mun"), all.x = TRUE)
GOVN <- data.table(ano = ANOS, np_gov = c("15", "15", "15", "20", "22"))
vc <- merge(vc, GOVN, by = "ano")
vc[, `:=`(incpart = !is.na(np_inc) & np == np_inc, gov = np == np_gov)]
setorder(vc, ano, mun, place_id, -votos, numero_candidato)
B <- vc[, { v <- sum(votos); s <- votos / v
  list(s_prefocc = sum(s[prefocc]), s_incpart = sum(s[incpart]), s_pub = sum(s[pub]), s_gov = sum(s[gov]),
       lider_prefocc = if (prefocc[1]) s[1] else 0, lider_incpart = if (incpart[1]) s[1] else 0,
       lider_pub = if (pub[1]) s[1] else 0, lider_naopub = if (!pub[1]) s[1] else 0, lider_gov = if (gov[1]) s[1] else 0,
       tem_prefocc = any(prefocc)) }, by = .(ano, mun, place_id)]
cat("municípios-ano com prefeito concorrendo (ocupação declarada):\n"); print(unique(B[, .(ano, mun, tem_prefocc)])[, .(com = sum(tem_prefocc), total = .N), by = ano])

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
PM <- merge(PM, B[, !"mun"], by = c("place_id", "ano"), all.x = TRUE)
YS <- c("s_prefocc", "s_incpart", "s_pub", "s_gov", "lider_prefocc", "lider_incpart", "lider_pub", "lider_naopub", "lider_gov")

TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
XY <- unique(PM[, .(place_id, x, y)])
placebo_amostra <- function(f) {                                         # mesma construção do W03 / V04
  trat <- merge(unique(PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE & g > 0, .(place_id, mun, g)]), XY, by = "place_id")
  cand <- merge(merge(unique(PM[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)]), XY, by = "place_id"), dist, by = "place_id")
  near <- cand[, { tt <- trat[mun == .BY$mun]; dd <- sqrt(outer(x, tt$x, "-")^2 + outer(y, tt$y, "-")^2); k <- max.col(-dd, ties.method = "first")
                   list(place_id = place_id, d_trat = dd[cbind(seq_len(.N), k)], g_near = tt$g[k]) }, by = mun]
  cand <- merge(cand, near[, .(place_id, d_trat, g_near)], by = "place_id")
  denv <- cand[[sprintf("dist_env_%s_m", f)]]
  cand[, papel := fifelse(d_trat <= 1000, "pseudo", fifelse(d_trat > 1500 & denv <= 3000, "controle", NA_character_))]
  sel <- cand[!is.na(papel), .(place_id, g_plac = fifelse(papel == "pseudo", g_near, 0L))]
  merge(PM[balanceado == TRUE], sel, by = "place_id")[, g := g_plac]
}
res <- list()
for (f in c("trafico", "milicia")) {
  am <- list(tratados = PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE], placebo = placebo_amostra(f))
  for (a in names(am)) for (yv in YS) {
    d0 <- am[[a]]; fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
    r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(f, a, yv)), error = function(e) { cat("ERRO", f, a, yv, conditionMessage(e), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    res[[paste(f, a, yv)]] <- data.table(faccao = f, amostra = a, outcome = yv, att = g$att, se = r$se_group_crve,
                                         p = 2 * pnorm(-abs(g$att / r$se_group_crve)), pre_p = r$wald_pre_crve$p,
                                         media_2008 = d[ano == 2008, mean(get(yv))], tratados = sum(r$n$por_coorte[u_g > 0]$N))
    cat(sprintf("%-8s %-9s %-14s ATT %+.4f (%.4f) p %.3f pré %.3f\n", f, a, yv, g$att, r$se_group_crve, res[[paste(f, a, yv)]]$p, r$wald_pre_crve$p))
  }
}
fwrite(rbindlist(res), file.path(OUT, "W10_beneficiarios.csv")); cat("OK W10\n")
