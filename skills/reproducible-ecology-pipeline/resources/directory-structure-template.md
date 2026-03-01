# Recommended Project Directory Structure

```
my-ecology-project/
│
├── README.md                    ← project overview, setup instructions
├── params.yaml                  ← ALL parameters; source of truth
├── .gitignore
│
├── data/
│   ├── raw/                     ← NEVER modified; read-only after deposit
│   │   ├── occurrences_raw.csv
│   │   ├── predictors/          ← original rasters
│   │   └── spatial/             ← original shapefiles
│   ├── processed/               ← cleaned, validated, analysis-ready
│   │   ├── data_clean.csv
│   │   ├── points_with_env.csv
│   │   └── predictors_stack.tif
│   └── spatial/                 ← derived spatial layers
│       ├── study_area.gpkg
│       └── M_area.gpkg
│
├── scripts/                     ← analysis scripts (numbered by order)
│   ├── 00_setup.R               ← load packages, set paths, source params
│   ├── 01_data_cleaning.R
│   ├── 02_geoprocessing.R
│   ├── 03_modeling.R
│   ├── 04_validation.R
│   └── 05_figures.R
│
├── models/                      ← fitted model objects
│   ├── maxnet_tuned.rds
│   ├── brt_tuned.rds
│   └── ensemble_weights.csv
│
├── outputs/
│   ├── figures/                 ← all plots
│   ├── tables/                  ← all CSV results
│   ├── maps/                    ← all raster outputs
│   └── reports/                 ← rendered reports
│
├── logs/
│   ├── decision_log.md
│   ├── data_provenance.md
│   ├── software_environment.txt
│   ├── file_manifest.md         ← checksums for all outputs
│   └── reproducibility_checklist.md
│
└── reports/
    ├── technical_report.md      ← or .Rmd / .qmd for literate programming
    └── supplementary/
```

## Naming Conventions

- Scripts: `NN_descriptive_name.R` (numbered for execution order)
- Data files: `snake_case`, no spaces, include version or date if multiple versions
- Rasters: `variable_source_resolution_date.tif` (e.g., `ndvi_modis_1km_2023.tif`)
- Models: `algorithm_species_version.rds`
- Outputs: `metric_context_date.csv`

## Version Control Rules

- Commit after each major step (cleaning, modeling, validation)
- Commit message format: `step: brief description` (e.g., `modeling: add BRT with spatial CV`)
- Tag the commit used for the submitted manuscript: `git tag -a v1.0 -m "manuscript submission"`
- Never commit raw data files (add to .gitignore); archive separately at Zenodo/OSF

## .gitignore Template

```
# Data (archive separately)
data/raw/*
!data/raw/.gitkeep

# Large model objects
models/*.rds
models/*.pkl

# Large rasters
data/**/*.tif
outputs/maps/*.tif

# Environment files
.Rhistory
.RData
__pycache__/
*.pyc
.ipynb_checkpoints/

# OS files
.DS_Store
Thumbs.db
```
