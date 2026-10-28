param(
 [ValidateSet('Run', 'Test', 'Screenshots', 'Verify', 'OpenShots', 'All')]
 [string]$Action = 'Run'
)
# VS Code entry point for the Android battle layout prototype (experiments/android_layout_sim).
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$simDir = Join-Path $root 'experiments/android_layout_sim'
$scene = 'res://experiments/android_layout_sim/sim_main.tscn'
$test = 'tests/test_android_layout_sim.gd'

# The prototype hard-codes its screenshot folder (work/android-layout-sim/v<N>/); follow it.
$simSource = [IO.File]::ReadAllText((Join-Path $simDir 'sim_main.gd'))
$match = [regex]::Match($simSource, 'res://work/android-layout-sim/(v\d+)/')
$version = if ($match.Success) { $match.Groups[1].Value } else { 'latest' }
$shotDir = Join-Path $root "work/android-layout-sim/$version"

function Invoke-Godot([string[]]$GodotArgs) {
 if (-not (Test-Path -LiteralPath $godot)) { throw "Godot not found: $godot" }
 Write-Output "> Godot $($GodotArgs -join ' ')"
 & $godot @GodotArgs
 if ($LASTEXITCODE -ne 0) { throw "Godot exited with $LASTEXITCODE" }
}

function Invoke-Test([bool]$Windowed) {
 $godotArgs = @('--path', $root, '--script', $test)
 if (-not $Windowed) { $godotArgs = @('--headless') + $godotArgs }
 $log = Join-Path $env:TEMP 'android-layout-sim-test.log'
 Write-Output "> Godot $($godotArgs -join ' ')"
 # Godot writes warnings to stderr; keep them as log text instead of terminating errors.
 $ErrorActionPreference = 'Continue'
 & $godot @godotArgs 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log
 $code = $LASTEXITCODE
 $ErrorActionPreference = 'Stop'
 $summary = Select-String -LiteralPath $log -Pattern 'checks=\d+ failures=\d+' | Select-Object -Last 1
 if ($summary) { Write-Output "Result: $($summary.Matches[0].Value)" }
 if ($code -ne 0) { throw "Test exited with $code" }
 if (-not $summary) { throw 'Test finished without a checks=/failures= summary line' }
 if ($summary.Matches[0].Value -notmatch 'failures=0$') { throw 'Test reported failures' }
}

switch ($Action) {
 'Run' {
  Write-Output "Prototype $version - keys: O C V U M L G E H R, F12 saves to $shotDir"
  Invoke-Godot @('--path', $root, $scene)
 }
 'Test' { Invoke-Test $false }
 'Screenshots' {
  Invoke-Test $true
  $shots = @(Get-ChildItem -LiteralPath $shotDir -Filter '*.png' -File -ErrorAction SilentlyContinue)
  Write-Output "$($shots.Count) PNG files in $shotDir"
 }
 'Verify' {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $simDir 'verify_workspace.ps1')
  if ($LASTEXITCODE -ne 0) { throw "verify_workspace.ps1 exited with $LASTEXITCODE" }
 }
 'OpenShots' {
  New-Item -ItemType Directory -Force -Path $shotDir | Out-Null
  Invoke-Item -LiteralPath $shotDir
 }
 'All' {
  Invoke-Test $false
  Invoke-Test $true
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $simDir 'verify_workspace.ps1')
  if ($LASTEXITCODE -ne 0) { throw "verify_workspace.ps1 exited with $LASTEXITCODE" }
 }
}
