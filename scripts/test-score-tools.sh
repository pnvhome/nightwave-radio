#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
cd "$SCRATCH"
git apply --include='src/yue2_instrumental/*' \
  --include='tests/test_yue2_instrumental.py' \
  --include='tests/test_yue2_arrangement.py' \
  "$ROOT/patches/mlx-serve-instrumental.patch"
python3 tests/test_yue2_instrumental.py
python3 tests/test_yue2_arrangement.py
