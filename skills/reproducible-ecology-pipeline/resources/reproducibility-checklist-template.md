# Reproducibility Checklist Template

Project: ___________________________  
Date: ___________________________  
Analyst: ___________________________  

## 1. Data Management

| Criterion | Status | Notes |
|-----------|--------|-------|
| Raw data preserved unchanged in `data/raw/` | PASS / FAIL | |
| All raw files have MD5/SHA256 checksums recorded | PASS / FAIL | |
| Data provenance (source, DOI, access date, license) documented | PASS / FAIL | |
| No manual edits to raw files | PASS / FAIL | |

## 2. Code and Parameters

| Criterion | Status | Notes |
|-----------|--------|-------|
| All parameters in `params.yaml` (no hard-coded values in scripts) | PASS / FAIL | |
| Random seeds fixed and documented in `params.yaml` | PASS / FAIL | |
| Scripts run end-to-end without manual steps | PASS / FAIL | |
| Code version-controlled (Git) | PASS / FAIL | |
| Final commit tagged or release created | PASS / FAIL | |

## 3. Environment

| Criterion | Status | Notes |
|-----------|--------|-------|
| `sessionInfo()` or `pip freeze` output saved | PASS / FAIL | |
| R version or Python version recorded | PASS / FAIL | |
| Package versions locked (`renv.lock` or `environment.yaml`) | PASS / FAIL | |
| OS and hardware noted | PASS / FAIL | |

## 4. Decisions and Decisions Log

| Criterion | Status | Notes |
|-----------|--------|-------|
| `decision_log.md` updated after each major step | PASS / FAIL | |
| Rationale documented for: QA thresholds, predictor selection, CV strategy, threshold method | PASS / FAIL | |
| Deviations from planned protocol documented | PASS / FAIL | |

## 5. Outputs

| Criterion | Status | Notes |
|-----------|--------|-------|
| All output files in `outputs/` with meaningful names | PASS / FAIL | |
| File manifest with checksums for all outputs | PASS / FAIL | |
| Figures regenerable from code | PASS / FAIL | |
| Numbers in report cross-checked against output files | PASS / FAIL | |

## 6. Archival

| Criterion | Status | Notes |
|-----------|--------|-------|
| Raw data archived at Zenodo / OSF / institutional repository | PASS / FAIL | |
| Code archived at GitHub / GitLab with DOI | PASS / FAIL | |
| Data availability statement included in report | PASS / FAIL | |

## Overall Assessment

- Total criteria: ___
- PASS: ___
- FAIL: ___
- N/A: ___
- **Reproducibility score:** ___/___
