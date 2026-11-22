# W15_inferencia_conjunta.R — inferência conjunta da matriz grupo x cargo x desfecho
# Mesma especificação do motor (fronteira 1 km, painel balanceado, ~ mun + lrenda, reg, NYT + NT, group, CRVE na grade de 2 km).
# (1) Diferença entre a estimativa de entrada e o placebo de vizinhança em cada célula, com variância conjunta.
#     Os controles da entrada (nunca tratados a <= 1 km do território) e os pseudo-tratados do placebo se sobrepõem,
#     então as duas estimativas não são independentes. Com S_c = soma, no cluster c, das funções de influência do
#     efeito agregado dividida pelo número de unidades da estimação, Var(E) = sum_c (S_c^E)^2 (o CRVE do motor) e
#     Var(E - P) = sum_c (S_c^E - S_c^P)^2, com S_c = 0 nos clusters ausentes de uma das amostras.
# (2) Testes múltiplos nas 12 células de entrada: Holm, Benjamini-Hochberg e max-t em etapas (Romano-Wolf) por
#     bootstrap multiplicador no cluster (pesos de Rademacher sobre S_c), que respeita a dependência entre células.
# (3) Contagens: tratados por coorte e células de 2 km que contêm tratados.
# Saídas: resultados/W15_matriz_conjunta.csv, W15_contagens.csv, W15_checagem.csv
# Uso: Rscript W15_inferencia_conjunta.R        (especificação principal: ~ mun + log da renda do entorno)
#      Rscript W15_inferencia_conjunta.R mun    (só município, ~ mun; saídas com sufixo _mun)

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados"); F2 <- file.path(F3DIR, "..", "fase2", "resultados")
B <- 9999L; SEED <- 20261111L
ARG <- commandArgs(TRUE); MUN <- length(ARG) > 0 && ARG[1] == "mun"; RENDA <- !MUN   # sem argumento: com renda (especificação principal)
XF <- if (RENDA) ~ mun + lrenda else ~ mun; SUF <- if (MUN) "_mun" else ""

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PM <- merge(PM, X[, .(place_id, ano, saldo_pref, saldo_ver)], by = c("place_id", "ano"), all.x = TRUE)
if (RENDA) { COV <- as.data.table(read_parquet(file.path(EXT, "censo2010_local.parquet")))
  COV[, lrenda := ifelse(!is.na(renda) & renda > 0, log(renda), NA_real_)]
  PM <- merge(PM, COV[, .(place_id, lrenda)], by = "place_id", all.x = TRUE); PM <- PM[!is.na(lrenda)] }
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
GR <- unique(PM[, .(place_id = as.character(place_id), grade_2km = as.character(grade_2km))])
stopifnot(!anyDuplicated(GR$place_id))
YS <- c("hhi_pref", "margin_pref", "saldo_pref", "hhi_ver", "margin_ver", "saldo_ver")
FS <- c("trafico", "milicia")

sem_na <- function(d, y) { fora <- unique(d$place_id[is.na(d[[y]])]); d[!place_id %in% fora] }
amostra <- function(f) PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
# placebo de vizinhança: construção idêntica à de fase3/W03_placebo_paper.R
amostra_placebo <- function(f) {
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
# S_c: soma das funções de influência do efeito agregado no cluster, dividida pelo nº de unidades
escore <- function(r) {
  u <- r$unidades; cl <- GR$grade_2km[match(as.character(u$u_id_chr), GR$place_id)]; stopifnot(!anyNA(cl), nrow(u) == nrow(r$psi_group))
  s <- rowsum(as.numeric(r$psi_group), cl) / nrow(r$psi_group)
  stopifnot(abs(sqrt(sum(s^2)) - r$se_group_crve) < 1e-10)          # reproduz o CRVE do motor
  data.table(cl = rownames(s), S = s[, 1])
}

res <- list(); SC <- list(); cont <- list()
for (f in FS) {
  dE <- amostra(f); dP <- amostra_placebo(f)
  for (y in YS) {
    rot <- paste(f, y)
    rE <- cs_estimar(sem_na(dE, y), y, xformla = XF, biters = 99, rotulo = paste("entrada", rot), retorna_if = TRUE)
    rP <- cs_estimar(sem_na(dP, y), y, xformla = XF, biters = 99, rotulo = paste("placebo", rot), retorna_if = TRUE)
    aE <- rE$overall[tipo == "group"]$att; aP <- rP$overall[tipo == "group"]$att
    sE <- escore(rE); sP <- escore(rP)
    m <- merge(sE, sP, by = "cl", all = TRUE, suffixes = c("_E", "_P")); m[is.na(S_E), S_E := 0]; m[is.na(S_P), S_P := 0]
    se_dif <- sqrt(sum((m$S_E - m$S_P)^2)); cov_ep <- sum(m$S_E * m$S_P)
    uE <- as.character(rE$unidades$u_id_chr); uP <- as.character(rP$unidades$u_id_chr)
    res[[rot]] <- data.table(faccao = f, outcome = y, att = aE, se = rE$se_group_crve, p = 2 * pnorm(-abs(aE / rE$se_group_crve)),
      pre_p = rE$wald_pre_crve$p, plac = aP, se_plac = rP$se_group_crve, p_plac = 2 * pnorm(-abs(aP / rP$se_group_crve)),
      pre_p_plac = rP$wald_pre_crve$p, dif = aE - aP, se_dif = se_dif, p_dif = 2 * pnorm(-abs((aE - aP) / se_dif)),
      corr_ep = cov_ep / (rE$se_group_crve * rP$se_group_crve), se_dif_indep = sqrt(rE$se_group_crve^2 + rP$se_group_crve^2),
      unidades_comuns = length(intersect(uE, uP)), unidades_E = length(uE), unidades_P = length(uP))
    SC[[rot]] <- sE
    cat(sprintf("%-22s entrada %+.4f (%.4f)  placebo %+.4f (%.4f)  dif %+.4f (%.4f) p %.3f  corr %+.2f\n",
                rot, aE, rE$se_group_crve, aP, rP$se_group_crve, aE - aP, se_dif, res[[rot]]$p_dif, res[[rot]]$corr_ep))
    if (y == "hhi_pref") {
      pc <- rE$n$por_coorte[u_g > 0]; ut <- unique(sem_na(dE, y)[g > 0, .(place_id = as.character(place_id))])
      cl_t <- GR$grade_2km[match(ut$place_id, GR$place_id)]
      cont[[f]] <- rbind(data.table(faccao = f, item = paste0("tratados_coorte_", pc$u_g), valor = pc$N),
                         data.table(faccao = f, item = c("tratados", "clusters_com_tratados", "clusters", "unidades"),
                                    valor = c(sum(pc$N), uniqueN(cl_t), rE$n$clusters, rE$n$unidades)))
    }
  }
}
R <- rbindlist(res)

# (2) testes múltiplos nas 12 células de entrada
R[, `:=`(p_holm = p.adjust(p, "holm"), q_bh = p.adjust(p, "BH"))]
cls <- sort(unique(unlist(lapply(SC, `[[`, "cl")))); M <- sapply(SC, function(s) { v <- numeric(length(cls)); v[match(s$cl, cls)] <- s$S; v })
stopifnot(all(abs(sqrt(colSums(M^2)) - R$se) < 1e-10), identical(colnames(M), paste(R$faccao, R$outcome)))
set.seed(SEED); Wt <- matrix(sample(c(-1, 1), B * length(cls), replace = TRUE), nrow = B)
Tb <- abs(sweep(Wt %*% M, 2, R$se, "/")); t_obs <- abs(R$att / R$se)
ord <- order(-t_obs); p_rw <- numeric(length(ord))
for (j in seq_along(ord)) p_rw[j] <- (1 + sum(apply(Tb[, ord[j:length(ord)], drop = FALSE], 1, max) >= t_obs[ord[j]])) / (B + 1)
R[ord, p_maxt := cummax(p_rw)]
# checagem do bootstrap: p unicelular pelo bootstrap contra o p normal
R[, p_boot1 := (1 + colSums(Tb >= rep(t_obs, each = B))) / (B + 1)]
fwrite(R, file.path(OUT, paste0("W15_matriz_conjunta", SUF, ".csv"))); if (RENDA) fwrite(rbindlist(cont), file.path(OUT, "W15_contagens.csv"))

# checagem contra os placebos salvos (fase 2 V04 e fase 3 W03)
PL <- rbind(fread(file.path(F2, "V04_placebo.csv"))[, .(faccao, outcome, att, se)], fread(file.path(OUT, "W03_placebo.csv"))[, .(faccao, outcome, att, se)])
ch <- merge(R[, .(faccao, outcome, plac, se_plac)], PL, by = c("faccao", "outcome"), all.x = TRUE)
ch[, `:=`(dif_att = plac - att, dif_se = se_plac - se)]
if (RENDA) fwrite(ch, file.path(OUT, "W15_checagem.csv"))
cat("\nmaior diferença contra os placebos salvos: att", max(abs(ch$dif_att), na.rm = TRUE), " se", max(abs(ch$dif_se), na.rm = TRUE),
    " | células sem placebo salvo:", sum(is.na(ch$att)), "\n\n")
print(R[, .(faccao, outcome, att = round(att, 4), p = round(p, 4), p_holm = round(p_holm, 4), q_bh = round(q_bh, 4), p_maxt = round(p_maxt, 4),
            p_boot1 = round(p_boot1, 4), dif = round(dif, 4), se_dif = round(se_dif, 4), p_dif = round(p_dif, 4))])
print(rbindlist(cont))
cat("OK W15\n")
