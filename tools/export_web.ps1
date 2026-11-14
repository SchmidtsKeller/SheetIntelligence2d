# Exports the Web build to build\web, ready to be served as a static site.
#
#   tools\export_web.ps1            # release build
#   tools\export_web.ps1 --debug    # debug build (readable errors in the browser console)
#   tools\export_web.ps1 --serve    # export, then serve at http://localhost:8060
#
# Needs Godot 4.7 with the Web export templates installed (Editor > Manage
# Export Templates). Uses the executable named by the GODOT environment
# variable, or "godot" from the PATH. On Windows, point GODOT at the
# *_console.exe so the output shows up in the terminal.

$ErrorActionPreference = "Stop"

$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$projectDir = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectDir "build"
$outDir = Join-Path $buildDir "web"

$mode = "release"
$serve = $false
foreach ($argument in $args) {
	switch ($argument) {
		"--debug" { $mode = "debug" }
		"--serve" { $serve = $true }
		default { Write-Error "Unknown option: $argument"; exit 2 }
	}
}

if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Force $outDir | Out-Null
# Keeps the editor from importing the exported files as project resources.
$gdignore = Join-Path $buildDir ".gdignore"
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }

& $godot --headless --path $projectDir --import --quiet
& $godot --headless --path $projectDir "--export-$mode" "Web" (Join-Path $outDir "index.html")

# Godot can exit with 0 although nothing was exported (e.g. missing templates).
foreach ($file in @("index.html", "index.js", "index.wasm", "index.pck")) {
	$path = Join-Path $outDir $file
	if (-not (Test-Path $path) -or (Get-Item $path).Length -eq 0) {
		Write-Host "Export failed: $path is missing."
		Write-Host "Are the Web export templates for this Godot version installed?"
		exit 1
	}
}

# Static files that ship next to the game (see web\page.js).
Copy-Item -Recurse -Force -Exclude ".gdignore" (Join-Path $projectDir "web\*") $outDir

Write-Host "Web build ($mode) exported to $outDir"

if ($serve) {
	& (Join-Path $PSScriptRoot "serve_web.ps1")
	exit $LASTEXITCODE
}
