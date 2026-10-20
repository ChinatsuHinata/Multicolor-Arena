param([switch]$Install)
$ErrorActionPreference = 'Stop'
# Preserve the previous command as an alias to the complete current workflow.
& (Join-Path $PSScriptRoot 'build_testmod_spacing.ps1') -Install:$Install
