# W07_balanco.R — balanço pré-tratamento e seleção sobre tendência.
# Diagnóstico descritivo de seleção na amostra principal (fronteira 1 km, balanceada):
#   (a) balanço em 2008: diferença tratados − controles DENTRO do município (variáveis centradas na média do município),
#       diferença normalizada e EP clusterizado na grade de 2 km;
#   (b) seleção sobre tendência: entre os locais ainda não tratados em 2012, a variação 2008→2012 do desfecho difere
#       entre os que entram depois (coortes 2016–2024) e os que nunca entram, dentro do município?
#   (c) as coortes diferem em nível em 2008 (teste F da coorte, dentro do município)?
# Não estima efeito de tratamento; é o balanço que acompanha o CS-DID.
# Saída: resultados/W07_balanco.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados")
PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
PM[, log_aptos := log(aptos)]
YS <- c("hhi_pref", "margin_pref", "enc_pref", "comparecimento_taxa", "hhi_ver", "margin_ver", "saldo_ver", "s_dir_ver", "s_esq_ver",
        "saldo_pref", "log_aptos")

# regressão de y em x dentro do município, EP clusterizado (CRVE) na grade de 2 km
within_ols <- function(y, x, mun, cl) {
  yd <- y - ave(y, mun); xd <- x - ave(x, mun)
  b <- sum(xd * yd) / sum(xd^2); e <- yd - b * xd
  s <- rowsum(xd * e, cl); se <- sqrt(sum(s^2)) / sum(xd^2)
  c(b = b, se = se, p = 2 * pnorm(-abs(b / se)))
}
res <- list()
for (f in c("trafico", "milicia")) {
  d <- PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
  b08 <- d[ano == 2008]; b08[, trat := as.numeric(g > 0)]
  w <- dcast(d[ano %in% c(2008, 2012)], place_id + mun + grade_2km + g ~ ano, value.var = YS)
  for (yv in YS) {
    z <- b08[!is.na(get(yv))]
    a <- within_ols(z[[yv]], z$trat, z$mun, z$grade_2km)
    nd <- (mean(z[trat == 1][[yv]]) - mean(z[trat == 0][[yv]])) / sqrt((var(z[trat == 1][[yv]]) + var(z[trat == 0][[yv]])) / 2)
    # (b) tendência 2008→2012 entre ainda não tratados em 2012 (coortes 2016+ vs nunca)
    t <- w[g == 0 | g >= 2016]; dy <- t[[paste0(yv, "_2012")]] - t[[paste0(yv, "_2008")]]; ok <- !is.na(dy)
    bt <- within_ols(dy[ok], as.numeric(t$g[ok] > 0), t$mun[ok], t$grade_2km[ok])
    # (c) F de coorte em nível (2008), dentro do município: regressão de y centrado em dummies de coorte centradas
    co <- z[g > 0]; fstat <- NA_real_; pf <- NA_real_
    if (uniqueN(co$g) > 1) {
      Y <- co[[yv]] - ave(co[[yv]], co$mun)
      D <- sapply(sort(unique(co$g))[-1], function(gg) { v <- as.numeric(co$g == gg); v - ave(v, co$mun) })
      fit <- lm.fit(cbind(D), Y); rss1 <- sum(fit$residuals^2); rss0 <- sum(Y^2); q <- ncol(D)
      fstat <- ((rss0 - rss1) / q) / (rss1 / (nrow(co) - q - uniqueN(co$mun))); pf <- 1 - pf(fstat, q, nrow(co) - q - uniqueN(co$mun))
    }
    res[[paste(f, yv)]] <- data.table(faccao = f, outcome = yv, media_trat_2008 = mean(z[trat == 1][[yv]]), media_ctrl_2008 = mean(z[trat == 0][[yv]]),
                                      dif_norm_bruta = nd, dif_dentro_mun = a[["b"]], se_dentro = a[["se"]], p_dentro = a[["p"]],
                                      tend_0812_dif = bt[["b"]], tend_0812_se = bt[["se"]], tend_0812_p = bt[["p"]], F_coorte_p = pf)
  }
}
R <- rbindlist(res); fwrite(R, file.path(OUT, "W07_balanco.csv"))
options(width = 220); print(R[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)])
cat("OK W07\n")
