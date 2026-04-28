# ============================================================================
# 83_sumstats_baseline.R — Table 0: Baseline Summary Statistics by Group
# ============================================================================
#
# Referee B Concern 2 (MAJOR): magnitudes cannot be calibrated without
# sample means. This script builds the summary-statistics table that the
# current manuscript is missing.
#
# Rows: HHI, ENC, margin_victory × {Prefeito, Vereador}
# Cols: mean and SD, separately for:
#       - militia-treated (stable_Militia, pre-treatment baseline = 2008)
#       - drug-treated (stable_Drug, pre-treatment baseline = 2008)
#       - NYT militia (militia stations treated later than observation year)
#       - NYT drug
#       - never-treated (NT)
#
# Output:
#   tab83_sumstats_baseline.csv  — long-format table
#   tab83_sumstats_wide.csv      — wide-format for LaTeX
# ============================================================================

library(data.table)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("83_sumstats_baseline.R — Table 0 of descriptive stats\n")
cat("============================================================\n\n")

# Data
dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("hhi", "enc", "margin_victory"))
  dt_elec[, (col) := as.numeric(get(col))]
dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]

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
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

# Build group labels for each station
all_locs <- unique(dt_elec$loc_id)
faction_locs <- unique(loc_faction$loc_id)
never_locs <- setdiff(all_locs, faction_locs)

# Data frame with one row per station × group
loc_groups <- rbind(
  loc_faction[change_type == "stable_Militia",
              .(loc_id, group = "militia_treated", gvar_cs)],
  loc_faction[change_type == "stable_Drug",
              .(loc_id, group = "drug_treated", gvar_cs)],
  data.table(loc_id = never_locs, group = "never_treated", gvar_cs = NA_real_)
)

# Merge with outcomes
d <- merge(dt_elec, loc_groups, by = "loc_id")
d <- merge(d, dt_aptos[, .(loc_id, election_year, qt_aptos)],
           by = c("loc_id", "election_year"), all.x = TRUE)
d <- d[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]

# Baseline observation: t < g for treated (pre-treatment), any year for NT
d[, is_baseline := (group == "never_treated" | election_year < gvar_cs)]
d_base <- d[is_baseline == TRUE]

# ── Summary statistics by group × cargo × outcome ──────────────────────────

outcomes <- c("hhi", "enc", "margin_victory")
outcome_labels <- c(hhi = "HHI", enc = "ENC", margin_victory = "Margin of Victory")
cargos <- c("Prefeito", "Vereador")

stats <- d_base[, {
  lst <- list(n_stations = uniqueN(loc_id), n_obs = .N)
  for (oc in outcomes) {
    vals <- get(oc)
    vals <- vals[!is.na(vals)]
    lst[[paste0(oc, "_mean")]] <- mean(vals)
    lst[[paste0(oc, "_sd")]]   <- sd(vals)
    lst[[paste0(oc, "_p25")]]  <- quantile(vals, 0.25)
    lst[[paste0(oc, "_p75")]]  <- quantile(vals, 0.75)
  }
  lst
}, by = .(group, cargo = DS_CARGO)]

fwrite(stats, file.path(OUT_DIR, "tab83_sumstats_wide.csv"))

cat("Summary statistics (baseline / pre-treatment):\n\n")
print(stats[cargo == "Prefeito", .(group, cargo, n_stations,
                                   hhi_mean, hhi_sd, enc_mean, enc_sd,
                                   margin_victory_mean, margin_victory_sd)])

cat("\n")
print(stats[cargo == "Vereador", .(group, cargo, n_stations,
                                   hhi_mean, hhi_sd, enc_mean, enc_sd,
                                   margin_victory_mean, margin_victory_sd)])

# Long-format (more readable)
long <- melt(stats, id.vars = c("group", "cargo", "n_stations", "n_obs"),
             variable.name = "stat", value.name = "val")
fwrite(long, file.path(OUT_DIR, "tab83_sumstats_baseline.csv"))

cat("\n============================================================\n")
cat("Done. Use tab83 in the paper's Table 0.\n")
cat("============================================================\n")


