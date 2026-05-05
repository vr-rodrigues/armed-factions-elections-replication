param(
  [string]$OutDir = "data/raw/tse/prestacao_contas"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutPath = Join-Path $Root $OutDir
$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $OutPath | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$Resources = @(
  @{ Year = 2008; Url = "https://cdn.tse.jus.br/estatistica/sead/odsele/prestacao_contas/prestacao_contas_2008.zip"; Bytes = 154761414 },
  @{ Year = 2012; Url = "https://cdn.tse.jus.br/estatistica/sead/odsele/prestacao_contas/prestacao_final_2012.zip"; Bytes = 671229467 },
  @{ Year = 2016; Url = "https://cdn.tse.jus.br/estatistica/sead/odsele/prestacao_contas/prestacao_contas_final_2016.zip"; Bytes = 1095335631 },
  @{ Year = 2020; Url = "https://cdn.tse.jus.br/estatistica/sead/odsele/prestacao_contas/prestacao_de_contas_eleitorais_candidatos_2020.zip"; Bytes = 1301110312 },
  @{ Year = 2024; Url = "https://cdn.tse.jus.br/estatistica/sead/odsele/prestacao_contas/prestacao_de_contas_eleitorais_candidatos_2024.zip"; Bytes = 1283332278 }
)

$MainLog = Join-Path $LogDir "download_campaign_finance.log"
"Starting campaign-finance download at $(Get-Date -Format s)" | Out-File -FilePath $MainLog -Encoding UTF8

foreach ($r in $Resources) {
  $file = Join-Path $OutPath (Split-Path $r.Url -Leaf)
  $current = if (Test-Path -LiteralPath $file) { (Get-Item -LiteralPath $file).Length } else { 0 }
  if ($current -eq [int64]$r.Bytes) {
    "[$($r.Year)] complete: $file" | Tee-Object -FilePath $MainLog -Append
    continue
  }

  "[$($r.Year)] downloading/resuming $current / $($r.Bytes): $file" | Tee-Object -FilePath $MainLog -Append
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & curl.exe `
    --location `
    --continue-at - `
    --fail `
    --retry 12 `
    --retry-delay 10 `
    --retry-all-errors `
    --output $file `
    $r.Url 2>&1 | Tee-Object -FilePath $MainLog -Append
  $ErrorActionPreference = $oldErrorActionPreference

  if ($LASTEXITCODE -ne 0) {
    "[$($r.Year)] curl failed with exit code $LASTEXITCODE" | Tee-Object -FilePath $MainLog -Append
    exit $LASTEXITCODE
  }

  $final = (Get-Item -LiteralPath $file).Length
  if ($final -ne [int64]$r.Bytes) {
    "[$($r.Year)] size mismatch: expected $($r.Bytes), got $final" | Tee-Object -FilePath $MainLog -Append
    exit 1
  }

  "[$($r.Year)] complete: $final bytes" | Tee-Object -FilePath $MainLog -Append
}

"Finished campaign-finance download at $(Get-Date -Format s)" | Tee-Object -FilePath $MainLog -Append
