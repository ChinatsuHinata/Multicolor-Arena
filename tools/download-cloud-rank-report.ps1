#requires -Version 5.1
param(
    [string]$OutputDir = 'D:\云端报告',
    [ValidateSet('rank', 'characters')][string]$Report = 'rank',
    [switch]$EnableCharacterRecording,
    [string]$Server = '8.137.122.187',
    [string]$User = 'codex',
    [int]$SshPort = 22,
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519_multicolor_ecs",
    [Security.SecureString]$Passphrase,
    [switch]$UpdatePassphrase,
    [string]$SnapshotFile,
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $PythonPath) {
    $candidates = @(
        $env:MULTICOLOR_PYTHON,
        (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
    )
    $candidates += @(Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    $PythonPath = $candidates | Where-Object {
        $_ -and $_ -notmatch '\\WindowsApps\\' -and (Test-Path -LiteralPath $_ -PathType Leaf)
    } | Select-Object -First 1
}
if (-not $PythonPath) { throw '找不到 Python 3，请安装 Python 或设置 MULTICOLOR_PYTHON。' }

$reportScript = if ($Report -eq 'characters') { 'download-cloud-character-report.py' } else { 'download-cloud-rank-report.py' }
if ($EnableCharacterRecording) {
    if ($SnapshotFile) { throw '启用云端采集不能同时使用本地快照。' }
    $reportScript = 'install-cloud-character-recorder.py'
}
$pythonArgs = @((Join-Path $PSScriptRoot $reportScript), '--output-dir', $OutputDir)
if ($EnableCharacterRecording) { $pythonArgs += '--confirm-service-restart' }
$credentialPath = $null
$savePassphrase = $false
$oldPhrase = [Environment]::GetEnvironmentVariable('MULTICOLOR_REPORT_KEY_PASSPHRASE', 'Process')
try {
    if ($SnapshotFile) {
        $pythonArgs += @('--snapshot-file', $SnapshotFile)
    } else {
        if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) { throw "找不到 SSH 私钥：$KeyPath" }
        $cacheDir = Join-Path $root 'work/cloud-report'
        [void][IO.Directory]::CreateDirectory($cacheDir)
        $credentialName = 'ssh-{0}-{1}-{2}.dpapi' -f ($Server -replace '[^a-zA-Z0-9.-]', '_'), ($User -replace '[^a-zA-Z0-9_-]', '_'), $SshPort
        $credentialPath = Join-Path $cacheDir $credentialName
        if (-not $Passphrase -and -not $UpdatePassphrase -and (Test-Path -LiteralPath $credentialPath)) {
            $Passphrase = Get-Content -LiteralPath $credentialPath -Raw | ConvertTo-SecureString
        } else {
            if (-not $Passphrase) { $Passphrase = Read-Host 'SSH 私钥口令（仅保存在本机当前 Windows 账户的加密缓存）' -AsSecureString }
            $savePassphrase = $true
        }
        if (-not $Passphrase -or $Passphrase.Length -eq 0) { throw 'SSH 口令不能为空。' }
        $helper = Join-Path $cacheDir 'askpass.exe'
        $helperSource = Join-Path $PSScriptRoot 'support/cloud-report-askpass.cs'
        if (-not (Test-Path -LiteralPath $helper) -or (Get-Item -LiteralPath $helperSource).LastWriteTimeUtc -gt (Get-Item -LiteralPath $helper).LastWriteTimeUtc) {
            $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
            if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe' }
            & $compiler /nologo /target:exe "/out:$helper" $helperSource
            if ($LASTEXITCODE -ne 0) { throw '无法编译 SSH 口令助手。' }
        }
        $phrasePointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Passphrase)
        try {
            $env:MULTICOLOR_REPORT_KEY_PASSPHRASE = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($phrasePointer)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($phrasePointer)
        }
        $pythonArgs += @('--server', $Server, '--user', $User, '--ssh-port', "$SshPort", '--key-path', $KeyPath, '--askpass-exe', $helper)
        if ($EnableCharacterRecording) { Write-Warning '正在安装自机采集补丁并重启两个中转服务，当前连接会断开。' }
        else { Write-Host "正在读取云端报告数据：${User}@${Server}" }
    }
    $resultJson = & $PythonPath @pythonArgs
    if ($LASTEXITCODE -ne 0) { throw "报告生成失败，退出码 $LASTEXITCODE。" }
    $result = ($resultJson -join "`n") | ConvertFrom-Json
    if ($savePassphrase) {
        $encrypted = ConvertFrom-SecureString -SecureString $Passphrase
        [IO.File]::WriteAllText($credentialPath, $encrypted, [Text.UTF8Encoding]::new($false))
    }
    if ($EnableCharacterRecording) {
        Write-Host "自机采集状态：$($result.status)；中转已重启：$($result.restarted)。"
        if ($result.backup) { Write-Host "云端原文件备份：$($result.backup)" }
        return
    }
    Write-Host "CSV 报告已生成（$($result.rows) 条）：$($result.report)"
    Write-Host "最新 CSV：$($result.latest)"
    Write-Host "数据时间：$($result.snapshot_time_china)（北京时间）"
    if ($Report -eq 'characters') {
        Write-Host "段位结算对局：$($result.eligible_matches) 场；有双方自机记录：$($result.covered_matches) 场。"
        if ($result.status -ne 'complete') { Write-Warning '自机数据不完整，具体缺失和统计范围见报告。' }
    }
} finally {
    [Environment]::SetEnvironmentVariable('MULTICOLOR_REPORT_KEY_PASSPHRASE', $oldPhrase, 'Process')
    $Passphrase = $null
}
