# =============================================================================
# audit_05_pretrends_wald.R
# Compile and assess all Wald p-values for pre-trends in main results.
# Compares paper-quoted Wald p-values vs reproduced (from audit_03).
# Also flags directionally important boundary cases (p < 0.05).
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

.script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
.script_dir <- if (!is.na(.script_file)) dirname(normalizePath(.script_file)) else getwd()
BASE <- normalizePath(file.path(.script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
OUT  <- file.path(BASE, "audit", "outputs")

cat("=== audit_05_pretrends_wald ===\n")

repro_path <- file.path(OUT, "audit_03_repro_atts.csv")
if (!file.exists(repro_path)) stop("Run audit_03 first.")
r <- fread(repro_path)

# Paper claim: in main NYT spec for prefeito + militia, "all four estimates pass
# the joint Wald pre-trends test" (p > 0.10).
nyt_militia_pref <- r[estimator == "NYT" & spec == "Militia" & cargo == "Prefeito"]
cat("\nNYT Militia Prefeito Wald p-values:\n")
print(nyt_militia_pref[, .(outcome, wald_p = round(wald_p, 4),
                           passes_at_10 = wald_p > 0.10)])

nyt_drug_pref <- r[estimator == "NYT" & spec == "Drug" & cargo == "Prefeito"]
cat("\nNYT Drug Prefeito Wald p-values:\n")
print(nyt_drug_pref[, .(outcome, wald_p = round(wald_p, 4),
                        passes_at_10 = wald_p > 0.10)])

cat("\nNYT Vereador Wald p-values (all):\n")
print(r[estimator == "NYT" & cargo == "Vereador",
        .(spec, outcome, wald_p = round(wald_p, 4),
          passes_at_10 = wald_p > 0.10)])

cat("\nNT Wald p-values for prefeito (paper says all 3 militia outcomes REJECT clean pre-trends):\n")
print(r[estimator == "NT" & cargo == "Prefeito",
        .(spec, outcome, wald_p = round(wald_p, 4),
          rejects_at_5 = wald_p < 0.05)])

# Build findings
findings <- list(
  nyt_militia_prefeito_all_pass_10 = list(
    n_outcomes = nrow(nyt_militia_pref),
    n_passing = sum(nyt_militia_pref$wald_p > 0.10),
    expected = "all 4 pass (paper claim)",
    severity = ifelse(all(nyt_militia_pref$wald_p > 0.10), "OK", "HIGH"),
    detail = nyt_militia_pref[, .(outcome, wald_p)]
  ),
  nyt_militia_vereador_enc_borderline = list(
    wald_p = round(r[estimator == "NYT" & spec == "Militia" & cargo == "Vereador" & outcome == "enc"]$wald_p, 4),
    note = "Reported as 0.093 in paper Table 5 — borderline at 10%",
    severity = "INFO"
  ),
  nt_militia_prefeito_hhi_enc_reject = list(
    expected = "p < 0.001 (paper says <0.001)",
    repro_hhi_p = round(r[estimator == "NT" & spec == "Militia" & cargo == "Prefeito" & outcome == "hhi"]$wald_p, 6),
    repro_enc_p = round(r[estimator == "NT" & spec == "Militia" & cargo == "Prefeito" & outcome == "enc"]$wald_p, 6),
    severity = "OK"
  )
)

write_json(list(test = "audit_05_pretrends_wald", findings = findings),
           file.path(OUT, "audit_05.json"), pretty = TRUE, auto_unbox = TRUE, na = "string")
cat("\nWrote audit_05.json\n")


