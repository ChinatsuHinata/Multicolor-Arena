param([string]$JavaSdkPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path '.godot-toolchain/jdk-17'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw 'Python 3 is required to prepare the Android replay import templates.' }
& $python.Source (Join-Path $PSScriptRoot 'build_android_replay_template.py') --root $root --jdk $JavaSdkPath
if ($LASTEXITCODE -ne 0) { throw 'Android replay template preparation failed.' }
