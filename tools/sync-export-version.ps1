param([switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
$match = [regex]::Match($project, '(?m)^config/version="([^"]+)"\r?$')
if (-not $match.Success) { throw 'project.godot is missing config/version.' }
$version = $match.Groups[1].Value
$numberMatch = [regex]::Match($version, '^(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?$')
if (-not $numberMatch.Success) {
    throw "Export version must have three or four numeric components and an optional prerelease suffix: $version"
}
$parts = @(1..4 | ForEach-Object { $numberMatch.Groups[$_].Value }) | ForEach-Object {
    if ([string]::IsNullOrEmpty($_)) { 0 } else { [int]$_ }
}
if ($parts[0] -gt 2099 -or $parts[1] -gt 99 -or $parts[2] -gt 99 -or $parts[3] -gt 99) {
    throw "Version components are too large for Android versionCode: $version"
}
$code = [int](1000000 * $parts[0] + 10000 * $parts[1] + 100 * $parts[2] + $parts[3])
if ($code -le 0 -or $code -gt [int]::MaxValue) { throw "Invalid Android versionCode for $version" }
$fileVersion = ($parts -join '.')

$path = Join-Path $root 'export_presets.cfg'
$original = Get-Content -LiteralPath $path -Raw -Encoding UTF8
$contents = $original
function Set-Option([string]$Name, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '=.*$'
    $found = [regex]::Matches($script:contents, $pattern)
    if ($found.Count -ne 1) { throw "Expected one $Name in export_presets.cfg; found $($found.Count)" }
    $script:contents = [regex]::Replace($script:contents, $pattern, "$Name=$Value")
}
Set-Option 'application/file_version' ('"' + $fileVersion + '"')
Set-Option 'application/product_version' ('"' + $fileVersion + '"')
Set-Option 'version/code' $code
Set-Option 'version/name' ('"' + $version + '"')

$presets = [regex]::Matches($contents, '(?ms)^\[preset\.\d+\]\r?\n.*?(?=^\[|\z)')
if ($presets.Count -ne 2) { throw 'Expected Windows and Android export presets.' }
$windows = @($presets | Where-Object { $_.Value -match '(?m)^name="Windows Desktop"\r?$' })
$android = @($presets | Where-Object { $_.Value -match '(?m)^name="Android"\r?$' })
if ($windows.Count -ne 1 -or $android.Count -ne 1) { throw 'Missing Windows or Android export preset.' }
foreach ($option in @('export_filter', 'include_filter', 'exclude_filter')) {
    $pattern = '(?m)^' + $option + '=(.*)\r?$'
    $pcValue = [regex]::Match($windows[0].Value, $pattern)
    $apkValue = [regex]::Match($android[0].Value, $pattern)
    if (-not $pcValue.Success -or -not $apkValue.Success -or $pcValue.Groups[1].Value -cne $apkValue.Groups[1].Value) {
        throw "Windows and Android $option differ. Keep both export resource lists identical."
    }
}

if ($CheckOnly -and $contents -cne $original) {
    throw "Export preset versions differ from project.godot ($version). Run the build without -CheckOnly."
}
if (-not $CheckOnly -and $contents -cne $original) {
    [IO.File]::WriteAllText($path, $contents, [Text.UTF8Encoding]::new($false))
    Write-Host "Synchronized export versions: Windows $fileVersion; Android $version (code $code)"
}
Write-Host "Export presets agree on resources and version $version."
