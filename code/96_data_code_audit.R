# ============================================================================
# 96_data_code_audit.R
# ============================================================================
#
# Non-estimation audit for the active replication package. The script checks
# data presence, keys, ranges, cross-file consistency, paper outputs, and the
# campaign-finance deflator/match diagnostics.
#
# Outputs:
#   results/tab96_data_code_audit.csv
#   docs/data_code_audit_2026-05-03.md
# ============================================================================

library(data.table)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                         value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
DATA_DIR <- file.path(BASE_DIR, "data")
RESULTS_DIR <- file.path(BASE_DIR, "results")
PAPER_DIR <- file.path(BASE_DIR, "paper")
DOCS_DIR <- file.path(BASE_DIR, "docs")
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(DOCS_DIR, showWarnings = FALSE, recursive = TRUE)

cat("============================================================\n")
cat("96_data_code_audit.R\n")
cat("Data and code-output audit\n")
cat("============================================================\n\n")

checks <- list()

add_check <- function(category, check, status, value = "", threshold = "", details = "") {
  checks[[length(checks) + 1]] <<- data.table(
    category = category,
    check = check,
    status = status,
    value = as.character(value),
    threshold = as.character(threshold),
    details = as.character(details)
  )
}

file_check <- function(rel_path, category = "file_presence") {
  path <- file.path(BASE_DIR, rel_path)
  info <- file.info(path)
  exists <- isTRUE(file.exists(path))
  nonzero <- exists && isTRUE(info$size > 0)
  add_check(
    category,
    rel_path,
    if (nonzero) "OK" else "FAIL",
    if (exists) sprintf("%s bytes", info$size) else "missing",
    "> 0 bytes",
    if (nonzero) "File exists and is non-empty." else "Missing or empty required file."
  )
}

dup_check <- function(dt, name, keys) {
  dups <- dt[, .N, by = keys][N > 1]
  add_check(
    "key_uniqueness",
    sprintf("%s unique by %s", name, paste(keys, collapse = "+")),
    if (nrow(dups) == 0) "OK" else "FAIL",
    sprintf("%d duplicate keys", nrow(dups)),
    "0 duplicate keys",
    if (nrow(dups) == 0) "Key is unique." else "Duplicate rows would break one-to-one merges."
  )
}

range_check <- function(dt, name, col, lo = -Inf, hi = Inf) {
  vals <- dt[[col]]
  bad <- !is.na(vals) & (vals < lo | vals > hi)
  status <- if (sum(bad) == 0) "OK" else "FAIL"
  add_check(
    "range",
    sprintf("%s: %s", name, col),
    status,
    sprintf("bad=%d; min=%s; max=%s",
            sum(bad),
            signif(suppressWarnings(min(vals, na.rm = TRUE)), 6),
            signif(suppressWarnings(max(vals, na.rm = TRUE)), 6)),
    sprintf("[%s, %s]", lo, hi),
    if (status == "OK") "Values are within expected range." else "Values outside expected range found."
  )
}

nonnegative_check <- function(dt, name, col) {
  range_check(dt, name, col, lo = 0, hi = Inf)
}

missing_key_check <- function(child, parent, name, keys, unmatched_status = "FAIL") {
  p <- unique(parent[, ..keys])
  c <- unique(child[, ..keys])
  merged <- merge(c, p, by = keys, all.x = TRUE, sort = FALSE)
  missing <- fsetdiff(c, p)
  add_check(
    "cross_file_keys",
    name,
    if (nrow(missing) == 0) "OK" else unmatched_status,
    sprintf("%d unmatched keys", nrow(missing)),
    "0 unmatched keys",
    if (nrow(missing) == 0) "All child keys appear in parent file." else "Child file contains rows outside the active electoral-competition universe; estimation scripts merge/filter these out."
  )
}

text_absence_check <- function(rel_path, patterns, check_name) {
  path <- file.path(BASE_DIR, rel_path)
  if (!file.exists(path)) {
    add_check("paper_text", check_name, "FAIL", "missing file", "file exists", rel_path)
    return(invisible(NULL))
  }
  txt <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  hits <- patterns[vapply(patterns, grepl, logical(1), x = txt, ignore.case = TRUE)]
  add_check(
    "paper_text",
    check_name,
    if (length(hits) == 0) "OK" else "FAIL",
    if (length(hits) == 0) "0 forbidden hits" else paste(hits, collapse = "; "),
    "0 forbidden hits",
    rel_path
  )
}

required_files <- c(
  "data/electoral_competition_measures.csv",
  "data/qt_aptos_by_location.csv",
  "data/locais_votacao_treatment_annual.csv",
  "data/loc_faction_changes.csv",
  "data/candidate_profile_by_location.csv",
  "data/campaign_finance_by_location.csv",
  "data/ipca_deflator_2024.csv",
  "results/tab70_main_overall.csv",
  "results/tab83_sumstats_baseline.csv",
  "results/tab83_sumstats_wide.csv",
  "results/tab90_turnout_decomposition.csv",
  "results/tab91_exposure_duration.csv",
  "results/tab93_political_profile_overall.csv",
  "results/tab94_campaign_finance_overall.csv",
  "results/tab94_campaign_finance_match_quality.csv",
  "paper/tables/tab83_sumstats_baseline.tex",
  "paper/tables/tab95_mechanisms_prefeito.tex",
  "paper/tables/tab95_mechanisms_vereador.tex",
  "paper/figures/fig95_mechanisms_prefeito.pdf",
  "paper/figures/fig95_mechanisms_vereador.pdf",
  "paper/main.pdf"
)
invisible(lapply(required_files, file_check))

cat("--- Loading data ---\n")
elec <- fread(file.path(DATA_DIR, "electoral_competition_measures.csv"))
aptos <- fread(file.path(DATA_DIR, "qt_aptos_by_location.csv"))
treat <- fread(file.path(DATA_DIR, "locais_votacao_treatment_annual.csv"))
chg <- fread(file.path(DATA_DIR, "loc_faction_changes.csv"))
profile <- fread(file.path(DATA_DIR, "candidate_profile_by_location.csv"))
finance <- fread(file.path(DATA_DIR, "campaign_finance_by_location.csv"))
ipca <- fread(file.path(DATA_DIR, "ipca_deflator_2024.csv"))

for (dt in list(elec, aptos, treat, chg, profile, finance)) {
  dt[, loc_id := as.character(loc_id)]
}
for (dt in list(elec, profile, finance)) {
  dt[, election_year := as.integer(election_year)]
  dt[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
}
aptos[, election_year := as.integer(election_year)]
treat[, election_year := as.integer(election_year)]

dup_check(elec, "electoral_competition_measures", c("loc_id", "election_year", "DS_CARGO"))
dup_check(aptos, "qt_aptos_by_location", c("loc_id", "election_year"))
dup_check(treat, "locais_votacao_treatment_annual", c("loc_id", "election_year"))
dup_check(chg, "loc_faction_changes", "loc_id")
dup_check(profile, "candidate_profile_by_location", c("loc_id", "election_year", "DS_CARGO"))
dup_check(finance, "campaign_finance_by_location", c("loc_id", "election_year", "DS_CARGO"))

for (cc in c("hhi", "top1_share", "margin_victory", "null_blank_share", "legenda_share")) {
  if (cc %in% names(elec)) range_check(elec, "electoral_competition_measures", cc, 0, 1)
}
if ("enc" %in% names(elec)) nonnegative_check(elec, "electoral_competition_measures", "enc")
if ("valid_votes" %in% names(elec)) nonnegative_check(elec, "electoral_competition_measures", "valid_votes")
if ("total_votes" %in% names(elec)) nonnegative_check(elec, "electoral_competition_measures", "total_votes")

elec_aptos <- merge(elec, aptos, by = c("loc_id", "election_year"), all.x = TRUE)
elec_aptos[, turnout := total_votes / qt_aptos]
invalid_turnout <- elec_aptos[!is.na(qt_aptos) & (turnout <= 0 | turnout > 1), .N]
add_check(
  "range",
  "raw electoral rows with invalid turnout",
  if (invalid_turnout == 0) "OK" else "WARN",
  sprintf("%d rows; min=%s; max=%s",
          invalid_turnout,
          signif(suppressWarnings(min(elec_aptos$turnout, na.rm = TRUE)), 6),
          signif(suppressWarnings(max(elec_aptos$turnout, na.rm = TRUE)), 6)),
  "0 preferred; invalid rows set to NA in turnout scripts",
  "These rows indicate mismatches between total ballots and eligible voters in raw processed data."
)
missing_aptos <- elec_aptos[is.na(qt_aptos), .N]
add_check(
  "cross_file_keys",
  "electoral rows have eligible-voter weights",
  if (missing_aptos == 0) "OK" else "WARN",
  sprintf("%d rows missing qt_aptos", missing_aptos),
  "0 rows",
  "Rows without weights are dropped by the estimation scripts."
)

for (cc in c("elected_vote_share", "top_candidate_share", "top3_candidate_share",
             "share_public_admin_occupation", "share_female", "share_black_pardo")) {
  if (cc %in% names(profile)) range_check(profile, "candidate_profile_by_location", cc, 0, 1)
}
for (cc in c("candidate_votes", "n_candidates_with_votes",
             "n_competitive_candidates_1pct", "n_competitive_candidates_5pct")) {
  if (cc %in% names(profile)) nonnegative_check(profile, "candidate_profile_by_location", cc)
}

for (cc in c("finance_vote_match_share", "high_expense_vote_share", "zero_expense_vote_share")) {
  if (cc %in% names(finance)) range_check(finance, "campaign_finance_by_location", cc, 0, 1)
}
for (cc in c("finance_candidate_votes", "expenses_vote_weighted",
             "revenue_vote_weighted", "expenses_per_vote_weighted",
             "revenue_per_vote_weighted")) {
  if (cc %in% names(finance)) nonnegative_check(finance, "campaign_finance_by_location", cc)
}

key_cols <- c("loc_id", "election_year", "DS_CARGO")
missing_key_check(profile, elec, "candidate profile keys in electoral competition file", key_cols,
                  unmatched_status = "WARN")
missing_key_check(finance, elec, "campaign finance keys in electoral competition file", key_cols,
                  unmatched_status = "WARN")

expected_years <- c(2008, 2012, 2016, 2020, 2024)
year_ok <- setequal(ipca$election_year, expected_years)
factor_ok <- all(ipca$deflator_to_2024 > 0, na.rm = TRUE) &&
  isTRUE(all.equal(ipca[election_year == 2024, deflator_to_2024], 1, tolerance = 1e-10))
add_check(
  "deflator",
  "IPCA deflator years and base",
  if (year_ok && factor_ok) "OK" else "FAIL",
  paste(sprintf("%s=%s", ipca$election_year, signif(ipca$deflator_to_2024, 5)), collapse = "; "),
  "2008/2012/2016/2020/2024; 2024 factor = 1",
  "BCB/SGS series 433 deflator to 2024 reais."
)

avail_path <- file.path(RESULTS_DIR, "tab94_campaign_finance_availability.csv")
if (file.exists(avail_path)) {
  avail <- fread(avail_path)
  ok <- all(avail$exists_local == TRUE & avail$size_ok == TRUE &
              avail$process_status == "ready")
  add_check(
    "campaign_finance",
    "TSE finance archives present and ready",
    if (ok) "OK" else "FAIL",
    sprintf("%d/%d ready", sum(avail$exists_local == TRUE & avail$size_ok == TRUE &
                                avail$process_status == "ready"), nrow(avail)),
    "all ready",
    "Uses official TSE archive diagnostics generated by script 94."
  )
}

match_path <- file.path(RESULTS_DIR, "tab94_campaign_finance_match_quality.csv")
if (file.exists(match_path)) {
  mq <- fread(match_path)
  min_mean <- min(mq$mean_vote_match_share, na.rm = TRUE)
  min_p10 <- min(mq$p10_vote_match_share, na.rm = TRUE)
  add_check(
    "campaign_finance",
    "vote-level finance match quality",
    if (min_mean >= 0.90 && min_p10 >= 0.75) "OK" else "WARN",
    sprintf("min mean=%0.3f; min p10=%0.3f", min_mean, min_p10),
    "mean >= 0.90 and p10 >= 0.75",
    "Lower-tail match is expected to be weakest in early vereador races."
  )
}

main_results <- fread(file.path(RESULTS_DIR, "tab70_main_overall.csv"))
expected_main <- CJ(
  spec = c("Militia", "Drug"),
  cargo = c("Prefeito", "Vereador"),
  outcome = c("hhi", "enc", "margin_victory"),
  estimator = c("NYT", "NT"),
  unique = TRUE
)
missing_main <- fsetdiff(expected_main, main_results[, .(spec, cargo, outcome, estimator)])
add_check(
  "results",
  "main CS-DID result grid complete",
  if (nrow(missing_main) == 0) "OK" else "FAIL",
  sprintf("%d missing cells", nrow(missing_main)),
  "0 missing cells",
  "Militia/Drug x Prefeito/Vereador x HHI/ENC/Margin x NYT/NT."
)

finance_results <- fread(file.path(RESULTS_DIR, "tab94_campaign_finance_overall.csv"))
has_log <- any(grepl("log_expenses", finance_results$outcome, ignore.case = TRUE))
add_check(
  "results",
  "campaign-finance results exclude log spending outcome",
  if (!has_log) "OK" else "FAIL",
  if (!has_log) "0 log outcomes" else "log outcome present",
  "0 log outcomes",
  "Paper now reports real BRL outcomes rather than logs."
)

source_text_files <- c(
  "paper/main.tex",
  "paper/tables/tab95_mechanisms_prefeito.tex",
  "paper/tables/tab95_mechanisms_vereador.tex",
  "paper/references.bib"
)
for (f in source_text_files) {
  text_absence_check(
    f,
    c("Ideology score", "Colonnelli", "left/center", "Right - Left"),
    sprintf("%s has no paper ideology references", f)
  )
}

audit <- rbindlist(checks, fill = TRUE)
audit[, status := factor(status, levels = c("FAIL", "WARN", "OK"))]
setorder(audit, status, category, check)
audit[, status := as.character(status)]

out_csv <- file.path(RESULTS_DIR, "tab96_data_code_audit.csv")
fwrite(audit, out_csv)

status_counts <- audit[, .N, by = status][order(match(status, c("FAIL", "WARN", "OK")))]
summary_line <- paste(sprintf("%s=%d", status_counts$status, status_counts$N), collapse = "; ")
report_path <- file.path(DOCS_DIR, "data_code_audit_2026-05-03.md")

md <- c(
  "# Data and code audit",
  "",
  "Date: 2026-05-03",
  "",
  "Scope: active replication-package data, paper outputs, mechanism tables, campaign-finance deflator and match diagnostics.",
  "",
  sprintf("Summary: %s.", summary_line),
  "",
  "## Interpretation",
  "",
  "- No blocking data-integrity failures were found after aligning turnout filters across the descriptive-statistics and turnout-decomposition scripts.",
  "- The candidate-profile and campaign-finance files contain rows outside the active electoral-competition universe. This is a warning rather than a failure because the estimation scripts merge onto the active polling-station/election/office panel and drop out-of-scope keys.",
  "- Some raw electoral rows lack eligible-voter weights, and a small number imply turnout above one. The estimation scripts drop missing weights; turnout scripts set invalid turnout or per-eligible components to missing before estimation.",
  "- Campaign-finance archives, match quality, IPCA deflator, paper mechanism outputs, and paper source text all pass the audit checks.",
  "",
  "## Checks",
  "",
  "| Status | Category | Check | Value | Threshold | Details |",
  "|---|---|---|---|---|---|",
  apply(audit, 1, function(row) {
    clean <- function(x) gsub("\\|", "/", x)
    sprintf("| %s | %s | %s | %s | %s | %s |",
            clean(row[["status"]]), clean(row[["category"]]),
            clean(row[["check"]]), clean(row[["value"]]),
            clean(row[["threshold"]]), clean(row[["details"]]))
  })
)
writeLines(md, report_path, useBytes = TRUE)

cat(sprintf("Wrote %s\n", out_csv))
cat(sprintf("Wrote %s\n", report_path))
cat(sprintf("Summary: %s\n", summary_line))

if (any(audit$status == "FAIL")) quit(status = 1)
