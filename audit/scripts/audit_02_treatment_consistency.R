# =============================================================================
# audit_02_treatment_consistency.R
# Cross-reference treatment definitions across loc_faction_changes,
# locais_votacao_treatment_annual, and the implicit filter in tab89.
# Sanity: 398 stable_Militia + 240 stable_Drug treated should drop to a slightly
# smaller subset by the regression (need valid Prefeito + qt_aptos > 0).
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_02_treatment_consistency ===\n")

dt_elec  <- fread(file.path(BASE, "data", "electoral_competition_measures.csv"))
dt_treat <- fread(file.path(BASE, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE, "data", "loc_faction_changes.csv"))
dt_aptos <- fread(file.path(BASE, "data", "qt_aptos_by_location.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]
dt_aptos[, loc_id := as.character(loc_id)]

findings <- list()

# Effective N after the same filters as 89_dynamic_agg_all.R uses for NYT
elec_years <- c(2008, 2012, 2016, 2020, 2024)

dt_elec_m <- merge(
  dt_elec[election_year %in% elec_years & DS_CARGO == "Prefeito"],
  dt_aptos[, .(loc_id, election_year, qt_aptos)], by = c("loc_id", "election_year"), all.x = TRUE
)

# Apply station filter as run_cs would
dt_elec_m <- dt_elec_m[!is.na(qt_aptos) & qt_aptos > 0]

# Stable-militia treated stations with at least one valid Prefeito obs after filter
sm_locs <- intersect(dt_chg[change_type == "stable_Militia"]$loc_id, dt_elec_m[!is.na(hhi)]$loc_id)
sd_locs <- intersect(dt_chg[change_type == "stable_Drug"]$loc_id,    dt_elec_m[!is.na(hhi)]$loc_id)

n_sm_eff <- length(sm_locs)
n_sd_eff <- length(sd_locs)

cat(sprintf("Effective stable_Militia treated (Prefeito + qt_aptos): %d\n", n_sm_eff))
cat(sprintf("Effective stable_Drug    treated (Prefeito + qt_aptos): %d\n", n_sd_eff))

findings[["effective_militia_count"]] <- list(
  reported = 398, reproduced = n_sm_eff, diff = n_sm_eff - 398, severity = "CRITICAL",
  desc = "Effective stable_Militia treated count after filters (paper Section 3 + Table 4: 398)"
)
findings[["effective_drug_count"]] <- list(
  reported = 240, reproduced = n_sd_eff, diff = n_sd_eff - 240, severity = "CRITICAL",
  desc = "Effective stable_Drug treated count after filters (paper Section 3 + Table 4: 240)"
)

# Vereador effective counts
dt_elec_v <- merge(
  dt_elec[election_year %in% elec_years & DS_CARGO == "Vereador"],
  dt_aptos[, .(loc_id, election_year, qt_aptos)], by = c("loc_id", "election_year"), all.x = TRUE
)
dt_elec_v <- dt_elec_v[!is.na(qt_aptos) & qt_aptos > 0]
sm_locs_v <- intersect(dt_chg[change_type == "stable_Militia"]$loc_id, dt_elec_v[!is.na(hhi)]$loc_id)
sd_locs_v <- intersect(dt_chg[change_type == "stable_Drug"]$loc_id,    dt_elec_v[!is.na(hhi)]$loc_id)

cat(sprintf("Effective stable_Militia treated Vereador: %d\n", length(sm_locs_v)))
cat(sprintf("Effective stable_Drug    treated Vereador: %d\n", length(sd_locs_v)))

findings[["effective_militia_vereador"]] <- list(
  reported = 398, reproduced = length(sm_locs_v), diff = length(sm_locs_v) - 398,
  severity = "HIGH", desc = "Stable Militia treated count for Vereador panel (Table 5: 398)"
)
findings[["effective_drug_vereador"]] <- list(
  reported = 240, reproduced = length(sd_locs_v), diff = length(sd_locs_v) - 240,
  severity = "HIGH", desc = "Stable Drug treated count for Vereador panel (Table 5: 240)"
)

# Cohort distribution from gvar_cs
loc_gvar <- dt_treat[, .(gvar_raw = gvar[1]), by = loc_id]
map_gvar <- function(g) {
  ifelse(g == 0 | is.na(g), 2008,
         sapply(g, function(x) {
           ey <- elec_years[elec_years >= x]
           if (length(ey) == 0) max(elec_years) else min(ey)
         }))
}
loc_gvar[, gvar_cs := map_gvar(gvar_raw)]
loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

cat("\nCohort distribution (gvar_cs) for treated stations:\n")
print(loc_info[, .N, by = .(change_type, gvar_cs)][order(change_type, gvar_cs)])

# Save merged loc_info for downstream debugging
fwrite(loc_info, file.path(OUT, "loc_info_treated.csv"))

res <- list(test = "audit_02_treatment_consistency", findings = findings,
            cohort_table = loc_info[, .N, by = .(change_type, gvar_cs)][order(change_type, gvar_cs)])
write_json(res, file.path(OUT, "audit_02.json"), pretty = TRUE, auto_unbox = TRUE)
cat("\nWrote audit_02.json\n")


