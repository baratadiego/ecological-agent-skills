"""Download occurrence records from GBIF via pygbif.

Usage: python download_from_gbif.py <species_name_or_list_csv> <output_dir> [country_code] [year_from] [year_to]

Arguments:
    species_name_or_list_csv : Species name (e.g., "Panthera onca") or path to CSV
                               with column 'scientificName'
    output_dir               : Directory for outputs (created if absent)
    country_code             : ISO 3166-1 alpha-2 code to restrict records (optional)
    year_from                : Minimum occurrence year (default: 1950)
    year_to                  : Maximum occurrence year (default: current year)

Outputs (per species):
    occurrences_raw_GBIF_{species}_{date}.csv — occurrence records
    download_metadata_{species}.txt            — download info including GBIF DOI
"""

import sys
import os
import time
import csv
from pathlib import Path
from datetime import date, datetime

try:
    import pandas as pd
    import pygbif.occurrences as occ
    import pygbif.species as spp
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}")
    print("Install with: pip install pygbif pandas")
    sys.exit(1)


# ── Constants ─────────────────────────────────────────────────────────────────
BASIS_OF_RECORD = [
    "HUMAN_OBSERVATION",
    "MACHINE_OBSERVATION",
    "PRESERVED_SPECIMEN",
]
COORD_UNCERTAINTY_MAX = 10000  # metres
POLL_INTERVAL = 30             # seconds between status checks for async downloads
SEARCH_LIMIT = 100000          # max records via occ.search (GBIF API cap)
LARGE_DATASET_THRESHOLD = 50000


# ── Helper functions ──────────────────────────────────────────────────────────

def get_taxon_key(species_name: str) -> int | None:
    """Look up GBIF backbone taxon key for a species name."""
    result = spp.name_backbone(name=species_name, rank="SPECIES")
    key = result.get("usageKey")
    if key is None:
        print(f"  WARNING: No GBIF taxon key found for '{species_name}'")
    return key


def count_records(taxon_key: int) -> int:
    """Estimate number of records for a taxon (unfiltered, approximate)."""
    return occ.count(taxonKey=taxon_key, hasCoordinate=True,
                     occurrenceStatus="PRESENT")


def search_download(taxon_key: int, country_code: str | None,
                    year_from: int, year_to: int) -> tuple[list[dict], str]:
    """Download via occ.search (< LARGE_DATASET_THRESHOLD records). No DOI."""
    filters = dict(
        taxonKey=taxon_key,
        hasCoordinate=True,
        occurrenceStatus="PRESENT",
        basisOfRecord=",".join(BASIS_OF_RECORD),
        coordinateUncertaintyInMeters=f"0,{COORD_UNCERTAINTY_MAX}",
        year=f"{year_from},{year_to}",
        limit=SEARCH_LIMIT,
        fields="minimal",
    )
    if country_code:
        filters["country"] = country_code

    result = occ.search(**filters)
    records = result.get("results", [])
    return records, None  # None = no DOI available


def async_download(taxon_key: int, country_code: str | None,
                   year_from: int, year_to: int) -> tuple[list[dict], str]:
    """Download via occ.download (reproducible, DOI generated). For large datasets."""
    predicates = [
        f"taxonKey = {taxon_key}",
        "hasCoordinate = TRUE",
        "occurrenceStatus = PRESENT",
        f"basisOfRecord in {','.join(BASIS_OF_RECORD)}",
        f"coordinateUncertaintyInMeters <= {COORD_UNCERTAINTY_MAX}",
        f"year >= {year_from}",
        f"year <= {year_to}",
    ]
    if country_code:
        predicates.append(f"country = {country_code}")

    print("  Initiating async download (DOI will be generated)...")
    dl_result = occ.download(predicates)
    dl_key = dl_result[0]
    print(f"  Download key: {dl_key}")
    print("  Waiting for GBIF to prepare download...")

    # Poll until complete
    while True:
        meta = occ.download_meta(dl_key)
        status = meta.get("status", "UNKNOWN")
        print(f"  Status: {status}")
        if status == "SUCCEEDED":
            break
        elif status in ("FAILED", "KILLED", "CANCELLED"):
            raise RuntimeError(f"GBIF download failed with status: {status}")
        time.sleep(POLL_INTERVAL)

    doi = meta.get("doi", "")
    print(f"  DOI: {doi}")

    # Get download URL and fetch via pandas
    download_url = meta.get("downloadLink", "")
    print(f"  Fetching data from: {download_url}")
    df = pd.read_csv(download_url, sep="\t", on_bad_lines="skip", low_memory=False)
    records = df.to_dict("records")
    return records, doi


def save_metadata(output_dir: Path, species_name: str, taxon_key: int,
                  dl_key: str | None, doi: str | None,
                  n_records: int, country_code: str | None,
                  year_from: int, year_to: int) -> None:
    """Write download_metadata.txt with citation information."""
    safe_name = species_name.replace(" ", "_")
    meta_path = output_dir / f"download_metadata_{safe_name}.txt"

    today = date.today().isoformat()
    year  = date.today().year

    if doi:
        citation = (f"GBIF.org ({year}) GBIF Occurrence Download. "
                    f"https://doi.org/{doi} Accessed on {today}")
    else:
        citation = ("occ.search used — no citable DOI. "
                    "Re-run with async download for publication.")

    lines = [
        f"Species: {species_name}",
        f"GBIF taxon key: {taxon_key}",
        f"Download key: {dl_key or 'N/A (occ.search used)'}",
        f"DOI: {doi or 'NOT AVAILABLE'}",
        f"Citation: {citation}",
        f"Download date: {today}",
        f"n_records: {n_records}",
        f"year_from: {year_from}",
        f"year_to: {year_to}",
        f"country_filter: {country_code or 'none'}",
        f"basisOfRecord: {', '.join(BASIS_OF_RECORD)}",
        f"coordinateUncertainty_max_m: {COORD_UNCERTAINTY_MAX}",
    ]

    meta_path.write_text("\n".join(lines))
    print(f"  Saved metadata: {meta_path}")


# ── Main download logic (single species) ──────────────────────────────────────

def download_species(species_name: str, output_dir: Path,
                     country_code: str | None,
                     year_from: int, year_to: int) -> None:
    print(f"\n--- Downloading: {species_name} ---")
    today_str = date.today().strftime("%Y%m%d")
    safe_name = species_name.replace(" ", "_")

    # Lookup taxon key
    taxon_key = get_taxon_key(species_name)
    if taxon_key is None:
        print(f"  Skipping '{species_name}' — no GBIF taxon key found.")
        return

    print(f"  GBIF taxon key: {taxon_key}")

    # Estimate record count to decide download method
    approx_n = count_records(taxon_key)
    print(f"  Approximate record count (unfiltered): {approx_n}")

    if approx_n > LARGE_DATASET_THRESHOLD:
        records, doi = async_download(taxon_key, country_code, year_from, year_to)
        dl_key = "see metadata"
    else:
        records, doi = search_download(taxon_key, country_code, year_from, year_to)
        dl_key = None

    n_records = len(records)
    print(f"  Records retrieved: {n_records}")

    if n_records < 30:
        print(f"  WARNING: insufficient records for reliable SDM (n = {n_records})")
        print("    Consider: (1) relaxing filters, (2) expanding geographic scope,")
        print("              (3) supplementing with other databases (VertNet, iNaturalist).")

    # Save occurrence CSV
    csv_path = output_dir / f"occurrences_raw_GBIF_{safe_name}_{today_str}.csv"
    if records:
        df = pd.DataFrame(records)
        df.to_csv(csv_path, index=False)
        print(f"  Saved: {csv_path}")
    else:
        print(f"  No records to save for '{species_name}'.")

    # Save metadata
    save_metadata(output_dir, species_name, taxon_key, dl_key, doi,
                  n_records, country_code, year_from, year_to)


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    argv = sys.argv[1:]

    if len(argv) < 2:
        species_input = "Panthera onca"
        output_dir    = Path("output/gbif")
        country_code  = None
        year_from     = 1950
        year_to       = date.today().year
    else:
        species_input = argv[0]
        output_dir    = Path(argv[1])
        country_code  = argv[2] if len(argv) >= 3 and argv[2] else None
        year_from     = int(argv[3]) if len(argv) >= 4 else 1950
        year_to       = int(argv[4]) if len(argv) >= 5 else date.today().year

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output directory: {output_dir}")

    # Build species list
    if species_input.endswith(".csv") and Path(species_input).exists():
        df_species   = pd.read_csv(species_input)
        species_list = df_species["scientificName"].dropna().unique().tolist()
        print(f"Batch mode: {len(species_list)} species loaded from {species_input}")
    else:
        species_list = [species_input.strip()]
        print(f"Single species mode: {species_list[0]}")

    # Download each species
    for sp in species_list:
        try:
            download_species(sp, output_dir, country_code, year_from, year_to)
        except Exception as e:
            print(f"  ERROR downloading '{sp}': {e}")

    print(f"\nAll downloads complete. Check {output_dir} for outputs.")


if __name__ == "__main__":
    main()
