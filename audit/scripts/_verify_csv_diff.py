"""Verify that the new electoral_competition_measures.csv matches the
expected pattern (Prefeito unchanged, Vereador 2016 corrected).

Compares the new CSV to the backup and reports the per-year, per-cargo
mean HHI / ENC / margin / n_candidates for both.
"""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
import pandas as pd
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
OLD = BASE / "_backup_pre_fix_2026-04-23/electoral_competition_measures.csv"
NEW = BASE / "data/electoral_competition_measures.csv"

old = pd.read_csv(OLD)
new = pd.read_csv(NEW)

# Normalize DS_CARGO for fair comparison
old['DS_CARGO_N'] = old['DS_CARGO'].astype(str).str.strip().str.lower().str.title()
new['DS_CARGO_N'] = new['DS_CARGO'].astype(str).str.strip().str.lower().str.title()

print("=" * 78)
print("CSV DIFF CHECK — electoral_competition_measures.csv")
print("=" * 78)
print(f"OLD: {len(old):,} rows   NEW: {len(new):,} rows")

cols = ['hhi', 'enc', 'margin_victory', 'n_candidates']
agg = {c: 'mean' for c in cols}
agg['loc_id'] = 'count' if 'loc_id' in old.columns else ('DS_CARGO', 'count')

def summary(df, tag):
    g = (df.groupby(['election_year', 'DS_CARGO_N'])
           [cols].mean().reset_index())
    g = g.sort_values(['DS_CARGO_N', 'election_year'])
    g['tag'] = tag
    return g

s_old = summary(old, 'OLD')
s_new = summary(new, 'NEW')

joined = s_old.merge(
    s_new, on=['election_year', 'DS_CARGO_N'],
    suffixes=('_old', '_new'), how='outer'
)

# Focus on Prefeito and Vereador (Title Case)
for cargo in ['Prefeito', 'Vereador']:
    sub = joined[joined['DS_CARGO_N'] == cargo].sort_values('election_year')
    print(f"\n--- {cargo} ---")
    print(f"{'year':<6}{'hhi_old':>10}{'hhi_new':>10}{'Δhhi':>9}"
          f"{'enc_old':>9}{'enc_new':>9}{'Δenc':>8}"
          f"{'mar_old':>9}{'mar_new':>9}{'Δmar':>9}"
          f"{'nc_old':>9}{'nc_new':>9}")
    for _, r in sub.iterrows():
        dh = (r['hhi_new'] - r['hhi_old'])
        de = (r['enc_new'] - r['enc_old'])
        dm = (r['margin_victory_new'] - r['margin_victory_old'])
        print(f"{int(r['election_year']):<6}"
              f"{r['hhi_old']:>10.4f}{r['hhi_new']:>10.4f}{dh:>+9.4f}"
              f"{r['enc_old']:>9.2f}{r['enc_new']:>9.2f}{de:>+8.2f}"
              f"{r['margin_victory_old']:>9.4f}{r['margin_victory_new']:>9.4f}{dm:>+9.4f}"
              f"{r['n_candidates_old']:>9.1f}{r['n_candidates_new']:>9.1f}")

# Sanity: Prefeito should be unchanged; Vereador 2016 should shift
print("\n" + "=" * 78)
print("SANITY CHECKS")
print("=" * 78)

def max_abs_diff(df, cargo, years, col):
    sub = df[df['DS_CARGO_N'] == cargo]
    sub = sub[sub['election_year'].isin(years)]
    d = (sub[f"{col}_new"] - sub[f"{col}_old"]).abs().max()
    return d

max_pref_diff_hhi = max_abs_diff(joined, 'Prefeito', [2008, 2012, 2016, 2020, 2024], 'hhi')
max_pref_diff_enc = max_abs_diff(joined, 'Prefeito', [2008, 2012, 2016, 2020, 2024], 'enc')
print(f"Prefeito: max |Δhhi| across years = {max_pref_diff_hhi:.5f}  (should be ≈ 0)")
print(f"Prefeito: max |Δenc| across years = {max_pref_diff_enc:.5f}  (should be ≈ 0)")

ver16_hhi_diff = max_abs_diff(joined, 'Vereador', [2016], 'hhi')
ver16_enc_diff = max_abs_diff(joined, 'Vereador', [2016], 'enc')
print(f"Vereador 2016: |Δhhi| = {ver16_hhi_diff:.5f}  (expected ≈ 0.005)")
print(f"Vereador 2016: |Δenc| = {ver16_enc_diff:.5f}  (expected ≈ 3–4)")

print("\nDone.")


