---
skill_id: landscape-connectivity
example_count: 5
---

# Landscape Connectivity — Example Prompts

## Scenario 1: Forest Fragment Connectivity Assessment

**Context:** Atlantic Forest remnants, southeastern Brazil. 85 patches of varying size in a 10,000 km² landscape dominated by pasture and sugarcane.

**Prompt:**
> "I have a shapefile of 85 Atlantic Forest patches in southeastern Brazil. Compute IIC and PC for the landscape at dispersal distances of 500 m, 1 km, and 2 km (to cover uncertainty about ocelot dispersal). Rank patches by dPC and identify the top 10 most important patches for connectivity."

**Expected workflow:**
1. `connectivity_metrics.R patches.shp outputs/ 1000` (repeat for 500, 2000)
2. Compare IIC and PC across three dmax values — check robustness
3. Rank by `dPC_pct` descending; report top 10 patches with area and dPC
4. Flag patches with dPC > 5% as high-priority conservation targets

**Key decision points:**
- If IIC changes > 50% between dmax = 500 and 2000 m → conduct formal sensitivity analysis before interpreting
- If top patches overlap with unprotected private land → identify restoration opportunity

---

## Scenario 2: Corridor Identification with Circuitscape

**Context:** Two forest blocks separated by 15 km of agricultural land. Identify the most likely movement corridors for pumas and test which land cover types are least permeable.

**Prompt:**
> "I have a resistance surface for pumas based on land cover type. Two forest blocks are the source and destination patches. Run Circuitscape in pairwise mode, identify pinch points in the current map, and test how corridor connectivity changes if the highway between the blocks is removed."

**Expected workflow:**
1. `resistance_surface.R landcover.tif resistance_table.csv outputs/ dem.tif roads.shp`
2. Run Circuitscape via `run_circuitscape()` function (pairwise, 2 nodes)
3. Load `*_cum_curmap.asc`; extract top 5% current cells as pinch points
4. Remove highway from resistance surface → re-run Circuitscape → compare effective resistance

**Expected findings:**
- Pinch points likely at river crossings and road underpasses
- Removing highway typically reduces effective resistance by 30–60%

---

## Scenario 3: Stepping Stone Prioritisation for Rewilding

**Context:** Degraded agricultural landscape. 12 existing forest patches; 30 candidate restoration sites. Identify which restoration sites most increase connectivity (dPC gain).

**Prompt:**
> "I have 12 existing forest patches and 30 candidate restoration polygons. For each candidate site, calculate how much it would increase PC if restored. Rank candidates by connectivity gain and identify the top 5 restoration priorities."

**Expected workflow:**
1. Compute PC for existing 12 patches
2. For each candidate: add it to patch set → recompute PC → ΔPC = PC_new − PC_baseline
3. Rank candidates by ΔPC descending
4. Report top 5 candidates with area, cost estimate, and ΔPC
5. Map showing candidate sites coloured by ΔPC gain

**Key decision points:**
- If multiple candidates have similar ΔPC → add cost layer and rank by ΔPC/ha
- If candidate overlaps with existing connectivity graph → betweenness centrality gain is secondary metric

---

## Scenario 4: Genetic Isolation by Resistance Test

**Context:** 8 populations of a montane amphibian sampled for genetic markers. Test whether resistance distance (based on land cover) predicts genetic differentiation better than Euclidean distance.

**Prompt:**
> "I have FST values for 8 amphibian populations and a resistance surface based on elevation and land cover. Compute pairwise resistance distances using Circuitscape, then compare IBR (isolation by resistance) vs IBD (isolation by distance) models using a partial Mantel test."

**Expected workflow:**
1. `resistance_surface.R` → combined resistance for amphibians
2. Circuitscape pairwise for 8 population locations → effective resistance matrix
3. Partial Mantel test: `FST ~ resistance | Euclidean` using `vegan::mantel.partial()`
4. Report: if resistance explains more variance than distance → resistance model supported

---

## Scenario 5: Connectivity Change Before and After Deforestation

**Context:** Long-term forest loss monitoring. Compute connectivity for years 2000, 2010, 2020 to quantify fragmentation over time.

**Prompt:**
> "I have three land cover maps (2000, 2010, 2020) for a deforestation frontier in Amazonia. Compute IIC and PC for each year at dmax = 2 km. Quantify patch loss, connectivity loss, and identify which patches were permanently deforested."

**Expected workflow:**
1. `connectivity_metrics.R` for each year → `landscape_summary.csv` per year
2. Join summaries; compute annual % change in IIC, PC, n_patches, mean_area
3. Identify patches present in 2000 but absent in 2020 → permanent deforestation
4. Plot IIC/PC trend over time with error bars from dmax sensitivity (500–5000 m)

**Expected findings:**
- Typical Amazonian deforestation frontier: IIC losses of 15–40% per decade
- PC declines faster than IIC at early stages (many small patches lose probabilistic connections before binary connectivity is severed)
