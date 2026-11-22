# util_v2.R — funções comuns da fase 2: HonestDiD com reescala, q-values e montagem do tratamento
# HonestDiD idêntico ao F02 (fase1/F02_robustez.R): efeito pós médio, matriz CRVE, reescala numérica
# (b*s, Sigma*s^2, M*s; IC/s), RM por bisseção na grade 0..2 (passo 0,1), SD/FLCI com M de breakdown por bisseção.
suppressPackageStartupMessages({ library(data.table); library(HonestDiD) })

prep_hd <- function(r) {
  ev <- r$event; V <- r$V_event; ref <- max(ev$e[ev$e < 0]); k <- ev$e != ref
  list(b = ev$att[k], S = V[k, k, drop = FALSE], e = ev$e[k])
}
escala_hd <- function(h) { s <- 1 / sqrt(mean(diag(h$S))); list(b = s * h$b, S = s^2 * h$S, e = h$e, s = s) }
honest_rm <- function(r) {
  h <- escala_hd(prep_hd(r)); npre <- sum(h$e < 0); npost <- sum(h$e >= 0); l <- rep(1 / npost, npost)
  mb <- seq(0, 2, by = 0.1)
  exclui <- function(i) { x <- createSensitivityResults_relativeMagnitudes(betahat = h$b, sigma = h$S, numPrePeriods = npre,
                            numPostPeriods = npost, Mbarvec = mb[i], l_vec = l); x$lb[1] > 0 | x$ub[1] < 0 }
  if (!exclui(1)) return(data.table(mbar_rm = 0))
  if (exclui(length(mb))) return(data.table(mbar_rm = max(mb)))
  lo <- 1; hi <- length(mb)
  while (hi - lo > 1) { mid <- (lo + hi) %/% 2; if (exclui(mid)) lo <- mid else hi <- mid }
  data.table(mbar_rm = mb[lo])
}
honest_sd <- function(r) {
  h <- prep_hd(r); hs <- escala_hd(h); npre <- sum(h$e < 0); npost <- sum(h$e >= 0); l <- rep(1 / npost, npost)
  ci <- function(M) { x <- createSensitivityResults(betahat = hs$b, sigma = hs$S, numPrePeriods = npre, numPostPeriods = npost,
                                                    method = "FLCI", Mvec = hs$s * M, l_vec = l)
                      c(lb = x$lb[1] / hs$s, ub = x$ub[1] / hs$s) }
  exclui <- function(v) v[["lb"]] > 0 | v[["ub"]] < 0
  pre <- c(h$b[h$e < 0], 0); bench <- if (length(pre) >= 3) max(abs(diff(pre, differences = 2))) else NA_real_
  c0 <- ci(0); cb <- if (is.finite(bench)) ci(bench) else c(lb = NA, ub = NA)
  mp <- abs(sum(l * h$b[h$e >= 0]))
  if (!exclui(c0)) brk <- 0 else {
    hi <- max(mp, 2 * bench, na.rm = TRUE)
    if (exclui(ci(hi))) brk <- Inf else { lo <- 0; while ((hi - lo) > 0.05 * hi) { mid <- (lo + hi) / 2; if (exclui(ci(mid))) lo <- mid else hi <- mid }; brk <- lo }
  }
  data.table(sd_ic0_lb = c0[["lb"]], sd_ic0_ub = c0[["ub"]], sd_ref_M = bench, sd_icref_lb = cb[["lb"]], sd_icref_ub = cb[["ub"]],
             sd_M_breakdown = brk, sd_M_razao = brk / bench)
}
HD_VAZIO <- data.table(mbar_rm = NA_real_, sd_ic0_lb = NA_real_, sd_ic0_ub = NA_real_, sd_ref_M = NA_real_,
                       sd_icref_lb = NA_real_, sd_icref_ub = NA_real_, sd_M_breakdown = NA_real_, sd_M_razao = NA_real_)

# q-values "sharpened" (BKY 2006; algoritmo de Anderson 2008), igual ao F01
bky_q <- function(p) {
  m <- length(p); q <- rep(1, m); o <- order(p); ps <- p[o]; k <- seq_len(m)
  for (qq in seq(1, 0.001, by = -0.001)) {
    q1 <- qq / (1 + qq); r1 <- max(c(0, k[ps <= k * q1 / m])); q2 <- q1 * m / (m - r1)
    r2 <- max(c(0, k[ps <= k * q2 / m])); if (r2 > 0) q[o[seq_len(r2)]] <- qq
  }
  q
}

# Aplica uma regra de tratamento ao painel, com a MESMA lógica do pipeline_v2/R/07_paineis.R (monta()):
#   trt: place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag (coorte do calendário do painel,
#        já na escala municipal ou bienal), g_mesmo (para sempre_tratado_mesmo; opcional)
#   painel: "mun" ou "geral"; dist: place_id, dist_env_milicia_m, dist_env_trafico_m
# Devolve o painel com g e as colunas de amostra recalculadas.
aplica_tratamento <- function(PX, trt, painel, dist, anos_gerais = c(2006, 2010, 2014, 2018, 2022)) {
  drop <- intersect(names(PX), c("faccao_entrada", "sempre_tratado", "nunca_tratado", "trat_pos_painel", "g",
                                 grep("^amostra_", names(PX), value = TRUE)))
  w <- copy(PX)[, (drop) := NULL]
  w <- merge(w, trt[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g = g_lag)], by = "place_id")
  if (!all(c("dist_env_milicia_m", "dist_env_trafico_m") %in% names(w))) w <- merge(w, dist, by = "place_id")
  for (f in c("milicia", "trafico")) {
    mun_f <- unique(w[faccao_entrada == f & !sempre_tratado & !is.na(g), mun])
    dcol <- paste0("dist_env_", f, "_m")
    for (d in c(500, 1000, 2000)) {
      nm <- sprintf("amostra_fronteira_%s_%d", f, d)
      w[, (nm) := mun %in% mun_f & !sempre_tratado &
                  ((faccao_entrada %in% f & !is.na(g)) | ((nunca_tratado | (trat_pos_painel & faccao_entrada %in% f)) & get(dcol) <= d))]
    }
    w[, (sprintf("amostra_nyt_%s", f)) := faccao_entrada %in% f & !sempre_tratado & (!is.na(g) | trat_pos_painel)]
    w[, (sprintf("amostra_todos_%s", f)) := mun %in% mun_f & !sempre_tratado &
                                            ((faccao_entrada %in% f & !is.na(g)) | nunca_tratado | (trat_pos_painel & faccao_entrada %in% f))]
  }
  w[is.na(g) | trat_pos_painel, g := 0L]
  if (painel == "geral") {
    prox <- function(v) vapply(v, function(x) { e <- anos_gerais[anos_gerais >= x]; if (length(e)) as.integer(min(e)) else 0L }, integer(1))
    w[g > 0, g := prox(g)]
  }
  for (cc in grep("^amostra_", names(w), value = TRUE)) set(w, j = cc, value = w[[cc]] %in% TRUE)
  w
}

# Estimador comum da fase 2 (validado contra o F01 até 1e-10): mesmas opções do motor, painel balanceado
# ou desbalanceado (cortes repetidos), SE CRVE na grade de 2 km a partir dos locais que o did de fato usa.
# d precisa de: place_id, ano, g_ponte (coorte), o outcome, aptos, peso, balanceado, mun, grade_2km.
suppressPackageStartupMessages(library(did))
.id <- function(x) { lv <- sort(unique(as.character(x)), method = "radix"); match(as.character(x), lv) }
# estimação: mesmas opções do motor (pipeline_v2/R/cs_engine.R), com painel balanceado OU desbalanceado
estima <- function(d, yv, xf, painel, rot) {          # yv: nome do outcome (o painel tem colunas x e y de coordenada)
  rc <- painel == "rc"; wcol <- if (rc) "aptos" else "peso"
  d <- d[!is.na(d[[yv]]) & !is.na(d[[wcol]]) & d[[wcol]] > 0]
  if (!rc) d <- d[balanceado == TRUE]
  d <- data.table(u_chr = d$place_id, ano = d$ano, g = d$g_ponte, u_y = d[[yv]], u_w = d[[wcol]], mun = as.character(d$mun), cl = d$grade_2km)
  # covariáveis do Censo pedidas pela fórmula: mesma fonte do motor; unidades sem valor saem
  cv_ped <- intersect(all.vars(xf), c("lrenda", "ldens"))
  if (length(cv_ped)) { cv <- cs_covariaveis(); for (v in cv_ped) set(d, j = v, value = cv[[v]][match(d$u_chr, cv$place_id)])
    d <- d[stats::complete.cases(d[, cv_ped, with = FALSE])] }
  t1 <- min(d$ano); stopifnot(d[g > 0 & g <= t1, .N] == 0)                       # G1
  log4 <- ""
  if ("mun" %in% all.vars(xf)) {                                                  # G4
    comp <- unique(d[, .(mun, u_chr, g)])[, .(tt = any(g > 0), tc = any(g == 0) | uniqueN(g[g > 0]) > 1), by = mun]
    fora <- comp[!(tt & tc), mun]; if (length(fora)) { log4 <- paste(fora, collapse = ","); d <- d[!mun %in% fora] }
  }
  d[, u_id := .id(u_chr)][, u_cl := .id(cl)]; setorder(d, u_id, ano)
  av <- character(0)
  att <- tryCatch(withCallingHandlers(
    att_gt(yname = "u_y", tname = "ano", idname = "u_id", gname = "g", data = as.data.frame(d), xformla = xf,
           est_method = "reg", control_group = "notyettreated", base_period = "universal", weightsname = "u_w",
           allow_unbalanced_panel = rc, bstrap = FALSE, cband = FALSE, faster_mode = FALSE, print_details = FALSE),
    warning = function(w) { av <<- c(av, conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = function(e) { av <<- c(av, paste("ERRO:", conditionMessage(e))); NULL })
  ruins <- grep("No avail|singular|overlap|Not enough control|ERRO", av, value = TRUE, ignore.case = TRUE)
  if (is.null(att) || length(ruins)) return(data.table(identificado = FALSE, motivo = substr(paste(unique(ruins), collapse = " | "), 1, 200)))
  cel <- data.table(g = att$group, t = att$t, att = att$att, se = att$se)
  tl <- sort(unique(d$ano)); cel[, ref := vapply(g, function(gg) max(tl[tl < gg]), numeric(1)) == t]
  if (cel[!ref & att == 0 & (is.na(se) | se == 0), .N]) return(data.table(identificado = FALSE, motivo = "G3: célula zerada"))
  ad <- tryCatch(aggte(att, type = "dynamic", na.rm = FALSE), error = function(e) NULL)
  ag <- tryCatch(aggte(att, type = "group", na.rm = FALSE), error = function(e) NULL)
  if (is.null(ad) || is.null(ag)) return(data.table(identificado = FALSE, motivo = "aggte: célula NA"))
  # linhas da função de influência = locais que o did de fato usou, em ordem de u_id (sem nunca tratados, o did
  # descarta o último período e os locais vistos só nele). Ordem verificada por perturbação de um local (6 de 6).
  ids_usados <- sort(unique(as.data.table(att$DIDparams$data)$u_id))
  cl_u <- d[match(ids_usados, d$u_id), u_cl]
  crve <- function(psi) { psi <- as.matrix(psi); stopifnot(nrow(psi) == length(cl_u)); crossprod(rowsum(psi, cl_u)) / nrow(psi)^2 }
  Ve <- crve(ad$inf.function$dynamic.inf.func.e); e <- ad$egt; pre <- which(e < 0 & e != max(e[e < 0]))
  wp <- if (length(pre)) { b <- ad$att.egt[pre]; 1 - pchisq(as.numeric(t(b) %*% solve(Ve[pre, pre, drop = FALSE]) %*% b), length(pre)) } else NA_real_
  coh <- unique(d[, .(u_id, g)])[g > 0, .N, by = g][order(g)]
  data.table(identificado = TRUE, motivo = log4,
             att_dyn = ad$overall.att, se_dyn = sqrt(crve(ad$inf.function$dynamic.inf.func)[1, 1]),
             att_grp = ag$overall.att, se_grp = sqrt(crve(ag$inf.function$selective.inf.func)[1, 1]),
             wald_pre_p = wp, e_m8 = if (any(e == -8)) ad$att.egt[e == -8] else NA_real_,
             e_0 = ad$att.egt[e == 0], unidades = uniqueN(d$u_id), tratados = sum(coh$N), clusters = uniqueN(d$u_cl),
             coortes = paste(sprintf("%d:%d", coh$g, coh$N), collapse = " "))
}

