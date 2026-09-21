@echo off
setlocal
set "MULTICOLOUR_VERIFY_DIR=%~dp0"
powershell.exe -NoLogo -NoProfile -Command "function Read-Sha256([string]$p) { $stream=[IO.File]::OpenRead($p); $sha=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() } finally { $stream.Dispose(); $sha.Dispose() } }; $ErrorActionPreference='Stop'; try { $p=Join-Path $env:MULTICOLOUR_VERIFY_DIR 'MulticolorArena-1.0-win64.zip'; $h=Read-Sha256 $p; if($h -eq '79bf32428064749e8d00d96ea5bfc3fe1909318cb478716d09cf342d93c27d94') { Write-Host 'PASS - ZIP matches the original release. Extract to a local folder.'; exit 0 }; Write-Host 'FAIL - ZIP checksum mismatch. Copy again from the verified source.'; exit 1 } catch { Write-Host ('MISSING/UNREADABLE ZIP: '+$_.Exception.Message); exit 2 }"
set "MULTICOLOUR_VERIFY_RESULT=%ERRORLEVEL%"
if not defined MULTICOLOUR_CHECK_NO_PAUSE pause
exit /b %MULTICOLOUR_VERIFY_RESULT%
