# Workflow: analyze-community-structure

**Purpose:** Multivariate analysis of species community composition and diversity  
**Skills:** ecological-data-foundation → biostatistics-workbench → community-ecology-ordination → model-validation-and-uncertainty → reproducible-ecology-pipeline

---

## Trigger

Invoke when the user wants to describe or compare species assemblages across sites, treatments, or gradients.

**Example prompts:**
- "Compare bird community composition between forest and pasture sites"
- "Ordinate plant communities along an elevational gradient"
- "Identify indicator species for each land use type"

---

## Steps

### Step 1 — ecological-data-foundation
- Validate species × site matrix (check species names, abundance values, site IDs)
- QA environmental metadata
- Output: `data_clean.csv`, `species_site_matrix.csv`

### Step 2 — biostatistics-workbench
- Test assumptions for parametric diversity comparisons (normality, homogeneity)
- Fit GLM/LMM for alpha diversity response to environmental gradients
- Output: `diversity_model_results.csv`, `assumption_diagnostics/`

### Step 3 — community-ecology-ordination
- Compute alpha diversity metrics (S, H', 1−D); rarefaction curves
- Compute beta diversity; partition into turnover and nestedness
- Run NMDS ordination; report stress
- PERMANOVA + PERMDISP for group comparisons
- SIMPER for species contributions
- Hierarchical clustering
- Output: `ordination_plot.png`, `diversity_metrics.csv`, `permanova_results.txt`

### Step 4 — model-validation-and-uncertainty
- Assess NMDS stress and convergence
- Validate PERMANOVA assumptions (PERMDISP)
- Report sensitivity to rare species inclusion/exclusion
- Output: `validation_report.md`

### Step 5 — reproducible-ecology-pipeline
- Document ordination parameters, seed, and dissimilarity metric
- Output: `parameter_manifest.yaml`, `decision_log.md`

---

## Expected Deliverables

- NMDS ordination biplot
- Alpha diversity summary per group
- PERMANOVA results table
- Indicator species list
- Cluster dendrogram
