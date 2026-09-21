@echo off
setlocal
set "MULTICOLOUR_VERIFY_DIR=%~dp0"
powershell.exe -NoLogo -NoProfile -Command "function Read-Sha256([string]$p) { $stream=[IO.File]::OpenRead($p); $sha=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() } finally { $stream.Dispose(); $sha.Dispose() } }; $ErrorActionPreference='Stop'; $base=$env:MULTICOLOUR_VERIFY_DIR; try { $m=Get-Content -LiteralPath (Join-Path $base 'SHA256SUMS.json') -Raw | ConvertFrom-Json; $bad=$false; foreach($name in @('Multicolour.exe','Multicolour.pck')) { try { $expected=$m.files.PSObject.Properties[$name].Value; if($null -eq $expected) { throw 'Missing expected checksum' }; $p=Join-Path $base $name; $f=Get-Item -LiteralPath $p; $h=Read-Sha256 $p; if($f.Length -eq $expected.bytes -and $h -eq $expected.sha256) { Write-Host ('PASS '+$name) } else { $bad=$true; Write-Host ('FAIL '+$name+' - size or SHA256 mismatch') } } catch { $bad=$true; Write-Host ('MISSING/UNREADABLE '+$name+': '+$_.Exception.Message) } }; if($bad) { exit 1 }; Write-Host 'All game files match the release.'; exit 0 } catch { Write-Host ('UNREADABLE manifest: '+$_.Exception.Message); exit 2 }"
set "MULTICOLOUR_VERIFY_RESULT=%ERRORLEVEL%"
if not defined MULTICOLOUR_CHECK_NO_PAUSE pause
exit /b %MULTICOLOUR_VERIFY_RESULT%
