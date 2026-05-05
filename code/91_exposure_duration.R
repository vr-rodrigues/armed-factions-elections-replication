# ============================================================================
# 91_exposure_duration.R
# ============================================================================
#
# Mechanism analysis 2: duration of exposure.
#
# The municipal-election panel observes treatment in four-year steps. This script
# reports dynamic CS-DID effects at the entry election (e = 0) and one municipal
# cycle later (e = +4). It also reports the difference between those two effects
# using the dynamic aggregation influence functions.
#
# Output:
#   results/tab91_exposure_duration_long.csv
#   results/tab91_exposure_duration.csv
# ============================================================================

library(data.table)
library(did)

set.seed(20260430)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("91_exposure_duration.R\n")
cat("============================================================\n\n")

dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("hhi", "enc", "margin_victory", "total_votes")) {
  dt_elec[, (col) := as.numeric(get(col))]
}

dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]

dt_elec <- merge(dt_elec, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                 by = c("loc_id", "election_year"), all.x = TRUE)
dt_elec[, turnout := total_votes / qt_aptos]
dt_elec[is.na(turnout) | is.infinite(turnout) | turnout > 1 | turnout <= 0,
        turnout := NA_real_]

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
  loc_gvar[, .(loc_id, gvar_cs)],
  by = "loc_id",
  all.x = TRUE
)

dt_faction <- merge(
  dt_elec,
  loc_info[, .(loc_id, gvar_cs, change_type)],
  by = "loc_id"
)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

run_duration <- function(d_run, outcome, lbl) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]
  if (uniqueN(d$gvar_cs) < 2) return(NULL)

  tryCatch({
    att <- att_gt(
      yname = outcome,
      tname = "election_year",
      idname = "loc_num",
      gname = "gvar_cs",
      xformla = ~1,
      data = as.data.frame(d),
      base_period = "universal",
      control_group = "notyettreated",
      allow_unbalanced_panel = TRUE,
      weightsname = "qt_aptos",
      print_details = FALSE
    )

    dyn <- aggte(att, type = "dynamic", min_e = -8, max_e = 4,
                 na.rm = TRUE)

    keep <- which(dyn$egt %in% c(0, 4) & !is.na(dyn$se.egt))
    long <- data.table(
      event_time = dyn$egt[keep],
      att = dyn$att.egt[keep],
      se = dyn$se.egt[keep]
    )
    long[, p_value := 2 * pnorm(-abs(att / se))]
    long[, `:=`(ci_lo = att - 1.96 * se, ci_hi = att + 1.96 * se)]

    diff_row <- NULL
    idx0 <- which(dyn$egt == 0)
    idx4 <- which(dyn$egt == 4)
    inf_func <- dyn$inf.function$dynamic.inf.func.e

    if (length(idx0) == 1 && length(idx4) == 1 &&
        !is.na(dyn$se.egt[idx0]) && !is.na(dyn$se.egt[idx4]) &&
        !is.null(inf_func) && ncol(inf_func) == length(dyn$egt)) {
      n_inf <- nrow(inf_func)
      v_full <- crossprod(inf_func) / (n_inf^2)
      diff_att <- dyn$att.egt[idx4] - dyn$att.egt[idx0]
      diff_se <- sqrt(v_full[idx4, idx4] + v_full[idx0, idx0] -
                        2 * v_full[idx4, idx0])
      diff_row <- data.table(
        event_time = NA_real_,
        att = diff_att,
        se = diff_se,
        p_value = 2 * pnorm(-abs(diff_att / diff_se)),
        ci_lo = diff_att - 1.96 * diff_se,
        ci_hi = diff_att + 1.96 * diff_se,
        contrast = "e4_minus_e0"
      )
    }

    long[, contrast := fifelse(event_time == 0, "entry_e0",
                               "one_cycle_after_e4")]
    out <- rbind(long, diff_row, fill = TRUE)

    cat(sprintf("  %-55s e0=%+.4f e4=%+.4f diff=%s N=%d\n",
                lbl,
                long[event_time == 0, att],
                long[event_time == 4, att],
                ifelse(is.null(diff_row), "NA",
                       sprintf("%+.4f", diff_row$att)),
                uniqueN(d$loc_id)))

    out[, n_locs := uniqueN(d$loc_id)]
    out
  }, error = function(e) {
    cat(sprintf("  %-55s ERROR: %s\n", lbl, e$message))
    NULL
  })
}

specs <- list(
  list(name = "Militia", filter = "stable_Militia"),
  list(name = "Drug", filter = "stable_Drug")
)

outcome_labels <- data.table(
  outcome = c("hhi", "enc", "margin_victory", "turnout"),
  label = c("HHI", "ENC", "Margin of victory", "Turnout")
)

results <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s, prefeito, NYT ===\n", sp$name))
  d_sp <- dt_faction[change_type == sp$filter & DS_CARGO == "Prefeito"]

  for (oc in outcome_labels$outcome) {
    r <- run_duration(d_sp, oc, sprintf("%s / Prefeito / %s", sp$name, oc))
    if (!is.null(r)) {
      r[, `:=`(spec = sp$name, cargo = "Prefeito", outcome = oc,
               estimator = "NYT")]
      results[[length(results) + 1]] <- r
    }
  }
}

tab_long <- rbindlist(results, fill = TRUE)
tab_long <- merge(tab_long, outcome_labels, by = "outcome", all.x = TRUE)
setcolorder(tab_long, c("spec", "cargo", "outcome", "label", "estimator",
                        "contrast", "event_time", "att", "se", "p_value",
                        "ci_lo", "ci_hi", "n_locs"))
tab_long[, `:=`(
  att = round(att, 5),
  se = round(se, 5),
  p_value = round(p_value, 4),
  ci_lo = round(ci_lo, 5),
  ci_hi = round(ci_hi, 5)
)]

wide <- dcast(
  tab_long,
  spec + cargo + outcome + label + estimator + n_locs ~ contrast,
  value.var = c("att", "se", "p_value")
)

fwrite(tab_long, file.path(OUT_DIR, "tab91_exposure_duration_long.csv"))
fwrite(wide, file.path(OUT_DIR, "tab91_exposure_duration.csv"))

cat("\n============================================================\n")
cat("Exposure-duration results, NYT preferred\n")
cat("============================================================\n")
print(tab_long)
cat("\nWritten: results/tab91_exposure_duration_long.csv\n")
cat("Written: results/tab91_exposure_duration.csv\n")
cat("DONE - 91_exposure_duration.R\n")
