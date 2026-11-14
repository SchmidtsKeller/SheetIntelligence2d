# Runs all unit tests headless. Exit code 0 = all passed.
#
#   tools\run_tests.ps1                     # everything
#   tools\run_tests.ps1 --filter=registry   # tests whose file or name contains "registry"
#   tools\run_tests.ps1 --quiet             # only failures and the summary
#
# Uses the Godot 4.7 executable named by the GODOT environment variable, or
# "godot" from the PATH. On Windows, point GODOT at the *_console.exe so the
# output shows up in the terminal.

$ErrorActionPreference = "Stop"

$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$projectDir = Split-Path -Parent $PSScriptRoot

# Import first: scripts find each other's class_name through the import cache,
# which does not exist in a fresh clone.
& $godot --headless --path $projectDir --import --quiet
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $godot --headless --path $projectDir res://tests/test_runner.tscn -- @args
exit $LASTEXITCODE
