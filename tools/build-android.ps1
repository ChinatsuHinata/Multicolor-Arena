param(
    [string]$OutputPath = 'builds/Android-debug/MulticolorArena-debug.apk',
    [string]$JavaSdkPath = 'C:\Program Files\Microsoft\jdk-17.0.10.7-hotspot'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'sync-export-version.ps1')
if (-not $?) { throw 'Export version synchronization failed.' }
$godot = Join-Path $root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$sdk = Join-Path $root '.godot-toolchain/android-sdk'
$templates = Join-Path $root '.godot-toolchain/editor/editor_data/export_templates/4.7.2.stable'
$settings = Join-Path $root '.godot-toolchain/editor/editor_data/editor_settings-4.7.tres'
$presets = Join-Path $root 'export_presets.cfg'

function Assert-File([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not found: $Path"
    }
}

function Get-EditorPath([string]$Contents, [string]$Name) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '[ \t]*=[ \t]*"((?:\\.|[^"\\])*)"[ \t]*\r?$'
    $found = [regex]::Match($Contents, $pattern)
    if (-not $found.Success -or [string]::IsNullOrWhiteSpace($found.Groups[1].Value)) {
        throw "Set $Name in the portable Godot Editor Settings: $settings"
    }
    return $found.Groups[1].Value.Replace('\\', '\')
}

function Assert-SamePath([string]$Actual, [string]$Expected, [string]$Name) {
    $actualFull = [IO.Path]::GetFullPath($Actual).TrimEnd('\', '/')
    $expectedFull = [IO.Path]::GetFullPath($Expected).TrimEnd('\', '/')
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($actualFull, $expectedFull)) {
        throw "$Name points to $actualFull; expected $expectedFull. Update the portable Godot Editor Settings."
    }
}

function Assert-CleanGodotLog([string]$Path, [string]$Stage) {
    Assert-File $Path "$Stage log"
    $errors = Select-String -LiteralPath $Path -Pattern 'SCRIPT ERROR:|ERROR:' |
        Where-Object { $_.Line -notmatch 'ERROR: Failed to read the root certificate store\.|ERROR: Could not create ObjectDB Snapshots directory: user://' }
    if ($errors) {
        throw "$Stage reported errors. See $Path"
    }
}

Assert-File $godot 'Godot 4.7.2 console editor'
$version = (& $godot --version).Trim()
if ($LASTEXITCODE -ne 0 -or -not $version.StartsWith('4.7.2.stable.')) {
    throw "Expected Godot 4.7.2 stable; found $version"
}
Assert-File (Join-Path $templates 'android_debug.apk') 'Godot Android debug export template'
Assert-File (Join-Path $templates 'version.txt') 'Godot export template version'
$templateVersion = (Get-Content -LiteralPath (Join-Path $templates 'version.txt') -Raw).Trim()
if ($templateVersion -ne '4.7.2.stable') {
    throw "Expected 4.7.2.stable export templates; found $templateVersion"
}

$java = Join-Path $JavaSdkPath 'bin/java.exe'
Assert-File $java 'JDK 17 java.exe'
Assert-File (Join-Path $JavaSdkPath 'bin/keytool.exe') 'JDK 17 keytool.exe'
$javaVersionOutput = @(& $java --version)
$javaVersion = $javaVersionOutput[0]
if ($LASTEXITCODE -ne 0 -or $javaVersion -notmatch '^(?:openjdk|java) 17(?:[.\s]|$)') {
    throw "Expected JDK 17 at $JavaSdkPath; found $javaVersion"
}

$requiredSdkFiles = @{
    'platform-tools/adb.exe' = 'Android Platform-Tools'
    'build-tools/35.0.1/apksigner.bat' = 'Android Build-Tools 35.0.1'
    'platforms/android-35/android.jar' = 'Android SDK Platform 35'
    'cmdline-tools/latest/bin/sdkmanager.bat' = 'Android Command-line Tools (latest)'
    'cmake/3.10.2.4988404/bin/cmake.exe' = 'Android CMake 3.10.2.4988404'
    'ndk/28.1.13356709/source.properties' = 'Android NDK 28.1.13356709'
}
foreach ($relativePath in $requiredSdkFiles.Keys) {
    Assert-File (Join-Path $sdk $relativePath) $requiredSdkFiles[$relativePath]
}
$platformToolsProperties = Join-Path $sdk 'platform-tools/source.properties'
Assert-File $platformToolsProperties 'Android Platform-Tools revision'
$platformToolsRevision = [regex]::Match((Get-Content -LiteralPath $platformToolsProperties -Raw), '(?m)^Pkg\.Revision\s*=\s*(\d+(?:\.\d+)*)\s*$')
if (-not $platformToolsRevision.Success -or [version]$platformToolsRevision.Groups[1].Value -lt [version]'35.0.0') {
    throw "Android Platform-Tools 35.0.0 or later is required: $platformToolsProperties"
}

Assert-File $presets 'Godot export presets'
$presetContents = Get-Content -LiteralPath $presets -Raw -Encoding UTF8
$sections = @{}
foreach ($section in [regex]::Matches($presetContents, '(?ms)^\[(preset\.\d+(?:\.options)?)\][ \t]*\r?\n(.*?)(?=^\[|\z)')) {
    $sections[$section.Groups[1].Value] = $section.Groups[2].Value
}
$androidOptions = $null
foreach ($key in $sections.Keys) {
    if ($key -match '^preset\.\d+$' -and $sections[$key] -match '(?m)^name="Android"\r?$') {
        $optionsKey = "$key.options"
        if ($sections.ContainsKey($optionsKey)) { $androidOptions = $sections[$optionsKey] }
        break
    }
}
if (-not $androidOptions) { throw 'Android export preset was not found in export_presets.cfg.' }
foreach ($requiredOption in @(
    'gradle_build/use_gradle_build=false',
    'gradle_build/export_format=0',
    'architectures/arm64-v8a=true',
    'architectures/armeabi-v7a=false',
    'architectures/x86=false',
    'architectures/x86_64=true'
)) {
    if ($androidOptions -notmatch ('(?m)^' + [regex]::Escape($requiredOption) + '\r?$')) {
        throw "Android debug APK preset must contain $requiredOption"
    }
}

Assert-File $settings 'Portable Godot editor settings'
$editorSettings = Get-Content -LiteralPath $settings -Raw -Encoding UTF8
Assert-SamePath (Get-EditorPath $editorSettings 'export/android/java_sdk_path') $JavaSdkPath 'Java SDK Path'
Assert-SamePath (Get-EditorPath $editorSettings 'export/android/android_sdk_path') $sdk 'Android SDK Path'
$debugKeystore = Get-EditorPath $editorSettings 'export/android/debug_keystore'
Assert-File $debugKeystore 'Android debug signing keystore'

$output = if ([IO.Path]::IsPathRooted($OutputPath)) {
    [IO.Path]::GetFullPath($OutputPath)
} else {
    [IO.Path]::GetFullPath((Join-Path $root $OutputPath))
}
if (-not $output.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must stay inside the project.'
}
if ([IO.Path]::GetExtension($output) -ne '.apk') { throw 'OutputPath must end in .apk.' }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
$logDir = Join-Path $root '.godot-toolchain/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$env:JAVA_HOME = [IO.Path]::GetFullPath($JavaSdkPath)
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path = "$(Join-Path $JavaSdkPath 'bin');$(Join-Path $sdk 'platform-tools');$(Join-Path $sdk 'build-tools/35.0.1');$env:Path"

$importLog = Join-Path $logDir 'android-import.log'
$importConsoleLog = Join-Path $logDir 'android-import-console.log'
Write-Host "Importing with $version"
$ErrorActionPreference = 'Continue'
& $godot --headless --path $root --editor --import --log-file $importLog *> $importConsoleLog
$importExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($importExitCode -ne 0) { throw "Godot import failed. See $importConsoleLog" }
Assert-CleanGodotLog $importLog 'Godot import'

$exportLog = Join-Path $logDir 'android-export.log'
$exportConsoleLog = Join-Path $logDir 'android-export-console.log'
$exportStarted = [DateTime]::UtcNow
Write-Host "Exporting Android arm64 + x86_64 debug APK to $output"
$ErrorActionPreference = 'Continue'
& $godot --headless --path $root --export-debug 'Android' $output --log-file $exportLog *> $exportConsoleLog
$exportExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exportExitCode -ne 0) { throw "Godot Android export failed. See $exportConsoleLog" }
Assert-CleanGodotLog $exportLog 'Godot Android export'
Assert-File $output 'Android debug APK'
$apkInfo = Get-Item -LiteralPath $output
if ($apkInfo.Length -le 0 -or $apkInfo.LastWriteTimeUtc -lt $exportStarted) {
    throw "Android export did not write a new nonempty APK: $output"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$apk = [IO.Compression.ZipFile]::OpenRead($output)
try {
    $entryNames = @($apk.Entries | ForEach-Object { $_.FullName })
    if ('AndroidManifest.xml' -notin $entryNames) { throw 'Exported APK has no AndroidManifest.xml.' }
    $nativeLibraries = @($entryNames | Where-Object { $_ -match '^lib/([^/]+)/[^/]+\.so$' })
    foreach ($architecture in @('arm64-v8a', 'x86_64')) {
        if (@($nativeLibraries | Where-Object { $_ -like "lib/$architecture/*" }).Count -eq 0) {
            throw "Exported APK has no $architecture native library."
        }
    }
    if (@($nativeLibraries | Where-Object { $_ -notmatch '^lib/(arm64-v8a|x86_64)/' }).Count -gt 0) {
        throw 'Exported APK contains an unexpected native library architecture.'
    }
} finally {
    $apk.Dispose()
}

$signatureLog = Join-Path $logDir 'android-apk-signature.log'
$apksigner = Join-Path $sdk 'build-tools/35.0.1/apksigner.bat'
$ErrorActionPreference = 'Continue'
& $apksigner verify --verbose --print-certs $output *> $signatureLog
$signatureExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($signatureExitCode -ne 0) { throw "APK signature verification failed. See $signatureLog" }

Write-Host "Built: $output"
Write-Host "Signature verified; logs: $logDir"
