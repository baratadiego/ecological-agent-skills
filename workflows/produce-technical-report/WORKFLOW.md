# Workflow: produce-technical-report

**Purpose:** Synthesise analytical outputs into a publication-ready technical report  
**Skills:** reproducible-ecology-pipeline, biostatistics-workbench

---

## Trigger

Invoke when the user wants to generate a structured technical report from the outputs of a completed analysis.

**Example prompts:**
- "Write a technical report from the SDM results"
- "Generate a methods and results section based on these outputs"
- "Produce the final impact assessment report"

---

## Prerequisites

At least one upstream workflow must have been completed. The following files should exist:
- `parameter_manifest.yaml`
- `decision_log.md`
- `performance_metrics.csv` or equivalent results tables
- Key figures (maps, plots)

---

## Steps

### Step 1 — Read Reproducibility Package
- Load `parameter_manifest.yaml` and `decision_log.md`
- Extract: data sources, software versions, all parameters, key decisions

### Step 2 — Inventory Analytical Outputs
- List all result tables, maps, and figures
- Confirm each output is traceable to its generating step

### Step 3 — Synthesise Methods Section
- Write Methods following the relevant reporting standard:
  - SDM: ODMAP protocol
  - Occupancy: standard unmarked/PRESENCE reporting
  - Impact assessment: BACI reporting guidelines
  - Community ecology: vegan + PERMANOVA conventions
- Include: data sources, cleaning steps, modeling approach, validation strategy, uncertainty quantification

### Step 4 — Synthesise Results Section
- Present results in order: data summary → model performance → main findings → uncertainty
- Integrate figures and tables with cross-references
- State statistical findings with: estimate, CI, test statistic, p-value, effect size

### Step 5 — Write Discussion Outline
- Interpret main findings in ecological context
- Discuss model limitations and uncertainties
- Suggest management implications (if applicable)
- Propose follow-up studies

### Step 6 — Final Checklist
- [ ] All figures labelled and captioned
- [ ] All tables numbered and titled
- [ ] All statistical values reported completely (estimate, CI, test stat, p, effect size)
- [ ] Data and code availability statement included
- [ ] Software citations included
- [ ] Report cross-checks against `parameter_manifest.yaml` complete

---

## Report Template Structure

```
1. Introduction
2. Methods
   2.1 Study area
   2.2 Data sources
   2.3 Data preparation
   2.4 Analysis approach
   2.5 Validation and uncertainty
3. Results
   3.1 Data summary
   3.2 Model performance
   3.3 Main findings
   3.4 Uncertainty
4. Discussion
5. Conclusions
6. References
Appendix: Reproducibility package
```

---

## Reporting Standards Reference

| Analysis type | Standard |
|---------------|---------|
| SDM | ODMAP (Zurell et al. 2020, Ecography) |
| Occupancy | MacKenzie et al. (2018) textbook conventions |
| Community ecology | vegan documentation; Oksanen et al. |
| Impact assessment | CEQ NEPA guidelines or local equivalent |
| Ecosystem services | IPBES assessment framework |

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| Analysis not reproducible from params.yaml alone | Missing parameter documentation | Complete params.yaml before finalising report; add all missing parameters and run again |
| Figures generated with different software versions | Version lock not enforced | Record all package versions in session_info.txt; use renv/conda lockfile for environment reproducibility |
| Statistical results change with different random seed | Stochastic component not fixed | Set and document seed in params.yaml; report sensitivity of results to seed variation |
| External reviewer cannot reproduce key figure | Code sharing incomplete | Ensure all scripts are included; verify all input data paths are documented and data is accessible |
| Report references unpublished dataset | Citation incomplete for peer review | Obtain dataset DOI (Zenodo, Dryad, GBIF) or write data availability statement before submission |
| Methods section length exceeds journal limit | Too much methodological detail in main text | Move detailed parameters to Supplementary Methods; use ODMAP table format for SDMs |
| Discussion cites model predictions without uncertainty | Overconfident interpretation | Always pair predictions with uncertainty estimates; use conditional language ("model suggests", "under assumptions") |
