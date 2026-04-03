#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
occupancy_analysis.py
Single-season occupancy analysis scaffold.
For full occupancy modelling in Python, interface with JAGS or use pyoccupancy.
This script demonstrates data formatting and naive occupancy computation.
Usage: python occupancy_analysis.py <detection_history_csv> <output_dir>
Requires: pandas, numpy
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "occupancy-and-detection"
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


def compute_naive_occ(dh: np.ndarray) -> float:
    detected = np.nansum(dh, axis=1) > 0
    return detected.sum() / len(detected)

def detection_summary(dh: np.ndarray) -> pd.DataFrame:
    return pd.DataFrame({
        "occasion":       [f"occ{i+1}" for i in range(dh.shape[1])],
        "n_surveyed":     [np.sum(~np.isnan(dh[:, i])) for i in range(dh.shape[1])],
        "n_detections":   [int(np.nansum(dh[:, i])) for i in range(dh.shape[1])],
        "detection_rate": [round(np.nanmean(dh[:, i]), 3) for i in range(dh.shape[1])],
    })

def validate_detection_history(dh: np.ndarray) -> None:
    valid = np.isin(dh[~np.isnan(dh)], [0, 1])
    if not valid.all():
        raise ValueError("Detection history contains values other than 0, 1, or NA.")
    all_na = np.all(np.isnan(dh), axis=1)
    if all_na.any():
        raise ValueError(f"{all_na.sum()} sites have all-NA detection histories. Remove them.")

def main():
    dh_file    = sys.argv[1] if len(sys.argv) > 1 else "data/detection_history.csv"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/occupancy")

    log_step(1, "Validate inputs")
    if not Path(dh_file).exists():
        logger.error(
            "Detection history file not found: %s\n"
            "Probable cause: incorrect path or file not yet generated\n"
            "Check: o argumento detection_history_csv e o working directory\n"
            "Previous skill: data-cleaning",
            dh_file
        )
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    log_step(2, "Load detection history")
    try:
        dh_df = pd.read_csv(dh_file, index_col=0)
        dh = dh_df.values.astype(float)
    except Exception as e:
        logger.error(
            "Unexpected error in load data: %s\n"
            "Probable cause: CSV malformado, valores nao numericos, ou ausencia de rownames\n"
            "Check: structra do arquivo (primeira coluna = site ID, restantes = ocasioes)\n"
            "Previous skill: data-cleaning",
            e
        )
        raise

    logger.info("Sites: %d | Occasions: %d", dh.shape[0], dh.shape[1])

    log_step(3, "Validate detection history structure")
    try:
        validate_detection_history(dh)
        logger.info("Detection history validation passed.")
    except ValueError as e:
        logger.error(
            "Unexpected error in validate_detection_history: %s\n"
            "Probable cause: valores invalidos (nao 0/1/NA) ou sitios com historico todo NA\n"
            "Check: codificacao dos dados (apenas 0, 1, ou NA sao permitidos)\n"
            "Previous skill: data-cleaning",
            e
        )
        raise

    log_step(4, "Compute naive occupancy")
    naive = compute_naive_occ(dh)
    logger.info("Naive occupancy: %.3f (%d/%d sites)", naive, int(naive * dh.shape[0]), dh.shape[0])

    if naive < 0.05:
        logger.warning(
            "Naive occupancy = %.3f is very low (<5%%). "
            "Occupancy models may have poor identifiability with so few detections.",
            naive
        )
    if naive > 0.95:
        logger.warning(
            "Naive occupancy = %.3f is very high (>95%%). "
            "Consider whether species is truly absent from any surveyed sites.",
            naive
        )

    log_step(5, "Compute detection summary per occasion")
    try:
        det_summary = detection_summary(dh)
        det_summary.to_csv(output_dir / "detection_summary.csv", index=False)
        logger.info("Detection summary:\n%s", det_summary.to_string(index=False))

        low_occ = det_summary[det_summary["detection_rate"] < 0.05]
        if not low_occ.empty:
            logger.warning(
                "Occasions with detection rate < 5%%: %s. "
                "Low-effort occasions may reduce model precision.",
                list(low_occ["occasion"])
            )
    except Exception as e:
        logger.error(
            "Unexpected error in detection summary: %s\n"
            "Probable cause: matriz com dimensoes invalidas ou valores inesperados\n"
            "Check: structra do historico de deteccao\n"
            "Previous skill: occupancy-and-detection (data loading)",
            e
        )
        raise

    # For full occupancy modelling, use R (unmarked) or JAGS via pyjags.
    # Example JAGS model call:
    #   import pyjags
    #   model_code = open("scripts/occu_model.jags").read()
    #   model = pyjags.Model(model_code, data={...}, chains=3)
    logger.info("For full occupancy modelling, use scripts/occupancy_analysis.R (unmarked package).")
    logger.info("Outputs written to: %s", output_dir)

if __name__ == "__main__":
    main()
