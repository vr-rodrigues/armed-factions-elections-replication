# W01_estimativas_paper.R — estimativas CS-DID para as tabelas e figuras do paper
# Especificação principal (igual ao F01): fronteira 1 km, painel balanceado de locais físicos, ~ mun + lrenda, reg,
# ainda não tratados + nunca tratados, mapa Y−1, base universal, agregação group, CRVE na grade de 2 km, pesos fixos.
# Amostra (c) "todos" (todos os nunca tratados dos municípios com tratados) como benchmark de controle amplo.
# Uso: Rscript W01_estimativas_paper.R <k/n>   (parte k de n da lista de estimações; sem argumento roda tudo)
# Saída: resultados/W01_<faccao>_<amostra>_<outcome>.rds (linha-resumo, event study e matriz de covariância CRVE)

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados", "rds"); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
BITERS <- 999

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
for (nm in c("f6_ideologia", "w00_outcomes_paper")) {
  X <- as.data.table(read_parquet(file.path(EXT, paste0(nm, ".parquet"))))[versao == "principal"]
  PM <- merge(PM, X[, !c("versao", "mun")], by = c("place_id", "ano"), all.x = TRUE)
}
# esquerda programática (PT, PSOL, PDT, PSB) = esquerda menos as demais legendas de esquerda
PM[, `:=`(hhi_esq_prog_pref = hhi_esq_pref - hhi_esq_outras_pref, lider_esq_prog_pref = lider_esq_pref - lider_esq_outras_pref)]

CORE <- c("hhi_pref", "enc_pref", "margin_pref", "comparecimento_taxa", "hhi_ver", "enc_ver", "margin_ver")
SEL  <- as.vector(outer(c("eleito_share", "ncomp1", "top1", "top3", "pubadm_share"), c("pref", "ver"), paste, sep = "_"))
DECO <- c("lider_apt_pref", "outros_apt_pref", "bn_apt_pref",
          paste0(c("hhi_dir", "hhi_cen", "hhi_esq", "hhi_pt", "hhi_psol", "hhi_pdt", "hhi_psb", "hhi_esq_outras",
                   "lider_dir", "lider_cen", "lider_esq", "lider_esq_outras", "hhi_esq_prog", "lider_esq_prog"), "_pref"),
          "hhi_dir_ver", "hhi_cen_ver", "hhi_esq_ver")
IDEO <- c("saldo_ver", "s_dir_ver", "s_esq_ver", "saldo_pref")
JOBS <- rbind(CJ(faccao = c("trafico", "milicia"), amostra = "a", outcome = c(CORE, SEL, DECO, IDEO), sorted = FALSE),
              CJ(faccao = c("trafico", "milicia"), amostra = "c", outcome = CORE, sorted = FALSE))
a <- commandArgs(TRUE)
if (length(a)) { p <- as.integer(strsplit(a[1], "/")[[1]]); JOBS <- JOBS[(seq_len(.N) - 1) %% p[2] == p[1] - 1] }

amostra <- function(f, s) {
  col <- if (s == "a") sprintf("amostra_fronteira_%s_1000", f) else sprintf("amostra_todos_%s", f)
  PM[get(col) == TRUE & balanceado == TRUE]
}
# painel balanceado no outcome: o motor exige que nenhum local perca anos por NA (Itaguaí 2024 em eleito_share_pref)
sem_na <- function(d, y) { fora <- unique(d$place_id[is.na(d[[y]])]); if (length(fora)) cat(sprintf("  %s: %d locais sem o outcome em algum ano, excluídos
", y, length(fora))); d[!place_id %in% fora] }
for (j in seq_len(nrow(JOBS))) {
  f <- JOBS$faccao[j]; s <- JOBS$amostra[j]; y <- JOBS$outcome[j]
  arq <- file.path(OUT, sprintf("W01_%s_%s_%s.rds", f, s, y))
  if (file.exists(arq)) next
  rot <- paste(f, s, y); t0 <- Sys.time()
  r <- tryCatch(cs_estimar(sem_na(amostra(f, s), y), y, biters = BITERS, rotulo = rot), error = function(e) { cat("ERRO", rot, conditionMessage(e), "\n"); NULL })
  if (is.null(r)) next
  g <- r$overall[tipo == "group"]; ev <- r$event; V <- r$V_event
  ev[, se := sqrt(diag(V))]
  # e = 0 e e = +4 (um ciclo depois) e a diferença, com a covariância CRVE do event study
  k0 <- which(ev$e == 0); k4 <- which(ev$e == 4)
  dif <- if (length(k4)) ev$att[k4] - ev$att[k0] else NA_real_
  se_dif <- if (length(k4)) sqrt(V[k0, k0] + V[k4, k4] - 2 * V[k0, k4]) else NA_real_
  linha <- data.table(faccao = f, amostra = s, outcome = y, att = g$att, se = r$se_group_crve,
                      p = 2 * pnorm(-abs(g$att / r$se_group_crve)), se_boot_did = g$se,
                      pre_p = r$wald_pre_crve$p, pre_df = r$wald_pre_crve$df,
                      e0 = ev$att[k0], se_e0 = ev$se[k0], e4 = if (length(k4)) ev$att[k4] else NA_real_,
                      se_e4 = if (length(k4)) ev$se[k4] else NA_real_, dif_e4_e0 = dif, se_dif = se_dif,
                      tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades, clusters = r$n$clusters,
                      municipios = r$n$municipios, log = if (is.null(r$log)) "" else r$log)
  saveRDS(list(linha = linha, event = ev, V_event = V, celulas = r$celulas, versoes = r$versoes, seed = r$seed), arq)
  cat(sprintf("%-50s ATT %+.4f (%.4f) pré p %.3f  [%.0fs]\n", rot, g$att, r$se_group_crve, r$wald_pre_crve$p,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
cat("OK W01", if (length(a)) a[1] else "", "\n")
