#!/usr/bin/env bash
set -euo pipefail
staging_dir="${1:?staging directory required}"
install_mode="${2:-full}"
case "$install_mode" in full|store-only|account-only) ;; *) exit 2 ;; esac
relay_dir="$HOME/.local/share/multicolor-relay"
case "$staging_dir" in "$relay_dir"/incoming-tournaments-*) ;; *) exit 2 ;; esac
backup_dir="$relay_dir/backups/tournaments-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
programs=(server.gd account_store.py task_store.py shop_store.py tournament_store.py tournament_pairing.py tournament_rules.py tournament_limitless.py tournament_limitless_web.py community_store.py)
services=(multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service)
if [ "$install_mode" = account-only ]; then
    # The existing relay forwards the value field as nickname; the new account
    # handler accepts that envelope without restarting any active game relay.
    if ! grep -Fq '"nickname":input.get("v","")' "$relay_dir/server.gd" || ! grep -q 'TOURNAMENT_PREFIX' "$relay_dir/server.gd"; then
        echo 'The installed relay does not support the required account/tournament envelope.' >&2
        exit 1
    fi
    programs=(account_store.py task_store.py shop_store.py tournament_store.py tournament_pairing.py tournament_rules.py tournament_limitless.py tournament_limitless_web.py community_store.py)
    services=(multicolor-account-user.service)
    cp "$relay_dir/server.gd" "$staging_dir/server.gd"
    # Use live content for migration checks, without publishing local content.
    cp "$relay_dir/data/announcements.json" "$staging_dir/data/announcements.json"
    cp "$relay_dir/data/shop.json" "$staging_dir/data/shop.json"
    cp -R "$relay_dir/data/tutorial/." "$staging_dir/data/tutorial/"
fi
if [ "$install_mode" = store-only ]; then
    if ! grep -q 'limitless_id' "$relay_dir/account_store.py" || ! grep -q 'payload.limitless_id' "$relay_dir/server.gd"; then
        echo 'Limitless account IDs and admission review require a full deployment first.' >&2
        exit 1
    fi
    if ! grep -q 'import community_store' "$relay_dir/account_store.py" || ! grep -q 'COMMUNITY_PREFIX' "$relay_dir/server.gd"; then
        echo 'The community/competition upgrade requires a full deployment first.' >&2
        exit 1
    fi
    programs=(tournament_store.py tournament_pairing.py tournament_rules.py tournament_limitless.py tournament_limitless_web.py community_store.py)
    services=(multicolor-account-user.service)
    # Validate against the actual deployed account and relay programs.
    for file in server.gd account_store.py; do
        cp "$relay_dir/$file" "$staging_dir/$file"
    done
fi
# Use the server's existing dependencies and card catalogue for migration checks.
for file in project.godot match_queue.gd match_character_log.gd deck_plaza_store.py cloud_deck_store.py deck_plaza_catalogue.json; do
    cp "$relay_dir/$file" "$staging_dir/$file"
done
python3 -m py_compile "$staging_dir/account_store.py" "$staging_dir/task_store.py" "$staging_dir/shop_store.py" "$staging_dir/tournament_store.py" "$staging_dir/tournament_pairing.py" "$staging_dir/tournament_rules.py" "$staging_dir/tournament_limitless.py" "$staging_dir/tournament_limitless_web.py" "$staging_dir/community_store.py"
"$HOME/.local/bin/godot" --headless --path "$staging_dir" --script server.gd --check-only > "$staging_dir/parse.log" 2>&1
cat "$staging_dir/parse.log"
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$staging_dir/parse.log"; then exit 1; fi
for file in "${programs[@]}"; do
    if [ -f "$relay_dir/$file" ]; then cp "$relay_dir/$file" "$backup_dir/$file"; fi
done
if [ -f "$relay_dir/data/shop.json" ]; then cp "$relay_dir/data/shop.json" "$backup_dir/shop.json"; fi
python3 - "$relay_dir/data/players.sqlite3" "$backup_dir/players.sqlite3" "$staging_dir" "$install_mode" <<'PY'
import sqlite3
import sys
from pathlib import Path
source, snapshot, stage = map(Path, sys.argv[1:4])
with sqlite3.connect(source) as current, sqlite3.connect(snapshot) as backup:
    active = current.execute("SELECT COUNT(*) FROM rating_matches WHERE status IN ('pending','playing') AND created_at>strftime('%s','now')-300").fetchone()[0]
    if active and sys.argv[4] == 'full':
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
    if [ -f "$backup_dir/shop.json" ]; then cp "$backup_dir/shop.json" "$relay_dir/data/shop.json"; else rm -f -- "$relay_dir/data/shop.json"; fi
    systemctl --user restart "${services[@]}" || true
}
trap rollback ERR
for file in "${programs[@]}"; do
    install -m 600 "$staging_dir/$file" "$relay_dir/$file.next"
    mv "$relay_dir/$file.next" "$relay_dir/$file"
done
if [ "$install_mode" != account-only ]; then
    mkdir -p "$relay_dir/data/tutorial"
    cp -R "$staging_dir/data/tutorial/." "$relay_dir/data/tutorial/"
    cp "$staging_dir/data/announcements.json" "$relay_dir/data/announcements.json"
    if [ "$install_mode" != store-only ]; then cp "$staging_dir/data/shop.json" "$relay_dir/data/shop.json"; fi
fi
systemctl --user restart "${services[@]}"
sleep 2
systemctl --user is-active multicolor-account-user.service multicolor-relay-user.service multicolor-relay-ws-user.service multicolor-update-gateway-user.service
python3 - "$relay_dir/data/players.sqlite3" "$backup_dir/players.sqlite3" "$install_mode" <<'PY'
import json
import sqlite3
import sys
import urllib.request
with sqlite3.connect(sys.argv[1]) as current, sqlite3.connect(sys.argv[2]) as backup:
    if sys.argv[3] == 'account-only':
        # Games and registrations continue during this deployment. Their valid
        # rank/session changes must not trigger a rollback of healthy programs.
        identities = set(current.execute('SELECT id,username,created_at FROM players'))
        assert set(backup.execute('SELECT id,username,created_at FROM players')).issubset(identities)
    else:
        assert backup.execute('SELECT id,username,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id').fetchall() == current.execute('SELECT id,username,elo,rank_step,rank_stars,rank_streak FROM players ORDER BY id').fetchall()
    for table in ('tournaments','tournament_members','tournament_rounds','tournament_pairings','tournament_schedules'):
        current.execute('SELECT COUNT(*) FROM ' + table).fetchone()
request = urllib.request.Request('http://127.0.0.1:47864/tournaments', data=json.dumps({'action':'list','token':'invalid'}).encode(), headers={'Content-Type':'application/json'})
with urllib.request.urlopen(request, timeout=5) as response:
    result = json.load(response)
assert result['ok'] is False and result['auth_required'] is True
print('Existing player identities preserved; authenticated competition endpoint is live.')
PY
trap - ERR
echo "Tournaments deployed; backup: $backup_dir"
