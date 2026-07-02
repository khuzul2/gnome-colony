#!/usr/bin/env bash
# The lint/format gate (plan T0.3). Covers project code; the vendored
# addons/gut/ tree is third-party and excluded (gdlint via .gdlintrc,
# gdformat via explicit paths — it has no config file).
# Usage: ./lint.sh          check only (the gate; used by tester/CI)
#        ./lint.sh --write  apply formatting
set -euo pipefail

DIRS=(sim test presentation)

if [ "${1:-}" = "--write" ]; then
  gdformat "${DIRS[@]}"
else
  gdformat --check "${DIRS[@]}"
fi
gdlint .
echo "lint gate: clean"
