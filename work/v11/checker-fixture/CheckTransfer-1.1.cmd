@echo off
setlocal
set "MULTICOLOUR_VERIFY_DIR=%~dp0"
powershell.exe -NoLogo -NoProfile -Command "function Read-Sha256([string]$p) { $stream=[IO.File]::OpenRead($p); $sha=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() } finally { $stream.Dispose(); $sha.Dispose() } }; $ErrorActionPreference='Stop'; try { $p=Join-Path $env:MULTICOLOUR_VERIFY_DIR 'MulticolorArena-1.1-win64.zip'; $h=Read-Sha256 $p; if($h -eq 'ba1eba2bbdff6fc3b9a5c4e205912bdffcf2228e33864a3c04d55ff1a2f21e6b') { Write-Host 'PASS - ZIP matches the original release. Extract to a local folder.'; exit 0 }; Write-Host 'FAIL - ZIP checksum mismatch. Copy again from the verified source.'; exit 1 } catch { Write-Host ('MISSING/UNREADABLE ZIP: '+$_.Exception.Message); exit 2 }"
set "MULTICOLOUR_VERIFY_RESULT=%ERRORLEVEL%"
if not defined MULTICOLOUR_CHECK_NO_PAUSE pause
exit /b %MULTICOLOUR_VERIFY_RESULT%
