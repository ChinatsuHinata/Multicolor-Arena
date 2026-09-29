param([Parameter(Mandatory = $true)][string]$ExePath)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$exe = (Resolve-Path -LiteralPath $ExePath).Path
$pck = [IO.Path]::ChangeExtension($exe, '.pck')
if (-not (Test-Path -LiteralPath $pck)) { throw "Missing release PCK: $pck" }
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$probe = Join-Path $root ('work/release-deck-runtime/' + [guid]::NewGuid().ToString('N'))
$packLog = Join-Path $root 'work/pack-release-runtime.log'
& $godot --headless --path $root --script res://tools/pack-release-runtime.gd --log-file $packLog -- "--output=$probe"
if ($LASTEXITCODE -ne 0) { throw 'Could not prepare release runtime harness.' }
$engineLog = Join-Path $probe 'runtime.log'
$consoleLog = Join-Path $probe 'console.log'
$probeExe = Join-Path $probe 'RuntimeProbe.exe'
# Release templates disable command-line pack overrides; pair an exact copy of
# the executable with the harness, which mounts the untouched game PCK itself.
Copy-Item -LiteralPath $exe -Destination $probeExe
$runtimeArgs = @('--headless', '--log-file', ('"{0}"' -f $engineLog), '--',
    ('"--release-pack={0}"' -f $pck), ('"--test-root={0}"' -f $probe))
$process = Start-Process -FilePath $probeExe -ArgumentList $runtimeArgs -WindowStyle Hidden -Wait -PassThru `
    -RedirectStandardOutput $consoleLog -RedirectStandardError (Join-Path $probe 'stderr.log')
$runtimeExit = $process.ExitCode
Get-Content -LiteralPath $consoleLog
Get-Content -LiteralPath (Join-Path $probe 'stderr.log')
if ($runtimeExit -ne 0 -or -not (Select-String -LiteralPath $engineLog -Pattern 'RELEASE_DECK_RUNTIME: \d+ checks; 0 failures')) {
    throw "Release runtime checks failed. See $engineLog"
}
$errors = Select-String -LiteralPath $engineLog -Pattern 'SCRIPT ERROR:|ERROR:' |
    Where-Object { $_.Line -notmatch 'ERROR: Failed to read the root certificate store\.|ERROR: Could not create ObjectDB Snapshots directory: user://' }
if ($errors) { throw "Release runtime reported errors. See $engineLog" }
Write-Host "Release runtime verified: $exe"
