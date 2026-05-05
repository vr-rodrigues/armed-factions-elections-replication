#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
R="${R:-Rscript}"
PY="${PY:-python}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

run_r() {
  local script="$1"
  local name
  name="$(basename "$script" .R)"
  echo "=== Running $script ==="
  "$R" "$ROOT/$script" 2>&1 | tee "$LOG_DIR/$name.log"
}

run_py() {
  local script="$1"
  local name
  name="$(basename "$script" .py)"
  echo "=== Running $script ==="
  "$PY" "$ROOT/$script" 2>&1 | tee "$LOG_DIR/$name.log"
}

run_r code/70_main_results.R
run_r code/72_rj_capital_results.R
run_r code/73_robustness_municipality.R
run_r code/74_main_demeaned.R
run_r code/75_results_region_dummies.R
run_r code/76_capital_baixada_dummies.R
run_r code/77_simple_aggregation.R
run_r code/78_three_specs_simple.R
run_r code/79_event_study_fixed.R
run_r code/80_honest_did.R
run_r code/81_sun_abraham.R
run_r code/82_placebo_lagged.R
run_r code/83_sumstats_baseline.R
run_r code/84_magnitude_translation.R
run_r code/85_cluster_polygon_wildboot.R
run_r code/86_equality_test_mde.R
run_r code/87_balance_table.R
run_r code/88_turnout_outcome.R
run_r code/89_dynamic_agg_all.R
run_r code/90_turnout_decomposition.R
run_r code/91_exposure_duration.R
run_py code/71_map_factions.py
run_py code/72_rj_capital_map.py

echo ""
echo "Replication complete. Outputs are in: $ROOT/results"
