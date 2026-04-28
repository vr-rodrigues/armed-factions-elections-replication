# ============================================================================
# 75_results_region_dummies.R — CS-DID with region dummies (capital/baixada/other)
# ============================================================================
#
# Instead of municipality demeaning, add region dummies to xformla:
#   xformla = ~baixada + other_metro  (capital = reference)
#
# Classification:
#   Capital:  Rio de Janeiro (60011)
#   Baixada:  Nova Iguaçu, Duque de Caxias, SJMeriti, Magé, Belford Roxo,
#             Nilópolis, Mesquita, Queimados, Japeri, Paracambi
#   Other:    Petrópolis, Niterói, São Gonçalo, Itaboraí, Maricá,
#             Cachoeiras de Macacu, Itaguaí, Seropédica, Rio Bonito
# ============================================================================

library(data.table)
library(did)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("75_results_region_dummies.R — CS-DID with region dummies\n")
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

# ── 2. Region Classification ────────────────────────────────────────────────

baixada_codes <- c(58696, 58335, 59013, 58491, 58041,
                   58637, 58467, 58122, 58149, 58718)

dt_elec[, region := fifelse(CD_MUNICIPIO == 60011, "capital",
                   fifelse(CD_MUNICIPIO %in% baixada_codes, "baixada",
                           "other_metro"))]
dt_elec[, baixada    := as.integer(region == "baixada")]
dt_elec[, other_metro := as.integer(region == "other_metro")]

cat("Region distribution (unique locations):\n")
print(dt_elec[, .(n_locs = uniqueN(loc_id)), by = region])
cat("\n")

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

loc_faction_spec <- dt_treat[inside_controle == 1,
  .(faction_specific = faction_type_controle[1]), by = loc_id]
loc_faction_spec[faction_specific %in% c("Milícia", "Milicia"),
                 faction_specific := "Militia"]

loc_info <- merge(
  dt_chg[change_type %in% c("stable_Militia", "stable_Drug")],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id", all.x = TRUE
)
loc_info <- merge(loc_info, loc_faction_spec, by = "loc_id", all.x = TRUE)

# ── 4. Build Panels ────────────────────────────────────────────────────────

# Faction-only (NYT)
dt_faction <- merge(dt_elec,
            loc_info[, .(loc_id, gvar_cs, change_type, faction_specific)],
            by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
            by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

cat(sprintf("Faction panel: %d obs, %d locations\n",
            nrow(dt_faction), uniqueN(dt_faction$loc_id)))

# Faction + never-treated (NT)
faction_locs <- unique(loc_info$loc_id)
never_locs <- setdiff(unique(dt_elec$loc_id), faction_locs)

nt_info <- data.table(
  loc_id = never_locs, gvar_cs = 0L,
  change_type = "never_treated", faction_specific = NA_character_
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

cat(sprintf("Full panel: %d obs, %d locations (%d NT)\n\n",
            nrow(dt_full), uniqueN(dt_full$loc_id), length(never_locs)))

# Region distribution by faction type
cat("Region distribution by faction type:\n")
print(dt_faction[, .(n = uniqueN(loc_id)), by = .(change_type, region)])
cat("\n")

# ── 5. CS-DID Engine ────────────────────────────────────────────────────────

run_csdid <- function(d_run, outcome, lbl, ctrl_group, use_region = TRUE) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]

  n_locs    <- uniqueN(d$loc_id)
  n_cohorts <- uniqueN(d$gvar_cs)

  if (n_cohorts < 2) {
    cat(sprintf("  %-55s SKIP (%d cohort)\n", lbl, n_cohorts))
    return(NULL)
  }

  # Check region variation
  xf <- ~1
  if (use_region) {
    n_regions <- uniqueN(d$region)
    if (n_regions >= 2) {
      xf <- ~baixada + other_metro
    } else {
      cat(sprintf("  %-55s single region, using xformla=~1\n", lbl))
    }
  }

  tryCatch({
    att <- att_gt(
      yname       = outcome,
      tname       = "election_year",
      idname      = "loc_num",
      gname       = "gvar_cs",
      xformla     = xf,
      data        = as.data.frame(d),
      base_period = "universal",
      control_group = ctrl_group,
      allow_unbalanced_panel = TRUE,
      weightsname = "qt_aptos",
      print_details = FALSE
    )

    agg <- aggte(att, type = "dynamic")
    p   <- 2 * pnorm(-abs(agg$overall.att / agg$overall.se))

    # Wald pre-trends
    pre_idx <- which(agg$egt < 0 & !is.na(agg$se.egt))
    w_stat  <- NA_real_; p_wald <- NA_real_; df_w <- length(pre_idx)

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
    cat(sprintf("  %-55s ERROR: %s\n", lbl, substr(e$message, 1, 80)))
    NULL
  })
}

# ── 6. Run All Specifications ──────────────────────────────────────────────

outcomes <- c("hhi", "enc", "margin_victory")
cargos   <- c("Prefeito", "Vereador")

specs <- list(
  list(name = "Militia", filter_type = "stable_Militia"),
  list(name = "Drug",    filter_type = "stable_Drug")
)

all_results <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s (with region dummies) ===\n", sp$name))

  d_nyt <- dt_faction[change_type == sp$filter_type]
  d_nt  <- dt_full[change_type == sp$filter_type | change_type == "never_treated"]

  cat(sprintf("  NYT: %d locs | NT: %d locs\n",
              uniqueN(d_nyt$loc_id), uniqueN(d_nt$loc_id)))
  cat(sprintf("  NYT region: capital=%d, baixada=%d, other=%d\n",
              uniqueN(d_nyt[region == "capital"]$loc_id),
              uniqueN(d_nyt[region == "baixada"]$loc_id),
              uniqueN(d_nyt[region == "other_metro"]$loc_id)))
  cat("\n")

  for (cargo in cargos) {
    for (oc in outcomes) {
      # NYT
      lbl_nyt <- sprintf("%s / %s / %s [NYT region]", sp$name, cargo, oc)
      res_nyt <- run_csdid(d_nyt[DS_CARGO == cargo], oc, lbl_nyt,
                           "notyettreated", use_region = TRUE)
      if (!is.null(res_nyt)) {
        res_nyt[, `:=`(spec = sp$name, cargo = cargo, outcome = oc,
                       estimator = "NYT")]
        all_results[[length(all_results) + 1]] <- res_nyt
      }

      # NT
      lbl_nt <- sprintf("%s / %s / %s [NT region]", sp$name, cargo, oc)
      res_nt <- run_csdid(d_nt[DS_CARGO == cargo], oc, lbl_nt,
                          "nevertreated", use_region = TRUE)
      if (!is.null(res_nt)) {
        res_nt[, `:=`(spec = sp$name, cargo = cargo, outcome = oc,
                      estimator = "NT")]
        all_results[[length(all_results) + 1]] <- res_nt
      }
    }
  }
}

# ── 7. Output ──────────────────────────────────────────────────────────────

tab <- rbindlist(all_results, fill = TRUE)
setcolorder(tab, c("spec", "cargo", "outcome", "estimator", "att", "se",
                    "p_value", "wald_stat", "wald_df", "wald_p",
                    "n_locs", "n_cohorts"))

fwrite(tab, file.path(OUT_DIR, "tab75_region_dummies.csv"))

# ── 8. Coefficient Plots ─────────────────────────────────────────────────

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
      geom_hline(yintercept = 0, color = "grey70", linetype = "dashed",
                 linewidth = 0.4) +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                    width = 0.12, linewidth = 0.42) +
      geom_point(size = 2.5) +
      scale_x_continuous(breaks = 1:2, labels = c("Militia", "Drug")) +
      scale_shape_manual(values = c("NT" = 22, "NYT" = 24)) +
      scale_fill_manual(values = c("NT" = "black", "NYT" = "grey50")) +
      scale_color_manual(values = c("NT" = "black", "NYT" = "grey50")) +
      labs(y = "ATT", x = NULL) +
      theme_classic(base_size = 11) +
      theme(legend.position = "bottom", legend.title = element_blank())

    fn <- sprintf("fig75_coefplot_%s_%s.pdf", tolower(cg), oc)
    ggsave(file.path(OUT_DIR, fn), p, width = 5, height = 3.5)
  }
}

# ── 9. Summary ──────────────────────────────────────────────────────────────

cat("\n============================================================\n")
cat("RESULTS — CS-DID with Region Dummies\n")
cat("============================================================\n\n")

cat("--- Overall ATTs ---\n")
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

cat("\n--- Comparison (Militia/Prefeito/NYT): ---\n")
cat("  Spec                HHI         ENC         Margin\n")
cat("  Raw (script 70):    +0.039***   -0.347***   +0.052***\n")
cat("  Demeaned (74):      +0.004      -0.102**    +0.016*\n")
cat("  Region dum (75):    see above\n")

cat("\nDONE — 75_results_region_dummies.R\n")


