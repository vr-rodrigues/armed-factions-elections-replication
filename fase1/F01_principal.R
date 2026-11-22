# F01_principal.R — Fase 1: especificação principal, famílias de desfechos F1–F3
# Estimador: Callaway & Sant'Anna (did), via pipeline_v2/R/cs_engine.R (guardas G1–G5).
# Especificação principal:
#   amostra (a) fronteira 1 km da facção; versão principal; painel balanceado de locais físicos;
#   coorte com mapa Y-1; ITT da 1ª entrada; xformla = ~ mun + lrenda (município e log da renda do entorno no Censo 2010), est_method = "reg";
#   controles: ainda não tratados + nunca tratados; base universal; pesos = aptos da 1ª eleição;
#   cluster = grade de 2 km; agregação principal = "group".
#   Estimando principal: contraste prefeito - vereador (F1 padronizado pelo DP do 1º período dos controles da
#   amostra principal; F2 e brancos/nulos em diferença direta); comparecimento sozinho (não há contraste).
# Critérios de robustez: (i) p < 0,05 e q < 0,10 na família; (ii) pré-tendência conjunta não
#   rejeita a 10%; (iii) M-barra de breakdown do HonestDiD >= 1 (efeito pós médio); (iv) sinal igual em (a), (b), (c).
# Inferência: erro-padrão clusterizado CRVE (soma das funções
#   de influência no cluster de 2 km). O bootstrap clusterizado do did usa a média no cluster e, com clusters de
#   tamanhos desiguais, não é consistente (verificado por simulação de Monte Carlo). O SE
#   do bootstrap do did é reportado ao lado em todas as tabelas.
# Entrada: $AFE_DADOS/pipeline_v2/painel_municipal.parquet (saída validada do pipeline v2)
# Saída:   fase1/resultados/F01_*.csv e F01_resumo.md

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(HonestDiD) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
F1DIR <- dirname(normalizePath(.f))
source(file.path(F1DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2")
OUT <- file.path(F1DIR, "resultados"); dir.create(OUT, showWarnings = FALSE)
BITERS <- 999

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))
PM <- PM[versao == "principal"]
cat(sprintf("painel: %d linhas; hash snapshot registrado\n", nrow(PM)))

OUT_F1 <- c("margin", "hhi")
OUT_F2 <- c("dissim", "exc_hhi", "exc_vencedor")
FAM <- data.table(outcome = c("margin_contraste", "hhi_contraste", "dissim_contraste", "exc_hhi_contraste",
                              "exc_vencedor_contraste", "comparecimento_taxa", "brancos_nulos_contraste"),
                  familia = c("F1", "F1", "F2", "F2", "F2", "F3", "F3"),
                  papel = c("primario", "primario", "primario", "primario", "secundario", "secundario", "secundario"))

# q-values "sharpened" (Benjamini, Krieger & Yekutieli 2006; algoritmo de Anderson 2008)
bky_q <- function(p) {
  m <- length(p); q <- rep(1, m); o <- order(p); ps <- p[o]; k <- seq_len(m)
  for (qq in seq(1, 0.001, by = -0.001)) {
    q1 <- qq / (1 + qq)
    r1 <- max(c(0, k[ps <= k * q1 / m]))
    q2 <- q1 * m / (m - r1)
    r2 <- max(c(0, k[ps <= k * q2 / m]))
    if (r2 > 0) q[o[seq_len(r2)]] <- qq
  }
  q
}

# HonestDiD (magnitudes relativas) sobre o efeito pós médio, com todos os pré-períodos
honest <- function(r) {
  ev <- r$event; V <- r$V_event
  ref <- max(ev$e[ev$e < 0])
  keep <- ev$e != ref
  b <- ev$att[keep]; S <- V[keep, keep, drop = FALSE]; e <- ev$e[keep]
  npre <- sum(e < 0); npost <- sum(e >= 0)
  l <- rep(1 / npost, npost)
  orig <- constructOriginalCS(betahat = b, sigma = S, numPrePeriods = npre, numPostPeriods = npost, l_vec = l)
  mb <- seq(0, 2, by = 0.1)
  rm <- createSensitivityResults_relativeMagnitudes(betahat = b, sigma = S, numPrePeriods = npre,
                                                    numPostPeriods = npost, Mbarvec = mb, l_vec = l)
  rm <- as.data.table(rm)
  exclui0 <- rm[, lb > 0 | ub < 0]
  brk <- if (!exclui0[1]) 0 else { j <- which(!exclui0); if (length(j)) rm$Mbar[min(j)] - 0.1 else max(mb) }
  data.table(media_pos = sum(l * b[e >= 0]), ic_orig_lb = orig$lb, ic_orig_ub = orig$ub,
             mbar_breakdown = brk, npre = npre, npost = npost)
}

roda <- function(d, y, rot) {
  r <- cs_estimar(d, y, biters = BITERS, rotulo = rot)
  g <- r$overall[tipo == "group"]; dy <- r$overall[tipo == "dynamic"]; e0 <- r$event[e == 0]
  se_ev_crve <- sqrt(diag(r$V_event)); se_an <- se_ev_crve[as.character(r$event$e) == "0"]
  list(r = r, linha = data.table(
    rotulo = rot, outcome = y, att_group = g$att, se_group = r$se_group_crve, p_group = 2 * pnorm(-abs(g$att / r$se_group_crve)),
    se_group_boot_did = g$se, p_group_boot_did = 2 * pnorm(-abs(g$att / g$se)),
    att_dynamic = dy$att, se_dynamic_boot_did = dy$se, att_e0 = e0$att, se_e0 = se_an, se_e0_boot_did = e0$se,
    wald_pre_stat = r$wald_pre_crve$stat, wald_pre_df = r$wald_pre_crve$df, wald_pre_p = r$wald_pre_crve$p,
    wald_pre_p_did = r$wald_pre_did$p,
    unidades = r$n$unidades, clusters = r$n$clusters, municipios = r$n$municipios,
    tratados = sum(r$n$por_coorte[u_g > 0]$N), log = if (is.null(r$log)) "" else r$log))
}

res <- list(); evs <- list(); hon <- list(); escalas <- list()
for (f in c("milicia", "trafico")) {
  am_a <- sprintf("amostra_fronteira_%s_1000", f); am_b <- sprintf("amostra_nyt_%s", f); am_c <- sprintf("amostra_todos_%s", f)
  base_a <- PM[get(am_a) == TRUE & balanceado == TRUE]
  # escala do contraste F1: DP no 1º período entre os controles da amostra principal
  for (v in OUT_F1) {
    a0 <- base_a[ano == min(ano) & g == 0]
    escalas[[paste(f, v)]] <- data.table(faccao = f, var = v, sd_pref = sd(a0[[paste0(v, "_pref")]], na.rm = TRUE),
                                         sd_ver = sd(a0[[paste0(v, "_ver")]], na.rm = TRUE))
  }
  prep <- function(dd) {
    for (v in OUT_F1) { es <- escalas[[paste(f, v)]]; dd <- cria_contraste(dd, v, TRUE, escala = c(sd_pref = es$sd_pref, sd_ver = es$sd_ver)) }
    for (v in c(OUT_F2, "brancos_nulos")) dd <- cria_contraste(dd, v, FALSE)
    dd
  }
  amostras <- list(a = prep(base_a), b = prep(PM[get(am_b) == TRUE & balanceado == TRUE]),
                   c = prep(PM[get(am_c) == TRUE & balanceado == TRUE]))
  for (s in names(amostras)) {
    ys <- if (s == "a") c(FAM$outcome, paste0(c(OUT_F1, OUT_F2, "brancos_nulos"), "_pref"), paste0(c(OUT_F1, OUT_F2, "brancos_nulos"), "_ver"))
          else FAM$outcome
    for (y in ys) {
      rot <- sprintf("%s|%s|%s", f, s, y)
      out <- tryCatch(roda(amostras[[s]], y, rot), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); NULL })
      if (is.null(out)) next
      res[[rot]] <- cbind(faccao = f, amostra = s, out$linha)
      evs[[rot]] <- cbind(faccao = f, amostra = s, outcome = y, out$r$event[, .(e, att, se_boot_did = se)],
                          se = sqrt(diag(out$r$V_event)))
      if (s == "a" && y %in% FAM$outcome) hon[[rot]] <- cbind(faccao = f, outcome = y, honest(out$r))
      cat(sprintf("  %-45s ATT(group)=%+.4f (se %.4f) | pré p=%.3f\n", rot, out$linha$att_group, out$linha$se_group, out$linha$wald_pre_p))
    }
  }
}
R <- rbindlist(res); E <- rbindlist(evs); H <- rbindlist(hon); ESC <- rbindlist(escalas)

# q-values por família, na especificação principal (amostra a, contrastes)
P <- merge(R[amostra == "a" & outcome %in% FAM$outcome], FAM, by = "outcome")
P[, q_familia := bky_q(p_group), by = .(faccao, familia)]
# critério (iv): sinal igual em a, b, c
# (iv) com as amostras estimáveis; amostra não identificada (ex.: NYT puro sem controles no município) fica registrada
sinais <- R[outcome %in% FAM$outcome, .(sinal_igual_abc = uniqueN(sign(att_group)) == 1,
                                         amostras_estimadas = paste(sort(amostra), collapse = "")), by = .(faccao, outcome)]
P <- merge(P, sinais, by = c("faccao", "outcome"))
P <- merge(P, H, by = c("faccao", "outcome"))
P[, `:=`(c_i = p_group < 0.05 & q_familia < 0.10, c_ii = wald_pre_p >= 0.10, c_iii = mbar_breakdown >= 1, c_iv = sinal_igual_abc)]
P[, robusto := c_i & c_ii & c_iii & c_iv]

fwrite(R, file.path(OUT, "F01_todas_estimativas.csv"))
fwrite(E, file.path(OUT, "F01_event_study.csv"))
fwrite(P, file.path(OUT, "F01_principal_criterios.csv"))
fwrite(ESC, file.path(OUT, "F01_escalas_contraste.csv"))
writeLines(c(sprintf("did %s, DRDID %s, HonestDiD %s, seed %d, biters %d, snapshot %s", CS_VERSOES$did, CS_VERSOES$DRDID,
                     as.character(packageVersion("HonestDiD")), 20261009, BITERS, SNAP)), file.path(OUT, "F01_versoes.txt"))

options(width = 250)
cat("\n=== ESPECIFICAÇÃO PRINCIPAL: contraste prefeito - vereador, fronteira 1 km ===\n")
print(P[order(faccao, familia, outcome), .(faccao, familia, outcome, att = round(att_group, 4), se_crve = round(se_group, 4), se_boot = round(se_group_boot_did, 4),
         p = round(p_group, 3), q = round(q_familia, 3), pre_p = round(wald_pre_p, 3), pre_p_did = round(wald_pre_p_did, 3), mbar = mbar_breakdown,
         sinal_abc = sinal_igual_abc, amostras = amostras_estimadas, robusto, tratados, clusters)])
cat("\n=== Por cargo (amostra a) ===\n")
print(R[amostra == "a" & grepl("_pref$|_ver$", outcome), .(faccao, outcome, att = round(att_group, 4), se = round(se_group, 4),
         p = round(p_group, 3), pre_p = round(wald_pre_p, 3))][order(faccao, outcome)])
cat("\nOK F01\n")
