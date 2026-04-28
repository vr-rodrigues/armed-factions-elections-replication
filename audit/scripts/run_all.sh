#!/usr/bin/env bash
# =============================================================================
# run_all.sh - Orchestrate all audit scripts in deterministic order
# =============================================================================
set -e

R="${R:-Rscript}"
PY="${PY:-python}"

BASE="$(cd "$(dirname "$0")/../.." && pwd)"
S="$BASE/audit/scripts"
L="$BASE/audit/logs"
O="$BASE/audit/outputs"

mkdir -p "$L" "$O"

run() {
  local script="$1"
  local engine="$2"
  local name="$(basename "$script" .R)"
  name="$(basename "$name" .py)"
  echo "=== Running $name ==="
  if [ "$engine" = "R" ]; then
    "$R" "$script" 2>&1 | tee "$L/$name.log"
  else
    "$PY" "$script" 2>&1 | tee "$L/$name.log"
  fi
}

# Order matters for audit_04/05 which depend on audit_03
run "$S/audit_01_data_integrity.R"        R
run "$S/audit_02_treatment_consistency.R" R
run "$S/audit_03_main_atts.R"             R
run "$S/audit_04_appendix_atts.R"         R
run "$S/audit_05_pretrends_wald.R"        R
run "$S/audit_06_summary_stats.R"         R
run "$S/audit_07_honest_did.R"            R
run "$S/audit_08_magnitudes.py"           PY
run "$S/audit_09_text_numbers.py"         PY
run "$S/audit_10_sample_construction.R"   R
run "$S/audit_11_citations.py"            PY
run "$S/audit_12_figures.py"              PY
run "$S/audit_13_reproducibility.py"      PY
run "$S/audit_14_formula_consistency.R"   R

# Consolidate findings
"$PY" "$S/consolidate_findings.py" 2>&1 | tee "$L/consolidate.log"

echo ""
echo "=== ALL DONE ==="
echo "See $O/audit_findings.csv and $O/audit_report.md"


