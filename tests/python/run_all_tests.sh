#!/bin/bash
# run_all_tests.sh
# Run the full pytest suite from the project root.
# Usage: bash tests/python/run_all_tests.sh [--fast]

set -e
cd "$(dirname "$0")/../.."

if ! python3 -c "import pytest" 2>/dev/null; then
  echo "pytest not installed. pip install pytest"
  exit 1
fi

EXTRA_ARGS=""
if [[ "$1" == "--fast" ]]; then
  EXTRA_ARGS="-m 'not slow and not integration'"
fi

echo "=== Running pytest suite ==="
python3 -m pytest tests/python/ \
  --tb=short \
  -v \
  --color=yes \
  $EXTRA_ARGS \
  "$@"
