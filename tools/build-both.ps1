param(
    [switch]$Installer,
    [string]$FromVersion
)

$ErrorActionPreference = 'Stop'
if ($Installer -and $FromVersion) { throw 'Choose either -Installer or -FromVersion.' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
$match = [regex]::Match($project, '(?m)^config/version="([^"]+)"\r?$')
if (-not $match.Success) { throw 'project.godot is missing config/version.' }
$version = $match.Groups[1].Value
if ($version -cnotmatch '^[0-9A-Za-z][0-9A-Za-z._-]*$') { throw "Unsafe version: $version" }

$pcRelative = "builds/installer-staging/$version/MulticolorArena.exe"
$pck = Join-Path $root "builds/installer-staging/$version/MulticolorArena.pck"
$apkRelative = "builds/Android-debug/MulticolorArena-$version-debug.apk"
$apk = Join-Path $root $apkRelative

& (Join-Path $PSScriptRoot 'build-windows.ps1') -OutputPath $pcRelative
if (-not $?) { throw 'Windows export failed.' }
& (Join-Path $PSScriptRoot 'build-android.ps1') -OutputPath $apkRelative
if (-not $?) { throw 'Android export failed.' }
& (Join-Path $PSScriptRoot 'check-cross-platform-core.ps1') -PckPath $pck -ApkPath $apk
if (-not $?) { throw 'Cross-platform core verification failed.' }

if ($Installer) {
    & (Join-Path $PSScriptRoot 'build-installer.ps1') -SkipExport
    if (-not $?) { throw 'Windows installer packaging failed.' }
} elseif ($FromVersion) {
    & (Join-Path $PSScriptRoot 'build-patch.ps1') -FromVersion $FromVersion -SkipExport
    if (-not $?) { throw 'Windows patch packaging failed.' }
}
Write-Host "Matching Windows and Android builds are ready for version $version."
Write-Host "Windows PCK: $pck"
Write-Host "Android APK: $apk"
