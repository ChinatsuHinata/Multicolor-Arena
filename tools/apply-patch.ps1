param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$PatchPath,
    [Parameter(Mandatory = $true)][string]$FromVersion,
    [Parameter(Mandatory = $true)][string]$ToVersion
)

$ErrorActionPreference = 'Stop'
try {
    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
        throw "Installation folder does not exist: $InstallDir"
    }
    Add-Type -Path (Join-Path $PSScriptRoot 'patch-engine.cs')
    [ArenaPatch]::Apply($InstallDir, $PatchPath, $FromVersion, $ToVersion)
    Write-Host "Updated multicolor:arena from $FromVersion to $ToVersion"
    exit 0
}
catch {
    Write-Error "Patch failed. Close the game and check the installed base version. $($_.Exception.Message)"
    exit 1
}
