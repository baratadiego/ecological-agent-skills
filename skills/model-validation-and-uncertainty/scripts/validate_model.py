#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
validate_model.py
Compute AUC, TSS, calibration for binary predictions.
Usage: python validate_model.py <predictions_csv> <output_dir>
Requires: pandas, numpy, sklearn, matplotlib
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "model-validation-and-uncertainty"
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
from sklearn.metrics import roc_auc_score, roc_curve


def compute_tss(y_true, y_pred_prob):
    thresholds = np.linspace(0, 1, 101)
    best_tss, best_thresh = -1, 0
    for th in thresholds:
        y_bin = (y_pred_prob >= th).astype(int)
        tp = ((y_bin == 1) & (y_true == 1)).sum()
        fp = ((y_bin == 1) & (y_true == 0)).sum()
        tn = ((y_bin == 0) & (y_true == 0)).sum()
        fn = ((y_bin == 0) & (y_true == 1)).sum()
        sens = tp / (tp + fn) if (tp + fn) > 0 else 0
        spec = tn / (tn + fp) if (tn + fp) > 0 else 0
        tss  = sens + spec - 1
        if tss > best_tss:
            best_tss, best_thresh = tss, th
    return best_tss, best_thresh

def calibration_plot(y_true, y_pred, output_path, n_bins=10):
    bins = np.linspace(0, 1, n_bins + 1)
    bin_ids = np.digitize(y_pred, bins) - 1
    bin_ids = np.clip(bin_ids, 0, n_bins - 1)
    mean_pred, obs_rate, counts = [], [], []
    for b in range(n_bins):
        mask = bin_ids == b
        if mask.sum() > 0:
            mean_pred.append(y_pred[mask].mean())
            obs_rate.append(y_true[mask].mean())
            counts.append(mask.sum())
    fig, ax = plt.subplots(figsize=(6, 5))
    ax.plot([0, 1], [0, 1], "k--", label="Perfect calibration")
    sc = ax.scatter(mean_pred, obs_rate, c=counts, cmap="Blues", s=80, edgecolor="navy", zorder=3)
    ax.plot(mean_pred, obs_rate, color="steelblue")
    plt.colorbar(sc, ax=ax, label="n per bin")
    ax.set_xlabel("Mean predicted probability"); ax.set_ylabel("Observed rate")
    ax.set_title("Calibration Plot"); ax.legend()
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()

def roc_plot(y_true, y_pred, auc_val, output_path):
    fpr, tpr, _ = roc_curve(y_true, y_pred)
    plt.figure(figsize=(5, 5))
    plt.plot(fpr, tpr, label=f"AUC = {auc_val:.3f}", color="steelblue")
    plt.plot([0, 1], [0, 1], "k--")
    plt.xlabel("False Positive Rate"); plt.ylabel("True Positive Rate")
    plt.title("ROC Curve"); plt.legend()
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()

def main():
    pred_file  = sys.argv[1] if len(sys.argv) > 1 else "outputs/predictions.csv"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/validation")

    log_step(1, "Validate inputs")
    if not Path(pred_file).exists():
        logger.error(
            "Predictions file not found: %s\n"
            "Causa provavel: caminho incorreto ou modelo nao gerou predicoes ainda\n"
            "Verifique: o argumento predictions_csv e que o modelo foi ajustado\n"
            "Skill anterior: species-distribution-modelling",
            pred_file
        )
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    log_step(2, "Load predictions data")
    try:
        dat = pd.read_csv(pred_file)
    except Exception as e:
        logger.error(
            "Unexpected error in load data: %s\n"
            "Causa provavel: CSV malformado ou permissoes insuficientes\n"
            "Verifique: encoding e estrutura do arquivo de predicoes\n"
            "Skill anterior: species-distribution-modelling",
            e
        )
        raise

    if "observed" not in dat.columns or "predicted" not in dat.columns:
        logger.error(
            "Required columns missing. Expected: 'observed', 'predicted'. Found: %s\n"
            "Causa provavel: cabecalho do CSV nao padronizado\n"
            "Verifique: que o arquivo tem colunas 'observed' (0/1) e 'predicted' (probabilidade)\n"
            "Skill anterior: species-distribution-modelling",
            list(dat.columns)
        )
        sys.exit(1)

    y_true = dat["observed"].values
    y_pred = dat["predicted"].values

    logger.info("Loaded %d predictions. Prevalence: %.3f", len(dat), y_true.mean())

    n_pos = (y_true == 1).sum()
    n_neg = (y_true == 0).sum()
    log_decision("evaluation_metrics", "AUC + MaxTSS + calibration plot", "standard triad for binary SDM evaluation")
    logger.info("Presences: %d | Absences: %d", n_pos, n_neg)

    if n_pos < 10:
        logger.warning(
            "Only %d presence records. AUC and TSS estimates will be highly uncertain.", n_pos
        )
    if n_neg < 10:
        logger.warning(
            "Only %d absence/background records. Consider increasing background sample size.", n_neg
        )
    if np.any((y_pred < 0) | (y_pred > 1)):
        logger.warning("Some predicted values are outside [0, 1]. Check that predictions are probabilities.")

    log_step(3, "Compute AUC-ROC")
    try:
        auc = roc_auc_score(y_true, y_pred)
        logger.info("AUC-ROC:  %.4f", auc)
        if auc < 0.7:
            logger.warning(
                "AUC = %.4f is below 0.70. Model discrimination is poor. "
                "Consider revisiting predictors or sampling design.", auc
            )
    except Exception as e:
        logger.error(
            "Unexpected error in AUC-ROC: %s\n"
            "Causa provavel: apenas uma classe em 'observed' ou valores NA\n"
            "Verifique: que 'observed' contem tanto 0 quanto 1 e 'predicted' nao tem NA\n"
            "Skill anterior: species-distribution-modelling",
            e
        )
        raise

    log_step(4, "Compute MaxTSS and optimal threshold")
    log_decision("threshold_method", "MaxTSS", "maximises sensitivity + specificity; robust for SDMs")
    try:
        tss, thresh = compute_tss(y_true, y_pred)
        logger.info("Max TSS:  %.4f  (threshold = %.2f)", tss, thresh)
        if tss < 0.4:
            logger.warning(
                "MaxTSS = %.4f is low. Model may have poor predictive performance.", tss
            )
    except Exception as e:
        logger.error(
            "Unexpected error in TSS computation: %s\n"
            "Causa provavel: valores NA ou classe unica em 'observed'\n"
            "Verifique: que 'observed' contem tanto 0 quanto 1\n"
            "Skill anterior: species-distribution-modelling",
            e
        )
        raise

    log_step(5, "Save performance metrics")
    try:
        metrics = pd.DataFrame({"metric": ["AUC-ROC", "MaxTSS", "Threshold_MaxTSS"],
                                "value":  [round(auc, 4), round(tss, 4), thresh]})
        metrics.to_csv(output_dir / "performance_metrics.csv", index=False)
        logger.info("Performance metrics saved.")
    except Exception as e:
        logger.error(
            "Unexpected error in save metrics: %s\n"
            "Causa provavel: diretorio sem permissao de escrita\n"
            "Verifique: output_dir e permissoes do sistema de arquivos\n"
            "Skill anterior: model-validation-and-uncertainty (metrics computation)",
            e
        )
        raise

    log_step(6, "Generate diagnostic plots")
    try:
        calibration_plot(y_true, y_pred, output_dir / "calibration_plot.png")
        logger.info("Calibration plot saved.")
        roc_plot(y_true, y_pred, auc, output_dir / "roc_curve.png")
        logger.info("ROC curve saved.")
    except Exception as e:
        logger.error(
            "Unexpected error in diagnostic plots: %s\n"
            "Causa provavel: dados insuficientes por bin ou backend matplotlib indisponivel\n"
            "Verifique: distribuicao dos valores preditos e configuracao do matplotlib\n"
            "Skill anterior: model-validation-and-uncertainty (metrics computation)",
            e
        )
        raise

    logger.info("Outputs written to: %s", output_dir)

if __name__ == "__main__":
    main()
