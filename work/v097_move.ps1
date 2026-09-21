$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath('C:\Users\tzx20\Documents\test')
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'work\v097-migration.json') -Raw -Encoding utf8 | ConvertFrom-Json
$prefix = $projectRoot + [System.IO.Path]::DirectorySeparatorChar
# Verify every absolute source and target before moving any individual file.
foreach ($entry in $manifest.moves) {
    $source = [System.IO.Path]::GetFullPath($entry.source)
    $destination = [System.IO.Path]::GetFullPath($entry.destination)
    if (-not $source.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not $destination.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Move escaped project directory' }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Test-Path -LiteralPath $destination)) { throw "Source missing or destination exists: $source" }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Source changed: $source" }
}
$database = Join-Path $projectRoot 'recourse\数据库'
New-Item -ItemType Directory -Path $database -Force | Out-Null
foreach ($entry in $manifest.moves) {
    Move-Item -LiteralPath $entry.source -Destination $entry.destination
    $metadata = $entry.source + '.import'
    if (Test-Path -LiteralPath $metadata) {
        $nextMetadata = $entry.destination + '.import'
        Move-Item -LiteralPath $metadata -Destination $nextMetadata
        $text = Get-Content -LiteralPath $nextMetadata -Raw -Encoding utf8
        $text = [System.Text.RegularExpressions.Regex]::Replace($text, '(?m)^source_file="[^"]*"', ('source_file="' + $entry.image + '"'))
        [System.IO.File]::WriteAllText($nextMetadata, $text, [System.Text.UTF8Encoding]::new($false))
    }
    $text = Get-Content -LiteralPath $entry.definition -Raw -Encoding utf8
    if (-not $text.Contains($entry.old_image)) { throw "Definition changed: $($entry.definition)" }
    [System.IO.File]::WriteAllText($entry.definition, $text.Replace($entry.old_image, $entry.image), [System.Text.UTF8Encoding]::new($false))
    if ((Get-FileHash -LiteralPath $entry.destination -Algorithm SHA256).Hash -ne $entry.sha256) { throw 'Moved image hash mismatch' }
}
Write-Output 'Moved 65 existing card images and their metadata; references updated. No new IDs registered.'
