# =============================================================================
# audit_04_appendix_atts.R
# Specialized audit for Appendix B tables (NT spec). Re-uses the NT rows
# produced in audit_03 (audit_03_repro_atts.csv) and contrasts vs paper.
# Also reports the "Wald < 0.001" case (Militia/Prefeito hhi+enc) explicitly.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_04_appendix_atts ===\n")

repro_path <- file.path(OUT, "audit_03_repro_atts.csv")
if (!file.exists(repro_path)) stop("Run audit_03 first.")
r <- fread(repro_path)

# Subset to NT
nt <- r[estimator == "NT"]
cat("\nNT reproductions:\n")
print(nt[, .(spec, cargo, outcome, att = round(att, 4),
             se = round(se, 4), p = round(p_value, 4),
             wald = round(wald_p, 4), n_locs)])

# Paper Appendix B Table 6 (Mayoral NT)
paper_b1 <- data.table(
  spec = c("Militia","Militia","Militia","Militia","Drug","Drug","Drug","Drug"),
  cargo = "Prefeito",
  outcome = c("hhi","enc","margin_victory","turnout","hhi","enc","margin_victory","turnout"),
  estimator = "NT",
  att_p = c(0.068, -0.774, 0.041, 0.027, 0.056, -0.094, 0.097, 0.034),
  se_p  = c(0.011, 0.094, 0.014, 0.011, 0.030, 0.188, 0.039, 0.025),
  wald_p_paper = c(0.000, 0.000, 0.010, 0.016, 0.073, 0.232, 0.523, 0.205)
  # 0.000 is "<0.001"
)

# Paper Appendix B Table 7 (Vereador NT)
paper_b2 <- data.table(
  spec = c("Militia","Militia","Militia","Drug","Drug","Drug"),
  cargo = "Vereador",
  outcome = c("hhi","enc","margin_victory","hhi","enc","margin_victory"),
  estimator = "NT",
  att_p = c(0.005, 1.057, 0.006, 0.008, -4.128, 0.025),
  se_p  = c(0.005, 1.717, 0.012, 0.005, 2.722, 0.012),
  wald_p_paper = c(0.348, 0.005, 0.454, 0.132, 0.181, 0.163)
)

paper_b <- rbind(paper_b1, paper_b2)
cmp <- merge(nt, paper_b, by = c("spec", "cargo", "outcome", "estimator"))
cmp[, att_diff := round(att - att_p, 4)]
cmp[, se_diff  := round(se  - se_p, 4)]
cmp[, wald_diff := round(wald_p - wald_p_paper, 4)]
print(cmp[, .(spec, cargo, outcome, att_p, att = round(att, 4), att_diff,
              se_p, se = round(se, 4), se_diff,
              wald_p_paper, wald = round(wald_p, 4), wald_diff)])

# Reference comparison: against canonical tab89_dynamic_overall.csv (the paper's source)
RES <- file.path(BASE, "results")
tab89 <- fread(file.path(RES, "tab89_dynamic_overall.csv"))
canon <- merge(tab89, paper_b, by = c("spec", "cargo", "outcome", "estimator"))
canon[, att_diff_canon := round(att - att_p, 4)]
canon[, se_diff_canon  := round(se - se_p, 4)]
canon[, wald_diff_canon := round(wald_p - wald_p_paper, 4)]

cat("\nCanonical tab89 NT vs paper claims:\n")
print(canon[, .(spec, cargo, outcome,
                att_paper = att_p, att_canon = att, att_diff_canon,
                se_paper = se_p, se_canon = se, se_diff_canon,
                wald_p_paper, wald_canon = wald_p, wald_diff_canon)])

findings <- list()
for (i in seq_len(nrow(canon))) {
  rr <- canon[i]
  # Allow 5% relative SE drift (min 0.01) to absorb bootstrap Monte-Carlo noise.
  se_thresh <- max(0.01, 0.05 * abs(rr$se_p))
  sev <- ifelse(abs(rr$att_diff_canon) > 0.005 | abs(rr$se_diff_canon) > se_thresh |
                  (abs(rr$wald_diff_canon) > 0.05 & !is.na(rr$wald_diff_canon)), "HIGH", "OK")
  key <- sprintf("%s_%s_%s_NT", rr$spec, rr$cargo, rr$outcome)
  findings[[key]] <- list(
    att_paper = rr$att_p, att_canon = round(rr$att, 4), att_diff = rr$att_diff_canon,
    se_paper  = rr$se_p,  se_canon  = round(rr$se, 4),  se_diff  = rr$se_diff_canon,
    wald_paper = rr$wald_p_paper, wald_canon = round(rr$wald_p, 4), wald_diff = rr$wald_diff_canon,
    severity = sev,
    note = "Canonical tab89 row vs paper Appendix B"
  )
}
write_json(list(test = "audit_04_appendix_atts", findings = findings),
           file.path(OUT, "audit_04.json"), pretty = TRUE, auto_unbox = TRUE, na = "string")
cat("\nWrote audit_04.json\n")


