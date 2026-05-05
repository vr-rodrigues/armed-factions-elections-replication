# ============================================================================
# 89_dynamic_agg_all.R — Dynamic Aggregation for All Specifications
# ============================================================================
# Produces overall ATTs via aggte(type = "dynamic") for:
#   - {Militia, Drug} x {Prefeito, Vereador} x {HHI, ENC, Margin}
#   - {Militia, Drug} x {Prefeito} x {Turnout}
#   - Both NYT and NT control groups
# Reports ATT, SE, p-value, Wald pre-trends p, and N for each cell.
# Output: tab89_dynamic_overall.csv
# ============================================================================

library(data.table)
library(did)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("89_dynamic_agg_all.R — Dynamic ATTs for all specs\n")
cat("============================================================\n\n")

# Data pipeline (same as 70/79)
dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
for (col in c("hhi", "enc", "margin_victory"))
  dt_elec[, (col) := as.numeric(get(col))]
dt_elec[, total_votes := as.numeric(total_votes)]
dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]

# Turnout
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
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

# Faction-only panel (for NYT)
dt_faction <- merge(dt_elec, loc_info[, .(loc_id, gvar_cs, change_type)], by = "loc_id")
dt_faction <- dt_faction[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]

# Full panel + never-treated (for NT)
faction_locs <- unique(loc_info$loc_id)
never_locs <- setdiff(unique(dt_elec$loc_id), faction_locs)
nt_info <- data.table(loc_id = never_locs, gvar_cs = 0L, change_type = "never_treated")
loc_info_full <- rbind(loc_info[, .(loc_id, gvar_cs, change_type)], nt_info)
dt_full <- merge(dt_elec, loc_info_full, by = "loc_id")
dt_full <- dt_full[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]

# Engine
run_cs <- function(d_run, outcome, ctrl_group, lbl) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]
  if (uniqueN(d$gvar_cs) < 2) return(NULL)
  tryCatch({
    att <- att_gt(
      yname = outcome, tname = "election_year", idname = "loc_num",
      gname = "gvar_cs", xformla = ~1, data = as.data.frame(d),
      base_period = "universal", control_group = ctrl_group,
      allow_unbalanced_panel = TRUE, weightsname = "qt_aptos",
      print_details = FALSE
    )
    # Dynamic aggregation (always)
    agg <- aggte(att, type = "dynamic", na.rm = TRUE)
    p <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))

    # Wald pre-trends
    pre_idx <- which(agg$egt < 0 & !is.na(agg$se.egt))
    p_wald <- NA_real_
    if (length(pre_idx) >= 1) {
      inf_func <- agg$inf.function$dynamic.inf.func.e
      if (!is.null(inf_func) && ncol(inf_func) == length(agg$egt)) {
        n_inf <- nrow(inf_func)
        v_full <- crossprod(inf_func) / (n_inf^2)
        v_pre <- v_full[pre_idx, pre_idx, drop = FALSE]
        pre_att <- agg$att.egt[pre_idx]
        tryCatch({
          w <- as.numeric(t(pre_att) %*% solve(v_pre) %*% pre_att)
          p_wald <- 1 - pchisq(w, df = length(pre_idx))
        }, error = function(e) {})
      }
    }
    sig <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
    cat(sprintf("  %-55s ATT=%+.4f (SE %.4f) p=%.3f%s  Wald=%s  N=%d\n",
                lbl, agg$overall.att, agg$overall.se, p, sig,
                ifelse(is.na(p_wald), "NA", sprintf("%.3f", p_wald)),
                uniqueN(d$loc_id)))
    data.table(
      att = round(agg$overall.att, 5),
      se  = round(agg$overall.se, 5),
      p_value = round(p, 4),
      wald_p  = round(p_wald, 4),
      n_locs  = uniqueN(d$loc_id)
    )
  }, error = function(e) {
    cat(sprintf("  %-55s ERROR: %s\n", lbl, substr(e$message, 1, 50))); NULL
  })
}

# Run all specs
specs    <- list(list(name = "Militia", filter = "stable_Militia"),
                 list(name = "Drug",    filter = "stable_Drug"))
cargos   <- c("Prefeito", "Vereador")
outcomes <- c("hhi", "enc", "margin_victory", "turnout")

results <- list()
for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$name))
  d_nyt <- dt_faction[change_type == sp$filter]
  d_nt  <- dt_full[change_type %in% c(sp$filter, "never_treated")]
  for (cg in cargos) {
    for (oc in outcomes) {
      # Turnout is a station-election participation measure. Report it once
      # with Prefeito and skip the mechanically duplicated Vereador cell.
      if (oc == "turnout" && cg == "Vereador") next

      lbl <- sprintf("%s / %s / %s [NYT]", sp$name, cg, oc)
      r <- run_cs(d_nyt[DS_CARGO == cg], oc, "notyettreated", lbl)
      if (!is.null(r)) {
        r[, `:=`(spec = sp$name, cargo = cg, outcome = oc, estimator = "NYT")]
        results[[length(results) + 1]] <- r
      }

      lbl <- sprintf("%s / %s / %s [NT]",  sp$name, cg, oc)
      r <- run_cs(d_nt[DS_CARGO == cg], oc, "nevertreated", lbl)
      if (!is.null(r)) {
        r[, `:=`(spec = sp$name, cargo = cg, outcome = oc, estimator = "NT")]
        results[[length(results) + 1]] <- r
      }
    }
  }
}

tab <- rbindlist(results, fill = TRUE)
setcolorder(tab, c("spec", "cargo", "outcome", "estimator",
                   "att", "se", "p_value", "wald_p", "n_locs"))
fwrite(tab, file.path(OUT_DIR, "tab89_dynamic_overall.csv"))

cat("\n============================================================\n")
cat("Summary — Dynamic ATTs (NYT preferred)\n")
cat("============================================================\n")
print(tab[estimator == "NYT"])
cat("\n============================================================\n")
cat("Summary — Dynamic ATTs (NT)\n")
cat("============================================================\n")
print(tab[estimator == "NT"])
cat("\nDONE — 89_dynamic_agg_all.R\n")


