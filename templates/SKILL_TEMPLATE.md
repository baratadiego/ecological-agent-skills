---
name: [REQUIRED — skill-id in kebab-case, must match directory name and SKILL_INDEX.json]
description: "[REQUIRED — 40-80 words in English. Start with what this skill does. Include 'Use this skill when...' followed by trigger phrases and synonyms. Cover situations where the skill should activate even without explicit mention by the user.]"
skill_version: 1.0.0
---

# Skill: [REQUIRED — skill-id in kebab-case, must match directory name and SKILL_INDEX.json]

<!-- INSTRUCTIONS FOR SKILL AUTHORS
     Fill in every [REQUIRED] field. Delete all HTML comments before submitting.
     Run the validation checklist at the bottom before opening a pull request.
     All content must be in English.
     No location-specific geographic references in global files.
-->

---

## Purpose

<!-- [REQUIRED]
     Write 2–4 sentences describing exactly what this skill does.
     Start with "Guides the agent through..."
     Be specific: name the methods, models, or operations covered.
     Do NOT describe when to use it (that goes in "When to Invoke").
-->

[REQUIRED — describe the skill's analytical scope]

---

## When to Invoke

<!-- [REQUIRED]
     List the situations that should trigger this skill as bullet points.
     Each bullet is a concrete scenario, not a keyword.
     These scenarios must be consistent with the trigger_keywords in SKILL_INDEX.json.
     Use plain language that matches how users phrase requests.
-->

Invoke this skill when:

- [REQUIRED — scenario 1]
- [REQUIRED — scenario 2]
- [REQUIRED — scenario 3]
- [add more as needed]

**trigger_keywords** (must match `skills/SKILL_INDEX.json`):
`[keyword1]`, `[keyword2]`, `[keyword3]`

<!-- List all trigger_keywords from SKILL_INDEX.json here so they stay in sync. -->

---

## Inputs

<!-- [REQUIRED]
     List every input the skill needs.
     "Required" = skill cannot run without it.
     "Conditional" = required only under specific conditions (explain in Notes).
     "Recommended" = skill produces lower-quality output without it.
     "Optional" = enhances output but not needed.
-->

| Input | Format | Required |
|---|---|---|
| [REQUIRED — input name] | [format: CSV, GeoTIFF, SHP, GPKG, RData, etc.] | Required / Conditional / Recommended / Optional |
| [input name] | [format] | Required |
| [input name] | [format] | Optional |

---

## Outputs

<!-- [REQUIRED]
     List every file this skill produces.
     Use snake_case filenames with extensions.
     The primary outputs must match primary_outputs in SKILL_INDEX.json.
-->

| Output | Description |
|---|---|
| `[REQUIRED — filename.ext]` | [what this file contains] |
| `[filename.ext]` | [description] |
| `[report_name.md]` | [full narrative report] |

---

## Steps

<!-- [REQUIRED]
     Numbered, sequential steps the agent must follow.
     Each step should be a complete, unambiguous instruction.
     Reference specific script names where applicable.
     Include the exact command or function call when precision matters.
     Minimum 4 steps.
-->

1. **[REQUIRED — step title]**
   [Detailed instruction. Name the script, function, or tool to use. Specify parameters.]

2. **[step title]**
   [Instruction]

3. **[step title]**
   [Instruction]

4. **Validate outputs**
   Confirm that all files listed in the Outputs table were created and are non-empty.
   Check file sizes are above 100 bytes. Record any anomalies in `decision_log.md`.

5. **Record decisions**
   Append to `decision_log.md` following the format defined in `AGENT_CONTEXT.md § 7`.

<!-- Add more steps as needed. Do not omit the validation and decision-logging steps. -->

---

## Decision Points

<!-- [REQUIRED]
     List every condition that requires a non-default decision.
     "Condition" = a measurable or observable state.
     "Diagnosis" = what the condition means.
     "Recommended Action" = what the agent should do.
     Minimum 3 rows.
     Must be consistent with decision_points in SKILL_INDEX.json.
-->

| Condition | Diagnosis | Recommended Action |
|---|---|---|
| [REQUIRED — e.g., n < 10] | [e.g., insufficient data for reliable modelling] | [e.g., do not fit model; communicate limitation to user] |
| [condition] | [diagnosis] | [action] |
| [condition] | [diagnosis] | [action] |

---

## Key Decisions to Document

<!-- [REQUIRED]
     List the decisions that MUST be recorded in decision_log.md.
     These are choices that affect reproducibility or interpretation.
     Phrase as questions the agent answered during analysis.
-->

Record the following in `decision_log.md` after running this skill:

- [REQUIRED — e.g., Which predictor variables were retained and why?]
- [e.g., Which model family was selected and what diagnostic justified it?]
- [e.g., Were any records excluded? How many and for what reason?]
- [add more as needed]

---

## Tools and Libraries

<!-- [REQUIRED — fill in at least one language block]
     List packages, not functions.
     Separate R and Python. Add CLI tools if applicable.
     Keep version constraints only when a specific version is required.
-->

**R**
```r
# [REQUIRED — list R packages]
library(package1)   # purpose
library(package2)   # purpose
```

**Python**
```python
# [REQUIRED — list Python packages]
import package1     # purpose
import package2     # purpose
```

**CLI** *(if applicable)*
```bash
# [optional — list CLI tools, e.g., GDAL, csvkit]
```

---

## Resources

<!-- [REQUIRED]
     Link to every file in this skill's resources/ directory.
     Minimum 2 resources.
     Use relative paths from the repository root.
-->

- [`skills/[skill-id]/resources/[filename].md`](resources/[filename].md) — [one-line description]
- [`skills/[skill-id]/resources/[filename].md`](resources/[filename].md) — [one-line description]

<!-- Add more resource links as needed. -->

---

## Notes

<!-- [REQUIRED]
     List caveats, common pitfalls, and edge cases.
     Be specific. Vague warnings are not useful.
     Minimum 3 bullet points.
-->

- **[REQUIRED — pitfall or caveat]**: [specific explanation of the problem and how to avoid it]
- **[pitfall]**: [explanation]
- **[pitfall]**: [explanation]

---

## Validation Checklist

Before submitting this skill, verify:

- [ ] `name:` field present in YAML frontmatter (kebab-case, matches directory name)
- [ ] `description:` field present in YAML frontmatter (40-80 words, includes trigger phrases)
- [ ] `trigger_keywords` added to `skills/SKILL_INDEX.json`
- [ ] At least 2 files in `resources/`
- [ ] At least 1 script in `scripts/` (R or Python)
- [ ] At least 3 examples in `examples/example-prompts.md`
- [ ] Skill added to `CATALOG.md`
- [ ] Skill added to `README.md`
- [ ] `skill_version` field present in YAML header
- [ ] `decision_points` in `SKILL_INDEX.json` match the Decision Points table above
- [ ] All `[REQUIRED]` placeholders replaced
- [ ] All HTML comments deleted
- [ ] `bash tests/ci_check.sh` exits with code 0
