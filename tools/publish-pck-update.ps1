param(
    [switch]$SkipBuild,
    [switch]$Publish,
    [switch]$CheckConnection,
    [switch]$ReplaceExisting,
    [string]$FromVersion,
    [string]$PreviousManifest,
    [string]$BaseWindowsPck,
    [string]$BaseAndroidPck,
    [switch]$UseInstalledWindowsPck,
    [string]$WindowsInstallDir = 'D:\Program Files (x86)\MulticolorArena',
    [string]$InstalledPatchDir,
    [string]$Server = '8.137.122.187',
    [string]$User = 'codex',
    [int]$SshPort = 22,
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519_multicolor_ecs"
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'pck-publish-support.ps1')

function Invoke-CloudCommand {
    param(
        [string]$Command,
        [string[]]$CommandArguments,
        [string]$Stage,
        [switch]$PassThru
    )

    $lines = [Collections.Generic.List[string]]::new()
    $previousPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 treats redirected native stderr as ErrorRecord.
        # Inspect the exit code instead, so SSH warnings do not stop the script.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        & $Command @CommandArguments 2>&1 | ForEach-Object {
            $line = $_.ToString()
            $lines.Add($line)
            if (-not $PassThru) { Write-Host $line }
        }
        $exitCode = $global:LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($null -eq $exitCode -or $exitCode -ne 0) {
        $details = ($lines | Select-Object -Last 12) -join [Environment]::NewLine
        $hint = 'See the SSH/SCP output above; the update has not completed.'
        if ($details -match 'kex_exchange_identification|Connection reset|Connection closed') {
            $hint = 'SSH connection was reset or closed. Check proxy/TUN/VPN routing first, then server SSH logs and source-IP restrictions.'
        } elseif ($details -match 'Connection timed out|Connection refused|No route to host') {
            $hint = 'Check the network route, ECS SSH port, security group and SSH service.'
        } elseif ($details -match 'Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED') {
            $hint = 'Verify the ECS host key before updating known_hosts. Strict host-key checking remains enabled.'
        } elseif ($details -match 'Permission denied.*publickey|Load key|sign_and_send_pubkey') {
            $hint = 'Check the existing SSH key, its passphrase or ssh-agent, and the server authorized_keys.'
        }
        throw "$Stage failed ($Command exit $exitCode, ${target}:$SshPort).`n$details`n$hint"
    }
    if ($PassThru) { return $lines.ToArray() }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($Publish -and $CheckConnection) { throw 'Use -CheckConnection without -Publish.' }
if ($Publish -and $PreviousManifest) { throw '-PreviousManifest is for local preparation only; publishing always verifies the cloud snapshot.' }
if ($Publish -or $CheckConnection) {
    if ($Server -ne '8.137.122.187' -or $User -ne 'codex') { throw 'Client server origin is pinned; update the client before publishing elsewhere.' }
    if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) { throw "SSH key not found: $KeyPath" }
    $ssh = (Get-Command ssh.exe -CommandType Application -ErrorAction Stop).Source
    $target = "${User}@${Server}"
    $connectionOptions = @('-i', $KeyPath, '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=yes',
        '-o', 'ConnectTimeout=10', '-o', 'ConnectionAttempts=1',
        '-o', 'ServerAliveInterval=10', '-o', 'ServerAliveCountMax=2')
    $sshOptions = $connectionOptions + @('-p', "$SshPort")
    if ($CheckConnection) {
        Write-Host "Checking cloud SSH connection: ${target}:$SshPort"
        Invoke-CloudCommand -Command $ssh -CommandArguments ($sshOptions + @($target, 'true')) -Stage 'Cloud SSH connection check'
        Write-Host 'Cloud SSH connection verified. No build or upload was performed.'
        return
    }
    $scp = (Get-Command scp.exe -CommandType Application -ErrorAction Stop).Source
    $scpOptions = @('-O') + $connectionOptions + @('-P', "$SshPort")
}
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
$match = [regex]::Match($project, '(?m)^config/version="(\d+\.\d+\.\d+(?:\.\d+)?)"\r?$')
if (-not $match.Success) { throw 'project.godot has no numeric target version.' }
$version = $match.Groups[1].Value
Assert-PckPublication -Version $version
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$prepareDir = Join-Path $root "builds/pck-patches/publish-$version"
New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null
$previous = $null
$installed = $null
$snapshotName = 'MISSING'
$snapshotHash = ''

if ($Publish) {
    $remoteRoot = '/home/codex/.local/share/multicolor-updates/pck'
    $incoming = "$remoteRoot/.incoming-$version-$([guid]::NewGuid().ToString('N'))"
    Write-Host "Checking cloud manifests and same-version replacement before building: ${target}:$SshPort"
    $readSnapshot = "if [ -f '$remoteRoot/chain.json' ]; then echo chain.json; base64 -w0 '$remoteRoot/chain.json'; echo; elif [ -f '$remoteRoot/latest.json' ]; then echo latest.json; base64 -w0 '$remoteRoot/latest.json'; echo; else echo MISSING; fi"
    $snapshot = @(Invoke-CloudCommand -Command $ssh -CommandArguments ($sshOptions + @($target, $readSnapshot)) -Stage 'Cloud PCK manifest inspection' -PassThru)
    if ($snapshot.Count -eq 1 -and $snapshot[0] -ceq 'MISSING') {
        Write-Host 'Cloud has no published PCK manifest.'
    } elseif ($snapshot.Count -eq 2 -and $snapshot[0] -in @('latest.json', 'chain.json')) {
        if ($snapshot[1].Length -gt 180000) { throw 'Cloud PCK manifest exceeds the supported size.' }
        $snapshotName = $snapshot[0]
        $PreviousManifest = Join-Path $prepareDir 'cloud-snapshot.json'
        [IO.File]::WriteAllBytes($PreviousManifest, [Convert]::FromBase64String($snapshot[1]))
        $snapshotHash = (Get-FileHash -LiteralPath $PreviousManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    } else { throw 'Unexpected cloud manifest inspection output.' }
}
if ($PreviousManifest) {
    $verifiedPayload = Join-Path $prepareDir 'verified-previous.json'
    & $godot --headless --path $root --script (Join-Path $root 'tools/verify-pck-manifest.gd') -- $PreviousManifest $verifiedPayload
    if ($LASTEXITCODE -ne 0) { throw 'Cloud PCK manifest signature verification failed.' }
    $previous = Get-Content -LiteralPath $verifiedPayload -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($previous.base -cne '1.2.7.1') { throw 'Unsupported cloud PCK base version.' }
}
Assert-PckPublication -Previous $previous -Version $version -ReplaceExisting:$ReplaceExisting
if ($UseInstalledWindowsPck) {
    if ($BaseWindowsPck) { throw 'Use either -UseInstalledWindowsPck or -BaseWindowsPck.' }
    . (Join-Path $PSScriptRoot 'pck-build-support.ps1')
    $installed = Get-InstalledPckSource -Root $root -WindowsInstallDir $WindowsInstallDir -FromVersion $FromVersion -InstalledPatchDir $InstalledPatchDir
    $FromVersion = $installed.Version
    $BaseWindowsPck = $installed.Path
}
$autoSource = -not $FromVersion
if (-not $FromVersion) {
    $FromVersion = if ($previous -and (ConvertTo-PckVersion $previous.version) -lt (ConvertTo-PckVersion $version)) { $previous.version } else { '1.2.7.1' }
    if ($previous -and $previous.version -ceq $version -and $previous.PSObject.Properties['patches']) {
        $followups = @($previous.patches | Where-Object { $_.to -ceq $version -and $_.from -cne '1.2.7.1' })
        if ($followups.Count -gt 0) { $FromVersion = $followups[-1].from }
    }
}
if ((ConvertTo-PckVersion $FromVersion) -lt (ConvertTo-PckVersion '1.2.7.1') -or
    (ConvertTo-PckVersion $FromVersion) -ge (ConvertTo-PckVersion $version)) { throw 'Source version must be at least 1.2.7.1 and older than the target.' }
# Bootstrap older publication workflows that did not retain complete snapshots.
# Explicit source versions and custom source PCKs always remain strict.
if ($autoSource -and $FromVersion -cne '1.2.7.1' -and -not $BaseWindowsPck -and -not $BaseAndroidPck) {
    $missingSource = $false
    foreach ($platform in @('windows', 'android')) {
        $candidate = if ($SkipBuild) {
            Join-Path $root "builds/pck-patches/$FromVersion-to-$version/MulticolorArena-$FromVersion-to-$version-$platform.pck"
        } else { Join-Path $root "builds/pck-base/$FromVersion-$platform.pck" }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { $missingSource = $true }
    }
    if ($missingSource) {
        Write-Host "Source $FromVersion has no complete prepared pair; publishing a cumulative bootstrap from 1.2.7.1."
        $FromVersion = '1.2.7.1'
    }
}
if ($Publish) {
    $guard = if ($ReplaceExisting) { ':' } else { "if [ -e '$remoteRoot/$version' ]; then echo 'Version already published; use -ReplaceExisting.' >&2; exit 1; fi" }
    $prepare = "$guard; mkdir -p '$incoming'"
    Invoke-CloudCommand -Command $ssh -CommandArguments ($sshOptions + @($target, $prepare)) -Stage 'Cloud PCK staging preparation'
    Write-Host $(if ($ReplaceExisting) { 'Same-version cloud replacement enabled; hash-addressed historical files will be retained.' } else { 'Same-version cloud replacement disabled; existing releases are rejected.' })
}

if (-not $SkipBuild) {
    $buildArgs = @{ FromVersion = $FromVersion }
    if ($BaseWindowsPck) { $buildArgs.BaseWindowsPck = $BaseWindowsPck }
    if ($BaseAndroidPck) { $buildArgs.BaseAndroidPck = $BaseAndroidPck }
    & (Join-Path $PSScriptRoot 'build-pck-patch.ps1') @buildArgs
    if (-not $?) { throw 'PCK patch build failed.' }
    if ($FromVersion -cne '1.2.7.1') {
        $cumulativeArgs = @{ FromVersion = '1.2.7.1' }
        if ($installed -and $installed.BaseVersion -ceq '1.2.7.1') { $cumulativeArgs.BaseWindowsPck = $installed.RawPath }
        & (Join-Path $PSScriptRoot 'build-pck-patch.ps1') @cumulativeArgs
        if (-not $?) { throw 'Legacy cumulative PCK patch build failed.' }
    }
}

$origin = "http://${Server}:47862"
$newEdges = @()
$uploadFiles = [Collections.Generic.List[string]]::new()
$legacy = [ordered]@{ format = 'multicolor:arena/pck-latest-1'; game = 'multicolor:arena'; base = '1.2.7.1'; version = $version }
$sources = @('1.2.7.1')
if ($FromVersion -cne '1.2.7.1') { $sources += $FromVersion }
foreach ($sourceVersion in $sources) {
    $edge = [ordered]@{ from = $sourceVersion; to = $version }
    $releaseDir = Join-Path $root "builds/pck-patches/$sourceVersion-to-$version"
    foreach ($platform in @('windows', 'android')) {
        $name = "MulticolorArena-$sourceVersion-to-$version-$platform.pck"
        $path = Join-Path $releaseDir $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing PCK patch: $path" }
        & $godot --headless --path $root --script (Join-Path $root 'tools/check-signed-pck-patch.gd') -- $path $sourceVersion $version $platform
        if ($LASTEXITCODE -ne 0) { throw "Invalid signed $platform patch: $path" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $hashedName = "MulticolorArena-$sourceVersion-to-$version-$platform-$hash.pck"
        $hashedPath = Join-Path $prepareDir $hashedName
        Copy-Item -LiteralPath $path -Destination $hashedPath -Force
        $uploadFiles.Add($hashedPath)
        $edge[$platform] = [ordered]@{ url = "$origin/updates/pck/$version/$hashedName"; size = (Get-Item -LiteralPath $path).Length; sha256 = $hash }
        if ($sourceVersion -ceq '1.2.7.1') {
            $legacy[$platform] = [ordered]@{ url = "$origin/updates/pck/$version/$name"; size = $edge[$platform].size; sha256 = $hash }
            $uploadFiles.Add($path)
        }
    }
    $newEdges += [pscustomobject]$edge
}
$chain = Merge-PckChain -Previous $previous -NewEdges $newEdges -Version $version -Origin $origin -ReplaceExisting:$ReplaceExisting
foreach ($manifestName in @('latest', 'chain')) {
    $manifest = if ($manifestName -eq 'latest') { $legacy } else { $chain }
    $payloadPath = Join-Path $prepareDir "$manifestName-payload.json"
    $signedPath = Join-Path $prepareDir "$manifestName.json"
    [IO.File]::WriteAllText($payloadPath, ($manifest | ConvertTo-Json -Depth 8 -Compress), [Text.UTF8Encoding]::new($false))
    & $godot --headless --path $root --script (Join-Path $root 'tools/sign-update-manifest.gd') -- $payloadPath $signedPath
    if ($LASTEXITCODE -ne 0) { throw "Could not sign PCK $manifestName manifest." }
    $uploadFiles.Add($signedPath)
    Write-Host "Prepared signed PCK manifest: $signedPath"
}
if (-not $Publish) { return }

$checksums = @($uploadFiles | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_) })
$checksumPath = Join-Path $prepareDir 'SHA256SUMS'
[IO.File]::WriteAllText($checksumPath, ($checksums -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
$uploadFiles.Add($checksumPath)
Invoke-CloudCommand -Command $scp -CommandArguments ($scpOptions + $uploadFiles.ToArray() + @("${target}:${incoming}/")) -Stage 'Cloud PCK upload'
$verify = New-PckActivationCommand -RemoteRoot $remoteRoot -Incoming $incoming -Version $version -SnapshotName $snapshotName -ExpectedHash $snapshotHash -ReplaceExisting:$ReplaceExisting
Invoke-CloudCommand -Command $ssh -CommandArguments ($sshOptions + @($target, $verify)) -Stage 'Cloud verification or activation'
Write-Host "Published: $origin/updates/pck/chain.json (legacy latest.json also updated)"
