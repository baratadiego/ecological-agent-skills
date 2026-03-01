#!/bin/bash
# init_project.sh
# Initialise a reproducible ecology project structure
# Usage: bash init_project.sh <project_name>

PROJECT="${1:-my-ecology-project}"
echo "Initialising project: $PROJECT"

mkdir -p "$PROJECT"/{data/{raw,processed,spatial},models,outputs/{figures,tables,maps},reports,scripts,logs}
touch "$PROJECT/data/raw/.gitkeep"
touch "$PROJECT/logs/decision_log.md"

# Create params.yaml from template
cp "$(dirname "$0")/../resources/params-yaml-template.yaml" "$PROJECT/params.yaml" 2>/dev/null || \
  echo "# params.yaml — fill in values" > "$PROJECT/params.yaml"

# Git init
cd "$PROJECT"
git init -q

# .gitignore
cat > .gitignore << 'GITIGNORE'
data/raw/*
!data/raw/.gitkeep
*.Rhistory
.Rdata
__pycache__/
*.pyc
.DS_Store
*.log
GITIGNORE

# decision_log.md header
cat > logs/decision_log.md << 'DLOG'
# Decision Log

| Date | Step | Decision | Rationale | Output files |
|------|------|----------|-----------|-------------|
DLOG

# data_provenance.md
cat > logs/data_provenance.md << 'PROV'
# Data Provenance

| Dataset | Source | Version | Access date | DOI/URL | License | Checksum |
|---------|--------|---------|-------------|---------|---------|---------|
PROV

echo "Project structure created in: $PROJECT/"
echo "Next steps:"
echo "  1. Fill in params.yaml"
echo "  2. Add raw data to $PROJECT/data/raw/"
echo "  3. Record provenance in logs/data_provenance.md"
