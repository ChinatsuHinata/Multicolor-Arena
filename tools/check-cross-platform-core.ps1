param(
    [Parameter(Mandatory = $true)][string]$PckPath,
    [Parameter(Mandatory = $true)][string]$ApkPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pck = (Resolve-Path -LiteralPath $PckPath).Path
$apkPath = (Resolve-Path -LiteralPath $ApkPath).Path
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$aapt = Join-Path $root '.godot-toolchain/android-sdk/build-tools/35.0.1/aapt.exe'
$manifestTool = Join-Path $PSScriptRoot 'manifest-release-core.gd'
foreach ($file in @($godot, $aapt, $manifestTool)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing verification tool: $file" }
}
& (Join-Path $PSScriptRoot 'sync-export-version.ps1') -CheckOnly
if (-not $?) { throw 'Export preset check failed.' }

$logDir = Join-Path $root '.godot-toolchain/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$consoleLog = Join-Path $logDir 'cross-platform-core-console.log'
$engineLog = Join-Path $logDir 'cross-platform-core-engine.log'
$ErrorActionPreference = 'Continue'
& $godot --headless --main-pack $pck --script $manifestTool --log-file $engineLog *> $consoleLog
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0) { throw "Could not inspect Windows PCK. See $consoleLog" }
$line = @(Get-Content -LiteralPath $consoleLog -Encoding UTF8 | Where-Object { $_.StartsWith('CORE_MANIFEST: ') })
if ($line.Count -ne 1) { throw "PCK core manifest was not produced. See $consoleLog" }
$pc = $line[0].Substring('CORE_MANIFEST: '.Length) | ConvertFrom-Json
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
$version = [regex]::Match($project, '(?m)^config/version="([^"]+)"\r?$').Groups[1].Value
if ([string]::IsNullOrEmpty($version) -or $pc.version -cne $version) {
    throw "Windows PCK version $($pc.version) differs from project version $version."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($apkPath)
try {
    $apkData = @{}
    $apkScripts = @()
    foreach ($entry in $zip.Entries) {
        if (-not $entry.FullName.StartsWith('assets/', [StringComparison]::Ordinal)) { continue }
        $relative = $entry.FullName.Substring('assets/'.Length)
        $isData = $relative -match '^(cards|data|net)/.*\.json$' -or $relative -eq 'data/account_public.pem'
        $isScript = $relative -match '^scripts/(rules|ai)/.*\.gdc$' -or
            $relative -in @('scripts/card_database.gdc', 'scripts/deck_store.gdc', 'scripts/deck_rule_set.gdc', 'scripts/account_client.gdc', 'scripts/account_session_store.gdc', 'scripts/deck_plaza_client.gdc', 'scripts/deck_plaza.gdc', 'scripts/main.gdc')
        if ($isData) {
            if ($apkData.ContainsKey($relative)) { throw "Duplicate core data in APK: $relative" }
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $apkData[$relative] = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
            finally { $sha.Dispose(); $stream.Dispose() }
        } elseif ($isScript) {
            $apkScripts += $relative
        }
    }
} finally { $zip.Dispose() }

$pcData = @{}
foreach ($property in $pc.data.PSObject.Properties) { $pcData[$property.Name] = [string]$property.Value }
foreach ($required in @('data/bundled_decks.json', 'net/rules_manifest.json', 'data/account_public.pem')) {
    if (-not $pcData.ContainsKey($required)) { throw "Windows PCK is missing $required" }
}
if (@($pcData.Keys | Where-Object { $_ -like 'cards/*.json' }).Count -eq 0) {
    throw 'Windows PCK has no card definitions.'
}
if ($pcData.Count -ne $apkData.Count) {
    throw "Core data file count differs: Windows $($pcData.Count), Android $($apkData.Count)."
}
foreach ($name in $pcData.Keys) {
    if (-not $apkData.ContainsKey($name)) { throw "Android APK is missing core data: $name" }
    if ($pcData[$name] -cne $apkData[$name]) { throw "Core data differs between Windows and Android: $name" }
}
$pcScripts = @($pc.scripts | Sort-Object -Unique)
$apkScripts = @($apkScripts | Sort-Object -Unique)
foreach ($required in @('scripts/card_database.gdc', 'scripts/deck_store.gdc', 'scripts/rules/duel_engine.gdc', 'scripts/account_client.gdc', 'scripts/account_session_store.gdc', 'scripts/deck_plaza_client.gdc', 'scripts/deck_plaza.gdc', 'scripts/main.gdc')) {
    if ($required -notin $pcScripts) { throw "Windows PCK is missing core script: $required" }
}
$scriptDiff = Compare-Object -ReferenceObject $pcScripts -DifferenceObject $apkScripts
if ($scriptDiff) { throw "Core script lists differ between Windows and Android: $($scriptDiff | Out-String)" }

if (-not $apkPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'APK must stay inside the project so Android SDK tools can read its relative path.'
}
$relativeApk = $apkPath.Substring($root.Length + 1)
Push-Location $root
try {
    $ErrorActionPreference = 'Continue'
    $badging = @(& $aapt dump badging $relativeApk)
    $aaptExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
} finally { Pop-Location }
if ($aaptExit -ne 0) { throw "Cannot read Android APK version: $apkPath" }
$package = @($badging | Where-Object { $_ -match '^package: ' } | Select-Object -First 1)
$apkVersion = if ($package.Count -eq 1) { [regex]::Match($package[0], "versionName='([^']+)'").Groups[1].Value } else { '' }
$apkCode = if ($package.Count -eq 1) { [regex]::Match($package[0], "versionCode='([^']+)'").Groups[1].Value } else { '' }
$preset = Get-Content -LiteralPath (Join-Path $root 'export_presets.cfg') -Raw -Encoding UTF8
$expectedCode = [regex]::Match($preset, '(?m)^version/code=(\d+)\r?$').Groups[1].Value
if ($apkVersion -cne $version -or $apkCode -cne $expectedCode) {
    throw "Android APK version differs: got $apkVersion (code $apkCode); expected $version (code $expectedCode)."
}
Write-Host "Cross-platform core verified: $version; $($pcData.Count) identical data files; $($pcScripts.Count) core scripts on each platform."
