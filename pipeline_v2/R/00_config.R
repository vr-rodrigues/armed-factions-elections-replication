# 00_config.R — caminhos, constantes e utilitários comuns do pipeline v2
# Fonte dos dados eleitorais: Base dos Dados (ver base_dados_bd/README.md).

AFE_DADOS <- normalizePath(Sys.getenv("AFE_DADOS", "data"), winslash = "/", mustWork = FALSE)   # pasta dos dados (README.md)
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(sf)
})

.this_dir <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  if (is.na(f)) getwd() else dirname(normalizePath(f))
}
PIPE_DIR <- normalizePath(file.path(.this_dir(), ".."), winslash = "/", mustWork = FALSE)
if (!dir.exists(file.path(PIPE_DIR, "R"))) PIPE_DIR <- normalizePath(.this_dir(), winslash = "/")

BD_DIR    <- file.path(AFE_DADOS, "basedosdados_tse")            # parquet da Base dos Dados
OUT_DIR   <- file.path(AFE_DADOS, "pipeline_v2")                 # saídas pesadas
CHECK_DIR <- file.path(PIPE_DIR, "checks")                               # relatórios de validação (pequenos)
MAPS_DIR  <- file.path(AFE_DADOS, "mapas_anuais")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(CHECK_DIR, showWarnings = FALSE, recursive = TRUE)

CRS_M <- 31983  # SIRGAS 2000 / UTM 23S (metros)

MUN <- data.table(
  tse  = c("58041","58157","58335","58378","58394","58149","58491","58530","58467","58637",
           "58653","58696","58718","58777","58122","58858","60011","58424","58971","59013"),
  ibge = c("3300456","3300803","3301702","3301900","3302007","3302270","3302502","3302700",
           "3302858","3303203","3303302","3303500","3303609","3303906","3304144","3304300",
           "3304557","3305554","3304904","3305109"),
  nome = c("BELFORD ROXO","CACHOEIRAS DE MACACU","DUQUE DE CAXIAS","ITABORAI","ITAGUAI","JAPERI",
           "MAGE","MARICA","MESQUITA","NILOPOLIS","NITEROI","NOVA IGUACU","PARACAMBI","PETROPOLIS",
           "QUEIMADOS","RIO BONITO","RIO DE JANEIRO","SEROPEDICA","SAO GONCALO","SAO JOAO DE MERITI"))

ANOS_MUNICIPAIS <- c(2008, 2012, 2016, 2020, 2024)
ANOS_GERAIS     <- c(2006, 2010, 2014, 2018, 2022)

read_bd <- function(tabela, anos = NULL) {
  fs <- list.files(file.path(BD_DIR, tabela), pattern = "\\.parquet$", full.names = TRUE)
  if (!is.null(anos)) fs <- fs[as.integer(sub(".*_(\\d{4})\\.parquet$", "\\1", fs)) %in% anos]
  stopifnot(length(fs) > 0)
  rbindlist(lapply(fs, function(f) as.data.table(read_parquet(f))), fill = TRUE, ignore.attr = TRUE)
}

# Normalização de nomes de locais para similaridade (remove acentos, pontuação e termos genéricos)
norm_nome <- function(x) {
  x <- toupper(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"))
  x[is.na(x)] <- ""
  x <- gsub("[^A-Z0-9 ]", " ", x)
  x <- gsub(" +", " ", x)   # colapsa espaços antes de remover siglas ("E. M." -> "E M")
  x <- gsub(paste0("\\b(ESCOLA|MUNICIPAL|ESTADUAL|FEDERAL|COLEGIO|CIEP|CENTRO|EDUCACIONAL|UNIDADE|",
                   "INSTITUTO|CRECHE|FACULDADE|UNIVERSIDADE|SALA|PREDIO|ANEXO|EM|E M|CE|C E|EE|E E|",
                   "DE|DA|DO|DOS|DAS|E|O|A|N|NO|NA)\\b"), " ", x)
  gsub(" +", " ", trimws(x))
}

# Normalização de endereços: abreviações comuns expandidas; tokens sem conteúdo removidos; números mantidos
norm_endereco <- function(x) {
  x <- toupper(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"))
  x[is.na(x)] <- ""
  x <- gsub("[^A-Z0-9 ]", " ", x)
  rep <- c("\\bR\\b" = "RUA", "\\bAV\\b" = "AVENIDA", "\\bAVEN\\b" = "AVENIDA", "\\bEST\\b" = "ESTRADA",
           "\\bESTR\\b" = "ESTRADA", "\\bPC\\b" = "PRACA", "\\bPCA\\b" = "PRACA", "\\bTRAV\\b" = "TRAVESSA",
           "\\bTV\\b" = "TRAVESSA", "\\bDR\\b" = "DOUTOR", "\\bPROF\\b" = "PROFESSOR", "\\bMAL\\b" = "MARECHAL",
           "\\bGAL\\b" = "GENERAL", "\\bGEN\\b" = "GENERAL", "\\bCEL\\b" = "CORONEL", "\\bSTA\\b" = "SANTA",
           "\\bSTO\\b" = "SANTO", "\\bROD\\b" = "RODOVIA", "\\bALM\\b" = "ALMIRANTE", "\\bPRES\\b" = "PRESIDENTE")
  for (k in names(rep)) x <- gsub(k, rep[[k]], x)
  x <- gsub("\\b(S|N|SN|NO|NUMERO|LOJA|LJ|LT|LOTE|QD|QUADRA|BL|BLOCO|DE|DA|DO|DOS|DAS|E|KM)\\b", " ", x)
  x <- gsub(" +", " ", trimws(x))
  x[!nzchar(x)] <- NA_character_
  x
}

# Tipo de escola pelo nome bruto: "M" (municipal), "E" (estadual) ou NA
tipo_escola <- function(nome) {
  x <- toupper(iconv(nome, from = "UTF-8", to = "ASCII//TRANSLIT")); x[is.na(x)] <- ""
  m <- grepl("MUNICIPAL|\\bE\\.? ?M\\.?\\b|^EM\\b|\\bCIEP\\b", x)
  e <- grepl("ESTADUAL|\\bC\\.? ?E\\.?\\b|\\bE\\.? ?E\\.?\\b|^CE\\b", x)
  fifelse(m & !e, "M", fifelse(e & !m, "E", NA_character_))
}

# Similaridade de Jaccard entre conjuntos de tokens (vetorizada)
jaccard <- function(a, b) {
  ta <- strsplit(a, " ", fixed = TRUE); tb <- strsplit(b, " ", fixed = TRUE)
  vapply(seq_along(ta), function(i) {
    x <- unique(ta[[i]][nzchar(ta[[i]])]); y <- unique(tb[[i]][nzchar(tb[[i]])])
    if (!length(x) || !length(y)) return(NA_real_)
    length(intersect(x, y)) / length(union(x, y))
  }, numeric(1))
}

# Guarda: interrompe com mensagem clara
check <- function(cond, msg) if (!isTRUE(cond)) stop("CHECK FALHOU: ", msg, call. = FALSE)

write_out <- function(dt, nome) {
  f <- file.path(OUT_DIR, paste0(nome, ".parquet"))
  write_parquet(dt, f)
  invisible(f)
}
