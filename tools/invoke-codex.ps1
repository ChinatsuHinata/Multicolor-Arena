[CmdletBinding(DefaultParameterSetName = 'Prompt')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Prompt')]
    [ValidateNotNullOrEmpty()]
    [string]$Prompt,
    [Parameter(Mandatory = $true, ParameterSetName = 'PromptFile')]
    [string]$PromptFile,
    [Parameter(Mandatory = $true, ParameterSetName = 'Check')]
    [switch]$Check,
    [Parameter(Mandatory = $true, ParameterSetName = 'ShowCli')]
    [switch]$ShowCli,
    [string]$OutputFile = 'work/codex-last-message.txt',
    [string]$Model = 'gpt-6.1-sol',
    [ValidateSet('low', 'medium', 'high', 'xhigh')]
    [string]$ReasoningEffort = 'xhigh',
    [ValidateSet('read-only', 'workspace-write')]
    [string]$Sandbox = 'workspace-write'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$candidates = @()
if ($env:CODEX_CLI_PATH) { $candidates += $env:CODEX_CLI_PATH }
if ($env:LOCALAPPDATA) {
    $appBin = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $appBin) {
        $candidates += Get-ChildItem -LiteralPath $appBin -Directory |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object { Join-Path $_.FullName 'codex.exe' }
    }
}
$candidates += Get-Command codex.exe, codex.cmd, codex.ps1 -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Source

$cli = $null
$cliVersion = $null
foreach ($candidate in ($candidates | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
    $ErrorActionPreference = 'Continue'
    $versionText = (& $candidate --version 2>$null | Out-String).Trim()
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0 -and $versionText -match 'codex-cli\s+(\d+\.\d+\.\d+)([^\s]*)') {
        # The old npm CLI cannot read the desktop app's current model catalog.
        if ([version]$Matches[1] -ge [version]'0.163.0') {
            $cli = $candidate
            $cliVersion = $Matches[1] + $Matches[2]
            break
        }
    }
}
if (-not $cli) {
    throw 'No compatible Codex CLI found (requires 0.163.0 or newer). Install/update the Codex desktop app, or set CODEX_CLI_PATH to its codex.exe. Do not use the old npm CLI with the current model cache.'
}
if ($ShowCli) {
    [pscustomobject]@{ Path = $cli; Version = $cliVersion; Model = $Model } | ConvertTo-Json
    exit 0
}

if ($Check) {
    $Prompt = 'This is a connection check only. Do not call tools, inspect files, modify files, or delegate. Reply with exactly CODEX_BRIDGE_OK.'
    $Sandbox = 'read-only'
    $ReasoningEffort = 'low'
    if (-not $PSBoundParameters.ContainsKey('OutputFile')) { $OutputFile = 'work/codex-bridge-check.txt' }
} elseif ($PSCmdlet.ParameterSetName -eq 'PromptFile') {
    if (-not [System.IO.Path]::IsPathRooted($PromptFile)) { $PromptFile = Join-Path $projectRoot $PromptFile }
    $Prompt = [System.IO.File]::ReadAllText($PromptFile, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($Prompt)) { throw 'The prompt file is empty.' }
}

$workRoot = Join-Path $projectRoot 'work'
if (-not [System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile = Join-Path $projectRoot $OutputFile }
$OutputFile = [System.IO.Path]::GetFullPath($OutputFile)
if (-not $OutputFile.StartsWith($workRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputFile must be inside this project''s work directory.'
}
[System.IO.Directory]::CreateDirectory((Split-Path -Parent $OutputFile)) | Out-Null
$logFile = $OutputFile + '.log'
# A failed invocation must never leave a previous successful reply at this path.
if (Test-Path -LiteralPath $OutputFile) { Remove-Item -LiteralPath $OutputFile }

$cliArgs = @('exec', '-C', $projectRoot, '-s', $Sandbox, '--color', 'never',
    '-m', $Model, '-c', ('model_reasoning_effort="{0}"' -f $ReasoningEffort), '-o', $OutputFile)
if ($Check) { $cliArgs += '--ephemeral' }
$cliArgs += '-'
Write-Host "Codex CLI: $cli ($cliVersion)"
Write-Host "Model: $Model; sandbox: $Sandbox; log: $logFile"

# Pipe UTF-8 input so Chinese text and embedded quotes survive Windows PowerShell.
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
# Windows PowerShell turns redirected native stderr into non-terminating errors.
# Preserve those diagnostics in the log and use the process exit code for success.
$ErrorActionPreference = 'Continue'
$Prompt | & $cli @cliArgs 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $logFile
$cliExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($cliExitCode -ne 0) {
    Write-Error "Codex failed with exit code $cliExitCode. See $logFile" -ErrorAction Continue
    exit $cliExitCode
}
if (-not (Test-Path -LiteralPath $OutputFile) -or (Get-Item -LiteralPath $OutputFile).Length -eq 0) {
    throw "Codex returned no final message. See $logFile"
}
if ($Check -and [System.IO.File]::ReadAllText($OutputFile).Trim() -cne 'CODEX_BRIDGE_OK') {
    throw "Unexpected connection-check reply. See $OutputFile and $logFile"
}
Write-Host "Final message: $OutputFile"
exit 0
