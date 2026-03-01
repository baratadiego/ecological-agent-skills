#!/usr/bin/env python3
"""
sdm_pipeline.py
SDM pipeline scaffold using elapid (MaxEnt equivalent in Python) + sklearn.
Usage: python sdm_pipeline.py <params_yaml> <output_dir>
Requires: pandas, numpy, sklearn, elapid (optional), yaml, matplotlib
"""
import sys, yaml, json
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import StratifiedKFold

try:
    import elapid
    HAS_ELAPID = True
except ImportError:
    HAS_ELAPID = False
    print("elapid not installed (MaxEnt). pip install elapid")

def load_params(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)

def load_data(p: dict) -> tuple:
    pts = pd.read_csv("data/processed/points_with_env.csv")
    predictors = open("outputs/selected_predictors.txt").read().strip().split("\n")
    predictors = [pr for pr in predictors if pr in pts.columns]
    X = pts[predictors].values
    y = pts["pa"].values if "pa" in pts.columns else pts["presence"].values
    return X, y, predictors

def spatial_cv_splits(pts_df, fold_col="cv_fold"):
    folds = pts_df[fold_col].unique()
    for fold in sorted(folds):
        test_idx  = pts_df.index[pts_df[fold_col] == fold].tolist()
        train_idx = pts_df.index[pts_df[fold_col] != fold].tolist()
        yield train_idx, test_idx

def fit_rf(X_train, y_train, params: dict):
    rf_p = params.get("hyperparameters", {}).get("random_forest", {})
    clf = RandomForestClassifier(n_estimators=rf_p.get("n_trees", 500),
                                  min_samples_leaf=rf_p.get("min_node_size", 5),
                                  random_state=params["random_seeds"]["global"],
                                  n_jobs=-1)
    clf.fit(X_train, y_train)
    return clf

def fit_brt(X_train, y_train, params: dict):
    brt_p = params.get("hyperparameters", {}).get("brt", {})
    clf = GradientBoostingClassifier(n_estimators=brt_p.get("n_trees", [500])[0],
                                      learning_rate=brt_p.get("learning_rate", [0.01])[0],
                                      max_depth=brt_p.get("tree_complexity", [3])[0],
                                      subsample=brt_p.get("bag_fraction", 0.75),
                                      random_state=params["random_seeds"]["global"])
    clf.fit(X_train, y_train)
    return clf

def main():
    params_file = sys.argv[1] if len(sys.argv) > 1 else "params.yaml"
    output_dir  = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/sdm")
    output_dir.mkdir(parents=True, exist_ok=True)

    p = load_params(params_file)
    np.random.seed(p["random_seeds"]["global"])
    print(f"SDM pipeline | Algorithms: {p['modeling']['algorithms']}")

    try:
        X, y, predictors = load_data(p)
    except Exception as e:
        print(f"Could not load data: {e}\nScaffold loaded. Add data loading for your study.")
        return

    # Spatial CV (simple k-fold fallback)
    skf = StratifiedKFold(n_splits=p["modeling"]["cv_folds"], shuffle=True,
                          random_state=p["random_seeds"]["global"])
    auc_rf, auc_brt = [], []
    for fold, (train_idx, test_idx) in enumerate(skf.split(X, y)):
        X_tr, X_te = X[train_idx], X[test_idx]
        y_tr, y_te = y[train_idx], y[test_idx]
        if "random_forest" in p["modeling"]["algorithms"]:
            rf = fit_rf(X_tr, y_tr, p)
            auc_rf.append(roc_auc_score(y_te, rf.predict_proba(X_te)[:, 1]))
        if "brt" in p["modeling"]["algorithms"]:
            brt = fit_brt(X_tr, y_tr, p)
            auc_brt.append(roc_auc_score(y_te, brt.predict_proba(X_te)[:, 1]))
        print(f"  Fold {fold+1}: RF AUC = {auc_rf[-1]:.3f}" if auc_rf else "")

    results = {}
    if auc_rf:  results["RandomForest"] = {"AUC_mean": np.mean(auc_rf), "AUC_sd": np.std(auc_rf)}
    if auc_brt: results["BRT"]         = {"AUC_mean": np.mean(auc_brt), "AUC_sd": np.std(auc_brt)}
    results_df = pd.DataFrame(results).T
    results_df.to_csv(output_dir / "cv_performance.csv")
    print(f"\nCV Performance:\n{results_df.to_string()}")
    print(f"\nOutputs written to: {output_dir}")

if __name__ == "__main__":
    main()
