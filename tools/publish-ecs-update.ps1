param(
    [switch]$SkipBuild,
    [switch]$PrepareOnly,
    [string]$Server = '8.137.122.187',
    [string]$User = 'codex',
    [int]$SshPort = 22,
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519_multicolor_ecs"
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$project = Get-Content -LiteralPath (Join-Path $root 'project.godot') -Raw -Encoding UTF8
$match = [regex]::Match($project, '(?m)^config/version="(\d+\.\d+\.\d+(?:\.\d+)?)"\r?$')
if (-not $match.Success) { throw 'project.godot must have a numeric three or four part version.' }
$version = $match.Groups[1].Value

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build-both.ps1') -Installer
    if (-not $?) { throw 'Windows and Android build failed.' }
}

$installer = Join-Path $root "builds/installers/MulticolorArena-$version-win64-setup.exe"
$apk = Join-Path $root "builds/Android-debug/MulticolorArena-$version-debug.apk"
$releaseDir = Join-Path $root "builds/releases/$version"
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
$windowsName = "MulticolorArena-$version-win64-setup.exe"
$androidName = "MulticolorArena-$version-android.apk"
$androidReleasePath = Join-Path $releaseDir $androidName
$payloadPath = Join-Path $releaseDir 'payload.json'
$manifestPath = Join-Path $releaseDir 'update.json'

foreach ($file in @($installer, $apk)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -le 0) {
        throw "Missing or empty release file: $file"
    }
}
& (Join-Path $PSScriptRoot 'check-cross-platform-core.ps1') -PckPath (Join-Path $root "builds/installer-staging/$version/MulticolorArena.pck") -ApkPath $apk
if (-not $?) { throw 'Cross-platform content verification failed.' }

$sdkBuildTools = Join-Path $root '.godot-toolchain/android-sdk/build-tools/35.0.1'
$javaHome = 'C:\Program Files\Microsoft\jdk-17.0.10.7-hotspot'
$env:JAVA_HOME = $javaHome
$env:Path = "$(Join-Path $javaHome 'bin');$sdkBuildTools;$env:Path"
$signature = @(& (Join-Path $sdkBuildTools 'apksigner.bat') verify --print-certs $apk)
if ($LASTEXITCODE -ne 0) { throw 'Android APK signature verification failed.' }
$certificate = [regex]::Match(($signature -join "`n"), 'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)')
if (-not $certificate.Success -or $certificate.Groups[1].Value -ne 'cc5f14eb3f31bdd9fda0ebc929be7c116b1a8e9b28afe2dca0d0161511bad11b') {
    throw 'Android signing certificate changed; this APK cannot update existing installs.'
}
$badge = @(& (Join-Path $sdkBuildTools 'aapt2.exe') dump badging $apk)
$packageLine = @($badge | Where-Object { $_ -match '^package:' }) | Select-Object -First 1
if ($LASTEXITCODE -ne 0 -or $packageLine -notmatch "^package: name='com\.example\.multicolorarena' versionCode='[0-9]+' versionName='$([regex]::Escape($version))'") {
    throw 'Android package identity or version does not match the current installation.'
}

Copy-Item -LiteralPath $apk -Destination $androidReleasePath -Force
$baseUrl = "http://${Server}:47862/updates/$version"
$manifest = [ordered]@{
    version = $version
    notes = "Windows 和安卓均可更新至 $version。安卓下载完成后请确认系统安装提示。"
    windows = [ordered]@{
        url = "$baseUrl/$windowsName"
        sha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
        size = (Get-Item -LiteralPath $installer).Length
    }
    android = [ordered]@{
        url = "$baseUrl/$androidName"
        sha256 = (Get-FileHash -LiteralPath $androidReleasePath -Algorithm SHA256).Hash.ToLowerInvariant()
        size = (Get-Item -LiteralPath $androidReleasePath).Length
    }
}
[IO.File]::WriteAllText($payloadPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path $root --script (Join-Path $root 'tools/sign-update-manifest.gd') -- $payloadPath $manifestPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $manifestPath)) { throw 'Release manifest signing failed.' }
Write-Host "Prepared signed manifest: $manifestPath"
Write-Host "Windows installer: $installer"
Write-Host "Android APK: $androidReleasePath"
if ($PrepareOnly) { return }

if ($Server -ne '8.137.122.187' -or $User -ne 'codex') { throw 'This client is pinned to the existing ECS address; update client configuration before changing server.' }
if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) { throw "SSH key not found: $KeyPath" }
$target = "${User}@${Server}"
$sshOptions = @('-i', $KeyPath, '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=yes', '-p', "$SshPort")
$scpOptions = @('-O', '-C', '-i', $KeyPath, '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=yes', '-P', "$SshPort")
$remoteRoot = '/home/codex/.local/share/multicolor-updates'
$incoming = "$remoteRoot/.incoming-$version"
$available = & ssh @sshOptions $target 'df -Pk ~ | tail -1'
if ($LASTEXITCODE -ne 0) { throw 'Could not check ECS disk space.' }
$fields = @($available.Trim() -split '\s+')
$needed = (Get-Item -LiteralPath $installer).Length + (Get-Item -LiteralPath $androidReleasePath).Length + 268435456
if ($fields.Count -lt 4 -or [long]$fields[3] * 1024 -lt $needed) { throw 'ECS does not have enough free space for the staged release.' }
& ssh @sshOptions $target "mkdir -p $incoming"
if ($LASTEXITCODE -ne 0) { throw 'Could not create ECS staging directory.' }
& scp @scpOptions $installer $androidReleasePath $manifestPath "${target}:${incoming}/"
if ($LASTEXITCODE -ne 0) { throw 'SCP upload failed; the previous release remains active.' }
$windowsHash = $manifest.windows.sha256
$androidHash = $manifest.android.sha256
$signedHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$verify = "cd $incoming && printf '%s  %s\n' '$windowsHash' '$windowsName' '$androidHash' '$androidName' '$signedHash' 'update.json' | sha256sum -c - && cd .. && if [ -e '$version' ]; then echo 'Version already published' >&2; exit 1; fi && mv '.incoming-$version' '$version' && cp '$version/update.json' latest.json.new && mv latest.json.new latest.json"
& ssh @sshOptions $target $verify
if ($LASTEXITCODE -ne 0) { throw 'ECS release verification or activation failed; inspect the staging directory before retrying.' }
Write-Host "Published domestic update: http://${Server}:47862/updates/latest.json"
