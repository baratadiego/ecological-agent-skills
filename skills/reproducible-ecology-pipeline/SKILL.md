# Skill: reproducible-ecology-pipeline

**Domain:** Provenance · Parameter logging · Decision audit · Checklist · Reporting  
**Phase:** 1 — Foundation  
**Used by:** All workflows

---

## Purpose

Ensures that every quantitative ecology project generates an auditable, reproducible record: all parameters, software versions, data sources, analytical decisions, and intermediate outputs are logged so the study can be independently replicated.

---

## When to Invoke

- At project initialisation (to set up the logging structure)
- At the end of every analytical step (to record decisions and outputs)
- Before generating a technical report or submitting results
- When the user asks about reproducibility, provenance, or audit trails

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Project directory with analytical outputs | Directory path | Yes |
| Analysis scripts | R, Python, bash | Recommended |
| Model parameter files | JSON, YAML, RData | Recommended |
| QA reports from upstream skills | Markdown, CSV | Recommended |

---

## Outputs

| Output | Description |
|--------|-------------|
| `reproducibility_checklist.md` | Completed checklist with pass/fail per criterion |
| `parameter_manifest.yaml` | All parameters used across all steps |
| `decision_log.md` | Chronological log of all analytical decisions |
| `software_environment.txt` | Package versions (`sessionInfo()` / `pip freeze`) |
| `data_provenance.md` | Source, version, access date for every dataset |
| `file_manifest.md` | All input/output files with checksums |

---

## Steps

### 1. Project Initialisation
- Create the standard directory structure (see template)
- Initialise a Git repository (or equivalent version control)
- Set a fixed random seed for all stochastic operations; document the seed
- Create `params.yaml` as the single source of truth for all parameters

### 2. Data Provenance Logging
- For each dataset: record institution, URL/DOI, access date, version/release, license
- Compute MD5/SHA256 checksums for all raw input files
- Store checksums in `file_manifest.md`

### 3. Software Environment Capture
- Run `sessionInfo()` (R) or `pip freeze` + `conda list` (Python) and save to `software_environment.txt`
- Record OS, R/Python version, key package versions
- Prefer `renv` (R) or `conda environment.yaml` (Python) for environment reproducibility

### 4. Parameter Manifest
- Centralise all analysis parameters in `params.yaml`:
  - Random seed
  - CRS / spatial resolution
  - Train/test split ratios
  - Model hyperparameters
  - Thresholds (QA, significance, etc.)
- No hard-coded parameters in scripts; all values referenced from `params.yaml`

### 5. Decision Log
- After each analytical step, append an entry to `decision_log.md`:
  - Date/time
  - Step name
  - Decision made
  - Rationale
  - Output files generated

### 6. Reproducibility Checklist
Evaluate each criterion as PASS / FAIL / N/A:

- [ ] Raw data preserved unchanged
- [ ] All input data checksums recorded
- [ ] Random seed(s) fixed and documented
- [ ] All parameters stored in `params.yaml` (no hard-coded values)
- [ ] Software environment captured
- [ ] All analytical decisions logged
- [ ] Scripts run end-to-end without manual intervention
- [ ] Intermediate outputs versioned or hashable
- [ ] Final outputs match those in the report

### 7. Pre-report Audit
- Re-run the full pipeline from raw data; confirm outputs match
- Cross-check all numbers in the report against the parameter manifest and output files
- Confirm all figures can be regenerated from code

---

## Key Decisions to Document

- Version control system and branching strategy
- Random seed value(s)
- Environment management tool (renv, conda, Docker)
- Intermediate output storage strategy (local, cloud, Zenodo)

---

## Tools and Libraries

**R:** `renv`, `targets`, `drake`, `sessionInfo()`  
**Python:** `DVC`, `MLflow`, `conda`, `pip freeze`, `hashlib`  
**General:** Git, GitHub/GitLab, Zenodo, OSF

---

## Resources

- `resources/reproducibility-checklist-template.md` — blank checklist
- `resources/params-yaml-template.yaml` — standard parameter manifest template
- `resources/directory-structure-template.md` — recommended project layout
- `examples/` — example decision log and provenance record

---

## Notes

- Reproducibility is not optional; it is a precondition for scientific validity
- Prefer `targets` (R) or `DVC` (Python) for pipeline orchestration in complex studies
- Archive raw data and final outputs to a persistent repository (Zenodo, OSF) before publication
