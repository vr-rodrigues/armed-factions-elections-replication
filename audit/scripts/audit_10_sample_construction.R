# =============================================================================
# audit_10_sample_construction.R
# Appendix C cross-check: 4654 unique, 4180 with coords, 712 ever-treated,
# 401 stable Militia, 246 stable Drug, 40+25 switchers, 3468 NT base,
# distribution panel 1740/1158/702/371/370. Plus 18 polygon vintages.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_10_sample_construction ===\n")

dt_treat <- fread(file.path(BASE, "data", "locais_votacao_treatment_annual.csv"))
dt_treat[, loc_id := as.character(loc_id)]
dt_chg <- fread(file.path(BASE, "data", "loc_faction_changes.csv"))
dt_chg[, loc_id := as.character(loc_id)]
dt_elec <- fread(file.path(BASE, "data", "electoral_competition_measures.csv"))
dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]

findings <- list()

# 1. Master roster: 4180 with coords. The paper claim of 4,654 "union" should be
# verifiable from the full TSE roster. We don't have the unfiltered roster as a
# CSV; treatment_annual is already restricted to coords. Check if the geocode
# script artifacts are present.
locais_metro <- file.path(BASE, "data", "locais_votacao_metro_rj.csv")
if (file.exists(locais_metro)) {
  lm <- fread(locais_metro)
  cat(sprintf("locais_votacao_metro_rj.csv rows: %d\n", nrow(lm)))
  cat(sprintf("Unique loc_id: %d\n", uniqueN(lm$loc_id)))
  if ("lat" %in% names(lm)) {
    n_with <- uniqueN(lm[!is.na(lat) & !is.na(lon)]$loc_id)
    n_no   <- uniqueN(lm[is.na(lat) | is.na(lon)]$loc_id)
    cat(sprintf("With coords: %d  Without: %d\n", n_with, n_no))
  } else cat("No lat/lon columns\n")
}

n_treat_unique <- uniqueN(dt_treat$loc_id)
findings[["n_unique_treat"]] <- list(
  reported = 4180, reproduced = n_treat_unique, diff = n_treat_unique - 4180,
  severity = "CRITICAL", desc = "Unique loc_id in treatment_annual (with coords)"
)

# 2. Polygon vintage count: paper says 18 annual polygons 2007-2024.
# The correct source is data/annual/YYYY_controle.geojson (one per year, 2007-2024 = 18).
annual_dir <- file.path(BASE, "data", "annual")
annual_ctrl <- list.files(annual_dir, pattern = "^[0-9]{4}_controle\\.geojson$", full.names = FALSE)
annual_years <- as.integer(sub("_controle\\.geojson$", "", annual_ctrl))
cat(sprintf("\nannual control polygons in data/annual/: %d  (years %d-%d)\n",
            length(annual_ctrl), min(annual_years), max(annual_years)))
findings[["polygon_vintages"]] <- list(
  reported = 18, reproduced = length(annual_ctrl), diff = length(annual_ctrl) - 18,
  severity = "HIGH",
  desc = "Number of annual control polygons in data/annual/ (paper: 18 annual polygons 2007-2024)"
)

# 3. annual_master_map_polygons.geojson
amap <- file.path(BASE, "data", "annual_master_map_polygons.geojson")
if (file.exists(amap)) {
  cat(sprintf("\nannual_master_map_polygons.geojson exists: %s (%.1f KB)\n", amap, file.size(amap)/1024))
  # Try to read via sf if available
  if (requireNamespace("sf", quietly = TRUE)) {
    library(sf)
    amap_sf <- st_read(amap, quiet = TRUE)
    cat(sprintf("Features: %d\n", nrow(amap_sf)))
    cat("Columns: ", paste(names(amap_sf), collapse = ", "), "\n")
    if ("year" %in% names(amap_sf)) {
      yrs <- sort(unique(amap_sf$year))
      cat(sprintf("Years: %s  (n=%d)\n", paste(yrs, collapse = ","), length(yrs)))
      findings[["polygon_years_in_master"]] <- list(
        reported_range = "2007-2024", reproduced_n = length(yrs),
        reproduced_min = min(yrs), reproduced_max = max(yrs),
        severity = "MEDIUM",
        desc = "Years present in annual_master_map_polygons.geojson"
      )
    }
  } else cat("(sf package not available — skip feature inspection)\n")
}

# 4. ever_treated, stable counts
n_ever <- nrow(dt_chg)
n_sm   <- nrow(dt_chg[change_type == "stable_Militia"])
n_sd   <- nrow(dt_chg[change_type == "stable_Drug"])
n_d2m  <- nrow(dt_chg[change_type == "Drug_to_Militia"])
n_m2d  <- nrow(dt_chg[change_type == "Militia_to_Drug"])

cat(sprintf("\nEver-treated (loc_faction_changes.csv): %d\n", n_ever))
findings[["n_ever_treated_appx"]] <- list(
  reported = 712, reproduced = n_ever, diff = n_ever - 712, severity = "HIGH",
  desc = "Total ever-treated stations (Appendix C Table 4: 712)"
)
findings[["n_stable_militia_appx"]] <- list(
  reported = 401, reproduced = n_sm, diff = n_sm - 401, severity = "HIGH",
  desc = "Stable Militia (Appendix C Table 4: 401)"
)
findings[["n_stable_drug_appx"]] <- list(
  reported = 246, reproduced = n_sd, diff = n_sd - 246, severity = "HIGH",
  desc = "Stable Drug (Appendix C Table 4: 246)"
)
findings[["n_d2m_appx"]] <- list(
  reported = 40, reproduced = n_d2m, diff = n_d2m - 40, severity = "HIGH",
  desc = "Drug to Militia switchers (Appendix C Table 4: 40)"
)
findings[["n_m2d_appx"]] <- list(
  reported = 25, reproduced = n_m2d, diff = n_m2d - 25, severity = "HIGH",
  desc = "Militia to Drug switchers (Appendix C Table 4: 25)"
)
findings[["share_switchers"]] <- list(
  reported = 0.091, reproduced = round((n_d2m + n_m2d) / n_ever, 3),
  diff = round((n_d2m + n_m2d) / n_ever - 0.091, 4), severity = "MEDIUM",
  desc = "Share of switchers among ever-treated (paper: 9.1%)"
)

# 5. Panel balance breakdown (restricted to the 4,180 geocoded analysis sample, as in Table 3).
elec_years <- c(2008, 2012, 2016, 2020, 2024)
geocoded_ids <- unique(dt_treat$loc_id)
prefeito <- dt_elec[DS_CARGO == "Prefeito" & election_year %in% elec_years & !is.na(hhi) & loc_id %in% geocoded_ids]
panel_counts <- prefeito[, .(n_elec = uniqueN(election_year)), by = loc_id]
balance_present <- panel_counts[, .N, by = n_elec][order(-n_elec)]
# Add the n_elec = 0 row (geocoded stations with no valid Prefeito outcome)
n_zero <- length(setdiff(geocoded_ids, panel_counts$loc_id))
balance <- rbind(balance_present, data.table(n_elec = 0, N = n_zero))[order(-n_elec)]
cat("\nPanel balance (Prefeito, valid hhi, 5 election years, restricted to 4,180 geocoded):\n"); print(balance)

# Paper Table 3 (post-reconciliation): {5:1740, 4:173, 3:1024, 2:979, 1:217, 0:47, total:4180}
paper_balance <- data.table(
  n_elec = c(5,4,3,2,1,0),
  N_paper = c(1740, 173, 1024, 979, 217, 47)
)
cmp_bal <- merge(balance, paper_balance, by = "n_elec", all = TRUE)
cmp_bal[is.na(N), N := 0]
cmp_bal[, diff := N - N_paper]
print(cmp_bal)

for (i in seq_len(nrow(cmp_bal))) {
  r <- cmp_bal[i]
  sev <- ifelse(abs(r$diff) > 5, "HIGH", ifelse(abs(r$diff) > 0, "MEDIUM", "OK"))
  findings[[paste0("panel_n_", r$n_elec)]] <- list(
    reported = r$N_paper, reproduced = r$N, diff = r$diff, severity = sev,
    desc = sprintf("Stations observed in %d elections (paper Table 3, restricted to 4,180 geocoded)", r$n_elec)
  )
}
findings[["panel_total_appx"]] <- list(
  reported = 4180, reproduced = sum(cmp_bal$N), diff = sum(cmp_bal$N) - 4180,
  severity = "HIGH",
  desc = "Total stations in Prefeito panel Table 3 (paper: 4,180 geocoded)"
)

# Share of balanced (denominator = 4,180 geocoded)
share_bal <- balance[n_elec == 5]$N / 4180
findings[["share_balanced_5"]] <- list(
  reported = 0.416, reproduced = round(share_bal, 3), diff = round(share_bal - 0.416, 4),
  severity = "MEDIUM", desc = "Share of stations in all 5 elections (paper: 41.6% of 4,180)"
)

write_json(list(test = "audit_10_sample_construction", findings = findings),
           file.path(OUT, "audit_10.json"), pretty = TRUE, auto_unbox = TRUE)
cat("\nWrote audit_10.json\n")


