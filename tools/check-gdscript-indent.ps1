$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$excludedDirectories = '\\(?:\.git|\.godot|\.godot-toolchain|builds|work|tmp|output)\\'
$errors = @()
$checked = 0

function Get-GDScriptFiles($directory) {
    foreach ($entry in Get-ChildItem -LiteralPath $directory) {
        if ($entry.PSIsContainer) {
            if (($entry.FullName + '\') -notmatch $excludedDirectories) {
                Get-GDScriptFiles $entry.FullName
            }
        } elseif ($entry.Extension -eq '.gd') {
            $entry
        }
    }
}

foreach ($file in Get-GDScriptFiles $projectRoot) {
    if ($file.FullName -match $excludedDirectories) { continue }
    $checked++
    $lines = [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::UTF8)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^[ \t]*\t') {
            $relative = $file.FullName.Substring($projectRoot.Length + 1)
            $errors += '{0}:{1}: leading TAB; use spaces' -f $relative, ($i + 1)
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Output $_ }
    exit 1
}

Write-Output "Checked $checked GDScript files: no leading TAB."
