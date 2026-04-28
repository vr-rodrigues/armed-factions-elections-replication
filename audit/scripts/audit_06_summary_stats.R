# =============================================================================
# audit_06_summary_stats.R
# Reproduce Table 1 (sumstats) baselines independently from raw data
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_06_summary_stats ===\n")

dt_elec  <- fread(file.path(BASE, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_aptos[, loc_id := as.character(loc_id)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]

elec_years <- c(2008, 2012, 2016, 2020, 2024)

# Build turnout - merge separately and add to electoral
dt_elec_t <- merge(dt_elec, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                   by = c("loc_id", "election_year"), all.x = TRUE)
dt_elec_t[, turnout := total_votes / qt_aptos]
dt_elec_t[is.na(turnout) | is.infinite(turnout) | turnout > 1 | turnout <= 0, turnout := NA_real_]
dt_elec[, turnout := dt_elec_t$turnout[match(paste(dt_elec$loc_id, dt_elec$election_year),
                                              paste(dt_elec_t$loc_id, dt_elec_t$election_year))]]

# gvar mapping (so we can pre-treatment filter)
map_gvar <- function(g) {
  ifelse(g == 0 | is.na(g), 2008,
         sapply(g, function(x) {
           ey <- elec_years[elec_years >= x]
           if (length(ey) == 0) max(elec_years) else min(ey)
         }))
}
loc_gvar <- dt_treat[, .(gvar_raw = gvar[1]), by = loc_id]
loc_gvar[, gvar_cs := map_gvar(gvar_raw)]
loc_gvar[, gvar_raw_first := loc_gvar$gvar_raw]

# Build group label MIRRORING script 89:
# - faction_locs = ONLY stable_Militia + stable_Drug (NOT switchers)
# - never_locs = all other loc_ids in dt_elec (includes switchers + others)
faction_dt <- dt_chg[change_type %in% c("stable_Militia", "stable_Drug")]
all_locs <- data.table(loc_id = unique(dt_elec$loc_id))
loc_lab <- merge(all_locs, faction_dt[, .(loc_id, change_type)], by = "loc_id", all.x = TRUE)
loc_lab[is.na(change_type), change_type := "never_treated"]

# Group mapping
loc_lab[, group := fcase(
  change_type == "never_treated",  "never_treated",
  change_type == "stable_Militia", "militia_treated",
  change_type == "stable_Drug",    "drug_treated"
)]

# Merge gvar for treated stations
loc_lab <- merge(loc_lab, loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id", all.x = TRUE)

# Election panel filtered to 5 elec_years AND qt_aptos > 0 (mirror script 83)
dp <- dt_elec[election_year %in% elec_years]
dp <- merge(dp, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dp <- dp[!is.na(qt_aptos) & qt_aptos > 0]
dp <- merge(dp, loc_lab[, .(loc_id, group, gvar_cs)], by = "loc_id", all.x = TRUE)

# Pre-treatment for treated: t < gvar_cs
# For never-treated: all 5 elections
dp_pre <- dp[
  group == "never_treated" |
  (group %in% c("militia_treated", "drug_treated") & election_year < gvar_cs)
]

# But the paper says "Station counts exclude stations whose first cohort is g=2008"
# (no pre-treatment observations available for those). So treated with gvar_cs == 2008 won't have pre-rows.

cat("Computing sumstats (mean, sd) for HHI/ENC/Margin/Turnout x Prefeito/Vereador x group\n")

compute_stats <- function(d, grp_col = "group") {
  res <- d[, .(
    n_obs = .N,
    n_stations = uniqueN(loc_id),
    hhi_mean = mean(hhi, na.rm = TRUE),
    hhi_sd   = sd(hhi, na.rm = TRUE),
    enc_mean = mean(enc, na.rm = TRUE),
    enc_sd   = sd(enc, na.rm = TRUE),
    margin_mean = mean(margin_victory, na.rm = TRUE),
    margin_sd   = sd(margin_victory, na.rm = TRUE),
    turnout_mean = mean(turnout, na.rm = TRUE),
    turnout_sd   = sd(turnout, na.rm = TRUE)
  ), by = .(group = get(grp_col), DS_CARGO)]
  res
}

stats <- compute_stats(dp_pre)
print(stats)
fwrite(stats, file.path(OUT, "audit_06_repro_sumstats.csv"))

# Compare to paper Table 1
paper <- data.table(
  group   = c("never_treated","militia_treated","drug_treated",
              "never_treated","militia_treated","drug_treated"),
  DS_CARGO = c("Prefeito","Prefeito","Prefeito","Vereador","Vereador","Vereador"),
  hhi_mean_p = c(0.374, 0.350, 0.384, 0.047, 0.048, 0.045),
  hhi_sd_p   = c(0.151, 0.153, 0.119, 0.047, 0.046, 0.029),
  enc_mean_p = c(3.151, 3.428, 2.913, 34.98, 32.17, 29.84),
  enc_sd_p   = c(1.303, 1.376, 1.057, 21.04, 18.79, 15.01),
  margin_mean_p = c(0.239, 0.207, 0.193, 0.061, 0.069, 0.049),
  margin_sd_p   = c(0.197, 0.185, 0.154, 0.080, 0.089, 0.055),
  turnout_mean_p = c(0.552, 0.523, 0.569, NA, NA, NA),
  turnout_sd_p   = c(0.197, 0.197, 0.205, NA, NA, NA),
  n_p = c(3789, 196, 70, 3789, 196, 70)
)
cmp <- merge(stats, paper, by = c("group", "DS_CARGO"), all = TRUE)
fwrite(cmp, file.path(OUT, "audit_06_compare.csv"))

cat("\n--- Summary stats compare ---\n")
for (i in seq_len(nrow(cmp))) {
  r <- cmp[i]
  cat(sprintf("\n%s / %s [n stations: paper=%s, repro=%s]\n",
              r$group, r$DS_CARGO,
              ifelse(is.na(r$n_p), "?", r$n_p),
              ifelse(is.na(r$n_stations), "?", r$n_stations)))
  for (oc in c("hhi","enc","margin","turnout")) {
    mp <- r[[paste0(oc, "_mean_p")]]
    sp <- r[[paste0(oc, "_sd_p")]]
    if (oc == "margin") {
      mc <- r$margin_mean; sc <- r$margin_sd
    } else if (oc == "turnout") {
      mc <- r$turnout_mean; sc <- r$turnout_sd
    } else {
      mc <- r[[paste0(oc, "_mean")]]; sc <- r[[paste0(oc, "_sd")]]
    }
    if (is.na(mp)) next
    md <- round(mc - mp, 3); sd_diff <- round(sc - sp, 3)
    flag <- ifelse(abs(md) > 0.005 | abs(sd_diff) > 0.005, "MISMATCH", "OK")
    cat(sprintf("  %-7s mean: paper=%.3f  repro=%.3f  [diff=%+.4f]  sd: paper=%.3f  repro=%.3f  [%s]\n",
                oc, mp, mc, mc - mp, sp, sc, flag))
  }
}

# Build findings
findings <- list()
for (i in seq_len(nrow(cmp))) {
  r <- cmp[i]
  for (oc in c("hhi","enc","margin","turnout")) {
    mp <- r[[paste0(oc, "_mean_p")]]
    if (is.na(mp)) next
    if (oc == "margin")  { mc <- r$margin_mean; sc <- r$margin_sd }
    else if (oc == "turnout") { mc <- r$turnout_mean; sc <- r$turnout_sd }
    else { mc <- r[[paste0(oc, "_mean")]]; sc <- r[[paste0(oc, "_sd")]] }
    sp <- r[[paste0(oc, "_sd_p")]]
    md <- mc - mp; sd_d <- sc - sp
    sev <- ifelse(abs(md) > 0.005 | (abs(sd_d) > 0.005 & !is.na(sd_d)), "HIGH", "OK")
    key <- sprintf("%s_%s_%s", r$group, r$DS_CARGO, oc)
    findings[[key]] <- list(
      mean_paper = mp, mean_repro = round(mc, 4), mean_diff = round(md, 4),
      sd_paper = sp, sd_repro = round(sc, 4), sd_diff = round(sd_d, 4),
      severity = sev
    )
  }
  # N stations
  if (!is.na(r$n_p)) {
    key <- sprintf("N_%s_%s", r$group, r$DS_CARGO)
    findings[[key]] <- list(
      reported = r$n_p, reproduced = r$n_stations, diff = r$n_stations - r$n_p,
      severity = ifelse(abs(r$n_stations - r$n_p) > 5, "CRITICAL", "OK")
    )
  }
}

write_json(list(test = "audit_06_summary_stats", findings = findings),
           file.path(OUT, "audit_06.json"), pretty = TRUE, auto_unbox = TRUE, na = "string")
cat("\nWrote audit_06.json\n")


