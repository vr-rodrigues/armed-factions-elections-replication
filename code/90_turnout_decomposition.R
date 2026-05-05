# ============================================================================
# 90_turnout_decomposition.R
# ============================================================================
#
# Mechanism analysis 1: decompose turnout into votes per eligible voter.
#
# The polling-station data do not identify a militia-linked candidate. They do
# contain the local leading candidate vote share. We therefore decompose turnout
# into:
#   1. valid votes for the station-leading candidate per eligible voter,
#   2. valid votes for all other candidates per eligible voter,
#   3. blank and null votes per eligible voter,
#   4. a residual turnout component.
#
# The residual reconciles total_votes with valid_votes + null_blank_votes. It is
# concentrated in 2008 and is kept as an accounting term, not as a substantive
# behavioral outcome.
#
# Output:
#   results/tab90_turnout_decomposition.csv
# ============================================================================

library(data.table)
library(did)

set.seed(20260430)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("90_turnout_decomposition.R\n")
cat("============================================================\n\n")

dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("top1_share", "valid_votes", "total_votes", "null_blank_votes")) {
  dt_elec[, (col) := as.numeric(get(col))]
}

dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]

dt_elec <- merge(dt_elec, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                 by = c("loc_id", "election_year"), all.x = TRUE)

dt_elec[, top1_valid_votes := top1_share * valid_votes]
dt_elec[, other_valid_votes := valid_votes - top1_valid_votes]
dt_elec[, residual_votes := total_votes - valid_votes - null_blank_votes]
dt_elec[residual_votes < 0 | is.na(residual_votes), residual_votes := NA_real_]

dt_elec[, turnout := total_votes / qt_aptos]
dt_elec[, top1_valid_per_eligible := top1_valid_votes / qt_aptos]
dt_elec[, other_valid_per_eligible := other_valid_votes / qt_aptos]
dt_elec[, null_blank_per_eligible := null_blank_votes / qt_aptos]
dt_elec[, residual_turnout_per_eligible := residual_votes / qt_aptos]
dt_elec[, valid_per_eligible := valid_votes / qt_aptos]

component_cols <- c(
  "turnout",
  "top1_valid_per_eligible",
  "other_valid_per_eligible",
  "null_blank_per_eligible",
  "residual_turnout_per_eligible",
  "valid_per_eligible"
)

for (col in component_cols) {
  dt_elec[is.na(get(col)) | is.infinite(get(col)) | get(col) < 0 | get(col) > 1,
          (col) := NA_real_]
}

dt_elec[, decomposition_gap := abs(
  turnout - top1_valid_per_eligible - other_valid_per_eligible -
    null_blank_per_eligible - residual_turnout_per_eligible
)]
gap <- dt_elec[DS_CARGO == "Prefeito", max(decomposition_gap, na.rm = TRUE)]
cat(sprintf("Maximum turnout decomposition gap, prefeito: %.8f\n\n", gap))

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

wald_pretrend <- function(agg) {
  pre_idx <- which(agg$egt < 0 & !is.na(agg$se.egt))
  if (length(pre_idx) < 1) return(NA_real_)

  inf_func <- agg$inf.function$dynamic.inf.func.e
  if (is.null(inf_func) || ncol(inf_func) != length(agg$egt)) return(NA_real_)

  n_inf <- nrow(inf_func)
  v_full <- crossprod(inf_func) / (n_inf^2)
  v_pre <- v_full[pre_idx, pre_idx, drop = FALSE]
  pre_att <- agg$att.egt[pre_idx]

  tryCatch({
    w <- as.numeric(t(pre_att) %*% solve(v_pre) %*% pre_att)
    1 - pchisq(w, df = length(pre_idx))
  }, error = function(e) NA_real_)
}

run_cs <- function(d_run, outcome, lbl) {
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

    agg <- aggte(att, type = "dynamic", na.rm = TRUE)
    p <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))
    p_wald <- wald_pretrend(agg)

    cat(sprintf("  %-60s ATT=%+.4f (SE %.4f) p=%.4f Wald=%s N=%d\n",
                lbl, agg$overall.att, agg$overall.se, p,
                ifelse(is.na(p_wald), "NA", sprintf("%.4f", p_wald)),
                uniqueN(d$loc_id)))

    data.table(
      att = agg$overall.att,
      se = agg$overall.se,
      p_value = p,
      wald_p = p_wald,
      n_locs = uniqueN(d$loc_id)
    )
  }, error = function(e) {
    cat(sprintf("  %-60s ERROR: %s\n", lbl, e$message))
    NULL
  })
}

specs <- list(
  list(name = "Militia", filter = "stable_Militia"),
  list(name = "Drug", filter = "stable_Drug")
)

outcome_labels <- data.table(
  outcome = c(
    "turnout",
    "top1_valid_per_eligible",
    "other_valid_per_eligible",
    "null_blank_per_eligible",
    "residual_turnout_per_eligible",
    "valid_per_eligible"
  ),
  label = c(
    "Total turnout",
    "Valid votes for local leader / eligible voters",
    "Valid votes for other candidates / eligible voters",
    "Blank and null votes / eligible voters",
    "Residual reported turnout / eligible voters",
    "Valid votes / eligible voters"
  )
)

results <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s, prefeito, NYT ===\n", sp$name))
  d_sp <- dt_faction[change_type == sp$filter & DS_CARGO == "Prefeito"]

  for (oc in outcome_labels$outcome) {
    r <- run_cs(d_sp, oc, sprintf("%s / Prefeito / %s", sp$name, oc))
    if (!is.null(r)) {
      r[, `:=`(spec = sp$name, cargo = "Prefeito", outcome = oc,
               estimator = "NYT")]
      results[[length(results) + 1]] <- r
    }
  }
}

tab <- rbindlist(results, fill = TRUE)
tab <- merge(tab, outcome_labels, by = "outcome", all.x = TRUE)
setcolorder(tab, c("spec", "cargo", "outcome", "label", "estimator",
                   "att", "se", "p_value", "wald_p", "n_locs"))

tab[, `:=`(
  att = round(att, 5),
  se = round(se, 5),
  p_value = round(p_value, 4),
  wald_p = round(wald_p, 4)
)]

fwrite(tab, file.path(OUT_DIR, "tab90_turnout_decomposition.csv"))

cat("\n============================================================\n")
cat("Turnout decomposition, NYT preferred\n")
cat("============================================================\n")
print(tab)
cat("\nWritten: results/tab90_turnout_decomposition.csv\n")
cat("DONE - 90_turnout_decomposition.R\n")
