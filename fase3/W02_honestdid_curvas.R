# W02_honestdid_curvas.R — curvas de sensibilidade HonestDiD (Rambachan e Roth 2023)
# Lê os event studies e as covariâncias CRVE salvos pelo W01 e calcula, com a reescala numérica do util_v2.R:
#   versão "plano": alvo = efeito pós médio (e >= 0), todos os pré-períodos (pré-especificada; é a do F01/V01)
#   versão "paper": alvo = efeito na eleição de entrada (e = 0), janela curta:
#                   um pré-período (e = -8), referência e = -4, dois pós (e = 0 e e = +4)
#   RM: magnitudes relativas, Mbar em 0..2 (passo 0,1); SD: suavidade (FLCI), M em múltiplos da maior segunda diferença pré
# Uso: Rscript W02_honestdid_curvas.R <i>   (alvo i da lista; um processo por alvo) e depois  Rscript W02_honestdid_curvas.R junta
# Saída: resultados/W02_honestdid_curvas.csv e resultados/W02_honestdid_breakdown.csv
# Breakdown reportado = maior valor da grade em que o IC robusto ainda exclui zero (0 se nem o IC com M = 0 exclui).

suppressPackageStartupMessages({ library(data.table); library(HonestDiD) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
RDS <- file.path(F3DIR, "resultados", "rds"); OUT <- file.path(F3DIR, "resultados")
ALVOS <- data.table(faccao = c(rep("trafico", 6), rep("milicia", 3)),
                    outcome = c("hhi_pref", "enc_pref", "margin_pref", "comparecimento_taxa", "hhi_ver", "margin_ver",
                                "saldo_ver", "s_dir_ver", "s_esq_ver"))

prep <- function(x, versao) {
  ev <- x$event; V <- x$V_event; ref <- max(ev$e[ev$e < 0])
  k <- if (versao == "plano") which(ev$e != ref) else which(ev$e %in% c(-8, 0, 4))
  e <- ev$e[k]; b <- ev$att[k]; S <- V[k, k, drop = FALSE]
  s <- 1 / sqrt(mean(diag(S)))
  npre <- sum(e < 0); npost <- sum(e >= 0)
  l <- if (versao == "plano") rep(1 / npost, npost) else c(1, rep(0, npost - 1))
  list(b = s * b, S = s^2 * S, s = s, npre = npre, npost = npost, l = l, e = e, braw = b)
}
a <- commandArgs(TRUE)
if (length(a) && a[1] != "junta") ALVOS <- ALVOS[as.integer(a[1])]
if (length(a) && a[1] == "junta") {          # junta as partes gravadas por cada processo
  C <- rbindlist(lapply(list.files(OUT, "^W02_parte_curvas_.*[.]csv$", full.names = TRUE), fread))
  B <- rbindlist(lapply(list.files(OUT, "^W02_parte_breakdown_.*[.]csv$", full.names = TRUE), fread))
  fwrite(C, file.path(OUT, "W02_honestdid_curvas.csv")); fwrite(B, file.path(OUT, "W02_honestdid_breakdown.csv"))
  options(width = 200); print(B[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 4) else z)]); cat("OK W02 junta
"); quit(save = "no")
}
res <- list(); brk <- list()
for (i in seq_len(nrow(ALVOS))) {
  f <- ALVOS$faccao[i]; y <- ALVOS$outcome[i]
  x <- readRDS(file.path(RDS, sprintf("W01_%s_a_%s.rds", f, y)))
  for (versao in c("plano", "paper")) {
    h <- prep(x, versao)
    alvo <- sum(h$l * h$braw[h$e >= 0])
    orig <- constructOriginalCS(betahat = h$b, sigma = h$S, numPrePeriods = h$npre, numPostPeriods = h$npost, l_vec = h$l); orig <- list(lb = as.numeric(orig$lb), ub = as.numeric(orig$ub))
    mb <- c(0, 0.1, 0.2, 0.3, 0.5, 0.75, 1, 1.5, 2)
    rm <- as.data.table(createSensitivityResults_relativeMagnitudes(betahat = h$b, sigma = h$S, numPrePeriods = h$npre,
                          numPostPeriods = h$npost, Mbarvec = mb, l_vec = h$l))
    rm[, `:=`(lb = lb / h$s, ub = ub / h$s)]
    exc <- rm[, lb > 0 | ub < 0]
    b_rm <- if (!exc[1]) 0 else { j <- which(!exc); if (length(j)) rm$Mbar[min(j) - 1] else max(mb) }   # maior Mbar da grade que ainda exclui zero
    # SD: grade em múltiplos da maior segunda diferença dos pré-períodos (com a referência normalizada em zero)
    pre <- c(h$braw[h$e < 0], 0)
    bench <- if (length(pre) >= 3) max(abs(diff(pre, differences = 2))) else abs(pre[1])
    mult <- seq(0, 2, by = 0.25)
    sd <- as.data.table(createSensitivityResults(betahat = h$b, sigma = h$S, numPrePeriods = h$npre, numPostPeriods = h$npost,
                          method = "FLCI", Mvec = h$s * bench * mult, l_vec = h$l))
    sd[, `:=`(lb = lb / h$s, ub = ub / h$s, mult = mult, M = bench * mult)]
    exs <- sd[, lb > 0 | ub < 0]
    b_sd <- if (!exs[1]) 0 else { j <- which(!exs); if (length(j)) sd$mult[min(j) - 1] else max(mult) }
    res[[length(res) + 1]] <- rbind(
      data.table(faccao = f, outcome = y, versao = versao, metodo = "original", M = NA_real_, lb = orig$lb / h$s, ub = orig$ub / h$s),
      rm[, .(faccao = f, outcome = y, versao = versao, metodo = "RM", M = Mbar, lb, ub)],
      sd[, .(faccao = f, outcome = y, versao = versao, metodo = "SD", M = mult, lb, ub)])
    brk[[length(brk) + 1]] <- data.table(faccao = f, outcome = y, versao = versao, alvo = alvo, ic_lb = orig$lb / h$s,
                                         ic_ub = orig$ub / h$s, npre = h$npre, mbar_rm = b_rm, sd_bench = bench, sd_mult_breakdown = b_sd)
  }
  cat("ok", f, y, "\n")
}
C <- rbindlist(res); B <- rbindlist(brk)
tag <- if (length(a)) a[1] else "todas"
fwrite(C, file.path(OUT, sprintf("W02_parte_curvas_%s.csv", tag))); fwrite(B, file.path(OUT, sprintf("W02_parte_breakdown_%s.csv", tag)))
options(width = 200); print(B[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 4) else z)])
cat("OK W02\n")
