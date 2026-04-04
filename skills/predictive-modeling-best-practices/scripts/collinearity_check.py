#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
collinearity_check.py
Assess and reduce predictor collinearity via pairwise correlations and VIF.
Usage: python collinearity_check.py <predictors_csv> <output_dir> [vif_threshold]
Requires: pandas, numpy, statsmodels
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "predictive-modeling-best-practices"
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
from statsmodels.stats.outliers_influence import variance_inflation_factor


def compute_vif(df: pd.DataFrame) -> pd.DataFrame:
    """Compute VIF for each column in a numeric DataFrame."""
    arr = df.values.astype(float)
    vif_data = []
    for i in range(arr.shape[1]):
        vif_val = variance_inflation_factor(arr, i)
        vif_data.append({"variable": df.columns[i], "VIF": round(vif_val, 4)})
    return pd.DataFrame(vif_data)


def stepwise_vif_reduction(df: pd.DataFrame, threshold: float) -> tuple[pd.DataFrame, list[str]]:
    """Iteratively remove the predictor with highest VIF until all VIF < threshold."""
    current = df.copy()
    removed = []
    while True:
        if current.shape[1] < 2:
            break
        vif_df = compute_vif(current)
        max_vif = vif_df["VIF"].max()
        if max_vif <= threshold:
            break
        worst = vif_df.loc[vif_df["VIF"].idxmax(), "variable"]
        logger.info("Removing '%s' (VIF=%.2f > %.2f)", worst, max_vif, threshold)
        removed.append(worst)
        current = current.drop(columns=[worst])
    return vif_df if current.shape[1] >= 2 else compute_vif(current), list(current.columns)


def main():
    # ── Arguments ────────────────────────────────────────────────────────────
    args = sys.argv[1:]
    env_file      = args[0] if len(args) >= 1 else "data/processed/env_matrix.csv"
    output_dir    = args[1] if len(args) >= 2 else "outputs"
    vif_threshold = float(args[2]) if len(args) >= 3 else 5.0

    # ── Input precondition check ─────────────────────────────────────────────
    if not Path(env_file).exists():
        logger.error(
            "Input not found: %s\n"
            "Probable cause: previous step did not complete.\n"
            "Check: outputs of the previous skill.\n"
            "Previous skill: species-distribution-modeling",
            env_file,
        )
        sys.exit(1)

    log_decision("vif_threshold", vif_threshold,
                 "VIF threshold for stepwise predictor exclusion; standard ecological threshold is 5 or 10")

    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    # ── Step 1: Load ─────────────────────────────────────────────────────────
    log_step(1, "Load environmental predictor matrix")
    try:
        logger.info("Loading: %s", env_file)
        env = pd.read_csv(env_file)
        # Keep only numeric columns
        env = env.select_dtypes(include=[np.number]).dropna()
        logger.info("Variables: %d | Rows: %d", env.shape[1], len(env))

        if len(env) < 30:
            logger.warning("Low row count (%d). Correlation estimates may be unstable with n < 30.", len(env))
        if env.shape[1] < 2:
            logger.error(
                "Only %d variable found. Collinearity analysis requires at least 2 predictors.\n"
                "Probable cause: Incorrect CSV or no numeric predictors.\n"
                "Check: env_matrix_csv file format.\n"
                "Previous skill: species-distribution-modeling",
                env.shape[1],
            )
            sys.exit(1)
    except Exception as exc:
        logger.error(
            "Failed in load_env_matrix: %s\n"
            "Probable cause: CSV file missing, malformed, or without numeric columns.\n"
            "Check: path and format of predictor CSV.\n"
            "Previous skill: species-distribution-modeling",
            exc,
        )
        sys.exit(1)

    # ── Step 2: Pairwise correlation ─────────────────────────────────────────
    log_step(2, "Compute pairwise Pearson correlations")
    try:
        cor_mat = env.corr(method="pearson")
        # Identify highly correlated pairs (|r| > 0.7)
        pairs = []
        cols = list(cor_mat.columns)
        for i in range(len(cols)):
            for j in range(i + 1, len(cols)):
                r = cor_mat.iloc[i, j]
                if abs(r) > 0.7:
                    pairs.append({"var1": cols[i], "var2": cols[j], "r": round(r, 4)})
        high_cor_pairs = pd.DataFrame(pairs)
        if not high_cor_pairs.empty:
            high_cor_pairs = high_cor_pairs.sort_values("r", key=abs, ascending=False)

        logger.info("Highly correlated pairs (|r| > 0.7): %d pairs found.", len(high_cor_pairs))
        if len(high_cor_pairs) > 0:
            logger.warning(
                "%d highly correlated predictor pairs (|r| > 0.70) detected. Collinearity reduction required.",
                len(high_cor_pairs),
            )
            logger.info("Highly correlated pairs:\n%s", high_cor_pairs.to_string(index=False))
    except Exception as exc:
        logger.error(
            "Failed in pairwise_correlation: %s\n"
            "Probable cause: non-numeric columns or remaining NA values.\n"
            "Check: CSV data types and result of dropna.\n"
            "Previous skill: species-distribution-modeling",
            exc,
        )
        sys.exit(1)

    # ── Step 3: VIF stepwise reduction ───────────────────────────────────────
    log_step(3, "VIF stepwise predictor reduction")
    try:
        logger.info("Running VIF stepwise reduction (threshold: %g)...", vif_threshold)
        vif_final, selected = stepwise_vif_reduction(env, vif_threshold)
        logger.info("Final VIF results:\n%s", vif_final.to_string(index=False))
        logger.info("Final selected predictors (%d): %s", len(selected), ", ".join(selected))
        log_decision(
            "selected_predictors", ", ".join(selected),
            f"VIF stepwise retained these predictors below threshold {vif_threshold}",
        )

        n_removed = env.shape[1] - len(selected)
        if n_removed > 0:
            logger.warning(
                "%d predictors removed by VIF > %g. Review whether ecologically important variables were excluded.",
                n_removed, vif_threshold,
            )
    except Exception as exc:
        logger.error(
            "Failed in vif_stepwise_reduction: %s\n"
            "Probable cause: singular matrix, constant predictors, or statsmodels failure.\n"
            "Check: variance of each predictor and statsmodels package installation.\n"
            "Previous skill: species-distribution-modeling",
            exc,
        )
        sys.exit(1)

    # ── Step 4: Write outputs ────────────────────────────────────────────────
    log_step(4, "Write collinearity outputs")
    try:
        high_cor_pairs.to_csv(out_path / "high_correlation_pairs.csv", index=False)
        vif_final.to_csv(out_path / "vif_results.csv", index=False)
        (out_path / "selected_predictors.txt").write_text("\n".join(selected) + "\n", encoding="utf-8")
        logger.info("Outputs written to: %s", output_dir)
    except Exception as exc:
        logger.error(
            "Failed in write_outputs: %s\n"
            "Probable cause: write permissions or non-existent output directory.\n"
            "Check: output_dir and filesystem permissions.\n"
            "Previous skill: species-distribution-modeling",
            exc,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
