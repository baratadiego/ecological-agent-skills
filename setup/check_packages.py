#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later
#
# check_packages.py -- Preflight check & installer for Python dependencies
#
# Usage:
#   python setup/check_packages.py                     # check all skills
#   python setup/check_packages.py --phase 1           # check Phase 1 only
#   python setup/check_packages.py --skill sdm         # check one skill
#   python setup/check_packages.py --install            # install missing packages
#   python setup/check_packages.py --install --phase 2  # install missing in Phase 2
#
# Returns exit code 0 if all packages are present, 1 if any are missing.
# ──────────────────────────────────────────────────────────────────────────────

import argparse
import importlib
import subprocess
import sys
from typing import Optional

# ── Package registry ─────────────────────────────────────────────────────────
# Maps: import_name -> pip_name (when they differ)
# Only lists third-party packages; stdlib modules are excluded.

PIP_NAMES = {
    "cv2": "opencv-python",
    "sklearn": "scikit-learn",
    "yaml": "pyyaml",
    "Bio": "biopython",
    "PIL": "Pillow",
    "bs4": "beautifulsoup4",
}

SKILL_PACKAGES: dict[str, dict] = {
    # ── Phase 1: Foundation ──────────────────────────────────────────────
    "ecological-data-foundation": {
        "phase": 1,
        "display": "Ecological Data Foundation",
        "packages": ["numpy", "pandas"],
    },
    "geoprocessing-for-ecology": {
        "phase": 1,
        "display": "Geoprocessing for Ecology",
        "packages": ["numpy", "pandas", "geopandas", "rasterio", "shapely"],
    },
    "biostatistics-workbench": {
        "phase": 1,
        "display": "Biostatistics Workbench",
        "packages": ["numpy", "pandas", "scipy", "statsmodels", "matplotlib"],
    },
    "predictive-modeling-best-practices": {
        "phase": 1,
        "display": "Predictive Modeling Best Practices",
        "packages": ["numpy", "pandas", "matplotlib"],
    },
    "reproducible-ecology-pipeline": {
        "phase": 1,
        "display": "Reproducible Ecology Pipeline",
        "packages": [],  # stdlib only (pathlib, hashlib, logging)
    },
    # ── Phase 2: Modeling ────────────────────────────────────────────────
    "species-distribution-modeling": {
        "phase": 2,
        "display": "Species Distribution Modeling",
        "packages": [
            "numpy", "pandas", "matplotlib", "sklearn",
            "yaml",
        ],
    },
    "model-validation-and-uncertainty": {
        "phase": 2,
        "display": "Model Validation & Uncertainty",
        "packages": ["numpy", "pandas", "matplotlib", "sklearn"],
    },
    "ecological-impact-assessment": {
        "phase": 2,
        "display": "Ecological Impact Assessment",
        "packages": ["numpy", "pandas", "rasterio", "scipy"],
    },
    "environmental-time-series": {
        "phase": 2,
        "display": "Environmental Time Series",
        "packages": ["numpy", "pandas", "matplotlib", "scipy"],
    },
    # ── Phase 3: Specialist ──────────────────────────────────────────────
    "occupancy-and-detection": {
        "phase": 3,
        "display": "Occupancy & Detection",
        "packages": ["numpy", "pandas"],
    },
    "community-ecology-ordination": {
        "phase": 3,
        "display": "Community Ecology Ordination",
        "packages": ["numpy", "pandas", "matplotlib", "scipy"],
    },
    "ecosystem-services-assessment": {
        "phase": 3,
        "display": "Ecosystem Services Assessment",
        "packages": ["numpy", "pandas", "rasterio"],
    },
    # ── Phase 4: Advanced ────────────────────────────────────────────────
    "camera-trap-processing": {
        "phase": 4,
        "display": "Camera Trap Processing",
        "packages": ["numpy", "pandas", "matplotlib"],
    },
    "acoustic-monitoring": {
        "phase": 4,
        "display": "Acoustic Monitoring",
        "packages": [],  # uses stdlib + subprocess to call BirdNET
    },
    "landscape-connectivity": {
        "phase": 4,
        "display": "Landscape Connectivity",
        "packages": ["numpy"],
    },
    "population-viability-analysis": {
        "phase": 4,
        "display": "Population Viability Analysis",
        "packages": ["numpy"],
    },
    "spatial-prioritization": {
        "phase": 4,
        "display": "Spatial Prioritization",
        "packages": [],  # R-only skill
    },
}

# ── Colour helpers ───────────────────────────────────────────────────────────

USE_COLOUR = sys.stdout.isatty()


def green(s: str) -> str:
    return f"\033[32m{s}\033[0m" if USE_COLOUR else s


def red(s: str) -> str:
    return f"\033[31m{s}\033[0m" if USE_COLOUR else s


def yellow(s: str) -> str:
    return f"\033[33m{s}\033[0m" if USE_COLOUR else s


def bold(s: str) -> str:
    return f"\033[1m{s}\033[0m" if USE_COLOUR else s


# ── Check logic ──────────────────────────────────────────────────────────────


def check_package(import_name: str) -> bool:
    """Return True if the package is importable."""
    try:
        importlib.import_module(import_name)
        return True
    except ImportError:
        return False


def pip_name(import_name: str) -> str:
    """Map import name to pip install name."""
    return PIP_NAMES.get(import_name, import_name)


def install_packages(packages: list[str]) -> dict[str, bool]:
    """Install packages via pip, return {pkg: success}."""
    results = {}
    for pkg in packages:
        pname = pip_name(pkg)
        print(f"  Installing {bold(pname)} ... ", end="", flush=True)
        try:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pname, "--quiet"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
            # Verify import works after install
            importlib.invalidate_caches()
            if check_package(pkg):
                print(green("OK"))
                results[pkg] = True
            else:
                print(red("INSTALLED BUT IMPORT FAILED"))
                results[pkg] = False
        except subprocess.CalledProcessError as e:
            print(red("FAILED"))
            stderr_msg = e.stderr.decode(errors="replace").strip()
            if stderr_msg:
                short = stderr_msg[:200] + "..." if len(stderr_msg) > 200 else stderr_msg
                print(f"    {red(short)}")
            results[pkg] = False
    return results


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="Check (and optionally install) Python dependencies for ecological-agent-skills"
    )
    parser.add_argument("--phase", type=int, choices=[1, 2, 3, 4], help="Check only this phase")
    parser.add_argument("--skill", type=str, help="Check a single skill (partial match)")
    parser.add_argument("--install", action="store_true", help="Install missing packages via pip")
    parser.add_argument("--summary", action="store_true", help="Compact one-line-per-skill view")
    args = parser.parse_args()

    # ── Filter skills ────────────────────────────────────────────────────
    skills = dict(SKILL_PACKAGES)

    if args.phase is not None:
        skills = {k: v for k, v in skills.items() if v["phase"] == args.phase}

    if args.skill is not None:
        matched = {k: v for k, v in SKILL_PACKAGES.items() if args.skill.lower() in k.lower()}
        if not matched:
            print(f"No skill matching '{args.skill}'")
            print("Available:")
            for k in SKILL_PACKAGES:
                print(f"  {k}")
            sys.exit(1)
        skills = matched

    # ── Run checks ───────────────────────────────────────────────────────
    print(bold("\n=== ecological-agent-skills: Python Package Check ===\n"))

    total_ok = 0
    total_miss = 0
    all_missing: list[str] = []

    for skill_id, info in skills.items():
        pkgs = list(dict.fromkeys(info["packages"]))  # dedupe preserving order

        phase = info["phase"]
        display = info["display"]
        header = bold(f"[Phase {phase}] {display}")

        if not pkgs:
            if not args.summary:
                print(header)
                print("  No third-party Python packages required\n")
            continue

        installed = {p: check_package(p) for p in pkgs}
        n_ok = sum(installed.values())
        n_miss = sum(not v for v in installed.values())
        total_ok += n_ok
        total_miss += n_miss

        missing = [p for p, ok in installed.items() if not ok]
        all_missing.extend(missing)

        if args.summary:
            status = green("OK") if n_miss == 0 else red(f"{n_miss} missing")
            print(f"  [Phase {phase}] {display:<42s} {status}")
        else:
            print(header)
            for p in pkgs:
                status = green("INSTALLED") if installed[p] else red("MISSING")
                print(f"  {p:<28s} {status}")
            print()

    # ── Summary ──────────────────────────────────────────────────────────
    print(bold("\n--- Summary ---"))
    print(f"  Packages checked : {total_ok + total_miss}")
    print(f"  Installed        : {green(str(total_ok))}")
    print(f"  Missing          : {red(str(total_miss)) if total_miss > 0 else green('0')}")

    all_missing = list(dict.fromkeys(all_missing))  # unique

    if total_miss > 0 and not args.install:
        pip_list = " ".join(pip_name(p) for p in all_missing)
        print(yellow(f"\nTo install all missing packages:"))
        print(f"  pip install {pip_list}")
        print(f"\nOr run: python setup/check_packages.py --install\n")
        sys.exit(1)

    if total_miss > 0 and args.install:
        print(yellow(f"\nInstalling {len(all_missing)} missing packages...\n"))
        results = install_packages(all_missing)
        n_failed = sum(not v for v in results.values())
        if n_failed > 0:
            print(red(f"\n{n_failed} package(s) failed to install."))
            print("Try installing manually or check your Python environment.\n")
            sys.exit(1)
        else:
            print(green("\nAll packages installed successfully!\n"))
            sys.exit(0)

    if total_miss == 0:
        print(green("\nAll Python packages are installed. You are ready to go!\n"))
        sys.exit(0)


if __name__ == "__main__":
    main()
