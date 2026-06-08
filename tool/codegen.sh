#!/usr/bin/env bash
# Drift codegen. Run after editing tables.dart or @DataClassName annotations.
# Usage:
#   ./tool/codegen.sh            # one-shot build
#   ./tool/codegen.sh --watch    # rebuild on save
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--watch" ]]; then
  dart run build_runner watch --delete-conflicting-outputs
else
  dart run build_runner build --delete-conflicting-outputs
fi
