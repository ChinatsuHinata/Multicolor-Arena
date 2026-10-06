$ErrorActionPreference = 'Stop'

function Assert-PckExportLog {
    param([string]$Path, [string]$Stage)
    # Export plugins can report errors even when Godot exits with status zero.
    $errors = @(Select-String -LiteralPath $Path -Pattern '^ERROR:|^SCRIPT ERROR:' | Where-Object {
        $_.Line -notmatch '^ERROR: Failed to read the root certificate store\.$'
    })
    if ($errors.Count -gt 0) { throw "$Stage reported errors: $((@($errors | Select-Object -First 4 -ExpandProperty Line)) -join '; ')" }
}

function Get-InstalledPckSource {
    param([string]$Root, [string]$WindowsInstallDir, [string]$FromVersion, [string]$InstalledPatchDir)
    $pck = Join-Path $WindowsInstallDir 'MulticolorArena.pck'
    if (-not (Test-Path -LiteralPath $pck -PathType Leaf)) { throw "Installed release PCK missing: $pck" }
    $pck = (Resolve-Path -LiteralPath $pck).Path
    $inspection = Join-Path $Root ('work/pck-source/' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $inspection | Out-Null
    $metadataPath = Join-Path $inspection 'metadata.json'
    $snapshot = Join-Path $inspection 'installed-windows.pck'
    if (-not $InstalledPatchDir) { $InstalledPatchDir = Join-Path $env:APPDATA 'Godot/app_userdata/极彩 Multicolour/patches' }
    $godot = Join-Path $Root '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
    & $godot --headless --log-file (Join-Path $inspection 'inspect.log') --main-pack $pck --script (Join-Path $Root 'tools/read-pck-metadata.gd') -- $metadataPath $InstalledPatchDir $snapshot | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the installed release PCK.' }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($metadata.version -cnotmatch '^[0-9]{1,5}(?:\.[0-9]{1,5}){2,3}$') { throw 'Installed PCK has no valid numeric version.' }
    if ($FromVersion -and $FromVersion -cne $metadata.version) { throw "Installed PCK version $($metadata.version) does not match requested source $FromVersion." }
    $publicKey = [IO.File]::ReadAllText((Join-Path $Root 'data/update_public.pem'), [Text.Encoding]::UTF8)
    if ($metadata.public_key -cne $publicKey) { throw 'Installed PCK and project have different release signing public keys.' }
    $effectivePck = if (@($metadata.patches).Count -gt 0) { $snapshot } else { $pck }
    Write-Host "Using installed release: $pck + $(@($metadata.patches).Count) verified patch(es) (active $($metadata.version), base $($metadata.base_version))"
    return [pscustomobject]@{ Path = $effectivePck; RawPath = $pck; Version = $metadata.version; BaseVersion = $metadata.base_version; PatchFiles = @($metadata.patches); SupportsChain = $metadata.supports_chain }
}

function Copy-PckTestProject {
    param([string]$Root, [string]$Destination, [string]$Version, [string]$PublicKeyPath)
    # A complete independent project avoids changing project.godot or source imports.
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($directory in @('addons', 'assets', 'cards', 'data', 'deck', 'net', 'recourse', 'scripts', 'tts_mod', 'tutorial', '.godot')) {
        $source = Join-Path $Root $directory
        if (-not (Test-Path -LiteralPath $source -PathType Container)) { continue }
        & robocopy.exe $source (Join-Path $Destination $directory) /E /XJ /NFL /NDL /NJH /NJS /NP /R:1 /W:1 /XD editor shader_cache /XF '~$*' | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Could not copy test project directory: $directory" }
    }
    Get-ChildItem -LiteralPath $Root -File | Where-Object { $_.Extension -in @('.gd', '.uid', '.tscn', '.tres', '.res', '.png', '.ico', '.svg', '.import') } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name)
    }
    Copy-Item -LiteralPath (Join-Path $Root 'export_presets.cfg') -Destination $Destination
    New-Item -ItemType Directory -Force -Path (Join-Path $Destination 'saves') | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'saves/decks.json') -Destination (Join-Path $Destination 'saves/decks.json')
    $project = [IO.File]::ReadAllText((Join-Path $Root 'project.godot'), [Text.Encoding]::UTF8)
    $project = [regex]::Replace($project, '(?m)^config/version="[^"]+"', ('config/version="' + $Version + '"'))
    [IO.File]::WriteAllText((Join-Path $Destination 'project.godot'), $project, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $PublicKeyPath -Destination (Join-Path $Destination 'data/update_public.pem') -Force
    [IO.File]::WriteAllText((Join-Path $Destination 'data/pck_virtual_version.json'), ('{"TEST_ONLY":true,"version":"' + $Version + '"}'), [Text.UTF8Encoding]::new($false))
}
