# W16_legislativo_estadual.R — composição partidária do voto para deputado estadual e federal
# Painel de eleições gerais (2006–2022), mesma especificação do motor (fronteira 1 km, painel balanceado, ~ mun + lrenda, reg,
# NYT + NT, group, CRVE na grade de 2 km). Deputado estadual e federal são eleitos por lista aberta, como vereador:
# se a entrada da milícia desloca o voto para vereador à direita, o mesmo teste nos dois cargos legislativos estaduais
# é uma checagem fora da amostra municipal. Estimativa de entrada e placebo de vizinhança (mesma construção do W03).
# HHI de deputado estadual e federal entram só para conferir a reprodução do F02 (Tabela de eleições gerais).
# Saída: resultados/W16_legislativo_estadual.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F3DIR <- dirname(normalizePath(.f))
source(file.path(F3DIR, "..", "pipeline_v2", "R", "cs_engine.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F3DIR, "resultados"); F1 <- file.path(F3DIR, "..", "fase1", "resultados")

PG <- as.data.table(read_parquet(file.path(SNAP, "painel_geral.parquet")))[versao == "principal"]
X <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal"]
IDE <- c("saldo_depest", "s_dir_depest", "s_esq_depest", "saldo_depfed", "s_dir_depfed", "s_esq_depfed")
PG <- merge(PG, X[, c("place_id", "ano", IDE), with = FALSE], by = c("place_id", "ano"), all.x = TRUE)
TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
YS <- c(IDE, "hhi_depest", "hhi_depfed")
cat("anos:", paste(sort(unique(PG$ano)), collapse = " "), " | coortes g:", paste(sort(unique(PG$g)), collapse = " "), "\n")

sem_na <- function(d, y) { fora <- unique(d$place_id[is.na(d[[y]])]); d[!place_id %in% fora] }
amostra <- function(f) PG[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE]
amostra_placebo <- function(f) {
  XY <- unique(PG[, .(place_id, x, y)]); dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
  trat <- unique(PG[get(sprintf("amostra_fronteira_%s_1000", f)) == TRUE & balanceado == TRUE & g > 0, .(place_id, mun, g)])
  trat <- merge(trat, XY, by = "place_id")
  cand <- unique(PG[balanceado == TRUE & nunca_tratado == TRUE & mun %in% trat$mun, .(place_id, mun)])
  cand <- merge(merge(cand, XY, by = "place_id"), dist, by = "place_id")
  near <- cand[, { tt <- trat[mun == .BY$mun]; dd <- sqrt(outer(x, tt$x, "-")^2 + outer(y, tt$y, "-")^2)
    k <- max.col(-dd, ties.method = "first"); list(place_id = place_id, d_trat = dd[cbind(seq_len(.N), k)], g_near = tt$g[k]) }, by = mun]
  cand <- merge(cand, near[, .(place_id, d_trat, g_near)], by = "place_id")
  denv <- cand[[sprintf("dist_env_%s_m", f)]]
  cand[, papel := fifelse(d_trat <= 1000, "pseudo", fifelse(d_trat > 1500 & denv <= 3000, "controle", NA_character_))]
  sel <- cand[!is.na(papel), .(place_id, g_plac = fifelse(papel == "pseudo", g_near, 0L))]
  list(d = merge(PG[balanceado == TRUE], sel, by = "place_id")[, g := g_plac], pseudo = sel[g_plac > 0, .N], controles = sel[g_plac == 0, .N])
}
linha <- function(r, f, y, am, extra = NULL) { g <- r$overall[tipo == "group"]
  cbind(data.table(faccao = f, outcome = y, amostra = am, att = g$att, se = r$se_group_crve, p = 2 * pnorm(-abs(g$att / r$se_group_crve)),
                   pre_p = r$wald_pre_crve$p, tratados = sum(r$n$por_coorte[u_g > 0]$N), unidades = r$n$unidades, clusters = r$n$clusters), extra) }
res <- list()
for (f in c("milicia", "trafico")) {
  dE <- amostra(f); pl <- amostra_placebo(f)
  for (y in YS) {
    rE <- tryCatch(cs_estimar(sem_na(dE, y), y, biters = 99, rotulo = paste("entrada", f, y)), error = function(e) { cat("ERRO", f, y, conditionMessage(e), "\n"); NULL })
    if (!is.null(rE)) res[[paste(f, y, "E")]] <- linha(rE, f, y, "tratados", data.table(pseudo_tratados = NA_integer_, controles = NA_integer_))
    if (y %in% IDE) {
      rP <- tryCatch(cs_estimar(sem_na(pl$d, y), y, biters = 99, rotulo = paste("placebo", f, y)), error = function(e) { cat("ERRO placebo", f, y, conditionMessage(e), "\n"); NULL })
      if (!is.null(rP)) res[[paste(f, y, "P")]] <- linha(rP, f, y, "placebo", data.table(pseudo_tratados = pl$pseudo, controles = pl$controles))
    }
  }
}
R <- rbindlist(res); fwrite(R, file.path(OUT, "W16_legislativo_estadual.csv"))
print(R[, .(faccao, outcome, amostra, att = round(att, 4), se = round(se, 4), p = round(p, 3), pre_p = round(pre_p, 3), tratados, unidades)])
# conferência contra o F02 (painel geral, amostra a)
R2 <- fread(file.path(F1, "F02_todas_estimativas.csv"))[painel == "geral" & amostra == "a" & outcome %in% c("hhi_depest", "hhi_depfed"),
                                                        .(faccao, outcome, att_f02 = att_group, se_f02 = se_group)]
ch <- merge(R[amostra == "tratados" & outcome %in% c("hhi_depest", "hhi_depfed"), .(faccao, outcome, att, se)], R2, by = c("faccao", "outcome"))
print(ch[, .(faccao, outcome, dif_att = att - att_f02, dif_se = se - se_f02)])
cat("OK W16\n")
