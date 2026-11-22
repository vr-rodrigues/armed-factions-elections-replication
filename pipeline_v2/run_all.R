# run_all.R — roda o pipeline v2 de ponta a ponta e registra hashes das saídas (teste de determinismo)
# Uso: Rscript run_all.R [rotulo]
# Ordem: 01 locais por ano -> 02 crosswalk de local físico -> 03 seção -> local -> 04 votos -> 05 outcomes
#        -> 06 tratamento -> 07 painéis -> testes do motor CS-DID (dados simulados)
# Fonte: Base dos Dados (parquet em $AFE_DADOS/basedosdados_tse, ver base_dados_bd/README.md)

args <- commandArgs(trailingOnly = TRUE)
rotulo <- if (length(args)) args[1] else format(Sys.time(), "%Y%m%d_%H%M%S")
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
PIPE <- dirname(normalizePath(.f))
RS <- file.path(R.home("bin"), "Rscript")

passos <- c("R/01_locais_ano.R", "R/02_place_crosswalk.R", "R/03_secao_place.R", "R/04_votos_place.R",
            "R/05_outcomes.R", "R/06_tratamento.R", "R/07_paineis.R", "tests/test_cs_engine.R")
dir.create(file.path(PIPE, "logs"), showWarnings = FALSE)
for (p in passos) {
  log <- file.path(PIPE, "logs", sprintf("%s_%s.log", rotulo, tools::file_path_sans_ext(basename(p))))
  t0 <- Sys.time()
  st <- system2(RS, shQuote(file.path(PIPE, p)), stdout = log, stderr = log)
  cat(sprintf("%-28s status=%d  %.1f min\n", p, st, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  if (st != 0) stop("falhou: ", p, " (ver ", log, ")")
}

# hashes de todas as saídas (dados pesados e relatórios), exceto a amostra aleatória de validação manual
source(file.path(PIPE, "R", "00_config.R"))
fs <- c(list.files(OUT_DIR, pattern = "\\.parquet$", full.names = TRUE),
        list.files(CHECK_DIR, pattern = "\\.csv$", full.names = TRUE))
h <- data.table::data.table(arquivo = basename(fs), sha256 = vapply(fs, function(f) digest::digest(file = f, algo = "sha256"), ""))
data.table::fwrite(h, file.path(PIPE, "logs", sprintf("hashes_%s.csv", rotulo)))

# versões
v <- data.table::data.table(item = c("R", "did", "DRDID", "data.table", "arrow", "sf", "igraph"),
                            versao = c(R.version.string, vapply(c("did", "DRDID", "data.table", "arrow", "sf", "igraph"),
                                                               function(p) as.character(packageVersion(p)), "")))
data.table::fwrite(v, file.path(PIPE, "logs", sprintf("versoes_%s.csv", rotulo)))
cat("OK run_all", rotulo, "\n")
