param(
    [string]$Server = '8.137.122.187',
    [string]$User = 'codex',
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519_multicolor_ecs"
)
$ErrorActionPreference = 'Stop'
$relayDir = Split-Path -Parent $PSCommandPath
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$archive = Join-Path $relayDir 'deck-plaza-deploy.tar.gz'
$target = "${User}@${Server}"
$sshOptions = @('-i',$KeyPath,'-o','IdentitiesOnly=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=10','-o','ServerAliveInterval=10','-o','ServerAliveCountMax=2')
try {
    & tar -czf $archive -C $relayDir server.gd account_store.py deck_plaza_store.py deck_plaza_catalogue.json install-deck-plaza.sh
    if ($LASTEXITCODE -ne 0) { throw 'Could not package deck plaza programs.' }
    & scp @sshOptions $archive "${target}:~/deck-plaza-deploy-$stamp.tar.gz"
    if ($LASTEXITCODE -ne 0) { throw 'Deck plaza upload failed.' }
    $remoteCommand = 'set -e; stage="$HOME/.local/share/multicolor-relay/incoming-deck-plaza-' + $stamp + '"; mkdir -p "$stage"; tar -xzf "$HOME/deck-plaza-deploy-' + $stamp + '.tar.gz" -C "$stage"; bash "$stage/install-deck-plaza.sh" "$stage"'
    & ssh @sshOptions $target $remoteCommand
    if ($LASTEXITCODE -ne 0) { throw 'Deck plaza deployment failed.' }
}
finally {
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
}
