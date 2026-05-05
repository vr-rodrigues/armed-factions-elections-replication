# ============================================================================
# 95_paper_mechanism_outputs.R
# ============================================================================
#
# Builds paper-ready mechanism figures and tables from political-profile and
# campaign-finance CS-DID outputs.
#
# Inputs:
#   results/tab93_political_profile_overall.csv
#   results/tab94_campaign_finance_overall.csv
#
# Outputs:
#   paper/figures/fig95_mechanisms_prefeito.pdf
#   paper/figures/fig95_mechanisms_vereador.pdf
#   paper/tables/tab95_mechanisms_prefeito.tex
#   paper/tables/tab95_mechanisms_vereador.tex
# ============================================================================

library(data.table)
library(ggplot2)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                         value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
RESULTS_DIR <- file.path(BASE_DIR, "results")
PAPER_DIR <- file.path(BASE_DIR, "paper")
FIG_DIR <- file.path(PAPER_DIR, "figures")
TAB_DIR <- file.path(PAPER_DIR, "tables")
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

cat("============================================================\n")
cat("95_paper_mechanism_outputs.R\n")
cat("Paper mechanism figures and tables\n")
cat("============================================================\n\n")

profile <- fread(file.path(RESULTS_DIR, "tab93_political_profile_overall.csv"))
finance <- fread(file.path(RESULTS_DIR, "tab94_campaign_finance_overall.csv"))

profile <- profile[estimator == "NYT"]
finance <- finance[estimator == "NYT"]

political_map <- data.table(
  outcome = c(
    "elected_vote_share",
    "n_competitive_candidates_1pct",
    "top_candidate_share",
    "top3_candidate_share",
    "share_public_admin_occupation"
  ),
  label = c(
    "Winning candidate vote share (pp)",
    "Competitive candidates at 1 pp (count)",
    "Top candidate vote share (pp)",
    "Top-3 candidates vote share (pp)",
    "Public-admin occupation share (pp)"
  ),
  scale = c(100, 1, 100, 100, 100),
  panel = "Panel A. Candidate selection"
)

finance_map <- data.table(
  outcome = c(
    "expenses_vote_weighted",
    "revenue_vote_weighted",
    "expenses_per_vote_weighted",
    "high_expense_vote_share"
  ),
  label = c(
    "Expenses, vote-weighted (2024 BRL 100k)",
    "Revenue, vote-weighted (2024 BRL 100k)",
    "Expenses per vote (2024 BRL)",
    "High-spending vote share (pp)"
  ),
  scale = c(1 / 100000, 1 / 100000, 1, 100),
  panel = "Panel B. Campaign finance"
)

plot_data <- function(cargo_value) {
  p <- merge(profile[cargo == cargo_value], political_map, by = "outcome")
  f <- merge(finance[cargo == cargo_value], finance_map, by = "outcome")
  dt <- rbind(p, f, fill = TRUE)
  dt[, estimate := att * scale]
  dt[, lower := (att - 1.96 * se) * scale]
  dt[, upper := (att + 1.96 * se) * scale]
  dt[, spec := factor(spec, levels = c("Militia", "Drug"),
                      labels = c("Militia", "Drug factions"))]
  ord <- c(rev(political_map$label), rev(finance_map$label))
  dt[, label := factor(label, levels = ord)]
  dt[, panel := factor(panel, levels = c(political_map$panel[1],
                                        finance_map$panel[1]))]
  dt
}

make_plot <- function(cargo_value, outfile) {
  dt <- plot_data(cargo_value)
  dodge <- position_dodge(width = 0.58)
  g <- ggplot(dt, aes(x = estimate, y = label, color = spec, shape = spec)) +
    geom_vline(xintercept = 0, linewidth = 0.35, color = "grey45") +
    geom_errorbarh(aes(xmin = lower, xmax = upper),
                   height = 0, linewidth = 0.55, position = dodge) +
    geom_point(size = 2.4, position = dodge) +
    facet_wrap(~ panel, ncol = 1, scales = "free_y") +
    scale_color_manual(values = c("Militia" = "black",
                                  "Drug factions" = "grey45")) +
    scale_shape_manual(values = c("Militia" = 16,
                                  "Drug factions" = 17)) +
    labs(x = "CS-DID ATT (outcome units shown in labels)",
         y = NULL, color = NULL, shape = NULL) +
    theme_minimal(base_size = 10) +
    theme(
      legend.position = "bottom",
      legend.margin = margin(t = 0, b = 0),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold", hjust = 0),
      strip.background = element_rect(fill = "grey92", color = NA),
      plot.margin = margin(5, 10, 5, 5)
    )
  ggsave(outfile, g, width = 7.2, height = 7.0, device = cairo_pdf)
  cat(sprintf("Wrote %s\n", outfile))
}

stars <- function(p) {
  fifelse(p < 0.01, "^{***}",
          fifelse(p < 0.05, "^{**}",
                  fifelse(p < 0.10, "^{*}", "")))
}

fmt_num <- function(x) {
  out <- ifelse(abs(x) >= 100, sprintf("%+.0f", x),
                ifelse(abs(x) >= 10, sprintf("%+.1f", x),
                       sprintf("%+.2f", x)))
  out
}

fmt_est <- function(att, se, p, scale) {
  est <- att * scale
  stderr <- se * scale
  c(sprintf("$%s%s$", fmt_num(est), stars(p)),
    sprintf("$(%s)$", sub("^\\+", "", fmt_num(stderr))))
}

rows_for_table <- function(cargo_value, map, source) {
  dt <- merge(source[cargo == cargo_value], map, by = "outcome")
  dt[, order := match(outcome, map$outcome)]
  dt <- dt[order(order, spec)]
  out <- list()
  for (i in seq_len(nrow(map))) {
    oc <- map$outcome[i]
    label <- map$label[i]
    scale <- map$scale[i]
    m <- dt[outcome == oc & spec == "Militia"]
    d <- dt[outcome == oc & spec == "Drug"]
    me <- fmt_est(m$att, m$se, m$p_value, scale)
    de <- fmt_est(d$att, d$se, d$p_value, scale)
    out[[length(out) + 1]] <- sprintf("%s & %s & %s \\\\", label, me[1], de[1])
    out[[length(out) + 1]] <- sprintf(" & %s & %s \\\\", me[2], de[2])
  }
  unlist(out, use.names = FALSE)
}

make_table <- function(cargo_value, caption, label, outfile) {
  pol <- rows_for_table(cargo_value, political_map, profile)
  fin <- rows_for_table(cargo_value, finance_map, finance)
  n_mil <- profile[cargo == cargo_value & spec == "Militia", unique(n_locs)][1]
  n_drug <- profile[cargo == cargo_value & spec == "Drug", unique(n_locs)][1]

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    sprintf("\\caption{%s}\\label{%s}", caption, label),
    "\\footnotesize",
    "\\begin{tabular}{@{}lcc@{}}",
    "\\toprule",
    sprintf(" & \\textbf{Militia} ($N = %s$) & \\textbf{Drug Factions} ($N = %s$) \\\\", n_mil, n_drug),
    "\\midrule",
    "\\multicolumn{3}{@{}l}{\\textit{Panel A. Candidate selection}} \\\\",
    pol,
    "\\midrule",
    "\\multicolumn{3}{@{}l}{\\textit{Panel B. Campaign finance}} \\\\",
    fin,
    "\\bottomrule",
    "\\end{tabular}",
    paste0("\\tabnotes{\\textit{Notes:} Preferred not-yet-treated CS-DID estimates. ",
           "Each coefficient is the dynamically aggregated ATT after a polling station enters faction territory. ",
           "Standard errors in parentheses use the \\texttt{did} influence-function bootstrap clustered at the polling-station level. ",
           "Campaign-finance amounts are deflated to 2024 reais using IPCA from BCB/SGS series 433 and matched to candidate votes using TSE candidate identifiers; match-quality diagnostics are reported in the replication outputs. ",
           "$^{***}\\,p<0.01$, $^{**}\\,p<0.05$, $^{*}\\,p<0.10$.}"),
    "\\end{table}"
  )
  writeLines(lines, outfile, useBytes = TRUE)
  cat(sprintf("Wrote %s\n", outfile))
}

make_plot("Prefeito", file.path(FIG_DIR, "fig95_mechanisms_prefeito.pdf"))
make_plot("Vereador", file.path(FIG_DIR, "fig95_mechanisms_vereador.pdf"))

make_table(
  "Prefeito",
  "Mechanism Outcomes in Mayoral Races",
  "tab:mechanisms_prefeito",
  file.path(TAB_DIR, "tab95_mechanisms_prefeito.tex")
)
make_table(
  "Vereador",
  "Mechanism Outcomes in City-Council Races",
  "tab:mechanisms_vereador",
  file.path(TAB_DIR, "tab95_mechanisms_vereador.tex")
)

cat("\nDONE - 95_paper_mechanism_outputs.R\n")
