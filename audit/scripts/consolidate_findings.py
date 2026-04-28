"""
consolidate_findings.py
Read audit_*.json and emit:
  - audit_findings.csv (one row per atomic finding, sorted by severity)
  - audit_report.md    (human-readable report in Portuguese)
"""
import json
import csv
from pathlib import Path
from datetime import datetime

BASE = Path(r"C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais")
OUT  = BASE / "audit" / "outputs"

SEV_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4, "OK": 5}

def severity_of(v):
    """Resolve severity: explicit + diff-based fallback."""
    if not isinstance(v, dict):
        return "INFO"
    explicit = v.get("severity")
    if explicit in SEV_ORDER:
        return explicit
    return "INFO"

def is_actual_mismatch(v):
    """True if the finding represents an actual data discrepancy."""
    if not isinstance(v, dict):
        return False
    # If we have reported/reproduced and they match, no mismatch
    rep = v.get("reported")
    rpd = v.get("reproduced")
    if rep is not None and rpd is not None:
        try:
            if abs(float(rep) - float(rpd)) < 1e-9:
                return False
        except (ValueError, TypeError):
            if rep == rpd:
                return False
    diff = v.get("diff")
    if diff is not None:
        try:
            if abs(float(diff)) < 1e-9:
                return False
        except (ValueError, TypeError):
            pass
    # ATT-style finding
    for k in ["att_diff", "mean_diff", "se_diff", "wald_diff", "ci_lo_diff", "ci_hi_diff", "mbar_diff"]:
        d = v.get(k)
        if d is not None:
            try:
                if abs(float(d)) >= 0.001:  # non-trivial
                    return True
            except (ValueError, TypeError):
                pass
        # if all _diff are tiny, no mismatch
    # If we got here with no reported/reproduced and no diffs were meaningful,
    # default to "info" only if there are no diff fields at all
    if any(k in v for k in ["att_diff","mean_diff","se_diff","wald_diff","ci_lo_diff","ci_hi_diff","mbar_diff"]):
        return False  # all diffs were tiny
    return True  # finding without diff fields — keep its severity

rows = []
for jf in sorted(OUT.glob("audit_*.json")):
    with open(jf, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except Exception as e:
            print(f"WARN: failed to parse {jf}: {e}")
            continue
    test = data.get("test", jf.stem)
    findings = data.get("findings", {}) or {}
    if isinstance(findings, dict):
        items = findings.items()
    else:
        items = [(jf.stem, findings)]
    for k, v in items:
        if not isinstance(v, dict):
            v = {"value": v}
        sev = severity_of(v)
        # Demote to OK if there is no actual mismatch
        if sev != "OK" and not is_actual_mismatch(v):
            sev = "OK"
        rows.append({
            "test": test,
            "finding_id": k,
            "severity": sev,
            "reported": v.get("reported", v.get("att_paper", v.get("mean_paper", v.get("ci_lo_paper", "")))),
            "reproduced": v.get("reproduced", v.get("att_repro", v.get("mean_repro", v.get("ci_lo_repro", "")))),
            "diff": v.get("diff", v.get("att_diff", v.get("mean_diff", v.get("ci_lo_diff", "")))),
            "description": v.get("desc", v.get("note", "")),
            "json_file": jf.name,
        })

rows.sort(key=lambda r: (SEV_ORDER.get(r["severity"], 99), r["test"], r["finding_id"]))

with open(OUT / "audit_findings.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["test","finding_id","severity","reported","reproduced","diff","description","json_file"])
    w.writeheader()
    w.writerows(rows)

# ----- Markdown report -----
sev_groups = {}
for r in rows:
    sev_groups.setdefault(r["severity"], []).append(r)

lines = []
lines.append("# Auditoria forense — main.tex × results/dados")
lines.append("")
lines.append(f"**Data:** {datetime.now().date().isoformat()}")
lines.append(f"**Manuscrito auditado:** `paper/overleaf_project/main.tex`")
lines.append(f"**Suíte:** `audit/scripts/audit_01..14`")
lines.append("")
lines.append("## Sumário")
lines.append("")
lines.append("| Severidade | Findings |")
lines.append("|---|---|")
for sev in ["CRITICAL","HIGH","MEDIUM","LOW","INFO","OK"]:
    lines.append(f"| {sev} | {len(sev_groups.get(sev, []))} |")
lines.append("")

for sev in ["CRITICAL","HIGH","MEDIUM","LOW","INFO"]:
    items = sev_groups.get(sev, [])
    if not items: continue
    lines.append(f"## {sev}")
    lines.append("")
    for r in items:
        rep = r["reported"]; rpd = r["reproduced"]; df = r["diff"]
        if rep == "" and rpd == "":
            lines.append(f"- **{r['finding_id']}** ({r['test']}): {r['description']}")
        else:
            lines.append(f"- **{r['finding_id']}** ({r['test']}): reportado=`{rep}` | reproduzido=`{rpd}` | diff=`{df}` — {r['description']}")
    lines.append("")

with open(OUT / "audit_report.md", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"=== consolidate_findings ===")
print(f"Total findings: {len(rows)}")
for sev in ["CRITICAL","HIGH","MEDIUM","LOW","INFO","OK"]:
    print(f"  {sev}: {len(sev_groups.get(sev, []))}")
print("Wrote audit_findings.csv + audit_report.md")


