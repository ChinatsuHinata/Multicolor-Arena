param(
    [string]$OutputPath = 'builds/Windows-1.1.1-bugfixed/MulticolorArena.exe'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot 4.7.2 was not found: $godot"
}

$version = (& $godot --version).Trim()
if (-not $version.StartsWith('4.7.2.stable.')) {
    throw "Expected Godot 4.7.2 stable; found $version"
}

$output = [IO.Path]::GetFullPath((Join-Path $root $OutputPath))
if (-not $output.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must stay inside the project.'
}

$outputDir = Split-Path -Parent $output
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$logDir = Join-Path $root '.godot-toolchain/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$assetDir = Join-Path $root 'recourse/数据库'
$imageExtensions = @('.png', '.jpg', '.jpeg', '.webp')
$images = @(Get-ChildItem -LiteralPath $assetDir -File -Recurse) +
    @(Get-ChildItem -LiteralPath (Join-Path $root 'recourse') -File)
foreach ($image in $images) {
    if ($image.Extension.ToLowerInvariant() -notin $imageExtensions -or $image.Length -gt 300) { continue }
    $content = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($image.FullName))
    if ($content.StartsWith('version https://git-lfs.github.com/spec/v1')) {
        throw "Git LFS image is still a pointer: $($image.FullName)"
    }
}

Write-Host "Importing with $version"
$ErrorActionPreference = 'Continue'
& $godot --headless --path $root --editor --import --log-file (Join-Path $logDir 'import.log') *> (Join-Path $logDir 'import-console.log')
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed. See $logDir/import-console.log"
}
$importErrors = Select-String -LiteralPath (Join-Path $logDir 'import.log') -Pattern 'SCRIPT ERROR:|ERROR:' |
    Where-Object { $_.Line -notmatch 'ERROR: Failed to read the root certificate store\.|ERROR: Could not create ObjectDB Snapshots directory: user://' }
if ($importErrors) {
    throw "Godot import reported errors. See $logDir/import.log"
}
$importFiles = @(Get-ChildItem -LiteralPath $assetDir -Filter '*.import' -File -Recurse) +
    @(Get-ChildItem -LiteralPath (Join-Path $root 'recourse') -Filter '*.import' -File)
$invalidImport = $importFiles | Select-String -Pattern 'valid=false' | Select-Object -First 1
if ($invalidImport) {
    throw "An image failed to import: $($invalidImport.Path)"
}

Write-Host "Exporting Windows Desktop to $output"
$ErrorActionPreference = 'Continue'
& $godot --headless --path $root --export-release 'Windows Desktop' $output --log-file (Join-Path $logDir 'export.log') *> (Join-Path $logDir 'export-console.log')
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed. See $logDir/export-console.log"
}
if (-not (Test-Path -LiteralPath $output)) {
    throw "Export did not create $output"
}
$pck = [IO.Path]::ChangeExtension($output, '.pck')
if (-not (Test-Path -LiteralPath $pck)) {
    throw "Export did not create $pck"
}
$exportErrors = Select-String -LiteralPath (Join-Path $logDir 'export.log') -Pattern 'SCRIPT ERROR:|ERROR:' |
    Where-Object { $_.Line -notmatch 'ERROR: Failed to read the root certificate store\.|ERROR: Could not create ObjectDB Snapshots directory: user://' }
if ($exportErrors) {
    throw "Godot export reported errors. See $logDir/export.log"
}
Write-Host "Built: $output"
Write-Host "Built: $pck"
