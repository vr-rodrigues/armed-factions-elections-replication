# ============================================================================
# 83_sumstats_baseline.R
# ============================================================================
#
# Builds pre-treatment descriptive statistics for the paper. The table covers
# the electoral-competition outcomes and the mechanism outcomes reported in the
# main text.
#
# Outputs:
#   results/tab83_sumstats_baseline.csv
#   results/tab83_sumstats_wide.csv
#   paper/tables/tab83_sumstats_baseline.tex
# ============================================================================

library(data.table)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                         value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
DATA_DIR <- file.path(BASE_DIR, "data")
OUT_DIR <- file.path(BASE_DIR, "results")
TAB_DIR <- file.path(BASE_DIR, "paper", "tables")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

cat("============================================================\n")
cat("83_sumstats_baseline.R\n")
cat("Pre-treatment descriptive statistics\n")
cat("============================================================\n\n")

to_title <- function(x) tools::toTitleCase(tolower(trimws(x)))

dt_elec <- fread(file.path(DATA_DIR, "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(DATA_DIR, "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(DATA_DIR, "locais_votacao_treatment_annual.csv"))
dt_chg <- fread(file.path(DATA_DIR, "loc_faction_changes.csv"))
dt_profile <- fread(file.path(DATA_DIR, "candidate_profile_by_location.csv"))
dt_finance <- fread(file.path(DATA_DIR, "campaign_finance_by_location.csv"))

for (dt in list(dt_elec, dt_aptos, dt_treat, dt_chg, dt_profile, dt_finance)) {
  dt[, loc_id := as.character(loc_id)]
}
for (dt in list(dt_elec, dt_profile, dt_finance)) {
  dt[, DS_CARGO := to_title(DS_CARGO)]
  dt[, election_year := as.integer(election_year)]
}
dt_aptos[, election_year := as.integer(election_year)]
dt_treat[, election_year := as.integer(election_year)]

numeric_cols <- c(
  "hhi", "enc", "margin_victory", "total_votes",
  "elected_vote_share", "n_competitive_candidates_1pct",
  "top_candidate_share", "top3_candidate_share",
  "share_public_admin_occupation",
  "expenses_vote_weighted", "revenue_vote_weighted",
  "expenses_per_vote_weighted", "high_expense_vote_share"
)

for (cc in intersect(numeric_cols, names(dt_elec))) dt_elec[, (cc) := as.numeric(get(cc))]
for (cc in intersect(numeric_cols, names(dt_profile))) dt_profile[, (cc) := as.numeric(get(cc))]
for (cc in intersect(numeric_cols, names(dt_finance))) dt_finance[, (cc) := as.numeric(get(cc))]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]

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

loc_faction <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)],
  by = "loc_id"
)

all_locs <- unique(dt_elec$loc_id)
faction_locs <- unique(loc_faction$loc_id)
broad_locs <- setdiff(all_locs, faction_locs)

loc_groups <- rbind(
  loc_faction[change_type == "stable_Militia",
              .(loc_id, group = "militia_treated", gvar_cs)],
  loc_faction[change_type == "stable_Drug",
              .(loc_id, group = "drug_treated", gvar_cs)],
  data.table(loc_id = broad_locs, group = "broad_control", gvar_cs = NA_real_)
)

d <- merge(dt_elec, loc_groups, by = "loc_id")
d <- merge(d, dt_aptos[, .(loc_id, election_year, qt_aptos)],
           by = c("loc_id", "election_year"), all.x = TRUE)
d <- merge(
  d,
  dt_profile[, .(loc_id, election_year, DS_CARGO,
                 elected_vote_share, n_competitive_candidates_1pct,
                 top_candidate_share, top3_candidate_share,
                 share_public_admin_occupation)],
  by = c("loc_id", "election_year", "DS_CARGO"),
  all.x = TRUE
)
d <- merge(
  d,
  dt_finance[, .(loc_id, election_year, DS_CARGO,
                 expenses_vote_weighted, revenue_vote_weighted,
                 expenses_per_vote_weighted, high_expense_vote_share)],
  by = c("loc_id", "election_year", "DS_CARGO"),
  all.x = TRUE
)

d <- d[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]
d[, turnout := total_votes / qt_aptos]
d[is.na(turnout) | is.infinite(turnout) | turnout <= 0 | turnout > 1,
  turnout := NA_real_]
d[, is_baseline := (group == "broad_control" | election_year < gvar_cs)]
d_base <- d[is_baseline == TRUE]

# Keep the descriptive table on a common station universe across mayoral and
# city-council races within each treatment group.
common_locs <- d_base[
  DS_CARGO %in% c("Prefeito", "Vereador") & !is.na(hhi),
  .(
    has_prefeito = any(DS_CARGO == "Prefeito"),
    has_vereador = any(DS_CARGO == "Vereador")
  ),
  by = .(group, loc_id)
][has_prefeito == TRUE & has_vereador == TRUE, .(group, loc_id)]
d_base <- merge(d_base, common_locs, by = c("group", "loc_id"))

outcome_specs <- data.table(
  panel = c(
    rep("Electoral competition", 3),
    "Participation",
    rep("Candidate selection", 5),
    rep("Campaign finance", 4)
  ),
  outcome = c(
    "hhi",
    "enc",
    "margin_victory",
    "turnout",
    "elected_vote_share",
    "n_competitive_candidates_1pct",
    "top_candidate_share",
    "top3_candidate_share",
    "share_public_admin_occupation",
    "expenses_vote_weighted",
    "revenue_vote_weighted",
    "expenses_per_vote_weighted",
    "high_expense_vote_share"
  ),
  label = c(
    "HHI",
    "ENC",
    "Margin of victory",
    "Turnout",
    "Winning candidate vote share",
    "Competitive candidates at 1 pp",
    "Top candidate vote share",
    "Top-3 candidates vote share",
    "Public-admin occupation share",
    "Expenses, vote-weighted (2024 BRL 100k)",
    "Revenue, vote-weighted (2024 BRL 100k)",
    "Expenses per vote (2024 BRL)",
    "High-spending vote share"
  ),
  scale = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1 / 100000, 1 / 100000, 1, 1),
  digits = c(3, 2, 3, 3, 3, 2, 3, 3, 3, 2, 2, 2, 3)
)
outcome_specs[, order := .I]

stats <- rbindlist(lapply(outcome_specs$outcome, function(oc) {
  d_base[, {
    vals <- get(oc)
    vals <- vals[!is.na(vals)]
    .(
      n_stations = uniqueN(loc_id),
      n_obs = .N,
      n_nonmissing = length(vals),
      mean = if (length(vals) == 0) NA_real_ else mean(vals),
      sd = if (length(vals) <= 1) NA_real_ else sd(vals),
      p25 = if (length(vals) == 0) NA_real_ else as.numeric(quantile(vals, 0.25)),
      p75 = if (length(vals) == 0) NA_real_ else as.numeric(quantile(vals, 0.75))
    )
  }, by = .(group, cargo = DS_CARGO)][, outcome := oc]
}), fill = TRUE)

stats <- merge(stats, outcome_specs, by = "outcome", all.x = TRUE)
setcolorder(stats, c("group", "cargo", "panel", "outcome", "label", "order",
                     "scale", "digits", "n_stations", "n_obs", "n_nonmissing",
                     "mean", "sd", "p25", "p75"))
setorder(stats, cargo, order, group)

# Turnout is a station-election participation measure, not a candidate-field
# outcome. Report it once with the mayoral panel to avoid duplicating it under
# city-council baselines.
stats <- stats[!(cargo == "Vereador" & outcome == "turnout")]

stats_export <- copy(stats)
for (cc in c("mean", "sd", "p25", "p75")) {
  stats_export[, (cc) := get(cc) * scale]
}
fwrite(stats_export, file.path(OUT_DIR, "tab83_sumstats_baseline.csv"))

wide <- dcast(
  stats_export,
  cargo + panel + outcome + label + order + scale + digits ~ group,
  value.var = c("mean", "sd", "n_nonmissing")
)
fwrite(wide, file.path(OUT_DIR, "tab83_sumstats_wide.csv"))

fmt_num <- function(x, digits) {
  if (is.na(x)) return("--")
  formatC(x, format = "f", digits = digits, big.mark = ",")
}

fmt_cell <- function(m, s, digits) {
  if (is.na(m)) return("--")
  sprintf("%s (%s)", fmt_num(m, digits), fmt_num(s, digits))
}

fmt_n <- function(x) formatC(x, format = "d", big.mark = ",")

group_order <- c("broad_control", "militia_treated", "drug_treated")
group_labels <- c(
  broad_control = "Broad control",
  militia_treated = "Militia (pre)",
  drug_treated = "Drug (pre)"
)

tex_rows_for_cargo <- function(cargo_value, panel_title) {
  s_cargo <- stats_export[cargo == cargo_value]
  n_by_group <- s_cargo[outcome == "hhi", .(n_stations = n_stations[1]), by = group]
  n_cells <- sapply(group_order, function(g) fmt_n(n_by_group[group == g, n_stations][1]))

  lines <- c(
    sprintf("\\multicolumn{4}{@{}l}{\\textit{%s}} \\\\", panel_title),
    sprintf("$N$ polling stations & %s & %s & %s \\\\", n_cells[1], n_cells[2], n_cells[3])
  )

  specs_this <- copy(outcome_specs)
  if (cargo_value == "Vereador")
    specs_this <- specs_this[outcome != "turnout"]

  current_panel <- NULL
  for (i in seq_len(nrow(specs_this))) {
    oc <- specs_this$outcome[i]
    sp <- specs_this[i]
    if (!identical(current_panel, sp$panel)) {
      lines <- c(lines, sprintf("\\addlinespace[2pt]\\multicolumn{4}{@{}l}{\\emph{%s}} \\\\", sp$panel))
      current_panel <- sp$panel
    }
    cells <- sapply(group_order, function(g) {
      row <- s_cargo[group == g & outcome == oc]
      fmt_cell(row$mean[1], row$sd[1], sp$digits)
    })
    lines <- c(lines, sprintf("%s & %s & %s & %s \\\\", sp$label, cells[1], cells[2], cells[3]))
  }
  lines
}

table_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\caption{Descriptive Statistics: Pre-Treatment Baselines}\\label{tab:sumstats}",
  "\\scriptsize",
  "\\begin{tabular}{@{}lccc@{}}",
  "\\toprule",
  sprintf(" & %s & %s & %s \\\\",
          group_labels["broad_control"],
          group_labels["militia_treated"],
          group_labels["drug_treated"]),
  "\\midrule",
  tex_rows_for_cargo("Prefeito", "Panel A: Prefeito (mayoral) races"),
  "\\addlinespace[4pt]",
  tex_rows_for_cargo("Vereador", "Panel B: Vereador (city-council) races"),
  "\\bottomrule",
  "\\end{tabular}",
  paste0("\\tabnotes{\\textit{Notes:} Cells report means and standard deviations in parentheses, ",
         "computed over baseline observations. For militia and drug-treated stations, the baseline sample ",
         "restricts to station-election observations before the first election year in faction territory. ",
         "For broad-control stations, all municipal elections are included. The descriptive table uses polling ",
         "stations observed in both mayoral and city-council baseline panels within each group. Turnout is reported ",
         "only in Panel A because it is a station-election participation measure rather than a candidate-field outcome. ",
         "Monetary values are deflated to ",
         "2024 reais using IPCA from BCB/SGS series 433. Vote shares, turnout, HHI, and the margin of victory ",
         "are reported on the 0--1 scale. Campaign-finance vote-weighted expenses and revenue are reported in ",
         "2024 BRL 100,000. Outcomes are defined in Table~\\ref{tab:outcomes}.}"),
  "\\end{table}"
)

writeLines(table_lines, file.path(TAB_DIR, "tab83_sumstats_baseline.tex"),
           useBytes = TRUE)

cat("Wrote results/tab83_sumstats_baseline.csv\n")
cat("Wrote results/tab83_sumstats_wide.csv\n")
cat("Wrote paper/tables/tab83_sumstats_baseline.tex\n")
cat("\nDONE - 83_sumstats_baseline.R\n")
