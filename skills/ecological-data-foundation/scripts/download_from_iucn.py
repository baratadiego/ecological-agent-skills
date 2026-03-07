# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""Download species assessment data from the IUCN Red List API v3.

Usage: python download_from_iucn.py <species_name_or_list_csv> <output_dir> [include_range_maps]

Arguments:
    species_name_or_list_csv : Species name (e.g., "Panthera onca") or path to CSV
                               with column 'scientificName'
    output_dir               : Directory for outputs (created if absent)
    include_range_maps       : 'true' or 'false' — download range data if available (default: false)

Requires:
    IUCN_REDLIST_KEY environment variable — obtain at: https://apiv3.iucnredlist.org/

Outputs (per species):
    iucn_status_{species}.csv           — Red List category, criteria, country occurrences
    iucn_habitats_{species}.csv         — suitable habitats
    download_metadata_IUCN_{species}.txt — provenance and citation

Standard output schema (iucn_status CSV):
    species, decimalLatitude, decimalLongitude, eventDate, countryCode,
    basisOfRecord, coordinateUncertaintyInMeters, datasetName, occurrenceID,
    source, download_doi
Extra IUCN columns:
    rl_category, rl_criteria, population_trend, assessment_year
"""

import logging
import os
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


from datetime import date

try:
    import requests
    import pandas as pd
except ImportError as e:
    logger.error(
        "Dependencia ausente: %s\n  Instale com: pip install requests pandas\n  Skill anterior: ecological-data-foundation",
        e,
    )
    sys.exit(1)


# ── Constants ─────────────────────────────────────────────────────────────────
IUCN_API_BASE = "https://apiv3.iucnredlist.org/api/v3"


# ── Helper functions ──────────────────────────────────────────────────────────

def iucn_get(endpoint: str, api_key: str) -> dict:
    """Make an authenticated GET request to the IUCN API."""
    url = f"{IUCN_API_BASE}/{endpoint}?token={api_key}"
    try:
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except requests.RequestException as e:
        logger.error(
            "Falha na requisicao IUCN API '%s': %s\n  Causa provavel: chave invalida ou API indisponivel.\n  Verifique: https://apiv3.iucnredlist.org/\n  Skill anterior: ecological-data-foundation",
            endpoint, e,
        )
        raise


def fetch_assessment(species_name: str, api_key: str) -> dict:
    """Fetch the most recent IUCN assessment for a species."""
    sp_encoded = species_name.replace(" ", "%20")
    return iucn_get(f"species/{sp_encoded}", api_key)


def fetch_country_occurrences(species_name: str, api_key: str) -> list[dict]:
    """Fetch country-level occurrences from IUCN."""
    sp_encoded = species_name.replace(" ", "%20")
    try:
        data = iucn_get(f"species/countries/name/{sp_encoded}", api_key)
        return data.get("result", [])
    except Exception as e:
        logger.warning("Falha ao buscar paises de ocorrencia para '%s': %s", species_name, e)
        return []


def fetch_habitats(species_name: str, api_key: str) -> list[dict]:
    """Fetch suitable habitats for a species."""
    sp_encoded = species_name.replace(" ", "%20")
    try:
        data = iucn_get(f"habitats/species/name/{sp_encoded}", api_key)
        return data.get("result", [])
    except Exception as e:
        logger.warning("Falha ao buscar habitats para '%s': %s", species_name, e)
        return []


def standardise_records(assessment: dict, countries: list[dict],
                         species_name: str) -> "pd.DataFrame":
    """Convert IUCN assessment data to the standard occurrence schema."""
    results = assessment.get("result", [])
    if not results:
        return pd.DataFrame()

    res         = results[0]
    taxon_id    = res.get("taxonid", "")
    category    = res.get("category", "")
    criteria    = res.get("criteria", "")
    pop_trend   = res.get("population_trend", "")
    assess_year = res.get("assessment_date", "")[:4] if res.get("assessment_date") else ""

    if not countries:
        rows = [{
            "species":                       species_name,
            "decimalLatitude":               None,
            "decimalLongitude":              None,
            "eventDate":                     None,
            "countryCode":                   None,
            "basisOfRecord":                 "LITERATURE",
            "coordinateUncertaintyInMeters": None,
            "datasetName":                   "IUCN Red List",
            "occurrenceID":                  f"IUCN:{taxon_id}",
            "source":                        "IUCN",
            "download_doi":                  None,
            "rl_category":                   category,
            "rl_criteria":                   criteria,
            "population_trend":              pop_trend,
            "assessment_year":               assess_year,
        }]
    else:
        rows = []
        for ctry in countries:
            rows.append({
                "species":                       species_name,
                "decimalLatitude":               None,
                "decimalLongitude":              None,
                "eventDate":                     None,
                "countryCode":                   ctry.get("code", ""),
                "basisOfRecord":                 "LITERATURE",
                "coordinateUncertaintyInMeters": None,
                "datasetName":                   "IUCN Red List",
                "occurrenceID":                  f"IUCN:{taxon_id}:{ctry.get('code', '')}",
                "source":                        "IUCN",
                "download_doi":                  None,
                "rl_category":                   category,
                "rl_criteria":                   criteria,
                "population_trend":              pop_trend,
                "assessment_year":               assess_year,
            })

    return pd.DataFrame(rows)


def save_metadata(output_dir: Path, species_name: str, taxon_id,
                  category: str, assess_year: str) -> None:
    safe_name = species_name.replace(" ", "_")
    today = date.today().isoformat()
    year  = date.today().year
    month = f"{date.today().month:02d}"
    lines = [
        f"Species: {species_name}",
        f"IUCN Taxon ID: {taxon_id}",
        f"Source: IUCN Red List (https://www.iucnredlist.org)",
        f"API version: v3 (https://apiv3.iucnredlist.org)",
        f"Red List category: {category}",
        f"Assessment year: {assess_year}",
        f"Download date: {today}",
        (f"Citation: IUCN {year}. The IUCN Red List of Threatened Species. "
         f"Version {year}-{month}. https://www.iucnredlist.org Accessed on {today}."),
        "License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
    ]
    meta_path = output_dir / f"download_metadata_IUCN_{safe_name}.txt"
    try:
        meta_path.write_text("\n".join(lines), encoding="utf-8")
        logger.info("Metadados gravados: %s", meta_path)
    except OSError as e:
        logger.error(
            "Falha ao gravar metadados: %s\n  Skill anterior: ecological-data-foundation", e,
        )
        raise


# ── Main download logic ────────────────────────────────────────────────────────

def download_species(species_name: str, output_dir: Path, api_key: str) -> None:
    logger.info("--- Iniciando download IUCN: %s ---", species_name)
    safe_name = species_name.replace(" ", "_")

    log_step(1, f"Buscar avaliacao IUCN para '{species_name}'")
    assessment = fetch_assessment(species_name, api_key)

    results = assessment.get("result", [])
    if not results:
        logger.warning("Nenhum resultado IUCN para '%s'. Especie pode nao estar avaliada.", species_name)
        return

    res         = results[0]
    taxon_id    = res.get("taxonid", "")
    category    = res.get("category", "")
    criteria    = res.get("criteria", "")
    pop_trend   = res.get("population_trend", "")
    assess_date = res.get("assessment_date", "")
    assess_year = assess_date[:4] if assess_date else ""

    logger.info("Categoria IUCN: %s | Criterios: %s | Tendencia: %s | Ano: %s",
                category, criteria, pop_trend, assess_year)

    if category in ("CR", "EN"):
        logger.warning(
            "Especie '%s' e %s — dados de distribuicao podem ser restritos por razoes de seguranca.",
            species_name, category,
        )

    log_step(2, f"Buscar ocorrencias por pais para '{species_name}'")
    countries = fetch_country_occurrences(species_name, api_key)
    logger.info("Paises de ocorrencia: %d", len(countries))

    log_step(3, f"Buscar habitats adequados para '{species_name}'")
    habitats = fetch_habitats(species_name, api_key)
    logger.info("Habitats identificados: %d", len(habitats))

    log_step(4, "Padronizar registros para schema de saida")
    df = standardise_records(assessment, countries, species_name)
    logger.info("Registros no schema padrao: %d", len(df))

    log_step(5, "Gravar CSV de status IUCN")
    csv_path = output_dir / f"iucn_status_{safe_name}.csv"
    try:
        df.to_csv(csv_path, index=False)
        logger.info("Gravado: %s", csv_path)
    except OSError as e:
        logger.error(
            "Falha ao gravar CSV IUCN: %s\n  Skill anterior: ecological-data-foundation", e,
        )
        raise

    if habitats:
        hab_df       = pd.DataFrame(habitats)
        hab_df["species"] = species_name
        hab_path     = output_dir / f"iucn_habitats_{safe_name}.csv"
        try:
            hab_df.to_csv(hab_path, index=False)
            logger.info("Habitats gravados: %s", hab_path)
        except OSError as e:
            logger.warning("Falha ao gravar habitats: %s", e)

    log_step(6, "Gravar metadados")
    save_metadata(output_dir, species_name, taxon_id, category, assess_year)


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    logger.info("Script: download_from_iucn.py | Skill: %s", SKILL_NAME)

    # Check API key
    api_key = os.environ.get("IUCN_REDLIST_KEY", "")
    if not api_key:
        logger.error(
            "Variavel IUCN_REDLIST_KEY nao definida.\n  Causa provavel: chave nao configurada no ambiente.\n  Verifique: export IUCN_REDLIST_KEY=your_key (Linux/Mac) ou setx IUCN_REDLIST_KEY your_key (Windows)\n  Skill anterior: ecological-data-foundation",
        )
        sys.exit(1)
    logger.info("Chave IUCN detectada (primeiros 4 chars): %s...", api_key[:4])
    log_decision("api_key", "***", "lida de IUCN_REDLIST_KEY; nunca exibida em logs")

    argv = sys.argv[1:]

    if len(argv) < 2:
        species_input = "Panthera onca"
        output_dir    = Path("output/iucn")
        logger.warning("Menos de 2 argumentos fornecidos. Usando valores padrao para teste.")
    else:
        species_input = argv[0]
        output_dir    = Path(argv[1])

    logger.info("Species input  : %s", species_input)
    logger.info("Output dir     : %s", output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    # Build species list
    log_step(0, "Construir lista de especies")
    if species_input.endswith(".csv") and Path(species_input).exists():
        try:
            df_sp = pd.read_csv(species_input)
            if "scientificName" not in df_sp.columns:
                logger.error(
                    "Coluna 'scientificName' nao encontrada em: %s\n  Skill anterior: ecological-data-foundation",
                    species_input,
                )
                sys.exit(1)
            species_list = df_sp["scientificName"].dropna().unique().tolist()
            logger.info("Modo batch: %d especies carregadas", len(species_list))
            log_decision("mode", "batch", "CSV valido com coluna scientificName")
        except Exception as e:
            logger.error(
                "Falha ao ler lista de especies: %s\n  Skill anterior: ecological-data-foundation", e,
            )
            sys.exit(1)
    else:
        species_list = [species_input.strip()]
        logger.info("Modo especie unica: %s", species_list[0])
        log_decision("mode", "single_species", "argumento nao e arquivo CSV")

    for sp in species_list:
        try:
            download_species(sp, output_dir, api_key)
        except FileNotFoundError as e:
            logger.error(
                "Arquivo de entrada nao encontrado: %s\n  Skill anterior: ecological-data-foundation", e,
            )
        except Exception as e:
            logger.error(
                "Falha ao baixar '%s' do IUCN: %s\n  Causa provavel: chave invalida, especie nao avaliada ou API indisponivel.\n  Skill anterior: ecological-data-foundation",
                sp, e,
            )

    logger.info("Todos os downloads IUCN concluidos. Verifique: %s", output_dir)


if __name__ == "__main__":
    main()
