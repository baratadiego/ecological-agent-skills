# GBIF Credentials Setup

GBIF credentials are **optional** but enable async downloads with a citable DOI,
which is required for reproducible publications and for datasets > 100,000 records.

Without credentials, `download_from_gbif.py` falls back to `occ.search`
(no DOI, max ~100,000 records, still functional for most studies).

---

## Step 1 — Create a free GBIF account

1. Go to https://www.gbif.org
2. Click **Login** > **Register**
3. Fill in username, email, and password
4. Confirm your email address

---

## Step 2 — Set environment variables

Set these three variables in your shell before running any skill:

```bash
# Linux / macOS — add to ~/.bashrc or ~/.zshrc
export GBIF_USER="your_gbif_username"
export GBIF_PWD="your_gbif_password"
export GBIF_EMAIL="your_email@example.com"
```

```powershell
# Windows — PowerShell (current session only)
$env:GBIF_USER  = "your_gbif_username"
$env:GBIF_PWD   = "your_gbif_password"
$env:GBIF_EMAIL = "your_email@example.com"
```

```powershell
# Windows — PowerShell (permanent, per user)
[System.Environment]::SetEnvironmentVariable("GBIF_USER",  "your_gbif_username", "User")
[System.Environment]::SetEnvironmentVariable("GBIF_PWD",   "your_gbif_password", "User")
[System.Environment]::SetEnvironmentVariable("GBIF_EMAIL", "your_email@example.com", "User")
```

If using conda, you can also add them to `environment.yaml` under `variables:`
(not recommended for shared/committed files — use a `.env` file instead).

---

## Step 3 — Verify

```bash
python -c "import os; print(os.getenv('GBIF_USER'))"
```

Should print your GBIF username.

---

## When credentials are used vs. not used

| Scenario | Method used | DOI | Max records |
|----------|-------------|-----|-------------|
| Credentials set + dataset > 100k records | Async download | Yes | Unlimited |
| Credentials set + dataset <= 100k records | `occ.search` | No | ~100k |
| No credentials | `occ.search` fallback | No | ~100k |

---

## Citing GBIF downloads

When credentials are set and an async download completes, the script saves a
`download_metadata_*.txt` file containing the DOI. Cite it in publications as:

> GBIF.org (YYYY) GBIF Occurrence Download https://doi.org/10.15468/dl.XXXXXX

---

## Troubleshooting

**"GBIF async download requires env vars"** — credentials not set; see Step 2 above.

**"occ.count returned 400"** — `hasCoordinate` is not supported by the count endpoint;
this is a known GBIF API limitation. The script handles this silently.

**pygbif TypeError on Python 3.14** — `pygbif` has an API incompatibility with
Python 3.14's `requests` session. The script automatically falls back to direct
HTTP calls to the GBIF REST API. No action needed.
