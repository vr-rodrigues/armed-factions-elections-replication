# V03_f6.R — análise EXPLORATÓRIA: família F6 (ideologia do voto) na especificação principal,
# com o tratamento por ponto e por área de captação (Censo 2010, limiar 0,5) lado a lado.
# Especificação (igual ao F01): CS-DID via pipeline_v2/R/cs_engine.R; painel balanceado; ~ mun + lrenda; reg; NYT + nunca tratados;
#   mapa Y−1; aggte group; CRVE na grade de 2 km (SE do bootstrap do did ao lado); seed 20261009; biters 999.
# Amostras: (a) fronteira 1 km (principal, com HonestDiD RM e SD); (b) NYT puro e (c) todos, para o critério (iv).
# Uso: Rscript V03_f6.R <painel> <faccao> <tratamento> [k/n]
#      painel em {mun, geral}; faccao em {milicia, trafico}; tratamento em {ponto, captacao}; k/n divide os outcomes de (a)
# Saída: resultados/V03_<painel>_<faccao>_<tratamento>[_p<k>de<n>]_{estimativas,event}.csv
# HonestDiD (RM e SD) só nos primários (saldo direita − esquerda).

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F2DIR <- dirname(normalizePath(.f))
source(file.path(F2DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
source(file.path(F2DIR, "util_v2.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2")
EXT  <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT  <- file.path(F2DIR, "resultados"); dir.create(OUT, showWarnings = FALSE)
BITERS <- 999

a <- commandArgs(TRUE); painel <- a[1]; f <- a[2]; trat <- a[3]
parte <- if (length(a) >= 4) as.integer(strsplit(a[4], "/")[[1]]) else c(1L, 1L)
stopifnot(painel %in% c("mun", "geral"), f %in% c("milicia", "trafico"), trat %in% c("ponto", "captacao"))
SUF <- if (parte[2] > 1) sprintf("_p%dde%d", parte[1], parte[2]) else ""
bloco <- sprintf("%s_%s_%s", painel, f, trat)
cat("V03", bloco, SUF, "\n")

PX <- as.data.table(read_parquet(file.path(SNAP, if (painel == "mun") "painel_municipal.parquet" else "painel_geral.parquet")))[versao == "principal"]
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
glag <- if (painel == "mun") "g_mun_lag" else "g_bien_lag"

# conferência: a função de tratamento reproduz o painel do 07 com o tratamento por ponto
chk <- aplica_tratamento(PX, TP[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag = get(glag))], painel, dist)
cols <- c("g", grep("^amostra_", names(PX), value = TRUE))
m <- merge(PX[, c("place_id", "ano", cols), with = FALSE], chk[, c("place_id", "ano", cols), with = FALSE], by = c("place_id", "ano"))
stopifnot(nrow(m) == nrow(PX), all(m$g.x == m$g.y))
for (cc in setdiff(cols, "g")) stopifnot(all((m[[paste0(cc, ".x")]] %in% TRUE) == m[[paste0(cc, ".y")]]))
if (trat == "captacao") {
  TC <- as.data.table(read_parquet(file.path(EXT, "captacao_tratamento.parquet")))[medida == "c2010" & limiar == 0.5]
  PX <- aplica_tratamento(PX, TC[, .(place_id, faccao_entrada, sempre_tratado, nunca_tratado, trat_pos_painel, g_lag = get(glag))], painel, dist)
}

# outcomes da F6 (pipeline_v2/R_ext/11_f6_ideologia.R)
F6 <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
PX <- merge(PX, F6[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
if (painel == "mun") {
  CG <- c("pref", "ver")
  FAM <- data.table(outcome = c(paste0("saldo_", CG), paste0("s_dir_", CG), paste0("s_esq_", CG), paste0("s_cen_", CG)),
                    familia = "F6", papel = rep(c("primario", "secundario"), c(2, 6)))
  ROB <- paste0("saldo_rob_", CG)
} else {
  CG <- c("pres", "gov", "depest")
  FAM <- data.table(outcome = c(paste0("saldo_", CG), paste0("s_dir_", CG), paste0("s_esq_", CG), paste0("s_cen_", CG)),
                    familia = "F6", papel = rep(c("primario", "secundario"), c(3, 9)))
  ROB <- c("saldo_sen", "saldo_depfed")                                   # complemento
}
fwrite(FAM, file.path(OUT, sprintf("V03_%s_familias.csv", painel)))

roda <- function(d, y, rot, hd) {
  r <- cs_estimar(d, y, biters = BITERS, rotulo = rot)
  g <- r$overall[tipo == "group"]
  h <- prep_hd(r); np <- sum(h$e >= 0); l <- rep(1 / np, np); kp <- h$e >= 0
  linha <- data.table(outcome = y, att_group = g$att, se_group = r$se_group_crve, p_group = 2 * pnorm(-abs(g$att / r$se_group_crve)),
                      se_group_boot_did = g$se, att_dynamic = r$overall[tipo == "dynamic"]$att,
                      media_pos = sum(l * h$b[kp]), wald_pre_df = r$wald_pre_crve$df, wald_pre_p = r$wald_pre_crve$p,
                      wald_pre_p_did = r$wald_pre_did$p, unidades = r$n$unidades, tratados = sum(r$n$por_coorte[u_g > 0]$N),
                      clusters = r$n$clusters, municipios = r$n$municipios,
                      coortes = paste(r$n$por_coorte[u_g > 0, sprintf("%d:%d", u_g, N)], collapse = " "),
                      log = if (is.null(r$log)) "" else r$log)
  list(r = r, linha = cbind(linha, if (hd) cbind(honest_rm(r), honest_sd(r)) else HD_VAZIO))
}

AM <- list(a = PX[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE],
           b = PX[get(sprintf("amostra_nyt_%s", f)) == TRUE & balanceado == TRUE],
           c = PX[get(sprintf("amostra_todos_%s", f)) == TRUE & balanceado == TRUE])
res <- list(); evs <- list()
for (s in names(AM)) {
  if (s != "a" && parte[1] != 1) next
  ys <- if (s == "a") c(FAM$outcome, ROB) else FAM$outcome
  if (s == "a") ys <- ys[(seq_along(ys) - 1) %% parte[2] == parte[1] - 1]
  for (y in ys) {
    rot <- sprintf("%s|%s|%s", bloco, s, y)
    hd <- s == "a" && y %in% FAM[papel == "primario", outcome]
    out <- tryCatch(roda(AM[[s]], y, rot, hd), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); conditionMessage(e) })
    if (is.character(out)) { res[[rot]] <- data.table(painel = painel, faccao = f, tratamento = trat, amostra = s, outcome = y, erro = out); next }
    res[[rot]] <- cbind(painel = painel, faccao = f, tratamento = trat, amostra = s, out$linha, erro = "")
    evs[[rot]] <- cbind(painel = painel, faccao = f, tratamento = trat, amostra = s, outcome = y,
                        out$r$event[, .(e, att, se_boot_did = se)], se = sqrt(diag(out$r$V_event)))
    with(out$linha, cat(sprintf("  %-55s ATT=%+.4f (se %.4f, p %.3f) | pré p=%.3f | M̄rm=%s | tratados %d\n", rot, att_group, se_group,
                                p_group, wald_pre_p, format(mbar_rm), tratados)))
  }
}
R <- rbindlist(res, fill = TRUE); E <- rbindlist(evs)
fwrite(R, file.path(OUT, sprintf("V03_%s%s_estimativas.csv", bloco, SUF)))
fwrite(E, file.path(OUT, sprintf("V03_%s%s_event.csv", bloco, SUF)))
writeLines(sprintf("did %s, DRDID %s, HonestDiD %s, seed %d, biters %d, snapshot %s, ext %s", CS_VERSOES$did, CS_VERSOES$DRDID,
                   as.character(packageVersion("HonestDiD")), 20261009, BITERS, SNAP, EXT), file.path(OUT, sprintf("V03_%s%s_versoes.txt", bloco, SUF)))
cat(sprintf("OK V03 %s%s: %d estimativas, %d erros\n", bloco, SUF, nrow(R), sum(R$erro != "")))
