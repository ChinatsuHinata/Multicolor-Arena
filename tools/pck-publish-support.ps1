$ErrorActionPreference = 'Stop'

function ConvertTo-PckVersion {
    param([string]$Value)
    if ($Value -cnotmatch '^[0-9]{1,5}(?:\.[0-9]{1,5}){2,3}$') { throw "Invalid PCK version: $Value" }
    $parts = @($Value.Split('.') | ForEach-Object { [int]$_ })
    while ($parts.Count -lt 4) { $parts += 0 }
    return [version]::new($parts[0], $parts[1], $parts[2], $parts[3])
}

function Assert-PckPublication {
    param($Previous, [string]$Version, [switch]$ReplaceExisting)
    $targetVersion = ConvertTo-PckVersion $Version
    if ($targetVersion -le (ConvertTo-PckVersion '1.2.7.1')) { throw 'PCK target must be newer than 1.2.7.1.' }
    if ($Previous) {
        $previousVersion = ConvertTo-PckVersion $Previous.version
        if ($targetVersion -lt $previousVersion) { throw 'Cannot replace an older release with newer dependent patches; publish a new version.' }
        if ($targetVersion -eq $previousVersion -and -not $ReplaceExisting) {
            throw 'Version already published. Use -ReplaceExisting to replace the current cloud release explicitly.'
        }
    }
}

function Assert-PckEdge {
    param($Edge, [string]$Origin, [string]$LatestVersion)
    $from = ConvertTo-PckVersion $Edge.from
    $to = ConvertTo-PckVersion $Edge.to
    if ($from -lt (ConvertTo-PckVersion '1.2.7.1') -or $to -le $from -or $to -gt (ConvertTo-PckVersion $LatestVersion)) {
        throw 'Invalid PCK chain edge versions.'
    }
    foreach ($platform in @('windows', 'android')) {
        $asset = $Edge.$platform
        if (-not $asset -or $asset.sha256 -cnotmatch '^[0-9a-fA-F]{64}$' -or
            $asset.size -isnot [ValueType] -or [double]$asset.size -ne [long]$asset.size -or [long]$asset.size -le 4096) {
            throw "Invalid $platform PCK asset."
        }
        $prefix = "$Origin/updates/pck/$($Edge.to)/MulticolorArena-$($Edge.from)-to-$($Edge.to)-$platform"
        $hashedUrl = "$prefix-$($asset.sha256.ToLowerInvariant()).pck"
        if ($asset.url -cne "$prefix.pck" -and $asset.url -cne $hashedUrl) { throw 'Invalid PCK asset URL.' }
    }
}

function Merge-PckChain {
    param($Previous, [object[]]$NewEdges, [string]$Version, [string]$Origin, [switch]$ReplaceExisting)
    Assert-PckPublication -Previous $Previous -Version $Version -ReplaceExisting:$ReplaceExisting
    $edges = [Collections.Generic.List[object]]::new()
    if ($Previous) {
        if ($Previous.format -cne 'multicolor:arena/pck-latest-1' -or $Previous.game -cne 'multicolor:arena' -or $Previous.base -cne '1.2.7.1') {
            throw 'Unsupported previous PCK manifest.'
        }
        $oldEdges = if ($Previous.PSObject.Properties['patches']) { @($Previous.patches) } else {
            @([pscustomobject]@{ from = $Previous.base; to = $Previous.version; windows = $Previous.windows; android = $Previous.android })
        }
        $seen = @{}
        foreach ($edge in $oldEdges) {
            Assert-PckEdge $edge $Origin $Previous.version
            $id = "$($edge.from)->$($edge.to)"
            if ($seen.ContainsKey($id)) { throw 'Duplicate existing PCK chain edge.' }
            $seen[$id] = $true
            $edges.Add($edge)
        }
    }
    $newIds = @{}
    foreach ($edge in $NewEdges) {
        Assert-PckEdge $edge $Origin $Version
        if ($edge.to -cne $Version) { throw 'New patch must target the current release.' }
        $id = "$($edge.from)->$($edge.to)"
        if ($newIds.ContainsKey($id)) { throw 'Duplicate new PCK chain edge.' }
        $newIds[$id] = $true
        for ($i = $edges.Count - 1; $i -ge 0; $i--) {
            if ($edges[$i].from -ceq $edge.from -and $edges[$i].to -ceq $edge.to) { $edges.RemoveAt($i) }
        }
        $edges.Add($edge)
    }
    # Replacing a version invalidates all old routes to that same target revision.
    if ($Previous -and $Previous.version -ceq $Version) {
        for ($i = $edges.Count - 1; $i -ge 0; $i--) {
            $id = "$($edges[$i].from)->$($edges[$i].to)"
            if ($edges[$i].to -ceq $Version -and -not $newIds.ContainsKey($id)) { $edges.RemoveAt($i) }
        }
    }
    if ($edges.Count -eq 0 -or $edges.Count -gt 128) { throw 'PCK chain exceeds the supported 128 edges.' }
    $cumulative = @($edges | Where-Object { $_.from -ceq '1.2.7.1' -and $_.to -ceq $Version })
    if ($cumulative.Count -ne 1) { throw 'A cumulative fixed-base patch is required for legacy clients.' }
    return [ordered]@{
        format = 'multicolor:arena/pck-latest-1'; game = 'multicolor:arena'; base = '1.2.7.1'
        version = $Version; windows = $cumulative[0].windows; android = $cumulative[0].android; patches = $edges.ToArray()
    }
}

function ConvertTo-PosixLiteral {
    param([string]$Value)
    $apostrophe = [string][char]39
    $quote = [string][char]34
    return $apostrophe + $Value.Replace($apostrophe, $apostrophe + $quote + $apostrophe + $quote + $apostrophe) + $apostrophe
}

function New-PckActivationCommand {
    param([string]$RemoteRoot, [string]$Incoming, [string]$Version, [string]$SnapshotName,
          [string]$ExpectedHash, [switch]$ReplaceExisting)
    [void](ConvertTo-PckVersion $Version)
    if ($RemoteRoot -cne '/home/codex/.local/share/multicolor-updates/pck' -or
        $Incoming -cnotmatch ('^' + [regex]::Escape($RemoteRoot) + '/\.incoming-' + [regex]::Escape($Version) + '-[0-9a-f]{32}$')) {
        throw 'Unexpected cloud staging path.'
    }
    if ($SnapshotName -notin @('MISSING', 'latest.json', 'chain.json') -or
        ($SnapshotName -ne 'MISSING' -and $ExpectedHash -cnotmatch '^[0-9a-f]{64}$')) { throw 'Invalid cloud snapshot.' }
    $compare = if ($SnapshotName -eq 'MISSING') {
        "test ! -e '$RemoteRoot/latest.json' && test ! -e '$RemoteRoot/chain.json'"
    } elseif ($SnapshotName -eq 'latest.json') {
        "test ! -e '$RemoteRoot/chain.json' && printf '%s  %s\n' '$ExpectedHash' '$RemoteRoot/latest.json' | sha256sum -c -"
    } else {
        "printf '%s  %s\n' '$ExpectedHash' '$RemoteRoot/chain.json' | sha256sum -c -"
    }
    $guard = if ($ReplaceExisting) { ':' } else { "test ! -e '$RemoteRoot/$Version'" }
    $hashSuffix = '?' * 64
    $script = @"
set -eu
cd '$Incoming'
sha256sum -c SHA256SUMS
if ! ( $compare ); then echo 'Cloud manifest changed; rebuild the chain and retry.' >&2; exit 1; fi
if ! ( $guard ); then echo 'Version already published; use -ReplaceExisting.' >&2; exit 1; fi
mkdir -p '$RemoteRoot/$Version'
for file in *.pck; do
  case "`$file" in
    *-${hashSuffix}.pck)
      if [ -e '$RemoteRoot/$Version/'"`$file" ]; then
        cmp "`$file" '$RemoteRoot/$Version/'"`$file"
        rm -- "`$file"
      else
        mv "`$file" '$RemoteRoot/$Version/'"`$file"
      fi ;;
    *) cp "`$file" '$RemoteRoot/$Version/'"`$file.new"; mv '$RemoteRoot/$Version/'"`$file.new" '$RemoteRoot/$Version/'"`$file"; rm -- "`$file" ;;
  esac
done
cp latest.json '$RemoteRoot/$Version/latest.json'
cp chain.json '$RemoteRoot/$Version/chain.json'
cp latest.json '$RemoteRoot/latest.json.new'
mv '$RemoteRoot/latest.json.new' '$RemoteRoot/latest.json'
cp chain.json '$RemoteRoot/chain.json.new'
mv '$RemoteRoot/chain.json.new' '$RemoteRoot/chain.json'
rm -- latest.json chain.json SHA256SUMS
cd '$RemoteRoot'
rmdir '$Incoming'
"@
    return "flock -x '$RemoteRoot/.publish.lock' sh -c " + (ConvertTo-PosixLiteral $script.Replace("`r", ''))
}
