"""Report character usage and win rates for matches with ranked settlement data."""
import argparse
from collections import Counter
from datetime import datetime, timezone, timedelta
import importlib.util
import json
from pathlib import Path
import subprocess

spec = importlib.util.spec_from_file_location('rank_report', Path(__file__).with_name('download-cloud-rank-report.py'))
rank_report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rank_report)
START_VERSION = '1.2.8'
# The release deployment's relay journal confirms both listeners were up at this time.
DEFAULT_SINCE = '2026-10-11T01:06:14+08:00'
CHINA_TZ = timezone(timedelta(hours=8))

REMOTE_QUERY = r'''
from datetime import datetime, timezone, timedelta
import json
from pathlib import Path
import sqlite3

root = Path.home() / '.local/share/multicolor-relay'
db = root / 'data/players.sqlite3'
conn = sqlite3.connect(db.as_uri() + '?mode=ro', uri=True, timeout=15)
conn.execute('PRAGMA query_only=ON')
conn.execute('BEGIN')
columns = {row[1] for row in conn.execute('PRAGMA table_info(rating_matches)')}
if not {'match_id','created_at','status','winner','rank_a','rank_b'}.issubset(columns):
    raise RuntimeError('Server database has no ranked settlement records')
rows = conn.execute('SELECT match_id,created_at,status,winner,rank_a,rank_b FROM rating_matches ORDER BY created_at,match_id').fetchall()
snapshot_time = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds')
conn.rollback()
conn.close()
catalogue = json.loads((root / 'deck_plaza_catalogue.json').read_text(encoding='utf-8'))['cards']
cards = {key:{field:value.get(field) for field in ('canonical','name','leader')} for key,value in catalogue.items()}
leader_logs = sorted((root / 'data').glob('match_leaders*.jsonl'))
records = []
invalid_lines = 0
for leader_log in leader_logs:
    with leader_log.open(encoding='utf-8') as stream:
        for line in stream:
            try:
                if len(line) > 16384:
                    raise ValueError('Oversized metadata line')
                record = json.loads(line)
                if not isinstance(record, dict):
                    raise ValueError('Invalid metadata record')
                records.append({key:record.get(key) for key in ('match_id','leaders','recorded_at')})
            except (ValueError, TypeError):
                invalid_lines += 1
print(json.dumps({
    'database':str(db), 'snapshot_time_china':snapshot_time,
    'matches':[dict(zip(('match_id','created_at','status','winner','rank_a','rank_b'), row)) for row in rows],
    'cards':cards, 'leader_records':records, 'leader_log_exists':bool(leader_logs),
    'invalid_log_lines':invalid_lines,
    'recorder_installed':'match_character_log.gd' in (root / 'server.gd').read_text(encoding='utf-8'),
}, ensure_ascii=True))
'''


def ranked_result(value):
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except ValueError:
            return False
    return isinstance(value, dict) and type(value.get('tier')) is int and value['tier'] in range(5)


def canonical_leader(card_id, cards):
    if not isinstance(card_id, str):
        return None
    card = cards.get(card_id)
    if not card or card.get('leader') is not True:
        return None
    canonical = str(card.get('canonical') or card_id)
    if not cards.get(canonical, {}).get('leader'):
        return None
    return canonical


def calculate(snapshot, since=DEFAULT_SINCE):
    cutoff = datetime.fromisoformat(since)
    if cutoff.tzinfo is None:
        raise ValueError('Statistics start time must include a timezone')
    cutoff = max(cutoff, datetime.fromisoformat(DEFAULT_SINCE)).astimezone(CHINA_TZ)
    since = cutoff.isoformat()
    cards = snapshot['cards']
    metadata = {}
    conflicts = set()
    invalid_records = 0
    for record in snapshot['leader_records']:
        match_id = record.get('match_id')
        leaders = record.get('leaders')
        if not isinstance(match_id, str) or not isinstance(leaders, list) or len(leaders) != 2:
            invalid_records += 1
            continue
        pair = tuple(canonical_leader(card_id, cards) for card_id in leaders)
        if None in pair:
            invalid_records += 1
            continue
        if match_id in metadata and metadata[match_id] != pair:
            conflicts.add(match_id)
        else:
            metadata[match_id] = pair
    excluded = Counter()
    coverage_missing = Counter()
    statuses = Counter()
    eligible = []
    covered = []
    seen = set()
    counts = {}
    for match in snapshot['matches']:
        match_id = match['match_id']
        if match_id in seen:
            raise ValueError('Duplicate database match ID')
        seen.add(match_id)
        if match['created_at'] < cutoff.timestamp():
            excluded['before_character_recording'] += 1
            continue
        statuses[match['status']] += 1
        if match['status'] != 'settled':
            excluded[match['status']] += 1
            continue
        if not ranked_result(match['rank_a']) or not ranked_result(match['rank_b']):
            excluded['no_ranked_settlement'] += 1
            continue
        if type(match['winner']) is not int or match['winner'] not in (0, 1):
            excluded['invalid_winner'] += 1
            continue
        eligible.append(match)
        if match_id in conflicts:
            coverage_missing['conflicting_leaders'] += 1
            continue
        if match_id not in metadata:
            coverage_missing['missing_or_invalid_leaders'] += 1
            continue
        covered.append(match)
        for actor, leader_id in enumerate(metadata[match_id]):
            counter = counts.setdefault(leader_id, {'leader_id':leader_id,
                'name':cards[leader_id]['name'], 'uses':0, 'wins':0, 'losses':0})
            counter['uses'] += 1
            counter['wins' if match['winner'] == actor else 'losses'] += 1
    participations = len(covered) * 2
    for counter in counts.values():
        counter['usage_rate'] = counter['uses'] / participations
        counter['win_rate'] = counter['wins'] / counter['uses']
    rows = sorted(counts.values(), key=lambda row: (-row['uses'], -row['wins'], row['leader_id']))
    if sum(row['uses'] for row in rows) != participations or sum(row['wins'] for row in rows) != len(covered):
        raise ValueError('Statistics totals are inconsistent')
    return {
        'server':snapshot['server'], 'snapshot_time_china':snapshot['snapshot_time_china'],
        'start_version':START_VERSION, 'since_china':since,
        'scope':'Only settled ranked matches created since character recording was deployed; earlier matches do not affect coverage',
        'eligible_matches':len(eligible), 'covered_matches':len(covered),
        'missing_leader_matches':len(eligible)-len(covered), 'participations':participations,
        'coverage_rate':len(covered)/len(eligible) if eligible else None,
        'first_ranked_match_china':datetime.fromtimestamp(min(match['created_at'] for match in eligible), CHINA_TZ).isoformat() if eligible else None,
        'leader_log_exists':snapshot['leader_log_exists'], 'recorder_installed':snapshot['recorder_installed'],
        'invalid_log_lines':snapshot['invalid_log_lines'], 'invalid_leader_records':invalid_records,
        'excluded':dict(excluded), 'statuses_since_character_recording':dict(statuses),
        'coverage_missing_reasons':dict(coverage_missing),
        'status':'complete' if eligible and len(covered)==len(eligible) else 'partial' if covered else 'insufficient_data',
        'rows':rows,
    }


def percent(value):
    return '无法统计' if value is None else f'{value:.2%}'


def export(report, output_dir):
    usage_label = '使用率' if report['status'] == 'complete' else '样本内使用率'
    lines = [
        'Multicolor Arena 段位匹配自机使用率与胜率',
        f"数据时间：{report['snapshot_time_china']}（北京时间）",
        f"统计起始版本：{report['start_version']}（实装对局自机采集）；统计起始时间：{report['since_china']}",
        '自机采集上线前的对局全部忽略，不计入样本、缺失数或覆盖率分母。',
        '范围：双方均有段位结算记录的已结算匹配；排除 Elo 时期、取消、未结算和无效结果。',
        f"符合范围的对局：{report['eligible_matches']} 场；双方自机可确认：{report['covered_matches']} 场。",
        f"缺失双方自机：{report['missing_leader_matches']} 场；数据覆盖率：{percent(report['coverage_rate'])}。",
        '使用率 = 自机出场次数 / 可确认双方自机的对局参赛次数（每场 2 次）；胜率 = 获胜次数 / 出场次数。',
        '镜像对局双方各计一次使用，一胜一负；异画合并至同一规范自机 ID。掉线判负按服务器最终结算结果计入。',
    ]
    if report['status'] == 'insufficient_data':
        lines += ['', '当前无法计算各自机使用率和胜率：没有可确认双方自机的有效样本。',
                  '服务器历史胜负记录不包含自机，不能从段位、Elo 或广场套牌推断当场所用自机。']
    elif report['status'] == 'partial':
        lines += ['', '当前仅统计采集上线后有双方自机记录的样本，以下百分比不能代表统计范围内缺失自机的对局。']
    if not report['recorder_installed']:
        lines += ['自机采集补丁尚未在服务器启用；已有历史缺失不会因启用而自动补齐。']
    lines += ['', f'自机 ID\t自机\t使用次数\t{usage_label}\t胜场\t负场\t胜率']
    for row in report['rows']:
        name = row['name'].replace('\t',' ').replace('\n',' ').replace('\r',' ')
        lines.append('\t'.join(map(str, (row['leader_id'], name, row['uses'], percent(row['usage_rate']),
                                        row['wins'], row['losses'], percent(row['win_rate'])))))
    if not report['rows']:
        lines.append('无可统计自机；缺失数据不记作 0% 胜率。')
    lines += ['', '排除记录数量：' + json.dumps(report['excluded'], ensure_ascii=False),
              f"自机日志损坏行数：{report['invalid_log_lines']}；无效自机记录数：{report['invalid_leader_records']}。"]
    text = '\n'.join(lines) + '\n'
    data = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    table = rank_report.csv_text(
        ('自机 ID', '自机', '使用次数', usage_label, '胜场', '负场', '胜率',
         '统计起始版本', '统计起始时间（北京时间）', '数据时间（北京时间）'),
        ((row['leader_id'], row['name'], row['uses'], percent(row['usage_rate']),
          row['wins'], row['losses'], percent(row['win_rate']), report['start_version'],
          report['since_china'], report['snapshot_time_china']) for row in report['rows']),
    )
    folder = Path(output_dir).resolve()
    folder.mkdir(parents=True, exist_ok=True)
    stem = '段位匹配自机统计_' + report['snapshot_time_china'][:19].replace('-','').replace(':','').replace('T','_')
    latest = folder / '段位匹配自机统计_最新.csv'
    archive = folder / (stem + '.csv')
    for path, contents, encoding in (
        (archive, table, 'utf-8-sig'), (latest, table, 'utf-8-sig'),
        (folder / (stem + '.txt'), text, 'utf-8-sig'),
        (folder / '段位匹配自机统计_最新.txt', text, 'utf-8-sig'),
        (folder / (stem + '.json'), data, 'utf-8'),
        (folder / '段位匹配自机统计_最新.json', data, 'utf-8'),
    ):
        rank_report.write_atomic(path, contents, encoding)
    return {'report':str(archive), 'latest':str(latest), 'rows':len(report['rows']),
            'snapshot_time_china':report['snapshot_time_china'], 'status':report['status'],
            'eligible_matches':report['eligible_matches'], 'covered_matches':report['covered_matches']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='D:\\云端报告')
    parser.add_argument('--since', default=DEFAULT_SINCE,
                        help='Timezone-aware start time; dates before character recording deployment are ignored')
    parser.add_argument('--snapshot-file')
    parser.add_argument('--save-snapshot')
    parser.add_argument('--server', default='8.137.122.187')
    parser.add_argument('--user', default='codex')
    parser.add_argument('--ssh-port', type=int, default=22)
    parser.add_argument('--key-path', default=str(Path.home()/'.ssh/id_ed25519_multicolor_ecs'))
    parser.add_argument('--ssh-exe', default=r'C:\Windows\System32\OpenSSH\ssh.exe')
    parser.add_argument('--askpass-exe')
    args = parser.parse_args()
    if args.snapshot_file:
        snapshot = json.loads(Path(args.snapshot_file).read_text(encoding='utf-8-sig'))
    else:
        snapshot = rank_report.download(args, REMOTE_QUERY)
    if args.save_snapshot:
        rank_report.write_atomic(Path(args.save_snapshot), json.dumps(snapshot,ensure_ascii=False,indent=2)+'\n','utf-8')
    report = calculate(snapshot, args.since)
    print(json.dumps(export(report, args.output_dir), ensure_ascii=True))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit('Report failed: ' + str(error))
