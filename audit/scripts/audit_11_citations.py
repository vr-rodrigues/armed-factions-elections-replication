"""
audit_11_citations.py
Extends scripts/audit_cites.py: catalogs all \\cite{,p,t}-style commands,
checks each key against references.bib, and flags claim-citation mismatches
known from notas/auditoria_citacoes.md.
"""
import re
import json
from pathlib import Path

BASE = Path(r"C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais")
MAIN = BASE / "paper" / "overleaf_project" / "main.tex"
BIB  = BASE / "paper" / "overleaf_project" / "references.bib"
OUT  = BASE / "audit" / "outputs"

text = MAIN.read_text(encoding="utf-8")
bibtxt = BIB.read_text(encoding="utf-8")

# Find all \cite{*}, \citep{*}, \citet{*}, \citealt{*}
cite_re = re.compile(r"\\cite[a-z]*\{([^}]+)\}")
keys_in_text = set()
key_lines = {}
for i, line in enumerate(text.split("\n"), 1):
    for m in cite_re.finditer(line):
        for k in m.group(1).split(","):
            k = k.strip()
            keys_in_text.add(k)
            key_lines.setdefault(k, []).append(i)

# Find all bib entries
bib_re = re.compile(r"^@\w+\{\s*([^,\s]+)\s*,", re.MULTILINE)
bib_keys = set(bib_re.findall(bibtxt))

missing = sorted(keys_in_text - bib_keys)
unused = sorted(bib_keys - keys_in_text)

print(f"=== audit_11_citations ===")
print(f"Distinct cite keys in main.tex: {len(keys_in_text)}")
print(f"Distinct entries in references.bib: {len(bib_keys)}")
print(f"Cite keys missing from .bib (HARD ERROR): {len(missing)}")
for k in missing: print(f"  MISSING: {k}  (used at lines {key_lines[k]})")
print(f"Bib entries not cited (cleanup): {len(unused)}")

# Cross-reference known issues from notas/auditoria_citacoes.md
known_issues = [
    ("magaloni2020", "MEDIUM",
     "Cite key uses authors+journal that don't match real Magaloni 2020 paper. "
     "Likely should be magaloni2020killing or removed."),
    ("blattman2017gangs", "MEDIUM",
     "Key says 2017 but year is 2024 in .bib; content (gangs+labor mobility, San Salvador) "
     "doesn't fit the claim 'effects on turnout, candidate selection, campaign violence'."),
    ("monteiro2022criminal", "MEDIUM",
     "Possible duplicate of monteiro2023enterprises — same title, different authors. "
     "Verify if they're the same paper."),
    ("hidalgo2025elections", "LOW",
     "Cite key suggests Hidalgo et al. but author field is Pantaleao-Montini. "
     "Verify Cambridge Core attribution.")
]

issues_findings = {}
for key, sev, note in known_issues:
    used_lines = key_lines.get(key, [])
    in_bib = key in bib_keys
    issues_findings[key] = dict(
        present_in_bib=in_bib, used_at_lines=used_lines,
        severity=sev, note=note
    )

# Save full findings
findings = dict(
    n_keys_in_text=len(keys_in_text),
    n_keys_in_bib=len(bib_keys),
    missing_from_bib=missing,
    unused_in_bib=unused,
    known_issues=issues_findings,
    all_cite_keys_in_text=sorted(keys_in_text)
)
with open(OUT / "audit_11.json", "w", encoding="utf-8") as f:
    json.dump({"test": "audit_11_citations", "findings": findings}, f, indent=2, ensure_ascii=False)
print("Wrote audit_11.json")


