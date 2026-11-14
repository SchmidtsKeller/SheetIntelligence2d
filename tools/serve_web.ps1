# Serves the exported Web build (build\web) at http://localhost:8060.
#
#   tools\serve_web.ps1               # this computer only
#   tools\serve_web.ps1 --lan         # also reachable from other devices in the network
#   tools\serve_web.ps1 --port=9000
#
# Browsers allow camera and clipboard only on https:// and on localhost, so
# pairing can be tested on this computer but not from a phone; use the
# deployed build for that (see README).

$ErrorActionPreference = "Stop"

$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$projectDir = Split-Path -Parent $PSScriptRoot

& $godot --headless --path $projectDir --script res://tools/serve_web.gd -- @args
exit $LASTEXITCODE
