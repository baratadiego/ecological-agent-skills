# Example Invocation Prompts — community-ecology-ordination

## Full Community Analysis

```
Load skill: community-ecology-ordination
Task: Analyse bird community structure across three land use types
(old-growth forest, secondary forest, pasture) in the Atlantic Forest.

Files:
  - data/bird_abundance_matrix.csv   (100 sites × 87 species, count data)
  - data/site_metadata.csv           (land_use, elevation, canopy_cover, edge_distance)

Steps:
1. Rarefaction curves to assess sampling adequacy.
2. Alpha diversity (richness, Shannon, Simpson) per land use; compare with Kruskal-Wallis.
3. NMDS (Bray-Curtis, k=2). Report stress.
4. PERMANOVA: community ~ land_use. Test assumption with PERMDISP.
5. SIMPER: top 10 species driving differences between land use pairs.
6. Indicator species (IndVal) per land use type.
7. Hierarchical clustering (Ward.D2) of sites.

Output: ordination_plot.png, diversity_metrics.csv, permanova_results.txt, community_report.md
```

## Beta Diversity Partitioning

```
Load skill: community-ecology-ordination
Task: Partition beta diversity into turnover and nestedness components
for amphibian communities across an elevation gradient (1000–3500 m, 25 sites).
Data: data/amphibian_pa_matrix.csv (presence/absence)
Use betapart package. Report total beta, turnover fraction, and nestedness fraction.
Plot beta diversity components against elevation.
```
