# QA Checklist — Ecological Data Foundation

Use this checklist for every new dataset before proceeding to analysis.

## 1. File and Ingest

- [ ] Source file preserved in `data/raw/` (never overwrite)
- [ ] File encoding confirmed (UTF-8 preferred)
- [ ] Delimiter and quoting confirmed
- [ ] Row count matches expected (check for truncation)
- [ ] Column names documented

## 2. Schema and Types

- [ ] All fields mapped to Darwin Core (or equivalent standard)
- [ ] Dates parsed as ISO-8601 strings
- [ ] Coordinates as decimal degrees (float)
- [ ] Country codes as ISO 3166-1 alpha-2
- [ ] Categorical fields enumerated and valid entries listed

## 3. Duplicates

- [ ] Exact duplicates identified and counted
- [ ] Spatial-temporal near-duplicates checked (same species, same coords ± X km, same date ± Y days)
- [ ] Resolution strategy documented and applied

## 4. Coordinates

- [ ] Latitude in range [-90, 90]
- [ ] Longitude in range [-180, 180]
- [ ] Zero coordinates (0, 0) flagged
- [ ] Country centroid coordinates flagged
- [ ] Capital city coordinates flagged
- [ ] Coordinates fall within stated country/region polygon
- [ ] Coordinate uncertainty recorded where available

## 5. Taxonomy

- [ ] Species names checked against reference backbone (GBIF / Catalogue of Life)
- [ ] Synonyms resolved to accepted name
- [ ] Misspellings corrected (with original preserved)
- [ ] Higher-rank-only identifications flagged
- [ ] Hybrids and cultivars handled according to study scope

## 6. Temporal

- [ ] No dates in the future
- [ ] No dates before plausible survey era for the taxon
- [ ] Temporal precision meets study requirements
- [ ] Records with year-only precision flagged if day-level is needed

## 7. Attribute Ranges

- [ ] Numeric fields checked for biologically impossible values
- [ ] Missing value rate per field computed and documented
- [ ] Fields exceeding missing value threshold (default 20%) flagged for decision

## 8. Outputs

- [ ] `data_clean.csv` written with `QA_status` column
- [ ] `flagged_records.csv` written with reason codes
- [ ] `qa_report.md` summarises issue counts and resolutions
- [ ] `schema.yaml` documents all field definitions
- [ ] `metadata.xml` (EML or Dublin Core) completed

## QA Status Codes

| Code | Meaning |
|------|---------|
| `OK` | Record passed all checks |
| `COORD_CENTROID` | Coordinates at country/institution centroid |
| `COORD_ZERO` | Coordinates are (0, 0) |
| `COORD_OUT_OF_RANGE` | lat or lon outside valid bounds |
| `COORD_OUTSIDE_COUNTRY` | Point falls outside declared country polygon |
| `DATE_FUTURE` | Event date is in the future |
| `DATE_UNLIKELY` | Event date before plausible survey era |
| `DUPLICATE_EXACT` | Identical to another record |
| `DUPLICATE_SPATIOTEMPORAL` | Near-duplicate (spatial-temporal proximity) |
| `TAXON_SYNONYM` | Name is a synonym; resolved to accepted name |
| `TAXON_MISSPELLING` | Misspelling detected and corrected |
| `TAXON_HIGH_RANK` | Identified only to genus or higher |
| `MISSING_COORDS` | No coordinate information |
| `REMOVED` | Record excluded from clean dataset |
