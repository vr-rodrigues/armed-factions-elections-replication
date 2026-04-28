# ============================================================================
# 73_robustness_municipality.R — Robustness: Municipality-Level Controls
# ============================================================================
#
# Tests whether pooling across municipalities drives the main results:
#   Test 1: xformla = ~factor(mun_id) in att_gt (municipality FE in CS-DID)
#   Test 2: CS-DID by individual large municipality
#   Test 3: Municipality-demeaned outcomes
#
# Baseline comparison: script 70 (xformla = ~1, all 20 municipalities)
# ============================================================================

library(data.table)
library(did)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("73_robustness_municipality.R\n")
cat("============================================================\n\n")

# ── 1. Data Loading (same as script 70) ──────────────────────────────────

dt_elec  <- fread(file.path(BASE_DIR, "data",
                            "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data",
                            "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data",
                            "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data",
                            "loc_faction_changes.csv"))

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

# CD_MUNICIPIO is already in dt_elec, no need for separate merge

# Treatment assignment
map_gvar <- function(g) {
  ifelse(g == 0 | is.na(g), 2008,
    sapply(g, function(x) {
      ey <- elec_years[elec_years >= x]
      if (length(ey) == 0) max(elec_years) else min(ey)
    })
  )
}

loc_gvar <- dt_treat[, .(gvar_raw = gvar[1]), by = loc_id]
loc_gvar[, gvar_cs := map_gvar(gvar_raw)]

loc_faction_spec <- dt_treat[inside_controle == 1,
  .(faction_specific = faction_type_controle[1]), by = loc_id]
loc_faction_spec[faction_specific %in% c("Milícia", "Milicia"),
                 faction_specific := "Militia"]

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id", all.x = TRUE
)
loc_info <- merge(loc_info, loc_faction_spec, by = "loc_id", all.x = TRUE)

# Build faction panel (NYT)
dt_faction <- merge(dt_elec,
            loc_info[, .(loc_id, gvar_cs, change_type, faction_specific)],
            by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]
dt_faction[, mun_id := as.integer(factor(CD_MUNICIPIO))]

cat(sprintf("Panel: %d obs, %d locs, %d municipalities\n\n",
            nrow(dt_faction), uniqueN(dt_faction$loc_id),
            uniqueN(dt_faction$CD_MUNICIPIO)))

# ── 2. CS-DID Engine ─────────────────────────────────────────────────────

run_csdid <- function(d_run, outcome, lbl, ctrl, xf = ~1) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]
  n_locs <- uniqueN(d$loc_id)
  n_cohorts <- uniqueN(d$gvar_cs)
  if (n_cohorts < 2) {
    cat(sprintf("  %-60s SKIP\n", lbl))
    return(NULL)
  }
  tryCatch({
    att <- att_gt(yname = outcome, tname = "election_year", idname = "loc_num",
                  gname = "gvar_cs", xformla = xf, data = as.data.frame(d),
                  base_period = "universal", control_group = ctrl,
                  allow_unbalanced_panel = TRUE, weightsname = "qt_aptos",
                  print_details = FALSE)
    agg <- aggte(att, type = "dynamic")
    p <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))
    sig <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
    cat(sprintf("  %-60s ATT=%+.4f (%.4f) p=%.3f%s N=%d\n",
                lbl, agg$overall.att, agg$overall.se, p, sig, n_locs))
    data.table(att = round(agg$overall.att, 5), se = round(agg$overall.se, 5),
               p_value = round(p, 4), n_locs = n_locs)
  }, error = function(e) {
    cat(sprintf("  %-60s ERROR: %s\n", lbl, substr(e$message, 1, 60)))
    NULL
  })
}

outcomes <- c("hhi", "enc", "margin_victory")
all_results <- list()

# ============================================================================
# TEST 1: xformla = ~factor(mun_id)
# ============================================================================
cat("=== TEST 1: Municipality FE in xformla ===\n\n")

for (sp in list(list("Militia", "stable_Militia"), list("Drug", "stable_Drug"))) {
  d_spec <- dt_faction[change_type == sp[[2]]]
  cat(sprintf("--- %s (N=%d, %d municipalities) ---\n", sp[[1]],
              uniqueN(d_spec$loc_id), uniqueN(d_spec$CD_MUNICIPIO)))
  for (cargo in c("Prefeito")) {
    for (oc in outcomes) {
      lbl <- sprintf("%s/%s/%s [NYT + mun FE]", sp[[1]], cargo, oc)
      res <- run_csdid(d_spec[DS_CARGO == cargo], oc, lbl, "notyettreated",
                       xf = ~factor(mun_id))
      if (!is.null(res)) {
        res[, `:=`(test = "mun_FE", spec = sp[[1]], cargo = cargo, outcome = oc)]
        all_results[[length(all_results) + 1]] <- res
      }
    }
  }
}

# ============================================================================
# TEST 2: By individual large municipality (NYT, Militia/Prefeito only)
# ============================================================================
cat("\n=== TEST 2: By individual municipality ===\n\n")

# Identify municipalities with enough militia stations
mun_counts <- dt_faction[change_type == "stable_Militia",
  .(n_militia = uniqueN(loc_id), n_cohorts = uniqueN(gvar_cs)),
  by = CD_MUNICIPIO][order(-n_militia)]
print(mun_counts)

# Run for each municipality with >= 2 cohorts and >= 10 stations
cat("\n")
for (i in seq_len(nrow(mun_counts))) {
  mc <- mun_counts[i]
  if (mc$n_cohorts < 2 || mc$n_militia < 10) next
  d_mun <- dt_faction[change_type == "stable_Militia" & CD_MUNICIPIO == mc$CD_MUNICIPIO]
  for (oc in outcomes) {
    lbl <- sprintf("Militia/Prefeito/%s [mun=%d, N=%d]", oc,
                   mc$CD_MUNICIPIO, mc$n_militia)
    res <- run_csdid(d_mun[DS_CARGO == "Prefeito"], oc, lbl, "notyettreated")
    if (!is.null(res)) {
      res[, `:=`(test = paste0("mun_", mc$CD_MUNICIPIO),
                 spec = "Militia", cargo = "Prefeito", outcome = oc)]
      all_results[[length(all_results) + 1]] <- res
    }
  }
}

# Drug by municipality
mun_counts_drug <- dt_faction[change_type == "stable_Drug",
  .(n_drug = uniqueN(loc_id), n_cohorts = uniqueN(gvar_cs)),
  by = CD_MUNICIPIO][order(-n_drug)]
cat("\nDrug by municipality:\n")
print(mun_counts_drug)
cat("\n")
for (i in seq_len(nrow(mun_counts_drug))) {
  mc <- mun_counts_drug[i]
  if (mc$n_cohorts < 2 || mc$n_drug < 10) next
  d_mun <- dt_faction[change_type == "stable_Drug" & CD_MUNICIPIO == mc$CD_MUNICIPIO]
  for (oc in outcomes) {
    lbl <- sprintf("Drug/Prefeito/%s [mun=%d, N=%d]", oc,
                   mc$CD_MUNICIPIO, mc$n_drug)
    res <- run_csdid(d_mun[DS_CARGO == "Prefeito"], oc, lbl, "notyettreated")
    if (!is.null(res)) {
      res[, `:=`(test = paste0("mun_", mc$CD_MUNICIPIO),
                 spec = "Drug", cargo = "Prefeito", outcome = oc)]
      all_results[[length(all_results) + 1]] <- res
    }
  }
}

# ============================================================================
# TEST 3: Municipality-demeaned outcomes
# ============================================================================
cat("\n=== TEST 3: Municipality-demeaned outcomes ===\n\n")

# CD_MUNICIPIO already in dt_faction from dt_elec
for (oc in outcomes) {
  dm_col <- paste0(oc, "_dm")
  dt_faction[, (dm_col) := get(oc) - mean(get(oc), na.rm = TRUE),
             by = .(CD_MUNICIPIO, election_year, DS_CARGO)]
}

for (sp in list(list("Militia", "stable_Militia"), list("Drug", "stable_Drug"))) {
  d_spec <- dt_faction[change_type == sp[[2]]]
  for (oc in outcomes) {
    dm_col <- paste0(oc, "_dm")
    lbl <- sprintf("%s/Prefeito/%s_dm [NYT demeaned]", sp[[1]], oc)
    res <- run_csdid(d_spec[DS_CARGO == "Prefeito"], dm_col, lbl, "notyettreated")
    if (!is.null(res)) {
      res[, `:=`(test = "demeaned", spec = sp[[1]], cargo = "Prefeito", outcome = oc)]
      all_results[[length(all_results) + 1]] <- res
    }
  }
}

# ── Output ────────────────────────────────────────────────────────────────

tab <- rbindlist(all_results, fill = TRUE)
setcolorder(tab, c("test", "spec", "cargo", "outcome", "att", "se", "p_value", "n_locs"))

cat("\n============================================================\n")
cat("SUMMARY: Municipality Robustness Tests\n")
cat("============================================================\n\n")

# Baseline from script 70 for comparison
cat("--- Baseline (script 70, xformla=~1, NYT) ---\n")
cat("  Militia/Prefeito: HHI +0.039*** ENC -0.347*** Margin +0.052***\n")
cat("  Drug/Prefeito:    HHI -0.003    ENC +0.078    Margin +0.002\n\n")

cat("--- Test 1: Municipality FE in xformla ---\n")
print(tab[test == "mun_FE"], nrows = 20)

cat("\n--- Test 2: By individual municipality ---\n")
print(tab[grepl("^mun_", test)], nrows = 40)

cat("\n--- Test 3: Municipality-demeaned outcomes ---\n")
print(tab[test == "demeaned"], nrows = 20)

fwrite(tab, file.path(OUT_DIR, "tab73_municipality_robustness.csv"))
cat("\nSaved: tab73_municipality_robustness.csv\n")
cat("\nDONE — 73_robustness_municipality.R\n")


