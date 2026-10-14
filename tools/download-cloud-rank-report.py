"""Download a read-only top-20 ranking snapshot with ranked win rates."""
import argparse
import ast
import csv
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


REMOTE_QUERY = r'''
import ast
from datetime import datetime, timezone, timedelta
import json
from pathlib import Path
import sqlite3

root = Path.home() / '.local/share/multicolor-relay'
source = (root / 'account_store.py').read_text(encoding='utf-8')
rules = {node.name: ast.get_source_segment(source, node)
         for node in ast.parse(source).body if isinstance(node, ast.FunctionDef)
         and node.name in ('player_rank', 'advance_rank')}
database = root / 'data/players.sqlite3'
conn = sqlite3.connect(database.as_uri() + '?mode=ro', uri=True, timeout=15)
conn.execute('PRAGMA query_only=ON')
conn.execute('BEGIN')
columns = {row[1] for row in conn.execute('PRAGMA table_info(players)')}
required = {'id', 'username', 'nickname', 'rank_step', 'rank_stars', 'elo'}
if not required.issubset(columns):
    raise RuntimeError('Server database is missing ranking columns')
total = conn.execute('SELECT COUNT(*) FROM players').fetchone()[0]
sages = conn.execute('SELECT COUNT(*) FROM players WHERE rank_step >= 11').fetchone()[0]
rows = conn.execute("""
    SELECT id, username, COALESCE(NULLIF(nickname, ''), username),
           rank_step, rank_stars, elo
    FROM players
    ORDER BY rank_step DESC,
             CASE WHEN rank_step < 11 THEN rank_stars ELSE 0 END DESC,
             elo DESC, id ASC
    LIMIT 20
""").fetchall()
match_columns = {row[1] for row in conn.execute('PRAGMA table_info(rating_matches)')}
if not {'player_a', 'player_b', 'status', 'winner', 'rank_a', 'rank_b'}.issubset(match_columns):
    raise RuntimeError('Server database has no ranked settlement records')
# Rank snapshots distinguish actual rank settlements from older Elo-only games.
mode_filter = "AND mode = 'ranked'" if 'mode' in match_columns else ''
statistics = conn.execute("""
    WITH eligible AS (
        SELECT player_a, player_b, winner FROM rating_matches
        WHERE status = 'settled' AND winner IN (0, 1)
          AND rank_a IS NOT NULL AND rank_b IS NOT NULL
          AND rank_a != '' AND rank_b != '' AND player_a != player_b
          """ + mode_filter + """
    ), participations AS (
        SELECT player_a AS player_id, winner = 0 AS won FROM eligible
        UNION ALL
        SELECT player_b AS player_id, winner = 1 AS won FROM eligible
    )
    SELECT player_id, COUNT(*), SUM(won), SUM(1 - won)
    FROM participations GROUP BY player_id
""").fetchall()
statistics = {player_id: (matches, wins, losses) for player_id, matches, wins, losses in statistics}
players = []
for position, row in enumerate(rows, 1):
    player = dict(zip(('player_id', 'username', 'nickname', 'rank_step', 'rank_stars', 'elo'), row),
                  position=position)
    matches, wins, losses = statistics.get(player['player_id'], (0, 0, 0))
    player.update(ranked_matches=matches, wins=wins, losses=losses,
                  win_rate=wins / matches if matches else None)
    players.append(player)
result = {
    'database': str(database),
    'snapshot_time_china': datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds'),
    'total_players': total,
    'sage_players': sages,
    'ordering': 'rank_step DESC; rank_stars DESC below sage; elo DESC; id ASC',
    'server_rank_rules': rules,
    'win_rate_scope': 'all_recorded_ranked_settlements',
    'total_ranked_matches': sum(stats[0] for stats in statistics.values()) // 2,
    'players': players,
}
conn.rollback()
conn.close()
print(json.dumps(result, ensure_ascii=True))
'''


def download(args, remote_query=None, timeout=45):
    secret = os.environ.get('MULTICOLOR_REPORT_KEY_PASSPHRASE', '')
    if not secret:
        raise RuntimeError('SSH passphrase is missing')
    with tempfile.NamedTemporaryFile(prefix='multicolor-report-askpass-', suffix='.exe', delete=False) as handle:
        helper = Path(handle.name)
    try:
        # OpenSSH on Windows cannot launch askpass from a Unicode project path.
        shutil.copyfile(args.askpass_exe, helper)
        env = os.environ.copy()
        env.update(SSH_ASKPASS=str(helper), SSH_ASKPASS_REQUIRE='force', DISPLAY='codex')
        command = [args.ssh_exe, '-i', args.key_path, '-p', str(args.ssh_port),
                   '-o', 'IdentitiesOnly=yes', '-o', 'StrictHostKeyChecking=yes',
                   '-o', 'ConnectTimeout=10', '-o', 'ConnectionAttempts=1',
                   '-o', 'ServerAliveInterval=10', '-o', 'ServerAliveCountMax=2',
                   '-o', 'IPQoS=none', f'{args.user}@{args.server}', 'python3 -']
        completed = subprocess.run(command, input=remote_query or REMOTE_QUERY, capture_output=True,
                                   encoding='utf-8', env=env, timeout=timeout)
    finally:
        helper.unlink(missing_ok=True)
    if completed.returncode:
        raise RuntimeError(completed.stderr.strip() or 'SSH query failed')
    snapshot = json.loads(completed.stdout)
    snapshot['server'] = args.server
    return snapshot


def sort_key(player):
    return (-player['rank_step'], -player['rank_stars'] if player['rank_step'] < 11 else 0,
            -player['elo'], player['player_id'])


def caption(player):
    step = player['rank_step']
    tier = 4 if step >= 11 else 3 if step >= 8 else 2 if step >= 5 else 1 if step >= 2 else 0
    if tier == 4:
        return '妖怪贤者'
    return f"{('毛玉级', '妖精级', '天狗级', '妖怪级')[tier]} {(2, 5, 8, 11)[tier] - step} · {player['rank_stars']} 星"


def validate(snapshot):
    from datetime import datetime
    datetime.fromisoformat(snapshot['snapshot_time_china'])
    players = snapshot['players']
    if len(players) != min(20, snapshot['total_players']):
        raise ValueError('Unexpected report row count')
    if len({player['player_id'] for player in players}) != len(players):
        raise ValueError('Duplicate players in ranking snapshot')
    if players != sorted(players, key=sort_key):
        raise ValueError('Ranking snapshot is out of order')
    for position, player in enumerate(players, 1):
        if player['position'] != position or not 0 <= player['rank_step'] <= 11 or not 0 <= player['rank_stars'] <= 3:
            raise ValueError('Unsupported server ranking format')
        fields = ('ranked_matches', 'wins', 'losses', 'win_rate')
        if not any(field in player for field in fields):
            continue  # Older saved snapshots do not contain win-rate data.
        if not all(field in player for field in fields):
            raise ValueError('Incomplete ranked win-rate statistics')
        matches, wins, losses = (player[field] for field in fields[:3])
        if any(type(value) is not int or value < 0 for value in (matches, wins, losses)) or matches != wins + losses:
            raise ValueError('Invalid ranked match counts')
        rate = player['win_rate']
        if matches == 0:
            if rate is not None:
                raise ValueError('A player with no ranked matches must have no win rate')
        elif type(rate) not in (int, float) or rate != wins / matches:
            raise ValueError('Ranked win rate does not match the win and loss counts')


def statistic_cells(player):
    if 'ranked_matches' not in player:
        return ('未采集',) * 4
    rate = f"{player['win_rate']:.2%}" if player['ranked_matches'] else '暂无对局'
    return player['ranked_matches'], player['wins'], player['losses'], rate


def write_atomic(path, contents, encoding):
    staging = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        with staging.open('w', encoding=encoding, newline='') as stream:
            stream.write(contents)
        staging.replace(path)
    finally:
        staging.unlink(missing_ok=True)


def csv_text(header, rows):
    def cell(value):
        # Account names and card names are text, including in Excel's CSV importer.
        if isinstance(value, str) and (value.lstrip()[:1] in ('=', '+', '-', '@')
                                      or value[:1] in ('\t', '\r', '\n')):
            return "'" + value
        return value

    stream = io.StringIO(newline='')
    writer = csv.writer(stream)
    writer.writerow(header)
    writer.writerows([cell(value) for value in row] for row in rows)
    return stream.getvalue()


def export(snapshot, output_dir):
    validate(snapshot)
    timestamp = snapshot['snapshot_time_china']
    players = snapshot['players']
    lines = [
        'Multicolor Arena 段位前 20 名名单',
        f"数据时间：{timestamp.replace('T', ' ').replace('+08:00', '')}（北京时间）",
        f"来源：服务器 {snapshot['server']}，账号数据库只读快照",
        f"账号总数：{snapshot['total_players']}；妖怪贤者人数：{snapshot['sage_players']}",
        '排序：段位从高到低，再按星数从多到少；同段同星按 Elo 降序、账号 ID 升序。',
        '说明：服务器只为妖怪贤者定义正式名次，其余段位的同段同星顺序采用上述导出规则。',
        '胜率 = 胜场 / 段位对局数；统计数据库保留的全部已结算段位对局（双方有段位结算记录）。',
        '取消、未结算、休闲、娱乐、旧版仅 Elo 结算及无效结果不计入；投降、断线判负按服务器最终结果计入。',
        '无段位对局显示“暂无对局”；旧快照未保存统计时显示“未采集”。',
        '', '序号\t昵称\t段位\tElo\t段位对局数\t胜场\t负场\t胜率\t账号 ID\t账号名',
    ]
    clean = lambda value: str(value).replace('\t', ' ').replace('\r', ' ').replace('\n', ' ')
    for player in players:
        lines.append('\t'.join(map(clean, (player['position'], player['nickname'], caption(player),
                                           player['elo'], *statistic_cells(player),
                                           player['player_id'], player['username']))))
    report = '\n'.join(lines) + '\n'
    data = json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n'
    table = csv_text(
        ('序号', '昵称', '段位', '段位序号', '星数', 'Elo', '段位对局数', '胜场', '负场', '胜率',
         '账号 ID', '账号名', '数据时间（北京时间）'),
        ((player['position'], player['nickname'], caption(player), player['rank_step'],
          player['rank_stars'], player['elo'], *statistic_cells(player),
          player['player_id'], player['username'], timestamp)
         for player in players),
    )
    folder = Path(output_dir).resolve()
    folder.mkdir(parents=True, exist_ok=True)
    stem = '段位前20名_' + timestamp[:19].replace('-', '').replace(':', '').replace('T', '_')
    archive = folder / (stem + '.csv')
    latest = folder / '段位前20名_最新.csv'
    for path, contents, encoding in (
        (archive, table, 'utf-8-sig'), (latest, table, 'utf-8-sig'),
        (folder / (stem + '.txt'), report, 'utf-8-sig'),
        (folder / '段位前20名_最新.txt', report, 'utf-8-sig'),
        (folder / (stem + '.json'), data, 'utf-8'),
        (folder / '段位前20名_最新.json', data, 'utf-8'),
    ):
        write_atomic(path, contents, encoding)
    return {'report': str(archive), 'latest': str(latest), 'rows': len(players),
            'snapshot_time_china': timestamp}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='D:\\云端报告')
    parser.add_argument('--snapshot-file', help='Format a previously downloaded snapshot without SSH')
    parser.add_argument('--server', default='8.137.122.187')
    parser.add_argument('--user', default='codex')
    parser.add_argument('--ssh-port', type=int, default=22)
    parser.add_argument('--key-path', default=str(Path.home() / '.ssh/id_ed25519_multicolor_ecs'))
    parser.add_argument('--ssh-exe', default=r'C:\Windows\System32\OpenSSH\ssh.exe')
    parser.add_argument('--askpass-exe')
    args = parser.parse_args()
    if args.snapshot_file:
        snapshot = json.loads(Path(args.snapshot_file).read_text(encoding='utf-8-sig'))
    else:
        if not args.askpass_exe:
            parser.error('--askpass-exe is required for an SSH download')
        snapshot = download(args)
    print(json.dumps(export(snapshot, args.output_dir), ensure_ascii=True))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit('Report failed: ' + str(error))
