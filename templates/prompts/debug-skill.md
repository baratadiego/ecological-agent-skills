# Prompt Template: Debug or Review Skill Output

Use when the output from a skill step needs to be reviewed, corrected, or improved.

```
Review the output of the <skill-name> step.

Output file(s):
  - <path to output>

Issues observed:
  - <describe what looks wrong or unexpected>

Expected behaviour:
  - <describe what the output should look like>

Please:
  1. Diagnose the issue
  2. Propose a fix
  3. Apply the fix and regenerate the affected output
  4. Add an entry to decision_log.md explaining what was wrong and how it was fixed
```

## Example

```
Review the output of the ecological-data-foundation step.

Output file: data/processed/data_clean.csv (n = 1,240)
Output file: data/processed/flagged_records.csv (n = 2)

Issues observed:
  - Only 2 records were flagged, but I can see at least 50 records with
    latitude values that look like they may be DMS format (e.g., "-15766"
    instead of "-15.766").
  - The QA_status column contains only "OK" and "COORD_ZERO".

Expected behaviour:
  - DMS-format coordinates should be detected and flagged as COORD_FORMAT_ERROR
    or converted to decimal degrees if the conversion is unambiguous.

Please:
  1. Diagnose why these records passed the coordinate range check
  2. Add a DMS detection step
  3. Re-run cleaning and update data_clean.csv and qa_report.md
  4. Add entry to decision_log.md
```
