$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$excludedDirectories = '\\(?:\.git|\.godot|\.godot-toolchain|builds)\\'
$errors = @()
$checked = 0

foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Filter '*.gd') {
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
