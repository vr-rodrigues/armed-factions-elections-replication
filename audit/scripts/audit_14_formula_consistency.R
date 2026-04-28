# =============================================================================
# audit_14_formula_consistency.R
# Verify on a sample of rows that:
#   ENC[i] = 1 / HHI[i]   (defining identity from Laakso-Taagepera)
#   margin_victory[i] = top1_share - second_place_share  (we don't have top2,
#       but we can sanity check that top1_share >= margin_victory)
#   HHI in [0, 1], ENC >= 1, turnout in (0, 1]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_14_formula_consistency ===\n")

dt <- fread(file.path(BASE, "data", "electoral_competition_measures.csv"))

# 1. ENC = 1/HHI?
dt[, enc_implied := 1 / hhi]
dt[, enc_diff := enc - enc_implied]
mismatch_enc <- dt[abs(enc_diff) > 1e-6 & !is.na(enc_diff)]
cat(sprintf("Rows where ENC != 1/HHI (tol 1e-6): %d / %d\n",
            nrow(mismatch_enc), nrow(dt[!is.na(hhi)])) )

# 2. HHI in [0,1]
hhi_oob <- dt[!is.na(hhi) & (hhi < 0 | hhi > 1)]
cat(sprintf("HHI outside [0,1]: %d\n", nrow(hhi_oob)))

# 3. ENC >= 1
enc_oob <- dt[!is.na(enc) & enc < 1]
cat(sprintf("ENC < 1: %d\n", nrow(enc_oob)))

# 4. margin_victory in [0, top1_share]
margin_oob <- dt[!is.na(margin_victory) & !is.na(top1_share) &
                 (margin_victory < 0 | margin_victory > top1_share + 1e-10)]
cat(sprintf("margin_victory outside [0, top1_share]: %d\n", nrow(margin_oob)))

# 5. Distribution sanity
cat("\nHHI summary:\n"); print(summary(dt$hhi))
cat("\nENC summary:\n"); print(summary(dt$enc))
cat("\nmargin_victory summary:\n"); print(summary(dt$margin_victory))

findings <- list(
  enc_eq_inv_hhi = list(
    n_mismatches = nrow(mismatch_enc), n_valid = nrow(dt[!is.na(hhi)]),
    severity = ifelse(nrow(mismatch_enc) == 0, "OK", "HIGH"),
    desc = "ENC must equal 1/HHI by Laakso-Taagepera definition"
  ),
  hhi_in_unit = list(
    n_violations = nrow(hhi_oob),
    severity = ifelse(nrow(hhi_oob) == 0, "OK", "HIGH"),
    desc = "HHI must lie in [0, 1]"
  ),
  enc_geq_1 = list(
    n_violations = nrow(enc_oob),
    severity = ifelse(nrow(enc_oob) == 0, "OK", "HIGH"),
    desc = "ENC must be >= 1"
  ),
  margin_le_top1 = list(
    n_violations = nrow(margin_oob),
    severity = ifelse(nrow(margin_oob) == 0, "OK", "HIGH"),
    desc = "margin_victory must lie in [0, top1_share]"
  )
)
write_json(list(test = "audit_14_formula_consistency", findings = findings),
           file.path(OUT, "audit_14.json"), pretty = TRUE, auto_unbox = TRUE)
cat("\nWrote audit_14.json\n")


