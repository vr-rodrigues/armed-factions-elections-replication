#!/usr/bin/env bash
# Re-run all downstream R scripts that consume electoral_competition_measures.csv,
# in dependency order. Each writes into results/ and logs here.
set -e
BASE="C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais"
LOGDIR="$BASE/_backup_pre_fix_2026-04-23"
cd "$BASE"

run() {
  local script="$1"; local tag="$2"
  echo "=== Running $script ==="
  Rscript "scripts/$script" > "$LOGDIR/run_$tag.log" 2>&1
  echo "   $script done (log: run_$tag.log)"
}

run 83_sumstats_baseline.R   83
run 70_main_results.R        70
run 89_dynamic_agg_all.R     89
run 79_event_study_fixed.R   79
run 80_honest_did.R          80
run 87_balance_table.R       87
run 88_turnout_outcome.R     88

echo "=== ALL DOWNSTREAM R SCRIPTS DONE ==="

