# =============================================================================
# audit_01_data_integrity.R
# Counts and panel structure: 4180/398/240/3791, 41.6% balanced, panel keys
# =============================================================================
suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT    <- file.path(BASE, "audit", "outputs")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

cat("=== audit_01_data_integrity ===\n")

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

# 1. Master roster = union of all distinct stations observed across 2008-2024 election files.
# The 4,654 union lives in electoral_competition_measures.csv (pre-coordinate filter).
# After the coord filter, treatment_annual.csv retains the 4,180 geocoded stations.
# The 474 dropped-for-no-coords = 4,654 - 4,180 by construction.
n_unique_master <- uniqueN(dt_elec$loc_id)
n_unique_treat  <- uniqueN(dt_treat$loc_id)
n_with_coords   <- uniqueN(dt_treat[!is.na(lat) & !is.na(lon)]$loc_id)
n_no_coords     <- n_unique_master - n_with_coords

cat(sprintf("Unique stations in electoral master (pre-coord filter): %d\n", n_unique_master))
cat(sprintf("Unique stations in treatment_annual (post-coord filter): %d\n", n_unique_treat))
cat(sprintf("With coords (lat & lon non-NA): %d\n", n_with_coords))
cat(sprintf("Without coords (master - with_coords): %d\n", n_no_coords))

# Paper claim: 4654 union, 4180 with coords, 474 dropped
findings[["n_unique_master"]] <- list(
  reported = 4654, reproduced = n_unique_master,
  diff = n_unique_master - 4654, severity = "HIGH",
  desc = "Unique loc_id in electoral_competition_measures.csv (Appendix C union: 4,654)"
)
findings[["n_with_coords"]] <- list(
  reported = 4180, reproduced = n_with_coords,
  diff = n_with_coords - 4180, severity = "CRITICAL",
  desc = "Loc_ids with valid coordinates (Appendix C and Section 3: 4,180)"
)
findings[["n_no_coords"]] <- list(
  reported = 474, reproduced = n_no_coords,
  diff = n_no_coords - 474, severity = "MEDIUM",
  desc = "Loc_ids dropped for no coordinates = master - geocoded (Appendix C: 474)"
)

# 2. Faction-type counts in loc_faction_changes
counts_chg <- dt_chg[, .N, by = change_type][order(-N)]
cat("\nchange_type counts:\n"); print(counts_chg)

n_stable_militia <- nrow(dt_chg[change_type == "stable_Militia"])
n_stable_drug    <- nrow(dt_chg[change_type == "stable_Drug"])
n_drug_to_mil    <- nrow(dt_chg[change_type == "Drug_to_Militia"])
n_mil_to_drug    <- nrow(dt_chg[change_type == "Militia_to_Drug"])
n_ever_treated   <- n_stable_militia + n_stable_drug + n_drug_to_mil + n_mil_to_drug

# Paper Appendix C: 401 stable Militia, 246 stable Drug, 40+25 switchers, 712 total
findings[["n_stable_militia_raw"]] <- list(
  reported = 401, reproduced = n_stable_militia,
  diff = n_stable_militia - 401, severity = "HIGH",
  desc = "Stable_Militia rows in loc_faction_changes.csv (Appendix C Table 4: 401)"
)
findings[["n_stable_drug_raw"]] <- list(
  reported = 246, reproduced = n_stable_drug,
  diff = n_stable_drug - 246, severity = "HIGH",
  desc = "Stable_Drug rows in loc_faction_changes.csv (Appendix C Table 4: 246)"
)
findings[["n_drug_to_militia"]] <- list(
  reported = 40, reproduced = n_drug_to_mil,
  diff = n_drug_to_mil - 40, severity = "HIGH",
  desc = "Drug_to_Militia switchers (Appendix C Table 4: 40)"
)
findings[["n_militia_to_drug"]] <- list(
  reported = 25, reproduced = n_mil_to_drug,
  diff = n_mil_to_drug - 25, severity = "HIGH",
  desc = "Militia_to_Drug switchers (Appendix C Table 4: 25)"
)
findings[["n_ever_treated"]] <- list(
  reported = 712, reproduced = n_ever_treated,
  diff = n_ever_treated - 712, severity = "HIGH",
  desc = "Total ever-treated stations (Appendix C Table 4: 712)"
)

# 3. Panel balance: stations with N elections of valid Prefeito outcome.
# Table 3 is restricted to the 4,180 geocoded analysis sample; stations with zero
# valid Prefeito outcomes (n_elec = 0) are included as an explicit row.
elec_years <- c(2008, 2012, 2016, 2020, 2024)
geocoded_ids <- unique(dt_treat$loc_id)
prefeito <- dt_elec[
  DS_CARGO %in% c("Prefeito", "PREFEITO", "prefeito") & election_year %in% elec_years &
  !is.na(hhi) & loc_id %in% geocoded_ids
]
panel_counts <- prefeito[, .(n_elec = uniqueN(election_year)), by = loc_id]

n_5 <- nrow(panel_counts[n_elec == 5])
n_4 <- nrow(panel_counts[n_elec == 4])
n_3 <- nrow(panel_counts[n_elec == 3])
n_2 <- nrow(panel_counts[n_elec == 2])
n_1 <- nrow(panel_counts[n_elec == 1])
n_0 <- length(setdiff(geocoded_ids, panel_counts$loc_id))
n_total_panel <- n_5 + n_4 + n_3 + n_2 + n_1 + n_0  # = 4180 by construction
share_5 <- n_5 / 4180

cat(sprintf("\nPrefeito panel balance (geocoded 4,180 sample): 5=%d, 4=%d, 3=%d, 2=%d, 1=%d, 0=%d, total=%d\n",
            n_5, n_4, n_3, n_2, n_1, n_0, n_total_panel))

# Paper Table 3 (post-reconciliation): 5->1740 (41.6%), 4->173 (4.1%), 3->1024 (24.5%),
# 2->979 (23.4%), 1->217 (5.2%), 0->47 (1.1%), total 4180.
findings[["panel_5_elections"]] <- list(
  reported = 1740, reproduced = n_5, diff = n_5 - 1740, severity = "HIGH",
  desc = "Prefeito panel: 5 elections (Appendix C Table 3: 1,740)"
)
findings[["panel_4_elections"]] <- list(
  reported = 173, reproduced = n_4, diff = n_4 - 173, severity = "MEDIUM",
  desc = "Prefeito panel: 4 elections (Appendix C Table 3: 173)"
)
findings[["panel_3_elections"]] <- list(
  reported = 1024, reproduced = n_3, diff = n_3 - 1024, severity = "MEDIUM",
  desc = "Prefeito panel: 3 elections (Appendix C Table 3: 1,024)"
)
findings[["panel_2_elections"]] <- list(
  reported = 979, reproduced = n_2, diff = n_2 - 979, severity = "MEDIUM",
  desc = "Prefeito panel: 2 elections (Appendix C Table 3: 979)"
)
findings[["panel_1_election"]] <- list(
  reported = 217, reproduced = n_1, diff = n_1 - 217, severity = "MEDIUM",
  desc = "Prefeito panel: 1 election (Appendix C Table 3: 217)"
)
findings[["panel_0_elections"]] <- list(
  reported = 47, reproduced = n_0, diff = n_0 - 47, severity = "MEDIUM",
  desc = "Prefeito panel: 0 elections (Appendix C Table 3: 47)"
)
findings[["panel_total"]] <- list(
  reported = 4180, reproduced = n_total_panel, diff = n_total_panel - 4180, severity = "HIGH",
  desc = "Prefeito panel total (Appendix C Table 3: 4,180 = geocoded roster)"
)
findings[["panel_share_balanced"]] <- list(
  reported = 0.416, reproduced = round(share_5, 3), diff = round(share_5 - 0.416, 4),
  severity = "MEDIUM", desc = "Share of stations with all 5 elections (Appendix C Table 3: 41.6%)"
)

# 4. Election year coverage
cat("\nElection years in electoral_competition_measures.csv:\n")
print(dt_elec[, .N, by = election_year][order(election_year)])

# 5. Duplicates check
dup_elec <- dt_elec[, .N, by = .(loc_id, election_year, DS_CARGO)][N > 1]
cat(sprintf("\nDuplicate (loc_id, election_year, DS_CARGO) rows: %d\n", nrow(dup_elec)))
findings[["dup_keys_electoral"]] <- list(
  reported = 0, reproduced = nrow(dup_elec), diff = nrow(dup_elec),
  severity = "CRITICAL", desc = "Duplicate panel keys in electoral_competition_measures.csv"
)

dup_treat <- dt_treat[, .N, by = .(loc_id, election_year)][N > 1]
cat(sprintf("Duplicate (loc_id, election_year) in treatment_annual: %d\n", nrow(dup_treat)))
findings[["dup_keys_treatment"]] <- list(
  reported = 0, reproduced = nrow(dup_treat), diff = nrow(dup_treat),
  severity = "MEDIUM", desc = "Duplicate panel keys in locais_votacao_treatment_annual.csv"
)

dup_chg <- dt_chg[, .N, by = loc_id][N > 1]
cat(sprintf("Duplicate loc_id in loc_faction_changes: %d\n", nrow(dup_chg)))
findings[["dup_keys_changes"]] <- list(
  reported = 0, reproduced = nrow(dup_chg), diff = nrow(dup_chg),
  severity = "CRITICAL", desc = "Duplicate loc_id in loc_faction_changes.csv"
)

# 6. Never-treated pool: paper says 3,791 (main text) and 3,468 (Appendix C Table 4).
# Per the paper's own note on Table 4, "never-treated" in Table 4 means "never received a
# stable faction-type classification from Monteiro (2023)" = geocoded stations absent from
# loc_faction_changes.csv. Equivalently, 4,180 geocoded - 712 classified = 3,468.
# (Informationally, we also report the stricter "never inside any annual polygon" count.)
n_never_classification <- uniqueN(dt_treat$loc_id) - nrow(dt_chg)
never_inside_strict <- dt_treat[, .(any_inside = max(inside_any, na.rm = TRUE)), by = loc_id]
n_never_strict <- nrow(never_inside_strict[any_inside == 0])
cat(sprintf("\nNever-treated by classification (4,180 - 712 classified): %d\n", n_never_classification))
cat(sprintf("Never inside ANY annual polygon (strict, informational): %d\n", n_never_strict))
findings[["n_never_strict"]] <- list(
  reported = 3468, reproduced = n_never_classification,
  diff = n_never_classification - 3468,
  severity = "MEDIUM",
  desc = "Never-treated by Monteiro classification = 4,180 geocoded - 712 classified (Appendix C Table 4: 3,468)"
)
findings[["n_never_inside_polygon_strict"]] <- list(
  reported = NA, reproduced = n_never_strict, diff = NA, severity = "INFO",
  desc = "Stations never inside any annual polygon (strict geographic definition; informational only)"
)

# Never-treated regression pool used in script 89:
# faction_locs = ONLY stable_Militia + stable_Drug (NOT switchers!)
# never_locs = setdiff(unique(dt_elec$loc_id), faction_locs)
# i.e. NT pool INCLUDES switchers + electoral-only stations missing from changes.
faction_locs <- unique(dt_chg[change_type %in% c("stable_Militia","stable_Drug")]$loc_id)
all_elec_locs <- unique(dt_elec$loc_id)
nt_raw <- setdiff(all_elec_locs, faction_locs)
cat(sprintf("Never-treated raw (in elec, not in stable Militia/Drug): %d\n", length(nt_raw)))

# Apply the EXACT script 89 pipeline:
elec_years <- c(2008, 2012, 2016, 2020, 2024)
dt_elec2 <- merge(dt_elec, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                  by = c("loc_id","election_year"), all.x = TRUE)
loc_info_full <- rbind(
  data.table(loc_id = faction_locs, change_type = "treated"),
  data.table(loc_id = nt_raw,        change_type = "never_treated")
)
dt_full <- merge(dt_elec2, loc_info_full, by = "loc_id")
dt_full <- dt_full[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]
n_nt_filtered <- uniqueN(dt_full[change_type == "never_treated"]$loc_id)
cat(sprintf("Never-treated AFTER full 89 pipeline filter: %d\n", n_nt_filtered))

findings[["n_nt_regression_pool"]] <- list(
  reported = 3791, reproduced = n_nt_filtered, diff = n_nt_filtered - 3791,
  severity = "CRITICAL", desc = "Never-treated regression pool after qt_aptos filter (Section 3 + Appendix B: 3,791)"
)
findings[["n_nt_regression_pool_unfiltered"]] <- list(
  reported = 3791, reproduced = length(nt_raw), diff = length(nt_raw) - 3791,
  severity = "INFO", desc = "Never-treated unfiltered (for reference)"
)

# Output
res <- list(test = "audit_01_data_integrity", findings = findings)
write_json(res, file.path(OUT, "audit_01.json"), pretty = TRUE, auto_unbox = TRUE)
cat("\nWrote audit_01.json\n")


