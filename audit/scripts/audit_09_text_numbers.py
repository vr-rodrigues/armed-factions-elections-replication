"""
audit_09_text_numbers.py
Regex parse all numerical claims from main.tex and cross-check.
Catalogue every number > 1 or with a decimal that appears outside math envs.
"""
import re
import json
from pathlib import Path

BASE = Path(r"C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais")
MAIN = BASE / "paper" / "overleaf_project" / "main.tex"
OUT  = BASE / "audit" / "outputs"

text_raw = MAIN.read_text(encoding="utf-8")
lines = text_raw.split("\n")
# Normalize LaTeX-escaped comma-group {,} to plain comma for substring matching
text = text_raw.replace("{,}", ",")

# Find all decimal numbers, percentages, and 4+ digit integer counts (population sizes)
num_re = re.compile(r"(?<![A-Za-z0-9.])(\d{1,3}(?:[,.]?\d{3})+|\d+\.\d+|\d+\s?(?:percent|%|pp))(?![A-Za-z0-9])", re.IGNORECASE)
short_re = re.compile(r"\b(\d+(?:\.\d+)?)\s?percent\b", re.IGNORECASE)
sci_pct_re = re.compile(r"(\d+(?:\.\d+)?)\\%")
n_count_re = re.compile(r"(\d{1,3}(?:[,.]\d{3})+|\d{4,})")

claims = []
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith("%") or not stripped:
        continue
    # Find all candidate numbers in the line
    for m in num_re.finditer(line):
        v = m.group(1)
        ctx = line[max(0, m.start()-30):min(len(line), m.end()+30)]
        claims.append({"tex_line": i, "raw": v, "context": ctx.strip()})

# Save full inventory
with open(OUT / "audit_09_text_numbers_full.json", "w", encoding="utf-8") as f:
    json.dump({"n_claims": len(claims), "claims": claims}, f, indent=2, ensure_ascii=False)

# Cross-check: a curated set of high-impact text-only claims.
# The check is "does the number token appear at least N times in main.tex?" — format-agnostic
# (matches both "4,180" and "4{,}180").
checks = [
    # (token, min_count, claim_label, severity_if_missing)
    ("4,180",                        3, "4,180 geocoded stations",              "CRITICAL"),
    ("398",                          3, "398 militia stations",                 "CRITICAL"),
    ("240",                          3, "240 drug stations",                    "CRITICAL"),
    ("3,791",                        6, "3,791 never-treated stations (prose + Table 1)", "CRITICAL"),
    ("97.2",                         1, "97.2% polygon stability",              "MEDIUM"),
    ("38 favelas",                   1, "38 favelas",                           "LOW"),
    ("4,654",                        1, "4,654 unique stations",                "HIGH"),
    ("474",                          1, "474 no-coord stations",                "MEDIUM"),
    ("1,740",                        1, "1,740 balanced (5 elections)",         "HIGH"),
    ("173 (4.1",                     1, "173 (4.1%) in 4 elections",            "MEDIUM"),
    ("1,024 (24.5",                  1, "1,024 (24.5%) in 3 elections",         "MEDIUM"),
    ("979 (23.4",                    1, "979 (23.4%) in 2 elections",           "MEDIUM"),
    ("217 (5.2",                     1, "217 (5.2%) in 1 election",             "MEDIUM"),
    ("47 (1.1",                      1, "47 (1.1%) in 0 elections",             "MEDIUM"),
    ("712 stations ever classified", 1, "712 ever-classified stations",         "HIGH"),
    ("401",                          2, "401 stable Militia",                   "HIGH"),
    ("246",                          2, "246 stable Drug",                      "HIGH"),
    ("65 as switchers",              1, "65 switchers",                         "HIGH"),
    ("40 stations transition",       1, "40 drug→militia",                      "HIGH"),
    ("25 transition from militia",   1, "25 militia→drug",                      "HIGH"),
    ("9.1",                          1, "9.1% switchers of ever-treated",       "MEDIUM"),
    ("3,468",                        1, "3,468 never-treated (classification)", "MEDIUM"),
    # Table 1 previously reported 3,789 but tab83_sumstats_baseline.csv has
    # n_stations=3,791 for never_treated Prefeito. The paper was updated so that
    # Table 1 and prose agree at 3,791 (counted via the "3,791" check above).
    ("18 annual control polygons published between 2007 and 2024", 1,
                                        "18 annual polygons 2007-2024",         "MEDIUM"),
]

findings = {}
for token, min_count, label, sev in checks:
    occ = text.count(token)
    ok = occ >= min_count
    findings[label] = {
        "token": token, "min_count": min_count, "observed_count": occ,
        "found_in_text": ok,
        "severity": "OK" if ok else sev,
        "note": "" if ok else f"Token '{token}' found {occ}x, expected >= {min_count}"
    }

with open(OUT / "audit_09.json", "w", encoding="utf-8") as f:
    json.dump({"test": "audit_09_text_numbers", "findings": findings,
               "n_total_numbers_extracted": len(claims)}, f, indent=2, ensure_ascii=False)
print(f"=== audit_09_text_numbers ===")
print(f"Extracted {len(claims)} numeric tokens from main.tex")
n_found = sum(1 for v in findings.values() if v.get('found_in_text', False))
print(f"Substring checks: {n_found}/{len(checks)} found")
for k, v in findings.items():
    if not v.get("found_in_text", True):
        print(f"  NOT FOUND: '{k}' (token '{v.get('token')}')  [{v.get('severity')}]")
print(f"Wrote audit_09.json + audit_09_text_numbers_full.json")


