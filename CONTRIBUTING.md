# Contributing to ecological-agent-skills

Thank you for contributing! This guide explains how to add or improve skills, workflows, and resources.

---

## License Compatibility

All contributions must be compatible with **GPL-3.0-or-later**. By submitting a pull request, you agree that your contribution is licensed under the same terms as this project.

---

## Skill Structure

Every skill must follow this structure exactly:

```
skills/<skill-name>/
├── SKILL.md          ← required; main instructions for the agent
├── resources/        ← reference documents, glossaries, tables
├── examples/         ← invocation prompt examples
└── scripts/          ← R and/or Python helper scripts
```

### SKILL.md Required Sections

1. **Purpose** — what this skill does
2. **When to Invoke** — trigger conditions
3. **Inputs** — table of expected inputs with format and required flag
4. **Outputs** — table of expected outputs with descriptions
5. **Steps** — numbered, detailed procedural steps
6. **Key Decisions to Document** — what must go in decision_log.md
7. **Tools and Libraries** — R and Python packages
8. **Resources** — links to files in `resources/`
9. **Notes** — caveats and common mistakes

---

## Adding a New Skill

1. Create the directory: `skills/<new-skill-name>/`
2. Write `SKILL.md` following the template above
3. Add at least one resource file in `resources/`
4. Add example prompts in `examples/example-prompts.md`
5. Add at least one script in `scripts/` (R or Python)
6. Add an entry to `CATALOG.md`
7. Update `README.md` skill table
8. If the skill is part of a workflow, update the relevant `WORKFLOW.md`

---

## Adding a New Workflow

1. Create `workflows/<workflow-name>/WORKFLOW.md`
2. Follow the WORKFLOW.md template: Trigger, Steps (with skill → output mapping), Deliverables
3. Add to `README.md` workflow table
4. Update `CATALOG.md` workflow × skill matrix

---

## Script Standards

**R scripts:**
- Use `suppressPackageStartupMessages()` for all library calls
- Accept input/output paths via `commandArgs(trailingOnly = TRUE)` with defaults
- Include a usage comment at the top
- Write all outputs explicitly; never rely on implicit working directory state

**Python scripts:**
- Use `sys.argv` for arguments with sensible defaults
- Include module-level docstring with usage
- Use `Path` (pathlib) for all file operations
- All scripts must run as `__main__` with `if __name__ == "__main__": main()`

---

## Quality Standards

- All new skills must follow the ODMAP, standard reporting, or equivalent framework relevant to their domain
- All scripts must be tested with at least one example dataset before merging
- All resources must cite data sources with DOI or URL

---

## Versioning

### Repository Releases (CHANGELOG.md)

| Version bump | When to use |
|-------------|-------------|
| **Patch** (1.0.x) | Bug fix in a script; correction in a resource file with no interface change |
| **Minor** (1.x.0) | New skill, workflow, or script added; new optional fields in Inputs/Outputs |
| **Major** (x.0.0) | Structural change that breaks existing invocations (e.g., renaming required Inputs, reordering Steps) |

Update `CHANGELOG.md` for every release.

### Release Process

1. **Who can release:** Any maintainer with push access to the main branch.
2. **When to release:** After completing a planned phase (minor/major) or after accumulating meaningful fixes (patch).
3. **How to release:** Follow `RELEASE_CHECKLIST.md` step by step. Do not skip the CI or regression test steps.
4. **Version numbering:** See the table below.
5. **Backward compatibility:** Changes to `SKILL.md` Inputs, Outputs, or Steps that would break existing workflow invocations require a **major** version bump for both the skill and the repository.

### Per-Skill Versioning (skill_version field in SKILL.md)

Every SKILL.md must contain a `skill_version` field in its YAML front-matter:

```yaml
---
skill_name: species-distribution-modeling
skill_version: "1.0.0"
---
```

Increment the `skill_version` according to these rules:

| Change type | Version bump | Example |
|-------------|-------------|---------|
| Fix typo, clarify wording in Steps/Notes/Resources | **Patch** (x.y.z+1) | `1.0.0` → `1.0.1` |
| Add a new resource file or new script to an existing skill | **Minor** (x.y+1.0) | `1.0.0` → `1.1.0` |
| Add a new optional input or output column | **Minor** (x.y+1.0) | `1.1.0` → `1.2.0` |
| Add a new required input, rename an existing input, or change the meaning of a Step | **Major** (x+1.0.0) | `1.0.0` → `2.0.0` |
| Remove a required input or output, or delete a mandatory Step | **Major** (x+1.0.0) | `1.2.3` → `2.0.0` |

#### Why this matters
Workflows chain skills together. If a downstream skill expects `suitability.tif` and an upstream skill is updated to output `suitability_current.tif` (a major change), the workflow will silently fail unless the version bump signals incompatibility.

Agents can inspect `skill_version` to decide whether to re-run a skill or accept a cached result.

---

## Logging Standards (v2.1.0+)

All scripts must include the inline logger block and follow these conventions:

### R scripts
- Inline logger block inserted immediately after the `# Usage:` line 1 comment
- `log_step(N, description)` at the start of each major processing block
- `log_decision(variable, value, rationale)` for every key parameter
- All informational `cat()` / `message()` calls replaced by `log_info()`
- `log_warn()` when data quality issues are detected (< 30 records, > 20% missing, etc.)
- Every `tryCatch` must emit an actionable `log_error()` message with:
  - Failing step name
  - Probable cause
  - What to check
  - Which upstream skill should have produced the missing input

### Python scripts
- Inline logger block inserted after the module docstring, before other imports
- `log_step(N, description)` / `log_decision(var, val, why)` helper functions
- All `print()` informational calls replaced by `logger.info()`
- Every `try/except` block must emit a structured error with the same four fields as R

### Precondition checks
Every script must verify all inputs exist before processing begins:
```r
# R
if (!file.exists(input_csv)) {
  log_error("Input nao encontrado: %s\nCausa provavel: ...\nVerifique: ...\nSkill anterior: ...", input_csv)
  stop("Missing input: ", input_csv)
}
```
```python
# Python
if not Path(input_csv).exists():
    logger.error("Input nao encontrado: %s\n  Skill anterior: ...", input_csv)
    sys.exit(1)
```
