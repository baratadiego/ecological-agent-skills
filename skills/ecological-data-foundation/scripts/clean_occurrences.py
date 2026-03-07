#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
clean_occurrences.py
Standard occurrence cleaning pipeline using Python.
Usage: python clean_occurrences.py <input_csv> <output_dir>
Requires: pandas, geopandas, shapely
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "ecological-data-foundation"
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


import os
import hashlib

import pandas as pd
import numpy as np


def load(path: str) -> pd.DataFrame:
    try:
        df = pd.read_csv(path, low_memory=False)
        logger.info("Carregadas %d linhas, %d colunas de %s", len(df), len(df.columns), path)
        return df
    except FileNotFoundError:
        logger.error(
            "Input nao encontrado: %s\n  Causa provavel: arquivo nao gerado pelo passo anterior.\n  Verifique a saida de: ecological-data-foundation (download_from_gbif)\n  Skill anterior: ecological-data-foundation",
            path,
        )
        sys.exit(1)
    except Exception as e:
        logger.error(
            "Falha ao ler CSV de entrada '%s': %s\n  Causa provavel: arquivo corrompido ou formato invalido.\n  Skill anterior: ecological-data-foundation",
            path, e,
        )
        sys.exit(1)


def check_required_cols(df: pd.DataFrame, required: list) -> None:
    missing = [c for c in required if c not in df.columns]
    if missing:
        logger.error(
            "Colunas obrigatorias ausentes: %s\n  Causa provavel: CSV gerado por fonte diferente ou schema alterado.\n  Skill anterior: ecological-data-foundation",
            missing,
        )
        raise ValueError(f"Missing required columns: {missing}")
    logger.info("Todas as colunas obrigatorias presentes: %s", required)


def flag_coordinate_issues(df: pd.DataFrame,
                           lat_col="decimalLatitude",
                           lon_col="decimalLongitude") -> pd.DataFrame:
    df = df.copy()
    df["QA_status"] = "OK"
    lat = pd.to_numeric(df[lat_col], errors="coerce")
    lon = pd.to_numeric(df[lon_col], errors="coerce")

    # Invalid range
    mask_range = (lat.abs() > 90) | (lon.abs() > 180)
    df.loc[mask_range, "QA_status"] = "COORD_OUT_OF_RANGE"

    # Zero coordinates
    mask_zero = (lat == 0) & (lon == 0)
    df.loc[mask_zero, "QA_status"] = "COORD_ZERO"

    # Missing coords
    mask_na = lat.isna() | lon.isna()
    df.loc[mask_na, "QA_status"] = "MISSING_COORDS"

    n_range = int(mask_range.sum())
    n_zero  = int(mask_zero.sum())
    n_na    = int(mask_na.sum())

    logger.info(
        "Problemas de coordenadas — Fora do intervalo: %d | Zero: %d | Ausentes: %d",
        n_range, n_zero, n_na,
    )
    if n_range > 0:
        logger.warning("Registros com coordenadas fora do intervalo valido: %d", n_range)
    if n_zero > 0:
        logger.warning("Registros com coordenadas zero (0,0): %d — possivelmente erros de digitacao", n_zero)
    if n_na > 0:
        logger.warning("Registros sem coordenadas (NA): %d", n_na)
    return df


def remove_exact_duplicates(df: pd.DataFrame,
                             cols=("scientificName","decimalLatitude","decimalLongitude","eventDate")
                             ) -> pd.DataFrame:
    cols_present = [c for c in cols if c in df.columns]
    log_decision(
        "dedup_cols",
        cols_present,
        "combinacao padrao para identificar duplicatas espaciotemporais",
    )
    n_before = len(df)
    df = df.drop_duplicates(subset=cols_present, keep="first")
    n_removed = n_before - len(df)
    if n_removed > 0:
        logger.warning("Duplicatas exatas removidas: %d", n_removed)
    else:
        logger.info("Nenhuma duplicata exata encontrada.")
    return df


def check_temporal(df: pd.DataFrame, date_col="eventDate") -> pd.DataFrame:
    if date_col not in df.columns:
        logger.warning("Coluna '%s' ausente — verificacao temporal pulada.", date_col)
        return df
    dates = pd.to_datetime(df[date_col], errors="coerce")
    future = dates > pd.Timestamp.now()
    n_future = int(future.sum())
    df.loc[future & (df["QA_status"] == "OK"), "QA_status"] = "DATE_FUTURE"
    if n_future > 0:
        logger.warning("Registros com datas futuras sinalizados: %d", n_future)
    else:
        logger.info("Nenhum registro com data futura encontrado.")
    return df


def write_outputs(df: pd.DataFrame, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    clean   = df[df["QA_status"] == "OK"]
    flagged = df[df["QA_status"] != "OK"]

    try:
        clean.to_csv(output_dir / "data_clean.csv", index=False)
        logger.info("Gravado: %s", output_dir / "data_clean.csv")
        flagged.to_csv(output_dir / "flagged_records.csv", index=False)
        logger.info("Gravado: %s", output_dir / "flagged_records.csv")
    except OSError as e:
        logger.error(
            "Falha ao gravar arquivos de saida em '%s': %s\n  Causa provavel: sem permissao de escrita no diretorio.\n  Skill anterior: ecological-data-foundation",
            output_dir, e,
        )
        raise

    # QA report
    flag_counts = flagged["QA_status"].value_counts().to_dict()
    lines = [
        "# QA Report — Occurrence Cleaning",
        f"- Raw records: {len(df):,}",
        f"- Clean records: {len(clean):,}",
        f"- Flagged records: {len(flagged):,}",
        "",
        "## Flag Counts",
    ] + [f"- `{k}`: {v}" for k, v in flag_counts.items()]

    try:
        (output_dir / "qa_report.md").write_text("\n".join(lines))
        logger.info("Gravado: %s", output_dir / "qa_report.md")
    except OSError as e:
        logger.error(
            "Falha ao gravar relatorio QA: %s\n  Causa provavel: sem permissao de escrita.\n  Skill anterior: ecological-data-foundation",
            e,
        )
        raise

    if len(clean) < 30:
        logger.warning(
            "Apenas %d registros limpos apos todas as filtragens. SDMs requerem >= 30 registros confiaveis.",
            len(clean),
        )

    logger.info("Concluido. Limpos: %d | Sinalizados: %d", len(clean), len(flagged))
    logger.info("Saidas gravadas em: %s", output_dir)


def main():
    logger.info("Script: clean_occurrences.py | Skill: %s", SKILL_NAME)

    input_file = sys.argv[1] if len(sys.argv) > 1 else "data/raw/occurrences.csv"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("data/processed")

    logger.info("Input file : %s", input_file)
    logger.info("Output dir : %s", output_dir)

    # Input precondition check
    if not Path(input_file).exists():
        logger.error(
            "Input nao encontrado: %s\n  Causa provavel: arquivo nao gerado pelo passo anterior.\n  Verifique a saida de: ecological-data-foundation (download_from_gbif)\n  Skill anterior: ecological-data-foundation",
            input_file,
        )
        sys.exit(1)

    log_decision("input_file", input_file, "caminho passado como argv[1] ou padrao")
    log_decision("output_dir", str(output_dir), "caminho passado como argv[2] ou padrao")

    log_step(1, "Carregar dados brutos de ocorrencias")
    df = load(input_file)

    if len(df) == 0:
        logger.warning("Arquivo de entrada nao contem registros: %s", input_file)

    log_step(2, "Verificar colunas obrigatorias")
    try:
        check_required_cols(df, ["decimalLatitude", "decimalLongitude"])
    except ValueError as e:
        logger.error("Verificacao de colunas falhou: %s", e)
        sys.exit(1)

    log_step(3, "Sinalizar problemas de coordenadas")
    log_decision(
        "cc_tests",
        "out_of_range,zero,missing",
        "verificacoes basicas de qualidade de coordenadas sem dependencias externas",
    )
    try:
        df = flag_coordinate_issues(df)
    except Exception as e:
        logger.error(
            "Falha na sinalizacao de coordenadas: %s\n  Causa provavel: colunas de coordenadas com tipos inesperados.\n  Skill anterior: ecological-data-foundation",
            e,
        )
        raise

    log_step(4, "Remover duplicatas exatas")
    try:
        df = remove_exact_duplicates(df)
    except Exception as e:
        logger.error(
            "Falha ao remover duplicatas: %s\n  Causa provavel: colunas de deduplicacao ausentes ou mal tipadas.\n  Skill anterior: ecological-data-foundation",
            e,
        )
        raise

    log_step(5, "Verificar datas futuras")
    try:
        df = check_temporal(df)
    except Exception as e:
        logger.error(
            "Falha na verificacao temporal: %s\n  Causa provavel: coluna eventDate com formato inesperado.\n  Skill anterior: ecological-data-foundation",
            e,
        )
        raise

    log_step(6, "Escrever arquivos de saida e relatorio QA")
    write_outputs(df, output_dir)


if __name__ == "__main__":
    main()
