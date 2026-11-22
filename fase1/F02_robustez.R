# F02_robustez.R — Fase 1: robustezes sobre a especificação principal do F01
#   1. HonestDiD por suavidade (Delta^SD, FLCI) ao lado das magnitudes relativas (Delta^RM), no efeito pós médio
#   2. Fronteira de 500 m e de 2 km (no lugar de 1 km)
#   3. Exclusão de locais com coordenada duvidosa: coord_possivelmente_herdada, geocodigo_impreciso,
#      fusao_suspeita (cada uma e as três juntas), a partir da amostra principal (a)
#   4. Rio × fora do Rio, a partir de (a). O Rio é um município só: xformla = ~ 1 (tendência comum do município)
#   5. Painel das eleições gerais (2006–2022): contraste governador − dep. estadual, por cargo
#      (governador, dep. estadual; senador e dep. federal como complemento), amostras (a), (b), (c)
# Tudo o mais igual ao F01: CS-DID via pipeline_v2/R/cs_engine.R (guardas G1–G5), painel balanceado, ~ mun + lrenda, reg,
#   NYT + nunca tratados, base universal, mapa Y−1, pesos fixos, aggte "group", CRVE no grid de 2 km
#   (SE do bootstrap do did ao lado), seed 20261009, biters 999.
# Escala do contraste F1: a mesma da amostra principal em todas as robustezes do painel municipal
#   (F01_escalas_contraste.csv); no painel geral, DP de 2006 entre os controles da amostra (a) do painel geral.
# Uso:   Rscript F02_robustez.R <bloco> [k/n], bloco em {mun_milicia, mun_trafico, geral_milicia, geral_trafico};
#        k/n (opcional) divide os outcomes da amostra (a) em n partes (paralelismo); as demais amostras rodam na parte 1
# Saída: resultados/F02_<bloco>[_p<k>de<n>]_estimativas.csv e _event.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow); library(HonestDiD) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
F1DIR <- dirname(normalizePath(.f))
source(file.path(F1DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2")
OUT <- file.path(F1DIR, "resultados")
BITERS <- 999
RIO <- "60011"
# teste rápido (F02_SMOKE=1): bootstrap curto, sem HonestDiD, saída no diretório temporário
SMOKE <- nzchar(Sys.getenv("F02_SMOKE"))
if (SMOKE) { BITERS <- 49; OUT <- Sys.getenv("F02_SMOKE") }

bloco <- commandArgs(TRUE)[1]
parte <- if (length(commandArgs(TRUE)) >= 2) as.integer(strsplit(commandArgs(TRUE)[2], "/")[[1]]) else c(1L, 1L)
SUF <- if (parte[2] > 1) sprintf("_p%dde%d", parte[1], parte[2]) else ""
stopifnot(bloco %in% c("mun_milicia", "mun_trafico", "geral_milicia", "geral_trafico"))
painel <- sub("_.*", "", bloco); f <- sub(".*_", "", bloco)
cat(sprintf("F02 bloco %s (painel %s, facção %s)\n", bloco, painel, f))

places <- as.data.table(read_parquet(file.path(SNAP, "places.parquet")))[, .(place_id, coord_possivelmente_herdada)]
arq <- if (painel == "mun") "painel_municipal.parquet" else "painel_geral.parquet"
PX <- as.data.table(read_parquet(file.path(SNAP, arq)))[versao == "principal"]
PX <- merge(PX, places, by = "place_id", all.x = TRUE)
stopifnot(!anyNA(PX$coord_possivelmente_herdada), !anyNA(PX$geocodigo_impreciso), !anyNA(PX$fusao_suspeita))

# ---------------- HonestDiD ----------------
prep_hd <- function(r) {
  ev <- r$event; V <- r$V_event; ref <- max(ev$e[ev$e < 0]); k <- ev$e != ref
  list(b = ev$att[k], S = V[k, k, drop = FALSE], e = ev$e[k])
}
# Reescala numérica para o HonestDiD: com variâncias muito pequenas (~1e-6, ex.: brancos e nulos) o otimizador do
# FLCI falha ("Error in optimization for h0" -> NaN). Os ICs de Delta^SD (FLCI) e Delta^RM são equivariantes à
# escala: com b* = s b, S* = s^2 S e M* = s M, IC* = s IC. Usa-se s = 1/sqrt(média da diagonal de S) e desfaz-se
# a escala no fim. Verificado: reproduz os ICs sem reescala até 1e-6 (tráfico, HHI prefeito; M = 0, 0,0036, 0,0089;
# M-barra = 0, 0,1, 0,2).
escala_hd <- function(h) { s <- 1 / sqrt(mean(diag(h$S))); list(b = s * h$b, S = s^2 * h$S, e = h$e, s = s) }
# magnitudes relativas: mesma definição do F01 (grade 0, 0,1, ..., 2; breakdown = último M̄ da grade antes do
# primeiro que inclui zero). Para poupar tempo (~5 s por M̄), a busca na grade é por bisseção (o IC cresce com M̄).
honest_rm <- function(r) {
  h <- escala_hd(prep_hd(r)); npre <- sum(h$e < 0); npost <- sum(h$e >= 0); l <- rep(1 / npost, npost)
  mb <- seq(0, 2, by = 0.1)
  exclui <- function(i) { x <- createSensitivityResults_relativeMagnitudes(betahat = h$b, sigma = h$S, numPrePeriods = npre,
                            numPostPeriods = npost, Mbarvec = mb[i], l_vec = l); x$lb[1] > 0 | x$ub[1] < 0 }
  if (!exclui(1)) return(data.table(mbar_rm = 0))
  if (exclui(length(mb))) return(data.table(mbar_rm = max(mb)))
  lo <- 1; hi <- length(mb)                       # exclui em lo, inclui em hi
  while (hi - lo > 1) { mid <- (lo + hi) %/% 2; if (exclui(mid)) lo <- mid else hi <- mid }
  data.table(mbar_rm = mb[lo])
}
# suavidade (Delta^SD, FLCI). M em unidades do outcome: limite para a variação da inclinação da tendência
# diferencial entre períodos consecutivos (4 anos). Referência empírica: maior |2ª diferença| dos coeficientes
# pré (incluindo a referência, = 0). Sem limiar pré-fixado para Delta^SD: reporta-se o IC com M = 0
# (extrapolação linear da pré-tendência), o IC com M = referência e o M de breakdown (bisseção, tolerância 1%).
honest_sd <- function(r) {
  h0 <- prep_hd(r); hs <- escala_hd(h0); h <- h0
  npre <- sum(h$e < 0); npost <- sum(h$e >= 0); l <- rep(1 / npost, npost)
  ci <- function(M) {                             # M e IC em unidades do outcome; cálculo na escala normalizada
    x <- createSensitivityResults(betahat = hs$b, sigma = hs$S, numPrePeriods = npre, numPostPeriods = npost,
                                  method = "FLCI", Mvec = hs$s * M, l_vec = l)
    c(lb = x$lb[1] / hs$s, ub = x$ub[1] / hs$s)
  }
  exclui <- function(v) v[["lb"]] > 0 | v[["ub"]] < 0
  pre <- c(h$b[h$e < 0], 0)
  bench <- if (length(pre) >= 3) max(abs(diff(pre, differences = 2))) else NA_real_
  c0 <- ci(0); cb <- if (is.finite(bench)) ci(bench) else c(lb = NA, ub = NA)
  mp <- abs(sum(l * h$b[h$e >= 0]))
  if (!exclui(c0)) brk <- 0 else {
    hi <- max(mp, 2 * bench, na.rm = TRUE)
    if (exclui(ci(hi))) brk <- Inf else {
      lo <- 0                                     # bisseção até 5% de precisão relativa (~7 s por avaliação)
      while ((hi - lo) > 0.05 * hi) { mid <- (lo + hi) / 2; if (exclui(ci(mid))) lo <- mid else hi <- mid }
      brk <- lo
    }
  }
  data.table(sd_ic0_lb = c0[["lb"]], sd_ic0_ub = c0[["ub"]], sd_ref_M = bench,
             sd_icref_lb = cb[["lb"]], sd_icref_ub = cb[["ub"]], sd_M_breakdown = brk, sd_M_razao = brk / bench)
}

# ---------------- estimação ----------------
roda <- function(d, y, rot, xformla, hd) {
  r <- cs_estimar(d, y, xformla = xformla, biters = BITERS, rotulo = rot)
  g <- r$overall[tipo == "group"]
  h <- prep_hd(r); npost <- sum(h$e >= 0); l <- rep(1 / npost, npost); kp <- h$e >= 0
  linha <- data.table(outcome = y, att_group = g$att, se_group = r$se_group_crve,
                      p_group = 2 * pnorm(-abs(g$att / r$se_group_crve)), se_group_boot_did = g$se,
                      media_pos = sum(l * h$b[kp]), se_media_pos = sqrt(as.numeric(t(l) %*% h$S[kp, kp] %*% l)),
                      wald_pre_df = r$wald_pre_crve$df, wald_pre_p = r$wald_pre_crve$p, wald_pre_p_did = r$wald_pre_did$p,
                      unidades = r$n$unidades, tratados = sum(r$n$por_coorte[u_g > 0]$N), clusters = r$n$clusters,
                      municipios = if (r$n$municipios > 0) r$n$municipios else uniqueN(d$mun),   # ~ 1 (Rio): 1
                      coortes = paste(r$n$por_coorte[u_g > 0, sprintf("%d:%d", u_g, N)], collapse = " "),
                      log = if (is.null(r$log)) "" else r$log)
  # HonestDiD só na amostra principal (a) de cada painel (onde vale o critério iii); nas demais, NA
  hon <- if (hd) cbind(honest_rm(r), honest_sd(r)) else
    data.table(mbar_rm = NA_real_, sd_ic0_lb = NA_real_, sd_ic0_ub = NA_real_, sd_ref_M = NA_real_,
               sd_icref_lb = NA_real_, sd_icref_ub = NA_real_, sd_M_breakdown = NA_real_, sd_M_razao = NA_real_)
  list(r = r, linha = cbind(linha, hon))
}

if (painel == "mun") {
  cargos <- c("pref", "ver")
  ESC <- fread(file.path(F1DIR, "resultados", "F01_escalas_contraste.csv"))[faccao == f]
  base_a <- PX[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
  amostras <- list(
    a          = list(d = base_a, x = ~ mun + lrenda),
    fr500      = list(d = PX[get(sprintf("amostra_fronteira_%s_500", f)) == TRUE & balanceado == TRUE], x = ~ mun + lrenda),
    fr2000     = list(d = PX[get(sprintf("amostra_fronteira_%s_2000", f)) == TRUE & balanceado == TRUE], x = ~ mun + lrenda),
    sem_herdada   = list(d = base_a[coord_possivelmente_herdada == FALSE], x = ~ mun + lrenda),
    sem_impreciso = list(d = base_a[geocodigo_impreciso == FALSE], x = ~ mun + lrenda),
    sem_fusao     = list(d = base_a[fusao_suspeita == FALSE], x = ~ mun + lrenda),
    sem_flags     = list(d = base_a[!(coord_possivelmente_herdada | geocodigo_impreciso | fusao_suspeita)], x = ~ mun + lrenda),
    rio        = list(d = base_a[mun == RIO], x = ~ lrenda),
    fora_rio   = list(d = base_a[mun != RIO], x = ~ mun + lrenda))
} else {
  cargos <- c("gov", "depest")
  base_a <- PX[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
  a0 <- base_a[ano == min(ano) & g == 0]
  ESC <- rbindlist(lapply(c("margin", "hhi"), function(v) data.table(faccao = f, var = v,
           sd_pref = sd(a0[[paste0(v, "_gov")]], na.rm = TRUE), sd_ver = sd(a0[[paste0(v, "_depest")]], na.rm = TRUE))))
  fwrite(ESC, file.path(OUT, sprintf("F02_%s_escalas_contraste.csv", bloco)))
  amostras <- list(
    a = list(d = base_a, x = ~ mun + lrenda),
    b = list(d = PX[get(sprintf("amostra_nyt_%s", f)) == TRUE & balanceado == TRUE], x = ~ mun + lrenda),
    c = list(d = PX[get(sprintf("amostra_todos_%s", f)) == TRUE & balanceado == TRUE], x = ~ mun + lrenda))
}

# contrastes: cargo 1 − cargo 2 (prefeito − vereador; governador − dep. estadual). Usa cria_contraste do motor:
# as colunas do cargo 1/2 são copiadas para <var>_pref/<var>_ver numa cópia da base (só nomes internos).
prep <- function(dd) {
  dd <- copy(dd)
  if (painel == "geral") for (v in c("margin", "hhi", "dissim", "exc_hhi", "exc_vencedor", "brancos_nulos")) {
    set(dd, j = paste0(v, "_pref"), value = dd[[paste0(v, "_gov")]]); set(dd, j = paste0(v, "_ver"), value = dd[[paste0(v, "_depest")]])
  }
  for (v in c("margin", "hhi")) { es <- ESC[var == v]; dd <- cria_contraste(dd, v, TRUE, escala = c(sd_pref = es$sd_pref, sd_ver = es$sd_ver)) }
  for (v in c("dissim", "exc_hhi", "exc_vencedor", "brancos_nulos")) dd <- cria_contraste(dd, v, FALSE)
  dd
}
CONTR <- c("margin_contraste", "hhi_contraste", "dissim_contraste", "exc_hhi_contraste", "exc_vencedor_contraste",
           "comparecimento_taxa", "brancos_nulos_contraste")
POR_CARGO <- as.vector(outer(c("margin", "hhi", "dissim", "exc_hhi", "exc_vencedor", "brancos_nulos"), cargos, paste, sep = "_"))
COMPL <- if (painel == "geral") c("margin_sen", "hhi_sen", "margin_depfed", "hhi_depfed") else character(0)

res <- list(); evs <- list()
for (s in names(amostras)) {
  if (s != "a" && parte[1] != 1) next             # amostras de robustez: só na parte 1
  d <- prep(amostras[[s]]$d)
  ys <- if (painel == "geral" && s != "a") CONTR else c(CONTR, POR_CARGO, COMPL)
  if (s == "a") ys <- ys[(seq_along(ys) - 1) %% parte[2] == parte[1] - 1]   # (a): outcomes divididos entre as partes
  for (y in ys) {
    rot <- sprintf("%s|%s|%s", bloco, s, y)
    out <- tryCatch(roda(d, y, rot, amostras[[s]]$x, hd = (s == "a" && !SMOKE)), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); conditionMessage(e) })
    if (is.character(out)) { res[[rot]] <- data.table(painel = painel, faccao = f, amostra = s, outcome = y, erro = out); next }
    res[[rot]] <- cbind(painel = painel, faccao = f, amostra = s, out$linha, erro = "")
    evs[[rot]] <- cbind(painel = painel, faccao = f, amostra = s, outcome = y, out$r$event[, .(e, att, se_boot_did = se)],
                        se = sqrt(diag(out$r$V_event)))
    with(out$linha, cat(sprintf("  %-50s ATT=%+.4f (se %.4f, p %.3f) | pré p=%.3f | M̄rm=%.1f | SD: IC0 [%+.4f, %+.4f] Mbrk=%.4f ref=%.4f\n",
                                rot, att_group, se_group, p_group, wald_pre_p, mbar_rm, sd_ic0_lb, sd_ic0_ub, sd_M_breakdown, sd_ref_M)))
  }
}
R <- rbindlist(res, fill = TRUE); E <- rbindlist(evs)
fwrite(R, file.path(OUT, sprintf("F02_%s%s_estimativas.csv", bloco, SUF)))
fwrite(E, file.path(OUT, sprintf("F02_%s%s_event.csv", bloco, SUF)))
writeLines(sprintf("did %s, DRDID %s, HonestDiD %s, seed %d, biters %d, snapshot %s", CS_VERSOES$did, CS_VERSOES$DRDID,
                   as.character(packageVersion("HonestDiD")), 20261009, BITERS, SNAP), file.path(OUT, sprintf("F02_%s%s_versoes.txt", bloco, SUF)))
cat(sprintf("\nOK F02 %s: %d estimativas, %d erros\n", bloco, nrow(R), sum(R$erro != "")))
