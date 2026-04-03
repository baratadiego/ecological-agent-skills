#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
community_analysis.py
Beta diversity, ordination (PCoA), and group comparison (PERMANOVA via skbio).
Usage: python community_analysis.py <species_matrix_csv> <metadata_csv> <output_dir>
Requires: pandas, numpy, scipy, skbio, matplotlib
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "community-ecology-ordination"
_LOG_DIR   = Path("logs")
_LOG_DIR.mkdir(parents=True, exist_ok=True)
_log_file  = _LOG_DIR / f"skill_{SKILL_NAME}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] [" + SKILL_NAME + "] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_log_file, encoding="utf-8"),
    ],
)
logger = logging.getLogger(SKILL_NAME)

def log_step(n: int, desc: str) -> None:
    logger.info("-- STEP %d: %s", n, desc)

def log_decision(var: str, val, why: str) -> None:
    logger.info("DECISION | %s = %s | %s", var, val, why)

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
    logger.warning("scikit-bio not installed. PCoA and PERMANOVA will be skipped. pip install scikit-bio")


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

    log_step(1, "Validate inputs")
    if not Path(sp_file).exists():
        logger.error(
            "Species matrix file not found: %s\n"
            "Probable cause: incorrect path or file not yet generated\n"
            "Check: o argumento species_matrix_csv e o working directory\n"
            "Previous skill: data-cleaning",
            sp_file
        )
        sys.exit(1)
    if not Path(meta_file).exists():
        logger.error(
            "Metadata file not found: %s\n"
            "Probable cause: incorrect path or file not yet generated\n"
            "Check: o argumento metadata_csv e o working directory\n"
            "Previous skill: data-cleaning",
            meta_file
        )
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    log_step(2, "Load species matrix and metadata")
    try:
        sp   = pd.read_csv(sp_file, index_col=0)
        meta = pd.read_csv(meta_file, index_col=0)
    except Exception as e:
        logger.error(
            "Unexpected error in load data: %s\n"
            "Probable cause: CSV malformado ou sem coluna de rownames\n"
            "Check: structra dos arquivos (primeira coluna deve ser site ID)\n"
            "Previous skill: data-cleaning",
            e
        )
        raise

    logger.info("Sites: %d | Species: %d", len(sp), len(sp.columns))

    if (sp < 0).any().any():
        logger.warning("Species matrix contains negative values. Abundances must be >= 0. Check your input data.")
    if sp.isna().any().any():
        logger.warning("Species matrix contains %d NA values. These will affect distance calculations.", sp.isna().sum().sum())

    log_step(3, "Compute alpha diversity metrics")
    try:
        div = alpha_diversity(sp)
        div.to_csv(output_dir / "diversity_metrics.csv", index=False)
        logger.info("Mean richness: %.1f | Shannon: %.2f", div['richness'].mean(), div['shannon'].mean())
    except Exception as e:
        logger.error(
            "Unexpected error in alpha diversity: %s\n"
            "Probable cause: matriz de especies vazia ou nao numerica\n"
            "Check: CSV structure de especies\n"
            "Previous skill: data-cleaning",
            e
        )
        raise

    log_step(4, "Compute Bray-Curtis distance matrix")
    log_decision("distance_metric", "bray-curtis", "standard for community composition; handles double-zeros correctly")
    try:
        dm = bray_curtis_matrix(sp)
        pd.DataFrame(dm, index=sp.index, columns=sp.index).to_csv(output_dir / "bray_curtis_matrix.csv")
        logger.info("Bray-Curtis matrix computed (%d x %d).", len(sp), len(sp))
    except Exception as e:
        logger.error(
            "Unexpected error in Bray-Curtis matrix: %s\n"
            "Probable cause: dados nao numericos na matriz de especies\n"
            "Check: tipos de dados no CSV de especies\n"
            "Previous skill: data-cleaning",
            e
        )
        raise

    log_step(5, "PCoA ordination and PERMANOVA")
    if HAS_SKBIO:
        log_decision("permanova_permutations", 999, "standard number for robust p-value estimation")
        try:
            dist_mat = DistanceMatrix(dm, ids=list(sp.index))
            pc = pcoa(dist_mat)
            scores = pc.samples[["PC1", "PC2"]].copy()
            scores["site"] = scores.index
            if "group" in meta.columns:
                scores["group"] = meta["group"].reindex(scores.index).values
                groups_for_perm = meta["group"].reindex(sp.index).values
                perm_result = permanova(dist_mat, groups_for_perm, permutations=999)
                logger.info(
                    "PERMANOVA: F = %.3f | p = %.4f",
                    perm_result['test statistic'], perm_result['p-value']
                )
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
                logger.info("PCoA plot saved.")
            else:
                logger.warning("Column 'group' not found in metadata. PERMANOVA skipped.")
        except Exception as e:
            logger.error(
                "Unexpected error in PCoA/PERMANOVA: %s\n"
                "Probable cause: grupo com apenas um nivel ou sites insuficientes\n"
                "Check: coluna 'group' nos metadados e balanceamento\n"
                "Previous skill: data-cleaning",
                e
            )
            raise
    else:
        logger.warning("scikit-bio unavailable. PCoA and PERMANOVA steps skipped.")

    log_step(6, "Hierarchical clustering")
    try:
        Z = linkage(squareform(dm), method="ward")
        c, _ = copshenetic(Z, squareform(dm))
        log_decision("linkage_method", "ward", "minimises total within-cluster variance; standard for ecology")
        logger.info("Cophenetic correlation (Ward): %.3f", c)
        if c < 0.7:
            logger.warning("Cophenetic correlation = %.3f < 0.70. Dendrogram may poorly represent distances.", c)
        fig, ax = plt.subplots(figsize=(max(8, len(sp)//2), 5))
        dendrogram(Z, labels=list(sp.index), ax=ax, leaf_rotation=90, leaf_font_size=8)
        ax.set_title(f"Hierarchical Clustering (Ward.D2) | Cophenetic r = {c:.3f}")
        plt.tight_layout()
        plt.savefig(output_dir / "cluster_dendrogram.png", dpi=150)
        plt.close()
        logger.info("Cluster dendrogram saved.")
    except Exception as e:
        logger.error(
            "Unexpected error in hierarchical clustering: %s\n"
            "Probable cause: distance matrix contains NaN or only one site\n"
            "Check: integridade da matriz Bray-Curtis\n"
            "Previous skill: community-ecology-ordination (distance matrix)",
            e
        )
        raise

    logger.info("Outputs written to: %s", output_dir)

if __name__ == "__main__":
    main()
