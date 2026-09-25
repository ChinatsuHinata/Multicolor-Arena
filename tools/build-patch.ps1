param(
    [Parameter(Mandatory = $true)][string]$FromVersion,
    [string]$BaseDir,
    [switch]$SkipExport,
    [string]$IsccPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw
$match = [regex]::Match($project, '(?m)^config/version="([^"]+)"')
if (-not $match.Success) { throw 'project.godot is missing config/version.' }
$toVersion = $match.Groups[1].Value
foreach ($version in @($FromVersion, $toVersion)) {
    if ($version -cnotmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') { throw "Unsafe version: $version" }
}
if ($FromVersion -eq $toVersion) { throw 'Patch source and target versions must differ.' }
function Get-NumericVersion([string]$value) {
    $core = ($value -split '[-+]', 2)[0]
    if ($core -notmatch '^[0-9]+(\.[0-9]+){0,3}$') { throw "Version is not comparable: $value" }
    $parts = @($core.Split('.') | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 4) { $parts += 0 }
    return [version]::new($parts[0], $parts[1], $parts[2], $parts[3])
}
if ((Get-NumericVersion $FromVersion) -ge (Get-NumericVersion $toVersion)) {
    throw "Patch target version must be newer than $FromVersion."
}

if (-not $BaseDir) { $BaseDir = Join-Path $root "builds/installer-staging/$FromVersion" }
$oldDir = (Resolve-Path -LiteralPath $BaseDir).Path
$newDir = Join-Path $root "builds/installer-staging/$toVersion"
$patchDir = Join-Path $root "builds/patch-staging/$FromVersion-to-$toVersion"
$outputDir = Join-Path $root 'builds/installers'
$installer = Join-Path $outputDir "MulticolorArena-$FromVersion-to-$toVersion-win64-patch.exe"

if (-not $SkipExport) {
    & (Join-Path $PSScriptRoot 'build-windows.ps1') -OutputPath "builds/installer-staging/$toVersion/MulticolorArena.exe"
    if (-not $?) { throw 'Godot export failed.' }
}
foreach ($dir in @($oldDir, $newDir)) {
    foreach ($name in @('MulticolorArena.exe', 'MulticolorArena.pck')) {
        $file = Join-Path $dir $name
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing export file: $file" }
        if ((Get-Item -LiteralPath $file).Length -eq 0) { throw "Empty export file: $file" }
    }
}

if (-not $IsccPath) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) { $IsccPath = $command.Source }
}
if (-not $IsccPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        (Join-Path $root '.godot-toolchain/innosetup/ISCC.exe')
    )
    $IsccPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $IsccPath -or -not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
    throw 'ISCC.exe not found. Install Inno Setup 6 or 7, or pass -IsccPath.'
}

New-Item -ItemType Directory -Force -Path $patchDir, $outputDir | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'patch-engine.cs'), (Join-Path $PSScriptRoot 'apply-patch.ps1') -Destination $patchDir -Force
$bundle = Join-Path $patchDir 'PatchBundle.bin'
Add-Type -Path (Join-Path $PSScriptRoot 'patch-engine.cs')
try {
    [ArenaPatch]::Create($oldDir, $newDir, $bundle, $FromVersion, $toVersion)
    # Apply to a disposable copy first. This checks the exact bytes and patch reader.
    $testDir = Join-Path $patchDir 'verify'
    New-Item -ItemType Directory -Force -Path $testDir | Out-Null
    foreach ($name in @('MulticolorArena.exe', 'MulticolorArena.pck')) {
        Copy-Item -LiteralPath (Join-Path $oldDir $name) -Destination (Join-Path $testDir $name) -Force
    }
    [ArenaPatch]::Apply($testDir, $bundle, $FromVersion, $toVersion)
    foreach ($name in @('MulticolorArena.exe', 'MulticolorArena.pck')) {
        $expected = (Get-FileHash -LiteralPath (Join-Path $newDir $name) -Algorithm SHA256).Hash
        $actual = (Get-FileHash -LiteralPath (Join-Path $testDir $name) -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw "Patch verification failed: $name" }
    }
}
finally {
    $testPath = [IO.Path]::GetFullPath((Join-Path $patchDir 'verify'))
    if (-not $testPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe verification path: $testPath"
    }
    if (Test-Path -LiteralPath $testPath) {
        Remove-Item -LiteralPath $testPath -Recurse -Force
    }
}

Write-Host "Compiling patch installer from $FromVersion to $toVersion"
& $IsccPath "/DFromVersion=$FromVersion" "/DToVersion=$toVersion" "/DPatchDir=$patchDir" "/DInstallerOutputDir=$outputDir" (Join-Path $PSScriptRoot 'patch-installer.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw "Patch installer was not created: $installer" }
Write-Host "Patch data: $bundle ($((Get-Item -LiteralPath $bundle).Length) bytes)"
Write-Host "Patch installer: $installer ($((Get-Item -LiteralPath $installer).Length) bytes)"
Get-FileHash -LiteralPath $installer -Algorithm SHA256 | Format-List Hash,Path
