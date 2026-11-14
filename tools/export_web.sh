#!/usr/bin/env bash
# Exports the Web build to build/web, ready to be served as a static site.
#
#   tools/export_web.sh            # release build
#   tools/export_web.sh --debug    # debug build (readable errors in the browser console)
#   tools/export_web.sh --serve    # export, then serve at http://localhost:8060
#
# Needs Godot 4.7 with the Web export templates installed (Editor > Manage
# Export Templates). Uses the executable named by the GODOT environment
# variable, or "godot" from the PATH.
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
OUT_DIR="$BUILD_DIR/web"

mode="release"
serve="false"
for argument in "$@"; do
	case "$argument" in
		--debug) mode="debug" ;;
		--serve) serve="true" ;;
		*) echo "Unknown option: $argument" >&2; exit 2 ;;
	esac
done

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
# Keeps the editor from importing the exported files as project resources.
touch "$BUILD_DIR/.gdignore"

"$GODOT" --headless --path "$PROJECT_DIR" --import --quiet
"$GODOT" --headless --path "$PROJECT_DIR" "--export-$mode" "Web" "$OUT_DIR/index.html"

# Godot can exit with 0 although nothing was exported (e.g. missing templates).
for file in index.html index.js index.wasm index.pck; do
	if [ ! -s "$OUT_DIR/$file" ]; then
		echo "Export failed: $OUT_DIR/$file is missing." >&2
		echo "Are the Web export templates for this Godot version installed?" >&2
		exit 1
	fi
done

# Static files that ship next to the game (see web/page.js).
cp -R "$PROJECT_DIR"/web/* "$OUT_DIR"/

echo "Web build ($mode) exported to $OUT_DIR"

if [ "$serve" = "true" ]; then
	exec "$PROJECT_DIR/tools/serve_web.sh"
fi
