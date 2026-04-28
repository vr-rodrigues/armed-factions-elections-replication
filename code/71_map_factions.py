"""
71_map_factions.py — Maps of faction territories + voting locations (2008 and 2024)

Shows:
  - Faction territory polygons (Drug = red, Militia = blue)
  - Voting locations INSIDE territories (same color, circle marker)
  - Voting locations OUTSIDE territories (grey, small dot)
  - RJ municipality boundary as base layer
"""

import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
OUT_DIR = BASE_DIR / "results"

# ── 1. Load data ────────────────────────────────────────────────────────────

# Voting locations with treatment status
dt_treat = pd.read_csv(BASE_DIR / "data" / "locais_votacao_treatment_annual.csv")
dt_treat["loc_id"] = dt_treat["loc_id"].astype(str)

# Faction classification
dt_chg = pd.read_csv(BASE_DIR / "data" / "loc_faction_changes.csv")
dt_chg["loc_id"] = dt_chg["loc_id"].astype(str)

# RJ municipality boundaries (IBGE)
gdf_mun = gpd.read_file(BASE_DIR / "data" / "municipios_rj.geojson")

# Filter to metro RJ municipalities used in the study
xwalk = pd.read_csv(BASE_DIR / "data" / "municipios_crosswalk.csv")
metro_codes = xwalk["ibge_7"].astype(str).tolist()
gdf_mun["codarea"] = gdf_mun["codarea"].astype(str)
gdf_metro = gdf_mun[gdf_mun["codarea"].isin(metro_codes)]

# Remove Ilha Grande / Mangaratiba area (far southwest island)
# Keep only municipalities whose centroid is above -23.05 lat (drops the island)
gdf_metro = gdf_metro[gdf_metro.geometry.centroid.y > -23.05]
print(f"Metro RJ municipalities: {len(gdf_metro)}")

# ── 2. Build maps for 2008 and 2024 ────────────────────────────────────────

for year in [2008, 2024]:
    print(f"\n=== Building map for {year} ===")

    # Load controle polygons for this year
    gdf_ctrl = gpd.read_file(BASE_DIR / "data" / "annual" / f"{year}_controle.geojson")
    print(f"  Polygons: {len(gdf_ctrl)}")

    # Classify faction type
    gdf_ctrl["faction"] = gdf_ctrl["Grupo_Armado_soControle"].apply(
        lambda x: "Militia" if "Mil" in str(x) else "Drug"
    )

    # Voting locations for this year
    locs_year = dt_treat[dt_treat["election_year"] == year][
        ["loc_id", "lat", "lon", "inside_controle", "faction_type_controle"]
    ].drop_duplicates(subset="loc_id")

    # Merge faction classification
    locs_year = locs_year.merge(
        dt_chg[["loc_id", "change_type"]].drop_duplicates(),
        on="loc_id", how="left"
    )

    # Classify locations
    locs_year["loc_faction"] = "Outside"
    locs_year.loc[
        locs_year["change_type"].isin(["stable_Militia", "Militia_to_Drug"]) &
        (locs_year["inside_controle"] == 1),
        "loc_faction"
    ] = "Militia"
    locs_year.loc[
        locs_year["change_type"].isin(["stable_Drug", "Drug_to_Militia"]) &
        (locs_year["inside_controle"] == 1),
        "loc_faction"
    ] = "Drug"
    # Also classify by faction_type_controle for locations not in dt_chg
    locs_year.loc[
        (locs_year["loc_faction"] == "Outside") &
        (locs_year["inside_controle"] == 1) &
        (locs_year["faction_type_controle"].str.contains("Mil", na=False)),
        "loc_faction"
    ] = "Militia"
    locs_year.loc[
        (locs_year["loc_faction"] == "Outside") &
        (locs_year["inside_controle"] == 1) &
        (locs_year["faction_type_controle"].isin(["CV", "TCP", "ADA"])),
        "loc_faction"
    ] = "Drug"

    print(f"  Voting locations: {len(locs_year)}")
    print(f"    Outside: {(locs_year['loc_faction'] == 'Outside').sum()}")
    print(f"    Militia: {(locs_year['loc_faction'] == 'Militia').sum()}")
    print(f"    Drug:    {(locs_year['loc_faction'] == 'Drug').sum()}")

    # Convert to GeoDataFrame
    gdf_locs = gpd.GeoDataFrame(
        locs_year,
        geometry=gpd.points_from_xy(locs_year["lon"], locs_year["lat"]),
        crs="EPSG:4326"
    )

    # ── Plot ────────────────────────────────────────────────────────────────

    fig, ax = plt.subplots(1, 1, figsize=(10, 8))

    # Municipality boundaries (base layer)
    gdf_metro.plot(ax=ax, facecolor="white", edgecolor="#999999",
                   linewidth=0.5, zorder=0)

    # Territory polygons
    drug_polys = gdf_ctrl[gdf_ctrl["faction"] == "Drug"]
    militia_polys = gdf_ctrl[gdf_ctrl["faction"] == "Militia"]

    if len(drug_polys) > 0:
        drug_polys.plot(ax=ax, color="#D64541", alpha=0.30, edgecolor="#D64541",
                        linewidth=0.2, zorder=1)
    if len(militia_polys) > 0:
        militia_polys.plot(ax=ax, color="#DAA520", alpha=0.30, edgecolor="#DAA520",
                           linewidth=0.2, zorder=1)

    # Voting locations — outside (grey x, small)
    outside = gdf_locs[gdf_locs["loc_faction"] == "Outside"]
    if len(outside) > 0:
        ax.scatter(outside.geometry.x, outside.geometry.y,
                   marker="x", s=4, c="#777777", linewidths=0.3,
                   alpha=0.45, zorder=2)

    # Voting locations — inside Drug (red circle)
    drug_locs = gdf_locs[gdf_locs["loc_faction"] == "Drug"]
    if len(drug_locs) > 0:
        ax.scatter(drug_locs.geometry.x, drug_locs.geometry.y,
                   marker="o", s=8, c="#D64541", edgecolors="black",
                   linewidths=0.2, alpha=0.85, zorder=3)

    # Voting locations — inside Militia (yellow triangle)
    militia_locs = gdf_locs[gdf_locs["loc_faction"] == "Militia"]
    if len(militia_locs) > 0:
        ax.scatter(militia_locs.geometry.x, militia_locs.geometry.y,
                   marker="^", s=10, c="#DAA520", edgecolors="black",
                   linewidths=0.2, alpha=0.85, zorder=3)

    # Legend: only on the 2008 map, upper-left corner, larger font
    if year == 2008:
        legend_elements = [
            mpatches.Patch(facecolor="#DAA520", alpha=0.30, edgecolor="#DAA520",
                           label="Militia territory"),
            mpatches.Patch(facecolor="#D64541", alpha=0.30, edgecolor="#D64541",
                           label="Drug faction territory"),
            plt.Line2D([0], [0], marker="^", color="w", markerfacecolor="#DAA520",
                       markeredgecolor="black", markersize=10,
                       label="Voting loc. (Militia)"),
            plt.Line2D([0], [0], marker="o", color="w", markerfacecolor="#D64541",
                       markeredgecolor="black", markersize=10,
                       label="Voting loc. (Drug)"),
            plt.Line2D([0], [0], marker="x", color="#777777", linestyle="None",
                       markersize=9, markeredgewidth=1.5,
                       label="Voting loc. (outside)"),
        ]
        ax.legend(handles=legend_elements, loc="upper left", fontsize=14,
                  framealpha=0.95, frameon=True, borderpad=0.8,
                  handletextpad=0.8, labelspacing=0.6)

    ax.set_axis_off()
    # Title removed from plot — year shown in LaTeX subcaption instead.

    # Zoom to metro RJ extent with padding
    minx, miny, maxx, maxy = gdf_metro.total_bounds
    pad = 0.02
    ax.set_xlim(minx - pad, maxx + pad)
    ax.set_ylim(miny - pad, maxy + pad)

    plt.tight_layout()
    fn = OUT_DIR / f"fig71_map_{year}.pdf"
    plt.savefig(fn, dpi=200, bbox_inches="tight")
    plt.close()
    print(f"  Saved: {fn}")

print("\nDone — 71_map_factions.py")


