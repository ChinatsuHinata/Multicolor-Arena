param(
    [string]$FromVersion,
    [string]$BaseWindowsPck,
    [string]$BaseAndroidPck,
    [switch]$UseInstalledWindowsPck,
    [string]$WindowsInstallDir = 'D:\Program Files (x86)\MulticolorArena',
    [string]$InstalledPatchDir,
    [ValidateSet('windows', 'android')][string[]]$Platforms = @('windows', 'android'),
    [string]$TestVersion,
    [string]$TestKeyPath,
    [string]$OutputDir,
    [switch]$SkipExport
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'pck-build-support.ps1')
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
$match = [regex]::Match($project, '(?m)^config/version="([^"]+)"')
if (-not $match.Success) { throw 'project.godot is missing config/version.' }
$toVersion = $match.Groups[1].Value
if ($UseInstalledWindowsPck) {
    if ($BaseWindowsPck) { throw 'Use either -UseInstalledWindowsPck or -BaseWindowsPck.' }
    $installed = Get-InstalledPckSource -Root $root -WindowsInstallDir $WindowsInstallDir -FromVersion $FromVersion -InstalledPatchDir $InstalledPatchDir
    $FromVersion = $installed.Version
    $BaseWindowsPck = $installed.Path
}
if (-not $FromVersion) { $FromVersion = '1.2.7.1' }
if ($TestVersion) {
    $toVersion = $TestVersion
    if (-not $TestKeyPath -or -not $OutputDir) { throw 'Test builds require an isolated -TestKeyPath and -OutputDir.' }
    $testRoot = [IO.Path]::GetFullPath((Join-Path $root 'builds/pck-tests')) + [IO.Path]::DirectorySeparatorChar
    foreach ($testPath in @($TestKeyPath, $OutputDir)) {
        if (-not [IO.Path]::GetFullPath($testPath).StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Test keys and output must stay inside builds/pck-tests/.'
        }
    }
} elseif ($TestKeyPath -or $OutputDir) { throw 'Custom key/output are only supported with -TestVersion.' }
foreach ($value in @($FromVersion, $toVersion)) {
    if ($value -cnotmatch '^[0-9]+(?:\.[0-9]+){2,3}$') { throw "Invalid version: $value" }
}
$sourceParts = @($FromVersion.Split('.') | ForEach-Object { [int]$_ })
$targetParts = @($toVersion.Split('.') | ForEach-Object { [int]$_ })
while ($sourceParts.Count -lt 4) { $sourceParts += 0 }
while ($targetParts.Count -lt 4) { $targetParts += 0 }
$sourceVersion = [version]::new($sourceParts[0], $sourceParts[1], $sourceParts[2], $sourceParts[3])
$targetVersion = [version]::new($targetParts[0], $targetParts[1], $targetParts[2], $targetParts[3])
if ($targetVersion -le $sourceVersion) { throw 'Target version must be newer than source version.' }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot not found: $godot" }
if (-not $TestVersion -and -not (Test-Path -LiteralPath (Join-Path $root '.godot-toolchain/release-signing.key') -PathType Leaf)) {
    throw 'Existing release signing key is required: .godot-toolchain/release-signing.key'
}

if (-not $OutputDir) { $OutputDir = Join-Path $root "builds/pck-patches/$FromVersion-to-$toVersion" }
if (-not $BaseWindowsPck) { $BaseWindowsPck = Join-Path $root "builds/pck-base/$FromVersion-windows.pck" }
if (-not $BaseAndroidPck) { $BaseAndroidPck = Join-Path $root "builds/pck-base/$FromVersion-android.pck" }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$exportRoot = $root
if ($TestVersion -and -not $SkipExport) {
    $exportRoot = Join-Path $OutputDir 'TEST_ONLY-project'
    Copy-PckTestProject -Root $root -Destination $exportRoot -Version $TestVersion -PublicKeyPath (Join-Path (Split-Path -Parent $TestKeyPath) 'test-public.pem')
}
if (-not $SkipExport) {
    foreach ($platform in $Platforms) {
        $base = if ($platform -eq 'windows') { $BaseWindowsPck } else { $BaseAndroidPck }
        if (-not (Test-Path -LiteralPath $base -PathType Leaf)) { throw "Source-version full PCK missing: $base" }
        & $godot --headless --log-file (Join-Path $OutputDir "check-base-$platform.log") --main-pack $base --script (Join-Path $root 'tools/check-pck-target-version.gd') -- $FromVersion
        if ($LASTEXITCODE -ne 0) { throw "Base PCK is not $FromVersion : $base" }
    }
    & $godot --headless --log-file (Join-Path $OutputDir 'import.log') --path $exportRoot --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot resource import failed.' }
}
foreach ($platform in $Platforms) {
    $preset = if ($platform -eq 'windows') { 'Windows Desktop' } else { 'Android' }
    $name = "MulticolorArena-$FromVersion-to-$toVersion-$platform.pck"
    $raw = Join-Path $outputDir "raw-$platform.pck"
    $final = Join-Path $outputDir $name
    $payloadPath = Join-Path $outputDir "payload-$platform.json"
    $signedPath = Join-Path $outputDir "signed-$platform.json"
    if (-not $SkipExport) {
        $base = if ($platform -eq 'windows') { $BaseWindowsPck } else { $BaseAndroidPck }
        & $godot --headless --log-file (Join-Path $OutputDir "export-$platform.log") --path $exportRoot --export-patch $preset $raw --patches $base
        if ($LASTEXITCODE -ne 0) { throw "$platform PCK export failed." }
        Assert-PckExportLog -Path (Join-Path $OutputDir "export-$platform.log") -Stage "$platform patch export"
        if ((Get-Item -LiteralPath $raw).Length -ge (Get-Item -LiteralPath $base).Length) {
            throw "$platform patch is not smaller than the source PCK; inspect export filters and base files."
        }
    }
    if (-not (Test-Path -LiteralPath $raw -PathType Leaf) -or (Get-Item -LiteralPath $raw).Length -eq 0) {
        throw "Missing exported $platform PCK: $raw"
    }
    & $godot --headless --log-file (Join-Path $OutputDir "check-target-$platform.log") --main-pack $raw --script (Join-Path $root 'tools/check-pck-target-version.gd') -- $toVersion
    if ($LASTEXITCODE -ne 0) { throw "$platform PCK contains the wrong target version." }
    $payload = [ordered]@{
        format = 'multicolor:arena/pck-patch-1'
        game = 'multicolor:arena'
        platform = $platform
        from = $FromVersion
        to = $toVersion
        sha256 = (Get-FileHash -LiteralPath $raw -Algorithm SHA256).Hash.ToLowerInvariant()
        size = (Get-Item -LiteralPath $raw).Length
    }
    if ($TestVersion) { $payload.test_only = $true }
    [IO.File]::WriteAllText($payloadPath, ($payload | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    $signArgs = @($payloadPath, $signedPath)
    if ($TestVersion) { $signArgs += $TestKeyPath }
    & $godot --headless --log-file (Join-Path $OutputDir "sign-$platform.log") --path $root --script (Join-Path $root 'tools/sign-update-manifest.gd') -- @signArgs
    if ($LASTEXITCODE -ne 0) { throw "$platform patch signing failed." }
    $header = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($signedPath, [Text.Encoding]::UTF8))
    if ($header.Length -gt 4084) { throw 'Signed PCK header exceeds 4096 bytes.' }
    $output = [IO.File]::Open($final, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    try {
        $writer = [IO.BinaryWriter]::new($output)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('MCA-PCK1'))
        $writer.Write([uint32]$header.Length)
        $writer.Write($header)
        $writer.Write([byte[]]::new(4096 - 12 - $header.Length))
        $inputFile = [IO.File]::OpenRead($raw)
        try { $inputFile.CopyTo($output) } finally { $inputFile.Dispose() }
    } finally { $output.Dispose() }
    Write-Host "Created $final"
    if (-not $SkipExport) {
        # Preserve a full snapshot, not the delta, as the next release's export base.
        $snapshotDir = Join-Path $root 'builds/pck-base'
        if ($TestVersion) { $snapshotDir = Join-Path $OutputDir 'TEST_ONLY-snapshots' }
        New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null
        $snapshot = Join-Path $snapshotDir "$toVersion-$platform.pck"
        $snapshotTmp = Join-Path $outputDir "snapshot-$platform.pck"
        & $godot --headless --log-file (Join-Path $OutputDir "snapshot-$platform.log") --path $exportRoot --export-pack $preset $snapshotTmp
        if ($LASTEXITCODE -ne 0) { throw "$platform full snapshot export failed." }
        Assert-PckExportLog -Path (Join-Path $OutputDir "snapshot-$platform.log") -Stage "$platform snapshot export"
        & $godot --headless --log-file (Join-Path $OutputDir "check-snapshot-$platform.log") --main-pack $snapshotTmp --script (Join-Path $root 'tools/check-pck-target-version.gd') -- $toVersion
        if ($LASTEXITCODE -ne 0) { throw "$platform full snapshot has the wrong target version." }
        Move-Item -LiteralPath $snapshotTmp -Destination $snapshot -Force
    }
}
if ($UseInstalledWindowsPck) {
    $sourceInfo = [ordered]@{ installed_pck = $installed.RawPath; installed_patches = $installed.PatchFiles; effective_pck = $installed.Path; version = $FromVersion; sha256 = (Get-FileHash -LiteralPath $installed.Path -Algorithm SHA256).Hash.ToLowerInvariant(); target = $toVersion; test_only = [bool]$TestVersion }
    [IO.File]::WriteAllText((Join-Path $OutputDir 'source-release.json'), ($sourceInfo | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}
Write-Host "PCK patches for $FromVersion -> $toVersion are ready in $outputDir"
