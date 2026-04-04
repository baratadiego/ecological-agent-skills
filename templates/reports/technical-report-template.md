# Technical Report — [Study Title]

**Authors:** [Names]  
**Date:** [YYYY-MM-DD]  
**Version:** [1.0]  
**Repository:** [URL]

---

## 1. Introduction

[Context, study objectives, and research questions.]

---

## 2. Methods

### 2.1 Study Area
[Description of the study area, geographic extent, and key environmental characteristics.]

### 2.2 Data Sources
| Dataset | Source | Resolution / Scale | Date | DOI |
|---------|--------|-------------------|------|-----|
| | | | | |

### 2.3 Data Preparation
[Describe cleaning steps, QA procedures, and key decisions. Reference qa_report.md.]

### 2.4 [Analysis Approach — e.g., Species Distribution Modeling]
[Full methods description following relevant reporting standard (ODMAP, etc.).]

### 2.5 Model Validation and Uncertainty
[Describe validation strategy, metrics, and uncertainty quantification.]

---

## 3. Results

### 3.1 Data Summary
[Number of records after cleaning, spatial extent covered, etc.]

### 3.2 Model Performance
| Metric | Training | CV | Test |
|--------|---------|-----|------|
| AUC-ROC | | | |
| TSS | | | |

### 3.3 Main Findings
[Primary results with full statistical reporting: estimate (95% CI), test statistic, p-value, effect size.]

### 3.4 Uncertainty
[Description of uncertainty sources and their magnitude.]

---

## 4. Discussion

[Interpretation, comparison with literature, management implications.]

---

## 5. Limitations and Caveats

<!-- Required section. Do not omit. Conservation Biology, PLOS ONE, and Methods in Ecology and Evolution
     require explicit treatment of limitations. Vague statements ("more data are needed") are not acceptable.
     Each bullet must be specific and, where possible, quantified. -->

- **Sample size:** [Describe how n_occurrences / n_sites / survey effort limits inference. State which conclusions would change with more data.]
- **Spatial extent:** [Describe the calibration area and whether the model applies outside it. Note if projections extend beyond sampled environments (MESS/MOP).]
- **Temporal scope:** [State the time period represented by the data and whether conditions may have changed.]
- **Data quality:** [Note coordinate uncertainty, taxonomic reliability, or detection biases in the occurrence/survey data.]
- **Model assumptions:** [List key assumptions (e.g., species at equilibrium with climate, closed population, parallel trends) and whether they were tested.]
- **Transferability:** [State whether results should be applied to other regions, taxa, or time periods.]

---

## 6. Conclusions

[Concise summary of main findings and recommendations.]

---

## 7. References

[Full citations in standard format.]

---

## Appendix A: Reproducibility Package

- **params.yaml:** [link or path]
- **Code repository:** [URL with commit hash or tag]
- **Raw data archive:** [Zenodo DOI or institutional repository URL]
- **Software environment:** See `logs/software_environment.txt`
- **Reproducibility checklist:** See `logs/reproducibility_checklist.md`
