# ============================================================================
# 82_placebo_lagged.R — Placebo: do lagged outcomes predict treatment cohort?
# ============================================================================
#
# Referee A Concern 2 (MAJOR): "do militias expand preferentially into
# stations where a politically aligned population has become electorally
# vulnerable?" If yes, treatment timing is endogenous to electoral dynamics.
#
# Placebo test: regress treatment cohort g on lagged station-level electoral
# outcomes (HHI, ENC, margin of victory) at t-1, t-2, separately for militia
# and drug stations. If lagged outcomes do not systematically predict g at
# conventional levels, the identifying assumption is defended empirically.
#
# Output:
#   tab82_placebo_lagged.csv   — coefficient of each lagged outcome on cohort g
# ============================================================================

library(data.table)
library(fixest)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("82_placebo_lagged.R — lagged-outcome placebo on cohort\n")
cat("============================================================\n\n")

# Data
dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("hhi", "enc", "margin_victory"))
  dt_elec[, (col) := as.numeric(get(col))]
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

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

# Pre-treatment outcomes at each station (baseline = 2008)
dt_baseline <- dt_elec[election_year == 2008 & DS_CARGO == "Prefeito"]

# Merge: station → cohort + 2008 baseline outcomes
d <- merge(
  loc_info[, .(loc_id, gvar_cs, change_type)],
  dt_baseline[, .(loc_id, hhi_2008 = hhi, enc_2008 = enc, margin_2008 = margin_victory)],
  by = "loc_id"
)

# Keep only stations with non-missing 2008 baseline and with gvar_cs > 2008
# (cohort at baseline year = excluded because no meaningful pre-treatment)
d <- d[!is.na(hhi_2008) & !is.na(enc_2008) & !is.na(margin_2008)]
d <- d[gvar_cs > 2008]  # drop already-treated-in-2008

cat(sprintf("Placebo sample: %d stations (militia: %d | drug: %d)\n",
            nrow(d), sum(d$change_type == "stable_Militia"),
            sum(d$change_type == "stable_Drug")))

# Regressions: cohort g on pre-treatment outcomes, separately by faction type
run_placebo <- function(d_sub, lbl) {
  d_sub <- copy(d_sub)
  d_sub[, g_num := as.numeric(gvar_cs)]

  results <- list()
  for (var in c("hhi_2008", "enc_2008", "margin_2008")) {
    m <- lm(as.formula(sprintf("g_num ~ %s", var)), data = d_sub)
    co <- summary(m)$coefficients
    if (nrow(co) < 2) next
    results[[var]] <- data.table(
      spec = lbl, outcome_lagged = var,
      coef = co[2, 1], se = co[2, 2], p = co[2, 4], n = nrow(d_sub)
    )
    cat(sprintf("  %s %-12s coef=%+.3f (SE %.3f) p=%.3f\n",
                lbl, var, co[2, 1], co[2, 2], co[2, 4]))
  }
  rbindlist(results)
}

cat("\n--- Militia cohort ~ 2008 baseline outcomes ---\n")
t_m <- run_placebo(d[change_type == "stable_Militia"], "Militia")

cat("\n--- Drug cohort ~ 2008 baseline outcomes ---\n")
t_d <- run_placebo(d[change_type == "stable_Drug"], "Drug")

# Joint F-test: cohort g regressed on all three 2008 outcomes
cat("\n--- Joint F-test: cohort g ~ all 2008 outcomes ---\n")
run_joint <- function(d_sub, lbl) {
  m_full <- lm(as.numeric(gvar_cs) ~ hhi_2008 + enc_2008 + margin_2008, data = d_sub)
  m_null <- lm(as.numeric(gvar_cs) ~ 1, data = d_sub)
  a <- anova(m_null, m_full)
  cat(sprintf("  %s F=%.3f p=%.4f\n", lbl, a$F[2], a$`Pr(>F)`[2]))
  data.table(spec = lbl, outcome_lagged = "joint", coef = NA_real_, se = NA_real_,
             p = a$`Pr(>F)`[2], n = nrow(d_sub), f_stat = a$F[2])
}
j_m <- run_joint(d[change_type == "stable_Militia"], "Militia")
j_d <- run_joint(d[change_type == "stable_Drug"], "Drug")

tab_out <- rbind(t_m, t_d, j_m, j_d, fill = TRUE)
fwrite(tab_out, file.path(OUT_DIR, "tab82_placebo_lagged.csv"))

cat("\n============================================================\n")
cat("Interpretation: if p-values above exceed conventional levels,\n")
cat("2008 baseline electoral outcomes do NOT predict the timing of\n")
cat("faction territorial entry, supporting conditional exogeneity.\n")
cat("============================================================\n")


