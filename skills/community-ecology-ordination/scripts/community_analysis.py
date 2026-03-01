#!/usr/bin/env python3
"""
community_analysis.py
Beta diversity, ordination (PCoA), and group comparison (PERMANOVA via skbio).
Usage: python community_analysis.py <species_matrix_csv> <metadata_csv> <output_dir>
Requires: pandas, numpy, scipy, skbio, matplotlib
"""
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.spatial.distance import braycurtis
from scipy.cluster.hierarchy import dendrogram, linkage, copshenetic
from scipy.spatial.distance import squareform

try:
    from skbio.diversity import beta_diversity
    from skbio.stats.ordination import pcoa
    from skbio.stats.distance import permanova, DistanceMatrix
    HAS_SKBIO = True
except ImportError:
    HAS_SKBIO = False
    print("scikit-bio not installed. pip install scikit-bio")

def bray_curtis_matrix(sp: pd.DataFrame) -> np.ndarray:
    n = len(sp)
    dm = np.zeros((n, n))
    vals = sp.values.astype(float)
    for i in range(n):
        for j in range(i+1, n):
            d = braycurtis(vals[i], vals[j])
            dm[i, j] = dm[j, i] = d
    return dm

def alpha_diversity(sp: pd.DataFrame) -> pd.DataFrame:
    richness = (sp > 0).sum(axis=1)
    def shannon(row):
        p = row[row > 0] / row.sum()
        return -np.sum(p * np.log(p))
    def simpson(row):
        p = row[row > 0] / row.sum()
        return 1 - np.sum(p**2)
    return pd.DataFrame({
        "site":     sp.index,
        "richness": richness.values,
        "shannon":  sp.apply(shannon, axis=1).values,
        "simpson":  sp.apply(simpson, axis=1).values,
    })

def main():
    sp_file    = sys.argv[1] if len(sys.argv) > 1 else "data/species_matrix.csv"
    meta_file  = sys.argv[2] if len(sys.argv) > 2 else "data/site_metadata.csv"
    output_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("outputs/community")
    output_dir.mkdir(parents=True, exist_ok=True)

    sp   = pd.read_csv(sp_file, index_col=0)
    meta = pd.read_csv(meta_file, index_col=0)
    print(f"Sites: {len(sp)} | Species: {len(sp.columns)}")

    # Alpha diversity
    div = alpha_diversity(sp)
    div.to_csv(output_dir / "diversity_metrics.csv", index=False)
    print(f"Mean richness: {div['richness'].mean():.1f} | Shannon: {div['shannon'].mean():.2f}")

    # Beta diversity (Bray-Curtis)
    dm = bray_curtis_matrix(sp)
    pd.DataFrame(dm, index=sp.index, columns=sp.index).to_csv(output_dir / "bray_curtis_matrix.csv")

    # PCoA
    if HAS_SKBIO:
        dist_mat = DistanceMatrix(dm, ids=list(sp.index))
        pc = pcoa(dist_mat)
        scores = pc.samples[["PC1", "PC2"]].copy()
        scores["site"] = scores.index
        if "group" in meta.columns:
            scores["group"] = meta["group"].reindex(scores.index).values
            groups_for_perm = meta["group"].reindex(sp.index).values
            perm_result = permanova(dist_mat, groups_for_perm, permutations=999)
            print(f"\nPERMANOVA: F = {perm_result['test statistic']:.3f} | "
                  f"p = {perm_result['p-value']:.4f}")
            perm_df = pd.DataFrame({"statistic": [perm_result["test statistic"]],
                                    "p_value":   [perm_result["p-value"]]})
            perm_df.to_csv(output_dir / "permanova_results.csv", index=False)
            # Plot coloured by group
            fig, ax = plt.subplots(figsize=(7, 6))
            for grp in scores["group"].unique():
                sub = scores[scores["group"] == grp]
                ax.scatter(sub["PC1"], sub["PC2"], label=grp, s=50, alpha=0.8)
            ax.set_xlabel(f"PC1 ({pc.proportion_explained[0]*100:.1f}%)")
            ax.set_ylabel(f"PC2 ({pc.proportion_explained[1]*100:.1f}%)")
            ax.set_title("PCoA (Bray-Curtis)")
            ax.legend(); plt.tight_layout()
            plt.savefig(output_dir / "pcoa_plot.png", dpi=150)
            plt.close()

    # Hierarchical clustering
    Z = linkage(squareform(dm), method="ward")
    c, _ = copshenetic(Z, squareform(dm))
    print(f"Cophenetic correlation (Ward): {c:.3f}")
    fig, ax = plt.subplots(figsize=(max(8, len(sp)//2), 5))
    dendrogram(Z, labels=list(sp.index), ax=ax, leaf_rotation=90, leaf_font_size=8)
    ax.set_title(f"Hierarchical Clustering (Ward.D2) | Cophenetic r = {c:.3f}")
    plt.tight_layout()
    plt.savefig(output_dir / "cluster_dendrogram.png", dpi=150)
    plt.close()
    print(f"Outputs written to: {output_dir}")

if __name__ == "__main__":
    main()
