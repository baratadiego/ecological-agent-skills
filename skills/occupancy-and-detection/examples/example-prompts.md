# Example Invocation Prompts — occupancy-and-detection

## Single-Season Occupancy

```
Load skill: occupancy-and-detection
Task: Single-season occupancy analysis for puma (Puma concolor) from camera trap data.

Files:
  - data/detection_history.csv   (80 sites × 6 survey occasions; 1/0/NA)
  - data/site_covariates.csv     (elevation, forest_cover, dist_to_road)
  - data/obs_covariates.csv      (effort_nights per occasion, observer_id)

Candidate models (occupancy ~ ..., detection ~ ...):
  ψ(forest_cover), p(effort)
  ψ(forest_cover + dist_to_road), p(effort)
  ψ(elevation + forest_cover), p(effort + observer)
  ψ(.), p(.)   ← null model

Run goodness-of-fit (MacKenzie-Bailey χ², 1000 bootstraps).
Select by AICc. If ĉ > 1.5, use QAICc.
Report ψ and p estimates with 95% CIs on probability scale.
```

## Power Analysis

```
Load skill: occupancy-and-detection
Task: Power analysis for a proposed camera trap study.
Expected occupancy (ψ): 0.4. Expected detection per occasion (p): 0.25.
Target: 80% power to detect a 20% decline in occupancy.
How many sites and survey occasions are needed?
```
