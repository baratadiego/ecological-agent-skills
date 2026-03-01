#!/usr/bin/env python3
"""
glm_pipeline.py
Fit candidate GLMs, check assumptions, model selection.
Usage: python glm_pipeline.py <data_csv> <response_var> <output_dir>
Requires: pandas, numpy, statsmodels, scipy, matplotlib, seaborn
"""
import sys
from pathlib import Path
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
            print(f"  {label}: AIC = {m.aic:.2f}")
        except Exception as e:
            print(f"  {label}: FAILED — {e}")
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
    output_dir.mkdir(parents=True, exist_ok=True)

    dat = pd.read_csv(data_file)
    print(f"Loaded {len(dat)} rows. Response: {response_var}")

    # --- Define your candidate models here ---
    candidates = {
        "null":    f"{response_var} ~ 1",
        "model1":  f"{response_var} ~ C(group)",
        "model2":  f"{response_var} ~ C(group) + elevation",
        "model3":  f"{response_var} ~ C(group) + elevation + forest_cover",
    }
    family = sm.families.NegativeBinomial()

    print("\nFitting candidate models:")
    results = fit_candidates(dat, response_var, candidates, family)

    tbl = model_selection_table(results)
    print(f"\nModel selection table:\n{tbl[['label','AIC','deltaAIC','weight']].to_string(index=False)}")
    tbl.drop(columns=["model"], errors="ignore").to_csv(output_dir / "model_selection.csv", index=False)

    best_result = min(results, key=lambda x: x["AIC"])
    best_model  = best_result["model"]
    print(f"\nBest model: {best_result['label']}")
    print(best_model.summary())
    (output_dir / "best_model_summary.txt").write_text(str(best_model.summary()))

    diagnostic_plots(best_model, best_result["label"], output_dir)
    print(f"\nOutputs written to: {output_dir}")

if __name__ == "__main__":
    main()
