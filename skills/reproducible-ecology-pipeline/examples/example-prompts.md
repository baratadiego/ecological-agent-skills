# Example Invocation Prompts — reproducible-ecology-pipeline

## Project Initialisation

```
Load skill: reproducible-ecology-pipeline
Task: Initialise a reproducible project structure for a jaguar SDM study.
Project name: "jaguar-sdm-amazon"
Create: standard directory layout, params.yaml (pre-filled with SDM defaults),
decision_log.md, data_provenance.md, and run `git init`.
```

## Pre-report Audit

```
Load skill: reproducible-ecology-pipeline
Task: Run a pre-submission reproducibility audit.
Project directory: /projects/cerrado-fire-risk/
1. Complete the reproducibility checklist template.
2. Verify all numbers in outputs/fire_risk_report_v3.md against outputs/*.csv.
3. Capture current R session info.
4. Generate file_manifest.md with SHA256 checksums for all files in outputs/.
```

## Decision Log Entry

```
Load skill: reproducible-ecology-pipeline
Task: Add an entry to the decision log for today's predictor selection step.
Decision: Removed bio7 (VIF = 11.2, highly collinear with bio4) from the predictor set.
Kept: bio1, bio4, bio12, bio15, NDVI, slope (6 variables total, all VIF < 5).
Rationale: bio4 retained over bio7 because it captures seasonality rather than range,
more ecologically meaningful for jaguar thermoregulation.
Append to: decision_log.md
```
