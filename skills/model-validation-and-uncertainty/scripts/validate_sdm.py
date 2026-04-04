# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: python validate_sdm.py <predictions_csv> <output_dir>
#
# Arguments:
#   predictions_csv : CSV with columns 'observed' (0/1) and 'predicted' (probability)
#   output_dir      : Directory for outputs (created if absent)
#
# Outputs:
#   performance_metrics.csv  - AUC-ROC, MaxTSS, optimal threshold
#   calibration_plot.png     - Calibration plot (predicted vs observed rate)
#
# Requires: numpy, pandas, matplotlib

import sys
import os
import logging
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# -- Inline logger ------------------------------------------------------------
SKILL_NAME = "model-validation-and-uncertainty"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(SKILL_NAME)
os.makedirs("logs", exist_ok=True)


def log_decision(variable: str, value: str, reason: str) -> None:
    """Log a methodological decision."""
    logger.info("DECISION | %s = %s | %s", variable, value, reason)


# -- 1. Parse arguments -------------------------------------------------------

def main():
    args = sys.argv[1:]
    pred_file = args[0] if len(args) >= 1 else "outputs/predictions.csv"
    output_dir = args[1] if len(args) >= 2 else "outputs/validation"

    logger.info("-- STEP 1: Validate inputs")
    if not os.path.isfile(pred_file):
        logger.error(
            "Failed in validate inputs: predictions file not found: %s\n"
            "Probable cause: incorrect path or model has not yet generated predictions\n"
            "Check: the predictions_csv argument and that the model has been fitted\n"
            "Previous skill: species-distribution-modelling",
            pred_file,
        )
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    # -- 2. Load predictions data -------------------------------------------------
    logger.info("-- STEP 2: Load predictions data")
    try:
        dat = pd.read_csv(pred_file)
    except Exception as e:
        logger.error(
            "Failed in load data: %s\n"
            "Probable cause: malformed CSV or insufficient permissions\n"
            "Check: encoding and structure of the predictions file\n"
            "Previous skill: species-distribution-modelling",
            e,
        )
        sys.exit(1)

    required_cols = {"observed", "predicted"}
    if not required_cols.issubset(dat.columns):
        logger.error(
            "Failed in validate columns: required columns missing. "
            "Expected: 'observed', 'predicted'. Found: %s\n"
            "Probable cause: CSV header not standardised\n"
            "Check: that the file has columns 'observed' (0/1) and 'predicted' (probability)\n"
            "Previous skill: species-distribution-modelling",
            ", ".join(dat.columns),
        )
        sys.exit(1)

    logger.info("Loaded %d predictions. Prevalence: %.3f", len(dat), dat["observed"].mean())

    n_pos = int((dat["observed"] == 1).sum())
    n_neg = int((dat["observed"] == 0).sum())
    log_decision(
        "evaluation_approach",
        "AUC + MaxTSS + calibration",
        "standard triad for binary SDM evaluation",
    )
    logger.info("Presences: %d | Absences: %d", n_pos, n_neg)

    if n_pos < 10:
        logger.warning(
            "Only %d presence records. AUC and TSS estimates will be highly uncertain "
            "with so few presences.",
            n_pos,
        )
    if n_neg < 10:
        logger.warning(
            "Only %d absence/background records. Consider increasing background sample size.",
            n_neg,
        )

    if ((dat["predicted"] < 0) | (dat["predicted"] > 1)).any():
        logger.warning(
            "Some predicted values are outside [0, 1]. Check that predictions are probabilities."
        )

    # -- 3. Compute AUC-ROC -------------------------------------------------------
    logger.info("-- STEP 3: Compute AUC-ROC")
    try:
        roc_data = dat.sort_values("predicted", ascending=False).reset_index(drop=True)
        tpr = np.cumsum(roc_data["observed"].values == 1) / n_pos
        fpr = np.cumsum(roc_data["observed"].values == 0) / n_neg

        # Trapezoidal AUC
        auc = float(np.abs(np.trapz(tpr, fpr)))
        logger.info("AUC-ROC: %.3f", auc)

        if auc < 0.7:
            logger.warning(
                "AUC = %.3f is below 0.70. Model discrimination is poor. "
                "Consider revisiting predictors or sampling design.",
                auc,
            )
    except Exception as e:
        logger.error(
            "Failed in AUC-ROC: %s\n"
            "Probable cause: NA values in 'observed' or 'predicted', or only one class\n"
            "Check: that 'observed' contains 0 and 1 and 'predicted' has no NA\n"
            "Previous skill: species-distribution-modelling",
            e,
        )
        sys.exit(1)

    # -- 4. Compute MaxTSS and optimal threshold -----------------------------------
    logger.info("-- STEP 4: Compute MaxTSS and optimal threshold")
    log_decision(
        "threshold_method",
        "MaxTSS",
        "maximises sensitivity + specificity; robust for SDMs",
    )
    try:
        thresholds = np.arange(0, 1.01, 0.01)
        observed = dat["observed"].values
        predicted = dat["predicted"].values

        tss_vals = np.empty(len(thresholds))
        for idx, th in enumerate(thresholds):
            pred_bin = (predicted >= th).astype(int)
            tp = int(np.sum((pred_bin == 1) & (observed == 1)))
            fp = int(np.sum((pred_bin == 1) & (observed == 0)))
            tn = int(np.sum((pred_bin == 0) & (observed == 0)))
            fn = int(np.sum((pred_bin == 0) & (observed == 1)))
            sens = tp / (tp + fn) if (tp + fn) > 0 else 0.0
            spec = tn / (tn + fp) if (tn + fp) > 0 else 0.0
            tss_vals[idx] = sens + spec - 1.0

        best_tss_idx = int(np.argmax(tss_vals))
        best_thresh = float(thresholds[best_tss_idx])
        best_tss = float(tss_vals[best_tss_idx])
        logger.info("MaxTSS: %.3f at threshold: %.2f", best_tss, best_thresh)

        if best_tss < 0.4:
            logger.warning(
                "MaxTSS = %.3f is low. Model may have poor predictive performance.",
                best_tss,
            )
    except Exception as e:
        logger.error(
            "Failed in TSS computation: %s\n"
            "Probable cause: NA values or single class in 'observed'\n"
            "Check: that 'observed' contains both 0 and 1\n"
            "Previous skill: species-distribution-modelling",
            e,
        )
        sys.exit(1)

    # -- 5. Save performance metrics -----------------------------------------------
    logger.info("-- STEP 5: Save performance metrics")
    try:
        metrics = pd.DataFrame(
            {
                "metric": ["AUC-ROC", "MaxTSS", "Threshold_MaxTSS"],
                "value": [round(auc, 4), round(best_tss, 4), round(best_thresh, 4)],
            }
        )
        metrics.to_csv(os.path.join(output_dir, "performance_metrics.csv"), index=False)
        logger.info("Performance metrics saved.")
    except Exception as e:
        logger.error(
            "Failed in save metrics: %s\n"
            "Probable cause: directory without write permission\n"
            "Check: output_dir and filesystem permissions\n"
            "Previous skill: model-validation-and-uncertainty (metrics computation)",
            e,
        )
        sys.exit(1)

    # -- 6. Generate calibration plot ----------------------------------------------
    logger.info("-- STEP 6: Generate calibration plot")
    try:
        dat["bin"] = pd.cut(dat["predicted"], bins=np.arange(0, 1.1, 0.1), include_lowest=True)
        cal = (
            dat.groupby("bin", observed=False)
            .agg(mean_pred=("predicted", "mean"), obs_rate=("observed", "mean"), n=("observed", "size"))
            .dropna(subset=["mean_pred"])
            .reset_index()
        )

        fig, ax = plt.subplots(figsize=(6, 5), dpi=150)
        ax.plot([0, 1], [0, 1], linestyle="--", color="grey", zorder=1)
        scatter = ax.scatter(
            cal["mean_pred"],
            cal["obs_rate"],
            s=cal["n"] * 5,
            c="#2166ac",
            zorder=3,
        )
        ax.plot(cal["mean_pred"], cal["obs_rate"], color="#2166ac", zorder=2)
        ax.set_xlabel("Mean Predicted Probability")
        ax.set_ylabel("Observed Rate")
        ax.set_title("Calibration Plot")
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)

        # Size legend
        handles, labels = scatter.legend_elements(
            prop="sizes", num=4, func=lambda s: s / 5, alpha=0.6
        )
        ax.legend(handles, labels, title="n", loc="upper left")

        plt.tight_layout()
        cal_plot_path = os.path.join(output_dir, "calibration_plot.png")
        fig.savefig(cal_plot_path)
        plt.close(fig)
        logger.info("Calibration plot written: %s", cal_plot_path)

    except Exception as e:
        logger.error(
            "Failed in calibration plot: %s\n"
            "Probable cause: insufficient data per bin or extreme predicted values\n"
            "Check: distribution of predicted values and number of records\n"
            "Previous skill: model-validation-and-uncertainty (metrics computation)",
            e,
        )
        sys.exit(1)

    logger.info("Validation complete. Outputs in: %s", output_dir)


if __name__ == "__main__":
    main()
