param(
    [switch]$SetupOnly,
    [switch]$StartOnly,
    [switch]$SkipBuild,
    [string]$AvdName = 'MulticolorArena_API35_AOSP',
    [string]$JavaSdkPath = 'C:\Program Files\Microsoft\jdk-17.0.10.7-hotspot',
    [string]$ApkPath = 'builds/Android-debug/MulticolorArena-debug.apk'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# The Android Emulator's Windows subprocess uses narrow paths. Give projects with
# non-ASCII directory names a stable ASCII junction for SDK and AVD paths.
$digest = [Security.Cryptography.SHA256]::Create()
try {
    $hash = [BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($root))).Replace('-', '').Substring(0, 10).ToLowerInvariant()
} finally { $digest.Dispose() }
$aliasRoot = Join-Path $env:TEMP "MulticolorArena-Android-$hash"
if ($aliasRoot -match '[^\x00-\x7F]') { throw 'The TEMP path must contain only ASCII characters for Android Emulator.' }
if (Test-Path -LiteralPath $aliasRoot) {
    $junction = Get-Item -LiteralPath $aliasRoot
    if ($junction.LinkType -ne 'Junction' -or
        -not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath(@($junction.Target)[0]), $root)) {
        throw "The emulator path is already used by another directory: $aliasRoot"
    }
} else {
    New-Item -ItemType Junction -Path $aliasRoot -Target $root | Out-Null
}
$sdk = Join-Path $aliasRoot '.godot-toolchain/android-sdk'
$androidHome = Join-Path $aliasRoot '.godot-toolchain/android-home'
$avdHome = Join-Path $androidHome 'avd'
$android = Join-Path $sdk 'cmdline-tools/latest/bin/android.exe'
$avdmanager = Join-Path $sdk 'cmdline-tools/latest/bin/avdmanager.bat'
$emulator = Join-Path $sdk 'emulator/emulator.exe'
$adb = Join-Path $sdk 'platform-tools/adb.exe'
$aapt = Join-Path $sdk 'build-tools/35.0.1/aapt.exe'
$image = Join-Path $sdk 'system-images/android-35/default/x86_64/system.img'

function Assert-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
}

function Get-RunningAvdSerial {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $devices = @(& $adb devices 2>$null)
        if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
        foreach ($line in $devices) {
            if ($line -match '^(emulator-\d+)\s+device\s*$') {
                $serial = $Matches[1]
                # The emulator console can be unavailable even when adb shell works.
                $name = @(& $adb -s $serial shell getprop ro.boot.qemu.avd_name 2>$null)
                if ($LASTEXITCODE -eq 0 -and @($name | Where-Object { $_.Trim() -eq $AvdName }).Count -gt 0) {
                    return $serial
                }
            }
        }
        return $null
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Test-TargetAvdProcess {
    # Current Android Emulator versions hold this file open while the AVD runs.
    # The older hardware-qemu.ini.lock/pid path is not created by version 37.
    $lockPath = Join-Path $avdHome "$AvdName.avd/multiinstance.lock"
    if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) { return $false }
    try {
        $lock = [IO.File]::Open($lockPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $lock.Dispose()
        return $false
    } catch [IO.IOException] {
        return $true
    } catch [UnauthorizedAccessException] {
        return $true
    }
}

function Save-EmulatorScreenshot([string]$Serial, [string]$Description) {
    $remotePath = '/sdcard/Download/multicolor-arena-screen.png'
    $screenPath = Join-Path $root 'work/android-emulator-screen.png'
    $screenPathForTools = Join-Path $aliasRoot 'work/android-emulator-screen.png'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $screenPath) | Out-Null
    $ErrorActionPreference = 'Continue'
    try {
        & $adb -s $Serial shell screencap -p $remotePath
        if ($LASTEXITCODE -ne 0) { throw 'Could not capture the emulator display.' }
        & $adb -s $Serial pull $remotePath $screenPathForTools
        if ($LASTEXITCODE -ne 0) { throw 'Could not save the emulator screenshot.' }
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    Assert-File $screenPath
    $bytes = [IO.File]::ReadAllBytes($screenPath)
    if ($bytes.Length -lt 1024 -or
        [BitConverter]::ToString($bytes, 0, 8) -ne '89-50-4E-47-0D-0A-1A-0A') {
        throw "The emulator screenshot is not a valid PNG: $screenPath"
    }
    Write-Host "$Description screenshot: $screenPath"
}

if ($SetupOnly -and $StartOnly) { throw 'Use either -SetupOnly or -StartOnly.' }
Assert-File $android
Assert-File $avdmanager
Assert-File $adb
Assert-File (Join-Path $JavaSdkPath 'bin/java.exe')

New-Item -ItemType Directory -Force -Path $androidHome, $avdHome | Out-Null
$env:JAVA_HOME = [IO.Path]::GetFullPath($JavaSdkPath)
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_USER_HOME = $androidHome
$env:ANDROID_AVD_HOME = $avdHome
Remove-Item Env:ANDROID_SDK_HOME -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $emulator -PathType Leaf) -or
    -not (Test-Path -LiteralPath $image -PathType Leaf)) {
    Write-Host 'Installing Android Emulator and AOSP Android 35 x86_64 system image...'
    & $android --sdk=$sdk --no-metrics sdk install emulator system-images/android-35/default/x86_64
    $installExitCode = $LASTEXITCODE
    if ($installExitCode -ne 0 -and
        (-not (Test-Path -LiteralPath $emulator -PathType Leaf) -or
         -not (Test-Path -LiteralPath $image -PathType Leaf))) {
        throw "Android SDK package installation failed with code $installExitCode."
    }
}
Assert-File $emulator
Assert-File $image
Assert-File (Join-Path $sdk 'emulator/source.properties')
Assert-File (Join-Path $sdk 'system-images/android-35/default/x86_64/source.properties')
if ((Get-Item -LiteralPath $emulator).Length -lt 1MB -or
    (Get-Item -LiteralPath $image).Length -lt 100MB) {
    throw 'The Android Emulator or system image appears incomplete.'
}

$avdConfig = Join-Path $avdHome "$AvdName.avd/config.ini"
if (-not (Test-Path -LiteralPath $avdConfig -PathType Leaf)) {
    Write-Host "Creating AOSP virtual device: $AvdName"
    'no' | & $avdmanager create avd -f -n $AvdName -k 'system-images;android-35;default;x86_64'
    if ($LASTEXITCODE -ne 0) { throw 'AVD creation failed.' }
}
Assert-File $avdConfig
$avdIni = Join-Path $avdHome "$AvdName.ini"
Assert-File $avdIni
$iniContents = Get-Content -LiteralPath $avdIni -Raw -Encoding UTF8
$expectedAvdPath = Join-Path $avdHome "$AvdName.avd"
$updatedIniContents = [regex]::Replace($iniContents, '(?m)^path=.*$', "path=$expectedAvdPath")
if ($updatedIniContents -ne $iniContents) {
    [IO.File]::WriteAllText($avdIni, $updatedIniContents, [Text.UTF8Encoding]::new($false))
}
$avdMarker = Join-Path $avdHome "$AvdName.avd/.multicolor-arena-configured"
if (-not (Test-Path -LiteralPath $avdMarker -PathType Leaf)) {
    $configuration = Get-Content -LiteralPath $avdConfig -Raw -Encoding UTF8
    foreach ($property in @(
        @('hw.lcd.width', '1280'),
        @('hw.lcd.height', '720'),
        @('hw.lcd.density', '240'),
        @('hw.initialOrientation', 'landscape'),
        @('hw.keyboard', 'yes')
    )) {
        $pattern = '(?m)^' + [regex]::Escape($property[0]) + '=.*$'
        if ($configuration -notmatch $pattern) { throw "AVD configuration is missing $($property[0])." }
        $configuration = [regex]::Replace($configuration, $pattern, "$($property[0])=$($property[1])")
    }
    [IO.File]::WriteAllText($avdConfig, $configuration, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($avdMarker, '')
}
Write-Host "AVD ready: $AvdName"
if ($SetupOnly) { return }

if (-not $StartOnly) {
    $apk = if ([IO.Path]::IsPathRooted($ApkPath)) {
        [IO.Path]::GetFullPath($ApkPath)
    } else {
        [IO.Path]::GetFullPath((Join-Path $root $ApkPath))
    }
    if (-not $SkipBuild) {
        & (Join-Path $PSScriptRoot 'build-android.ps1') -OutputPath $apk -JavaSdkPath $JavaSdkPath
        if ($LASTEXITCODE -ne 0) { throw 'Android APK build failed.' }
    }
    Assert-File $apk
}

$ErrorActionPreference = 'Continue'
& $adb start-server 2>$null
$adbStartExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($adbStartExitCode -ne 0) { throw 'Could not start the adb server.' }
$serial = Get-RunningAvdSerial
if (-not $serial) {
    if (Test-TargetAvdProcess) {
        $reconnectDeadline = (Get-Date).AddSeconds(30)
        do {
            Start-Sleep -Seconds 2
            $serial = Get-RunningAvdSerial
        } while (-not $serial -and (Get-Date) -lt $reconnectDeadline)
    }
}
if (-not $serial -and (Test-TargetAvdProcess)) {
    throw "The AVD $AvdName is already running, but adb cannot connect to it. Close that emulator or restore its adb connection before retrying."
}
if (-not $serial) {
    $acceleration = @(& $emulator -accel-check 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Android Emulator acceleration is unavailable. Enable Windows Hypervisor Platform and CPU virtualization, then restart Windows. Details: $($acceleration -join ' ')"
    }
    Write-Host "Starting $AvdName..."
    # The emulator is an interactive window; keep it open after this script finishes.
    $logDir = Join-Path $root '.godot-toolchain/logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $emulatorLog = Join-Path $logDir 'android-emulator.log'
    $emulatorErrorLog = Join-Path $logDir 'android-emulator-error.log'
    # A saved graphics snapshot has crashed this AVD on restore. A cold boot
    # preserves installed apps while avoiding that snapshot and the crash-report dialog.
    $emulatorProcess = Start-Process -FilePath $emulator -ArgumentList @('-avd', $AvdName, '-no-snapshot-load', '-crash-report-mode', 'never', '-verbose', '-no-metrics') -WorkingDirectory (Split-Path -Parent $emulator) -PassThru -WindowStyle Normal -RedirectStandardOutput $emulatorLog -RedirectStandardError $emulatorErrorLog
}

$deadline = (Get-Date).AddMinutes(4)
$ErrorActionPreference = 'Continue'
do {
    if (-not $serial) { $serial = Get-RunningAvdSerial }
    if ($serial) {
        $boot = @(& $adb -s $serial shell getprop sys.boot_completed 2>$null)
        if ($LASTEXITCODE -eq 0 -and $boot -contains '1') { break }
    }
    if ($emulatorProcess -and $emulatorProcess.HasExited) {
        $emulatorProcess.Refresh()
        $exitCode = if ($null -eq $emulatorProcess.ExitCode) { 'unavailable' } else { [string]$emulatorProcess.ExitCode }
        $lastError = @(Get-Content -LiteralPath $emulatorLog -Tail 80 | Where-Object { $_ -match '^(ERROR|FATAL)' } | Select-Object -Last 1)
        $reason = if ($lastError.Count -gt 0) { " $($lastError[0])" } else { '' }
        throw "Android Emulator exited (code: $exitCode).$reason See $emulatorLog and $emulatorErrorLog"
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
$ErrorActionPreference = 'Stop'
if (-not $serial -or $boot -notcontains '1') { throw 'Timed out waiting for the Android Emulator to finish booting.' }
Write-Host "Android Emulator ready: $serial"
if ($StartOnly) {
    Save-EmulatorScreenshot $serial 'Emulator'
    return
}

$apkForTools = if ($apk.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    Join-Path $aliasRoot $apk.Substring($root.Length).TrimStart('\', '/')
} else { $apk }
Assert-File $aapt
$badging = @(& $aapt dump badging $apkForTools)
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the APK package name.' }
$packageLine = $badging | Where-Object { $_ -match "^package: name='([^']+)'" } | Select-Object -First 1
if (-not $packageLine) { throw 'APK package name was not found.' }
$packageName = [regex]::Match($packageLine, "^package: name='([^']+)'").Groups[1].Value

Write-Host "Installing $apk on $serial..."
$ErrorActionPreference = 'Continue'
& $adb -s $serial install -r $apkForTools
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
Write-Host "Launching $packageName..."
$ErrorActionPreference = 'Continue'
& $adb -s $serial shell monkey -p $packageName -c android.intent.category.LAUNCHER 1
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { throw 'APK launch failed.' }
$foregroundDeadline = (Get-Date).AddSeconds(30)
$foreground = $false
do {
    $ErrorActionPreference = 'Continue'
    $focus = @(& $adb -s $serial shell dumpsys window 2>$null)
    $focusExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($focusExitCode -eq 0 -and
        @($focus | Where-Object { $_ -match 'mCurrentFocus=.*' + [regex]::Escape($packageName) + '/' }).Count -gt 0) {
        $foreground = $true
        break
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $foregroundDeadline)
if (-not $foreground) { throw "Android did not show $packageName in the foreground after launch." }
Start-Sleep -Seconds 2
Save-EmulatorScreenshot $serial 'Game'
Write-Host "Running on $serial"
