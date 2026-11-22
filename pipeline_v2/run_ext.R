# run_ext.R — roda a extensão do pipeline v2 (F5, F4, captação, F6) e registra hashes das saídas
# Uso: Rscript run_ext.R [rotulo]. Lê as saídas do pipeline v2 (inalteradas) e os dados extras da Base dos Dados.
AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
args <- commandArgs(trailingOnly = TRUE)
rotulo <- if (length(args)) args[1] else format(Sys.time(), "%Y%m%d_%H%M%S")
PIPE <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
RS <- file.path(R.home("bin"), "Rscript")
passos <- c("R_ext/08_f5_lista_aberta.R", "R_ext/09_f4_mecanismos.R", "R_ext/10_captacao.R", "R_ext/11_f6_ideologia.R", "R_ext/12_f6_blocos.R")
dir.create(file.path(PIPE, "logs"), showWarnings = FALSE)
for (p in passos) {
  log <- file.path(PIPE, "logs", sprintf("ext_%s_%s.log", rotulo, tools::file_path_sans_ext(basename(p))))
  t0 <- Sys.time(); st <- system2(RS, shQuote(file.path(PIPE, p)), stdout = log, stderr = log)
  cat(sprintf("%-32s status=%d  %.1f min\n", p, st, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  if (st != 0) stop("falhou: ", p, " (ver ", log, ")")
}
EXT <- file.path(AFE_DADOS, "pipeline_v2_ext")
fs <- c(list.files(EXT, pattern = "\\.parquet$", full.names = TRUE), list.files(file.path(PIPE, "checks_ext"), pattern = "\\.csv$", full.names = TRUE))
h <- data.table::data.table(arquivo = basename(fs), sha256 = vapply(fs, function(f) digest::digest(file = f, algo = "sha256"), ""))
data.table::fwrite(h, file.path(PIPE, "logs", sprintf("hashes_ext_%s.csv", rotulo)))
v <- data.table::data.table(item = c("R", "data.table", "arrow", "sf", "GEOS"),
                            versao = c(R.version.string, as.character(packageVersion("data.table")), as.character(packageVersion("arrow")),
                                       as.character(packageVersion("sf")), sf::sf_extSoftVersion()[["GEOS"]]))
data.table::fwrite(v, file.path(PIPE, "logs", sprintf("versoes_ext_%s.csv", rotulo)))
cat("OK run_ext", rotulo, "\n")
