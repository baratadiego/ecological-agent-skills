# Worked Example: Phytoplankton Community — Amazon Reservoirs

**Workflow:** analyze-community-structure  
**System:** Phytoplankton assemblages in hydroelectric reservoirs  
**Sites:** 24 sampling stations across 3 reservoirs (Tucuruí, Balbina, Samuel)  
**Survey:** Quarterly sampling, 2018–2022 (6 campaigns × 24 stations = 144 samples)  
**Matrix:** 144 samples × 63 genera (cell density, cells/mL)

---

## Data Preparation

- Hellinger transformation applied (sqrt of relative abundance) to reduce effect of dominant taxa
- Rare genera (< 5 samples, < 10 cells/mL peak density) removed: 63 → 51 genera retained
- Seasonal grouping: wet season (Nov–Mar) / dry season (Apr–Oct)

## Alpha Diversity by Reservoir and Season

| Reservoir | Season | Richness | Shannon H' | Simpson 1−D |
|-----------|--------|---------|-----------|------------|
| Tucuruí | Wet | 31.2 ± 4.1 | 2.91 ± 0.31 | 0.91 |
| Tucuruí | Dry | 22.4 ± 3.7 | 2.44 ± 0.28 | 0.87 |
| Balbina | Wet | 18.7 ± 5.2 | 2.21 ± 0.41 | 0.83 |
| Balbina | Dry | 14.1 ± 4.0 | 1.87 ± 0.38 | 0.76 |
| Samuel | Wet | 26.3 ± 3.9 | 2.73 ± 0.29 | 0.89 |
| Samuel | Dry | 19.8 ± 3.4 | 2.38 ± 0.25 | 0.86 |

Tucuruí showed significantly higher richness (KW: H = 18.4, p < 0.001), associated with larger surface area and longer water residence time.

## NMDS — Stress = 0.11 (good)

Environmental fitting (envfit, 999 permutations):

| Variable | r² | p |
|---------|----|----|
| Total phosphorus | 0.61 | 0.001 |
| Water temperature | 0.54 | 0.001 |
| Season | 0.48 | 0.001 |
| Reservoir | 0.42 | 0.001 |
| Turbidity | 0.31 | 0.004 |

## PERMANOVA

```
adonis2(bray_dist ~ reservoir * season, permutations = 999)

              Df  SumOfSqs   R²      F    p
reservoir      2    3.412  0.312  28.1  0.001
season         1    1.847  0.169  30.4  0.001
reservoir:season 2  0.934  0.085   7.7  0.001
Residual     138    4.200  0.384
Total        143   10.939  1.000
```

## Key Findings

- Community composition differed strongly between reservoirs (R² = 0.31) and seasons (R² = 0.17)
- Cyanobacteria (Microcystis, Cylindrospermopsis) dominated Balbina dry season — consistent with known eutrophication issues
- Diatoms (Aulacoseira, Cyclotella) dominated Tucuruí wet season — associated with higher turbulence and silica availability
- Temporal beta diversity was dominated by species turnover (77%), not nestedness, suggesting true seasonal succession rather than simple impoverishment
