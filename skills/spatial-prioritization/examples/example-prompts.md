---
skill_id: spatial-prioritization
example_count: 5
---

# Spatial Prioritization — Example Prompts

## Scenario 1: 30×30 Target Achievement — Tropical Country

**Context:** A tropical nation needs to expand its protected area network from current 14% coverage to 30% by 2030 (Kunming-Montreal GBF Target 3).

**Prompt:**
> "I have SDM suitability layers for 120 species and an opportunity cost surface for a tropical country. Design a minimum-cost protected area network that achieves 30% representation for all species AND covers at least 30% of total land area. Lock in existing PAs."

**Expected workflow:**
1. Build feature layers (120 species SDM suitability rasters)
2. Set targets = 0.30 for all features; add area constraint via `add_min_set_objective`
3. Lock in WDPA existing PAs via `locked_in_raster`
4. `run_prioritization.R pu_cost.tif features/ outputs/ 0.30 wdpa.tif`
5. Check `feature_representation.csv` — verify all 120 features ≥ 30%
6. Map solution; compute % land area covered

**Key decision points:**
- If any species < 30% → check if its range is fully within locked-out areas
- If solution selects > 40% of land → check if some targets can be relaxed for LC species

---

## Scenario 2: Fixed Budget Conservation Planning

**Context:** NGO has USD 10M to acquire land in a biodiversity hotspot. Maximise conservation benefit within this budget.

**Prompt:**
> "With a budget of USD 10M, select the set of land parcels (planning units) that maximises the number of threatened species (IUCN CR, EN, VU) whose representation targets are met. Use IUCN-based targets (CR=60%, EN=50%, VU=40%)."

**Expected workflow:**
1. Compute IUCN targets via `set_iucn_targets()` from resource guide
2. Switch to `add_max_features_objective(budget = 10e6)`
3. `run_prioritization.R pu_cost.tif features/ outputs/ targets_iucn.csv NA NA 0 10000000`
4. Load `feature_representation.csv` → count species above/below target
5. Report cost-effectiveness: threatened species-targets met per million USD

---

## Scenario 3: Corridor Design Between Two National Parks

**Context:** Two national parks need to be connected by a wildlife corridor. Identify the minimum-cost land parcels connecting them while protecting 40% of corridor species.

**Prompt:**
> "Design a wildlife corridor connecting Park A and Park B. Select planning units that form a connected corridor while meeting 40% representation targets for 25 focal species. Lock in both parks; exclude urban areas."

**Expected workflow:**
1. Lock in both parks as locked_in_raster
2. Lock out urban + water as locked_out_raster
3. Set BLM = 0.05 to encourage compact, connected solution
4. `run_prioritization.R pu.tif features/ outputs/ 0.40 parks.tif urban_water.tif 0.05`
5. Verify solution forms a connected path (use igraph on solution raster)
6. Report total corridor length and width at narrowest point

---

## Scenario 4: Sensitivity Analysis for Policy Decision

**Context:** Government needs to defend a new protected area design to stakeholders. Show how the solution is robust to cost uncertainty and target choice.

**Prompt:**
> "Run a sensitivity analysis on the conservation solution: (1) BLM calibration to find the optimal compactness, (2) test target scalings from 50% to 150% of the baseline 30% target, (3) test cost uncertainty ±30%. Produce a portfolio irreplaceability map."

**Expected workflow:**
1. `prioritization_sensitivity.R pu.tif features/ outputs/ 0.30 locked_in.tif locked_out.tif`
2. Load `blm_calibration.csv` → plot cost-compactness tradeoff → select elbow BLM
3. Load `target_sensitivity.csv` → show cost doubles going from 50% to 150% scaling
4. Load `portfolio_frequency.tif` → map areas selected in > 75% of scenarios = robust priorities

---

## Scenario 5: Marine Protected Area Network

**Context:** Marine spatial planning for a coastal nation. Design an MPA network covering 30% of territorial waters while protecting key fish spawning areas and coral reefs.

**Prompt:**
> "I have marine biodiversity feature layers (fish spawning areas, coral, seagrass, endemic species SDMs) and a planning unit grid representing fishing revenue as opportunity cost. Design an MPA network meeting 30% targets for all features while minimising cost to fishers."

**Expected workflow:**
1. Planning units: 1 km² grid cells covering territorial waters; cost = annual fishing revenue
2. Features: spawning aggregations, coral cover, seagrass, endemic species suitability
3. Locked-out: shipping lanes (navigational requirement), oil/gas concessions
4. `run_prioritization.R marine_pu.tif marine_features/ outputs/ 0.30 NA shipping.tif 0.01`
5. Report: total fishing revenue lost in solution vs % marine area protected

**Key decision points:**
- If fishing revenue cost unavailable → use inverse of fishing effort as proxy
- If no-take zones are mandatory in PA regulations → add no-take constraint as binary feature layer
