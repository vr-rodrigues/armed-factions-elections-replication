# ============================================================================
# 80_honest_did.R — Honest-DiD / Rambachan-Roth Sensitivity Analysis
# ============================================================================
#
# For each of the three militia/prefeito cells (HHI, ENC, margin_victory),
# compute the "breakdown" M-bar: the multiple of the largest observed
# pre-treatment slope that would have to hold in the post-treatment period
# to reverse the sign of (or nullify statistical significance of) the ATT.
#
# Implementation uses the HonestDiD package. We follow the example in the
# package vignette: extract influence function (inf.function) from the CS-DID
# aggregated event-study, feed it to createSensitivityResults_relativeMagnitudes.
#
# Output:
#   tab80_honest_did.csv         — breakdown M-bar per cell
#   fig80_honest_{oc}.pdf        — sensitivity plots per outcome
# ============================================================================

library(data.table)
library(did)

# Install HonestDiD if needed: remotes::install_github("asheshrambachan/HonestDiD")
if (!requireNamespace("HonestDiD", quietly = TRUE)) {
  stop("HonestDiD not installed. Run: remotes::install_github('asheshrambachan/HonestDiD')")
}
library(HonestDiD)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("80_honest_did.R — Rambachan-Roth sensitivity for militia/prefeito\n")
cat("============================================================\n\n")

# ── 1. Data loading (same pipeline as scripts 70/74/79) ────────────────────

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
  dt_chg[change_type == "stable_Militia"],
  loc_gvar[, .(loc_id, gvar_cs)], by = "loc_id"
)

dt_faction <- merge(dt_elec, loc_info[, .(loc_id, gvar_cs)], by = "loc_id")
dt_faction <- merge(dt_faction, dt_aptos[, .(loc_id, election_year, qt_aptos)],
                    by = c("loc_id", "election_year"), all.x = TRUE)
dt_faction <- dt_faction[election_year %in% elec_years & !is.na(qt_aptos) & qt_aptos > 0]

cat(sprintf("Militia panel: %d obs | %d locs\n\n",
            nrow(dt_faction), uniqueN(dt_faction$loc_id)))

# ── 2. Run CS-DID + HonestDiD for each outcome ─────────────────────────────

outcomes <- c("hhi", "enc", "margin_victory")
outcome_labels <- c(hhi = "HHI", enc = "ENC", margin_victory = "Margin of Victory")

results_tab <- list()

for (oc in outcomes) {
  cat(sprintf("--- %s ---\n", outcome_labels[oc]))
  d <- dt_faction[DS_CARGO == "Prefeito" & !is.na(get(oc))]
  d[, loc_num := as.integer(factor(loc_id))]

  att <- att_gt(
    yname = oc, tname = "election_year", idname = "loc_num", gname = "gvar_cs",
    xformla = ~1, data = as.data.frame(d),
    base_period = "universal", control_group = "notyettreated",
    allow_unbalanced_panel = TRUE, weightsname = "qt_aptos",
    print_details = FALSE
  )

  # Dynamic aggregation — need this to extract event-study point estimates
  # and the influence-function matrix for HonestDiD.
  agg <- aggte(att, type = "dynamic", na.rm = TRUE, min_e = -12, max_e = 4)

  # HonestDiD expects:
  #   betahat: vector of event-study coefficients
  #   sigma:   variance-covariance matrix (V = inf.func^T inf.func / n^2)
  #   numPrePeriods, numPostPeriods

  keep <- !is.na(agg$att.egt) & !is.na(agg$se.egt)
  es_egt  <- agg$egt[keep]
  es_att  <- agg$att.egt[keep]
  inf_mat <- agg$inf.function$dynamic.inf.func.e[, keep, drop = FALSE]

  n_inf <- nrow(inf_mat)
  sigma <- crossprod(inf_mat) / (n_inf^2)

  # Order: pre-periods first (e < 0), then post (e >= 0).
  # HonestDiD convention: betahat ordered [pre-periods | post-periods].
  pre_idx  <- which(es_egt <  0)
  post_idx <- which(es_egt >= 0)
  ord <- c(pre_idx, post_idx)

  betahat  <- es_att[ord]
  sigma    <- sigma[ord, ord, drop = FALSE]
  n_pre    <- length(pre_idx)
  n_post   <- length(post_idx)

  cat(sprintf("  %d pre-periods, %d post-periods\n", n_pre, n_post))
  cat(sprintf("  Event-times kept: %s\n", paste(es_egt[ord], collapse = ", ")))

  # Relative-magnitudes sensitivity for each post-treatment horizon (l).
  # Breakdown M-bar at horizon l_vec[i] returned as a data.frame.
  sens <- tryCatch(
    HonestDiD::createSensitivityResults_relativeMagnitudes(
      betahat        = betahat,
      sigma          = sigma,
      numPrePeriods  = n_pre,
      numPostPeriods = n_post,
      Mbarvec        = seq(0, 2, by = 0.25)
    ),
    error = function(e) { cat("  HonestDiD ERROR:", e$message, "\n"); NULL }
  )

  if (is.null(sens)) next

  orig <- HonestDiD::constructOriginalCS(
    betahat = betahat, sigma = sigma,
    numPrePeriods = n_pre, numPostPeriods = n_post
  )

  # Breakdown M-bar: smallest M-bar such that CI crosses zero.
  dt_sens <- as.data.table(sens)
  dt_sens[, crosses_zero := (lb <= 0 & ub >= 0)]
  breakdown <- if (any(dt_sens$crosses_zero)) dt_sens[crosses_zero == TRUE, min(Mbar)] else NA_real_

  cat(sprintf("  Original 95%% CI: [%.4f, %.4f]\n", orig$lb, orig$ub))
  cat(sprintf("  Breakdown M-bar : %s\n\n",
              ifelse(is.na(breakdown), "> 2 (robust)", sprintf("%.2f", breakdown))))

  results_tab[[length(results_tab) + 1]] <- data.table(
    outcome        = oc,
    outcome_label  = outcome_labels[oc],
    att_original   = mean(betahat[(n_pre + 1):(n_pre + n_post)]),
    ci_lo_original = orig$lb,
    ci_hi_original = orig$ub,
    breakdown_mbar = breakdown
  )

  # Sensitivity plot — no title (will be in LaTeX subcaption), larger fonts,
  # cleaner legend at top.
  p <- HonestDiD::createSensitivityPlot_relativeMagnitudes(sens, orig) +
    theme_classic(base_size = 14) +
    theme(
      plot.title      = element_blank(),
      legend.position = "top",
      legend.title    = element_blank(),
      legend.text     = element_text(size = 13),
      axis.text       = element_text(size = 12),
      axis.title      = element_text(size = 14)
    ) +
    scale_color_manual(
      values = c("Original" = "#0077BB", "C-LF" = "black"),
      labels = c("Original" = "Original 95% CI",
                 "C-LF"     = "Robust CI (Rambachan-Roth)")
    ) +
    labs(x = expression(bar(M)), y = "ATT")

  ggsave(file.path(OUT_DIR, sprintf("fig80_honest_%s.pdf", oc)),
         p, width = 7, height = 3.2)
}

tab_out <- rbindlist(results_tab, fill = TRUE)
fwrite(tab_out, file.path(OUT_DIR, "tab80_honest_did.csv"))

cat("============================================================\n")
cat("Summary — Breakdown M-bar (militia/prefeito):\n")
print(tab_out)
cat("\nInterpretation: M-bar > 1 means the ATT survives pre-trend violations\n")
cat("up to the size of the largest observed pre-period slope.\n")
cat("============================================================\n")


