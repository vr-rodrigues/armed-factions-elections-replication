# =============================================================================
# audit_07_honest_did.R
# Verify Table 5 (Honest-DiD) values against tab80_honest_did.csv
# Paper claims: HHI Mbar=1.50, ENC Mbar=1.75, Margin Mbar=1.25
#               HHI ATT=+0.059 CI [+0.040, +0.118]
#               ENC ATT=-0.521 CI [-1.025, -0.378]
#               Margin ATT=+0.077 CI [+0.035, +0.121]
# Note: We do NOT re-run HonestDiD (slow); we read the existing CSV and
# verify it matches the paper claims.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
RES  <- file.path(BASE, "results")
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_07_honest_did ===\n")

hd <- fread(file.path(RES, "tab80_honest_did.csv"))
cat("Columns: ", paste(names(hd), collapse = ", "), "\n")
print(hd)

paper <- data.table(
  outcome = c("hhi", "enc", "margin_victory"),
  ci_lo_p = c( 0.040, -1.025,  0.035),
  ci_hi_p = c( 0.118, -0.378,  0.121),
  att_p   = c( 0.059, -0.521,  0.077),
  mbar_p  = c( 1.50,   1.75,   1.25)
)
cmp <- merge(hd, paper, by = "outcome", all = TRUE)
cmp[, ci_lo_diff := round(get("ci_lo_original.V1") - ci_lo_p, 4)]
cmp[, ci_hi_diff := round(get("ci_hi_original.V1") - ci_hi_p, 4)]
cmp[, att_diff   := round(att_original - att_p, 4)]
cmp[, mbar_diff  := round(breakdown_mbar - mbar_p, 4)]
print(cmp[, .(outcome, ci_lo_p, ci_lo_repro = round(get("ci_lo_original.V1"), 4), ci_lo_diff,
              ci_hi_p, ci_hi_repro = round(get("ci_hi_original.V1"), 4), ci_hi_diff,
              att_p, att_repro = round(att_original, 4), att_diff,
              mbar_p, mbar_repro = breakdown_mbar, mbar_diff)])

findings <- list()
for (i in seq_len(nrow(cmp))) {
  r <- cmp[i]
  sev <- ifelse(abs(r$att_diff) > 0.005 | abs(r$mbar_diff) > 0.05 |
                abs(r$ci_lo_diff) > 0.005 | abs(r$ci_hi_diff) > 0.005, "HIGH", "OK")
  findings[[as.character(r$outcome)]] <- list(
    ci_lo_paper = r$ci_lo_p, ci_lo_repro = round(r[["ci_lo_original.V1"]], 4),
    ci_hi_paper = r$ci_hi_p, ci_hi_repro = round(r[["ci_hi_original.V1"]], 4),
    att_paper   = r$att_p,   att_repro   = round(r$att_original, 4),
    mbar_paper  = r$mbar_p,  mbar_repro  = r$breakdown_mbar,
    severity = sev
  )
}
write_json(list(test = "audit_07_honest_did", findings = findings),
           file.path(OUT, "audit_07.json"), pretty = TRUE, auto_unbox = TRUE, na = "string")
cat("\nWrote audit_07.json\n")


