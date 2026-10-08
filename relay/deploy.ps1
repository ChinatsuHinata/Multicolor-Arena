param(
    [string]$Server = '8.137.122.187',
    [string]$User = 'codex',
    [int]$SshPort = 22,
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519_multicolor_ecs"
)

$ErrorActionPreference = 'Stop'
$relayDir = Split-Path -Parent $PSCommandPath
$archive = Join-Path $relayDir 'relay-deploy.tar.gz'

if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH key not found: $KeyPath"
}
try {
    if (-not (Test-Path -LiteralPath (Join-Path $relayDir 'account_private.pem') -PathType Leaf)) {
        throw 'Account private key is missing; do not deploy an account client with a different key.'
    }
    & tar -czf $archive -C $relayDir project.godot server.gd match_queue.gd account_store.py deck_plaza_store.py deck_plaza_catalogue.json account_private.pem update_gateway.py multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service multicolor-update-gateway-user.service install-user.sh
    if ($LASTEXITCODE -ne 0) { throw 'Could not package relay files.' }
    & scp -i $KeyPath -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=2 -P $SshPort $archive "${User}@${Server}:~/relay-deploy.tar.gz"
    if ($LASTEXITCODE -ne 0) { throw 'SCP upload failed.' }
    & ssh -i $KeyPath -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=2 -p $SshPort "${User}@${Server}" 'mkdir -p ~/.local/share/multicolor-relay && tar -xzf ~/relay-deploy.tar.gz -C ~/.local/share/multicolor-relay && rm ~/relay-deploy.tar.gz && bash ~/.local/share/multicolor-relay/install-user.sh'
    if ($LASTEXITCODE -ne 0) { throw 'Remote installation failed.' }
}
finally {
    Remove-Item -LiteralPath $archive -ErrorAction SilentlyContinue
}
