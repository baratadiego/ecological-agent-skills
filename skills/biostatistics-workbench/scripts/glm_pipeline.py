#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
glm_pipeline.py
Fit candidate GLMs, check assumptions, model selection.
Usage: python glm_pipeline.py <data_csv> <response_var> <output_dir>
Requires: pandas, numpy, statsmodels, scipy, matplotlib, seaborn
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "biostatistics-workbench"
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
import statsmodels.formula.api as smf
import statsmodels.api as sm
import matplotlib.pyplot as plt
import scipy.stats as stats


def vif_check(df: pd.DataFrame, predictors: list) -> pd.DataFrame:
    """Compute VIF for each predictor via auxiliary regressions."""
    from statsmodels.stats.outliers_influence import variance_inflation_factor
    X = sm.add_constant(df[predictors].dropna())
    vif_data = pd.DataFrame({
        "predictor": predictors,
        "VIF": [variance_inflation_factor(X.values, i+1) for i in range(len(predictors))]
    }).sort_values("VIF", ascending=False)
    return vif_data

def fit_candidates(data: pd.DataFrame, response: str, candidates: dict, family) -> list:
    results = []
    for label, formula_str in candidates.items():
        try:
            m = smf.glm(formula_str, data=data, family=family).fit(disp=0)
            results.append({"label": label, "formula": formula_str, "AIC": m.aic,
                            "deviance": m.deviance, "df_resid": m.df_resid, "model": m})
            logger.info("  %s: AIC = %.2f", label, m.aic)
        except Exception as e:
            logger.error(
                "Unexpected error in fit_candidates [%s]: %s\n"
                "Probable cause: invalid formula, missing columns, or incompatible family\n"
                "Check: column names in the CSV and defined formula\n"
                "Previous skill: data-cleaning",
                label, e
            )
    return results

def model_selection_table(results: list) -> pd.DataFrame:
    tbl = pd.DataFrame([{k: v for k, v in r.items() if k != "model"} for r in results])
    tbl = tbl.sort_values("AIC").reset_index(drop=True)
    tbl["deltaAIC"] = tbl["AIC"] - tbl["AIC"].min()
    tbl["weight"]   = np.exp(-0.5 * tbl["deltaAIC"])
    tbl["weight"]  /= tbl["weight"].sum()
    return tbl

def diagnostic_plots(model, label: str, output_dir: Path) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(10, 4))
    # Residuals vs fitted
    fitted = model.fittedvalues
    resid  = model.resid_pearson
    axes[0].scatter(fitted, resid, alpha=0.5, s=20)
    axes[0].axhline(0, color="red", linestyle="--")
    axes[0].set_xlabel("Fitted values"); axes[0].set_ylabel("Pearson residuals")
    axes[0].set_title("Residuals vs Fitted")
    # QQ plot
    stats.probplot(resid, dist="norm", plot=axes[1])
    axes[1].set_title("QQ Plot of Pearson Residuals")
    fig.suptitle(f"Diagnostics: {label}")
    plt.tight_layout()
    plt.savefig(output_dir / f"diagnostics_{label}.png", dpi=150)
    plt.close()

def main():
    data_file    = sys.argv[1] if len(sys.argv) > 1 else "data/processed/data.csv"
    response_var = sys.argv[2] if len(sys.argv) > 2 else "richness"
    output_dir   = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("outputs/stats")

    log_step(1, "Validate inputs and load data")
    if not Path(data_file).exists():
        logger.error(
            "Input file not found: %s\n"
            "Probable cause: incorrect path or file not yet generated\n"
            "Check: the data_csv argument and working directory\n"
            "Previous skill: data-cleaning",
            data_file
        )
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        dat = pd.read_csv(data_file)
    except Exception as e:
        logger.error(
            "Unexpected error in load data: %s\n"
            "Probable cause: malformed CSV file or insufficient permissions\n"
            "Check: encoding and structure of the CSV file\n"
            "Previous skill: data-cleaning",
            e
        )
        raise

    logger.info("Loaded %d rows. Response: %s", len(dat), response_var)

    if response_var not in dat.columns:
        logger.error(
            "Response variable '%s' not found in columns: %s\n"
            "Probable cause: incorrect response variable name\n"
            "Check: CSV header and the response_var argument\n"
            "Previous skill: data-cleaning",
            response_var, list(dat.columns)
        )
        sys.exit(1)

    n_missing = dat[response_var].isna().sum()
    if n_missing > 0:
        log_warn_msg = (
            "Response variable '%s' has %d missing values (%.1f%%). "
            "Rows with NA will be dropped by statsmodels."
        )
        logger.warning(log_warn_msg, response_var, n_missing, 100 * n_missing / len(dat))

    log_step(2, "Define candidate models and family")
    # --- Define your candidate models here ---
    candidates = {
        "null":    f"{response_var} ~ 1",
        "model1":  f"{response_var} ~ C(group)",
        "model2":  f"{response_var} ~ C(group) + elevation",
        "model3":  f"{response_var} ~ C(group) + elevation + forest_cover",
    }
    family = sm.families.NegativeBinomial()
    log_decision("family", "NegativeBinomial", "count response variable; NB handles overdispersion")
    log_decision("n_candidates", len(candidates), "null + 3 increasingly complex models for AIC comparison")

    log_step(3, "Fit candidate models")
    logger.info("Fitting candidate models:")
    results = fit_candidates(dat, response_var, candidates, family)

    if not results:
        logger.error(
            "No models converged successfully.\n"
            "Probable cause: insufficient data or predictors with NA in all rows\n"
            "Check: data completeness and candidate formulas\n"
            "Previous skill: data-cleaning"
        )
        sys.exit(1)

    log_step(4, "Build model selection table")
    try:
        tbl = model_selection_table(results)
        logger.info("Model selection table:\n%s", tbl[['label','AIC','deltaAIC','weight']].to_string(index=False))
        tbl.drop(columns=["model"], errors="ignore").to_csv(output_dir / "model_selection.csv", index=False)
    except Exception as e:
        logger.error(
            "Unexpected error in model selection table: %s\n"
            "Probable cause: no model fitted successfully\n"
            "Check: fitting step for previous error messages\n"
            "Previous skill: biostatistics-workbench (fitting)",
            e
        )
        raise

    log_step(5, "Summarise best model and save diagnostics")
    try:
        best_result = min(results, key=lambda x: x["AIC"])
        best_model  = best_result["model"]
        log_decision("best_model", best_result["label"], "lowest AIC among converged candidates")
        logger.info("Best model: %s (AIC = %.2f)", best_result["label"], best_result["AIC"])
        logger.info(str(best_model.summary()))
        (output_dir / "best_model_summary.txt").write_text(str(best_model.summary()))

        diagnostic_plots(best_model, best_result["label"], output_dir)
        logger.info("Outputs written to: %s", output_dir)
    except Exception as e:
        logger.error(
            "Unexpected error in best model summary/diagnostics: %s\n"
            "Probable cause: invalid model object or directory without write permission\n"
            "Check: output_dir and the selected model\n"
            "Previous skill: biostatistics-workbench (fitting)",
            e
        )
        raise

if __name__ == "__main__":
    main()
