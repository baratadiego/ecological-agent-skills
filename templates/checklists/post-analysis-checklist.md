# Post-Analysis Checklist

Complete before finalising any report or publication.

## Statistical Reporting

- [ ] All p-values accompanied by effect sizes and CIs
- [ ] Sample sizes (n) reported for all comparisons
- [ ] Test statistics reported (F, t, χ², H, Z)
- [ ] Model performance reported for train, CV, AND test (never only training)
- [ ] Multiple comparisons: correction applied and method stated (Bonferroni, FDR)
- [ ] Confidence intervals: method stated (Wald, profile likelihood, bootstrap)

## Model Reporting

- [ ] Algorithm(s) and version(s) stated
- [ ] All hyperparameters reported (not just "default settings")
- [ ] CV strategy reported (k, block size for spatial CV)
- [ ] Threshold selection method and value reported
- [ ] Uncertainty quantification described and reported
- [ ] Variable importance reported for all predictors

## Spatial Outputs

- [ ] CRS and resolution stated for all rasters
- [ ] Spatial extent (bounding box or description) stated
- [ ] Area estimates in appropriate units (ha, km²)
- [ ] MESS / ExDet applied if predicting outside training range
- [ ] All maps include scale bar, north arrow, and legend

## Figures

- [ ] All figures have informative captions (not just "Figure 1")
- [ ] NMDS plots include stress value
- [ ] ROC curves include AUC
- [ ] Calibration plots include calibration slope
- [ ] Colour palettes are colourblind-friendly (avoid red-green alone)
- [ ] Figure resolution ≥ 300 dpi for publication

## Data and Code Availability

- [ ] Raw data archived with DOI (Zenodo, OSF, figshare)
- [ ] Code archived with DOI and linked to specific commit
- [ ] Data availability statement written
- [ ] Code availability statement written
- [ ] License specified for both data and code
- [ ] README in data/code archive explains how to reproduce the analysis

## Reporting Standards Compliance

- [ ] SDM: ODMAP checklist completed (Zurell et al. 2020)
- [ ] Occupancy: MacKenzie-Bailey GoF reported
- [ ] Impact assessment: BACI design requirements verified
- [ ] Community ecology: PERMDISP run before interpreting PERMANOVA
- [ ] ES assessment: method and data source per service documented
