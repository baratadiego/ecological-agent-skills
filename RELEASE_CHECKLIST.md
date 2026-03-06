# Release Checklist

Follow this checklist before every repository release. Do not skip steps.

---

## Pre-Release

- [ ] Run CI: `bash tests/ci_check.sh` — all checks pass
- [ ] Run Python tests: `python3 -m pytest tests/python/` (if pytest available)
- [ ] Run R tests: `Rscript tests/r/run_all_tests.R` (if testthat available)
- [ ] Run regression tests: `bash tests/regression/run_regression_tests.sh`
- [ ] Verify smoke tests manually (`tests/agent_smoke/smoke_test_cases.json`)
- [ ] Update `CHANGELOG.md` with new entries for this version
- [ ] Verify `SKILL_INDEX.json` is valid JSON: `python3 -m json.tool skills/SKILL_INDEX.json > /dev/null`
- [ ] Verify `SKILL_INDEX.json` is synchronized with all existing skills
- [ ] Verify `renv.lock` includes all R packages referenced in scripts
- [ ] Verify `environment.yaml` includes all Python packages referenced in scripts
- [ ] No empty files: `find . -empty -type f` (should return nothing)
- [ ] No references to old name: `grep -r "antigravity" .` (should return nothing)
- [ ] All examples have documented data sources
- [ ] All new scripts have inline logger block
- [ ] All new scripts have `tryCatch` (R) or `try/except` (Python) error handling

## Release

- [ ] Create annotated git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z: description"`
- [ ] Generate ZIP: `git archive --format=zip --output=ecological-agent-skills-vX.Y.Z.zip --prefix=ecological-agent-skills/ HEAD`
- [ ] Verify ZIP: `unzip -l ecological-agent-skills-vX.Y.Z.zip | head -20`
- [ ] Update `AGENT_CONTEXT.md` if agent routing behavior changed
- [ ] Update `docs/global-examples-index.md` if new examples were added
- [ ] Push to remote: `git push origin main --tags`

## Post-Release

- [ ] Verify `CHANGELOG.md` has the release date
- [ ] Update `_metadata.last_updated` in `SKILL_INDEX.json`
- [ ] Record known issues in `KNOWN_ISSUES.md` if applicable
- [ ] Archive smoke test results as `tests/agent_smoke/smoke_test_results_{date}.json`
