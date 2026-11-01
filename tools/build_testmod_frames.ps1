param([switch]$Install)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskRuntime = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies'
$taskPython = Join-Path $taskRuntime 'python/python.exe'
$taskNode = Join-Path $taskRuntime 'node/bin/node.exe'
$env:NODE_PATH = Join-Path $taskRuntime 'node/node_modules'
$env:PYTHONPATH = Join-Path $taskRoot 'work/psd-python'
$env:PYTHONIOENCODING = 'utf-8'
$env:TESTMOD_OUTPUT = 'output/testmod-frames'
$env:TESTMOD_DESIGN = $env:TESTMOD_OUTPUT
$env:TESTMOD_ART = "$($env:TESTMOD_OUTPUT)/illustrations"
$env:TESTMOD_SOURCE_UNIT = 'D:/叶子游戏/模板/教学用 天才教师上白泽慧音.psd'
$taskTimings = @()
Push-Location -LiteralPath $taskRoot
try {
    foreach ($taskStep in @('prepare_testmod_titles.py','build_testmod_frames.py','render_testmod_cards_v5.cjs','export_testmod_typography_layers.cjs','build_testmod_typography_psd.py','verify_testmod_typography.py','verify_testmod_title_samples.py','finalize_testmod_titles.py')) {
        $taskExecutable = if ($taskStep.EndsWith('.cjs')) { $taskNode } else { $taskPython }
        $taskTimer = [System.Diagnostics.Stopwatch]::StartNew()
        if ($taskStep -eq 'finalize_testmod_titles.py' -and $Install) {
            & $taskExecutable (Join-Path $PSScriptRoot $taskStep) --install
        } else {
            & $taskExecutable (Join-Path $PSScriptRoot $taskStep)
        }
        $taskExitCode = $LASTEXITCODE
        $taskTimer.Stop()
        $taskTimings += [pscustomobject]@{ step = $taskStep; seconds = [math]::Round($taskTimer.Elapsed.TotalSeconds, 3); exit_code = $taskExitCode }
        $taskTimings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $env:TESTMOD_OUTPUT 'build-timings.json') -Encoding UTF8
        Write-Output ("{0}: {1:N3}s (exit {2})" -f $taskStep, $taskTimer.Elapsed.TotalSeconds, $taskExitCode)
        if ($taskExitCode -ne 0) { throw "Card build failed: $taskStep" }
    }
}
finally { Pop-Location }
