# ============================================================================
# 74_main_demeaned.R — PREFERRED SPECIFICATION: Municipality-Demeaned Outcomes
# ============================================================================
#
# Primary specification: ỹ_{imt} = y_{imt} - ȳ_{mt}
#   where ȳ_{mt} = mean across all stations in municipality m, election t, cargo
#
# This removes municipality × election-year baselines, isolating within-
# municipality variation attributable to faction territorial control.
#
# Estimators: NYT (preferred) and NT (complementary)
# Unit: voting location (loc_id)
# Weights: qt_aptos (eligible voters)
# Base period: universal
#
# Output:
#   tab74_demeaned_overall.csv    — Overall ATTs + Wald pre-trends
#   tab74_demeaned_es.csv         — Event study coefficients
#   fig74_coefplot_{cargo}_{oc}.pdf — Coefplots (NT vs NYT)
#   fig74_es_{spec}_{cargo}_{oc}.pdf — Event study plots (NYT only)
# ============================================================================

library(data.table)
library(did)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("74_main_demeaned.R — Municipality-Demeaned CS-DID\n")
cat("============================================================\n\n")

# ── 1. Data Loading ─────────────────────────────────────────────────────────

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

# ── 2. Treatment Assignment ────────────────────────────────────────────────

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

# ── 3. Build Panels ────────────────────────────────────────────────────────

# Panel A: faction-only (NYT)
dt_faction <- merge(dt_elec,
            loc_info[, .(loc_id, gvar_cs, change_type, faction_specific)],
            by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

cat(sprintf("Faction panel: %d obs, %d locations, %d municipalities\n",
            nrow(dt_faction), uniqueN(dt_faction$loc_id),
            uniqueN(dt_faction$CD_MUNICIPIO)))

# Panel B: faction + never-treated (NT)
faction_locs <- unique(loc_info$loc_id)
all_elec_locs <- unique(dt_elec$loc_id)
never_locs <- setdiff(all_elec_locs, faction_locs)

nt_info <- data.table(
  loc_id = never_locs,
  gvar_cs = 0L,
  change_type = "never_treated",
  faction_specific = NA_character_
)

loc_info_full <- rbind(
  loc_info[, .(loc_id, gvar_cs, change_type, faction_specific)],
  nt_info
)

dt_full <- merge(dt_elec, loc_info_full, by = "loc_id")
dt_full <- merge(dt_full, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                 by = c("loc_id", "election_year"), all.x = TRUE)
dt_full <- dt_full[election_year %in% elec_years]
dt_full <- dt_full[!is.na(qt_aptos) & qt_aptos > 0]

cat(sprintf("Full panel (+ never-treated): %d obs, %d locations (%d NT)\n\n",
            nrow(dt_full), uniqueN(dt_full$loc_id), length(never_locs)))

# ── 4. Municipality Demeaning ────────────────────────────────────────────────
# ỹ_{imt} = y_{imt} - ȳ_{mt}

outcomes_raw <- c("hhi", "enc", "margin_victory")

cat("--- Municipality Demeaning ---\n")
for (oc in outcomes_raw) {
  dm_col <- paste0(oc, "_dm")
  # Demean on FULL panel (includes never-treated), by municipality × year × cargo
  dt_full[, (dm_col) := get(oc) - mean(get(oc), na.rm = TRUE),
          by = .(CD_MUNICIPIO, election_year, DS_CARGO)]
  # Same for faction-only panel
  dt_faction[, (dm_col) := get(oc) - mean(get(oc), na.rm = TRUE),
             by = .(CD_MUNICIPIO, election_year, DS_CARGO)]
  cat(sprintf("  %s → %s: mean demeaned ≈ %.6f (full), %.6f (faction)\n",
              oc, dm_col,
              mean(dt_full[[dm_col]], na.rm = TRUE),
              mean(dt_faction[[dm_col]], na.rm = TRUE)))
}
cat("\n")

outcomes_dm <- paste0(outcomes_raw, "_dm")

# ── 5. CS-DID Engine ────────────────────────────────────────────────────────

run_csdid <- function(d_run, outcome, lbl, ctrl_group, return_es = FALSE) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]

  n_locs    <- uniqueN(d$loc_id)
  n_cohorts <- uniqueN(d$gvar_cs)

  if (n_cohorts < 2) {
    cat(sprintf("  %-55s SKIP (%d cohort)\n", lbl, n_cohorts))
    return(NULL)
  }

  tryCatch({
    att <- att_gt(
      yname       = outcome,
      tname       = "election_year",
      idname      = "loc_num",
      gname       = "gvar_cs",
      xformla     = ~1,
      data        = as.data.frame(d),
      base_period = "universal",
      control_group = ctrl_group,
      allow_unbalanced_panel = TRUE,
      weightsname = "qt_aptos",
      print_details = FALSE
    )

    agg <- aggte(att, type = "dynamic")
    p   <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))

    # Wald joint test for pre-trends
    pre_idx <- which(agg$egt < 0 & !is.na(agg$se.egt))
    w_stat  <- NA_real_
    p_wald  <- NA_real_
    df_w    <- length(pre_idx)

    if (df_w >= 1) {
      inf_func <- agg$inf.function$dynamic.inf.func.e
      if (!is.null(inf_func) && ncol(inf_func) == length(agg$egt)) {
        n_inf  <- nrow(inf_func)
        v_full <- crossprod(inf_func) / (n_inf^2)
        v_pre  <- v_full[pre_idx, pre_idx, drop = FALSE]
        pre_att <- agg$att.egt[pre_idx]
        tryCatch({
          w_stat <- as.numeric(t(pre_att) %*% solve(v_pre) %*% pre_att)
          p_wald <- 1 - pchisq(w_stat, df = df_w)
        }, error = function(e2) {})
      }
    }

    sig <- ifelse(p < 0.01, "***",
           ifelse(p < 0.05, "**",
           ifelse(p < 0.10, "*", "")))
    wald_str <- ifelse(is.na(p_wald), "NA",
                sprintf("%.4f%s", p_wald,
                        ifelse(p_wald < 0.05, " REJ", " ok")))
    cat(sprintf("  %-55s ATT=%+.4f p=%.3f%s  Wald=%s  N=%d\n",
                lbl, agg$overall.att, p, sig, wald_str, n_locs))

    overall_res <- data.table(
      att       = round(agg$overall.att, 5),
      se        = round(agg$overall.se, 5),
      p_value   = round(p, 4),
      wald_stat = round(w_stat, 3),
      wald_df   = df_w,
      wald_p    = round(p_wald, 4),
      n_locs    = n_locs,
      n_cohorts = n_cohorts
    )

    if (return_es) {
      es_dt <- data.table(
        event_time = agg$egt,
        att_e = agg$att.egt,
        se_e  = agg$se.egt
      )
      es_dt[, ci_lo := att_e - 1.96 * se_e]
      es_dt[, ci_hi := att_e + 1.96 * se_e]
      return(list(overall = overall_res, es = es_dt))
    } else {
      return(overall_res)
    }
  }, error = function(e) {
    cat(sprintf("  %-55s ERROR: %s\n", lbl, substr(e$message, 1, 60)))
    NULL
  })
}

# ── 6. Run All Specifications ──────────────────────────────────────────────

cargos   <- c("Prefeito", "Vereador")

specs <- list(
  list(name = "Militia", filter_type = "stable_Militia"),
  list(name = "Drug",    filter_type = "stable_Drug")
)

all_results <- list()
all_es      <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s (demeaned) ===\n", sp$name))

  d_nyt <- dt_faction[change_type == sp$filter_type]
  d_nt  <- dt_full[change_type == sp$filter_type | change_type == "never_treated"]

  cat(sprintf("  NYT: %d locs | NT: %d locs (%d treated + %d NT)\n",
              uniqueN(d_nyt$loc_id),
              uniqueN(d_nt$loc_id),
              uniqueN(d_nt[change_type != "never_treated"]$loc_id),
              uniqueN(d_nt[change_type == "never_treated"]$loc_id)))
  cat("\n")

  for (cargo in cargos) {
    for (i in seq_along(outcomes_dm)) {
      oc_dm  <- outcomes_dm[i]
      oc_raw <- outcomes_raw[i]

      # NYT (preferred) — with event study
      lbl_nyt <- sprintf("%s / %s / %s [NYT dm]", sp$name, cargo, oc_raw)
      res_nyt <- run_csdid(d_nyt[DS_CARGO == cargo], oc_dm, lbl_nyt,
                           "notyettreated", return_es = TRUE)
      if (!is.null(res_nyt)) {
        res_nyt$overall[, `:=`(spec = sp$name, cargo = cargo, outcome = oc_raw,
                               estimator = "NYT")]
        all_results[[length(all_results) + 1]] <- res_nyt$overall
        es <- res_nyt$es
        es[, `:=`(spec = sp$name, cargo = cargo, outcome = oc_raw,
                  estimator = "NYT")]
        all_es[[length(all_es) + 1]] <- es
      }

      # NT (complementary) — with event study
      lbl_nt <- sprintf("%s / %s / %s [NT dm]", sp$name, cargo, oc_raw)
      res_nt <- run_csdid(d_nt[DS_CARGO == cargo], oc_dm, lbl_nt,
                          "nevertreated", return_es = TRUE)
      if (!is.null(res_nt)) {
        res_nt$overall[, `:=`(spec = sp$name, cargo = cargo, outcome = oc_raw,
                              estimator = "NT")]
        all_results[[length(all_results) + 1]] <- res_nt$overall
        es <- res_nt$es
        es[, `:=`(spec = sp$name, cargo = cargo, outcome = oc_raw,
                  estimator = "NT")]
        all_es[[length(all_es) + 1]] <- es
      }
    }
  }
}

# ── 7. Output Tables ────────────────────────────────────────────────────────

tab <- rbindlist(all_results, fill = TRUE)
setcolorder(tab, c("spec", "cargo", "outcome", "estimator", "att", "se",
                    "p_value", "wald_stat", "wald_df", "wald_p",
                    "n_locs", "n_cohorts"))

fwrite(tab, file.path(OUT_DIR, "tab74_demeaned_overall.csv"))

tab_es <- rbindlist(all_es, fill = TRUE)
fwrite(tab_es, file.path(OUT_DIR, "tab74_demeaned_es.csv"))

# ── 8. Coefficient Plots ─────────────────────────────────────────────────
# Same style as script 70

outcome_labels <- c(
  hhi = "HHI",
  enc = "ENC",
  margin_victory = "Margin of Victory"
)

tab[, ci_lo := att - 1.96 * se]
tab[, ci_hi := att + 1.96 * se]

for (cg in cargos) {
  for (oc in outcomes_raw) {
    d_plot <- tab[cargo == cg & outcome == oc & spec %in% c("Militia", "Drug")]
    if (nrow(d_plot) == 0) next

    d_plot[, spec := factor(spec, levels = c("Militia", "Drug"))]
    d_plot[, x_pos := as.numeric(spec) + ifelse(estimator == "NT", -0.1, 0.1)]

    p <- ggplot(d_plot, aes(x = x_pos, y = att, shape = estimator,
                            fill = estimator, color = estimator)) +
      geom_hline(yintercept = 0, color = "grey70", linetype = "dashed",
                 linewidth = 0.4) +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                    width = 0.12, linewidth = 0.42) +
      geom_point(size = 2.5) +
      scale_x_continuous(breaks = 1:2, labels = c("Militia", "Drug")) +
      scale_shape_manual(values = c("NT" = 22, "NYT" = 24)) +
      scale_fill_manual(values = c("NT" = "black", "NYT" = "grey50")) +
      scale_color_manual(values = c("NT" = "black", "NYT" = "grey50")) +
      labs(y = "ATT (demeaned)", x = NULL) +
      theme_classic(base_size = 11) +
      theme(legend.position = "bottom", legend.title = element_blank())

    fn <- sprintf("fig74_coefplot_%s_%s.pdf", tolower(cg), oc)
    ggsave(file.path(OUT_DIR, fn), p, width = 5, height = 3.5)
  }
}

# ── 9. Event Study Plots (NYT only) ──────────────────────────────────────
# One plot per spec × cargo × outcome, showing dynamic ATT path

for (sp_name in c("Militia", "Drug")) {
  for (cg in cargos) {
    for (oc in outcomes_raw) {
      d_es <- tab_es[spec == sp_name & cargo == cg & outcome == oc &
                     estimator == "NYT"]
      if (nrow(d_es) == 0) next

      d_es[, event_elections := event_time / 4]

      p <- ggplot(d_es, aes(x = event_elections, y = att_e)) +
        geom_hline(yintercept = 0, color = "grey70", linetype = "dashed",
                   linewidth = 0.3) +
        geom_vline(xintercept = -0.5, color = "grey70", linetype = "dashed",
                   linewidth = 0.3) +
        geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                      width = 0.08, linewidth = 0.35) +
        geom_point(size = 1.5) +
        labs(x = "Elections Relative to Treatment",
             y = "ATT (demeaned)",
             title = sprintf("%s — %s — %s", sp_name, cg,
                             outcome_labels[oc])) +
        theme_classic(base_size = 11) +
        theme(plot.title = element_text(size = 11))

      fn <- sprintf("fig74_es_%s_%s_%s.pdf",
                    tolower(sp_name), tolower(cg), oc)
      ggsave(file.path(OUT_DIR, fn), p, width = 7, height = 4.5)
    }
  }
}

# ── 10. Summary ──────────────────────────────────────────────────────────────

cat("\n============================================================\n")
cat("RESULTS — Municipality-Demeaned CS-DID\n")
cat("============================================================\n\n")

cat("--- Overall ATTs (demeaned outcomes) ---\n")
print(tab[, .(spec, cargo, outcome, estimator, att, se, p_value,
              wald_p, n_locs)], nrows = 40)

cat("\n--- Significant (p < 0.10) with clean pre-trends (Wald p > 0.05) ---\n")
sig <- tab[p_value < 0.10 & (wald_p > 0.05 | is.na(wald_p))]
if (nrow(sig) > 0) {
  print(sig[, .(spec, cargo, outcome, estimator, att, p_value, wald_p)],
        nrows = 20)
} else {
  cat("  None\n")
}

cat("\n--- Comparison: Raw vs Demeaned (NYT, Prefeito) ---\n")
cat("                        Raw (script 70)    Demeaned (this script)\n")
cat("  Militia/HHI:          +0.039***          see above\n")
cat("  Militia/ENC:          -0.347***          see above\n")
cat("  Militia/Margin:       +0.052***          see above\n")
cat("  Drug/HHI:             -0.003             see above\n")
cat("  Drug/ENC:             +0.078             see above\n")
cat("  Drug/Margin:          +0.002             see above\n")

cat("\nDONE — 74_main_demeaned.R\n")


