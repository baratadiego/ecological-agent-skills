# ecological-agent-skills — Claude Code Context

## Read First
Read `AGENT_CONTEXT.md` before any task. All agent routing rules are there.

## Key Files
- `skills/SKILL_INDEX.json` — skill routing table (use trigger_keywords, not names)
- `CATALOG.md` — human-readable catalog of all 17 skills
- `CHANGELOG.md` — version history
- `KNOWN_ISSUES.md` — active known issues

## Project Structure
- `skills/<id>/SKILL.md` — skill definition; read fully before executing scripts
- `workflows/<id>/WORKFLOW.md` — ordered skill sequences for complete pipelines
- `tests/` — CI, Python pytest, R testthat, regression, and agent smoke tests

## Testing
- Full CI: `bash tests/ci_check.sh`
- Python: `python3 -m pytest tests/python/`
- R: `Rscript tests/r/run_all_tests.R`
- Validate SKILL_INDEX: `python3 -m json.tool skills/SKILL_INDEX.json > /dev/null`
- Regression suite: `bash tests/regression/run_regression_tests.sh` (35 checks).
  On Git Bash/Windows prefix with `LC_ALL=C.UTF-8` to avoid locale errors in
  `tests/generate_stats.sh` and the regression scripts.
- Regenerate regression references: `bash tests/regression/update_references.sh --confirm-update`

## Known Environment Issues
- **Python 3.14**: `skbio` does not yet install (blocks `community_analysis.py`
  regression reference). `biom-format` wheels also missing — skip or use 3.11.
- **GLM test fixture**: `tests/data/points_with_env.csv` exposes `pa`, not
  `richness`. Use `pa` as the response when invoking `glm_pipeline.py` on it.
- **Regression fixtures**: `tests/data/rasters/{landcover,bio1,bio12}.tif`,
  `carbon_pools.csv`, `patches.csv`, `vital_rates.csv` are synthetic —
  do not reuse as scientific examples.

## Release
Follow `RELEASE_CHECKLIST.md` exactly. Never skip steps.
Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z: description"`

## Git
- Bundle session fixes into one commit; no need to confirm before committing
- Never push `analises_*.md`, `.claude/`, or any local analysis files
- Commits in English; communicate with user in PT-BR
