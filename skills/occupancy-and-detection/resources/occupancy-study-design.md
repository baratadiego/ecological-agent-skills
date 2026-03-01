# Occupancy Study Design Reference

## Minimum Survey Requirements

### Rule of Thumb
- **Sites:** ≥ 30 sites (≥ 50 recommended for covariate estimation)
- **Surveys per site:** ≥ 3 repeat visits within a closed season
- **Detection probability:** If p > 0.3, fewer sites needed; if p < 0.1, many more required

### MacKenzie & Royle (2005) Guidelines

For 95% confidence that all sites with ψ > threshold are detected with K surveys:

| ψ (occupancy) | p (detection) | Sites needed | Surveys/site |
|--------------|--------------|-------------|-------------|
| 0.5 | 0.5 | 20 | 3 |
| 0.5 | 0.3 | 30 | 5 |
| 0.3 | 0.5 | 35 | 3 |
| 0.3 | 0.3 | 50 | 5 |
| 0.1 | 0.5 | 100 | 3 |
| 0.1 | 0.3 | 150 | 5 |

### Confirming Absence
Minimum surveys to confirm absence with confidence 1−α:

K ≥ log(α) / log(1 − p)

Example: p = 0.3, α = 0.05 → K ≥ log(0.05)/log(0.7) ≈ 8.4 → 9 surveys

## Closure Assumption

The population must be **closed** (no births, deaths, immigration, emigration) within a season. Practical guidelines:
- Mammals: typically 1–4 weeks per season
- Birds (breeding): 2–6 weeks
- Amphibians (breeding): days to 2 weeks
- If closure is uncertain: use dynamic (multi-season) model or robust design

## Common Protocols by Taxa

| Taxa | Protocol | Primary p covariate |
|------|---------|-------------------|
| Large mammals | Camera trap | Trap-nights (effort) |
| Birds | Point count | Observer, time of day |
| Amphibians | Acoustic survey | Temperature, rainfall |
| Reptiles | Visual encounter | Temperature, time of day |
| Bats | Acoustic detector | Night, temperature |
| Plants | Plot survey | Surveyor, season |
