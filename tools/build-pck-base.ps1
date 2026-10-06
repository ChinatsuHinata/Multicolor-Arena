param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
if ($project -cnotmatch '(?m)^config/version="1\.2\.7\.1"\r?$') {
    throw 'The fixed-base PCKs can only be exported from version 1.2.7.1.'
}
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$output = Join-Path $root 'builds/pck-base'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $godot --headless --path $root --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
foreach ($platform in @('windows', 'android')) {
    $preset = if ($platform -eq 'windows') { 'Windows Desktop' } else { 'Android' }
    $path = Join-Path $output "1.2.7.1-$platform.pck"
    & $godot --headless --path $root --export-pack $preset $path
    if ($LASTEXITCODE -ne 0) { throw "Fixed-base $platform export failed." }
    & $godot --headless --main-pack $path --script (Join-Path $root 'tools/check-pck-target-version.gd') -- '1.2.7.1'
    if ($LASTEXITCODE -ne 0) { throw "Fixed-base $platform pack has the wrong version." }
    & $godot --headless --main-pack $path --script (Join-Path $root 'tools/check-pck-base-content.gd')
    if ($LASTEXITCODE -ne 0) { throw "Fixed-base $platform pack lacks update resources." }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "$platform fixed base: $path SHA-256 $hash"
}
