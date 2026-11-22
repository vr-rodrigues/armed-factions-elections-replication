# W13_eleicao_2004.R — painel a partir de 2004. Acrescenta a eleição
# municipal de 2004 ao painel como pré-período adicional. Ganho principal: a coorte de 2012 (a maior) passa a ter um
# pré-período testável (2004 contra a base 2008). Os locais já controlados em 2007 continuam fora: a entrada deles pode
# ser anterior a 2004.
# Ligação seção → local físico: não há geocódigos de seção para 2004. A seção (município, zona, número) de 2004 recebe o
# local da mesma seção em 2008 (versão principal), mantida só se o eleitorado for compatível (aptos 2004 / aptos 2008
# entre 0,5 e 2). Ideologia de 2004: a classificação de 2006 para o mesmo número de partido (Colonnelli et al. começa em
# 2006); votos em números sem classificação ficam fora dos shares e são reportados.
# Desfechos de 2004 calculados como no pipeline (1º turno, eleição ordinária, votos nominais de candidatos).
# Saída: resultados/W13_2004_ligacao.csv, W13_2004_estimativas.csv, W13_2004_coorte2012.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); V3 <- file.path(AFE_DADOS, "basedosdados_v3")
BD <- file.path(AFE_DADOS, "basedosdados_tse"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados")

# ---- ligação 2004 → local físico pela seção de 2008 ----
SP <- as.data.table(read_parquet(file.path(SNAP, "secao_place.parquet")))[ano == 2008 & metodo %in% c("secao_2010_validada", "geocodigo_vizinho_100m")]
d04 <- as.data.table(read_parquet(file.path(V3, "detalhes_votacao_secao_2004.parquet")))[turno == 1 & tipo_eleicao == "eleicao ordinaria"]
d08 <- as.data.table(read_parquet(file.path(BD, "detalhes_votacao_secao", "detalhes_votacao_secao_2008.parquet")))
d08 <- d08[turno == 1 & cargo == "prefeito" & tipo_eleicao == "eleicao ordinaria", .(mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), aptos08 = aptos)]
a04 <- d04[cargo == "prefeito", .(mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), aptos04 = aptos)]
L <- merge(merge(a04, d08, by = c("mun", "zona", "secao"), all.x = TRUE), SP[, .(mun, zona, secao, place_id)], by = c("mun", "zona", "secao"), all.x = TRUE)
L[, ok := !is.na(place_id) & !is.na(aptos08) & aptos04 / aptos08 >= 0.5 & aptos04 / aptos08 <= 2]
LIG <- data.table(item = c("seções 2004", "eleitores 2004", "share de eleitores com seção igual em 2008 ligada a local", "share de eleitores ligada e validada (aptos compatível)"),
                  valor = c(nrow(L), L[, sum(aptos04)], L[!is.na(place_id), sum(aptos04)] / L[, sum(aptos04)], L[ok == TRUE, sum(aptos04)] / L[, sum(aptos04)]))
fwrite(LIG, file.path(OUT, "W13_2004_ligacao.csv")); print(LIG)
L <- L[ok == TRUE, .(mun, zona, secao, place_id)]

# ---- desfechos de 2004 por local ----
r04 <- as.data.table(read_parquet(file.path(V3, "resultados_candidato_secao_2004.parquet")))[turno == 1 & tipo_eleicao == "eleicao ordinaria"]
r04[, `:=`(mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao))]
r04 <- merge(r04, L, by = c("mun", "zona", "secao"))
cv <- r04[, .(votos = sum(votos)), by = .(place_id, cargo, numero_candidato)][votos > 0]
O <- cv[order(-votos), { v <- sum(votos); s <- votos / v
  list(hhi = sum(s^2), margin = s[1] - fifelse(length(s) > 1, s[2], 0), top1 = s[1]) }, by = .(place_id, cargo)][, enc := 1 / hhi]
# ideologia (vereador e prefeito): classificação de 2006 para o mesmo número
CL <- fread(file.path(F3DIR, "..", "pipeline_v2", "R_ext", "ideologia_partidos.csv"), colClasses = list(character = "numero"), encoding = "UTF-8")
CL06 <- CL[ano_ini <= 2006 & ano_fim >= 2006, .(np = numero, categoria)]
cv[, np := substr(numero_candidato, 1, 2)]
cv <- merge(cv, CL06, by = "np", all.x = TRUE)
cobertura <- cv[, .(classificado = sum(votos[!is.na(categoria)]) / sum(votos)), by = cargo]; cat("cobertura da classificação em 2004:\n"); print(cobertura)
I <- cv[!is.na(categoria), { v <- sum(votos); list(s_dir = sum(votos[categoria == "direita"]) / v, s_esq = sum(votos[categoria == "esquerda"]) / v) }, by = .(place_id, cargo)]
I[, saldo := s_dir - s_esq]
O <- merge(O, I, by = c("place_id", "cargo"), all.x = TRUE)
O[, suf := fifelse(cargo == "prefeito", "pref", "ver")]
W04 <- dcast(O, place_id ~ suf, value.var = c("hhi", "margin", "enc", "top1", "s_dir", "s_esq", "saldo"), sep = "_")
tp <- d04[cargo == "prefeito", .(mun = id_municipio_tse, zona = as.integer(zona), secao = as.integer(secao), aptos, comparecimento)]
tp <- merge(tp, L, by = c("mun", "zona", "secao"))[, .(comparecimento_taxa = sum(comparecimento) / sum(aptos)), by = place_id]
W04 <- merge(W04, tp, by = "place_id", all = TRUE)[, ano := 2004L]

# ---- painel 2004-2024 ----
PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal" & balanceado == TRUE]
F6 <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PM <- merge(PM, F6[, .(place_id, ano, s_dir_ver, s_esq_ver, saldo_ver, saldo_pref)], by = c("place_id", "ano"), all.x = TRUE)
fixas <- unique(PM[, .(place_id, mun, g, peso, grade_2km, amostra_fronteira_milicia_1000, amostra_fronteira_trafico_1000)])
P04 <- merge(W04, fixas, by = "place_id")
YS <- c("hhi_pref", "margin_pref", "enc_pref", "comparecimento_taxa", "hhi_ver", "saldo_ver", "s_dir_ver", "s_esq_ver", "saldo_pref")
PX <- rbind(PM[, c("place_id", "ano", "mun", "g", "peso", "grade_2km", "amostra_fronteira_milicia_1000", "amostra_fronteira_trafico_1000", YS), with = FALSE],
            P04[, c("place_id", "ano", "mun", "g", "peso", "grade_2km", "amostra_fronteira_milicia_1000", "amostra_fronteira_trafico_1000", YS), with = FALSE])
ALVOS <- list(trafico = c("hhi_pref", "margin_pref", "enc_pref", "comparecimento_taxa", "hhi_ver"), milicia = c("saldo_ver", "s_dir_ver", "s_esq_ver", "hhi_pref"))
res <- list(); c12 <- list()
for (f in names(ALVOS)) {
  d0 <- PX[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE]
  for (yv in ALVOS[[f]]) {
    comp <- d0[!is.na(get(yv)), .N, by = place_id][N == 6, place_id]          # balanceado 2004-2024 no desfecho
    d <- d0[place_id %in% comp]
    r <- tryCatch(cs_estimar(d, yv, biters = 99, rotulo = paste(f, yv)), error = function(e) { cat("ERRO", f, yv, conditionMessage(e), "\n"); NULL })
    if (is.null(r)) next
    g <- r$overall[tipo == "group"]
    res[[paste(f, yv)]] <- data.table(faccao = f, outcome = yv, att = g$att, se = r$se_group_crve, p = 2 * pnorm(-abs(g$att / r$se_group_crve)),
                                      pre_p = r$wald_pre_crve$p, pre_df = r$wald_pre_crve$df, tratados = sum(r$n$por_coorte[u_g > 0]$N),
                                      unidades = r$n$unidades, coorte2012 = r$n$por_coorte[u_g == 2012]$N)
    x <- r$celulas[g == 2012 & t == 2004]
    c12[[paste(f, yv)]] <- data.table(faccao = f, outcome = yv, att_2012_em_2004 = x$att, se_bootstrap_did = x$se)
    cat(sprintf("%-8s %-20s ATT %+.4f (%.4f) p %.3f pré %.3f (df %d) | trat %d (2012: %d) | coorte 2012 em 2004: %+.4f (%.4f)\n", f, yv, g$att,
                r$se_group_crve, res[[paste(f, yv)]]$p, r$wald_pre_crve$p, r$wald_pre_crve$df, res[[paste(f, yv)]]$tratados,
                res[[paste(f, yv)]]$coorte2012, x$att, x$se))
  }
}
fwrite(rbindlist(res), file.path(OUT, "W13_2004_estimativas.csv")); fwrite(rbindlist(c12), file.path(OUT, "W13_2004_coorte2012.csv"))
cat("OK W13\n")

# ---- com 2004: base duas eleições antes da entrada para TODAS as coortes (coorte reetiquetada g - 4, como no W08) ----
# Reporta o event study completo (base g-4) e, na versão reetiquetada, a média dos efeitos pós-entrada contra a base g-8
# e o coeficiente da eleição anterior à entrada ("vale").
res2 <- list(); evs <- list()
for (z in list(c("trafico", "hhi_pref"), c("trafico", "margin_pref"), c("trafico", "enc_pref"), c("milicia", "saldo_ver"), c("milicia", "s_dir_ver"))) {
  f <- z[1]; yv <- z[2]
  d0 <- PX[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE]
  comp <- d0[!is.na(get(yv)), .N, by = place_id][N == 6, place_id]; d <- d0[place_id %in% comp]
  r <- cs_estimar(d, yv, biters = 99, rotulo = paste(f, yv, "ev"))
  evs[[paste(f, yv)]] <- cbind(faccao = f, outcome = yv, r$event[, .(e, att)], se = sqrt(diag(r$V_event)))
  dc <- copy(d)[g > 0, g := g - 4L]
  rc <- cs_estimar(dc, yv, biters = 99, rotulo = paste(f, yv, "c"))
  ev <- rc$event; V <- rc$V_event; k <- which(ev$e %in% c(4, 8, 12, 16)); l <- rep(1 / length(k), length(k))
  att <- sum(l * ev$att[k]); se <- sqrt(as.numeric(t(l) %*% V[k, k] %*% l)); j <- which(ev$e == 0)
  # mesma agregação com a base usual (horizontes e = 0..12 da versão não reetiquetada), para comparar só a base
  k0 <- which(r$event$e %in% c(0, 4, 8, 12)); l0 <- rep(1 / length(k0), length(k0))
  att0 <- sum(l0 * r$event$att[k0]); se0 <- sqrt(as.numeric(t(l0) %*% r$V_event[k0, k0] %*% l0))
  res2[[paste(f, yv)]] <- data.table(faccao = f, outcome = yv, att_dyn_base_g4 = att0, se_dyn_base_g4 = se0,
                                     p_dyn_base_g4 = 2 * pnorm(-abs(att0 / se0)), att_base_g8 = att, se = se, p = 2 * pnorm(-abs(att / se)),
                                     vale = ev$att[j], se_vale = sqrt(V[j, j]), pre_p = rc$wald_pre_crve$p, tratados = sum(rc$n$por_coorte[u_g > 0]$N))
  cat(sprintf("%-8s %-12s base g-8 (todas as coortes): %+.4f (%.4f) p %.3f | vale %+.4f (%.4f) | pré %.3f\n", f, yv, att, se,
              2 * pnorm(-abs(att / se)), ev$att[j], sqrt(V[j, j]), rc$wald_pre_crve$p))
}
fwrite(rbindlist(res2), file.path(OUT, "W13_2004_base_g8.csv")); fwrite(rbindlist(evs), file.path(OUT, "W13_2004_event_study.csv"))
print(dcast(rbindlist(evs)[, .(faccao, outcome, e, v = sprintf("%+.3f (%.3f)", att, se))], e ~ faccao + outcome, value.var = "v"))
cat("OK W13 base g-8\n")
