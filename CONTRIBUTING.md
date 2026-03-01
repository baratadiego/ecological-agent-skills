# Contributing to antigravity-eco-skills

Thank you for contributing! This guide explains how to add or improve skills, workflows, and resources.

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

- Patch (1.0.x): bug fixes, minor additions to existing skills
- Minor (1.x.0): new skills or workflows
- Major (x.0.0): breaking changes to SKILL.md structure or workflow chaining

Update `CHANGELOG.md` for every release.
