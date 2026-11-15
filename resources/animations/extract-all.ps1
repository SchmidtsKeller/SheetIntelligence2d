$RootPath = "."

Get-ChildItem -Path $RootPath -Filter "*.zip" -Recurse -File | ForEach-Object {
    $Destination = Join-Path -Path $_.DirectoryName -ChildPath $_.BaseName

    Write-Host "Extracting '$($_.Name)' -> '$Destination'"

    try {
        Expand-Archive -LiteralPath $_.FullName -DestinationPath $Destination -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to extract '$($_.FullName)': $_"
    }
}