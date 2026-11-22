#!/usr/bin/env bash
# run_replication.sh: runs the replication pipeline (see README.md).
#
# Usage, from this folder (Bash; Git Bash on Windows):
#   export AFE_DADOS=/path/to/data                                   # default: ./data
#   GCP_PROJECT=<billing-project> bash run_replication.sh extract    # Base dos Dados extraction (BigQuery), once
#   bash run_replication.sh                                          # base ext inputs estimates tables
#   bash run_replication.sh estimates tables                         # any subset of stages, in order
#
# Environment: AFE_DADOS (data folder), MAX_JOBS (parallel R jobs in the estimation stage, default 4),
# RSCRIPT and PYTHON (interpreters, default Rscript and python on PATH).
# Each job writes logs/<job>.log; logs/progress.txt records start, end and exit code of every job.
# The script stops at the end of any stage in which a job failed.
set -u
cd "$(dirname "$0")" || exit 1
export AFE_DADOS="${AFE_DADOS:-$PWD/data}"
# Git Bash on Windows: R needs C:/... paths, not /c/...
if command -v cygpath > /dev/null 2>&1; then AFE_DADOS="$(cygpath -m "$AFE_DADOS")"; fi
RS="${RSCRIPT:-Rscript}"; PY="${PYTHON:-python}"; MAX="${MAX_JOBS:-4}"
LOG="$PWD/logs"; PROG="$LOG/progress.txt"
mkdir -p "$LOG" "$AFE_DADOS" fase1/resultados fase2/resultados fase3/resultados/rds paper_v2/tables paper_v2/figures \
         pipeline_v2/checks pipeline_v2/checks_ext pipeline_v2/logs

note() { echo "$* $(date '+%F %T')" | tee -a "$PROG"; }
# sequential job: stops the pipeline if it fails
seq1() { local nome="$1"; shift; note "$nome start"; "$@" > "$LOG/$nome.log" 2>&1; local e=$?
         echo "$nome exit $e $(date +%T)" >> "$PROG"; [ $e -eq 0 ] || { note "STOPPED at $nome (see logs/$nome.log)"; exit $e; }; }
# parallel job: at most MAX at a time
run() { local nome="$1"; shift; while [ "$(jobs -rp | wc -l)" -ge "$MAX" ]; do sleep 2; done
        ( "$@" > "$LOG/$nome.log" 2>&1; echo "$nome exit $? $(date +%T)" >> "$PROG" ) & }
fim() { wait; local n; n=$(grep -c "exit [1-9]" "$PROG"); [ "$n" -eq 0 ] || { note "STOPPED after $1: $n failed job(s), see logs/progress.txt"; exit 1; }
        note "$1 done"; }

extract() {   # Base dos Dados -> $AFE_DADOS/basedosdados_{tse,v2,v3,v4}
  [ -n "${GCP_PROJECT:-}" ] || { echo "set GCP_PROJECT to the Google Cloud project billed for the BigQuery queries"; exit 2; }
  for s in extrair_bd extrair_bd_v2 extrair_bd_v3 extrair_bd_v4; do
    seq1 "extract_$s" "$PY" "base_dados_bd/$s.py" --project "$GCP_PROJECT" --run; done
  note "extract done"
}

base() {      # polling places, crosswalk, section links, votes, outcomes, treatment, panels; CS-DID engine tests
  seq1 base_pipeline "$RS" pipeline_v2/run_all.R replication; note "base done"
}

ext() {       # open-list concentration, mechanism outcomes, catchment-area exposure, ideology and party blocs
  seq1 ext_pipeline "$RS" pipeline_v2/run_ext.R replication; note "ext done"
}

inputs() {    # outcomes used in the paper; 2010 census income around each polling place (covariate of the main spec)
  seq1 W00 "$RS" fase3/W00_outcomes_paper.R
  seq1 W17_income "$RS" fase3/W17_covariaveis_censo.R
  note "inputs done"
}

estimates() {
  rm -f fase3/resultados/rds/*.rds   # W01 skips specifications whose .rds already exists
  # 1. estimations that only need the data
  run F01 "$RS" fase1/F01_principal.R
  for p in mun geral; do for f in milicia trafico; do for t in ponto captacao; do for k in 1 2 3; do
    run "V03_${p}_${f}_${t}_p${k}" "$RS" fase2/V03_f6.R "$p" "$f" "$t" "$k/3"; done; done; done; done
  for z in "trafico hhi_pref" "milicia saldo_ver"; do set -- $z; for v in R0 R1; do for k in 1 2; do
    run "V04_ri_$1_$2_${v}_p${k}" "$RS" fase2/V04_f6_testes.R ri "$1" "$2" "$v" "$k/2"; done; done; done
  run V04_blocos "$RS" fase2/V04_f6_testes.R blocos
  run V04_placebo "$RS" fase2/V04_f6_testes.R placebo
  for k in 1 2 3 4 5 6; do run "W01_p${k}" "$RS" fase3/W01_estimativas_paper.R "$k/6"; done
  for w in W03_placebo_paper W05_composicao W06_inferencia_espacial W07_balanco W09_exposicao_buffer W10_beneficiarios \
           W12_financas W13_eleicao_2004 W14_exposicao_influencia W18_receita_percentil W19_checagens_h2 W20_h2_exposicao \
           W21_clausula_h2 W22_receita_sensibilidade; do
    run "$w" "$RS" "fase3/$w.R"; done
  run W11_1000 "$RS" fase3/W11_candidatos_locais.R 1000
  run W11_3000 "$RS" fase3/W11_candidatos_locais.R 3000
  fim "estimates 1/4"
  # 2. what needs step 1
  for b in mun_milicia mun_trafico geral_milicia geral_trafico; do for k in 1 2 3; do
    run "F02_${b}_p${k}" "$RS" fase1/F02_robustez.R "$b" "$k/3"; done; done
  run V03b "$RS" fase2/V03b_tabelas.R
  run V04b "$RS" fase2/V04b_ri_resumo.R
  for z in "trafico hhi_pref" "milicia saldo_ver" "milicia hhi_pref"; do set -- $z; run "V02_$1_$2" "$RS" fase2/V02_curva.R "$1" "$2"; done
  for i in 1 2 3 4 5 6 7 8 9; do run "W02_$i" "$RS" fase3/W02_honestdid_curvas.R "$i"; done
  run W04 "$RS" fase3/W04_agregacao_municipal.R
  run W08 "$RS" fase3/W08_antecipacao.R
  run W15 "$RS" fase3/W15_inferencia_conjunta.R
  run W15_mun "$RS" fase3/W15_inferencia_conjunta.R mun
  fim "estimates 2/4"
  # 3. summaries of step 2
  run F02b "$RS" fase1/F02b_tabelas.R
  run V02b "$RS" fase2/V02b_curva_resumo.R
  run W02_junta "$RS" fase3/W02_honestdid_curvas.R junta
  fim "estimates 3/4"
  # 4. what needs the summaries
  run W16 "$RS" fase3/W16_legislativo_estadual.R
  run W17 "$RS" fase3/W17_covariaveis_censo.R
  fim "estimates 4/4"
}

tables() {    # paper_v2/tables/*.tex (including numbers.tex, every number cited in the text) and paper_v2/figures/*.pdf
  seq1 tables "$RS" paper_v2/R/tabelas_figuras.R; note "tables done"
}

[ $# -gt 0 ] || set -- base ext inputs estimates tables
: > "$PROG"; note "AFE_DADOS=$AFE_DADOS MAX_JOBS=$MAX stages: $*"
for s in "$@"; do
  case "$s" in extract|base|ext|inputs|estimates|tables) "$s" ;; *) echo "unknown stage: $s"; exit 2 ;; esac
done
note "finished"
