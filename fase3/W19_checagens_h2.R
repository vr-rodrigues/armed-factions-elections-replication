# W19_checagens_h2.R — checagens dos resultados em que H2 e H3 se apoiam.
# Especificação principal (~ mun + lrenda), motor do projeto.
# 1. Entrada − placebo com variância conjunta (como o W15) para os desfechos de "quem ganha".
# 2. Forma funcional da renda: linear no log (principal), quadrática, quartis.
# 3. Coortes de 2016–2024 apenas: para elas o Censo de 2010 é anterior à entrada (na coorte de 2012 é contemporâneo).
# Saídas: resultados/W19_entrada_placebo.csv, resultados/W19_forma_funcional.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
RAIZ <- normalizePath(file.path(F3DIR, "..")); AQUI <- file.path(F3DIR, "resultados")
source(file.path(RAIZ, "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
ANOS <- c(2008L, 2012L, 2016L, 2020L, 2024L)

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "f6_blocos", "w00_outcomes_paper")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  novas <- setdiff(names(X), c(names(PM), "versao", "mun"))
  PM <- merge(PM, X[, c("place_id", "ano", novas), with = FALSE], by = c("place_id", "ano"), all.x = TRUE)
}
# receita de campanha: percentil (W18) e quartil superior (W12), mesma construção
R <- as.data.table(read_parquet(file.path(AFE_DADOS, "basedosdados_v3/receitas_candidato_agregado.parquet")))
R <- R[, .(receita = sum(receita_financeira)), by = .(ano, mun = id_municipio_tse, cargo, sequencial_candidato)]
vc <- as.data.table(read_parquet(file.path(SNAP, "votos_cand_place.parquet")))[versao == "principal" & ano %in% ANOS & cargo %in% c("prefeito", "vereador")]
vc <- merge(vc, R, by = c("ano", "mun", "cargo", "sequencial_candidato"), all.x = TRUE)
cm <- unique(vc[, .(ano, mun, cargo, sequencial_candidato, receita)])
cm[!is.na(receita), pct := (frank(receita, ties.method = "average") - 0.5) / .N, by = .(ano, mun, cargo)]
cm[, q4 := !is.na(receita) & receita >= quantile(receita, 0.75, na.rm = TRUE), by = .(ano, mun, cargo)]
vc <- merge(vc, cm[, .(ano, mun, cargo, sequencial_candidato, pct, q4)], by = c("ano", "mun", "cargo", "sequencial_candidato"))
B <- vc[, { s <- votos / sum(votos); ok <- !is.na(pct)
  list(vw_pctrec = if (any(ok)) sum(s[ok] * pct[ok]) / sum(s[ok]) else NA_real_, s_q4rec = sum(s[q4])) }, by = .(ano, place_id, cargo)]
B[, suf := fifelse(cargo == "prefeito", "pref", "ver")]
W <- dcast(B, ano + place_id ~ suf, value.var = c("vw_pctrec", "s_q4rec"), sep = "_")
PM <- merge(PM, W, by = c("place_id", "ano"), all.x = TRUE)
# renda: termos adicionais
CV <- copy(cs_covariaveis()); CV[, lrenda2 := lrenda^2]
qs <- quantile(CV$lrenda, c(.25, .5, .75), na.rm = TRUE)
CV[, `:=`(rq2 = as.numeric(lrenda > qs[1] & lrenda <= qs[2]), rq3 = as.numeric(lrenda > qs[2] & lrenda <= qs[3]), rq4 = as.numeric(lrenda > qs[3]))]
PM <- merge(PM, CV[, .(place_id, lrenda, lrenda2, rq2, rq3, rq4)], by = "place_id", all.x = TRUE)

TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
GR <- unique(PM[, .(place_id = as.character(place_id), grade_2km = as.character(grade_2km))])
sem_na <- function(d, y) { fora <- unique(d$place_id[is.na(d[[y]])]); d[!place_id %in% fora] }
amostra <- function(f) PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
amostra_placebo <- function(f) {     # idêntica à de fase3/W03 e W15
  XY <- unique(PM[, .(place_id, x, y)]); dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
  trat <- unique(PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE & g > 0, .(place_id, mun, g)])
  trat <- merge(trat, XY, by = "place_id")
  cand <- unique(PM[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)])
  cand <- merge(merge(cand, XY, by = "place_id"), dist, by = "place_id")
  near <- cand[, { tt <- trat[mun == .BY$mun]; dd <- sqrt(outer(x, tt$x, "-")^2 + outer(y, tt$y, "-")^2)
    k <- max.col(-dd, ties.method = "first"); list(place_id = place_id, d_trat = dd[cbind(seq_len(.N), k)], g_near = tt$g[k]) }, by = mun]
  cand <- merge(cand, near[, .(place_id, d_trat, g_near)], by = "place_id")
  denv <- cand[[sprintf("dist_env_%s_m", f)]]
  cand[, papel := fifelse(d_trat <= 1000, "pseudo", fifelse(d_trat > 1500 & denv <= 3000, "controle", NA_character_))]
  sel <- cand[!is.na(papel), .(place_id, g_plac = fifelse(papel == "pseudo", g_near, 0L))]
  merge(PM[balanceado == TRUE], sel, by = "place_id")[, g := g_plac]
}
escore <- function(r) { u <- r$unidades; cl <- GR$grade_2km[match(as.character(u$u_id_chr), GR$place_id)]
  s <- rowsum(as.numeric(r$psi_group), cl) / nrow(r$psi_group); stopifnot(abs(sqrt(sum(s^2)) - r$se_group_crve) < 1e-10)
  data.table(cl = rownames(s), S = s[, 1]) }

# ---------------- 1. entrada − placebo ----------------
ALVOS <- list(trafico = c("hhi_pref", "eleito_share_pref", "vw_pctrec_pref", "top1_pref", "vw_pctrec_ver", "s_q4rec_ver", "eleito_share_ver"),
              milicia = c("saldo_ver", "s_dir_ver", "s_esq_ver", "dir_outras_ver", "dir_pol_ver", "dir_nao_pol_ver", "s_q4rec_ver", "vw_pctrec_ver"))
res <- list()
for (f in names(ALVOS)) { dE <- amostra(f); dP <- amostra_placebo(f)
  for (y in ALVOS[[f]]) {
    rE <- cs_estimar(sem_na(dE, y), y, biters = 49, retorna_if = TRUE); rP <- cs_estimar(sem_na(dP, y), y, biters = 49, retorna_if = TRUE)
    aE <- rE$overall[tipo == "group"]$att; aP <- rP$overall[tipo == "group"]$att
    m <- merge(escore(rE), escore(rP), by = "cl", all = TRUE, suffixes = c("_E", "_P")); m[is.na(S_E), S_E := 0]; m[is.na(S_P), S_P := 0]
    sd_ <- sqrt(sum((m$S_E - m$S_P)^2)); ev <- rE$event
    res[[paste(f, y)]] <- data.table(faccao = f, outcome = y, att = aE, se = rE$se_group_crve, p = 2 * pnorm(-abs(aE / rE$se_group_crve)), pre_p = rE$wald_pre_crve$p,
      plac = aP, se_plac = rP$se_group_crve, p_plac = 2 * pnorm(-abs(aP / rP$se_group_crve)), pre_p_plac = rP$wald_pre_crve$p,
      dif = aE - aP, se_dif = sd_, p_dif = 2 * pnorm(-abs((aE - aP) / sd_)), e0 = ev[e == 0]$att, e12 = ev[e == 12]$att, tratados = sum(rE$n$por_coorte[u_g > 0]$N))
    cat(sprintf("%-8s %-18s entrada %+.4f (%.4f) p %.3f pré %.3f | placebo %+.4f (%.4f) | dif %+.4f (%.4f) p %.3f\n", f, y, aE, rE$se_group_crve,
                res[[paste(f, y)]]$p, rE$wald_pre_crve$p, aP, rP$se_group_crve, aE - aP, sd_, res[[paste(f, y)]]$p_dif))
  } }
fwrite(rbindlist(res), file.path(AQUI, "W19_entrada_placebo.csv"))

# ---------------- 2. forma funcional da renda e 3. coortes de 2016–2024 ----------------
ESP <- list(linear = ~ mun + lrenda, quadratica = ~ mun + lrenda + lrenda2, quartis = ~ mun + rq2 + rq3 + rq4, so_mun = ~ mun)
CH <- list(c("trafico", "hhi_pref"), c("trafico", "eleito_share_pref"), c("trafico", "vw_pctrec_pref"), c("milicia", "saldo_ver"), c("milicia", "s_dir_ver"))
r2 <- list()
for (z in CH) { d <- sem_na(amostra(z[1]), z[2]); d <- d[!is.na(lrenda)]
  for (e in names(ESP)) { r <- cs_estimar(d, z[2], xformla = ESP[[e]], biters = 49); a <- r$overall[tipo == "group"]$att
    r2[[paste(z[1], z[2], e)]] <- data.table(faccao = z[1], outcome = z[2], espec = e, amostra = "todas as coortes", att = a, se = r$se_group_crve,
      p = 2 * pnorm(-abs(a / r$se_group_crve)), pre_p = r$wald_pre_crve$p, tratados = sum(r$n$por_coorte[u_g > 0]$N)) }
  d16 <- d[!(g == 2012)]; r <- cs_estimar(d16, z[2], biters = 49); a <- r$overall[tipo == "group"]$att
  r2[[paste(z[1], z[2], "c16")]] <- data.table(faccao = z[1], outcome = z[2], espec = "linear", amostra = "coortes 2016-2024", att = a, se = r$se_group_crve,
    p = 2 * pnorm(-abs(a / r$se_group_crve)), pre_p = r$wald_pre_crve$p, tratados = sum(r$n$por_coorte[u_g > 0]$N)) }
R2 <- rbindlist(r2); fwrite(R2, file.path(AQUI, "W19_forma_funcional.csv"))
print(R2[, .(faccao, outcome, espec, amostra, att = round(att, 4), se = round(se, 4), p = round(p, 3), pre_p = round(pre_p, 3), tratados)])
cat("OK W19\n")
