param(
  [string]$Rscript = "Rscript",
  [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScriptDir = Join-Path $Root "audit\scripts"
$LogDir = Join-Path $Root "audit\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$steps = @(
  @{ Engine = "R";  Script = "audit_01_data_integrity.R" },
  @{ Engine = "R";  Script = "audit_02_treatment_consistency.R" },
  @{ Engine = "R";  Script = "audit_03_main_atts.R" },
  @{ Engine = "R";  Script = "audit_04_appendix_atts.R" },
  @{ Engine = "R";  Script = "audit_05_pretrends_wald.R" },
  @{ Engine = "R";  Script = "audit_06_summary_stats.R" },
  @{ Engine = "R";  Script = "audit_07_honest_did.R" },
  @{ Engine = "PY"; Script = "audit_08_magnitudes.py" },
  @{ Engine = "PY"; Script = "audit_09_text_numbers.py" },
  @{ Engine = "R";  Script = "audit_10_sample_construction.R" },
  @{ Engine = "PY"; Script = "audit_11_citations.py" },
  @{ Engine = "PY"; Script = "audit_12_figures.py" },
  @{ Engine = "PY"; Script = "audit_13_reproducibility.py" },
  @{ Engine = "R";  Script = "audit_14_formula_consistency.R" },
  @{ Engine = "PY"; Script = "consolidate_findings.py" }
)

foreach ($step in $steps) {
  $script = Join-Path $ScriptDir $step.Script
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
    throw "Audit step failed: $($step.Script)"
  }
}

Write-Host ""
Write-Host "Audit complete. Outputs are in: $Root\audit\outputs"
