# Pre-Analysis Checklist

Complete before starting any quantitative ecology analysis.

## Data

- [ ] Raw data archived in `data/raw/` and not modified
- [ ] Data provenance documented (source, version, DOI, access date, license)
- [ ] `ecological-data-foundation` skill applied; `qa_report.md` reviewed
- [ ] Final cleaned dataset confirmed and saved

## Spatial

- [ ] Project CRS defined and documented in `params.yaml`
- [ ] All layers reprojected to project CRS
- [ ] Raster stack aligned (same extent, resolution, CRS)
- [ ] Study area polygon finalised

## Modeling

- [ ] Collinearity assessed; final predictor set documented
- [ ] CV strategy defined (spatial or temporal if applicable)
- [ ] Candidate model set justified (not purely data-driven)
- [ ] Primary evaluation metric pre-specified

## Reproducibility

- [ ] `params.yaml` complete (no hard-coded values remain in scripts)
- [ ] Random seeds set in `params.yaml`
- [ ] `git init` and initial commit done
- [ ] `decision_log.md` opened and dated
