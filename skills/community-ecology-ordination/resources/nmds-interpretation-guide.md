# NMDS Interpretation Guide

## What is NMDS?

Non-Metric Multidimensional Scaling (NMDS) is an ordination technique that represents the rank-order dissimilarity between samples in a low-dimensional space. Unlike PCA, it makes no assumptions about the data distribution and works with any dissimilarity matrix.

## Stress Value — Quality of Fit

| Stress | Fit quality | Action |
|--------|-------------|--------|
| < 0.05 | Excellent | Report and proceed |
| 0.05–0.10 | Good | Report and proceed |
| 0.10–0.15 | Acceptable | Report; note limitation |
| 0.15–0.20 | Poor | Consider k=3 dimensions |
| > 0.20 | Unacceptable | Do not use 2D representation |

**Always report stress in the plot caption or legend.**

## How to Run Properly

```r
library(vegan)
set.seed(42)  # for reproducibility

nmds <- metaMDS(
  comm    = species_matrix,
  distance = "bray",    # Bray-Curtis for abundance; jaccard for PA
  k       = 2,          # start with 2; try 3 if stress > 0.15
  trymax  = 50,         # run 50 random starts; keep best
  autotransform = FALSE # don't auto-transform; apply Hellinger manually if needed
)

cat("Stress:", nmds$stress, "\n")
cat("Converged:", nmds$converged, "\n")

# Run multiple k values to choose
for (k in 2:4) {
  tmp <- metaMDS(species_matrix, distance="bray", k=k, trymax=20, trace=0)
  cat("k =", k, "| stress =", round(tmp$stress, 4), "\n")
}
```

## Reading an NMDS Plot

### Site scores (samples)
- **Nearby points** → similar species composition
- **Distant points** → dissimilar composition
- **Clusters** → groups with consistently similar assemblages

### Species scores (if added)
- Arrow/point direction → gradient of increasing species abundance/occurrence
- Arrow length → strength of association with NMDS axes

### Environmental vectors (envfit)
- Added post-hoc to correlate environmental variables with ordination axes
- Arrow direction and length indicate direction and strength of environmental gradient

```r
# Add environmental vectors
env_fit <- envfit(nmds, env_matrix, permutations = 999)
print(env_fit)  # shows r² and p-value for each variable

# Plot
plot(nmds, display = "sites")
plot(env_fit, p.max = 0.05)  # only significant vectors
```

## Producing a Publication-Quality Plot

```r
library(ggplot2)

scores_df <- as.data.frame(scores(nmds, display = "sites"))
scores_df$group <- metadata$land_use  # your grouping variable

ggplot(scores_df, aes(x = NMDS1, y = NMDS2, colour = group, shape = group)) +
  geom_point(size = 3, alpha = 0.8) +
  stat_ellipse(level = 0.95, linetype = "dashed") +  # 95% confidence ellipses
  annotate("text", x = Inf, y = Inf,
           label = paste("Stress =", round(nmds$stress, 3)),
           hjust = 1.1, vjust = 1.5, size = 3.5) +
  scale_colour_brewer(palette = "Set2") +
  labs(title = "NMDS (Bray-Curtis)", colour = "Land use", shape = "Land use") +
  theme_bw() +
  theme(legend.position = "right")
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Only running 1 random start | Set `trymax = 50` |
| Reporting stress > 0.20 as acceptable | Use k=3 or a different ordination |
| Not setting seed | Always `set.seed()` before metaMDS |
| Using autotransform=TRUE without checking | Turn off; apply transformation explicitly |
| Not checking convergence | Check `nmds$converged` |
| Interpreting axes as principal components | NMDS axes are arbitrary; only relative distances matter |

## When to Use PCA Instead

- Data are continuous environmental variables (not species composition)
- Linear relationships are expected
- You need to explain specific % variance per axis
- For species data: apply Hellinger transformation first (PCA on Hellinger = RDA with no constraints)
