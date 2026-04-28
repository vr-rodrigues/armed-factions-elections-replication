# 78_three_specs_simple.R -- CS-DID aggte(simple): raw, +capital, demeaned

library(data.table)
library(did)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("78_three_specs_simple.R — CS-DID aggte(simple): raw, +capital, demeaned\n")
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

baixada_codes <- c(58041, 58335, 58394, 58149, 58491, 58467,
                   58637, 58696, 58718, 58122, 59013, 58424)

dt_elec[, capital := as.integer(CD_MUNICIPIO == 60011)]
dt_elec[, baixada := as.integer(CD_MUNICIPIO %in% baixada_codes)]

cat("Dummy distribution (unique locations):\n")
print(dt_elec[, .(n_locs = uniqueN(loc_id)), by = .(capital, baixada)][order(-capital, -baixada)])
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
cat("Faction panel by type and dummy:\n")
print(dt_faction[, .(n_locs = uniqueN(loc_id)), by = .(change_type, capital, baixada)][order(change_type, -capital, -baixada)])
cat("\n")

# -- Demean outcomes by municipality-year --------------------------------------
for (oc in c("hhi", "enc", "margin_victory")) {
  dm_col <- paste0(oc, "_dm")
  dt_faction[, (dm_col) := get(oc) - mean(get(oc), na.rm = TRUE),
             by = .(CD_MUNICIPIO, election_year)]
  dt_full[, (dm_col) := get(oc) - mean(get(oc), na.rm = TRUE),
          by = .(CD_MUNICIPIO, election_year)]
}
cat("Demeaned outcomes created

")

# -- 5. CS-DID Engine ---------------------------------------------------------

run_csdid <- function(d_run, outcome, lbl, ctrl_group, xf) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]
  n_locs    <- uniqueN(d$loc_id)
  n_cohorts <- uniqueN(d$gvar_cs)
  if (n_cohorts < 2) {
    cat(sprintf("  %-60s SKIP (%d cohort)\n", lbl, n_cohorts))
    return(NULL)
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
    agg_s <- aggte(att, type = "simple")
    agg_d <- aggte(att, type = "dynamic")
    p   <- 2 * pnorm(-abs(agg_s$overall.att / agg_s$overall.se))
    pre_idx <- which(agg_d$egt < 0 & !is.na(agg_d$se.egt))
    w_stat  <- NA_real_; p_wald <- NA_real_; df_w <- length(pre_idx)
    if (df_w >= 1) {
      inf_func <- agg_d$inf.function$dynamic.inf.func.e
      if (!is.null(inf_func) && ncol(inf_func) == length(agg_d$egt)) {
        n_inf  <- nrow(inf_func)
        v_full <- crossprod(inf_func) / (n_inf^2)
        v_pre  <- v_full[pre_idx, pre_idx, drop = FALSE]
        pre_att <- agg_d$att.egt[pre_idx]
        tryCatch({
          w_stat <- as.numeric(t(pre_att) %*% solve(v_pre) %*% pre_att)
          p_wald <- 1 - pchisq(w_stat, df = df_w)
        }, error = function(e2) {})
      }
    }
    sig <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
    wald_str <- ifelse(is.na(p_wald), "NA",
                sprintf("%.4f%s", p_wald, ifelse(p_wald < 0.05, " REJ", " ok")))
    cat(sprintf("  %-60s ATT=%+.4f p=%.3f%s  Wald=%s  N=%d\n",
                lbl, agg_s$overall.att, p, sig, wald_str, n_locs))
    data.table(
      att = round(agg_s$overall.att, 5), se = round(agg_s$overall.se, 5),
      p_value = round(p, 4), wald_stat = round(w_stat, 3),
      wald_df = df_w, wald_p = round(p_wald, 4),
      n_locs = n_locs, n_cohorts = n_cohorts
    )
  }, error = function(e) {
    cat(sprintf("  %-60s ERROR: %s\n", lbl, substr(e$message, 1, 80)))
    NULL
  })
}

# -- 6. Run All Specifications ------------------------------------------------

outcomes <- c("hhi", "enc", "margin_victory")
cargos   <- c("Prefeito", "Vereador")

faction_specs <- list(
  list(name = "Militia", filter_type = "stable_Militia"),
  list(name = "Drug",    filter_type = "stable_Drug")
)

dummy_specs <- list(
  list(tag = "raw",          xf = ~1,       use_dm = FALSE),
  list(tag = "capital_only", xf = ~capital,  use_dm = FALSE),
  list(tag = "demeaned",     xf = ~1,       use_dm = TRUE)
)

all_results <- list()

for (ds in dummy_specs) {
  cat(sprintf("\n##########################################################\n"))
  cat(sprintf("  DUMMY SPEC: %s\n", ds$tag))
  cat(sprintf("##########################################################\n"))

  for (sp in faction_specs) {
    cat(sprintf("\n=== %s (%s) ===\n", sp$name, ds$tag))
    d_nyt <- dt_faction[change_type == sp$filter_type]
    d_nt  <- dt_full[change_type == sp$filter_type | change_type == "never_treated"]

    n_cap_nyt <- uniqueN(d_nyt$capital)
    n_bai_nyt <- uniqueN(d_nyt$baixada)
    cat(sprintf("  NYT: %d locs (capital var=%d, baixada var=%d)\n",
                uniqueN(d_nyt$loc_id), n_cap_nyt, n_bai_nyt))

    xf_nyt <- ds$xf
    if (ds$tag == "capital_only" && n_cap_nyt < 2) {
      cat("  WARNING: no capital variation in NYT, using ~1\n")
      xf_nyt <- ~1
    }
    cat(sprintf("  NT:  %d locs\n\n", uniqueN(d_nt$loc_id)))

    for (cargo in cargos) {
      for (oc in outcomes) {
        oc_use <- if (isTRUE(ds$use_dm)) paste0(oc, "_dm") else oc
        lbl_nyt <- sprintf("%s/%s/%s [NYT %s]", sp$name, cargo, oc, ds$tag)
        res_nyt <- run_csdid(d_nyt[DS_CARGO == cargo], oc_use, lbl_nyt,
                             "notyettreated", xf_nyt)
        if (!is.null(res_nyt)) {
          res_nyt[, c("spec","cargo","outcome","estimator","dummy_spec") :=
                    list(sp$name, cargo, oc, "NYT", ds$tag)]
          all_results[[length(all_results) + 1]] <- res_nyt
        }

        lbl_nt <- sprintf("%s/%s/%s [NT %s]", sp$name, cargo, oc, ds$tag)
        res_nt <- run_csdid(d_nt[DS_CARGO == cargo], oc_use, lbl_nt,
                            "nevertreated", ds$xf)
        if (!is.null(res_nt)) {
          res_nt[, c("spec","cargo","outcome","estimator","dummy_spec") :=
                   list(sp$name, cargo, oc, "NT", ds$tag)]
          all_results[[length(all_results) + 1]] <- res_nt
        }
      }
    }
  }
}

# -- 7. Output ----------------------------------------------------------------

tab <- rbindlist(all_results, fill = TRUE)
setcolorder(tab, c("dummy_spec", "spec", "cargo", "outcome", "estimator",
                    "att", "se", "p_value", "wald_stat", "wald_df", "wald_p",
                    "n_locs", "n_cohorts"))
fwrite(tab, file.path(OUT_DIR, "tab78_three_specs.csv"))

# -- 8. Coefficient Plots -----------------------------------------------------

tab[, ci_lo := att - 1.96 * se]
tab[, ci_hi := att + 1.96 * se]

for (ds_tag in c("raw", "capital_only", "demeaned")) {
  for (cg in cargos) {
    for (oc in outcomes) {
      d_plot <- tab[dummy_spec == ds_tag & cargo == cg & outcome == oc &
                    spec %in% c("Militia", "Drug")]
      if (nrow(d_plot) == 0) next
      d_plot[, spec := factor(spec, levels = c("Militia", "Drug"))]
      d_plot[, x_pos := as.numeric(spec) * 0.6 + ifelse(estimator == "NT", -0.06, 0.06)]
      p <- ggplot(d_plot, aes(x = x_pos, y = att, shape = estimator,
                              fill = estimator, color = estimator)) +
        geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.4) +
        geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.08, linewidth = 0.5) +
        geom_point(size = 3) +
        scale_x_continuous(breaks = c(0.6, 1.2), labels = c("Militia", "Drug"),
                           limits = c(0.35, 1.45)) +
        scale_shape_manual(values = c("NT" = 22, "NYT" = 24)) +
        scale_fill_manual(values = c("NT" = "black", "NYT" = "grey50")) +
        scale_color_manual(values = c("NT" = "black", "NYT" = "grey50")) +
        labs(y = "ATT", x = NULL) +
        theme_classic(base_size = 13) +
        theme(legend.position = "bottom", legend.title = element_blank(),
              plot.margin = margin(5, 8, 5, 5))
      fn <- sprintf("fig78_%s_coefplot_%s_%s.pdf", ds_tag, tolower(cg), oc)
      ggsave(file.path(OUT_DIR, fn), p, width = 3, height = 4)
    }
  }
}

# -- 9. Summary ---------------------------------------------------------------

cat("\n============================================================\n")
cat("RESULTS\n")
cat("============================================================\n\n")

for (ds_tag in c("raw", "capital_only", "demeaned")) {
  cat(sprintf("--- %s ---\n", ds_tag))
  print(tab[dummy_spec == ds_tag,
            .(spec, cargo, outcome, estimator, att, se, p_value, wald_p, n_locs)], nrows = 30)
  cat("\n")
}

cat("--- Significant (p < 0.10) with clean pre-trends (Wald p > 0.05) ---\n")
sig <- tab[p_value < 0.10 & (wald_p > 0.05 | is.na(wald_p))]
if (nrow(sig) > 0) {
  print(sig[, .(dummy_spec, spec, cargo, outcome, estimator, att, p_value, wald_p)], nrows = 30)
} else {
  cat("  None\n")
}

cat("\nDONE -- 78_three_specs_simple.R\n")


