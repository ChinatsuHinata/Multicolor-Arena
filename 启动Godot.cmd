@echo off
setlocal
set "ROOT=%~dp0"
for %%I in ("%ROOT%..\..") do set "MAIN_ROOT=%%~fI"
set "GODOT=%MAIN_ROOT%\.godot-toolchain\editor\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 editor not found: "%GODOT%"
  pause
  exit /b 1
)
"%GODOT%" --editor --path "%ROOT%." %*
