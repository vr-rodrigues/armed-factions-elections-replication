# 00_config_ext.R — extensão do pipeline v2 para as medidas F5, F4 e captação
# Lê as saídas validadas do pipeline v2 (não alteradas) e os dados extras da Base dos Dados (extrair_bd_v2.py);
# grava em EXT_DIR e os relatórios em pipeline_v2/checks_ext.

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
.ext_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(.ext_dir, "..", "R", "00_config.R"))   # MUN, CRS_M, check(), funções comuns

SNAP      <- file.path(AFE_DADOS, "pipeline_v2")   # saídas validadas do pipeline v2
BD2_DIR   <- file.path(AFE_DADOS, "basedosdados_v2")             # extrair_bd_v2.py
EXT_DIR   <- file.path(AFE_DADOS, "pipeline_v2_ext")
CHECK_EXT <- normalizePath(file.path(.ext_dir, "..", "checks_ext"), winslash = "/", mustWork = FALSE)
MAPS_ANUAIS <- file.path(AFE_DADOS, "mapas_anuais")
dir.create(EXT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(CHECK_EXT, showWarnings = FALSE, recursive = TRUE)

read_snap <- function(nome) as.data.table(read_parquet(file.path(SNAP, paste0(nome, ".parquet"))))
read_bd2  <- function(nome) as.data.table(read_parquet(file.path(BD2_DIR, paste0(nome, ".parquet"))))
write_ext <- function(dt, nome) { f <- file.path(EXT_DIR, paste0(nome, ".parquet")); write_parquet(dt, f); invisible(f) }

# partido do governador na data de cada eleição municipal
GOV_PARTIDO <- data.table(ano = c(2008L, 2012L, 2016L, 2020L, 2024L), partido_gov = c("PMDB", "PMDB", "PMDB", "PSC", "PL"))
