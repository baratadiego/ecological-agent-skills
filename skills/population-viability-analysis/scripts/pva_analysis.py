# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Population Viability Analysis using stage-structured matrix models.

Usage:
    python pva_analysis.py <vital_rates_csv> <output_dir>
        [--n_init 500] [--t_max 100] [--n_sim 1000] [--quasi_ext 50]

Inputs:
    vital_rates_csv — CSV with columns: year, a_i_j (matrix elements),
                      population_N (optional census count)

Implements:
    - Deterministic analysis: λ, stable stage, sensitivity, elasticity
    - Stochastic PVA: Monte Carlo with Beta/Lognormal vital rate sampling
    - IUCN Criterion E classification

Outputs:
    lambda_summary.csv           — Eigenvalue analysis
    stochastic_pva_results.csv   — P(extinction), MTE, λ_s
    extinction_curve.csv         — P(ext) by year
    iucn_criterion_e.csv         — Category assessment
    trajectory_plot.png          — Stochastic trajectories
"""

import logging
import sys
import csv
import math
import random
import argparse
import warnings
from datetime import datetime
from pathlib import Path
from collections import defaultdict

SKILL_NAME = "population-viability-analysis"
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

try:
    import numpy.linalg as la
except ImportError:
    logger.error("numpy required. Install: pip install numpy")
    sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(description="Population Viability Analysis")
    parser.add_argument("vital_rates_csv", help="CSV of vital rates over years")
    parser.add_argument("output_dir",      help="Output directory")
    parser.add_argument("--n_init",    type=int,   default=None,
                        help="Initial population size (default: last year N in CSV)")
    parser.add_argument("--t_max",    type=int,   default=100,
                        help="Projection years (default: 100)")
    parser.add_argument("--n_sim",    type=int,   default=1000,
                        help="Monte Carlo simulations (default: 1000)")
    parser.add_argument("--quasi_ext", type=float, default=50.0,
                        help="Quasi-extinction threshold (default: 50)")
    return parser.parse_args()


def load_vital_rates(csv_path: Path) -> tuple[list[str], list[dict]]:
    """Load vital rates CSV; return (mat_cols, rows)."""
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    mat_cols = [k for k in rows[0].keys() if k.startswith("a_")]
    return mat_cols, rows


def build_mean_matrix(mat_cols: list[str], rows: list[dict]) -> np.ndarray:
    """Build mean matrix from vital rate rows."""
    indices = []
    for col in mat_cols:
        parts = col.split("_")
        indices.append((int(parts[1]) - 1, int(parts[2]) - 1))
    k = max(max(i, j) for i, j in indices) + 1
    A = np.zeros((k, k))
    for col, (i, j) in zip(mat_cols, indices):
        vals = [float(r[col]) for r in rows if r[col] != ""]
        A[i, j] = sum(vals) / len(vals) if vals else 0.0
    return A


def compute_lambda(A: np.ndarray) -> float:
    """Dominant eigenvalue of A."""
    evals = la.eigvals(A)
    return float(max(evals.real))


def stable_stage(A: np.ndarray) -> np.ndarray:
    """Right eigenvector corresponding to dominant eigenvalue."""
    evals, evecs = la.eig(A)
    dom_idx = np.argmax(evals.real)
    v = evecs[:, dom_idx].real
    v = np.abs(v)
    return v / v.sum()


def sensitivity_matrix(A: np.ndarray) -> np.ndarray:
    """Sensitivity matrix S_ij = ∂λ/∂a_ij = w_i * v_j / <w,v>."""
    evals, evecs_right = la.eig(A)
    dom_idx = np.argmax(evals.real)
    w = evecs_right[:, dom_idx].real
    evals_l, evecs_left = la.eig(A.T)
    dom_idx_l = np.argmax(evals_l.real)
    v = evecs_left[:, dom_idx_l].real
    w, v = np.abs(w), np.abs(v)
    inner = np.dot(v, w)
    S = np.outer(w, v) / inner
    return S


def elasticity_matrix(A: np.ndarray, S: np.ndarray) -> np.ndarray:
    lam = compute_lambda(A)
    return (A / lam) * S


def beta_draw(mu: float, var: float) -> float:
    """Draw from Beta distribution parameterised by mean and variance."""
    if var <= 0 or mu <= 0 or mu >= 1:
        return mu
    max_var = mu * (1 - mu) - 1e-6
    var_use = min(var, max_var * 0.95)
    denom = mu * (1 - mu) / var_use - 1
    a = mu * denom
    b = (1 - mu) * denom
    if a <= 0 or b <= 0:
        return mu
    return random.betavariate(a, b)


def lnorm_draw(mu: float, var: float) -> float:
    """Draw from lognormal parameterised by mean and variance."""
    if var <= 0 or mu <= 0:
        return mu
    sigma2_ln = math.log(1 + var / mu**2)
    mu_ln     = math.log(mu) - sigma2_ln / 2
    return math.exp(random.gauss(mu_ln, math.sqrt(sigma2_ln)))


def build_stoch_distributions(mat_cols, rows, indices):
    """Compute mean and variance per matrix element."""
    dists = {}
    for col, (i, j) in zip(mat_cols, indices):
        vals = [float(r[col]) for r in rows if r.get(col, "") != ""]
        if not vals:
            dists[col] = {"mu": 0.0, "var": 0.0, "row": i, "col": j}
            continue
        mu  = sum(vals) / len(vals)
        var = sum((v - mu)**2 for v in vals) / max(len(vals) - 1, 1)
        dists[col] = {"mu": mu, "var": var, "row": i, "col": j}
    return dists


def draw_random_matrix(dists: dict, k: int) -> np.ndarray:
    A = np.zeros((k, k))
    for col, d in dists.items():
        i, j = d["row"], d["col"]
        mu, var = d["mu"], d["var"]
        if i == 0:  # fecundity row
            A[i, j] = max(0.0, lnorm_draw(mu, var))
        else:
            A[i, j] = beta_draw(mu, var)
    return A


def run_stochastic_pva(dists, k, n0, t_max, n_sim, quasi_ext, stable_stg):
    all_N     = np.full((n_sim, t_max + 1), np.nan)
    ext_times = np.full(n_sim, np.nan)

    for s in range(n_sim):
        n_vec = np.round(n0 * stable_stg).astype(float)
        all_N[s, 0] = n_vec.sum()
        extinct = False
        for t in range(1, t_max + 1):
            if not extinct:
                A_t   = draw_random_matrix(dists, k)
                n_vec = A_t @ n_vec
                N_t   = n_vec.sum()
                all_N[s, t] = N_t
                if N_t <= quasi_ext:
                    extinct = True
                    ext_times[s] = t
                    all_N[s, t + 1:] = 0.0
    return all_N, ext_times


def iucn_criterion_e(ext_curve, t_max, gen_time=20):
    results = []
    for cat, threshold, horiz_fn in [
        ("CR", 0.50, lambda g: min(100, max(10, 3 * g))),
        ("EN", 0.20, lambda g: min(100, max(20, 5 * g))),
        ("VU", 0.10, lambda g: 100),
    ]:
        T = int(round(horiz_fn(gen_time)))
        T_use = min(T, t_max) - 1
        p_ext = ext_curve[T_use] if T_use >= 0 else 0.0
        results.append({
            "category":     cat,
            "threshold":    threshold,
            "time_horizon": T,
            "p_extinction": round(p_ext, 4),
            "qualifies":    p_ext >= threshold,
        })
    return results


def main():
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("vital_rates_csv", args.vital_rates_csv,
                 "Input vital rates CSV with stage matrix elements over years")
    log_decision("t_max", args.t_max, "Projection horizon in years for stochastic PVA")
    log_decision("n_sim", args.n_sim, "Number of Monte Carlo simulation replicates")
    log_decision("quasi_ext", args.quasi_ext,
                 "Quasi-extinction threshold N below which population is considered extinct")

    if not Path(args.vital_rates_csv).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: reproducible-ecology-pipeline",
            args.vital_rates_csv
        )
        sys.exit(1)

    try:
        log_step(1, "Loading vital rates and building mean matrix")
        mat_cols, rows = load_vital_rates(Path(args.vital_rates_csv))
        if not mat_cols:
            logger.error("No a_i_j columns found in vital_rates_csv.")
            sys.exit(1)

        indices = [(int(c.split("_")[1]) - 1, int(c.split("_")[2]) - 1) for c in mat_cols]
        k = max(max(i, j) for i, j in indices) + 1
        logger.info("Matrix size: %dx%d", k, k)

        log_step(2, "Deterministic analysis: lambda, stable stage, sensitivity, elasticity")
        A = build_mean_matrix(mat_cols, rows)
        lam = compute_lambda(A)
        SS  = stable_stage(A)
        S   = sensitivity_matrix(A)
        E   = elasticity_matrix(A, S)

        logger.info("lambda = %.4f", lam)
        if lam < 0.95:
            logger.warning(
                "lambda = %.4f < 0.95 — population declining rapidly. "
                "Review vital rates and consider conservation interventions.",
                lam
            )
        elif lam < 1.0:
            logger.warning(
                "lambda = %.4f < 1.0 — population is declining (sub-replacement).",
                lam
            )

        log_step(3, "Resolving initial population size")
        # Initial N
        n0 = args.n_init
        if n0 is None:
            pop_vals = [float(r["population_N"]) for r in rows
                        if "population_N" in r and r["population_N"] != ""]
            n0 = int(pop_vals[-1]) if pop_vals else 1000
            log_decision("n0", n0,
                         "Taken from last population_N value in CSV (no --n_init provided)")
        else:
            log_decision("n0", n0, "User-specified initial population size via --n_init")
        logger.info("N0 = %d, quasi-extinction threshold = %s", n0, args.quasi_ext)

        log_step(4, "Writing lambda summary CSV")
        # Lambda summary
        lam_sum_path = output_dir / "lambda_summary.csv"
        with open(lam_sum_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["metric", "value"])
            writer.writerows([
                ["lambda",          round(lam, 6)],
                ["log_lambda",      round(math.log(lam), 6) if lam > 0 else "nan"],
                ["doubling_time_yr", round(math.log(2) / math.log(lam), 2) if lam > 1 else "Inf"],
                ["halving_time_yr",  round(math.log(0.5) / math.log(lam), 2) if 0 < lam < 1 else "Inf"],
            ])
            writer.writerow(["sum_elasticity", round(float(E.sum()), 4)])

        logger.info("Lambda summary -> %s", lam_sum_path)

        log_step(5, "Running stochastic Monte Carlo simulations")
        logger.info(
            "Running %d stochastic simulations (t=%d)...", args.n_sim, args.t_max
        )
        dists = build_stoch_distributions(mat_cols, rows, indices)
        all_N, ext_times = run_stochastic_pva(
            dists, k, n0, args.t_max, args.n_sim, args.quasi_ext, SS
        )

        log_step(6, "Computing extinction curve and IUCN Criterion E")
        # Extinction curve
        ext_curve = []
        for t in range(1, args.t_max + 1):
            p = float(np.sum(~np.isnan(ext_times) & (ext_times <= t))) / args.n_sim
            ext_curve.append(p)

        ext_path = output_dir / "extinction_curve.csv"
        with open(ext_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["time", "p_extinction"])
            for t, p in enumerate(ext_curve, 1):
                writer.writerow([t, round(p, 4)])
        logger.info("Extinction curve -> %s", ext_path)

        # IUCN Criterion E
        iucn_rows = iucn_criterion_e(ext_curve, args.t_max, gen_time=args.t_max // 5)
        iucn_path = output_dir / "iucn_criterion_e.csv"
        with open(iucn_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(iucn_rows[0].keys()))
            writer.writeheader()
            writer.writerows(iucn_rows)

        # Determine category
        risk_cat = "LC/NT"
        for row in iucn_rows:
            if row["qualifies"]:
                risk_cat = row["category"]
                break

        log_step(7, "Computing MTE and stochastic growth rate")
        # MTE
        valid_ext = ext_times[~np.isnan(ext_times)]
        mte_mean = float(np.mean(valid_ext)) if len(valid_ext) > 0 else float("inf")
        mte_lo   = float(np.percentile(valid_ext, 2.5))  if len(valid_ext) >= 10 else float("nan")
        mte_hi   = float(np.percentile(valid_ext, 97.5)) if len(valid_ext) >= 10 else float("nan")

        # Stochastic growth rate
        final_N  = all_N[:, -1]
        log_N    = np.log(final_N[np.isfinite(final_N) & (final_N > 0)])
        lam_s    = float(np.exp((np.mean(log_N) - math.log(n0)) / args.t_max)) if len(log_N) > 0 else float("nan")

        log_step(8, "Writing stochastic PVA results CSV")
        results_path = output_dir / "stochastic_pva_results.csv"
        with open(results_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["metric", "value"])
            writer.writerows([
                ["n_simulations",     args.n_sim],
                ["n_init",            n0],
                ["quasi_ext_threshold", args.quasi_ext],
                ["t_max",             args.t_max],
                ["p_extinction",      round(ext_curve[-1], 4)],
                ["mte_mean_yr",       round(mte_mean, 1)],
                ["mte_CI_2.5",        round(mte_lo, 1)],
                ["mte_CI_97.5",       round(mte_hi, 1)],
                ["lambda_s",          round(lam_s, 4)],
                ["iucn_category",     risk_cat],
            ])
        logger.info("PVA results -> %s", results_path)
        logger.info("P(extinction at t=%d) = %.4f", args.t_max, ext_curve[-1])
        logger.info("IUCN Criterion E: %s", risk_cat)
        if risk_cat in ("CR", "EN"):
            logger.warning(
                "Population qualifies as %s under IUCN Criterion E. "
                "Immediate conservation action recommended.",
                risk_cat
            )

        log_step(9, "Generating trajectory and extinction curve plots")
        # Trajectory plot
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt

            fig, axes = plt.subplots(1, 2, figsize=(12, 5))
            t_axis = np.arange(args.t_max + 1)
            sample_idx = np.random.choice(args.n_sim, min(200, args.n_sim), replace=False)
            for s in sample_idx:
                axes[0].plot(t_axis, all_N[s, :], alpha=0.05, color="steelblue", lw=0.5)
            med_N = np.nanmedian(all_N, axis=0)
            axes[0].plot(t_axis, med_N, color="darkblue", lw=2, label="Median N")
            axes[0].axhline(args.quasi_ext, color="red", ls="--", label=f"Ne={args.quasi_ext}")
            axes[0].set_xlabel("Time (years)"); axes[0].set_ylabel("N")
            axes[0].set_title(f"Stochastic trajectories ({args.n_sim} sims, N0={n0})")
            axes[0].legend(); axes[0].set_ylim(bottom=0)

            axes[1].plot(range(1, args.t_max + 1), ext_curve, color="darkred", lw=2)
            for pct, label, col in [(0.50, "CR >=50%", "red"),
                                      (0.20, "EN >=20%", "orange"),
                                      (0.10, "VU >=10%", "goldenrod")]:
                axes[1].axhline(pct, color=col, ls="--", lw=1, label=label)
            axes[1].set_xlabel("Time (years)"); axes[1].set_ylabel("P(quasi-extinction)")
            axes[1].set_title(f"Extinction curve (Ne={args.quasi_ext})")
            axes[1].legend(); axes[1].set_ylim(0, 1)

            plt.suptitle(f"PVA — IUCN Category: {risk_cat} | lambda={lam:.4f} | lambda_s={lam_s:.4f}")
            plt.tight_layout()
            fig.savefig(output_dir / "trajectory_plot.png", dpi=150)
            plt.close(fig)
            logger.info("Trajectory plot -> %s", output_dir / "trajectory_plot.png")
        except ImportError:
            logger.warning("matplotlib not available; skipping trajectory plot.")

        logger.info("PVA analysis complete.")

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: reproducible-ecology-pipeline\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in PVA analysis: %s", e)
        raise


if __name__ == "__main__":
    main()
