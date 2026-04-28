# Validation log

Validated on 2026-04-27.

## Audit suite

Command:

```powershell
.\run_audit.ps1 -Rscript "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -Python "C:\Users\victo\AppData\Local\Python\bin\python.exe"
```

Result:

- 175 total findings
- 153 OK
- 22 INFO
- 0 LOW
- 0 MEDIUM
- 0 HIGH
- 0 CRITICAL

Output:

- `audit/outputs/audit_findings.csv`
- `audit/outputs/audit_report.md`

## Replication smoke tests

R data/table script:

```powershell
Rscript code/83_sumstats_baseline.R
```

Result: completed and regenerated `results/tab83_sumstats_baseline.csv` and `results/tab83_sumstats_wide.csv`.

Python map script:

```powershell
python code/71_map_factions.py
```

Result: completed and regenerated:

- `results/fig71_map_2008.pdf`
- `results/fig71_map_2024.pdf`

The regenerated `fig71` files were copied into `paper/figures/`. All 31 matching PDFs in `results/` and `paper/figures/` have identical SHA-256 hashes.

