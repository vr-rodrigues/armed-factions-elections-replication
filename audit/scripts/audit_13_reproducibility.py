"""
audit_13_reproducibility.py
Scan scripts 70-89 for reproducibility hazards:
- set.seed() calls (or lack thereof) for any rng-using code
- random ordering / sample() / runif()
- platform-specific paths that won't work on Linux/Mac
- explicit factor() ordering on loc_id (CS-DID is sensitive to id ordering)
"""
import re
import json
from pathlib import Path

BASE = Path(r"C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais")
SCRIPTS = BASE / "scripts"
OUT = BASE / "audit" / "outputs"

candidates = sorted([p for p in SCRIPTS.glob("*.R") if p.name[:2].isdigit() and 70 <= int(p.name[:2]) <= 89] +
                    [p for p in SCRIPTS.glob("*.py") if p.name[:2].isdigit() and 70 <= int(p.name[:2]) <= 89])

results = {}
for s in candidates:
    txt = s.read_text(encoding="utf-8", errors="ignore")
    rec = dict(
        path=str(s),
        has_set_seed=bool(re.search(r"set\.seed\(", txt)),
        uses_sample=bool(re.search(r"\bsample\(", txt)),
        uses_runif=bool(re.search(r"\brunif\(", txt)),
        uses_rnorm=bool(re.search(r"\brnorm\(", txt)),
        uses_rng=bool(re.search(r"\b(?:np\.random|random\.|numpy\.random)", txt)),
        explicit_factor_order=bool(re.search(r"factor\([^)]*levels\s*=", txt)),
        sys_time_in_output=bool(re.search(r"Sys\.time\(\)|Sys\.Date\(\)|datetime\.now\(\)", txt)),
        windows_paths=bool(re.search(r"C:\\\\|C:/", txt)),
        rscript_path=bool(re.search(r"/Program Files/R", txt)),
        bootstrap_iter=re.findall(r"biters?\s*=\s*(\d+)", txt),
    )
    needs_seed = rec["uses_sample"] or rec["uses_runif"] or rec["uses_rnorm"] or rec["uses_rng"]
    if needs_seed and not rec["has_set_seed"]:
        rec["seed_warning"] = "RNG used without set.seed()"
    results[s.name] = rec

# Special attention: CS-DID's `did` package uses an influence-function bootstrap
# by default (deterministic). It accepts `bstrap=TRUE/FALSE` and `biters=N` for
# a multiplier bootstrap which IS rng-dependent. Check 89:
script89 = next(p for p in candidates if p.name.startswith("89"))
txt89 = script89.read_text()
results[script89.name]["uses_bstrap_in_attgt"] = "bstrap" in txt89

print(f"=== audit_13_reproducibility ===")
print(f"Scripts scanned: {len(results)}")
for name, rec in results.items():
    flags = []
    if rec.get("seed_warning"): flags.append(rec["seed_warning"])
    if rec.get("sys_time_in_output"): flags.append("Sys.time used")
    if flags:
        print(f"  {name}: {', '.join(flags)}")

findings = {"scripts": results}
with open(OUT / "audit_13.json", "w", encoding="utf-8") as f:
    json.dump({"test": "audit_13_reproducibility", "findings": findings}, f, indent=2, ensure_ascii=False)
print("Wrote audit_13.json")


