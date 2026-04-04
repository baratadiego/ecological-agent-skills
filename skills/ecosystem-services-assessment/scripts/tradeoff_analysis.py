#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
tradeoff_analysis.py
ES trade-off and synergy analysis across pixels or land cover units.
Usage: python tradeoff_analysis.py <es_summary_csv> <output_dir>
Requires: pandas, numpy, scipy, matplotlib, seaborn
"""
import logging
import sys
from datetime import datetime
from pathlib import Path
from itertools import combinations

SKILL_NAME = "ecosystem-services-assessment"
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
from scipy.stats import spearmanr
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns


def main():
    # ── Arguments ────────────────────────────────────────────────────────────
    es_file    = sys.argv[1] if len(sys.argv) >= 2 else "outputs/ecosystem_services/es_summary_table.csv"
    output_dir = sys.argv[2] if len(sys.argv) >= 3 else "outputs/ecosystem_services"

    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    logger.info("Skill: %s | es_file=%s | output_dir=%s", SKILL_NAME, es_file, output_dir)

    # ── Input precondition check ─────────────────────────────────────────────
    if not Path(es_file).exists():
        logger.error(
            "Input not found: %s\n"
            "Probable cause: o script de quantificacao de servicos ecossistemicos nao foi executado ou o caminho esta errado.\n"
            "Check: execute primeiro o script de mapeamento/quantificacao de ES.\n"
            "Previous skill: ecosystem-services-assessment (quantification step).",
            es_file,
        )
        sys.exit(1)

    # ── Step 1: Load ─────────────────────────────────────────────────────────
    log_step(1, "Load ecosystem services table")
    try:
        es = pd.read_csv(es_file)
    except Exception as exc:
        logger.error(
            "Failed to read CSV de servicos ecossistemicos: %s\n"
            "Probable cause: corrupted file ou com separador incorreto.\n"
            "Check: abra o arquivo em editor de texto e confira o formato.\n"
            "Previous skill: ecosystem-services-assessment (quantification step).",
            exc,
        )
        sys.exit(1)

    logger.info("ES table loaded: %d land use classes", len(es))

    n_na_total = int(es.isna().sum().sum())
    if n_na_total > 0:
        logger.warning(
            "ES table contains %d NA values total — correlations will be computed with complete observations.",
            n_na_total,
        )

    # ── Step 2: Identify numeric ES columns ──────────────────────────────────
    log_step(2, "Identify ES indicator columns and normalise 0-1")
    exclude_cols = {"lulc_code", "n_pixels"}
    es_cols = [c for c in es.select_dtypes(include=[np.number]).columns if c not in exclude_cols]
    logger.info("ES indicators: %s", ", ".join(es_cols))
    log_decision(
        "es_cols", ", ".join(es_cols),
        "colunas numericas excluindo lulc_code e n_pixels sao tratadas como indicadores de ES",
    )

    if len(es_cols) < 2:
        logger.warning(
            "Fewer than 2 ES indicators found — trade-off analysis not possible with only %d column(s).",
            len(es_cols),
        )
        logger.info("Exiting without error. Add more indicators to the input CSV.")
        sys.exit(0)

    # ── Normalise to 0-1 ─────────────────────────────────────────────────────
    try:
        es_norm = es.copy()
        eps = 1e-10
        for col in es_cols:
            cmin = es_norm[col].min()
            cmax = es_norm[col].max()
            es_norm[col] = (es_norm[col] - cmin) / (cmax - cmin + eps)
    except Exception as exc:
        logger.error(
            "Failed to normalise indicators 0-1: %s\n"
            "Probable cause: non-numeric columns incorrectly identified as indicators.\n"
            "Check: column types in the input CSV.\n"
            "Previous skill: ecosystem-services-assessment (quantification step).",
            exc,
        )
        sys.exit(1)

    log_decision(
        "normalization", "min-max [0,1] with epsilon 1e-10",
        "evita divisao por zero quando todos os valores de um indicador sao iguais",
    )

    # ── Step 3: Correlation matrix (Spearman) ────────────────────────────────
    log_step(3, "Compute Spearman correlation matrix among ES indicators")
    try:
        subset = es_norm[es_cols].dropna()
        rho, _ = spearmanr(subset)
        if len(es_cols) == 2:
            # spearmanr returns scalar for 2 variables — reshape to matrix
            cor_mat = np.array([[1.0, rho], [rho, 1.0]])
        else:
            cor_mat = rho
        cor_df = pd.DataFrame(cor_mat, index=es_cols, columns=es_cols)
    except Exception as exc:
        logger.error(
            "Failed to compute correlation matrix: %s\n"
            "Probable cause: all values in some column are NA after normalisation.\n"
            "Check: presence of variation in ES indicators.\n"
            "Previous skill: ecosystem-services-assessment (quantification step).",
            exc,
        )
        sys.exit(1)

    log_decision(
        "correlation_method", "Spearman",
        "metodo nao-parametrico robusto a distribuicoes assimetricas comuns em dados de ES",
    )

    try:
        csv_path = out_path / "tradeoff_matrix.csv"
        cor_df.to_csv(csv_path)
        logger.info("tradeoff_matrix.csv saved in: %s", output_dir)
    except Exception as exc:
        logger.error(
            "Failed to salvar tradeoff_matrix.csv: %s\n"
            "Probable cause: permissao negada ou disco cheio.\n"
            "Check: permissoes do output directory.\n"
            "Previous skill: [none].",
            exc,
        )
        sys.exit(1)

    # ── Step 4: Correlation heatmap ──────────────────────────────────────────
    log_step(4, "Generate trade-off heatmap")
    try:
        fig, ax = plt.subplots(figsize=(8, 7))
        mask = np.triu(np.ones_like(cor_df, dtype=bool), k=1)
        sns.heatmap(
            cor_df, mask=mask, annot=True, fmt=".2f", cmap="RdBu_r",
            vmin=-1, vmax=1, center=0, square=True, linewidths=0.5, ax=ax,
        )
        ax.set_title("ES Trade-offs (Spearman r)")
        fig.tight_layout()
        fig.savefig(out_path / "tradeoff_heatmap.png", dpi=150)
        plt.close(fig)
        logger.info("tradeoff_heatmap.png saved in: %s", output_dir)
    except Exception as exc:
        logger.error(
            "Failed to generate heatmap de trade-offs: %s\n"
            "Probable cause: matplotlib/seaborn not installed ou matriz de correlacao invalida.\n"
            "Check: se os pacotes matplotlib e seaborn estao disponiveis e a matriz tem pelo menos 2 variaveis.\n"
            "Previous skill: [none].",
            exc,
        )
        sys.exit(1)

    # ── Step 5: Scatter plots for top pairs ──────────────────────────────────
    log_step(5, "Generate scatter plots for ES indicator pairs")
    pair_combos = list(combinations(es_cols, 2))
    n_pairs = min(6, len(pair_combos))
    logger.info("Generating %d scatter plots (of %d possible pairs)", n_pairs, len(pair_combos))
    log_decision(
        "max_scatter_plots", str(n_pairs),
        "limitado a 6 pares para evitar geracao excessiva de arquivos",
    )

    label_col = "lulc_code" if "lulc_code" in es.columns else None

    for v1, v2 in pair_combos[:n_pairs]:
        try:
            fig, ax = plt.subplots(figsize=(5, 4))
            ax.scatter(es[v1], es[v2], s=30, color="#2166ac", edgecolors="white", linewidths=0.5)
            if label_col is not None:
                for idx, row in es.iterrows():
                    ax.annotate(
                        str(row[label_col]),
                        (row[v1], row[v2]),
                        fontsize=7, alpha=0.7,
                        textcoords="offset points", xytext=(4, 4),
                    )
            ax.set_xlabel(v1)
            ax.set_ylabel(v2)
            ax.set_title(f"Trade-off: {v1} vs {v2}")
            fig.tight_layout()
            fname = f"scatter_{v1}_vs_{v2}.png"
            fig.savefig(out_path / fname, dpi=150)
            plt.close(fig)
            logger.info("Saved: %s", fname)
        except Exception as exc:
            logger.error(
                "Failed to generate scatter plot for pair %s vs %s: %s\n"
                "Probable cause: column missing after filtering or annotation error.\n"
                "Check: columns '%s' and '%s' exist and have valid data.\n"
                "Previous skill: [none].",
                v1, v2, exc, v1, v2,
            )
            sys.exit(1)

    logger.info("Trade-off analysis completed. Outputs in: %s", output_dir)


if __name__ == "__main__":
    main()
