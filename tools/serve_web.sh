#!/usr/bin/env bash
# Serves the exported Web build (build/web) at http://localhost:8060.
#
#   tools/serve_web.sh               # this computer only
#   tools/serve_web.sh --lan         # also reachable from other devices in the network
#   tools/serve_web.sh --port=9000
#
# Browsers allow camera and clipboard only on https:// and on localhost, so
# pairing can be tested on this computer but not from a phone; use the
# deployed build for that (see README).
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$GODOT" --headless --path "$PROJECT_DIR" --script res://tools/serve_web.gd -- "$@"
