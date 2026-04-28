# ============================================================================
# 72_rj_capital_results.R — RJ CAPITAL ONLY: CS-DID NT vs NYT
# ============================================================================
#
# Same methodology as 70_main_results.R but restricted to
# RJ capital (CD_MUNICIPIO == 60011, TSE code).
#
# Output:
#   tab72_rj_capital_overall.csv          — Overall ATTs + Wald pre-trends
#   fig72_coefplot_{cargo}_{outcome}.pdf  — Coefficient plots (NT vs NYT)
# ============================================================================

library(data.table)
library(did)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("72_rj_capital_results.R — CS-DID NT vs NYT (RJ Capital)\n")
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

# Type coercion
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

# ── 2. Filter to RJ Capital ────────────────────────────────────────────────

rj_locs <- unique(dt_treat[CD_MUNICIPIO == 60011]$loc_id)
cat(sprintf("RJ Capital voting locations: %d\n", length(rj_locs)))

# Filter all datasets to RJ capital locations
dt_elec  <- dt_elec[loc_id %in% rj_locs]
dt_aptos <- dt_aptos[loc_id %in% rj_locs]

# ── 3. Treatment Assignment ────────────────────────────────────────────────

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

# Specific faction from first inside observation
loc_faction_spec <- dt_treat[inside_controle == 1,
  .(faction_specific = faction_type_controle[1]), by = loc_id]
loc_faction_spec[faction_specific %in% c("Milícia", "Milicia"),
                 faction_specific := "Militia"]

# Faction locations: classification + gvar + specific faction
loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id", all.x = TRUE
)
loc_info <- merge(loc_info, loc_faction_spec, by = "loc_id", all.x = TRUE)

# Filter to RJ capital
loc_info <- loc_info[loc_id %in% rj_locs]

# ── 4. Build Panels ────────────────────────────────────────────────────────

# Panel A: faction-only (for NYT) — RJ capital
dt_faction <- merge(dt_elec,
            loc_info[, .(loc_id, gvar_cs, change_type, faction_specific)],
            by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

cat(sprintf("Faction panel (RJ Capital): %d obs, %d locations\n",
            nrow(dt_faction), uniqueN(dt_faction$loc_id)))

# Breakdown
rj_militia_n <- uniqueN(dt_faction[change_type == "stable_Militia"]$loc_id)
rj_drug_n    <- uniqueN(dt_faction[change_type == "stable_Drug"]$loc_id)
cat(sprintf("  Militia: %d   Drug: %d\n", rj_militia_n, rj_drug_n))

# Panel B: faction + never-treated (for NT) — RJ capital
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

cat(sprintf("Full panel (+ never-treated, RJ Capital): %d obs, %d locations (%d never-treated)\n\n",
            nrow(dt_full), uniqueN(dt_full$loc_id), length(never_locs)))

# ── 5. CS-DID Engine ────────────────────────────────────────────────────────

run_csdid <- function(d_run, outcome, lbl, ctrl_group) {
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

    data.table(
      att       = round(agg$overall.att, 5),
      se        = round(agg$overall.se, 5),
      p_value   = round(p, 4),
      wald_stat = round(w_stat, 3),
      wald_df   = df_w,
      wald_p    = round(p_wald, 4),
      n_locs    = n_locs,
      n_cohorts = n_cohorts
    )
  }, error = function(e) {
    cat(sprintf("  %-55s ERROR: %s\n", lbl, substr(e$message, 1, 60)))
    NULL
  })
}

# ── 6. Run All Specifications ──────────────────────────────────────────────

outcomes <- c("hhi", "enc", "margin_victory")
cargos   <- c("Prefeito", "Vereador")

specs <- list(
  list(name = "Militia", filter_type = "stable_Militia",
       filter_specific = NULL),
  list(name = "Drug",    filter_type = "stable_Drug",
       filter_specific = NULL)
)

all_results <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$name))

  # --- NYT: faction-only ---
  d_nyt <- dt_faction[change_type == sp$filter_type]
  if (!is.null(sp$filter_specific))
    d_nyt <- d_nyt[faction_specific == sp$filter_specific]

  cat(sprintf("  NYT sample: %d locs\n", uniqueN(d_nyt$loc_id)))

  # --- NT: faction + never-treated ---
  d_nt <- dt_full[change_type == sp$filter_type | change_type == "never_treated"]
  if (!is.null(sp$filter_specific))
    d_nt <- d_nt[faction_specific == sp$filter_specific | change_type == "never_treated"]

  cat(sprintf("  NT  sample: %d locs (%d treated + %d never-treated)\n",
              uniqueN(d_nt$loc_id),
              uniqueN(d_nt[change_type != "never_treated"]$loc_id),
              uniqueN(d_nt[change_type == "never_treated"]$loc_id)))
  cat("\n")

  for (cargo in cargos) {
    for (oc in outcomes) {
      # NYT
      lbl_nyt <- sprintf("%s / %s / %s [NYT]", sp$name, cargo, oc)
      res_nyt <- run_csdid(d_nyt[DS_CARGO == cargo], oc, lbl_nyt, "notyettreated")
      if (!is.null(res_nyt)) {
        res_nyt[, `:=`(spec = sp$name, cargo = cargo, outcome = oc,
                       estimator = "NYT")]
        all_results[[length(all_results) + 1]] <- res_nyt
      }

      # NT
      lbl_nt <- sprintf("%s / %s / %s [NT]", sp$name, cargo, oc)
      res_nt <- run_csdid(d_nt[DS_CARGO == cargo], oc, lbl_nt, "nevertreated")
      if (!is.null(res_nt)) {
        res_nt[, `:=`(spec = sp$name, cargo = cargo, outcome = oc,
                      estimator = "NT")]
        all_results[[length(all_results) + 1]] <- res_nt
      }
    }
  }
}

# ── 7. Output Table ────────────────────────────────────────────────────────

tab <- rbindlist(all_results, fill = TRUE)
setcolorder(tab, c("spec", "cargo", "outcome", "estimator", "att", "se",
                    "p_value", "wald_stat", "wald_df", "wald_p",
                    "n_locs", "n_cohorts"))

fwrite(tab, file.path(OUT_DIR, "tab72_rj_capital_overall.csv"))

# ── 8. Coefficient Plots ─────────────────────────────────────────────────
# Same style as script 70: NT = black square, NYT = grey triangle

outcome_labels <- c(
  hhi = "HHI",
  enc = "ENC",
  margin_victory = "Margin of Victory"
)

tab[, ci_lo := att - 1.96 * se]
tab[, ci_hi := att + 1.96 * se]

for (cg in cargos) {
  for (oc in outcomes) {
    d_plot <- tab[cargo == cg & outcome == oc & spec %in% c("Militia", "Drug")]
    if (nrow(d_plot) == 0) next

    d_plot[, spec := factor(spec, levels = c("Militia", "Drug"))]
    d_plot[, x_pos := as.numeric(spec) + ifelse(estimator == "NT", -0.1, 0.1)]

    p <- ggplot(d_plot, aes(x = x_pos, y = att, shape = estimator,
                            fill = estimator, color = estimator)) +
      geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.4) +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                    width = 0.12, linewidth = 0.42) +
      geom_point(size = 2.5) +
      scale_x_continuous(
        breaks = 1:2,
        labels = c("Militia", "Drug")
      ) +
      scale_shape_manual(values = c("NT" = 22, "NYT" = 24)) +
      scale_fill_manual(values = c("NT" = "black", "NYT" = "grey50")) +
      scale_color_manual(values = c("NT" = "black", "NYT" = "grey50")) +
      labs(y = "ATT", x = NULL) +
      theme_classic(base_size = 11) +
      theme(legend.position = "bottom", legend.title = element_blank())

    fn <- sprintf("fig72_coefplot_%s_%s.pdf", tolower(cg), oc)
    ggsave(file.path(OUT_DIR, fn), p, width = 5, height = 3.5)
  }
}

# ── 9. Summary ──────────────────────────────────────────────────────────────

cat("\n============================================================\n")
cat("RJ CAPITAL — CS-DID NT vs NYT\n")
cat("============================================================\n\n")

cat("--- Overall ATTs ---\n")
print(tab[, .(spec, cargo, outcome, estimator, att, se, p_value,
              wald_p, n_locs)], nrows = 40)

cat("\n--- Significant results (p < 0.10) with clean pre-trends (Wald p > 0.05) ---\n")
sig <- tab[p_value < 0.10 & (wald_p > 0.05 | is.na(wald_p))]
if (nrow(sig) > 0) {
  print(sig[, .(spec, cargo, outcome, estimator, att, p_value, wald_p)], nrows = 20)
} else {
  cat("  None\n")
}

cat("\nDONE — 72_rj_capital_results.R\n")


