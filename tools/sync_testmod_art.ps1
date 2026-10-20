param([string]$Revision = 'testmod-typography-v4')
$ErrorActionPreference = 'Stop'
if ($Revision -notin @('testmod-typography-v4','testmod-typography-v5')) { throw 'Unknown art revision.' }
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskSource = Join-Path $taskRoot 'examples/testmod'
$taskTarget = [IO.Path]::GetFullPath('D:/叶子游戏/testmod')
$taskExpected = [IO.Path]::GetFullPath('D:/叶子游戏/testmod')
if ($taskTarget -ne $taskExpected) { throw 'Unexpected mod target.' }
$taskManifest = Get-Content -LiteralPath (Join-Path $taskSource 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$taskInstalled = Get-Content -LiteralPath (Join-Path $taskTarget 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($taskManifest.id -ne 'testmod' -or $taskInstalled.id -ne 'testmod' -or $taskManifest.cards.Count -ne 13) { throw 'Unexpected mod identity.' }
# This revision updates cosmetic files only. Refuse to replace diverged rules.
foreach ($taskDefinition in @($taskManifest.cards) + @('abilities.gd')) {
    $taskOriginalHash = (Get-FileHash -LiteralPath (Join-Path $taskSource $taskDefinition)).Hash
    $taskInstalledHash = (Get-FileHash -LiteralPath (Join-Path $taskTarget $taskDefinition)).Hash
    if ($taskOriginalHash -ne $taskInstalledHash) { throw "Installed rules differ: $taskDefinition" }
}
$taskBackup = Join-Path $taskRoot "output/$Revision/installed-mod-before.zip"
if (-not (Test-Path -LiteralPath $taskBackup)) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($taskTarget, $taskBackup)
}
foreach ($taskDefinition in $taskManifest.cards) {
    $taskCard = Get-Content -LiteralPath (Join-Path $taskSource $taskDefinition) -Raw -Encoding UTF8 | ConvertFrom-Json
    $taskImage = $taskCard.'图片'
    $taskDestination = [IO.Path]::GetFullPath((Join-Path $taskTarget $taskImage))
    if (-not $taskDestination.StartsWith($taskTarget + [IO.Path]::DirectorySeparatorChar)) { throw 'Image path escaped mod directory.' }
    Copy-Item -LiteralPath (Join-Path $taskSource $taskImage) -Destination $taskDestination
    if ((Get-FileHash -LiteralPath (Join-Path $taskSource $taskImage)).Hash -ne (Get-FileHash -LiteralPath $taskDestination).Hash) { throw "Image verification failed: $taskImage" }
}
Copy-Item -LiteralPath (Join-Path $taskSource 'README.txt') -Destination (Join-Path $taskTarget 'README.txt')
# Keep the manifest byte-identical to the distributed package for peer hashes.
Copy-Item -LiteralPath (Join-Path $taskSource 'manifest.json') -Destination (Join-Path $taskTarget 'manifest.json')
Write-Output "Updated 13 installed card images; testmod $($taskManifest.version). Backup: $taskBackup"
