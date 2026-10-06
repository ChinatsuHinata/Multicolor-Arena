param(
    [string]$WindowsInstallDir = 'D:\Program Files (x86)\MulticolorArena',
    [string]$InstalledPatchDir,
    [string]$TestVersion,
    [string]$PreparedTestDirectory,
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'pck-build-support.ps1')
$installed = Get-InstalledPckSource -Root $root -WindowsInstallDir $WindowsInstallDir -InstalledPatchDir $InstalledPatchDir
$exe = Join-Path $WindowsInstallDir 'MulticolorArena.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Installed executable missing: $exe" }
$projectPath = Join-Path $root 'project.godot'
$projectHash = (Get-FileHash -LiteralPath $projectPath -Algorithm SHA256).Hash
$project = [IO.File]::ReadAllText($projectPath, [Text.Encoding]::UTF8)
$current = [regex]::Match($project, '(?m)^config/version="([^"]+)"').Groups[1].Value
. (Join-Path $PSScriptRoot 'pck-publish-support.ps1')
if ($PreparedTestDirectory) {
    $fixture = (Resolve-Path -LiteralPath $PreparedTestDirectory).Path
    $allowed = [IO.Path]::GetFullPath((Join-Path $root 'builds/pck-tests')) + [IO.Path]::DirectorySeparatorChar
    if (-not $fixture.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Prepared tests must stay inside builds/pck-tests/.' }
    $prepared = Get-Content -LiteralPath (Join-Path $fixture 'patch/payload-windows.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $prepared.test_only -or $prepared.from -cne $installed.Version) { throw 'Prepared test does not match the installed source version.' }
    if ($TestVersion -and $TestVersion -cne $prepared.to) { throw 'Prepared test targets a different virtual version.' }
    $TestVersion = $prepared.to
}
if (-not $TestVersion) {
    $latest = if ((ConvertTo-PckVersion $current) -gt (ConvertTo-PckVersion $installed.Version)) { $current } else { $installed.Version }
    $parts = @($latest.Split('.') | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 4) { $parts += 0 }
    $parts[3] += 1
    $TestVersion = $parts -join '.'
}
if ((ConvertTo-PckVersion $TestVersion) -le (ConvertTo-PckVersion $current) -or (ConvertTo-PckVersion $TestVersion) -le (ConvertTo-PckVersion $installed.Version)) {
    throw 'Virtual test version must be newer than both the project and installed release.'
}
if (-not $PythonPath) {
    $bundled = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    $PythonPath = if (Test-Path -LiteralPath $bundled -PathType Leaf) { $bundled } else { (Get-Command python.exe -CommandType Application -ErrorAction Stop).Source }
}
if (-not $PreparedTestDirectory) {
    $fixture = Join-Path $root ('builds/pck-tests/TEST_ONLY-' + $TestVersion + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixture | Out-Null
} else {
    # Resolved fixture was checked above; remove only this test's isolated profile.
    $testProfile = [IO.Path]::GetFullPath((Join-Path $fixture 'profile'))
    if (-not $testProfile.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test profile path.' }
    if (Test-Path -LiteralPath $testProfile) { Remove-Item -LiteralPath $testProfile -Recurse -Force }
}
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$previousAppData = $env:APPDATA
$server = $null
try {
    $sourceList = Join-Path $fixture 'installed-source-patches.json'
    [IO.File]::WriteAllText($sourceList, (ConvertTo-Json -InputObject @($installed.PatchFiles) -Compress), [Text.UTF8Encoding]::new($false))
    & $godot --headless --log-file (Join-Path $fixture 'prepare.log') --path $root --script (Join-Path $root 'tests/support/prepare_installed_pck_update.gd') -- $fixture $installed.BaseVersion (Join-Path $root 'tests/support/installed_pck_update_runtime.gd') $sourceList
    if ($LASTEXITCODE -ne 0) { throw 'Could not prepare isolated release harness.' }
    Copy-Item -LiteralPath $exe -Destination (Join-Path $fixture 'UpdateProbe.exe')
    $patchDir = Join-Path $fixture 'patch'
    Write-Host "TEST_ONLY: $($installed.Version) -> $TestVersion; real release PCK, independent key and isolated profile."
    $buildOptions = @{ FromVersion = $installed.Version; BaseWindowsPck = $installed.Path; Platforms = @('windows'); TestVersion = $TestVersion; TestKeyPath = (Join-Path $fixture 'test-signing.key'); OutputDir = $patchDir; SkipExport = [bool]$PreparedTestDirectory }
    & (Join-Path $PSScriptRoot 'build-pck-patch.ps1') @buildOptions
    if (-not $?) { throw 'Test delta build failed.' }
    $snapshot = Join-Path $patchDir "TEST_ONLY-snapshots/$TestVersion-windows.pck"
    & $godot --headless --log-file (Join-Path $fixture 'inventory.log') --main-pack $snapshot --script (Join-Path $root 'tools/support/pck-test-inventory.gd') -- (Join-Path $fixture 'target-inventory.json')
    if ($LASTEXITCODE -ne 0) { throw 'Target inventory failed.' }
    foreach ($name in @('server.json', 'requests.jsonl')) {
        $oldOutput = Join-Path $fixture $name
        if (Test-Path -LiteralPath $oldOutput) { Remove-Item -LiteralPath $oldOutput -Force }
    }
    $server = Start-Process -FilePath $PythonPath -ArgumentList @(('"{0}"' -f (Join-Path $root 'tools/support/pck-test-server.py')), ('"{0}"' -f $fixture)) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $fixture 'server-stdout.log') -RedirectStandardError (Join-Path $fixture 'server-stderr.log')
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path -LiteralPath (Join-Path $fixture 'server.json')) -and [DateTime]::UtcNow -lt $deadline) {
        if ($server.HasExited) { throw "Local HTTP server failed; see $fixture/server-stderr.log" }
        Start-Sleep -Milliseconds 100
    }
    $origin = (Get-Content -LiteralPath (Join-Path $fixture 'server.json') -Raw | ConvertFrom-Json).origin
    $name = "MulticolorArena-$($installed.Version)-to-$TestVersion-windows.pck"
    $patch = Join-Path $patchDir $name
    $assetPath = "/updates/pck/$TestVersion/$name"
    $asset = [ordered]@{ url = $origin + $assetPath; size = (Get-Item -LiteralPath $patch).Length; sha256 = (Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash.ToLowerInvariant() }
    $payload = [ordered]@{ format = 'multicolor:arena/pck-latest-1'; game = 'multicolor:arena'; base = '1.2.7.1'; version = $TestVersion; windows = $asset; test_only = $true }
    if ($installed.SupportsChain) { $payload.patches = @([ordered]@{ from = $installed.Version; to = $TestVersion; windows = $asset }) }
    $payloadPath = Join-Path $fixture 'manifest-payload.json'
    $manifestPath = Join-Path $fixture 'manifest.json'
    [IO.File]::WriteAllText($payloadPath, ($payload | ConvertTo-Json -Depth 8 -Compress), [Text.UTF8Encoding]::new($false))
    & $godot --headless --log-file (Join-Path $fixture 'sign-manifest.log') --path $root --script (Join-Path $root 'tools/sign-update-manifest.gd') -- $payloadPath $manifestPath (Join-Path $fixture 'test-signing.key')
    if ($LASTEXITCODE -ne 0) { throw 'Test manifest signing failed.' }
    $routes = @{ '/updates/pck/latest.json' = 'manifest.json' }
    $routes[$assetPath] = 'patch/' + $name
    if ($installed.SupportsChain) { $routes['/updates/pck/chain.json'] = 'manifest.json' }
    [IO.File]::WriteAllText((Join-Path $fixture 'routes.json'), ($routes | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    $env:APPDATA = Join-Path $fixture 'profile'
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    foreach ($mode in @('login', 'restart')) {
        $log = Join-Path $fixture "$mode.log"
        $arguments = @('--headless', '--log-file', ('"{0}"' -f $log), '--', ('"{0}"' -f $installed.RawPath), $origin, $TestVersion, $mode, $installed.Version)
        $process = Start-Process -FilePath (Join-Path $fixture 'UpdateProbe.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $fixture "$mode-stdout.log") -RedirectStandardError (Join-Path $fixture "$mode-stderr.log")
        # Cache the handle before exit; Windows PowerShell otherwise loses ExitCode.
        $null = $process.Handle
        if (-not $process.WaitForExit(180000)) { $process.Kill(); throw "Release $mode test timed out." }
        Get-Content -LiteralPath (Join-Path $fixture "$mode-stdout.log") -Encoding UTF8
        Get-Content -LiteralPath (Join-Path $fixture "$mode-stderr.log") -Encoding UTF8
        if ($process.ExitCode -ne 0 -or -not (Select-String -LiteralPath $log -SimpleMatch "INSTALLED_PCK_AUTO_UPDATE: PASS $mode")) { throw "Release $mode test failed; see $log" }
    }
    $requests = @(Get-Content -LiteralPath (Join-Path $fixture 'requests.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    if (@($requests | Where-Object { $_.path.EndsWith('.pck') }).Count -ne 1) { throw 'The restarted client downloaded the patch again.' }
    $report = [ordered]@{ TEST_ONLY = $true; source = $installed.RawPath; source_patches = $installed.PatchFiles; effective_source = $installed.Path; from = $installed.Version; to = $TestVersion; original_project_version = $current; patch = $patch; patch_size = $asset.size; base_size = (Get-Item -LiteralPath $installed.Path).Length; released_login_update = 'PASS'; restart_and_resource_comparison = 'PASS'; no_repeat_download = 'PASS'; origin = $origin; requests = $requests }
    [IO.File]::WriteAllText((Join-Path $fixture 'result.json'), ($report | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Write-Host "INSTALLED_PCK_AUTO_UPDATE: PASS; report: $fixture/result.json"
} finally {
    $env:APPDATA = $previousAppData
    if ($server -and -not $server.HasExited) { $server.Kill(); $server.WaitForExit() }
    if ((Get-FileHash -LiteralPath $projectPath -Algorithm SHA256).Hash -cne $projectHash) { throw 'project.godot changed during the test.' }
}
