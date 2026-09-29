param(
    [Parameter(Mandatory = $true)][string]$PckPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$pck = (Resolve-Path -LiteralPath $PckPath).Path
$policy = Join-Path $root 'addons/share_export/release_policy.gd'
$checker = Join-Path $PSScriptRoot 'verify-release-package.gd'
$logDir = Join-Path $root '.godot-toolchain/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$consoleLog = Join-Path $logDir 'release-package-console.log'
$engineLog = Join-Path $logDir 'release-package.log'
$ErrorActionPreference = 'Continue'
& $godot --headless --main-pack $pck --script $checker --log-file $engineLog -- "--policy=$policy" *> $consoleLog
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0 -or -not (Select-String -LiteralPath $consoleLog -SimpleMatch 'RELEASE_PACKAGE: PASS')) {
    throw "Release package check failed. Export again without -SkipExport. See $consoleLog"
}
$errors = Select-String -LiteralPath $engineLog -Pattern 'SCRIPT ERROR:|ERROR:' |
    Where-Object { $_.Line -notmatch 'ERROR: Failed to read the root certificate store\.|ERROR: Could not create ObjectDB Snapshots directory: user://' }
if ($errors) { throw "Release package reported errors. See $engineLog" }
Write-Host "Release package verified: $pck"
