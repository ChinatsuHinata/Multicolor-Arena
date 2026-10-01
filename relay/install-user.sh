#!/usr/bin/env bash
set -euo pipefail

relay_dir="$HOME/.local/share/multicolor-relay"
bin_dir="$HOME/.local/bin"
unit_dir="$HOME/.config/systemd/user"
mkdir -p "$relay_dir" "$bin_dir" "$unit_dir"
mkdir -p "$relay_dir/data"
chmod 700 "$relay_dir/data"
chmod 600 "$relay_dir/account_private.pem"

if [ ! -x "$bin_dir/godot" ]; then
    command -v curl >/dev/null || { echo 'curl is required to download Godot.' >&2; exit 1; }
    command -v python3 >/dev/null || { echo 'python3 is required to extract Godot.' >&2; exit 1; }
    zip_path="$(mktemp "$relay_dir/godot.XXXXXX.zip")"
    trap 'rm -f "$zip_path"' EXIT
    curl --fail --location --retry 3 --output "$zip_path" \
        'https://downloads.godotengine.org/?version=4.7.2&flavor=stable&platform=linux.64&slug=linux.x86_64.zip'
    python3 - "$zip_path" "$bin_dir/godot" <<'PY'
import os
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    name = 'Godot_v4.7.2-stable_linux.x86_64'
    with archive.open(name) as source, open(sys.argv[2], 'wb') as target:
        while chunk := source.read(1024 * 1024):
            target.write(chunk)
os.chmod(sys.argv[2], 0o755)
PY
fi

"$bin_dir/godot" --version
ws_backup="$unit_dir/multicolor-relay-ws-user.service.before-updates"
if [ -f "$unit_dir/multicolor-relay-ws-user.service" ]; then
    cp "$unit_dir/multicolor-relay-ws-user.service" "$ws_backup"
fi
rollback_gateway() {
    echo 'Update gateway deployment failed; restoring the previous WebSocket service.' >&2
    systemctl --user stop multicolor-update-gateway-user.service || true
    systemctl --user disable multicolor-update-gateway-user.service || true
    if [ -f "$ws_backup" ]; then
        cp "$ws_backup" "$unit_dir/multicolor-relay-ws-user.service"
        systemctl --user daemon-reload
        systemctl --user restart multicolor-relay-ws-user.service || true
    fi
}
trap rollback_gateway ERR
cp "$relay_dir/multicolor-relay-user.service" "$unit_dir/"
cp "$relay_dir/multicolor-relay-ws-user.service" "$unit_dir/"
cp "$relay_dir/multicolor-update-gateway-user.service" "$unit_dir/"
cp "$relay_dir/multicolor-account-user.service" "$unit_dir/"
systemctl --user daemon-reload
systemctl --user enable multicolor-account-user.service
systemctl --user restart multicolor-account-user.service
systemctl --user enable multicolor-relay-user.service
systemctl --user enable multicolor-relay-ws-user.service
systemctl --user enable multicolor-update-gateway-user.service
systemctl --user restart multicolor-relay-user.service multicolor-relay-ws-user.service
systemctl --user restart multicolor-update-gateway-user.service
sleep 1
systemctl --user is-active --quiet multicolor-relay-ws-user.service
systemctl --user is-active --quiet multicolor-update-gateway-user.service
gateway_code="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 http://127.0.0.1:47862/updates/latest.json)"
[ "$gateway_code" = '200' ] || [ "$gateway_code" = '404' ]
trap - ERR
if ! loginctl enable-linger "$USER"; then
    echo 'Warning: user lingering could not be enabled; the service may stop after logout.' >&2
fi
systemctl --user --no-pager status multicolor-relay-user.service
systemctl --user --no-pager status multicolor-relay-ws-user.service
systemctl --user --no-pager status multicolor-update-gateway-user.service
systemctl --user --no-pager status multicolor-account-user.service
loginctl show-user "$USER" -p Linger
