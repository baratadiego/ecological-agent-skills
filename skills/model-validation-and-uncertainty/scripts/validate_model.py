#!/usr/bin/env python3
"""
validate_model.py
Compute AUC, TSS, calibration for binary predictions.
Usage: python validate_model.py <predictions_csv> <output_dir>
Requires: pandas, numpy, sklearn, matplotlib
"""
import sys
from pathlib import Path
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
    output_dir.mkdir(parents=True, exist_ok=True)

    dat = pd.read_csv(pred_file)
    assert "observed" in dat.columns and "predicted" in dat.columns
    y_true = dat["observed"].values
    y_pred = dat["predicted"].values

    auc = roc_auc_score(y_true, y_pred)
    tss, thresh = compute_tss(y_true, y_pred)
    print(f"AUC-ROC:  {auc:.4f}")
    print(f"Max TSS:  {tss:.4f}  (threshold = {thresh:.2f})")

    metrics = pd.DataFrame({"metric": ["AUC-ROC", "MaxTSS", "Threshold_MaxTSS"],
                            "value":  [round(auc, 4), round(tss, 4), thresh]})
    metrics.to_csv(output_dir / "performance_metrics.csv", index=False)

    calibration_plot(y_true, y_pred, output_dir / "calibration_plot.png")
    roc_plot(y_true, y_pred, auc, output_dir / "roc_curve.png")
    print(f"Outputs written to: {output_dir}")

if __name__ == "__main__":
    main()
