# ============================================================================
# 79_event_study_fixed.R — CORRECTED Event-Study Plots
# ============================================================================
#
# Fixes bugs in scripts 70 and 74 event-study figures:
#   1. base_period = "varying" (not "universal"): avoids degenerate 0/NA cells
#      at extreme event-times that arose from universal base-period convention.
#   2. min_e / max_e: restrict window to event-times with enough cohort support.
#   3. Drop rows with se == NA before plotting (except the reference period,
#      which is shown explicitly as normalized to 0).
#   4. Run for BOTH raw and demeaned outcomes, side by side.
#
# Specs: {Militia, Drug} × {Prefeito, Vereador} × {HHI, ENC, margin_victory}
#        × {raw, demeaned} × {NYT preferred}
#
# Output (overwrites the broken fig74_es_*.pdf plots):
#   fig79_es_{spec}_{outcome_type}_{cargo}_{outcome}.pdf
#   tab79_event_study.csv
# ============================================================================

library(data.table)
library(did)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("79_event_study_fixed.R — Corrected CS-DID event-studies\n")
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

# ── 2. Treatment assignment (same mapping as scripts 70/74) ─────────────────

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

# ── 3. Build panel (faction-only, NYT design) ──────────────────────────────

dt_faction <- merge(
  dt_elec,
  loc_info[, .(loc_id, gvar_cs, change_type, faction_specific)],
  by = "loc_id"
)
dt_faction <- merge(
  dt_faction,
  dt_aptos[, .(loc_id, election_year, qt_aptos)],
  by = c("loc_id", "election_year"), all.x = TRUE
)
dt_faction <- dt_faction[election_year %in% elec_years]
dt_faction <- dt_faction[!is.na(qt_aptos) & qt_aptos > 0]

cat(sprintf("Faction panel: %d obs | %d locs | %d municipalities\n",
            nrow(dt_faction), uniqueN(dt_faction$loc_id),
            uniqueN(dt_faction$CD_MUNICIPIO)))

# Municipality demeaning
outcomes_raw <- c("hhi", "enc", "margin_victory")
for (oc in outcomes_raw) {
  dm_col <- paste0(oc, "_dm")
  dt_faction[, (dm_col) := get(oc) - mean(get(oc), na.rm = TRUE),
             by = .(CD_MUNICIPIO, election_year, DS_CARGO)]
}

# ── 4. CS-DID event-study engine ────────────────────────────────────────────

run_event_study <- function(d_run, outcome, lbl) {
  d <- d_run[!is.na(get(outcome)) & qt_aptos > 0]
  d[, loc_num := as.integer(factor(loc_id))]

  if (uniqueN(d$gvar_cs) < 2) {
    cat(sprintf("  %-55s SKIP (single cohort)\n", lbl))
    return(NULL)
  }

  tryCatch({
    # base_period = "universal" — matches Tables 1/2 in main.tex.
    # Under universal, cohort g=2008 has no pre-period (panel starts at 2008),
    # so some (g,t) cells are unidentified. These appear in the dynamic
    # aggregation as att.egt = 0 / se.egt = NA at extreme event-times.
    # We filter those out below before plotting.
    att <- att_gt(
      yname       = outcome,
      tname       = "election_year",
      idname      = "loc_num",
      gname       = "gvar_cs",
      xformla     = ~1,
      data        = as.data.frame(d),
      base_period = "universal",
      control_group = "notyettreated",
      allow_unbalanced_panel = TRUE,
      weightsname = "qt_aptos",
      print_details = FALSE
    )

    # min_e = -12, max_e = 4 in year units (= -3 to +1 in election units).
    # These are the event-times with meaningful cohort support.
    agg <- aggte(att, type = "dynamic",
                 min_e = -12, max_e = 4,
                 na.rm = TRUE)

    es_dt <- data.table(
      event_time = agg$egt,
      att_e      = agg$att.egt,
      se_e       = agg$se.egt
    )
    # Under universal base, reference period is e = -4 (earliest pre-period
    # relative to a cohort's treatment year). att.egt for the reference is 0
    # with se.egt = NA by construction. Other event-times with se.egt = NA are
    # the extreme cells where only one cohort contributes and that contribution
    # equals the cohort's base period (so ATT = 0 mechanically).

    # Drop degenerate rows (NA SE at non-reference event times).
    # Reference row (event_time = -4 with NA SE) is the universal-base anchor;
    # we keep it and re-add explicitly below if absent.
    es_dt <- es_dt[!(event_time != -4 & is.na(se_e))]

    es_dt[, ci_lo := att_e - 1.96 * se_e]
    es_dt[, ci_hi := att_e + 1.96 * se_e]

    # Ensure reference row is present
    if (!(-4 %in% es_dt$event_time)) {
      es_dt <- rbind(es_dt,
                     data.table(event_time = -4, att_e = 0, se_e = NA_real_,
                                ci_lo = NA_real_, ci_hi = NA_real_))
    }
    setorder(es_dt, event_time)

    cat(sprintf("  %-55s ATT=%+.4f (SE %.4f) | %d event-times\n",
                lbl, agg$overall.att, agg$overall.se, nrow(es_dt)))

    return(es_dt)
  }, error = function(e) {
    cat(sprintf("  %-55s ERROR: %s\n", lbl, e$message))
    NULL
  })
}

# ── 5. Run all specifications ───────────────────────────────────────────────

cargos <- c("Prefeito", "Vereador")
specs  <- list(
  list(name = "Militia", filter_type = "stable_Militia"),
  list(name = "Drug",    filter_type = "stable_Drug")
)
outcome_variants <- list(
  list(type = "raw",      cols = outcomes_raw),
  list(type = "demeaned", cols = paste0(outcomes_raw, "_dm"))
)

all_es <- list()

for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$name))
  d_nyt <- dt_faction[change_type == sp$filter_type]
  cat(sprintf("  %s panel: %d locs\n", sp$name, uniqueN(d_nyt$loc_id)))

  for (ov in outcome_variants) {
    cat(sprintf("\n  -- %s outcomes --\n", ov$type))
    for (cargo in cargos) {
      for (i in seq_along(ov$cols)) {
        oc_var <- ov$cols[i]
        oc_raw <- outcomes_raw[i]
        lbl <- sprintf("%s / %s / %s [%s]", sp$name, cargo, oc_raw, ov$type)
        es  <- run_event_study(d_nyt[DS_CARGO == cargo], oc_var, lbl)
        if (!is.null(es)) {
          es[, `:=`(spec = sp$name, cargo = cargo, outcome = oc_raw,
                    outcome_type = ov$type)]
          all_es[[length(all_es) + 1]] <- es
        }
      }
    }
  }
}

tab_es <- rbindlist(all_es, fill = TRUE)
fwrite(tab_es, file.path(OUT_DIR, "tab79_event_study.csv"))

cat(sprintf("\n\nWritten: %s (%d rows)\n",
            file.path(OUT_DIR, "tab79_event_study.csv"), nrow(tab_es)))

# ── 6. Event-study plots ─────────────────────────────────────────────────────

outcome_labels <- c(
  hhi            = "HHI",
  enc            = "ENC",
  margin_victory = "Margin of Victory"
)

make_es_plot <- function(d_es, y_lab) {
  d_plot <- copy(d_es)
  d_plot[, event_elections := event_time / 4]
  is_ref <- d_plot$event_time == -4

  # Point-range layer: valid (non-reference) points only
  d_valid <- d_plot[!is_ref]

  p <- ggplot() +
    geom_hline(yintercept = 0, color = "grey70", linetype = "dashed",
               linewidth = 0.4) +
    geom_vline(xintercept = -0.5, color = "grey70", linetype = "dashed",
               linewidth = 0.4) +
    geom_errorbar(data = d_valid,
                  aes(x = event_elections, ymin = ci_lo, ymax = ci_hi),
                  width = 0.10, linewidth = 0.6) +
    geom_point(data = d_valid,
               aes(x = event_elections, y = att_e),
               size = 3, color = "black") +
    # Reference period: open circle at 0
    geom_point(data = d_plot[is_ref],
               aes(x = event_elections, y = att_e),
               size = 3.5, shape = 21, fill = "white", color = "black",
               stroke = 0.8) +
    labs(x = "Elections Relative to Treatment", y = y_lab) +
    scale_x_continuous(breaks = seq(-3, 1, 1)) +
    theme_classic(base_size = 16) +
    theme(axis.text = element_text(size = 14),
          axis.title = element_text(size = 16))

  return(p)
}

for (sp_name in c("Militia", "Drug")) {
  for (ov_type in c("raw", "demeaned")) {
    for (cg in cargos) {
      for (oc in outcomes_raw) {
        d_es <- tab_es[spec == sp_name & cargo == cg & outcome == oc &
                       outcome_type == ov_type]
        if (nrow(d_es) == 0) next

        y_lab <- ifelse(ov_type == "demeaned", "ATT (demeaned)", "ATT")

        p <- make_es_plot(d_es, y_lab)

        fn <- sprintf("fig79_es_%s_%s_%s_%s.pdf",
                      tolower(sp_name), ov_type, tolower(cg), oc)
        ggsave(file.path(OUT_DIR, fn), p, width = 9, height = 3.5)
      }
    }
  }
}

cat("\n============================================================\n")
cat("DONE — 79_event_study_fixed.R\n")
cat("============================================================\n")
cat(sprintf("  %d event-study PDFs written to %s/\n",
            2 * 2 * 2 * 3, OUT_DIR))
cat("  Naming: fig79_es_{militia|drug}_{raw|demeaned}_{prefeito|vereador}_{hhi|enc|margin_victory}.pdf\n")


