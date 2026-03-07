#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
generate_file_manifest.py
Generate SHA256 checksums for all files in a directory and write a manifest.
Usage: python generate_file_manifest.py <directory> [output_file]
"""
import logging
import sys
import hashlib
from datetime import datetime
from pathlib import Path

SKILL_NAME = "reproducible-ecology-pipeline"
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


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    target_dir  = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("outputs")
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("logs/file_manifest.md")
    output_file.parent.mkdir(parents=True, exist_ok=True)

    log_decision("target_dir", str(target_dir),
                 "Directory to scan for files and compute checksums")
    log_decision("output_file", str(output_file),
                 "Markdown manifest output path")

    if not target_dir.exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: geoprocessing-for-ecology",
            target_dir
        )
        sys.exit(1)

    try:
        log_step(1, "Discovering files in target directory")
        files = sorted(f for f in target_dir.rglob("*") if f.is_file())
        logger.info("Files found: %d in %s", len(files), target_dir)
        if len(files) == 0:
            logger.warning(
                "No files found in %s. The directory may be empty or outputs not yet produced.",
                target_dir
            )

        log_step(2, "Computing SHA256 checksums and building manifest")
        lines = [
            "# File Manifest",
            f"Directory: `{target_dir}`",
            f"Files: {len(files)}",
            "",
            "| File | Size (KB) | SHA256 |",
            "|------|----------|--------|",
        ]
        for f in files:
            try:
                size_kb = round(f.stat().st_size / 1024, 2)
                checksum = sha256(f)
                rel = f.relative_to(target_dir)
                lines.append(f"| `{rel}` | {size_kb} | `{checksum[:16]}...` |")
                logger.info("  Checksummed: %s (%s KB)", rel, size_kb)
            except (OSError, PermissionError) as e:
                logger.warning("Could not process file %s: %s", f, e)

        log_step(3, "Writing manifest file")
        output_file.write_text("\n".join(lines))
        logger.info("Manifest written: %s (%d files)", output_file, len(files))

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: geoprocessing-for-ecology\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in generate_file_manifest: %s", e)
        raise

if __name__ == "__main__":
    main()
