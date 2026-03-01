# Dissimilarity Metric Selection Guide

## Bray-Curtis (Sørensen quantitative)
- **Data:** Abundance (count or biomass)
- **Properties:** Asymmetric (treats double-zeros correctly); ranges 0–1
- **When:** Most ecological abundance data; default for NMDS of communities
- **R:** `vegan::vegdist(x, method = "bray")`

## Jaccard
- **Data:** Presence/absence
- **Properties:** Symmetric; ranges 0–1
- **When:** Presence-only data; when all species are equally important
- **R:** `vegan::vegdist(x, method = "jaccard")`

## Sørensen (Dice)
- **Data:** Presence/absence
- **Properties:** Emphasises co-occurrences more than Jaccard
- **When:** Similar to Jaccard; slightly more weight to shared species
- **R:** `vegan::vegdist(x, method = "bray")` on 0/1 matrix (equivalent)

## Chao
- **Data:** Abundance (accounts for unobserved species)
- **Properties:** Estimates true dissimilarity adjusting for sampling effort
- **When:** Datasets with very different sampling intensities; rare species important
- **R:** `vegan::vegdist(x, method = "chao")`

## Euclidean
- **Data:** Continuous environmental variables
- **Properties:** Symmetric; sensitive to magnitude; double-zero problem
- **When:** Environmental (not species) data in PCA / RDA
- **Avoid for:** Raw species abundances (use Hellinger transform first)

## Hellinger Distance
- **Data:** Abundance (after Hellinger transformation)
- **Properties:** Avoids double-zero problem; linear methods applicable
- **When:** PCA or RDA on species data; good compromise
- **R:** `vegan::decostand(x, "hellinger")` then Euclidean distance

## Aitchison Distance
- **Data:** Compositional / proportional abundance
- **Properties:** Log-ratio based; appropriate for compositional data
- **When:** Microbiome, pollen, compositional assemblage data
- **R:** `compositions::dist.acomp()` or `zCompositions` + Euclidean

## Decision Summary

```
Data type: Abundance?
  YES → Bray-Curtis (default) | Chao (unequal effort) | Hellinger (for PCA/RDA)
  NO  → Presence/absence?
          YES → Jaccard | Sørensen
          NO  → Continuous (env) → Euclidean | Gower (mixed types)
```
