# SDM Reporting Checklist (ODMAP-based)

Follow the ODMAP protocol (Zurell et al. 2020, Ecography) for complete reporting.

## O — Overview
- [ ] Study objective defined (interpolation vs extrapolation, prospective vs retrospective)
- [ ] Target taxa listed with accepted nomenclature
- [ ] Study area and calibration area (M) described
- [ ] Temporal scope of predictions stated

## D — Data
- [ ] Occurrence source(s) listed with DOI or institution
- [ ] Number of records before and after cleaning stated
- [ ] Spatial thinning distance and method reported
- [ ] Background/pseudo-absence strategy described
- [ ] Predictor sources listed with resolution and version
- [ ] Collinearity assessment and final predictor set reported

## M — Model
- [ ] Algorithm(s) listed (MaxEnt, BRT, RF, etc.)
- [ ] Hyperparameter tuning procedure described
- [ ] Regularisation / complexity parameters reported
- [ ] CV strategy and number of folds stated
- [ ] Block size for spatial CV reported

## A — Assessment
- [ ] Performance metrics reported for train, CV, and test
- [ ] TSS and AUC reported; Boyce index if presence-background
- [ ] Threshold method reported with threshold value
- [ ] Calibration assessed and reported

## P — Prediction
- [ ] Extent of prediction stated (within M area or beyond)
- [ ] MESS / ExDet extrapolation mask applied (if predicting outside training range)
- [ ] Ensemble method described (weighted average, mean, etc.)
- [ ] Uncertainty map produced (SD across ensemble)
- [ ] Scenario data sources and time horizon stated (for projections)
