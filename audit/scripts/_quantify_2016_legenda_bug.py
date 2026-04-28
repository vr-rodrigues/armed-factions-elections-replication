"""Quantify HHI/ENC/margin contamination in Vereador 2016 due to legenda-vote bug."""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
import pandas as pd
import numpy as np
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
TSE = BASE / "data/tse"
CSV_OUT = BASE / "data/electoral_competition_measures.csv"

print("=" * 70)
print("QUANTIFY: 2016 Vereador legenda-vote contamination")
print("=" * 70)

# Load 2016 raw TSE
print("\nLoading 2016 raw TSE...")
df = pd.read_csv(TSE / "votacao_secao_RJ_2016.csv", dtype=str, low_memory=False)
print(f"  rows: {len(df):,}")
print(f"  DS_CARGO unique: {sorted(df['DS_CARGO'].unique())}")
print(f"  Vereador rows: {(df['DS_CARGO'] == 'VEREADOR').sum():,}")

# Reproduce the buggy logic: is_proportional via case-sensitive isin
proportional_cargos_buggy = {'Vereador', 'Deputado Estadual', 'Deputado Federal'}
df['is_proportional_buggy'] = df['DS_CARGO'].isin(proportional_cargos_buggy)
# Correct logic
proportional_cargos_norm = {'vereador', 'deputado estadual', 'deputado federal'}
df['is_proportional_correct'] = df['DS_CARGO'].str.lower().str.strip().isin(proportional_cargos_norm)

print(f"\n  is_proportional BUGGY for Vereador 2016: {df.loc[df['DS_CARGO']=='VEREADOR','is_proportional_buggy'].mean():.0%}")
print(f"  is_proportional CORRECT for Vereador 2016: {df.loc[df['DS_CARGO']=='VEREADOR','is_proportional_correct'].mean():.0%}")

# Filter to Vereador only
ver = df[df['DS_CARGO'] == 'VEREADOR'].copy()
ver['nr_len'] = ver['NR_VOTAVEL'].str.len()
ver['is_special'] = ver['NR_VOTAVEL'].isin({'95', '96'})
print(f"\n  Vereador 2016 — distribution of NR_VOTAVEL length:")
print(ver['nr_len'].value_counts().to_string())

# Buggy: is_legenda = is_proportional_buggy & nr_len==2 & ~is_special  → all False
ver['is_legenda_buggy'] = ver['is_proportional_buggy'] & (ver['nr_len'] == 2) & ~ver['is_special']
ver['is_legenda_correct'] = ver['is_proportional_correct'] & (ver['nr_len'] == 2) & ~ver['is_special']

n_bug = ver['is_legenda_buggy'].sum()
n_correct = ver['is_legenda_correct'].sum()
votes_bug = ver.loc[ver['is_legenda_buggy'], 'QT_VOTOS'].astype(int).sum()
votes_correct = ver.loc[ver['is_legenda_correct'], 'QT_VOTOS'].astype(int).sum()

print(f"\n  Legenda rows BUGGY identified : {n_bug:,}")
print(f"  Legenda rows CORRECT identified: {n_correct:,}")
print(f"  Legenda votes BUGGY counted in HHI : {votes_bug:,}")
print(f"  Legenda votes CORRECT (excluded)   : {votes_correct:,}")
print(f"  ⇒ Bug counts {votes_correct:,} legenda votes as candidate votes")

# Compute HHI/ENC for Vereador 2016 under both logics, station-level
def compute_metrics(df_in, exclude_legenda):
    d = df_in[~df_in['is_special']].copy()
    if exclude_legenda:
        d = d[~d['is_legenda_correct']]
    d['QT_VOTOS'] = d['QT_VOTOS'].astype(int)
    grp = ['CD_MUNICIPIO', 'NR_ZONA', 'NR_LOCAL_VOTACAO']
    cand = d.groupby(grp + ['NR_VOTAVEL'])['QT_VOTOS'].sum().reset_index()
    valid = cand.groupby(grp)['QT_VOTOS'].sum().reset_index().rename(columns={'QT_VOTOS': 'valid'})
    cand = cand.merge(valid, on=grp)
    cand['share'] = cand['QT_VOTOS'] / cand['valid'].replace(0, np.nan)
    cand['share2'] = cand['share'] ** 2
    out = cand.groupby(grp).agg(
        hhi=('share2', 'sum'),
        n_cand=('share', 'count')
    ).reset_index()
    out['enc'] = 1 / out['hhi']
    # margin
    top = cand.sort_values(grp + ['share'], ascending=[True]*len(grp)+[False])
    top['rank'] = top.groupby(grp).cumcount()
    top1 = top[top['rank']==0].set_index(grp)['share'].rename('top1')
    top2 = top[top['rank']==1].set_index(grp)['share'].rename('top2')
    out = out.merge(top1, on=grp).merge(top2, on=grp, how='left')
    out['top2'] = out['top2'].fillna(0)
    out['margin'] = out['top1'] - out['top2']
    return out

print("\nComputing competition metrics under both logics...")
buggy = compute_metrics(ver, exclude_legenda=False)
correct = compute_metrics(ver, exclude_legenda=True)

print(f"\n  Vereador 2016 — BUGGY  pipeline (used to generate CSV in repo):")
print(f"    mean HHI={buggy['hhi'].mean():.4f}  ENC={buggy['enc'].mean():.2f}  margin={buggy['margin'].mean():.4f}  n_cand={buggy['n_cand'].mean():.1f}")
print(f"  Vereador 2016 — CORRECT pipeline (legenda excluded):")
print(f"    mean HHI={correct['hhi'].mean():.4f}  ENC={correct['enc'].mean():.2f}  margin={correct['margin'].mean():.4f}  n_cand={correct['n_cand'].mean():.1f}")

print(f"\n  Δ HHI    = {(buggy['hhi'].mean() - correct['hhi'].mean()):+.4f}")
print(f"  Δ ENC    = {(buggy['enc'].mean() - correct['enc'].mean()):+.2f}")
print(f"  Δ margin = {(buggy['margin'].mean() - correct['margin'].mean()):+.4f}")
print(f"  Δ n_cand = {(buggy['n_cand'].mean() - correct['n_cand'].mean()):+.2f}")

# Compare to CSV currently saved
print("\n--- Cross-check: CSV electoral_competition_measures.csv for 2016 Vereador ---")
csv = pd.read_csv(CSV_OUT)
csv16v = csv[(csv['election_year'] == 2016) & (csv['DS_CARGO'].str.upper() == 'VEREADOR')]
print(f"  rows: {len(csv16v):,}")
print(f"  mean HHI={csv16v['hhi'].mean():.4f}  ENC={csv16v['enc'].mean():.2f}  margin={csv16v['margin_victory'].mean():.4f}")
print(f"  ⇒ matches BUGGY mean HHI? {abs(csv16v['hhi'].mean() - buggy['hhi'].mean()) < 0.005}")

# Also show 2012 for sanity (no bug — Title case)
print("\n--- Sanity: Vereador 2012 should be OK ---")
csv12v = csv[(csv['election_year'] == 2012) & (csv['DS_CARGO'].str.upper() == 'VEREADOR')]
print(f"  CSV 2012 vereador mean HHI={csv12v['hhi'].mean():.4f}  ENC={csv12v['enc'].mean():.2f}  margin={csv12v['margin_victory'].mean():.4f}")

# What this means for paper Table 1 baseline (vereador militia: hhi=0.047, enc=33.16, margin=0.068)
print("\n--- Implication for paper Table 1 (Panel B, Vereador) ---")
print("  Reported: HHI=0.046-0.047, ENC=30-36, margin=0.048-0.068")
print(f"  If 2016 is contaminated, baseline mean is biased by approximately:")
print(f"    ΔHHI / 5 elec = {(buggy['hhi'].mean() - correct['hhi'].mean())/5:+.4f}")
print(f"    ΔENC / 5 elec = {(buggy['enc'].mean() - correct['enc'].mean())/5:+.2f}")


