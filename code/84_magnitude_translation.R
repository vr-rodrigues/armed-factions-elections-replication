# ============================================================================
# 84_magnitude_translation.R — Policy Magnitude Translation
# ============================================================================
#
# Referee B Concern 2 (MAJOR, binding for POLICY lens): "Is an ENC drop of
# 0.459 a big effect? I don't know, because I don't know if mean ENC in this
# sample is 2.0 or 8.0."
#
# This script produces three translations:
#   1. ATT / baseline-mean = percentage change
#   2. ATT / baseline-SD = effect size in SDs (Cohen's d-like)
#   3. Fraction of Brazilian 2020 mayoral races that the margin effect would
#      flip (using the full TSE distribution if available; otherwise the
#      metropolitan Rio sample distribution).
#
# Output:
#   tab84_magnitude_translation.csv
# ============================================================================

library(data.table)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("84_magnitude_translation.R\n")
cat("============================================================\n\n")

# Load Table 1 (main CS-DID estimates) + Table 0 (summary stats)
tab_cs <- fread(file.path(OUT_DIR, "tab70_main_overall.csv"))
sumstats <- fread(file.path(OUT_DIR, "tab83_sumstats_wide.csv"))

# NYT estimates (main specification)
cs_nyt <- tab_cs[estimator == "NYT", .(spec, cargo, outcome, att, se, p_value)]
cs_nyt[, spec := gsub("stable_", "", spec)]

# Baseline means by group (treated only; pre-treatment)
base_m <- sumstats[group == "militia_treated"]
base_d <- sumstats[group == "drug_treated"]

# Function to fetch baseline mean for a given outcome
get_base <- function(group_dt, cargo_target, outcome_target, stat = "mean") {
  oc_col <- paste0(outcome_target, "_", stat)
  val <- group_dt[cargo == cargo_target, get(oc_col)]
  if (length(val) == 0) NA_real_ else val
}

# Merge baseline stats
cs_nyt[, base_mean := mapply(function(s, c_, o) {
  if (s == "Militia") get_base(base_m, c_, o, "mean")
  else if (s == "Drug") get_base(base_d, c_, o, "mean")
  else NA_real_
}, spec, cargo, outcome)]

cs_nyt[, base_sd := mapply(function(s, c_, o) {
  if (s == "Militia") get_base(base_m, c_, o, "sd")
  else if (s == "Drug") get_base(base_d, c_, o, "sd")
  else NA_real_
}, spec, cargo, outcome)]

cs_nyt[, pct_change := 100 * att / base_mean]
cs_nyt[, effect_sd  := att / base_sd]

# ── 2. Fraction of Brazilian mayoral races the margin effect would flip ───
# For margin_victory at prefeito, what fraction of races have margin < |ATT|?
# Using the sample distribution of margin at treated militia stations
# pre-treatment (the most natural benchmark here).

dt_elec <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
dt_elec[, margin_victory := as.numeric(margin_victory)]
dt_elec[, loc_id := as.character(loc_id)]

dt_chg <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))
dt_chg[, loc_id := as.character(loc_id)]

# Distribution of margin at militia pre-treatment stations
pre_margin <- dt_elec[
  loc_id %in% dt_chg[change_type == "stable_Militia"]$loc_id &
  election_year == 2008 & DS_CARGO == "Prefeito"
]$margin_victory
pre_margin <- pre_margin[!is.na(pre_margin)]

militia_margin_att <- cs_nyt[spec == "Militia" & cargo == "Prefeito" &
                             outcome == "margin_victory", att]

frac_flipped <- if (length(militia_margin_att) > 0 && !is.na(militia_margin_att)) {
  mean(pre_margin < abs(militia_margin_att))
} else NA_real_

cat(sprintf("Militia/prefeito margin ATT: %+.4f\n", militia_margin_att))
cat(sprintf("Baseline margin mean:        %.4f\n", mean(pre_margin)))
cat(sprintf("Fraction of races with pre-treatment margin < |ATT|: %.1f%%\n",
            100 * frac_flipped))
cat("=> In this fraction of races, the militia effect would be sufficient to\n")
cat("   widen the margin beyond the pre-existing closest-runner-up gap.\n\n")

fwrite(cs_nyt, file.path(OUT_DIR, "tab84_magnitude_translation.csv"))

cat("Magnitude-translated results:\n")
print(cs_nyt[, .(spec, cargo, outcome, att, base_mean, pct_change, effect_sd)])

# ── 3. Paragraph-ready sentences for §5 ─────────────────────────────────────

cat("\n============================================================\n")
cat("READY-TO-PASTE SENTENCES FOR §5 (MAGNITUDES):\n")
cat("============================================================\n")

for (row_i in 1:nrow(cs_nyt)) {
  r <- cs_nyt[row_i]
  if (r$spec != "Militia" || r$cargo != "Prefeito") next
  if (is.na(r$pct_change)) next
  cat(sprintf("  %s: ATT=%+.3f on baseline %.3f = %+.1f%% of baseline (%.2f SD of the outcome).\n",
              r$outcome, r$att, r$base_mean, r$pct_change, r$effect_sd))
}

cat(sprintf("\n  Of militia-treated prefeito races in 2008, %.0f%% had a pre-\n",
            100 * frac_flipped))
cat(sprintf("  treatment margin below the estimated militia effect of %.1f pp.\n",
            100 * militia_margin_att))

cat("\nDONE — 84_magnitude_translation.R\n")


