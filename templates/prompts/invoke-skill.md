# Prompt Template: Invoke a Single Skill

```
Load skill: <skill-name>
Task: <describe the specific task>

Inputs:
  - <file or data description>
  - <file or data description>

Requirements:
  - <specific requirement or constraint>
  - <specific requirement or constraint>

Output: <list expected output files or formats>
```

## Example

```
Load skill: ecological-data-foundation
Task: Clean and validate mammal occurrence data for the Pantanal.

Inputs:
  - data/raw/mammals_raw.csv  (GBIF download, Darwin Core format)
  - data/spatial/pantanal_boundary.shp  (study area)

Requirements:
  - Use CoordinateCleaner flags: capitals, centroids, zeros, validity
  - Taxonomy: GBIF Backbone 2023
  - Remove records with coordinate uncertainty > 10 km

Output: data/processed/data_clean.csv, data/processed/qa_report.md
```
