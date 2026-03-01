# Example Invocation Prompts — ecological-data-foundation

## Basic Cleaning

```
Load skill: ecological-data-foundation
Task: Clean and validate the occurrence dataset at data/raw/occurrences_raw.csv.
Apply all standard QA checks. The target taxon is mammals. Use GBIF Backbone for taxonomy.
Output results to data/processed/.
```

## Merging Multiple Sources

```
Load skill: ecological-data-foundation
Task: I have three occurrence datasets from different institutions:
  - data/raw/mnrj_mammals.csv (MNRJ herbarium export)
  - data/raw/gbif_download.csv (GBIF Darwin Core)
  - data/raw/fieldwork_2023.xlsx (our field data)
Merge them into a single Darwin Core dataset. Remove duplicates and apply full QA.
Report how many records each source contributed after cleaning.
```

## Targeted Check

```
Load skill: ecological-data-foundation
Task: I already cleaned my data but want to run just the coordinate checks.
File: data/processed/occ_v1.csv. Apply CoordinateCleaner flags and report.
Do NOT modify the file; just produce a flag report.
```

## Schema Validation

```
Load skill: ecological-data-foundation
Task: Validate that data/processed/occ_clean.csv conforms to Darwin Core.
List any fields that are missing, misnamed, or have incorrect data types.
Generate schema.yaml from the current file.
```
