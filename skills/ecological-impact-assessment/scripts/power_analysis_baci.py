#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
power_analysis_baci.py
Compute statistical power for BACI designs and recommend minimum sample sizes.
Usage: python power_analysis_baci.py <output_dir> [effect_size] [n_sites] [n_surveys] [alpha] [variance_estimate]
Outputs: power_curves.png, power_summary.csv, minimum_n_recommendation.md
Requires: numpy, scipy, matplotlib
"""
import logging
import math
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "ecological-impact-assessment"
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
from scipy import stats
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


# ── Helper: BACI power ──────────────────────────────────────────────────────
# BACI interaction term is tested as a two-sample t-test on the
# difference-in-differences. Effective n per group = n_sites * n_surveys.
# Cohen's d adjusted for variance: d = effect_size / sqrt(variance_estimate)

def baci_power(n_s: int, n_sv: int, eff: float, var_est: float, a: float) -> float:
    """Compute power for a BACI design using non-central t distribution."""
    try:
        d_adj = eff / math.sqrt(var_est)
        n_eff = n_s * n_sv  # effective replication per group
        df = 2 * n_eff - 2  # degrees of freedom for two-sample t-test
        if df < 1:
            return float("nan")
        # Non-centrality parameter
        ncp = d_adj * math.sqrt(n_eff / 2.0)
        t_crit = stats.t.ppf(1.0 - a / 2.0, df)
        # Power = P(|T_ncp| > t_crit) = 1 - P(-t_crit < T_ncp < t_crit)
        power = 1.0 - (stats.nct.cdf(t_crit, df, ncp) - stats.nct.cdf(-t_crit, df, ncp))
        return power
    except Exception:
        return float("nan")


def find_min_n(target_power: float, vary: str, fixed_n: int, eff: float,
               var_est: float, a: float, n_sv_or_ns: int) -> int | None:
    """Find minimum n_sites or n_surveys to reach target_power."""
    upper = 200 if vary == "sites" else 100
    for n in range(2 if vary == "sites" else 1, upper + 1):
        if vary == "sites":
            p = baci_power(n, n_sv_or_ns, eff, var_est, a)
        else:
            p = baci_power(n_sv_or_ns, n, eff, var_est, a)
        if not math.isnan(p) and p >= target_power:
            return n
    return None


def main():
    # ── Arguments ────────────────────────────────────────────────────────────
    args = sys.argv[1:]
    output_dir        = args[0] if len(args) >= 1 else "outputs/power_analysis"
    effect_size       = float(args[1]) if len(args) >= 2 else 0.5
    n_sites           = int(args[2])   if len(args) >= 3 else 10
    n_surveys         = int(args[3])   if len(args) >= 4 else 4
    alpha             = float(args[4]) if len(args) >= 5 else 0.05
    variance_estimate = float(args[5]) if len(args) >= 6 else 1.0

    log_decision("effect_size", effect_size,
                 "Cohen's d: 0.2=small, 0.5=medium, 0.8=large. Use 0.5 if no pilot data available.")
    log_decision("n_sites", n_sites,
                 "Number of control + impact sites each side. Minimum recommended: 5 per group.")
    log_decision("n_surveys", n_surveys,
                 "Survey occasions before + after. Minimum recommended: 3 pre + 3 post = 6 total.")
    log_decision("alpha", alpha,
                 "Type I error rate. Standard: 0.05. Use 0.10 for preliminary screening.")
    log_decision("variance_estimate", variance_estimate,
                 "Within-group variance from pilot data or literature. Affects Cohen's d calculation.")

    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    # ── Step 1: Power x n_sites ──────────────────────────────────────────────
    log_step(1, "Computing power x n_sites curve")
    sites_range = np.arange(2, 31)
    pow_vs_sites = np.array([baci_power(int(ns), n_surveys, effect_size, variance_estimate, alpha)
                             for ns in sites_range])
    current_power = baci_power(n_sites, n_surveys, effect_size, variance_estimate, alpha)
    logger.info("Power at n_sites=%d (n_surveys=%d fixed): %.3f", n_sites, n_surveys, current_power)

    # ── Step 2: Power x n_surveys ────────────────────────────────────────────
    log_step(2, "Computing power x n_surveys curve")
    surveys_range = np.arange(1, 21)
    pow_vs_surveys = np.array([baci_power(n_sites, int(nv), effect_size, variance_estimate, alpha)
                               for nv in surveys_range])

    # ── Step 3: Power x effect_size ──────────────────────────────────────────
    log_step(3, "Computing power x effect_size curve")
    eff_range = np.arange(0.1, 1.55, 0.05)
    pow_vs_eff = np.array([baci_power(n_sites, n_surveys, float(e), variance_estimate, alpha)
                           for e in eff_range])

    # ── Step 4: Minimum n calculations ───────────────────────────────────────
    log_step(4, "Calculating minimum n for power = 0.80 and 0.90")

    min_sites_80  = find_min_n(0.80, "sites", n_sites, effect_size, variance_estimate, alpha, n_surveys)
    min_sites_90  = find_min_n(0.90, "sites", n_sites, effect_size, variance_estimate, alpha, n_surveys)
    min_surveys_80 = find_min_n(0.80, "surveys", n_surveys, effect_size, variance_estimate, alpha, n_sites)
    min_surveys_90 = find_min_n(0.90, "surveys", n_surveys, effect_size, variance_estimate, alpha, n_sites)

    logger.info("Min sites for power=0.80: %s | power=0.90: %s (surveys=%d fixed)",
                min_sites_80, min_sites_90, n_surveys)
    logger.info("Min surveys for power=0.80: %s | power=0.90: %s (sites=%d fixed)",
                min_surveys_80, min_surveys_90, n_sites)

    if min_sites_80 is None:
        logger.warning("Power 0.80 not achievable with sites<=200. Increase effect_size or reduce variance_estimate.")

    # ── Step 5: Power curves plot ────────────────────────────────────────────
    log_step(5, "Generating power curves plot")
    try:
        fig, axes = plt.subplots(3, 1, figsize=(8, 12))

        # Panel 1: power vs sites
        ax = axes[0]
        ax.plot(sites_range, pow_vs_sites, color="#2471a3", linewidth=2)
        ax.axhline(0.80, linestyle="--", color="#e74c3c", linewidth=0.8)
        ax.axhline(0.90, linestyle="--", color="#27ae60", linewidth=0.8)
        if min_sites_80 is not None:
            ax.axvline(min_sites_80, linestyle=":", color="#e74c3c", linewidth=0.8)
            ax.annotate(f"n={min_sites_80}\n(80%)", xy=(min_sites_80 + 0.5, 0.05),
                        fontsize=8, color="#e74c3c")
        if min_sites_90 is not None:
            ax.axvline(min_sites_90, linestyle=":", color="#27ae60", linewidth=0.8)
            ax.annotate(f"n={min_sites_90}\n(90%)", xy=(min_sites_90 + 0.5, 0.05),
                        fontsize=8, color="#27ae60")
        ax.set_ylim(0, 1)
        ax.set_ylabel("Statistical Power")
        ax.set_xlabel("Number of sites per group")
        ax.set_title(f"BACI Power vs. Sites (n_surveys={n_surveys} fixed)")

        # Panel 2: power vs surveys
        ax = axes[1]
        ax.plot(surveys_range, pow_vs_surveys, color="#8e44ad", linewidth=2)
        ax.axhline(0.80, linestyle="--", color="#e74c3c", linewidth=0.8)
        ax.axhline(0.90, linestyle="--", color="#27ae60", linewidth=0.8)
        ax.set_ylim(0, 1)
        ax.set_ylabel("Statistical Power")
        ax.set_xlabel("Survey occasions (before + after)")
        ax.set_title(f"BACI Power vs. Surveys (n_sites={n_sites} fixed)")

        # Panel 3: power vs effect size
        ax = axes[2]
        ax.plot(eff_range, pow_vs_eff, color="#e67e22", linewidth=2)
        ax.axhline(0.80, linestyle="--", color="#e74c3c", linewidth=0.8)
        ax.axhline(0.90, linestyle="--", color="#27ae60", linewidth=0.8)
        ax.axvline(effect_size, linestyle=":", color="grey", linewidth=0.8)
        ax.set_ylim(0, 1)
        ax.set_ylabel("Statistical Power")
        ax.set_xlabel("Effect size (Cohen's d)")
        ax.set_title(f"BACI Power vs. Effect Size (n={n_sites} sites, {n_surveys} surveys)")

        fig.tight_layout()
        plot_file = out_path / "power_curves.png"
        fig.savefig(plot_file, dpi=150)
        plt.close(fig)
        logger.info("Power curves plot saved: %s", plot_file)
    except Exception as exc:
        logger.error(
            "Failed to generate power plot: %s\n"
            "Probable cause: matplotlib not installed.\n"
            "Check: pip install matplotlib",
            exc,
        )
        sys.exit(1)

    # ── Step 6: Power summary CSV ────────────────────────────────────────────
    log_step(6, "Saving power summary CSV")
    import pandas as pd

    summary_df = pd.DataFrame({
        "parameter": [
            "effect_size", "n_sites", "n_surveys", "alpha", "variance_estimate",
            "power_current", "min_sites_power80", "min_sites_power90",
            "min_surveys_power80", "min_surveys_power90",
        ],
        "value": [
            effect_size, n_sites, n_surveys, alpha, variance_estimate,
            round(current_power, 4),
            min_sites_80 if min_sites_80 is not None else "NA",
            min_sites_90 if min_sites_90 is not None else "NA",
            min_surveys_80 if min_surveys_80 is not None else "NA",
            min_surveys_90 if min_surveys_90 is not None else "NA",
        ],
    })
    csv_file = out_path / "power_summary.csv"
    summary_df.to_csv(csv_file, index=False)
    logger.info("Power summary saved: %s", csv_file)

    # ── Step 7: Recommendation markdown ──────────────────────────────────────
    log_step(7, "Writing minimum-n recommendation report")
    adequacy = "ADEQUATE" if (not math.isnan(current_power) and current_power >= 0.80) else "INSUFFICIENT"

    def _fmt(val):
        return str(val) if val is not None else "not achievable"

    rec_lines = f"""# BACI Power Analysis -- Field Protocol Recommendation

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Input Parameters
- **Effect size (Cohen's d):** {effect_size}
- **Number of sites (per group):** {n_sites}
- **Survey occasions (before + after):** {n_surveys}
- **Significance level (alpha):** {alpha}
- **Variance estimate:** {variance_estimate}

## Current Design Power
**Statistical power = {round(current_power * 100, 1)}%** ({adequacy})

{"WARNING: The current design has insufficient power to detect the target effect." if adequacy == "INSUFFICIENT" else "The current design has adequate power to detect the target effect."}

## Minimum Sample Size Recommendations

### To achieve power = 80% (alpha = {alpha})
- **Sites per group:** >= {_fmt(min_sites_80)} (with {n_surveys} survey occasions)
- **Survey occasions:** >= {_fmt(min_surveys_80)} (with {n_sites} sites)

### To achieve power = 90% (alpha = {alpha})
- **Sites per group:** >= {_fmt(min_sites_90)} (with {n_surveys} survey occasions)
- **Survey occasions:** >= {_fmt(min_surveys_90)} (with {n_sites} sites)

## Interpretation
- A Cohen's d of **{effect_size}** corresponds to detecting a {round(effect_size * math.sqrt(variance_estimate), 3)} unit difference between impact and control sites, adjusting for var = {variance_estimate}.
- **Rule of thumb:** BACI studies should have >=5 control and >=5 impact sites, with >=3 survey occasions before and >=3 after the impact.
- If power is insufficient, prioritise adding **sites** (stronger than adding surveys) because spatial replication reduces pseudo-replication bias.

## How to Obtain Variance Estimate
1. **From pilot data:** compute SD of the response variable across sites, then var = SD^2.
2. **From literature:** use SD values reported for the same metric and habitat type.
3. **Conservative default:** use variance_estimate = 1.0 (corresponds to Cohen's d units).

## References
- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.).
- Underwood, A.J. (1994). On beyond BACI. *Ecological Applications*, 4(1), 3-15.
- Stewart-Oaten, A. & Bence, J.R. (2001). Temporal and spatial variation in environmental impact assessment. *Ecological Monographs*, 71(2), 305-339.
"""

    md_file = out_path / "minimum_n_recommendation.md"
    md_file.write_text(rec_lines, encoding="utf-8")
    logger.info("Recommendation report saved: %s", md_file)

    log_step(8, "Done -- power analysis outputs in: %s" % output_dir)


if __name__ == "__main__":
    main()
