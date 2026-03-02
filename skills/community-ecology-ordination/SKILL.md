---
skill_version: 1.0.0
---

# Skill: community-ecology-ordination

**Domain:** NMDS · PCA · PCoA · Diversity · Clustering · Composition  
**Phase:** 3 — Specialist  
**Used by:** analyze-community-structure

---

## Purpose

Guides the agent through multivariate analysis of ecological communities: ordination of species assemblages, diversity metric computation, beta diversity partitioning, cluster analysis, and hypothesis testing on community composition.

---

## When to Invoke

- Analysing species composition across multiple sites
- Comparing community structure between treatments, habitats, or time periods
- Computing alpha and beta diversity metrics
- Identifying species groups or site clusters

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Species × site abundance or presence matrix | CSV | Yes |
| Environmental metadata per site | CSV | Recommended |
| Treatment or grouping variable | Factor column | Recommended |

---

## Outputs

| Output | Description |
|--------|-------------|
| `ordination_plot.png` | NMDS/PCA biplot |
| `diversity_metrics.csv` | Alpha diversity per site |
| `beta_diversity_matrix.csv` | Pairwise dissimilarity matrix |
| `permanova_results.txt` | PERMANOVA output |
| `cluster_dendrogram.png` | Hierarchical clustering dendrogram |
| `community_report.md` | Full analysis narrative |

---

## Steps

### 1. Data Preparation
- Check for sites with zero species (remove or flag)
- Check for species observed at only one site (rare species handling: keep or remove)
- Standardise if needed (Hellinger, Wisconsin, presence/absence)
- Choose dissimilarity metric: Bray-Curtis (abundance), Jaccard (presence/absence), UniFrac (phylogenetic)

### 2. Alpha Diversity
- Species richness (S)
- Shannon index (H')
- Simpson index (1−D)
- Rarefaction curves to assess sampling adequacy
- Report metric ± SE per group

### 3. Ordination
**NMDS:**
- Run with k=2 (default) and k=3; choose lowest stress with acceptable fit
- Stress < 0.1 = excellent, < 0.2 = acceptable, > 0.2 = poor
- Run with ≥ 20 random starts; confirm convergence

**PCA (for environmental gradients or species scores):**
- Use Hellinger-transformed data or correlation matrix
- Report eigenvalues and % variance per axis

**PCoA / MDS:**
- For non-Euclidean dissimilarity matrices

### 4. Beta Diversity Partitioning
- Partition total beta diversity into nestedness and turnover components (betapart)
- Report contribution of each component per group comparison

### 5. Hypothesis Testing
- PERMANOVA (`adonis2`): test if group centroids differ
- PERMDISP: test if group dispersions (variances) differ (required before interpreting PERMANOVA)
- ANOSIM: alternative non-parametric test
- Report F/R statistic, R², p-value (permutation-based)

### 6. Species Contributions
- SIMPER: identify species driving dissimilarity between groups
- IndVal: identify indicator species per group
- Report top N contributing species per axis or group

### 7. Cluster Analysis
- Hierarchical clustering: Ward.D2 linkage preferred
- Cophenetic correlation to assess cluster quality
- k-means as alternative for large datasets
- Determine optimal k using silhouette or elbow method

---

## Key Decisions to Document

- Dissimilarity metric and rationale
- Rare species handling
- Data transformation applied
- Number of NMDS dimensions
- Permutation count for PERMANOVA

---

## Tools and Libraries

**R:** `vegan`, `betapart`, `indicspecies`, `ape`, `dendextend`, `ggplot2`  
**Python:** `skbio`, `scipy.cluster`, `sklearn.manifold`

---

## Resources

- `resources/dissimilarity-metric-guide.md` — which metric for which data type
- `resources/nmds-interpretation-guide.md` — how to read and report NMDS plots
- `examples/` — worked NMDS and PERMANOVA example

---

## Notes

- Always run PERMDISP before interpreting PERMANOVA; significant dispersion differences can inflate PERMANOVA results
- Stress value must be reported alongside all NMDS plots
- Rarefaction is mandatory when sites have very different sampling intensities
