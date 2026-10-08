#!/usr/bin/env bash
set -euo pipefail
staging_dir="${1:?staging directory required}"
relay_dir="$HOME/.local/share/multicolor-relay"
case "$staging_dir" in "$relay_dir"/incoming-deck-plaza-*) ;; *) exit 2 ;; esac
backup_dir="$relay_dir/backups/deck-plaza-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
cp "$relay_dir/project.godot" "$staging_dir/project.godot"
if [ ! -f "$staging_dir/server.gd" ]; then cp "$relay_dir/server.gd" "$staging_dir/server.gd"; fi
if [ ! -f "$staging_dir/match_queue.gd" ] && [ -f "$relay_dir/match_queue.gd" ]; then cp "$relay_dir/match_queue.gd" "$staging_dir/"; fi
python3 -m py_compile "$staging_dir/account_store.py" "$staging_dir/deck_plaza_store.py"
"$HOME/.local/bin/godot" --headless --path "$staging_dir" --script server.gd --check-only
restart_services=(multicolor-account-user.service)
if ! cmp -s "$staging_dir/server.gd" "$relay_dir/server.gd" || { [ -f "$staging_dir/match_queue.gd" ] && ! cmp -s "$staging_dir/match_queue.gd" "$relay_dir/match_queue.gd"; }; then
    restart_services+=(multicolor-relay-user.service multicolor-relay-ws-user.service)
fi
for file in server.gd account_store.py; do cp "$relay_dir/$file" "$backup_dir/$file"; done
if [ -f "$relay_dir/match_queue.gd" ]; then cp "$relay_dir/match_queue.gd" "$backup_dir/"; fi
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
    if [ -f "$backup_dir/match_queue.gd" ]; then cp "$backup_dir/match_queue.gd" "$relay_dir/"; fi
    if [ -f "$backup_dir/deck_plaza_store.py" ]; then cp "$backup_dir/deck_plaza_store.py" "$relay_dir/"; fi
    if [ -f "$backup_dir/deck_plaza_catalogue.json" ]; then cp "$backup_dir/deck_plaza_catalogue.json" "$relay_dir/"; fi
    systemctl --user restart "${restart_services[@]}" || true
}
trap rollback ERR
for file in server.gd account_store.py deck_plaza_store.py deck_plaza_catalogue.json; do
    install -m 600 "$staging_dir/$file" "$relay_dir/$file.next"
    mv "$relay_dir/$file.next" "$relay_dir/$file"
done
if [ -f "$staging_dir/match_queue.gd" ]; then install -m 600 "$staging_dir/match_queue.gd" "$relay_dir/match_queue.gd"; fi
systemctl --user restart "${restart_services[@]}"
sleep 2
systemctl --user is-active multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service multicolor-update-gateway-user.service
python3 - "$relay_dir/data/players.sqlite3" "$backup_dir/players.sqlite3" <<'PY'
import sqlite3
import sys
with sqlite3.connect(sys.argv[1]) as current, sqlite3.connect(sys.argv[2]) as backup:
    count, minimum, maximum = current.execute("SELECT COUNT(*),MIN(elo),MAX(elo) FROM players").fetchone()
    assert current.execute("SELECT COUNT(*) FROM players WHERE elo IS NULL").fetchone()[0] == 0
    current.execute("SELECT COUNT(*) FROM player_follows").fetchone()
    previous_ids = {row[0] for row in backup.execute("SELECT id FROM players")}
    assert previous_ids <= {row[0] for row in current.execute("SELECT id FROM players")}
    print(f"Account migration verified: {count} players; Elo range {minimum}..{maximum}.")
PY
trap - ERR
echo "Deck plaza deployed; backup: $backup_dir"
