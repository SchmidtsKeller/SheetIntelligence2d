#!/usr/bin/env bash
# Imports the project and fails if Godot reports an error while doing so:
# a script that does not parse, a resource that does not load, a broken scene.
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
