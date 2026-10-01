param(
    [string]$ApkPath,
    [string]$Address,
    [ValidateRange(1, 65535)][int]$Port = 8765
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

if (-not $ApkPath) {
    $latest = Get-ChildItem -LiteralPath (Join-Path $root 'builds/Android-debug') -Filter '*.apk' -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw 'No APK found in builds/Android-debug. Build one or pass -ApkPath.' }
    $ApkPath = $latest.FullName
} elseif (-not [IO.Path]::IsPathRooted($ApkPath)) {
    $ApkPath = Join-Path $root $ApkPath
}
$apk = Get-Item -LiteralPath $ApkPath
if ($apk -isnot [IO.FileInfo] -or $apk.Extension -ine '.apk') { throw 'Only an APK file can be shared.' }

if (-not $Address) {
    $wifiAddresses = @(
        [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.NetworkInterfaceType -eq 'Wireless80211' -and $_.OperationalStatus -eq 'Up' } |
            ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
            Where-Object { $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.Address }
    )
    if ($wifiAddresses.Count -ne 1) {
        throw 'Could not select one Wi-Fi IPv4 address. Pass -Address <PC Wi-Fi IPv4>.'
    }
    $ip = $wifiAddresses[0]
} else {
    $ip = [Net.IPAddress]::Parse($Address)
    if ($ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Use a Wi-Fi IPv4 address.' }
}

$secret = New-Object byte[] 16
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($secret) } finally { $rng.Dispose() }
$token = [BitConverter]::ToString($secret).Replace('-', '').ToLowerInvariant()
$urlPath = "/$token/MulticolorArena.apk"
$url = "http://$($ip.IPAddressToString):$Port$urlPath"
$listener = [Net.Sockets.TcpListener]::new($ip, $Port)
$listener.Start()

function Send-Response($stream, [int]$status, [string]$reason, [string[]]$headers) {
    $lines = @("HTTP/1.1 $status $reason") + $headers + @('Connection: close', '', '')
    $bytes = [Text.Encoding]::ASCII.GetBytes(($lines -join "`r`n"))
    $stream.Write($bytes, 0, $bytes.Length)
}

Write-Host "APK: $($apk.FullName)"
Write-Host "Size: $([math]::Round($apk.Length / 1MB, 1)) MiB"
Write-Host "Phone URL: $url"
Write-Host 'Keep this window open while downloading. Press Ctrl+C to stop.'

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.NoDelay = $true
            $client.ReceiveTimeout = 10000
            $client.SendTimeout = 120000
            $stream = $client.GetStream()
            $header = [Collections.Generic.List[byte]]::new()
            while ($header.Count -lt 16384) {
                $value = $stream.ReadByte()
                if ($value -lt 0) { break }
                $header.Add([byte]$value)
                $n = $header.Count
                if ($n -ge 4 -and $header[$n-4] -eq 13 -and $header[$n-3] -eq 10 -and
                    $header[$n-2] -eq 13 -and $header[$n-1] -eq 10) { break }
            }
            $request = [Text.Encoding]::ASCII.GetString($header.ToArray())
            if (-not $request.EndsWith("`r`n`r`n")) {
                Send-Response $stream 431 'Request Header Fields Too Large' @('Content-Length: 0')
                continue
            }
            $lines = $request -split "`r`n"
            $first = $lines[0] -split ' '
            if ($first.Count -ne 3 -or $first[0] -notin @('GET', 'HEAD') -or $first[2] -notin @('HTTP/1.0', 'HTTP/1.1')) {
                Send-Response $stream 400 'Bad Request' @('Content-Length: 0')
                continue
            }
            if ($first[1] -cne $urlPath) {
                Send-Response $stream 404 'Not Found' @('Content-Length: 0')
                continue
            }
            $start = [long]0
            $end = [long]($apk.Length - 1)
            $partial = $false
            $rangeHeader = $lines | Where-Object { $_ -imatch '^Range:' } | Select-Object -First 1
            if ($rangeHeader) {
                $range = [regex]::Match($rangeHeader, '^Range:\s*bytes=(\d*)-(\d*)\s*$', 'IgnoreCase')
                if (-not $range.Success -or ($range.Groups[1].Value -eq '' -and $range.Groups[2].Value -eq '')) {
                    Send-Response $stream 416 'Range Not Satisfiable' @("Content-Range: bytes */$($apk.Length)", 'Content-Length: 0')
                    continue
                }
                if ($range.Groups[1].Value -ne '') {
                    $start = [long]::Parse($range.Groups[1].Value)
                    if ($range.Groups[2].Value -ne '') { $end = [Math]::Min([long]::Parse($range.Groups[2].Value), $end) }
                } else {
                    $start = [Math]::Max([long]0, $apk.Length - [long]::Parse($range.Groups[2].Value))
                }
                if ($start -gt $end -or $start -ge $apk.Length) {
                    Send-Response $stream 416 'Range Not Satisfiable' @("Content-Range: bytes */$($apk.Length)", 'Content-Length: 0')
                    continue
                }
                $partial = $true
            }
            $length = $end - $start + 1
            $headers = @(
                "Content-Length: $length",
                'Content-Type: application/vnd.android.package-archive',
                'Content-Disposition: attachment; filename="MulticolorArena.apk"',
                'Accept-Ranges: bytes',
                'Cache-Control: no-store',
                'X-Content-Type-Options: nosniff'
            )
            if ($partial) { $headers += "Content-Range: bytes $start-$end/$($apk.Length)" }
            Send-Response $stream $(if ($partial) { 206 } else { 200 }) $(if ($partial) { 'Partial Content' } else { 'OK' }) $headers
            if ($first[0] -eq 'HEAD') { continue }
            Write-Host "Sending $length bytes to $($client.Client.RemoteEndPoint)..."
            $file = [IO.File]::OpenRead($apk.FullName)
            try {
                $file.Position = $start
                $buffer = New-Object byte[] (1024 * 1024)
                while ($length -gt 0) {
                    $count = $file.Read($buffer, 0, [int][Math]::Min($buffer.Length, $length))
                    if ($count -eq 0) { break }
                    $stream.Write($buffer, 0, $count)
                    $length -= $count
                }
            } finally { $file.Dispose() }
        } catch [IO.IOException] {
            Write-Warning "Client disconnected: $($_.Exception.Message)"
        } catch {
            Write-Warning "Request failed: $($_.Exception.Message)"
        } finally {
            $client.Dispose()
        }
    }
} finally {
    $listener.Stop()
}
