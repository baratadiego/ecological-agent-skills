# Prompt Template: Invoke a Workflow

```
Run workflow: <workflow-name>

Species / System: <target species or ecological system>
Study area: <geographic scope>
Temporal scope: <date range or time points>

Inputs:
  - <primary data file>
  - <spatial layer>
  - <additional data>

Key parameters:
  - <parameter name>: <value>
  - <parameter name>: <value>

Output directory: <path>
Report format: <markdown / PDF / DOCX>
```

## Example

```
Run workflow: run-sdm-study

Species: Giant anteater (Myrmecophaga tridactyla)
Study area: Cerrado biome + 200 km buffer
Temporal scope: Current (WorldClim 1970–2000) + SSP2-4.5 2050

Inputs:
  - data/processed/data_clean.csv   (n = 412 occurrences after cleaning)
  - data/predictors/cerrado_stack.tif  (bio1, bio4, bio12, bio15, NDVI, slope)
  - data/spatial/cerrado_buffer.shp

Key parameters:
  - Spatial thinning: 10 km
  - CV blocks: 5, size 400 km
  - Algorithms: MaxEnt, BRT, Random Forest
  - Threshold: MaxTSS

Output directory: outputs/anteater_sdm/
Report format: markdown
```
