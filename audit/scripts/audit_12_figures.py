"""
audit_12_figures.py
For every \\includegraphics{...} in main.tex, confirm the file exists in
paper/overleaf_project/figures/.
"""
import re
import json
from pathlib import Path

BASE = Path(r"C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais")
MAIN = BASE / "paper" / "overleaf_project" / "main.tex"
FIGD = BASE / "paper" / "overleaf_project" / "figures"
OUT  = BASE / "audit" / "outputs"

text = MAIN.read_text(encoding="utf-8")
inc_re = re.compile(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}")

refs = []
missing = []
present = []
for i, line in enumerate(text.split("\n"), 1):
    for m in inc_re.finditer(line):
        fname = m.group(1)
        # Some references omit the .pdf extension
        candidates = [fname, fname + ".pdf", fname + ".png", fname + ".jpg"]
        found = None
        for c in candidates:
            if (FIGD / c).exists():
                found = c
                break
        refs.append({"line": i, "ref": fname, "resolved": found})
        if found:
            present.append((i, fname, found))
        else:
            missing.append((i, fname))

print(f"=== audit_12_figures ===")
print(f"Total \\includegraphics: {len(refs)}")
print(f"Resolved: {len(present)}")
print(f"Missing:  {len(missing)}")
for i, f in missing:
    print(f"  MISSING: line {i}: {f}")

findings = dict(
    n_total=len(refs), n_present=len(present), n_missing=len(missing),
    missing=[{"line": l, "ref": f} for l, f in missing],
    present=[{"line": l, "ref": f, "file": x} for l, f, x in present]
)
with open(OUT / "audit_12.json", "w", encoding="utf-8") as f:
    json.dump({"test": "audit_12_figures", "findings": findings}, f, indent=2, ensure_ascii=False)
print(f"Wrote audit_12.json")


