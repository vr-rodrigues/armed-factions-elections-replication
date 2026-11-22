# W08_antecipacao.R — sensibilidade à eleição-base (antecipação, reversão à média).
# Antes da entrada, os desfechos dos locais tratados oscilam
# (ex.: HHI do prefeito sobe 2008→2012 e cai 2012→2016 nas coortes 2020/2024 do tráfico, W07). Se a eleição usada como
# base (a imediatamente anterior à entrada) estiver num vale, parte do efeito pode ser reversão à média ("Ashenfelter dip")
# ou antecipação. Teste: base duas eleições antes da entrada.
#   (a) principal: todas as coortes, base g-4;  (b) coortes 2016-2024, base g-4 (mesma amostra de (c));
#   (c) coortes 2016-2024, base g-8: a coorte é reetiquetada uma eleição antes (g' = g - 4), o que trata a eleição anterior
#       à entrada como possivelmente afetada e afasta esses locais do grupo de controle a partir dela. É idêntico ao
#       parâmetro anticipation do did medido em anos (anticipation = 4, isto é, uma eleição): coeficientes e EP iguais em
#       todos os horizontes. Reporta: o coeficiente da eleição anterior à entrada (e' = 0, o "vale") e a média dos coeficientes
#       pós-entrada (e' = 4, 8, 12) contra a base g-8, com EP pela covariância CRVE do event study.
# Também: HonestDiD (magnitudes relativas, efeito pós médio) sem o pré-período mais distante (e = -16), que só a coorte
# de 2024 identifica, reportado como sensibilidade.
# Saída: resultados/W08_antecipacao.csv, W08_honest_sem16.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(HonestDiD) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados")
PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "w00_outcomes_paper")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
}
ALVOS <- list(trafico = c("hhi_pref", "margin_pref", "enc_pref", "eleito_share_pref", "lider_apt_pref"),
              milicia = c("saldo_ver", "s_dir_ver", "s_esq_ver"))
res <- list()
for (f in names(ALVOS)) {
  d0 <- PM[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
  for (yv in ALVOS[[f]]) {
    fora <- unique(d0$place_id[is.na(d0[[yv]])]); d <- d0[!place_id %in% fora]
    d16 <- d[!(g == 2012)]                                               # sem a coorte de 2012
    d16c <- copy(d16)[g > 0, g := g - 4L]
    vers <- list(a = d, b = d16, c = d16c)
    for (v in names(vers)) {
      r <- tryCatch(cs_estimar(vers[[v]], yv, biters = 99, rotulo = paste(f, yv, v)),
                    error = function(e) { cat("ERRO", f, yv, v, conditionMessage(e), "
"); NULL })
      if (is.null(r)) next
      ev <- r$event; V <- r$V_event
      media <- function(es) { k <- which(ev$e %in% es); l <- rep(1 / length(k), length(k))
                              c(sum(l * ev$att[k]), sqrt(as.numeric(t(l) %*% V[k, k] %*% l))) }
      if (v == "c") {                                                    # efeitos pós-entrada contra a base g-8
        m <- media(c(4, 8, 12)); att <- m[1]; se <- m[2]; att_dyn <- m[1]; se_dyn <- m[2]
        vale <- ev$att[ev$e == 0]; se_vale <- sqrt(V[which(ev$e == 0), which(ev$e == 0)])
      } else {
        g <- r$overall[tipo == "group"]; att <- g$att; se <- r$se_group_crve; vale <- NA_real_; se_vale <- NA_real_
        # mesma agregação da versão c (média simples dos coeficientes pós-entrada, nos mesmos horizontes), para que a
        # comparação b x c isole a base e os controles
        m <- media(if (v == "b") c(0, 4, 8) else c(0, 4, 8, 12)); att_dyn <- m[1]; se_dyn <- m[2]
      }
      res[[paste(f, yv, v)]] <- data.table(faccao = f, outcome = yv, versao = v, att = att, se = se, p = 2 * pnorm(-abs(att / se)),
                                           pre_p = r$wald_pre_crve$p, vale = vale, se_vale = se_vale,
                                           att_dyn = att_dyn, se_dyn = se_dyn, p_dyn = 2 * pnorm(-abs(att_dyn / se_dyn)),
                                           tratados = sum(r$n$por_coorte[u_g > 0]$N))
      cat(sprintf("%-8s %-18s %s ATT %+.4f (%.4f) p %.3f pré %.3f vale %+.4f trat %d
", f, yv, v, att, se,
                  2 * pnorm(-abs(att / se)), r$wald_pre_crve$p, vale, res[[paste(f, yv, v)]]$tratados))
    }
  }
}
fwrite(rbindlist(res), file.path(OUT, "W08_antecipacao.csv"))

# ---- HonestDiD sem e = -16 (efeito pós médio, magnitudes relativas) ----
hd <- function(x, drop16) {
  ev <- x$event; V <- x$V_event; k <- which(ev$e != -4 & (!drop16 | ev$e != -16))
  e <- ev$e[k]; b <- ev$att[k]; S <- V[k, k, drop = FALSE]; s <- 1 / sqrt(mean(diag(S)))
  npre <- sum(e < 0); npost <- sum(e >= 0); l <- rep(1 / npost, npost); mb <- c(0, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2)
  rm <- as.data.table(createSensitivityResults_relativeMagnitudes(betahat = s * b, sigma = s^2 * S, numPrePeriods = npre,
                        numPostPeriods = npost, Mbarvec = mb, l_vec = l))
  exc <- rm[, lb > 0 | ub < 0]
  data.table(npre = npre, mbar_rm = if (!exc[1]) 0 else { j <- which(!exc); if (length(j)) mb[min(j) - 1] else max(mb) },
             max_pre_dev = max(abs(diff(c(b[e < 0], 0)))))
}
H <- rbindlist(lapply(list(c("trafico", "hhi_pref"), c("trafico", "margin_pref"), c("trafico", "enc_pref"), c("milicia", "saldo_ver")), function(z) {
  x <- readRDS(file.path(OUT, "rds", sprintf("W01_%s_a_%s.rds", z[1], z[2])))
  rbind(cbind(faccao = z[1], outcome = z[2], versao = "todos os pré", hd(x, FALSE)),
        cbind(faccao = z[1], outcome = z[2], versao = "sem e=-16", hd(x, TRUE)))
}))
fwrite(H, file.path(OUT, "W08_honest_sem16.csv")); print(H)
cat("OK W08\n")
