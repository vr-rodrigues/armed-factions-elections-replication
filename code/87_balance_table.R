# ============================================================================
# 87_balance_table.R — Pre-treatment Covariate Balance: Treated vs NYT
# ============================================================================
#
# Referee B minor + Lens 3 M3: balance table is standard DiD deliverable;
# currently absent. This shows pre-period covariate balance between treated
# militia stations and the NYT militia control group (stations that become
# militia-controlled in later cohorts).
#
# Covariates:
#   - Pre-period (2008) HHI, ENC, margin
#   - qt_aptos (eligible voters — a rough demographic proxy)
#   - Total post-periods available (panel balance)
#
# Output:
#   tab87_balance_militia.csv, tab87_balance_drug.csv
# ============================================================================

library(data.table)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("87_balance_table.R — Pre-treatment balance treated vs NYT\n")
cat("============================================================\n\n")

dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

for (dd in list(dt_elec, dt_aptos, dt_treat, dt_chg))
  dd[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("hhi", "enc", "margin_victory"))
  dt_elec[, (col) := as.numeric(get(col))]
dt_aptos[, election_year := as.numeric(election_year)]
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

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

# For each station, extract 2008 values
base_prefeito <- dt_elec[election_year == 2008 & DS_CARGO == "Prefeito",
                         .(loc_id, hhi_p = hhi, enc_p = enc, margin_p = margin_victory)]
base_aptos   <- dt_aptos[election_year == 2008, .(loc_id, aptos_2008 = qt_aptos)]

d <- merge(loc_info, base_prefeito, by = "loc_id", all.x = TRUE)
d <- merge(d, base_aptos, by = "loc_id", all.x = TRUE)

# Define treated vs NYT for each faction type.
# "Treated" = stations treated in the first cohort of the faction (earliest g among spec).
# "NYT" = stations treated in a LATER cohort of the same faction.
# This matches the CS-DID NYT comparison for the first cohort's ATT.

do_balance <- function(d_sub, lbl) {
  cohorts <- sort(unique(d_sub$gvar_cs))
  # Drop 2008 already-treated (no pre-period)
  cohorts <- cohorts[cohorts > 2008]
  if (length(cohorts) < 2) return(NULL)

  earliest <- cohorts[1]
  d_sub[, group := ifelse(gvar_cs == earliest, "Treated",
                   ifelse(gvar_cs > earliest, "NYT", "already_treated"))]
  d_sub <- d_sub[group %in% c("Treated", "NYT")]

  # Mean and SD per group
  ss <- d_sub[, .(
    n = .N,
    hhi_mean = mean(hhi_p, na.rm = TRUE), hhi_sd = sd(hhi_p, na.rm = TRUE),
    enc_mean = mean(enc_p, na.rm = TRUE), enc_sd = sd(enc_p, na.rm = TRUE),
    margin_mean = mean(margin_p, na.rm = TRUE), margin_sd = sd(margin_p, na.rm = TRUE),
    aptos_mean = mean(aptos_2008, na.rm = TRUE), aptos_sd = sd(aptos_2008, na.rm = TRUE)
  ), by = group]

  # Normalized differences (Imbens-Wooldridge: |xbar_T - xbar_C| / sqrt((s2_T + s2_C)/2))
  t <- ss[group == "Treated"]; c_ <- ss[group == "NYT"]
  if (nrow(t) == 0 || nrow(c_) == 0) return(NULL)

  nd <- function(a, b, sa, sb) (a - b) / sqrt((sa^2 + sb^2) / 2)

  balance <- data.table(
    spec     = lbl,
    covariate = c("HHI", "ENC", "margin_victory", "aptos"),
    treated_mean = c(t$hhi_mean, t$enc_mean, t$margin_mean, t$aptos_mean),
    treated_sd   = c(t$hhi_sd, t$enc_sd, t$margin_sd, t$aptos_sd),
    nyt_mean     = c(c_$hhi_mean, c_$enc_mean, c_$margin_mean, c_$aptos_mean),
    nyt_sd       = c(c_$hhi_sd, c_$enc_sd, c_$margin_sd, c_$aptos_sd),
    n_treated    = t$n,
    n_nyt        = c_$n
  )
  balance[, norm_diff := nd(treated_mean, nyt_mean, treated_sd, nyt_sd)]
  balance
}

cat("--- Militia ---\n")
t_m <- do_balance(d[change_type == "stable_Militia"], "Militia")
print(t_m)

cat("\n--- Drug ---\n")
t_d <- do_balance(d[change_type == "stable_Drug"], "Drug")
print(t_d)

fwrite(t_m, file.path(OUT_DIR, "tab87_balance_militia.csv"))
fwrite(t_d, file.path(OUT_DIR, "tab87_balance_drug.csv"))

cat("\n============================================================\n")
cat("Imbens-Wooldridge rule-of-thumb: |norm_diff| < 0.25 = 'balanced'.\n")
cat("Values above 0.25 suggest systematic pre-treatment differences.\n")
cat("============================================================\n")


