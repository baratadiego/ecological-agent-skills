# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Batch species detection using BirdNET-Analyzer for passive acoustic monitoring.

Usage:
    python batch_species_detection.py <audio_dir> <output_dir>
        [--confidence 0.7] [--lat -3.0] [--lon -60.0]
        [--date 2024-06-01] [--overlap 0.0] [--rtype csv]

Requires:
    BirdNET-Analyzer installed and available on PATH as `birdnet_analyzer`
    (or configured via BIRDNET_PATH environment variable).

Outputs:
    detections_raw.csv           — all detections from all files
    detections_filtered.csv      — above confidence threshold
    species_list.csv             — unique species with n detections, max conf
    detection_summary.csv        — species × hour detection counts
    daily_detection_plot.png     — species accumulation and hourly bar chart
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "acoustic-monitoring"
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
import subprocess
import csv
import json
import re
from datetime import timedelta
from collections import defaultdict
import argparse


BIRDNET_CMD = os.environ.get("BIRDNET_PATH", "birdnet_analyzer")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Batch BirdNET species detection for PAM recordings"
    )
    parser.add_argument("audio_dir",  help="Directory containing .wav/.flac files")
    parser.add_argument("output_dir", help="Directory for output files")
    parser.add_argument("--confidence", type=float, default=0.7,
                        help="Minimum confidence threshold (default: 0.7)")
    parser.add_argument("--lat", type=float, default=None,
                        help="Recording latitude (improves species filtering)")
    parser.add_argument("--lon", type=float, default=None,
                        help="Recording longitude")
    parser.add_argument("--date", default=None,
                        help="Recording date YYYY-MM-DD (enables seasonal filter)")
    parser.add_argument("--overlap", type=float, default=0.0,
                        help="Segment overlap in seconds (default: 0.0)")
    parser.add_argument("--rtype", default="csv",
                        choices=["csv", "table", "audacity"],
                        help="BirdNET result type (default: csv)")
    parser.add_argument("--min_conf_flag", type=float, default=0.5,
                        help="Minimum confidence for raw output (default: 0.5)")

    # Also support positional fallback for simple invocation
    if len(sys.argv) >= 3 and not sys.argv[2].startswith("--"):
        # Called as: script.py <audio_dir> <output_dir>
        ns = parser.parse_args(sys.argv[1:])
    else:
        ns = parser.parse_args()
    return ns


def discover_audio_files(audio_dir: Path) -> list[Path]:
    """Return all .wav and .flac files in audio_dir (recursive)."""
    files = []
    for ext in ("*.wav", "*.WAV", "*.flac", "*.FLAC"):
        files.extend(audio_dir.rglob(ext))
    return sorted(files)


def parse_timestamp_from_filename(fname: str):
    """Extract datetime from common recorder filename patterns.
    Returns datetime or None.
    """
    patterns = [
        r"(\d{8})[_$T](\d{6})",   # AUDIOMOTH_20240601_050000
        r"(\d{4}-\d{2}-\d{2})T(\d{2}-\d{2}-\d{2})",  # ISO variant
    ]
    for pat in patterns:
        m = re.search(pat, fname)
        if m:
            date_s, time_s = m.group(1), m.group(2)
            date_s = date_s.replace("-", "")
            time_s = time_s.replace("-", "")
            try:
                return datetime.strptime(date_s + time_s, "%Y%m%d%H%M%S")
            except ValueError:
                continue
    return None


def run_birdnet(audio_file: Path, output_dir: Path, args) -> Path | None:
    """Run BirdNET-Analyzer on a single file. Returns path to result file."""
    result_dir = output_dir / "birdnet_raw"
    result_dir.mkdir(parents=True, exist_ok=True)

    result_file = result_dir / (audio_file.stem + f".BirdNET.results.{args.rtype}")

    cmd = [
        BIRDNET_CMD,
        "--i", str(audio_file),
        "--o", str(result_dir),
        "--min_conf", str(args.min_conf_flag),
        "--overlap", str(args.overlap),
        "--rtype", args.rtype,
    ]
    if args.lat is not None and args.lon is not None:
        cmd += ["--lat", str(args.lat), "--lon", str(args.lon)]
    if args.date is not None:
        cmd += ["--week", _date_to_week(args.date)]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if proc.returncode != 0:
            logger.warning("BirdNET failed for %s: %s", audio_file.name, proc.stderr[:200])
            return None
        return result_file if result_file.exists() else None
    except FileNotFoundError:
        logger.error(
            "BirdNET not found. Configure BIRDNET_PATH ou instale birdnet_analyzer\n  Probable cause: BirdNET-Analyzer nao installed or not in PATH\n  Previous skill: [none — external dependency]"
        )
        sys.exit(1)
    except subprocess.TimeoutExpired:
        logger.warning("Timeout ao processar %s", audio_file.name)
        return None


def _date_to_week(date_str: str) -> str:
    """Convert YYYY-MM-DD to BirdNET week number (1-48)."""
    try:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        # BirdNET uses 48 weeks (each ~7.6 days)
        week = min(48, max(1, int((d.timetuple().tm_yday - 1) / 7.625) + 1))
        return str(week)
    except ValueError:
        return "1"


def parse_birdnet_csv(result_file: Path) -> list[dict]:
    """Parse BirdNET CSV output into list of detection dicts."""
    detections = []
    try:
        with open(result_file, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f, delimiter="\t")
            if reader.fieldnames is None:
                return detections
            for row in reader:
                # Normalize column names (BirdNET versions differ)
                det = {
                    "start_s":    float(row.get("Start (s)", row.get("start", 0))),
                    "end_s":      float(row.get("End (s)",   row.get("end",   0))),
                    "species_code": row.get("Label",    row.get("label",  "")).strip(),
                    "common_name":  row.get("Common name", row.get("common_name", "")).strip(),
                    "confidence": float(row.get("Confidence", row.get("confidence", 0))),
                }
                detections.append(det)
    except Exception as e:
        logger.warning("Could not analyse %s: %s", result_file.name, e)
    return detections


def main():
    args = parse_args()
    audio_dir  = Path(args.audio_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # ── Input precondition checks ────────────────────────────────────────────
    if not audio_dir.is_dir():
        logger.error(
            "Input not found: %s\n  Probable cause: incorrect path or directory not mounted\n  Previous skill: [none — initial step]",
            audio_dir,
        )
        sys.exit(1)

    log_decision("confidence", args.confidence,
                 "limiar minimo de confianca para filtrar deteccoes; >= 0.7 recomendado")
    log_decision("lat/lon", f"{args.lat}/{args.lon}",
                 "coordenadas geograficas melhoram o filtro de especies do BirdNET")
    log_decision("overlap", args.overlap,
                 "sobreposicao de segmentos em segundos; 0 = sem sobreposicao")

    log_step(1, "Discovering audio files")
    audio_files = discover_audio_files(audio_dir)
    if not audio_files:
        logger.error(
            "No audio files found em %s\n  Probable cause: empty directory ou unsupported extensions\n  Previous skill: [none]",
            audio_dir,
        )
        sys.exit(1)
    logger.info("Found %d audio files", len(audio_files))
    logger.info("Confidence threshold: %s", args.confidence)

    log_step(2, "Running BirdNET on each audio file")
    all_detections = []

    for i, fpath in enumerate(audio_files, 1):
        logger.info("  [%d/%d] %s", i, len(audio_files), fpath.name)
        file_ts = parse_timestamp_from_filename(fpath.name)
        if file_ts is None:
            logger.warning("Timestamp not extracted from file name: %s", fpath.name)

        try:
            result_file = run_birdnet(fpath, output_dir, args)
        except Exception as e:
            logger.error("Unexpected error in run_birdnet for %s: %s", fpath.name, e)
            raise
        if result_file is None:
            continue

        raw_dets = parse_birdnet_csv(result_file)
        for det in raw_dets:
            det["file"] = fpath.name
            if file_ts is not None:
                abs_time = file_ts + timedelta(seconds=det["start_s"])
                det["datetime"] = abs_time.strftime("%Y-%m-%d %H:%M:%S")
                det["hour"]     = abs_time.hour
                det["date"]     = abs_time.strftime("%Y-%m-%d")
            else:
                det["datetime"] = ""
                det["hour"]     = -1
                det["date"]     = ""
            all_detections.append(det)

    if not all_detections:
        logger.warning(
            "No detections produced. Check a BirdNET installation e os arquivos de audio."
        )
        sys.exit(0)

    logger.info("Total raw detections: %d", len(all_detections))

    log_step(3, "Writing raw and filtered detections")
    # ── Write raw detections ────────────────────────────────────────────────
    fieldnames = ["file", "datetime", "date", "hour",
                  "start_s", "end_s", "species_code", "common_name", "confidence"]
    raw_path = output_dir / "detections_raw.csv"
    try:
        with open(raw_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(all_detections)
        logger.info("Deteccoes brutas: %d -> %s", len(all_detections), raw_path)
    except Exception as e:
        logger.error("Unexpected error writing raw detections: %s", e)
        raise

    # ── Filter by confidence ────────────────────────────────────────────────
    filtered = [d for d in all_detections if d["confidence"] >= args.confidence]
    filt_path = output_dir / "detections_filtered.csv"
    with open(filt_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(filtered)
    logger.info("Deteccoes filtradas (>=%s): %d -> %s", args.confidence, len(filtered), filt_path)

    if len(filtered) == 0:
        logger.warning(
            "No detections apos filtro de confianca %.2f; considere reduzir o limiar",
            args.confidence,
        )

    log_step(4, "Building detected species list")
    # ── Species list ────────────────────────────────────────────────────────
    species_stats = defaultdict(lambda: {"n": 0, "max_conf": 0.0, "dates": set()})
    for d in filtered:
        sp = d["common_name"] or d["species_code"]
        species_stats[sp]["n"] += 1
        species_stats[sp]["max_conf"] = max(species_stats[sp]["max_conf"], d["confidence"])
        if d["date"]:
            species_stats[sp]["dates"].add(d["date"])

    sp_path = output_dir / "species_list.csv"
    with open(sp_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["species", "n_detections", "max_confidence",
                         "n_dates", "confidence_category"])
        for sp, stats in sorted(species_stats.items(), key=lambda x: -x[1]["n"]):
            conf_cat = ("high" if stats["max_conf"] >= 0.9 else
                        "medium" if stats["max_conf"] >= 0.7 else "low")
            writer.writerow([sp, stats["n"], round(stats["max_conf"], 3),
                             len(stats["dates"]), conf_cat])
    logger.info("Especies detectadas: %d -> %s", len(species_stats), sp_path)

    log_step(5, "Generating detection summary by hour")
    # ── Detection summary by hour ────────────────────────────────────────────
    hour_counts = defaultdict(lambda: defaultdict(int))
    for d in filtered:
        if d["hour"] >= 0:
            sp = d["common_name"] or d["species_code"]
            hour_counts[sp][d["hour"]] += 1

    if hour_counts:
        all_hours = list(range(24))
        all_sps   = sorted(hour_counts.keys())
        sum_path  = output_dir / "detection_summary.csv"
        with open(sum_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["species"] + [str(h) for h in all_hours])
            for sp in all_sps:
                writer.writerow([sp] + [hour_counts[sp].get(h, 0) for h in all_hours])
        logger.info("Hourly detection summary -> %s", sum_path)
    else:
        logger.warning(
            "No hourly timestamps available; detection_summary.csv not generated"
        )

    log_step(6, "Computing species accumulation")
    # ── Species accumulation (text) ─────────────────────────────────────────
    seen = set()
    accumulation = []
    for i, d in enumerate(filtered, 1):
        sp = d["common_name"] or d["species_code"]
        seen.add(sp)
        if i % max(1, len(filtered) // 50) == 0 or i == len(filtered):
            accumulation.append({"n_detections": i, "cumulative_species": len(seen)})

    accum_path = output_dir / "species_accumulation.csv"
    with open(accum_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["n_detections", "cumulative_species"])
        writer.writeheader()
        writer.writerows(accumulation)
    logger.info("Species accumulation -> %s", accum_path)

    logger.info("Batch detection completed")


if __name__ == "__main__":
    main()
