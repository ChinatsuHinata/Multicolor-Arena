#!/usr/bin/env bash
set -euo pipefail
staging_dir="${1:?staging directory required}"
relay_dir="$HOME/.local/share/multicolor-relay"
case "$staging_dir" in "$relay_dir"/incoming-deck-plaza-*) ;; *) exit 2 ;; esac
backup_dir="$relay_dir/backups/deck-plaza-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
cp "$relay_dir/project.godot" "$staging_dir/project.godot"
python3 -m py_compile "$staging_dir/account_store.py" "$staging_dir/deck_plaza_store.py"
"$HOME/.local/bin/godot" --headless --path "$staging_dir" --script server.gd --check-only
for file in server.gd account_store.py; do cp "$relay_dir/$file" "$backup_dir/$file"; done
if [ -f "$relay_dir/deck_plaza_store.py" ]; then cp "$relay_dir/deck_plaza_store.py" "$backup_dir/"; fi
if [ -f "$relay_dir/deck_plaza_catalogue.json" ]; then cp "$relay_dir/deck_plaza_catalogue.json" "$backup_dir/"; fi
python3 - "$relay_dir/data/players.sqlite3" "$backup_dir/players.sqlite3" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as source, sqlite3.connect(sys.argv[2]) as target:
    source.backup(target)
PY
rollback() {
    echo 'Restoring the previous account and relay programs.' >&2
    cp "$backup_dir/server.gd" "$relay_dir/server.gd"
    cp "$backup_dir/account_store.py" "$relay_dir/account_store.py"
    if [ -f "$backup_dir/deck_plaza_store.py" ]; then cp "$backup_dir/deck_plaza_store.py" "$relay_dir/"; fi
    if [ -f "$backup_dir/deck_plaza_catalogue.json" ]; then cp "$backup_dir/deck_plaza_catalogue.json" "$relay_dir/"; fi
    systemctl --user restart multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service || true
}
trap rollback ERR
for file in server.gd account_store.py deck_plaza_store.py deck_plaza_catalogue.json; do
    install -m 600 "$staging_dir/$file" "$relay_dir/$file.next"
    mv "$relay_dir/$file.next" "$relay_dir/$file"
done
systemctl --user restart multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service
sleep 2
systemctl --user is-active multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service multicolor-update-gateway-user.service
trap - ERR
echo "Deck plaza deployed; backup: $backup_dir"
