# ============================================================================
# 81_sun_abraham.R — Sun & Abraham (2021) Cross-Estimator Robustness
# ============================================================================
#
# Referee B Concern 1 (MAJOR): post-2021 AEJ:Applied convention is to report
# at least one cross-estimator (Sun-Abraham, de Chaisemartin-D'Haultfoeuille,
# or Borusyak-Jaravel-Spiess) alongside CS-DID.
#
# This script implements Sun-Abraham 2021 (interaction-weighted estimator)
# via fixest::sunab, matching the NYT comparison used in CS-DID.
#
# Output:
#   tab81_sun_abraham.csv   — ATT estimates per spec/cargo/outcome
#   tab81_csdid_vs_sa.csv   — side-by-side CS-DID vs Sun-Abraham comparison
# ============================================================================

library(data.table)
library(did)
if (!requireNamespace("fixest", quietly = TRUE)) install.packages("fixest")
library(fixest)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("81_sun_abraham.R — Sun-Abraham cross-estimator\n")
cat("============================================================\n\n")

# Data pipeline (same as 70/74/79/80)
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

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

dt <- merge(dt_elec, loc_info, by = "loc_id")
dt <- merge(dt, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dt <- dt[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]
dt[, loc_num := as.integer(factor(loc_id))]

# ── Sun-Abraham estimation ──────────────────────────────────────────────────
# feols(y ~ sunab(cohort, period) | unit + period, data)
# With never-treated absent here (Sun-Abraham requires at least one
# never-treated or not-yet-treated cohort), we code the last cohort as the
# reference. Sun-Abraham + fixest handles this automatically.

outcomes <- c("hhi", "enc", "margin_victory")
cargos   <- c("Prefeito", "Vereador")
specs    <- c("stable_Militia", "stable_Drug")

results_sa <- list()

for (sp in specs) {
  spec_label <- gsub("stable_", "", sp)
  for (cg in cargos) {
    for (oc in outcomes) {
      d <- dt[change_type == sp & DS_CARGO == cg & !is.na(get(oc))]
      if (uniqueN(d$gvar_cs) < 2) next

      lbl <- sprintf("%-8s / %-9s / %-15s", spec_label, cg, oc)

      # Sun-Abraham: sunab(cohort, period)
      # fixest aggregates to ATT via summary(m, agg = "ATT")
      res <- tryCatch({
        fml <- as.formula(sprintf("%s ~ sunab(gvar_cs, election_year) | loc_num + election_year", oc))
        m <- feols(fml, data = d, weights = ~qt_aptos, cluster = ~loc_num)
        # Aggregate post-treatment event-time coefficients to a single ATT
        s_att <- summary(m, agg = "ATT")
        ct <- s_att$coeftable
        # The aggregated coefficient is typically named "ATT"
        att_row <- which(grepl("ATT", rownames(ct)))
        if (length(att_row) == 0) att_row <- 1
        list(att = ct[att_row, 1], se = ct[att_row, 2],
             p = ct[att_row, 4])
      }, error = function(e) { cat(sprintf("  %s ERROR: %s\n", lbl, e$message)); NULL })

      if (is.null(res)) next

      cat(sprintf("  %s ATT=%+.4f (SE %.4f) p=%.3f\n",
                  lbl, res$att, res$se, res$p))

      results_sa[[length(results_sa) + 1]] <- data.table(
        spec = spec_label, cargo = cg, outcome = oc,
        estimator = "SunAbraham",
        att = res$att, se = res$se, p_value = res$p
      )
    }
  }
}

tab_sa <- rbindlist(results_sa, fill = TRUE)
fwrite(tab_sa, file.path(OUT_DIR, "tab81_sun_abraham.csv"))

# ── Side-by-side comparison with CS-DID (from tab70_main_overall.csv) ──────

cs_tab <- fread(file.path(OUT_DIR, "tab70_main_overall.csv"))
cs_nyt <- cs_tab[estimator == "NYT"]

cs_nyt[, spec := gsub("stable_", "", spec)]
compare <- merge(
  cs_nyt[, .(spec, cargo, outcome, att_cs = att, se_cs = se, p_cs = p_value)],
  tab_sa[, .(spec, cargo, outcome, att_sa = att, se_sa = se, p_sa = p_value)],
  by = c("spec", "cargo", "outcome"), all = TRUE
)
compare[, diff_pct := 100 * (att_sa - att_cs) / att_cs]

fwrite(compare, file.path(OUT_DIR, "tab81_csdid_vs_sa.csv"))

cat("\n============================================================\n")
cat("CS-DID vs Sun-Abraham (NYT, main-specification comparison)\n")
cat("============================================================\n")
print(compare[, .(spec, cargo, outcome, att_cs, att_sa, diff_pct)])

cat("\nDONE — 81_sun_abraham.R\n")


