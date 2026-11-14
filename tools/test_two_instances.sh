#!/usr/bin/env bash
# Runs a self-check with two real instances on this computer: a host and a
# guest that connect over the desktop dev transport. Exit code 0 = both
# instances saw everything they expected.
#
#   tools/test_two_instances.sh            # the session framework
#   tools/test_two_instances.sh monster    # the Monster against the Sheepherder
#   tools/test_two_instances.sh companions # the Shepherd Dog and the Allied Bat
#   tools/test_two_instances.sh --net-latency=80 --net-jitter=40 --net-loss=10
#   tools/test_two_instances.sh monster --net-latency=80 --net-jitter=40 --net-loss=10
#
# Uses the Godot 4.7 executable named by the GODOT environment variable, or
# "godot" from the PATH.
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENE="res://systems/session/demo/net_selfcheck.tscn"
EXTRA=()
case "${1:-}" in
	session)
		shift
		;;
	monster)
		SCENE="res://entities/monster/sandbox/monster_selfcheck.tscn"
		shift
		;;
	companions)
		SCENE="res://entities/companions/sandbox/companion_selfcheck.tscn"
		EXTRA=(--perk=shepherd_dog,allied_bat)
		shift
		;;
	--* | "") ;;
	*)
		echo "Unknown check '$1'. Known checks: session, monster, companions." >&2
		exit 2
		;;
esac
PORT=$((20000 + RANDOM % 20000))
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

"$GODOT" --headless --path "$PROJECT_DIR" --import --quiet

"$GODOT" --headless --path "$PROJECT_DIR" "$SCENE" -- --host "--port=$PORT" ${EXTRA[@]+"${EXTRA[@]}"} "$@" > "$LOG_DIR/host.log" 2>&1 &
host_pid=$!
"$GODOT" --headless --path "$PROJECT_DIR" "$SCENE" -- --join "--port=$PORT" ${EXTRA[@]+"${EXTRA[@]}"} "$@" > "$LOG_DIR/guest.log" 2>&1 &
guest_pid=$!

wait "$host_pid"
host_exit=$?
wait "$guest_pid"
guest_exit=$?

grep -h "^SELFCHECK\|ERROR" "$LOG_DIR/host.log" "$LOG_DIR/guest.log"

if [ "$host_exit" -eq 0 ] && [ "$guest_exit" -eq 0 ]; then
	echo "RESULT: PASSED"
	exit 0
fi
echo "RESULT: FAILED (host exit code $host_exit, guest exit code $guest_exit)"
exit 1
