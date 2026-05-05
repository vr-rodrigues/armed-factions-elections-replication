param(
  [string]$Rscript = "Rscript",
  [string]$Python = "python",
  [switch]$SkipMaps
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$steps = @(
  @{ Engine = "R";  Script = "code/70_main_results.R" },
  @{ Engine = "R";  Script = "code/72_rj_capital_results.R" },
  @{ Engine = "R";  Script = "code/73_robustness_municipality.R" },
  @{ Engine = "R";  Script = "code/74_main_demeaned.R" },
  @{ Engine = "R";  Script = "code/75_results_region_dummies.R" },
  @{ Engine = "R";  Script = "code/76_capital_baixada_dummies.R" },
  @{ Engine = "R";  Script = "code/77_simple_aggregation.R" },
  @{ Engine = "R";  Script = "code/78_three_specs_simple.R" },
  @{ Engine = "R";  Script = "code/79_event_study_fixed.R" },
  @{ Engine = "R";  Script = "code/80_honest_did.R" },
  @{ Engine = "R";  Script = "code/81_sun_abraham.R" },
  @{ Engine = "R";  Script = "code/82_placebo_lagged.R" },
  @{ Engine = "R";  Script = "code/83_sumstats_baseline.R" },
  @{ Engine = "R";  Script = "code/84_magnitude_translation.R" },
  @{ Engine = "R";  Script = "code/85_cluster_polygon_wildboot.R" },
  @{ Engine = "R";  Script = "code/86_equality_test_mde.R" },
  @{ Engine = "R";  Script = "code/87_balance_table.R" },
  @{ Engine = "R";  Script = "code/88_turnout_outcome.R" },
  @{ Engine = "R";  Script = "code/89_dynamic_agg_all.R" },
  @{ Engine = "R";  Script = "code/90_turnout_decomposition.R" },
  @{ Engine = "R";  Script = "code/91_exposure_duration.R" }
)

if (-not $SkipMaps) {
  $steps += @(
    @{ Engine = "PY"; Script = "code/71_map_factions.py" },
    @{ Engine = "PY"; Script = "code/72_rj_capital_map.py" }
  )
}

foreach ($step in $steps) {
  $script = Join-Path $Root $step.Script
  $name = [IO.Path]::GetFileNameWithoutExtension($script)
  $log = Join-Path $LogDir "$name.log"
  Write-Host "=== Running $($step.Script) ==="

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  if ($step.Engine -eq "R") {
    $output = & $Rscript $script 2>&1
  } else {
    $output = & $Python $script 2>&1
  }
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldErrorActionPreference
  $output | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $log

  if ($exitCode -ne 0) {
    throw "Step failed: $($step.Script)"
  }
}

Write-Host ""
Write-Host "Replication complete. Outputs are in: $Root\results"
