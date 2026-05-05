# ============================================================================
# 88_turnout_outcome.R — Turnout as a 4th Outcome
# ============================================================================
#
# Motivation (Blattman 2009 APSR "From Violence to Voting"): violence exposure
# increases turnout through "expressive voting." In our setting, militia
# territorial expansion could either:
#   (a) raise turnout via coercive mobilization (militia delivers concentrated
#       votes to allied candidates — so turnout AND concentration both rise); or
#   (b) reduce turnout via voter suppression (citizens stay home out of fear).
#
# Testing turnout as an additional outcome distinguishes these mechanisms:
#   - If turnout ↑ and HHI ↑ jointly → coercive mobilization dominates.
#   - If turnout ↓ → suppression dominates.
#   - If turnout unchanged and HHI ↑ → compositional effect (who votes shifts
#     but aggregate participation is stable).
#
# Turnout = total_votes / qt_aptos (TSE standard).
#
# Output:
#   tab88_turnout_overall.csv  — ATTs per spec × cargo (NYT + NT)
#   tab88_turnout_es.csv       — Event-study coefficients
#   fig88_es_*.pdf             — Event-study plots
# ============================================================================

library(data.table)
library(did)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("88_turnout_outcome.R — Turnout as 4th Outcome\n")
cat("============================================================\n\n")

# ── 1. Data loading ─────────────────────────────────────────────────────────

dt_elec  <- fread(file.path(BASE_DIR, "data", "electoral_competition_measures.csv"))
dt_aptos <- fread(file.path(BASE_DIR, "data", "qt_aptos_by_location.csv"))
dt_treat <- fread(file.path(BASE_DIR, "data", "locais_votacao_treatment_annual.csv"))
dt_chg   <- fread(file.path(BASE_DIR, "data", "loc_faction_changes.csv"))

dt_elec[, loc_id := as.character(loc_id)]
dt_elec[, DS_CARGO := tools::toTitleCase(tolower(trimws(DS_CARGO)))]
dt_elec[, election_year := as.numeric(election_year)]
dt_elec[, total_votes := as.numeric(total_votes)]
dt_aptos[, loc_id := as.character(loc_id)]
dt_aptos[, election_year := as.numeric(election_year)]
dt_aptos[, qt_aptos := as.numeric(qt_aptos)]
dt_treat[, loc_id := as.character(loc_id)]
dt_chg[, loc_id := as.character(loc_id)]

# Merge turnout: total_votes / qt_aptos
dt_elec <- merge(dt_elec, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                 by = c("loc_id", "election_year"), all.x = TRUE)
dt_elec[, turnout := total_votes / qt_aptos]
dt_elec[is.na(turnout) | is.infinite(turnout) | turnout > 1 | turnout <= 0,
        turnout := NA_real_]

cat("Turnout summary (prefeito, all stations):\n")
print(dt_elec[DS_CARGO == "Prefeito", .(
  mean = mean(turnout, na.rm = TRUE),
  sd   = sd(turnout, na.rm = TRUE),
  n    = sum(!is.na(turnout))
), by = election_year][order(election_year)])

elec_years <- c(2008, 2012, 2016, 2020, 2024)

# ── 2. Treatment assignment (same as 79/80) ────────────────────────────────

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

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

# Panel
dt <- merge(dt_elec, loc_info, by = "loc_id")
dt <- dt[election_year %in% elec_years]
dt <- dt[!is.na(turnout) & !is.na(qt_aptos) & qt_aptos > 0]

# Full panel (+ never treated) for NT spec
faction_locs <- unique(loc_info$loc_id)
nt_info <- data.table(
  loc_id = setdiff(unique(dt_elec$loc_id), faction_locs),
  gvar_cs = 0L,
  change_type = "never_treated"
)
dt_full <- rbind(
  dt[, .(loc_id, gvar_cs, change_type)],
  nt_info
)
dt_full <- unique(dt_full, by = "loc_id")

dt_full_panel <- merge(dt_elec, dt_full, by = "loc_id")
dt_full_panel <- dt_full_panel[election_year %in% elec_years]
dt_full_panel <- dt_full_panel[!is.na(turnout) & !is.na(qt_aptos) & qt_aptos > 0]

# ── 3. CS-DID engine ────────────────────────────────────────────────────────

run_cs <- function(d_run, outcome, lbl, ctrl_group) {
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
    agg <- aggte(att, type = "dynamic", na.rm = TRUE)
    p <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))

    # Wald pre-trends
    dyn <- agg
    pre_idx <- which(dyn$egt < 0 & !is.na(dyn$se.egt))
    p_wald <- NA_real_
    if (length(pre_idx) >= 1) {
      inf_func <- dyn$inf.function$dynamic.inf.func.e
      if (!is.null(inf_func) && ncol(inf_func) == length(dyn$egt)) {
        n_inf <- nrow(inf_func)
        v_full <- crossprod(inf_func) / (n_inf^2)
        v_pre <- v_full[pre_idx, pre_idx, drop = FALSE]
        pre_att <- dyn$att.egt[pre_idx]
        tryCatch({
          w <- as.numeric(t(pre_att) %*% solve(v_pre) %*% pre_att)
          p_wald <- 1 - pchisq(w, df = length(pre_idx))
        }, error = function(e) {})
      }
    }

    es_dt <- data.table(
      event_time = dyn$egt, att_e = dyn$att.egt, se_e = dyn$se.egt
    )
    es_dt <- es_dt[!(event_time != -4 & is.na(se_e))]
    es_dt[, ci_lo := att_e - 1.96 * se_e]
    es_dt[, ci_hi := att_e + 1.96 * se_e]

    sig <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
    cat(sprintf("  %-40s ATT=%+.4f (SE %.4f) p=%.4f%s  Wald=%.3f  N=%d\n",
                lbl, agg$overall.att, agg$overall.se, p, sig, p_wald, uniqueN(d$loc_id)))

    list(
      overall = data.table(att = agg$overall.att, se = agg$overall.se,
                           p = p, wald_p = p_wald, n_locs = uniqueN(d$loc_id)),
      es = es_dt
    )
  }, error = function(e) { cat(sprintf("  %-40s ERROR: %s\n", lbl, e$message)); NULL })
}

# ── 4. Run all specs ────────────────────────────────────────────────────────

# Turnout is a station-election outcome, not office-specific. Keep it under
# Prefeito to avoid mechanically duplicating the same result under Vereador.
cargos <- c("Prefeito")
specs <- list(
  list(name = "Militia", filter = "stable_Militia"),
  list(name = "Drug",    filter = "stable_Drug")
)

res_overall <- list()
res_es      <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$name))

  d_nyt <- dt[change_type == sp$filter]
  d_nt  <- dt_full_panel[change_type %in% c(sp$filter, "never_treated")]

  for (cg in cargos) {
    # NYT
    r <- run_cs(d_nyt[DS_CARGO == cg], "turnout",
                sprintf("%s / %s / turnout [NYT]", sp$name, cg), "notyettreated")
    if (!is.null(r)) {
      r$overall[, `:=`(spec = sp$name, cargo = cg, outcome = "turnout", estimator = "NYT")]
      r$es[, `:=`(spec = sp$name, cargo = cg, outcome = "turnout", estimator = "NYT")]
      res_overall[[length(res_overall) + 1]] <- r$overall
      res_es[[length(res_es) + 1]] <- r$es
    }
    # NT
    r <- run_cs(d_nt[DS_CARGO == cg], "turnout",
                sprintf("%s / %s / turnout [NT]", sp$name, cg), "nevertreated")
    if (!is.null(r)) {
      r$overall[, `:=`(spec = sp$name, cargo = cg, outcome = "turnout", estimator = "NT")]
      r$es[, `:=`(spec = sp$name, cargo = cg, outcome = "turnout", estimator = "NT")]
      res_overall[[length(res_overall) + 1]] <- r$overall
      res_es[[length(res_es) + 1]] <- r$es
    }
  }
}

tab_overall <- rbindlist(res_overall)
tab_es <- rbindlist(res_es)
fwrite(tab_overall, file.path(OUT_DIR, "tab88_turnout_overall.csv"))
fwrite(tab_es, file.path(OUT_DIR, "tab88_turnout_es.csv"))

cat("\n============================================================\n")
cat("Turnout ATTs summary (NYT = preferred):\n")
print(tab_overall[estimator == "NYT"])
cat("\n============================================================\n")

# ── 5. Event-study plots ────────────────────────────────────────────────────

for (sp in c("Militia", "Drug")) {
  for (cg in cargos) {
    d_plot <- tab_es[spec == sp & cargo == cg & estimator == "NYT"]
    if (nrow(d_plot) == 0) next
    d_plot[, event_elections := event_time / 4]
    is_ref <- d_plot$event_time == -4

    p <- ggplot() +
      geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.3) +
      geom_vline(xintercept = -0.5, color = "grey70", linetype = "dashed", linewidth = 0.3) +
      geom_errorbar(data = d_plot[!is_ref],
                    aes(x = event_elections, ymin = ci_lo, ymax = ci_hi),
                    width = 0.08, linewidth = 0.4) +
      geom_point(data = d_plot[!is_ref],
                 aes(x = event_elections, y = att_e), size = 2) +
      geom_point(data = d_plot[is_ref],
                 aes(x = event_elections, y = att_e),
                 size = 2.5, shape = 21, fill = "white", stroke = 0.6) +
      labs(x = "Elections Relative to Treatment", y = "ATT on Turnout",
           title = sprintf("%s \u2014 %s \u2014 Turnout", sp, cg)) +
      scale_x_continuous(breaks = seq(-3, 1, 1)) +
      theme_classic(base_size = 11)

    fn <- sprintf("fig88_es_%s_%s_turnout.pdf", tolower(sp), tolower(cg))
    ggsave(file.path(OUT_DIR, fn), p, width = 6, height = 4)
  }
}

cat(sprintf("\nWritten: tab88_turnout_overall.csv, tab88_turnout_es.csv, %d fig88_es_*.pdf\n",
            2 * length(cargos)))
cat("DONE — 88_turnout_outcome.R\n")


