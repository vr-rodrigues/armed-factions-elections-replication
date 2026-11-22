# V02_curva.R — curva de especificações, painel municipal
# Dimensões (fixadas antes de estimar):
#   tratamento: ponto | captacao (Censo 2010, limiar 0,5)
#   tempo     : Y-1 | Y (mapa do próprio ano)
#   faccao    : entrada | estavel (classe pela trajetória nos 5 mapas de anos municipais; quem troca sai, como no paper)
#   amostra   : fronteira 500 m | 1 km | 2 km | todos os locais
#   painel    : bal (balanceado, peso fixo) | rc (desbalanceado, cortes repetidos, pesos do ano)
#   comparacao: ~ mun (dentro do município) | ~ 1 (entre municípios)
#   agregacao : group | dynamic (da mesma estimação)
# Estimador: fase2/util_v2.R::estima, validado contra o F01 até 1e-10. Sempre tratados (coorte <= 2008)
# removidos antes do att_gt em todas as especificações. Especificação não identificada fica registrada, sem estimativa.
# Uso: Rscript V02_curva.R <faccao> <outcome>      Saída: resultados/curva/V02_<faccao>_<outcome>.csv

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({ library(data.table); library(arrow) })
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]); F2DIR <- dirname(normalizePath(.f))
source(file.path(F2DIR, "..", "pipeline_v2", "R", "cs_engine.R"))   # cria_contraste
source(file.path(F2DIR, "util_v2.R"))
SNAP <- file.path(AFE_DADOS, "pipeline_v2"); EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
OUT <- file.path(F2DIR, "resultados", "curva"); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
a <- commandArgs(TRUE); f <- a[1]; yv <- a[2]
ELEI <- c(2008L, 2012L, 2016L, 2020L, 2024L)
coorte <- function(entrada, cal, defas) vapply(entrada, function(e) { if (is.na(e)) return(NA_integer_)
  ok <- cal[cal - defas >= e]; if (length(ok)) as.integer(min(ok)) else NA_integer_ }, integer(1))

PM <- as.data.table(read_parquet(file.path(SNAP, "painel_municipal.parquet")))[versao == "principal"]
# outcomes: contrastes com a escala fixa da amostra principal (F01) e F5 do vereador
ESC <- fread(file.path(F2DIR, "..", "fase1", "resultados", "F01_escalas_contraste.csv"))[faccao == f]
for (v in c("margin", "hhi")) { es <- ESC[var == v]; PM <- cria_contraste(PM, v, TRUE, escala = c(sd_pref = es$sd_pref, sd_ver = es$sd_ver)) }
for (v in c("dissim", "exc_hhi", "exc_vencedor", "brancos_nulos")) PM <- cria_contraste(PM, v, FALSE)
F5 <- as.data.table(read_parquet(file.path(EXT, "f5_lista_aberta.parquet")))[versao == "principal" & cargo == "vereador",
        .(place_id, ano, hhi_part_ver = hhi_part, intra_part_ver = intra_part, exc_top_local_ver = exc_top_local)]
PM <- merge(PM, F5, by = c("place_id", "ano"), all.x = TRUE)
F6 <- as.data.table(read_parquet(file.path(EXT, "f6_ideologia.parquet")))[versao == "principal",
        .(place_id, ano, saldo_pref, saldo_ver, s_dir_pref, s_esq_pref, s_dir_ver, s_esq_ver)]   # F6 (exploratório)
PM <- merge(PM, F6, by = c("place_id", "ano"), all.x = TRUE)
stopifnot(yv %in% names(PM))

TP <- as.data.table(read_parquet(file.path(SNAP, "tratamento_place.parquet")))
dist <- TP[, .(place_id, dist_env_milicia_m, dist_env_trafico_m)]
TC <- as.data.table(read_parquet(file.path(EXT, "captacao_tratamento.parquet")))[medida == "c2010" & limiar == 0.5]
# classe estável (variante D): tipos presentes nos 5 mapas de anos municipais
EP <- as.data.table(read_parquet(file.path(SNAP, "exposicao_anual.parquet")))[ano_mapa %in% ELEI & dentro_controle == TRUE]
CLS_P <- EP[, .(classe = { u <- unique(faccao); if (length(u) == 1) u else NA_character_ }), by = place_id]
EC <- as.data.table(read_parquet(file.path(EXT, "captacao_exposicao.parquet")))[medida == "c2010" & ano_mapa %in% ELEI]
EC <- rbind(EC[milicia >= 0.5, .(place_id, ano_mapa, faccao = "milicia")], EC[trafico >= 0.5, .(place_id, ano_mapa, faccao = "trafico")])
CLS_C <- EC[, .(classe = { u <- unique(faccao); if (length(u) == 1) u else NA_character_ }), by = place_id]

trt_tab <- function(tratamento, tempo, faccao) {
  b <- if (tratamento == "ponto") TP[, .(place_id, entrada, faccao_entrada, nunca_tratado)] else TC[, .(place_id, entrada, faccao_entrada, nunca_tratado)]
  b[, g_lag := coorte(entrada, ELEI, if (tempo == "Y-1") 1L else 0L)]
  b[, `:=`(sempre_tratado = !is.na(g_lag) & g_lag <= 2008L, trat_pos_painel = !is.na(entrada) & is.na(g_lag))]
  if (faccao == "estavel") { cl <- if (tratamento == "ponto") CLS_P else CLS_C; b[, faccao_entrada := cl$classe[match(place_id, cl$place_id)]] }
  b[]
}

GR <- CJ(tratamento = c("ponto", "captacao"), tempo = c("Y-1", "Y"), faccao = c("entrada", "estavel"),
         amostra = c("fronteira_500", "fronteira_1000", "fronteira_2000", "todos"), painel = c("bal", "rc"), x = c("mun", "1"), sorted = FALSE)
cache <- list(); res <- vector("list", nrow(GR))
for (i in seq_len(nrow(GR))) {
  s <- GR[i]; kk <- paste(s$tratamento, s$tempo, s$faccao)
  if (is.null(cache[[kk]])) cache[[kk]] <- aplica_tratamento(PM, trt_tab(s$tratamento, s$tempo, s$faccao), "mun", dist)
  W <- cache[[kk]]
  col <- if (s$amostra == "todos") sprintf("amostra_todos_%s", f) else sprintf("amostra_fronteira_%s_%s", f, sub("fronteira_", "", s$amostra))
  d <- W[get(col) == TRUE][, g_ponte := g]
  r <- tryCatch(estima(d, yv, if (s$x == "1") ~ lrenda else ~ mun + lrenda, s$painel, paste(unlist(s), collapse = "|")),
                error = function(e) data.table(identificado = FALSE, motivo = substr(conditionMessage(e), 1, 200)))
  res[[i]] <- cbind(s, r)
}
R <- rbindlist(res, fill = TRUE)[, `:=`(faccao_alvo = f, outcome = yv)]
# conferência: a especificação principal reproduz o F01 (quando o outcome está no F01)
F01 <- fread(file.path(F2DIR, "..", "fase1", "resultados", "F01_todas_estimativas.csv"))[amostra == "a" & faccao == f & outcome == yv]
pr <- R[tratamento == "ponto" & tempo == "Y-1" & faccao == "entrada" & amostra == "fronteira_1000" & painel == "bal" & x == "mun"]
if (nrow(F01)) stopifnot(abs(pr$att_grp - F01$att_group) < 1e-10, abs(pr$se_grp - F01$se_group) < 1e-10)
fwrite(R, file.path(OUT, sprintf("V02_%s_%s.csv", f, yv)))
cat(sprintf("OK V02 %s %s: %d combinações, %d identificadas\n", f, yv, nrow(R), sum(R$identificado %in% TRUE)))
