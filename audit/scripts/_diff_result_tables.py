"""Diff old (backup) and new result tables to list every number that
changed, so we know exactly which cells in main.tex need updating.
"""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
import pandas as pd
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
OLD = BASE / "_backup_pre_fix_2026-04-23"
NEW = BASE / "results"

# ── tab70_main_overall (NYT + NT ATTs for all cargo/outcome cells) ───────────
print("=" * 78)
print("TAB70 (tab:csdid_main, tab:csdid_vereador, tab:csdid_*_nt)")
print("=" * 78)
try:
    o = pd.read_csv(OLD / "tab70_main_overall.csv")
    n = pd.read_csv(NEW / "tab70_main_overall.csv")
    key = ['spec', 'cargo', 'outcome', 'estimator']
    cols = ['att', 'se', 'p_value', 'wald_stat', 'wald_p']
    m = o.merge(n, on=key, suffixes=('_old', '_new'))
    for c in cols:
        m[f"d_{c}"] = m[f"{c}_new"] - m[f"{c}_old"]
    for _, r in m.iterrows():
        d_att = r['d_att']
        d_se = r['d_se']
        d_waldp = r['d_wald_p']
        if abs(d_att) > 0.0005 or abs(d_se) > 0.0005 or abs(d_waldp) > 0.005:
            print(f"  {r['spec']:<7} {r['cargo']:<9} {r['outcome']:<16} "
                  f"{r['estimator']:<4}  "
                  f"ATT {r['att_old']:+.4f}->{r['att_new']:+.4f} (Δ={d_att:+.4f})  "
                  f"SE {r['se_old']:.4f}->{r['se_new']:.4f} "
                  f"WALDp {r['wald_p_old']:.3f}->{r['wald_p_new']:.3f}")
except FileNotFoundError as e:
    print(f"   (table missing: {e.filename})")

# ── tab80_honest_did (Honest-DiD breakdown Mbar for militia/prefeito) ────────
print()
print("=" * 78)
print("TAB80 (tab:honest_did) — should be UNCHANGED (prefeito only)")
print("=" * 78)
try:
    o = pd.read_csv(OLD / "tab80_honest_did.csv")
    n = pd.read_csv(NEW / "tab80_honest_did.csv")
    key = [c for c in o.columns if c not in ('Mbar', 'm_bar', 'ci_lo', 'ci_hi', 'att')
           and o[c].dtype == object]
    print(f"  key cols: {key}")
    for i, r_o in o.iterrows():
        r_n = n.iloc[i]
        numerics = [c for c in o.columns if o[c].dtype != object]
        shown = False
        for c in numerics:
            if pd.notna(r_o[c]) and pd.notna(r_n[c]):
                if abs(r_o[c] - r_n[c]) > 0.001:
                    if not shown:
                        print(f"  row {i}: {dict((k, r_o[k]) for k in key)}")
                        shown = True
                    print(f"     {c}: {r_o[c]:.4f} -> {r_n[c]:.4f}")
except FileNotFoundError as e:
    print(f"   (table missing: {e.filename})")

# ── tab87 balance (should be unchanged — it uses Prefeito outcomes) ──────────
print()
print("=" * 78)
print("TAB87 militia + drug — balance (likely prefeito-only)")
print("=" * 78)
for suf in ['militia', 'drug']:
    try:
        o = pd.read_csv(OLD / f"tab87_balance_{suf}.csv")
        n = pd.read_csv(NEW / f"tab87_balance_{suf}.csv")
        if o.equals(n):
            print(f"  tab87_balance_{suf}: UNCHANGED")
        else:
            print(f"  tab87_balance_{suf}: CHANGED (inspect)")
    except FileNotFoundError as e:
        print(f"   (missing: {e.filename})")

# ── tab89 dynamic ────────────────────────────────────────────────────────────
print()
print("=" * 78)
print("TAB89 (dynamic aggregation, event-study)")
print("=" * 78)
try:
    o = pd.read_csv(OLD / "tab89_dynamic_overall.csv")
    n = pd.read_csv(NEW / "tab89_dynamic_overall.csv")
    print(f"  OLD rows={len(o)} NEW rows={len(n)} cols={list(o.columns)}")
    if not o.equals(n):
        common = [c for c in o.columns if c in n.columns]
        merge_key = [c for c in common if o[c].dtype == object]
        print(f"  merge_key={merge_key}")
except FileNotFoundError as e:
    print(f"   (missing: {e.filename})")

# ── tab79 event-study ────────────────────────────────────────────────────────
print()
print("=" * 78)
print("TAB79 (event-study)")
print("=" * 78)
try:
    o = pd.read_csv(OLD / "tab79_event_study.csv")
    n = pd.read_csv(NEW / "tab79_event_study.csv")
    print(f"  OLD rows={len(o)} NEW rows={len(n)} cols={list(o.columns)}")
except FileNotFoundError as e:
    print(f"   (missing: {e.filename})")

print()
print("Done.")


