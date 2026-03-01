# Skill: ecological-data-foundation

**Domain:** Data ingestion · QA · Schema · Metadata  
**Phase:** 1 — Foundation  
**Used by:** All workflows

---

## Purpose

This skill guides the agent through the first mandatory step of any quantitative ecology project: getting raw data into a clean, well-documented, analysis-ready state. It covers ingestion of heterogeneous sources, structural validation, duplicate and outlier detection, schema standardisation, and metadata generation.

---

## When to Invoke

- A new dataset arrives (CSV, XLSX, GDB, Shapefile, database export, API pull)
- Before any spatial operation, statistical test, or model fitting
- When the user asks to "clean", "validate", "check", or "prepare" ecological data
- When merging datasets from different sources or institutions

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Raw occurrence or survey data | CSV, XLSX, TSV, GDB | Yes |
| Data dictionary or field protocol | PDF, DOCX, TXT | Recommended |
| Environmental layers (if applicable) | GeoTIFF, NetCDF | Optional |
| Existing metadata record | EML, JSON, YAML | Optional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `data_clean.csv` | Validated, deduplicated, standardised dataset |
| `qa_report.md` | Summary of issues found and actions taken |
| `schema.yaml` | Field definitions, types, valid ranges, units |
| `metadata.xml` | EML or Dublin Core metadata record |
| `flagged_records.csv` | Records removed or flagged, with reason codes |

---

## Steps

### 1. Ingest and Inspect
- Load all source files; report file sizes, row counts, column names, and data types
- Identify encoding issues, BOM characters, delimiter inconsistencies
- Document source provenance (institution, date, version, license)

### 2. Schema Standardisation
- Map field names to a canonical schema (Darwin Core preferred for biodiversity)
- Enforce consistent data types (dates as ISO-8601, coordinates as decimal degrees WGS84)
- Flag or convert non-standard units

### 3. Duplicate Detection
- Identify exact duplicates (all fields identical)
- Identify spatial-temporal near-duplicates (same species, same coordinates, same date ± N days)
- Document resolution strategy (keep first, keep most complete, remove all)

### 4. Coordinate and Spatial QA
- Check coordinate ranges (latitude: −90 to 90; longitude: −180 to 180)
- Flag records with coordinates at country centroids, capital cities, or institution headquarters (likely georeferencing errors)
- Flag records with zero coordinates (0,0)
- Validate records fall within the stated country/region polygon

### 5. Taxonomic QA
- Check species names against a reference taxonomy (GBIF Backbone, Catalogue of Life)
- Flag synonyms, misspellings, and higher-rank-only identifications
- Resolve to accepted name + authorship

### 6. Temporal QA
- Check for dates in the future or before plausible survey era
- Flag records with only year-level precision when finer precision is needed

### 7. Attribute QA
- Check numeric fields for out-of-range values (e.g., abundance < 0, DBH > 500 cm)
- Check categorical fields for invalid entries
- Assess missing value rates per field; flag fields above threshold (default 20%)

### 8. Generate Outputs
- Write `data_clean.csv` with action codes in an appended `QA_status` column
- Write `qa_report.md` summarising each issue category, count, and resolution
- Write `schema.yaml` with field definitions
- Write `metadata.xml` in EML format

---

## Key Decisions to Document

- Duplicate resolution strategy
- Coordinate uncertainty threshold for exclusion
- Temporal precision requirement
- Missing value threshold per field
- Taxonomy backbone version used

---

## Tools and Libraries

**R:** `dplyr`, `readr`, `janitor`, `CoordinateCleaner`, `taxize`, `EML`  
**Python:** `pandas`, `pyjanitor`, `geopy`, `pycountry`, `dwca-reader`  
**CLI:** `csvkit`, `miller (mlr)`

---

## Resources

- `resources/darwin-core-glossary.md` — Darwin Core field reference
- `resources/qa-checklist.md` — printable QA checklist
- `resources/coordinate-cleaning-flags.md` — flag code reference
- `examples/` — example prompt invocations

---

## Notes

- Always preserve the original raw file; never overwrite it
- Record the exact software versions used for reproducibility
- Large raster datasets should be handled by the `geoprocessing-for-ecology` skill after this step
