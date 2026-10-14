#!/usr/bin/env bash
set -euo pipefail
staging_dir="${1:?staging directory required}"
install_mode="${2:-full}"
case "$install_mode" in full|store-only) ;; *) exit 2 ;; esac
relay_dir="$HOME/.local/share/multicolor-relay"
case "$staging_dir" in "$relay_dir"/incoming-tournaments-*) ;; *) exit 2 ;; esac
backup_dir="$relay_dir/backups/tournaments-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
programs=(server.gd account_store.py tournament_store.py tournament_pairing.py)
services=(multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service)
if [ "$install_mode" = store-only ]; then
    programs=(tournament_store.py)
    services=(multicolor-account-user.service)
    # Validate against the actual deployed account and relay programs.
    for file in server.gd account_store.py tournament_pairing.py; do
        cp "$relay_dir/$file" "$staging_dir/$file"
    done
fi
# Use the server's existing dependencies and card catalogue for migration checks.
for file in project.godot match_queue.gd match_character_log.gd deck_plaza_store.py deck_plaza_catalogue.json; do
    cp "$relay_dir/$file" "$staging_dir/$file"
done
python3 -m py_compile "$staging_dir/account_store.py" "$staging_dir/tournament_store.py" "$staging_dir/tournament_pairing.py"
"$HOME/.local/bin/godot" --headless --path "$staging_dir" --script server.gd --check-only > "$staging_dir/parse.log" 2>&1
cat "$staging_dir/parse.log"
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$staging_dir/parse.log"; then exit 1; fi
for file in "${programs[@]}"; do
    if [ -f "$relay_dir/$file" ]; then cp "$relay_dir/$file" "$backup_dir/$file"; fi
done
python3 - "$relay_dir/data/players.sqlite3" "$backup_dir/players.sqlite3" "$staging_dir" "$install_mode" <<'PY'
import sqlite3
import sys
from pathlib import Path
source, snapshot, stage = map(Path, sys.argv[1:4])
with sqlite3.connect(source) as current, sqlite3.connect(snapshot) as backup:
    active = current.execute("SELECT COUNT(*) FROM rating_matches WHERE status IN ('pending','playing') AND created_at>strftime('%s','now')-300").fetchone()[0]
    if active and sys.argv[4] != 'store-only':
        raise RuntimeError('Recent unfinished games exist; finish them before restarting the relay')
    current.backup(backup)
with sqlite3.connect(snapshot) as backup, sqlite3.connect(stage / 'migration-check.sqlite3') as test:
    backup.backup(test)
sys.path.insert(0, str(stage))
import account_store
import tournament_store
conn = account_store.database(stage / 'migration-check.sqlite3')
assert conn.execute("SELECT COUNT(*) FROM players WHERE username='bigcake' COLLATE NOCASE").fetchone()[0] == 1
for table in ('tournaments','tournament_members','tournament_rounds','tournament_pairings','tournament_schedules'):
    conn.execute('SELECT COUNT(*) FROM ' + table).fetchone()
with sqlite3.connect(snapshot) as original:
    for table in ('players','tournaments','tournament_members','tournament_rounds','tournament_pairings','tournament_schedules'):
        old_columns = [row[1] for row in original.execute('PRAGMA table_info(' + table + ')')]
        if not old_columns:
            continue
        columns = ','.join(old_columns)
        assert original.execute('SELECT ' + columns + ' FROM ' + table + ' ORDER BY rowid').fetchall() == conn.execute('SELECT ' + columns + ' FROM ' + table + ' ORDER BY rowid').fetchall(), table
    assert conn.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
# Exercise deletion of existing competitions exclusively on the disposable DB copy.
owner_id = conn.execute("SELECT id FROM players WHERE username='bigcake' COLLATE NOCASE").fetchone()[0]
owner = {'ok': True, 'username': 'bigcake', 'player_id': owner_id}
ids = [row[0] for row in conn.execute("SELECT id FROM tournaments WHERE owner_id=? AND phase!='deleted'", (owner_id,))]
for tournament_id in ids:
    answer = tournament_store.handle(conn, {'action':'delete','id':tournament_id}, owner)
    assert answer['ok'], answer
    assert not tournament_store.handle(conn, {'action':'detail','id':tournament_id}, owner)['ok']
    for table in ('tournament_members','tournament_rounds','tournament_pairings','tournament_schedules'):
        assert conn.execute('SELECT COUNT(*) FROM '+table+' WHERE tournament_id=?', (tournament_id,)).fetchone()[0] == 0
conn.close()
print('Competition migration preserves existing data; deletion verified on an isolated database copy:', len(ids))
PY
rollback() {
    echo 'Restoring the previous competition/account/relay programs.' >&2
    for file in "${programs[@]}"; do
        if [ -f "$backup_dir/$file" ]; then cp "$backup_dir/$file" "$relay_dir/$file"; else rm -f -- "$relay_dir/$file"; fi
    done
    systemctl --user restart "${services[@]}" || true
}
trap rollback ERR
for file in "${programs[@]}"; do
    install -m 600 "$staging_dir/$file" "$relay_dir/$file.next"
    mv "$relay_dir/$file.next" "$relay_dir/$file"
done
systemctl --user restart "${services[@]}"
sleep 2
systemctl --user is-active multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service multicolor-update-gateway-user.service
python3 - "$relay_dir/data/players.sqlite3" "$backup_dir/players.sqlite3" <<'PY'
import json
import sqlite3
import sys
import urllib.request
with sqlite3.connect(sys.argv[1]) as current, sqlite3.connect(sys.argv[2]) as backup:
    assert backup.execute('SELECT id,username,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id').fetchall() == current.execute('SELECT id,username,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id').fetchall()
    for table in ('tournaments','tournament_members','tournament_rounds','tournament_pairings','tournament_schedules'):
        current.execute('SELECT COUNT(*) FROM ' + table).fetchone()
request = urllib.request.Request('http://127.0.0.1:47864/tournaments', data=json.dumps({'action':'list','token':'invalid'}).encode(), headers={'Content-Type':'application/json'})
with urllib.request.urlopen(request, timeout=5) as response:
    result = json.load(response)
assert result['ok'] is False and result['auth_required'] is True
print('Player ranks preserved; authenticated competition endpoint is live.')
PY
trap - ERR
echo "Tournaments deployed; backup: $backup_dir"
