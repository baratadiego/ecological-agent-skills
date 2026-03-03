"""Process camera trap detection records from CSV output of camtrapR.
Usage: python process_camtrap_data.py <record_table_csv> <output_dir> [species_name]

Reads a record_table.csv produced by camtrapR's recordTable() function.
Computes descriptive statistics per species and camera station.
Generates a detection timeline plot.
Does NOT require camtrapR — works with the CSV output only.

Arguments:
    record_table_csv : path to record_table.csv from camtrapR
    output_dir       : directory for output files
    species_name     : optional; filter to a single species
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "camera-trap-processing"
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

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates


def load_records(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path, parse_dates=["DateTimeOriginal"])
    required = {"Station", "Species", "DateTimeOriginal"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Record table missing required columns: {missing}")
    return df


def species_summary(df: pd.DataFrame) -> pd.DataFrame:
    summary = (
        df.groupby("Species")
        .agg(
            n_events=("Species", "count"),
            n_stations=("Station", "nunique"),
            first_detection=("DateTimeOriginal", "min"),
            last_detection=("DateTimeOriginal", "max"),
        )
        .reset_index()
    )
    summary["rai_per_100_trapnights"] = np.nan  # requires cam_op; computed externally
    return summary


def station_summary(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df.groupby("Station")
        .agg(
            n_events=("Species", "count"),
            n_species=("Species", "nunique"),
            first_detection=("DateTimeOriginal", "min"),
            last_detection=("DateTimeOriginal", "max"),
        )
        .reset_index()
    )


def plot_detection_timeline(df: pd.DataFrame, output_path: Path) -> None:
    """Timeline of detections per species over time."""
    species_list = df["Species"].unique()
    species_codes = {sp: i for i, sp in enumerate(sorted(species_list))}

    fig, ax = plt.subplots(figsize=(12, max(4, len(species_list) * 0.6)))
    for _, row in df.iterrows():
        y = species_codes[row["Species"]]
        ax.plot(row["DateTimeOriginal"], y, "|", color="steelblue",
                markersize=4, alpha=0.5)

    ax.set_yticks(list(species_codes.values()))
    ax.set_yticklabels([s.replace("_", " ") for s in species_codes.keys()],
                       fontsize=8)
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    fig.autofmt_xdate()
    ax.set_xlabel("Date")
    ax.set_title("Camera Trap Detection Timeline")
    ax.grid(axis="x", linestyle="--", alpha=0.4)
    plt.tight_layout()
    fig.savefig(output_path, dpi=120)
    plt.close(fig)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    record_csv = sys.argv[1]
    output_dir = Path(sys.argv[2])
    species_filter = sys.argv[3] if len(sys.argv) >= 4 else None

    # ── Input precondition checks ────────────────────────────────────────────
    if not Path(record_csv).exists():
        logger.error(
            "Input nao encontrado: %s\n  Causa provavel: process_camtrap_data.R nao foi executado ou falhou\n  Skill anterior: camera-trap-processing (process_camtrap_data.R)",
            record_csv,
        )
        sys.exit(1)

    log_decision("species_filter", species_filter,
                 "None = todas as especies; nome especifico = filtro por especie")

    output_dir.mkdir(parents=True, exist_ok=True)

    log_step(1, "Carregando registros da tabela CSV")
    try:
        df = load_records(record_csv)
    except Exception as e:
        logger.error(
            "Falha ao carregar record_table CSV: %s\n  Causa provavel: colunas obrigatorias ausentes ou arquivo corrompido\n  Skill anterior: camera-trap-processing",
            e,
        )
        sys.exit(1)

    logger.info("Total de registros: %d, Especies: %d", len(df), df["Species"].nunique())

    if species_filter:
        log_step(2, f"Filtrando para a especie '{species_filter}'")
        df = df[df["Species"] == species_filter]
        logger.info("Filtrado para '%s': %d registros", species_filter, len(df))
        if len(df) == 0:
            logger.error(
                "Nenhum registro encontrado para a especie '%s'\n  Causa provavel: nome de especie incorreto\n  Skill anterior: camera-trap-processing (process_camtrap_data.R)",
                species_filter,
            )
            sys.exit(1)
    else:
        log_step(2, "Processando todas as especies")

    log_step(3, "Calculando resumo por especie e estacao")
    try:
        sp_sum = species_summary(df)
        st_sum = station_summary(df)
    except Exception as e:
        logger.error("Unexpected error in species/station summary: %s", e)
        raise

    sp_sum.to_csv(output_dir / "species_summary.csv", index=False)
    st_sum.to_csv(output_dir / "station_summary.csv", index=False)
    logger.info("species_summary.csv: %d especies", len(sp_sum))
    logger.info("station_summary.csv: %d estacoes", len(st_sum))

    low_events = sp_sum[sp_sum["n_events"] < 10]["Species"].tolist()
    if low_events:
        logger.warning(
            "Especies com < 10 eventos (apenas RAI; sem estimativa de ocupancia): %s",
            low_events,
        )

    log_step(4, "Gerando grafico de linha do tempo de deteccoes")
    try:
        plot_detection_timeline(df, output_dir / "detection_timeline.png")
        logger.info("detection_timeline.png salvo")
    except Exception as e:
        logger.error("Unexpected error in plot_detection_timeline: %s", e)
        raise

    logger.info("Concluido. Saidas gravadas em: %s", output_dir)
    logger.info("  species_summary.csv: %d especies", len(sp_sum))
    logger.info("  station_summary.csv: %d estacoes", len(st_sum))


if __name__ == "__main__":
    main()
