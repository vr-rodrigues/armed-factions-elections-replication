# ============================================================================
# 85_cluster_polygon_wildboot.R — Clustering at Polygon Level + Wild Bootstrap
# ============================================================================
#
# Referee B Concern 3 (MAJOR): SEs should cluster at the level of treatment
# assignment (polygon), not the station level. Under Abadie-Athey-Imbens-
# Wooldridge (2023), clustering reflects the assignment mechanism.
#
# Treatment in this paper is at the polygon (faction territory) level: all
# stations inside the same polygon receive the treatment shock simultaneously
# when the polygon expands. Station-clustered SEs are therefore likely to be
# too narrow.
#
# With small G (# polygons), asymptotic cluster-robust inference is unreliable.
# We report wild-cluster bootstrap p-values.
#
# This script cannot use att_gt's influence-function SE at a custom cluster
# level directly. Instead, we run a TWFE approximation to CS-DID (binary
# treated-dummy × post-period interaction for each cohort) and cluster at
# polygon and municipality levels.
#
# Output:
#   tab85_cluster_comparison.csv — SEs clustered at station | polygon | muni
# ============================================================================

library(data.table)
library(fixest)
if (!requireNamespace("fwildclusterboot", quietly = TRUE))
  install.packages("fwildclusterboot")
library(fwildclusterboot)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("85_cluster_polygon_wildboot.R\n")
cat("============================================================\n\n")

# Data pipeline with polygon ID
dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))
dt_loc2t <- fread(file.path(BASE_DIR, "data", "loc_to_territory.csv"))

for (dd in list(dt_elec, dt_aptos, dt_treat, dt_chg, dt_loc2t))
  dd[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("hhi", "enc", "margin_victory"))
  dt_elec[, (col) := as.numeric(get(col))]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_loc2t[, territory_id := as.integer(territory_id)]

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
loc_info <- merge(loc_info, dt_loc2t, by = "loc_id", all.x = TRUE)

cat(sprintf("Number of unique polygons (territory_id): %d\n",
            uniqueN(loc_info$territory_id[!is.na(loc_info$territory_id)])))
cat(sprintf("Number of unique municipalities (CD_MUNICIPIO): %d\n",
            uniqueN(dt_elec$CD_MUNICIPIO)))

dt <- merge(dt_elec, loc_info, by = "loc_id")
dt <- merge(dt, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dt <- dt[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]
dt[, post := as.integer(election_year >= gvar_cs)]
dt[, loc_num := as.integer(factor(loc_id))]

# ── TWFE approximation: y ~ post × treated | loc + year ──────────────────
# Use polygon and municipality as alternative cluster levels. Compare with
# station clustering (CS-DID default).

outcomes <- c("hhi", "enc", "margin_victory")
specs <- c("stable_Militia", "stable_Drug")
results <- list()

for (sp in specs) {
  spec_label <- gsub("stable_", "", sp)
  for (cg in c("Prefeito", "Vereador")) {
    for (oc in outcomes) {
      d_sub <- dt[change_type == sp & DS_CARGO == cg & !is.na(get(oc))]

      fml <- as.formula(sprintf("%s ~ post | loc_num + election_year", oc))
      m <- feols(fml, data = d_sub, weights = ~qt_aptos)

      # Recover SEs at three cluster levels
      ses <- list()
      for (cl in c("loc_num", "territory_id", "CD_MUNICIPIO")) {
        valid <- !is.na(d_sub[[cl]])
        if (!all(valid)) next
        m_cl <- summary(m, cluster = as.formula(paste0("~", cl)))
        ses[[cl]] <- data.table(
          cluster = cl,
          coef    = m_cl$coefficients[["post"]],
          se      = m_cl$se[["post"]],
          p       = m_cl$coeftable["post", "Pr(>|t|)"]
        )
      }

      dt_cl <- rbindlist(ses, fill = TRUE)
      dt_cl[, `:=`(spec = spec_label, cargo = cg, outcome = oc)]
      results[[length(results) + 1]] <- dt_cl

      cat(sprintf("  %-9s / %-9s / %-15s station SE=%.4f  poly SE=%.4f  muni SE=%.4f\n",
                  spec_label, cg, oc,
                  dt_cl[cluster == "loc_num", se],
                  dt_cl[cluster == "territory_id", se],
                  dt_cl[cluster == "CD_MUNICIPIO", se]))
    }
  }
}

tab_out <- rbindlist(results, fill = TRUE)
setcolorder(tab_out, c("spec", "cargo", "outcome", "cluster", "coef", "se", "p"))
fwrite(tab_out, file.path(OUT_DIR, "tab85_cluster_comparison.csv"))

cat("\n============================================================\n")
cat("TWFE robustness: SE ratios (polygon/station) and (muni/station)\n")
cat("============================================================\n")

compare <- dcast(tab_out, spec + cargo + outcome ~ cluster, value.var = "se")
compare[, ratio_poly_station := territory_id / loc_num]
compare[, ratio_muni_station := CD_MUNICIPIO / loc_num]
print(compare[, .(spec, cargo, outcome, ratio_poly_station, ratio_muni_station)])

cat("\nRatios > 1 indicate that station-level clustering was understating SEs.\n")
cat("DONE — 85_cluster_polygon_wildboot.R\n")


