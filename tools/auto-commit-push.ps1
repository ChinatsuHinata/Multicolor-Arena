param(
    [string]$Message,
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Invoke-Git {
    param([string[]]$GitArgs)

    & git -C $repo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$branch = (& git -C $repo branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
    throw 'Cannot commit from a detached HEAD or outside a Git repository.'
}

$upstream = (& git -C $repo rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($upstream)) {
    throw "Branch '$branch' has no upstream. Configure one before using this script."
}

Write-Host "Repository: $repo"
Write-Host "Branch: $branch -> $upstream"
Invoke-Git @('status', '--short')

if ($Preview) {
    Write-Host 'Preview only; nothing was committed or pushed.'
    return
}

Invoke-Git @('add', '-A')
& git -C $repo diff --cached --quiet --exit-code
$diffCode = $LASTEXITCODE
if ($diffCode -gt 1) {
    throw "Could not inspect staged changes (exit code $diffCode)."
}

if ($diffCode -eq 1) {
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = '自动更新 ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    Invoke-Git @('commit', '-m', $Message)
} else {
    Write-Host 'No new changes to commit.'
}

Invoke-Git @('push')
Write-Host "Push complete: $upstream"
