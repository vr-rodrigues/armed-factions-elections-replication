# ============================================================================
# 86_equality_test_mde.R — Formal ATT_militia = ATT_drug + MDE
# ============================================================================
#
# Referee A Concern 3 (MAJOR): the comparative claim (militias != drug factions)
# rests on two imprecise estimates whose CIs overlap. Formal test needed.
#
# Also: minimum detectable effect (MDE) for the drug-faction null, so readers
# can judge what size of effect the null can reject.
#
# Approach:
#   1. Wald test H0: ATT_milicia = ATT_drug for each outcome × cargo.
#      Since the two samples are disjoint, variance of the difference is
#      Var(ATT_m) + Var(ATT_d) and the t-statistic is
#        (ATT_m - ATT_d) / sqrt(SE_m^2 + SE_d^2).
#   2. MDE at alpha=0.05, power=0.80: 2.80 * SE for 2-sided (1.96 + 0.84).
#
# Output:
#   tab86_equality_test.csv  — Wald test + MDE per outcome × cargo
# ============================================================================

library(data.table)

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE_DIR <- normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)
OUT_DIR  <- file.path(BASE_DIR, "results")

cat("============================================================\n")
cat("86_equality_test_mde.R\n")
cat("============================================================\n\n")

# Load main CS-DID results
tab <- fread(file.path(OUT_DIR, "tab70_main_overall.csv"))

# Focus on NYT (preferred)
tab_nyt <- tab[estimator == "NYT"]
tab_nyt[, spec := gsub("stable_", "", spec)]

# Wide format: militia | drug on same row
wide <- dcast(tab_nyt, cargo + outcome ~ spec, value.var = c("att", "se", "n_locs"))

# Equality test: H0: ATT_m = ATT_d
wide[, att_diff := att_Militia - att_Drug]
wide[, se_diff  := sqrt(se_Militia^2 + se_Drug^2)]
wide[, z_stat   := att_diff / se_diff]
wide[, p_equal  := 2 * pnorm(-abs(z_stat))]

# MDE at alpha=0.05, power=0.80 (two-sided): (1.96 + 0.84) * SE = 2.80 * SE
wide[, mde_militia := 2.80 * se_Militia]
wide[, mde_drug    := 2.80 * se_Drug]

# Formatted output
cat("Equality tests (H0: ATT_Militia = ATT_Drug under NYT):\n\n")
print(wide[, .(cargo, outcome, att_Militia, att_Drug, att_diff, se_diff, z_stat, p_equal)])

cat("\nMinimum Detectable Effects (alpha=.05, power=.80):\n")
print(wide[, .(cargo, outcome, se_Militia, mde_militia, se_Drug, mde_drug)])

cat("\n============================================================\n")
cat("Paragraph for §5.2 (drug null):\n")
cat("============================================================\n")

for (r_i in 1:nrow(wide)) {
  r <- wide[r_i]
  if (r$cargo != "Prefeito") next
  cat(sprintf("  %s: H0 p-value = %.3f (reject equality = %s).\n",
              r$outcome, r$p_equal,
              ifelse(r$p_equal < 0.05, "YES", "NO")))
  cat(sprintf("    Drug MDE (80%% power) = %.3f (about %.1f%% of the militia point estimate).\n",
              r$mde_drug, 100 * r$mde_drug / abs(r$att_Militia)))
}

fwrite(wide, file.path(OUT_DIR, "tab86_equality_test.csv"))

cat("\nInterpretation:\n")
cat("- If p_equal < 0.05, we reject equality and the comparative claim holds.\n")
cat("- If MDE > |militia ATT|, the drug null is 'consistent with militia-sized\n")
cat("  effect' rather than 'evidence of no effect'; we soften branding accordingly.\n")
cat("DONE — 86_equality_test_mde.R\n")


