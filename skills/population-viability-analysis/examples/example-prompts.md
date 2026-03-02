---
skill_id: population-viability-analysis
example_count: 5
---

# Population Viability Analysis — Example Prompts

## Scenario 1: IUCN Criterion E Assessment for an Endangered Antelope

**Context:** 7 years of mark-recapture data for a savanna antelope. Need IUCN listing recommendation.

**Prompt:**
> "I have 7 years of vital rate estimates (adult survival, subadult survival, juvenile survival, fecundity) for a savanna antelope. Build a Lefkovitch matrix, estimate λ and its 95% bootstrap CI, run a stochastic PVA with 1,000 simulations over 100 years, and classify the species under IUCN Criterion E."

**Expected workflow:**
1. Build mean matrix → `lambda_summary.csv` with λ and CI
2. Check CV of vital rates → if any CV > 0.30, stochastic PVA mandatory
3. `stochastic_pva.R` with n_sim = 1000, t_max = 100, quasi_ext = 50
4. Load `iucn_criterion_e.csv` → report qualifying category
5. Run sensitivity analysis → identify most critical vital rate for management

**Key decision points:**
- If λ < 0.95 → calculate MTE; report as urgent
- If P(extinction at 100yr) ≥ 0.50 → qualify as CR
- Report uncertainty: P(extinction) ± bootstrapped 95% CI

---

## Scenario 2: Elasticity-Guided Management of a Sea Turtle

**Context:** Leatherback sea turtle at a nesting beach. Limited budget for conservation action. Determine whether protecting adult survival or nest success has higher λ return.

**Prompt:**
> "Build a 5-stage Lefkovitch matrix for leatherback sea turtles using published vital rates (eggs, hatchlings, juveniles, subadults, adults). Compute elasticity for each matrix element and identify whether management should prioritise adult survival (bycatch reduction) or fecundity (nest protection) based on elasticity."

**Expected workflow:**
1. `matrix_pva.R vital_rates.csv outputs/ 250 100 10`
2. Load `sensitivity_elasticity.csv` → compare fecundity vs adult survival elasticity
3. Plot `elasticity_heatmap.png` — visualise management targets
4. Calculate LTRE comparing two management scenarios (bycatch reduction vs nest protection)
5. Report: which scenario gives higher ΔPC per conservation dollar

**Expected finding:** Adult survival elasticity typically 0.7–0.9 for sea turtles → bycatch reduction is the highest-impact management action.

---

## Scenario 3: Minimum Viable Population for a Reintroduction

**Context:** Planning a reintroduction of a mountain ungulate to a restored habitat. Need to determine the minimum founding population size to achieve < 10% extinction risk over 50 years.

**Prompt:**
> "Using vital rates from a source population of mountain ungulates, determine the minimum founding population size (N₀) needed to keep P(extinction at 50 years) < 0.10. Run stochastic PVA for N₀ = 20, 50, 100, 200 individuals."

**Expected workflow:**
1. Loop `stochastic_pva.R` for each N₀: n_init = 20, 50, 100, 200
2. Extract P(extinction at t=50) from each `stochastic_pva_results.csv`
3. Plot P(extinction) vs N₀ with VU threshold line
4. Identify minimum N₀ where P(extinction) < 0.10

**Key decision points:**
- If minimum N₀ > 200 → assess carrying capacity of release site
- If carrying capacity < minimum viable population → rule out reintroduction

---

## Scenario 4: Catastrophe Modeling for a Wildfire-Prone Species

**Context:** Rare ground-nesting bird in fire-prone ecosystem. Historical records show a major fire every 8–12 years that reduces adult survival by 60% in the fire year.

**Prompt:**
> "I have vital rates for a rare ground-nesting bird. Include a catastrophe module in the stochastic PVA: every 10 years (Poisson-distributed), adult survival drops to 40% of its normal value. Compare P(extinction at 100 yr) with and without catastrophes."

**Expected workflow:**
1. Run baseline stochastic PVA (no catastrophes)
2. Modify `stochastic_pva.R` to add Poisson catastrophe events every λ_cat = 10 yr
3. In catastrophe years: multiply Sa draw by 0.40
4. Compare extinction curves with and without catastrophes
5. Calculate contribution of catastrophes to P(extinction)

---

## Scenario 5: Two-Population Meta-Population PVA

**Context:** Two isolated populations of a tree frog connected by occasional dispersal (5% annual exchange rate). Assess whether dispersal prevents extinction in the smaller population.

**Prompt:**
> "I have vital rates for two isolated tree frog populations (N₁ = 800, N₂ = 120) with 5% annual immigration from pop1 to pop2. Run a two-population stochastic PVA and compare P(extinction of pop2 at 50 yr) with and without dispersal from pop1."

**Expected workflow:**
1. Run single-population PVA for pop2 alone → baseline P(extinction)
2. Add dispersal term: each year, add round(N₁ × 0.05) to pop2 vector (stage distribution of source)
3. Re-run stochastic PVA with dispersal → compare extinction curves
4. Calculate rescue effect: ΔP(extinction) = P_no_dispersal − P_with_dispersal

**Expected finding:** Dispersal rescue effect strongest when pop2 < MVP; diminishes when pop2 is large enough to self-sustain.
