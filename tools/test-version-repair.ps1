$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe' }
$testDir = Join-Path $root ('work/version-repair-tests/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
$testExe = Join-Path $testDir 'VersionRepairTests.exe'
& $csc /nologo /target:exe /main:VersionRepairTests "/out:$testExe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Core.dll (Join-Path $PSScriptRoot 'version-repair.cs') (Join-Path $PSScriptRoot 'test-version-repair.cs')
if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
& $testExe $testDir
if ($LASTEXITCODE -ne 0) { throw 'Version repair tests failed.' }
