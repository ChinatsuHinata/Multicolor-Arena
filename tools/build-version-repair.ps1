param([string]$CscPath)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $CscPath) {
    $CscPath = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if (-not (Test-Path -LiteralPath $CscPath -PathType Leaf)) {
        $CscPath = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
    }
}
if (-not (Test-Path -LiteralPath $CscPath -PathType Leaf)) { throw '.NET Framework C# compiler not found.' }
$outputDir = Join-Path $root 'builds/repair-tools'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$exe = Join-Path $outputDir 'MulticolorArena-VersionRepair.exe'
& $CscPath /nologo /target:winexe /platform:anycpu /optimize+ "/out:$exe" "/win32manifest:$(Join-Path $PSScriptRoot 'version-repair.manifest')" "/win32icon:$(Join-Path $root 'icon.ico')" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Core.dll (Join-Path $PSScriptRoot 'version-repair.cs')
if ($LASTEXITCODE -ne 0) { throw 'Version repair compilation failed.' }
Copy-Item -LiteralPath (Join-Path $root 'docs/版本记录修复工具.md') -Destination (Join-Path $outputDir '使用说明.txt') -Force
$zip = Join-Path $outputDir 'MulticolorArena-VersionRepair.zip'
Compress-Archive -LiteralPath $exe, (Join-Path $outputDir '使用说明.txt') -DestinationPath $zip -Force
Write-Host "Repair tool: $exe"
Write-Host "Share package: $zip"
Get-FileHash -LiteralPath $exe -Algorithm SHA256 | Format-List Hash,Path
