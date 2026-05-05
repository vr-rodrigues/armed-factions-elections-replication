# ============================================================================
# 94_campaign_finance_outcomes.R
# ============================================================================
#
# Campaign-finance mechanism outcomes.
#
# The script expects TSE campaign-finance ZIP archives under:
#
#   data/raw/tse/prestacao_contas/
#
# Use code/download_campaign_finance.ps1 to fetch/resume the official archives.
#
# Outputs:
#   data/ipca_deflator_2024.csv
#   data/campaign_finance_by_candidate.csv
#   data/campaign_finance_by_location.csv
#   results/tab94_campaign_finance_availability.csv
#   results/tab94_campaign_finance_match_quality.csv
#   results/tab94_campaign_finance_overall.csv
#   results/tab94_campaign_finance_es.csv
# ============================================================================

library(data.table)
library(did)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                         value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
DATA_DIR <- file.path(BASE_DIR, "data")
OUT_DIR <- file.path(BASE_DIR, "results")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("============================================================\n")
cat("94_campaign_finance_outcomes.R\n")
cat("Campaign-finance outcomes\n")
cat("============================================================\n\n")

raw_dir <- Sys.getenv("TSE_FINANCE_DIR", "")
if (!nzchar(raw_dir)) raw_dir <- file.path(DATA_DIR, "raw", "tse", "prestacao_contas")
raw_dir <- normalizePath(raw_dir, winslash = "/", mustWork = FALSE)

resources <- data.table(
  election_year = c(2008, 2012, 2016, 2020, 2024),
  resource_name = c(
    "Prestacao de contas",
    "Prestacao de contas final",
    "Prestacoes de contas finais",
    "Candidatos",
    "Prestacao de contas de candidatos"
  ),
  file_name = c(
    "prestacao_contas_2008.zip",
    "prestacao_final_2012.zip",
    "prestacao_contas_final_2016.zip",
    "prestacao_de_contas_eleitorais_candidatos_2020.zip",
    "prestacao_de_contas_eleitorais_candidatos_2024.zip"
  ),
  expected_bytes = c(154761414, 671229467, 1095335631, 1301110312, 1283332278)
)
resources[, zip_path := file.path(raw_dir, file_name)]
resources[, exists_local := file.exists(zip_path)]
resources[, size_bytes := fifelse(exists_local, file.info(zip_path)$size, NA_real_)]
resources[, size_ok := exists_local & size_bytes == expected_bytes]
resources[, process_status := fifelse(size_ok, "ready", "missing_or_incomplete")]

fwrite(resources[, .(election_year, resource_name, file_name, zip_path,
                     expected_bytes, exists_local, size_bytes, size_ok,
                     process_status)],
       file.path(OUT_DIR, "tab94_campaign_finance_availability.csv"))

cat("Availability:\n")
print(resources[, .(election_year, file_name, size_bytes, expected_bytes, size_ok)])

if (!any(resources$size_ok)) {
  cat("\nNo complete campaign-finance archives found. Stop.\n")
  quit(save = "no", status = 0)
}

find_tse_dir <- function() {
  env <- Sys.getenv("TSE_RAW_DIR", "")
  candidates <- c(
    env,
    file.path(DATA_DIR, "raw", "tse"),
    file.path(DATA_DIR, "tse"),
    file.path(dirname(BASE_DIR), "legado", "01_workspace_pre_replication",
              "dados", "tse")
  )
  candidates <- candidates[nzchar(candidates)]
  for (p in candidates) {
    if (dir.exists(p) && file.exists(file.path(p, "votacao_secao_RJ_2024.csv"))) {
      return(normalizePath(p, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Could not find TSE raw directory. Set TSE_RAW_DIR or place files under data/raw/tse.")
}

TSE_DIR <- find_tse_dir()
CAND_DIR <- file.path(TSE_DIR, "candidatos")
cat(sprintf("\nUsing TSE raw dir: %s\n", TSE_DIR))
cat(sprintf("Using finance dir: %s\n\n", raw_dir))

clean_text <- function(x) {
  x <- trimws(as.character(x))
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  toupper(x)
}

std_cargo <- function(x) {
  z <- clean_text(x)
  fifelse(z == "PREFEITO", "Prefeito",
          fifelse(z == "VEREADOR", "Vereador", NA_character_))
}

parse_money <- function(x) {
  if (is.numeric(x)) return(x)
  x <- trimws(as.character(x))
  x[x %in% c("", "#NULO", "NA", "NaN")] <- NA_character_
  x <- gsub("\\.", "", x)
  x <- gsub(",", ".", x, fixed = TRUE)
  suppressWarnings(as.numeric(x))
}

clean_id <- function(x) {
  x <- trimws(as.character(x))
  x <- sub("\\.0$", "", x)
  x <- gsub("[^0-9]", "", x)
  x[x == ""] <- NA_character_
  x
}

build_ipca_deflator <- function(years, base_year = 2024) {
  out_path <- file.path(DATA_DIR, sprintf("ipca_deflator_%d.csv", base_year))
  url <- paste0(
    "https://api.bcb.gov.br/dados/serie/bcdata.sgs.433/dados?",
    "formato=csv&dataInicial=01/01/2008&dataFinal=31/12/", base_year
  )

  if (file.exists(out_path)) {
    cached <- fread(out_path)
    if (all(years %in% cached$election_year) &&
        "deflator_to_2024" %in% names(cached)) {
      cat(sprintf("Using cached IPCA deflator: %s\n", out_path))
      return(cached[election_year %in% years])
    }
  }

  tmp <- tempfile("ipca_433_", fileext = ".csv")
  ok <- tryCatch({
    utils::download.file(url, tmp, quiet = TRUE, mode = "wb")
    TRUE
  }, error = function(e) FALSE)
  if (!ok || !file.exists(tmp)) {
    stop("Could not download IPCA series from BCB SGS and no usable cached deflator was found.")
  }

  ipca <- fread(tmp, sep = ";", encoding = "UTF-8")
  setnames(ipca, c("data", "valor"), c("date", "ipca_pct"))
  ipca[, date := as.IDate(date, format = "%d/%m/%Y")]
  ipca[, ipca_pct := as.numeric(gsub(",", ".", ipca_pct, fixed = TRUE))]
  setorder(ipca, date)
  ipca[, cpi_index := 100 * cumprod(1 + ipca_pct / 100)]
  ipca[, election_year := as.integer(format(date, "%Y"))]

  annual <- ipca[, .(cpi_year_avg = mean(cpi_index, na.rm = TRUE)),
                 by = election_year]
  base_avg <- annual[election_year == base_year, cpi_year_avg]
  annual[, cpi_base_avg := base_avg]
  annual[, deflator_to_2024 := cpi_base_avg / cpi_year_avg]
  annual[, source := "Banco Central do Brasil SGS 433 (IPCA monthly percent change)"]
  annual <- annual[election_year %in% years]
  fwrite(annual, out_path)
  cat(sprintf("Wrote data/%s\n", basename(out_path)))
  annual
}

ipca_deflator <- build_ipca_deflator(resources$election_year)

pick_col <- function(nms, aliases) {
  hit <- aliases[aliases %in% nms]
  if (length(hit) == 0) NA_character_ else hit[1]
}

zip_names <- function(zip_path) {
  tryCatch(unzip(zip_path, list = TRUE)$Name, error = function(e) character())
}

extract_matching_file <- function(zip_path, patterns) {
  files <- zip_names(zip_path)
  hit <- files[Reduce(`&`, lapply(patterns, function(p) grepl(p, files, ignore.case = TRUE)))]
  if (!length(hit)) return(NA_character_)
  tmp <- tempfile("tse_fin_")
  dir.create(tmp)
  out <- unzip(zip_path, files = hit[1], exdir = tmp, overwrite = TRUE)
  normalizePath(out, winslash = "/", mustWork = TRUE)
}

aggregate_finance_file <- function(path, amount_aliases, amount_name,
                                   filter_rj_2008 = FALSE) {
  if (is.na(path) || !file.exists(path)) return(NULL)
  hdr <- names(fread(path, nrows = 0, sep = ";", encoding = "Latin-1",
                     showProgress = FALSE))

  sq_col <- pick_col(hdr, c("SQ_CANDIDATO", "Sequencial Candidato",
                            "SEQUENCIAL_CANDIDATO"))
  ue_col <- pick_col(hdr, c("SG_UE", "Sigla da UE", "Número UE", "Numero UE"))
  cargo_col <- pick_col(hdr, c("DS_CARGO", "Cargo"))
  nr_col <- pick_col(hdr, c("NR_CANDIDATO", "Número candidato",
                            "Numero candidato"))
  sg_partido_col <- pick_col(hdr, c("SG_PARTIDO", "Sigla  Partido"))
  nr_partido_col <- pick_col(hdr, c("NR_PARTIDO", "Número partido",
                                    "Numero partido"))
  amount_col <- pick_col(hdr, amount_aliases)
  uf_filter_col <- pick_col(hdr, c("SG_UE_SUPERIOR", "SG_UF", "UF"))

  needed <- unique(na.omit(c(sq_col, ue_col, cargo_col, nr_col,
                             sg_partido_col, nr_partido_col, amount_col,
                             uf_filter_col)))
  dt <- fread(path, select = needed, sep = ";", encoding = "Latin-1",
              showProgress = FALSE)

  if (filter_rj_2008 && !is.na(uf_filter_col)) {
    dt <- dt[clean_text(get(uf_filter_col)) == "RJ"]
  }

  dt[, SQ_CANDIDATO := clean_id(get(sq_col))]
  dt[, CD_MUNICIPIO := suppressWarnings(as.integer(clean_id(get(ue_col))))]
  dt[, DS_CARGO := std_cargo(get(cargo_col))]
  dt[, NR_CANDIDATO := suppressWarnings(as.integer(clean_id(get(nr_col))))]
  if (!is.na(sg_partido_col)) dt[, SG_PARTIDO := as.character(get(sg_partido_col))]
  else dt[, SG_PARTIDO := NA_character_]
  if (!is.na(nr_partido_col)) dt[, NR_PARTIDO := suppressWarnings(as.integer(clean_id(get(nr_partido_col))))]
  else dt[, NR_PARTIDO := NA_integer_]
  dt[, amount := parse_money(get(amount_col))]

  dt <- dt[DS_CARGO %in% c("Prefeito", "Vereador") & !is.na(SQ_CANDIDATO)]
  ans <- dt[, .(
    value = sum(amount, na.rm = TRUE),
    CD_MUNICIPIO = CD_MUNICIPIO[!is.na(CD_MUNICIPIO)][1],
    DS_CARGO = DS_CARGO[!is.na(DS_CARGO)][1],
    NR_CANDIDATO = NR_CANDIDATO[!is.na(NR_CANDIDATO)][1],
    NR_PARTIDO = NR_PARTIDO[!is.na(NR_PARTIDO)][1],
    SG_PARTIDO = SG_PARTIDO[!is.na(SG_PARTIDO)][1]
  ), by = SQ_CANDIDATO]
  setnames(ans, "value", amount_name)
  ans
}

finance_year <- function(yr, zip_path) {
  cat(sprintf("\n--- Finance %d ---\n", yr))

  if (yr == 2008) {
    exp_path <- extract_matching_file(zip_path, c("despesas_candidatos", "brasil"))
    rev_path <- extract_matching_file(zip_path, c("receitas_candidatos", "brasil"))
    exp <- aggregate_finance_file(exp_path, c("VR_DESPESA"), "total_expenses",
                                  filter_rj_2008 = TRUE)
    rev <- aggregate_finance_file(rev_path, c("VR_RECEITA"), "total_revenue",
                                  filter_rj_2008 = TRUE)
  } else if (yr == 2012) {
    exp_path <- extract_matching_file(zip_path, c("despesas_candidatos_2012_RJ"))
    rev_path <- extract_matching_file(zip_path, c("receitas_candidatos_2012_RJ"))
    exp <- aggregate_finance_file(exp_path, c("Valor despesa"), "total_expenses")
    rev <- aggregate_finance_file(rev_path, c("Valor receita"), "total_revenue")
  } else if (yr == 2016) {
    exp_path <- extract_matching_file(zip_path, c("despesas_candidatos", "2016_RJ"))
    rev_path <- extract_matching_file(zip_path, c("receitas_candidatos", "2016_RJ"))
    exp <- aggregate_finance_file(exp_path, c("Valor despesa"), "total_expenses")
    rev <- aggregate_finance_file(rev_path, c("Valor receita"), "total_revenue")
  } else {
    exp_path <- extract_matching_file(zip_path, c("despesas_contratadas_candidatos",
                                                  as.character(yr), "RJ"))
    rev_path <- extract_matching_file(zip_path, c("receitas_candidatos",
                                                  as.character(yr), "RJ"))
    exp <- aggregate_finance_file(exp_path, c("VR_DESPESA_CONTRATADA"),
                                  "total_expenses")
    rev <- aggregate_finance_file(rev_path, c("VR_RECEITA"),
                                  "total_revenue")
  }

  if (is.null(exp) && is.null(rev)) return(NULL)
  if (is.null(exp)) exp <- data.table(SQ_CANDIDATO = character())
  if (is.null(rev)) rev <- data.table(SQ_CANDIDATO = character())

  fin <- merge(exp, rev, by = "SQ_CANDIDATO", all = TRUE, suffixes = c("", "_rev"))
  for (v in c("CD_MUNICIPIO", "DS_CARGO", "NR_CANDIDATO", "NR_PARTIDO", "SG_PARTIDO")) {
    rv <- paste0(v, "_rev")
    if (rv %in% names(fin)) {
      fin[is.na(get(v)), (v) := get(rv)]
      fin[, (rv) := NULL]
    }
  }
  fin[is.na(total_expenses), total_expenses := 0]
  fin[is.na(total_revenue), total_revenue := 0]
  fin[, election_year := yr]
  cat(sprintf("  candidates with finance: %d\n", nrow(fin)))
  fin[]
}

finance_list <- list()
for (i in which(resources$size_ok)) {
  yr <- resources$election_year[i]
  res <- finance_year(yr, resources$zip_path[i])
  if (!is.null(res)) finance_list[[as.character(yr)]] <- res
}

finance <- rbindlist(finance_list, fill = TRUE)
setcolorder(finance, c("election_year", "SQ_CANDIDATO", "CD_MUNICIPIO",
                       "DS_CARGO", "NR_CANDIDATO", "NR_PARTIDO", "SG_PARTIDO"))
finance <- unique(finance, by = c("election_year", "SQ_CANDIDATO"))
finance <- merge(
  finance,
  ipca_deflator[, .(election_year, deflator_to_2024)],
  by = "election_year",
  all.x = TRUE
)
finance[, total_expenses_nominal := total_expenses]
finance[, total_revenue_nominal := total_revenue]
finance[, total_expenses := total_expenses_nominal * deflator_to_2024]
finance[, total_revenue := total_revenue_nominal * deflator_to_2024]
fwrite(finance, file.path(DATA_DIR, "campaign_finance_by_candidate.csv"))
cat(sprintf("\nWrote data/campaign_finance_by_candidate.csv (%d rows)\n",
            nrow(finance)))

read_candidates_key <- function(yr) {
  f <- file.path(CAND_DIR, sprintf("consulta_cand_%d_RJ.csv", yr))
  cand <- fread(f, encoding = "Latin-1", showProgress = FALSE)
  cand[, election_year := yr]
  cand[, DS_CARGO := std_cargo(DS_CARGO)]
  if (!"CD_MUNICIPIO" %in% names(cand)) cand[, CD_MUNICIPIO := as.integer(SG_UE)]
  cand[, CD_MUNICIPIO := as.integer(CD_MUNICIPIO)]
  cand[, NR_CANDIDATO := as.integer(NR_CANDIDATO)]
  cand[, SQ_CANDIDATO := clean_id(SQ_CANDIDATO)]
  unique(cand[DS_CARGO %in% c("Prefeito", "Vereador"),
              .(election_year, CD_MUNICIPIO, DS_CARGO, NR_CANDIDATO,
                SQ_CANDIDATO)])
}

read_votes_year <- function(yr, cand_key) {
  f <- file.path(TSE_DIR, sprintf("votacao_secao_RJ_%d.csv", yr))
  header <- names(fread(f, nrows = 0, showProgress = FALSE))
  select_cols <- intersect(header, c("CD_MUNICIPIO", "NR_ZONA",
                                     "NR_LOCAL_VOTACAO", "NR_TURNO",
                                     "DS_CARGO", "NR_VOTAVEL", "QT_VOTOS"))
  dt <- fread(f, select = select_cols, encoding = "Latin-1", showProgress = FALSE)
  dt[, election_year := yr]
  dt[, DS_CARGO := std_cargo(DS_CARGO)]
  dt <- dt[NR_TURNO == 1 & DS_CARGO %in% c("Prefeito", "Vereador")]
  dt[, CD_MUNICIPIO := as.integer(CD_MUNICIPIO)]
  dt[, NR_VOTAVEL := as.integer(NR_VOTAVEL)]
  dt[, QT_VOTOS := as.numeric(QT_VOTOS)]
  dt[, loc_id := paste(CD_MUNICIPIO, NR_ZONA, NR_LOCAL_VOTACAO, sep = "_")]

  dt <- merge(dt, cand_key,
              by.x = c("election_year", "CD_MUNICIPIO", "DS_CARGO", "NR_VOTAVEL"),
              by.y = c("election_year", "CD_MUNICIPIO", "DS_CARGO", "NR_CANDIDATO"),
              all.x = FALSE)
  dt[, .(votes = sum(QT_VOTOS, na.rm = TRUE)),
     by = .(loc_id, election_year, DS_CARGO, CD_MUNICIPIO, SQ_CANDIDATO)]
}

cat("\n--- Building candidate-location vote weights ---\n")
years_ready <- sort(unique(finance$election_year))
cand_key <- rbindlist(lapply(years_ready, read_candidates_key), fill = TRUE)
votes <- rbindlist(lapply(years_ready, function(yr) {
  cat(sprintf("  Votes %d\n", yr))
  read_votes_year(yr, cand_key[election_year == yr])
}), fill = TRUE)

votes[, loc_total_votes := sum(votes, na.rm = TRUE),
      by = .(loc_id, election_year, DS_CARGO)]
votes[, vote_share_candidate := votes / loc_total_votes]
votes[, candidate_total_votes := sum(votes, na.rm = TRUE),
      by = .(election_year, DS_CARGO, SQ_CANDIDATO)]

votes <- merge(votes,
               finance[, .(election_year, SQ_CANDIDATO, total_expenses,
                            total_revenue)],
               by = c("election_year", "SQ_CANDIDATO"), all.x = TRUE)
votes[, has_finance := !is.na(total_expenses) | !is.na(total_revenue)]
votes[is.na(total_expenses), total_expenses := 0]
votes[is.na(total_revenue), total_revenue := 0]
votes[, expenses_per_vote_candidate := fifelse(candidate_total_votes > 0,
                                               total_expenses / candidate_total_votes,
                                               NA_real_)]
votes[, revenue_per_vote_candidate := fifelse(candidate_total_votes > 0,
                                              total_revenue / candidate_total_votes,
                                              NA_real_)]

candidate_rank <- unique(votes[, .(election_year, DS_CARGO, SQ_CANDIDATO,
                                   total_expenses)])
candidate_rank[, high_expense_q75 := {
  vals <- total_expenses[total_expenses > 0]
  if (length(vals) < 5) rep(FALSE, .N) else total_expenses >= quantile(vals, 0.75, na.rm = TRUE)
}, by = .(election_year, DS_CARGO)]
votes <- merge(votes, candidate_rank[, .(election_year, DS_CARGO, SQ_CANDIDATO,
                                         high_expense_q75)],
               by = c("election_year", "DS_CARGO", "SQ_CANDIDATO"), all.x = TRUE)
votes[is.na(high_expense_q75), high_expense_q75 := FALSE]

loc_fin <- votes[, .(
  finance_candidate_votes = sum(votes, na.rm = TRUE),
  finance_vote_match_share = sum(votes[has_finance == TRUE], na.rm = TRUE) /
    sum(votes, na.rm = TRUE),
  expenses_vote_weighted = sum(vote_share_candidate * total_expenses, na.rm = TRUE),
  revenue_vote_weighted = sum(vote_share_candidate * total_revenue, na.rm = TRUE),
  expenses_per_vote_weighted = sum(vote_share_candidate * expenses_per_vote_candidate,
                                   na.rm = TRUE),
  revenue_per_vote_weighted = sum(vote_share_candidate * revenue_per_vote_candidate,
                                  na.rm = TRUE),
  high_expense_vote_share = sum(vote_share_candidate[high_expense_q75 == TRUE],
                                na.rm = TRUE),
  zero_expense_vote_share = sum(vote_share_candidate[total_expenses == 0],
                                na.rm = TRUE)
), by = .(loc_id, election_year, DS_CARGO)]

for (cc in names(loc_fin)) {
  if (is.numeric(loc_fin[[cc]])) {
    loc_fin[is.nan(get(cc)) | is.infinite(get(cc)), (cc) := NA_real_]
  }
}

fwrite(loc_fin, file.path(DATA_DIR, "campaign_finance_by_location.csv"))
cat(sprintf("Wrote data/campaign_finance_by_location.csv (%d rows)\n",
            nrow(loc_fin)))

match_quality <- loc_fin[, .(
  n_location_office_year = .N,
  mean_vote_match_share = mean(finance_vote_match_share, na.rm = TRUE),
  p10_vote_match_share = quantile(finance_vote_match_share, 0.10, na.rm = TRUE),
  p50_vote_match_share = quantile(finance_vote_match_share, 0.50, na.rm = TRUE),
  p90_vote_match_share = quantile(finance_vote_match_share, 0.90, na.rm = TRUE)
), by = .(election_year, DS_CARGO)]
fwrite(match_quality, file.path(OUT_DIR, "tab94_campaign_finance_match_quality.csv"))
cat("Wrote results/tab94_campaign_finance_match_quality.csv\n")

# CS-DID panels, following the main scripts.
dt_aptos <- fread(file.path(DATA_DIR, "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(DATA_DIR, "locais_votacao_treatment_annual.csv"))
dt_chg <- fread(file.path(DATA_DIR, "loc_faction_changes.csv"))
dt_loc2t <- fread(file.path(DATA_DIR, "loc_to_territory.csv"))
dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]
dt_loc2t[, loc_id := as.character(loc_id)]
dt_loc2t[, territory_id := as.integer(territory_id)]

elec_years <- c(2008, 2012, 2016, 2020, 2024)
map_gvar <- function(g) {
  ifelse(g == 0 | is.na(g), 2008,
         sapply(g, function(x) {
           ey <- elec_years[elec_years >= x]
           if (length(ey) == 0) max(elec_years) else min(ey)
         }))
}
loc_gvar <- dt_treat[, .(gvar_raw = gvar[1]), by = loc_id]
loc_gvar[, gvar_cs := map_gvar(gvar_raw)]

loc_faction_spec <- dt_treat[inside_controle == 1,
  .(faction_specific = faction_type_controle[1]), by = loc_id]
loc_faction_spec[faction_specific %in% c("Milicia", "MilÃ­cia"),
                 faction_specific := "Militia"]
loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id", all.x = TRUE
)
loc_info <- merge(loc_info, dt_loc2t, by = "loc_id", all.x = TRUE)
loc_info <- merge(loc_info, loc_faction_spec, by = "loc_id", all.x = TRUE)

loc_fin[, loc_id := as.character(loc_id)]
loc_fin[, election_year := as.numeric(election_year)]
dt_faction <- merge(loc_fin,
                    loc_info[, .(loc_id, gvar_cs, change_type,
                                 faction_specific, territory_id)],
                    by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                    by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

faction_locs <- unique(loc_info$loc_id)
never_locs <- setdiff(unique(loc_fin$loc_id), faction_locs)
nt_info <- data.table(loc_id = never_locs, gvar_cs = 0L,
                      change_type = "never_treated",
                      faction_specific = NA_character_,
                      territory_id = NA_integer_)
loc_info_full <- rbind(loc_info[, .(loc_id, gvar_cs, change_type,
                                    faction_specific, territory_id)],
                       nt_info, fill = TRUE)
dt_full <- merge(loc_fin, loc_info_full, by = "loc_id")
dt_full <- merge(dt_full, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                 by = c("loc_id", "election_year"), all.x = TRUE)
dt_full <- dt_full[!is.na(qt_aptos) & qt_aptos > 0]

run_csdid <- function(d_run, outcome, lbl, ctrl_group) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]
  n_locs <- uniqueN(d$loc_id)
  n_cohorts <- uniqueN(d$gvar_cs)
  if (n_cohorts < 2 || n_locs < 20) {
    cat(sprintf("  %-65s SKIP\n", lbl))
    return(NULL)
  }

  tryCatch({
    att <- att_gt(
      yname = outcome,
      tname = "election_year",
      idname = "loc_num",
      gname = "gvar_cs",
      xformla = ~1,
      data = as.data.frame(d),
      base_period = "universal",
      control_group = ctrl_group,
      allow_unbalanced_panel = TRUE,
      weightsname = "qt_aptos",
      print_details = FALSE
    )
    agg <- aggte(att, type = "dynamic")
    p <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))
    cat(sprintf("  %-65s ATT=%+.4f p=%.3f N=%d\n",
                lbl, agg$overall.att, p, n_locs))
    list(
      overall = data.table(outcome = outcome, att = agg$overall.att,
                           se = agg$overall.se, p_value = p,
                           n_locs = n_locs, n_cohorts = n_cohorts),
      es = data.table(outcome = outcome, event_time = agg$egt,
                      att = agg$att.egt, se = agg$se.egt)
    )
  }, error = function(e) {
    cat(sprintf("  %-65s ERROR: %s\n", lbl, substr(e$message, 1, 70)))
    NULL
  })
}

outcomes <- c(
  "finance_vote_match_share",
  "expenses_vote_weighted",
  "revenue_vote_weighted",
  "expenses_per_vote_weighted",
  "high_expense_vote_share",
  "zero_expense_vote_share"
)
specs <- list(
  list(name = "Militia", filter_type = "stable_Militia"),
  list(name = "Drug", filter_type = "stable_Drug")
)
cargos <- c("Prefeito", "Vereador")

all_overall <- list()
all_es <- list()
for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$name))
  d_nyt <- dt_faction[change_type == sp$filter_type]
  d_nt <- dt_full[change_type == sp$filter_type | change_type == "never_treated"]
  for (cargo in cargos) {
    for (oc in outcomes) {
      r <- run_csdid(d_nyt[DS_CARGO == cargo], oc,
                     sprintf("%s / %s / %s [NYT]", sp$name, cargo, oc),
                     "notyettreated")
      if (!is.null(r)) {
        r$overall[, `:=`(spec = sp$name, cargo = cargo, estimator = "NYT")]
        r$es[, `:=`(spec = sp$name, cargo = cargo, estimator = "NYT")]
        all_overall[[length(all_overall) + 1]] <- r$overall
        all_es[[length(all_es) + 1]] <- r$es
      }
      r <- run_csdid(d_nt[DS_CARGO == cargo], oc,
                     sprintf("%s / %s / %s [NT]", sp$name, cargo, oc),
                     "nevertreated")
      if (!is.null(r)) {
        r$overall[, `:=`(spec = sp$name, cargo = cargo, estimator = "NT")]
        r$es[, `:=`(spec = sp$name, cargo = cargo, estimator = "NT")]
        all_overall[[length(all_overall) + 1]] <- r$overall
        all_es[[length(all_es) + 1]] <- r$es
      }
    }
  }
}

tab_overall <- rbindlist(all_overall, fill = TRUE)
tab_es <- rbindlist(all_es, fill = TRUE)
setcolorder(tab_overall, c("spec", "cargo", "estimator", "outcome"))
setcolorder(tab_es, c("spec", "cargo", "estimator", "outcome"))
fwrite(tab_overall, file.path(OUT_DIR, "tab94_campaign_finance_overall.csv"))
fwrite(tab_es, file.path(OUT_DIR, "tab94_campaign_finance_es.csv"))

cat("\nWrote results/tab94_campaign_finance_overall.csv\n")
cat("Wrote results/tab94_campaign_finance_es.csv\n")
cat("DONE - 94_campaign_finance_outcomes.R\n")
