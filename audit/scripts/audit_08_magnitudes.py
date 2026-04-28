"""
audit_08_magnitudes.py
Verify all derived "% relative to baseline" claims in main.tex.
Paper line 202: 11% HHI, 10% ENC, 25% Margin, 3.4% Turnout
Paper line 251: 3.1% HHI, 0.2% ENC, 3.9% Margin (Vereador, post-fix)
Paper line 304: 11/10/25% (discussion repeat)
"""
import json
from pathlib import Path

BASE = Path(r"C:/Users/victo/OneDrive/Pesquisas/faccoes e eleicoes locais")
OUT  = BASE / "audit" / "outputs"

# Baselines from Table 1
baselines = {
    ("militia", "Prefeito", "hhi"):     0.350,
    ("militia", "Prefeito", "enc"):     3.428,
    ("militia", "Prefeito", "margin"):  0.207,
    ("militia", "Prefeito", "turnout"): 0.523,
    ("militia", "Vereador", "hhi"):     0.048,
    ("militia", "Vereador", "enc"):     32.17,
    ("militia", "Vereador", "margin"):  0.069,
}

# Unrounded ATTs from audit_03_repro_atts.csv (NYT)
atts_rounded = {  # paper-displayed rounding
    ("militia", "Prefeito", "hhi"):     0.039,
    ("militia", "Prefeito", "enc"):    -0.347,
    ("militia", "Prefeito", "margin"):  0.052,
    ("militia", "Prefeito", "turnout"): 0.018,
    ("militia", "Vereador", "hhi"):     0.001,
    ("militia", "Vereador", "enc"):    -0.072,
    ("militia", "Vereador", "margin"):  0.003,
}
atts = {  # unrounded for magnitude computation (from tab70_main_overall.csv post-fix)
    ("militia", "Prefeito", "hhi"):     0.03928,
    ("militia", "Prefeito", "enc"):    -0.34711,
    ("militia", "Prefeito", "margin"):  0.05164,
    ("militia", "Prefeito", "turnout"): 0.01791,
    ("militia", "Vereador", "hhi"):     0.00149,
    ("militia", "Vereador", "enc"):    -0.07195,
    ("militia", "Vereador", "margin"):  0.00265,
}
# Unrounded baselines from tab83_sumstats_baseline.csv post-fix
baselines_unrounded = {
    ("militia", "Prefeito", "hhi"):     0.3498706,
    ("militia", "Prefeito", "enc"):     3.4280034,
    ("militia", "Prefeito", "margin"):  0.2073685,
    ("militia", "Prefeito", "turnout"): 0.5233308,
    ("militia", "Vereador", "hhi"):     0.0484654,
    ("militia", "Vereador", "enc"):     32.17333,
    ("militia", "Vereador", "margin"):  0.0685458,
}

# Paper's quoted percentages
paper_pcts = {
    ("militia", "Prefeito", "hhi"):     0.11,    # "about an 11 percent"
    ("militia", "Prefeito", "enc"):     0.10,    # "about a 10 percent"
    ("militia", "Prefeito", "margin"):  0.25,    # "25 percent widening"
    ("militia", "Prefeito", "turnout"): 0.034,   # "about a 3.4 percent increase"
    ("militia", "Vereador", "hhi"):     0.031,   # "3.1 percent rise in HHI"   (post-fix)
    ("militia", "Vereador", "enc"):     0.002,   # "0.2 percent reduction"     (post-fix)
    ("militia", "Vereador", "margin"):  0.039,   # "3.9 percent widening"
}

# Paper baseline shorthand: 0.350, 3.43, 0.21, 0.52
paper_baseline_short = {
    ("militia", "Prefeito", "hhi"):     0.350,   # "baseline of 0.350"
    ("militia", "Prefeito", "enc"):     3.43,    # "baseline of 3.43"
    ("militia", "Prefeito", "margin"):  0.21,    # "baseline of 0.21"
    ("militia", "Prefeito", "turnout"): 0.52,    # "baseline of 0.52"
}

print("=== audit_08_magnitudes ===\n")
print("--- Mode A: derive % using PAPER-ROUNDED ATT and baseline (informational) ---")
findings = {}
for k, paper_pct in paper_pcts.items():
    base = baselines[k]
    att  = atts_rounded[k]
    derived = abs(att) / base
    diff = derived - paper_pct
    # Mode A is only informational — severity is driven by Mode B (unrounded)
    sev = "INFO"
    print(f"  {k}: paper={paper_pct:.3f}  derived={derived:.4f} (|{att}|/{base})  diff={diff:+.4f}  [{sev}]")
    findings[f"rounded_{k[0]}_{k[1]}_{k[2]}"] = dict(
        paper_pct=paper_pct, derived_pct=round(derived, 4),
        att=att, baseline=base, diff=round(diff, 4), severity=sev,
        note="using paper-rounded ATT & rounded baseline (INFO only)"
    )

print("\n--- Mode B: derive % using UNROUNDED ATT & baseline (true magnitude) ---")
# Tolerance: paper prose rounds to "about X percent"; allow 0.6 pp drift before flagging.
# The paper-rounded values (e.g. 11%, 10%, 25%) are two-decimal roundings of e.g. 11.23%,
# so a 0.006 tolerance on absolute pp difference is the correct reconciliation threshold.
for k, paper_pct in paper_pcts.items():
    base = baselines_unrounded[k]
    att  = atts[k]
    derived = abs(att) / base
    diff = derived - paper_pct
    sev = "HIGH" if abs(diff) > 0.01 else ("MEDIUM" if abs(diff) > 0.006 else "OK")
    print(f"  {k}: paper={paper_pct:.3f}  derived={derived:.4f} (|{att:.5f}|/{base:.5f})  diff={diff:+.4f}  [{sev}]")
    findings[f"unrounded_{k[0]}_{k[1]}_{k[2]}"] = dict(
        paper_pct=paper_pct, derived_pct=round(derived, 4),
        att=att, baseline=base, diff=round(diff, 4), severity=sev,
        note="using unrounded ATT & baseline; tolerance=0.6pp for prose rounding"
    )

print("\n--- Paper baseline shorthand vs Table 1 exact ---")
# Paper prose rounds Table 1 baselines to 2 decimals (0.21, 0.52, 3.43) for readability.
# The two-decimal prose value is an acceptable rounding of the three-decimal table value
# when |diff| <= 0.005 (half of the last retained decimal).
for k, p_short in paper_baseline_short.items():
    exact = baselines[k]
    diff = exact - p_short
    sev = "OK" if abs(diff) <= 0.005 else "MEDIUM"
    print(f"{k}: paper-short={p_short}  exact={exact}  diff={diff:+.4f}  [{sev}]")
    findings[f"baseline_short_{k[1]}_{k[2]}"] = dict(
        paper_short=p_short, exact=exact, diff=round(diff, 4), severity=sev,
        note="two-decimal prose rounding of three-decimal table value; tol=0.005"
    )

# 18% flip rate (mentioned in problema descobertas)
# Skipped — no claim of "18% flip rate" in current main.tex (only in old notes).

with open(OUT / "audit_08.json", "w", encoding="utf-8") as f:
    json.dump({"test": "audit_08_magnitudes", "findings": findings}, f, indent=2, ensure_ascii=False)
print("\nWrote audit_08.json")


