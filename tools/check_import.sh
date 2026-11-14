#!/usr/bin/env bash
# Imports the project and fails if Godot reports an error while doing so:
# a resource that cannot be imported, an autoload that does not load.
#
# This is not a full script check: the import does not compile every script.
# That is done by the unit test tests/unit/test_scripts_compile.gd, which loads
# all scripts inside the running project (tools/run_tests.sh).
#
#   tools/check_import.sh
#
# Uses the Godot 4.7 executable named by the GODOT environment variable, or
# "godot" from the PATH.
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# Godot reports import problems on the console but still exits with 0.
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$LOG" || true

if grep -E "^(SCRIPT ERROR|ERROR|USER ERROR)" "$LOG" > /dev/null; then
	echo "The import reported errors:"
	grep -E -A 2 "^(SCRIPT ERROR|ERROR|USER ERROR)" "$LOG"
	exit 1
fi

echo "Import finished without errors."
