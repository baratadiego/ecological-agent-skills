# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Graph-based landscape connectivity analysis using networkx and scikit-image.

Usage:
    python connectivity_analysis.py <patches_csv> <output_dir>
        [--dmax 1000] [--area_col area_ha]

Inputs:
    patches_csv — CSV with columns: patch_id, x (centroid easting),
                  y (centroid northing), <area_col>
                  (produced by GIS export of patch centroids)

Outputs:
    patch_metrics.csv        — IIC, dIIC, PC, dPC, betweenness centrality
    landscape_summary.csv    — Landscape-level metrics
    connectivity_graph.png   — Network plot coloured by dPC
    least_cost_paths.csv     — Pairwise effective resistance and path length

Notes:
    For resistance-surface least-cost paths, provide a resistance raster via
    --resistance_tif. Requires rasterio and scikit-image.
"""

import logging
import sys
import csv
import math
import argparse
import warnings
from datetime import datetime
from pathlib import Path
from itertools import combinations

SKILL_NAME = "landscape-connectivity"
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
    import networkx as nx
except ImportError:
    logger.error("networkx not installed. Run: pip install networkx")
    sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Graph-based landscape connectivity metrics"
    )
    parser.add_argument("patches_csv", help="CSV of patch centroids (id, x, y, area_ha)")
    parser.add_argument("output_dir",  help="Output directory")
    parser.add_argument("--dmax",      type=float, default=1000.0,
                        help="Max dispersal distance in map units (default: 1000)")
    parser.add_argument("--area_col",  default="area_ha",
                        help="Column name for patch area (default: area_ha)")
    parser.add_argument("--resistance_tif", default=None,
                        help="Optional resistance raster for least-cost paths")
    return parser.parse_args()


def load_patches(csv_path: Path, area_col: str) -> list[dict]:
    """Load patch data from CSV."""
    patches = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                patches.append({
                    "id":   row.get("patch_id", row.get("id", str(len(patches)))),
                    "x":    float(row["x"]),
                    "y":    float(row["y"]),
                    "area": float(row[area_col]),
                })
            except (KeyError, ValueError) as e:
                logger.warning("Skipping row %s: %s", row, e)
                warnings.warn(f"Skipping row {row}: {e}")
    return patches


def euclidean_distance(p1: dict, p2: dict) -> float:
    return math.sqrt((p1["x"] - p2["x"]) ** 2 + (p1["y"] - p2["y"]) ** 2)


def build_graph(patches: list[dict], dmax: float) -> nx.Graph:
    """Build undirected graph; edges for pairs within dmax."""
    G = nx.Graph()
    for p in patches:
        G.add_node(p["id"], x=p["x"], y=p["y"], area=p["area"])
    for p1, p2 in combinations(patches, 2):
        d = euclidean_distance(p1, p2)
        if d < dmax:
            prob = math.exp(-d / dmax)  # negative exponential kernel
            G.add_edge(p1["id"], p2["id"], weight=d, prob=prob)
    return G


def compute_iic(G: nx.Graph, total_area: float) -> float:
    """Integral Index of Connectivity (binary graph)."""
    nodes = list(G.nodes())
    n = len(nodes)
    numerator = 0.0
    # Convert to unweighted graph for hop-count shortest paths
    G_uw = nx.Graph(G)
    for u, v in G_uw.edges():
        G_uw[u][v]["weight"] = 1

    for i, ni in enumerate(nodes):
        for j, nj in enumerate(nodes):
            if i <= j:
                try:
                    nij = nx.shortest_path_length(G_uw, ni, nj)
                except nx.NetworkXNoPath:
                    continue
                ai = G.nodes[ni]["area"]
                aj = G.nodes[nj]["area"]
                val = (ai * aj) / (1 + nij)
                numerator += val if i == j else 2 * val

    return numerator / (total_area ** 2)


def compute_pc(G: nx.Graph, total_area: float) -> float:
    """Probability of Connectivity using shortest probabilistic paths."""
    nodes = list(G.nodes())
    numerator = 0.0
    # Edge weight for dijkstra = -log(prob)
    G_prob = nx.Graph()
    G_prob.add_nodes_from(G.nodes(data=True))
    for u, v, data in G.edges(data=True):
        neg_log_p = -math.log(data.get("prob", 1e-9) + 1e-12)
        G_prob.add_edge(u, v, weight=neg_log_p)

    for i, ni in enumerate(nodes):
        for j, nj in enumerate(nodes):
            if i <= j:
                try:
                    path_cost = nx.shortest_path_length(G_prob, ni, nj, weight="weight")
                    pij = math.exp(-path_cost)
                except nx.NetworkXNoPath:
                    pij = 0.0
                ai = G.nodes[ni]["area"]
                aj = G.nodes[nj]["area"]
                val = pij * ai * aj
                numerator += val if i == j else 2 * val

    return numerator / (total_area ** 2)


def patch_importance(patches: list[dict], dmax: float,
                     iic_full: float, pc_full: float,
                     total_area: float) -> list[dict]:
    """Compute dIIC and dPC for each patch by leave-one-out."""
    results = []
    for i, target in enumerate(patches):
        remaining = [p for j, p in enumerate(patches) if j != i]
        ta_i = sum(p["area"] for p in remaining)
        G_i  = build_graph(remaining, dmax)
        iic_i = compute_iic(G_i, ta_i)
        pc_i  = compute_pc(G_i, ta_i)
        diic = (iic_full - iic_i) / iic_full * 100 if iic_full > 0 else 0
        dpc  = (pc_full  - pc_i)  / pc_full  * 100 if pc_full  > 0 else 0
        results.append({"patch_id": target["id"],
                         "dIIC_pct": round(diic, 4),
                         "dPC_pct":  round(dpc,  4)})
    return results


def main():
    args = parse_args()
    patches_csv = Path(args.patches_csv)
    output_dir  = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("patches_csv", str(patches_csv),
                 "Input CSV of patch centroids with area values")
    log_decision("dmax", args.dmax,
                 "Maximum dispersal distance threshold for edge creation (map units)")
    log_decision("area_col", args.area_col,
                 "Column name for patch area in the input CSV")

    if not patches_csv.exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: ecological-impact-assessment",
            patches_csv
        )
        sys.exit(1)

    try:
        log_step(1, "Loading patch data from CSV")
        patches = load_patches(patches_csv, args.area_col)
        if len(patches) < 3:
            logger.error("Need at least 3 patches, found %d", len(patches))
            sys.exit(1)

        total_area = sum(p["area"] for p in patches)
        logger.info("Loaded %d patches. Total area: %.1f ha", len(patches), total_area)
        logger.info("Dispersal distance threshold (dmax): %s m", args.dmax)

        log_step(2, "Building landscape connectivity graph")
        G = build_graph(patches, args.dmax)
        logger.info("Graph: %d nodes, %d edges", G.number_of_nodes(), G.number_of_edges())
        if G.number_of_edges() == 0:
            logger.warning(
                "No edges in graph — all patch pairs exceed dmax=%.1f. "
                "Consider increasing --dmax.",
                args.dmax
            )

        log_step(3, "Computing landscape-level IIC and PC metrics")
        # Landscape metrics
        iic_full = compute_iic(G, total_area)
        pc_full  = compute_pc(G,  total_area)
        comps    = list(nx.connected_components(G))
        largest  = max(len(c) for c in comps)
        logger.info("IIC = %.6f  |  PC = %.6f", iic_full, pc_full)
        logger.info("Components: %d, largest: %d patches", len(comps), largest)
        if len(comps) > 1:
            logger.warning(
                "Landscape is fragmented into %d disconnected components. "
                "dmax may be too small or habitat too sparse.",
                len(comps)
            )

        log_step(4, "Computing betweenness centrality")
        # Betweenness centrality (unweighted)
        bc_dict = nx.betweenness_centrality(G, normalized=True)

        log_step(5, "Computing patch importance (dIIC, dPC) via leave-one-out")
        logger.info("Computing patch importance (dIIC, dPC)...")
        importance = patch_importance(patches, args.dmax, iic_full, pc_full, total_area)

        log_step(6, "Assembling and writing patch metrics CSV")
        # Assemble patch metrics
        comp_membership = {}
        for c_id, comp in enumerate(comps):
            for node in comp:
                comp_membership[node] = c_id + 1

        patch_rows = []
        imp_dict = {r["patch_id"]: r for r in importance}
        for p in patches:
            pid = p["id"]
            row = {
                "patch_id":   pid,
                "area_ha":    p["area"],
                "dIIC_pct":   imp_dict.get(pid, {}).get("dIIC_pct", 0),
                "dPC_pct":    imp_dict.get(pid, {}).get("dPC_pct",  0),
                "BC_norm":    round(bc_dict.get(pid, 0), 4),
                "component":  comp_membership.get(pid, -1),
            }
            patch_rows.append(row)

        patch_rows.sort(key=lambda r: -r["dPC_pct"])
        patch_path = output_dir / "patch_metrics.csv"
        with open(patch_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(patch_rows[0].keys()))
            writer.writeheader()
            writer.writerows(patch_rows)
        logger.info("Patch metrics -> %s", patch_path)

        log_step(7, "Writing landscape summary CSV")
        # Landscape summary
        summary_path = output_dir / "landscape_summary.csv"
        with open(summary_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["metric", "value"])
            writer.writerows([
                ["IIC",                    round(iic_full, 6)],
                ["PC",                     round(pc_full,  6)],
                ["n_patches",              len(patches)],
                ["n_components",           len(comps)],
                ["largest_component_size", largest],
                ["dmax_m",                 args.dmax],
                ["total_patch_area_ha",    round(total_area, 2)],
            ])
        logger.info("Landscape summary -> %s", summary_path)

        log_step(8, "Computing pairwise effective resistance / least-cost paths")
        # Pairwise effective resistance (from PC path costs)
        lcp_rows = []
        G_prob = nx.Graph()
        G_prob.add_nodes_from(G.nodes(data=True))
        for u, v, data in G.edges(data=True):
            neg_log_p = -math.log(data.get("prob", 1e-9) + 1e-12)
            G_prob.add_edge(u, v, weight=neg_log_p)

        for p1, p2 in combinations(patches, 2):
            try:
                cost = nx.shortest_path_length(G_prob, p1["id"], p2["id"],
                                               weight="weight")
                dist = euclidean_distance(p1, p2)
                lcp_rows.append({"from": p1["id"], "to": p2["id"],
                                  "euclidean_dist_m": round(dist, 1),
                                  "effective_cost":   round(cost, 4),
                                  "pij_star":         round(math.exp(-cost), 4)})
            except nx.NetworkXNoPath:
                lcp_rows.append({"from": p1["id"], "to": p2["id"],
                                  "euclidean_dist_m": round(euclidean_distance(p1, p2), 1),
                                  "effective_cost": float("inf"),
                                  "pij_star": 0.0})

        lcp_path = output_dir / "least_cost_paths.csv"
        if lcp_rows:
            with open(lcp_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=list(lcp_rows[0].keys()))
                writer.writeheader()
                writer.writerows(lcp_rows)
            logger.info("Pairwise costs -> %s", lcp_path)

        log_step(9, "Generating network visualisation plot")
        # Network visualisation
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt
            import matplotlib.cm as cm

            fig, ax = plt.subplots(figsize=(8, 7))
            pos = {p["id"]: (p["x"], p["y"]) for p in patches}
            dpc_vals = np.array([r["dPC_pct"] for r in patch_rows])
            node_order = [p["id"] for p in patches]
            dpc_map = {r["patch_id"]: r["dPC_pct"] for r in patch_rows}
            node_colors = [dpc_map.get(n, 0) for n in G.nodes()]
            area_map = {p["id"]: p["area"] for p in patches}
            max_area = max(area_map.values())
            node_sizes = [300 * area_map.get(n, 1) / max_area + 50 for n in G.nodes()]

            nx.draw_networkx_edges(G, pos, ax=ax, alpha=0.4, edge_color="grey")
            sc = nx.draw_networkx_nodes(G, pos, ax=ax,
                                        node_color=node_colors,
                                        node_size=node_sizes,
                                        cmap=plt.cm.plasma)
            plt.colorbar(sc, ax=ax, label="dPC (%)")
            ax.set_title(f"Connectivity graph (dmax={args.dmax}m, IIC={iic_full:.4f})")
            ax.set_xlabel("Easting"); ax.set_ylabel("Northing")
            ax.axis("equal")
            plt.tight_layout()
            fig.savefig(output_dir / "connectivity_graph.png", dpi=150)
            plt.close(fig)
            logger.info("Graph plot -> %s", output_dir / "connectivity_graph.png")
        except ImportError:
            logger.warning("matplotlib not available; skipping network plot.")

        logger.info("Connectivity analysis complete.")
        logger.info(
            "Top patch by dPC: %s (dPC = %.2f%%)",
            patch_rows[0]["patch_id"], patch_rows[0]["dPC_pct"]
        )

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: ecological-impact-assessment\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in connectivity analysis: %s", e)
        raise


if __name__ == "__main__":
    main()
