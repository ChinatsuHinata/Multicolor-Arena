param(
    [string]$Server = '8.137.122.187',
    [string]$User = 'codex',
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519_multicolor_ecs",
    [switch]$StoreOnly
)
$ErrorActionPreference = 'Stop'
$relayDir = Split-Path -Parent $PSCommandPath
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$archive = Join-Path $relayDir 'tournaments-deploy.tar.gz'
$target = "${User}@${Server}"
$sshOptions = @('-i',$KeyPath,'-o','IdentitiesOnly=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=10','-o','ConnectionAttempts=1','-o','ServerAliveInterval=10','-o','ServerAliveCountMax=2')
try {
    & tar -czf $archive -C $relayDir server.gd account_store.py tournament_store.py tournament_pairing.py install-tournaments.sh
    if ($LASTEXITCODE -ne 0) { throw 'Could not package competition service.' }
    & scp @sshOptions $archive "${target}:~/tournaments-deploy-$stamp.tar.gz"
    if ($LASTEXITCODE -ne 0) { throw 'Competition upload failed.' }
    $installMode = if ($StoreOnly) { 'store-only' } else { 'full' }
    $remoteCommand = 'set -e; stage="$HOME/.local/share/multicolor-relay/incoming-tournaments-' + $stamp + '"; mkdir -p "$stage"; tar -xzf "$HOME/tournaments-deploy-' + $stamp + '.tar.gz" -C "$stage"; bash "$stage/install-tournaments.sh" "$stage" ' + $installMode
    & ssh @sshOptions $target $remoteCommand
    if ($LASTEXITCODE -ne 0) { throw 'Competition deployment failed.' }
}
finally {
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
}
