#!/usr/bin/env bash
# Runs all unit tests headless. Exit code 0 = all passed.
#
#   tools/run_tests.sh                     # everything
#   tools/run_tests.sh --filter=registry   # tests whose file or name contains "registry"
#   tools/run_tests.sh --quiet             # only failures and the summary
#
# Uses the Godot 4.7 executable named by the GODOT environment variable, or
# "godot" from the PATH.
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Import first: scripts find each other's class_name through the import cache,
# which does not exist in a fresh clone.
"$GODOT" --headless --path "$PROJECT_DIR" --import --quiet

exec "$GODOT" --headless --path "$PROJECT_DIR" res://tests/test_runner.tscn -- "$@"
