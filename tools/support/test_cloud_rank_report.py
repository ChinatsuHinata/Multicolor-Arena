"""Exercise the remote SQLite query and ranked win-rate report exports."""
from contextlib import redirect_stdout
import csv
import importlib.util
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    'rank_report', Path(__file__).resolve().parents[1] / 'download-cloud-rank-report.py')
reporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reporter)


def query_fixture(with_mode=True):
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder) / '.local/share/multicolor-relay'
        database = root / 'data/players.sqlite3'
        database.parent.mkdir(parents=True)
        (root / 'account_store.py').write_text(
            'def player_rank(conn, player):\n    return {}\n'
            'def advance_rank(step, stars, streak, won):\n    return step, stars, streak\n',
            encoding='utf-8')
        conn = sqlite3.connect(database)
        conn.execute('''CREATE TABLE players (
            id INTEGER PRIMARY KEY, username TEXT, nickname TEXT,
            rank_step INTEGER, rank_stars INTEGER, elo INTEGER)''')
        conn.executemany('INSERT INTO players VALUES (?, ?, ?, ?, ?, ?)',
                         [(i, f'user_{i}', f'玩家 {i}', 10, 2, 2000 - i) for i in range(1, 24)])
        mode_column = ', mode TEXT' if with_mode else ''
        conn.execute('''CREATE TABLE rating_matches (
            match_id TEXT PRIMARY KEY, player_a INTEGER, player_b INTEGER,
            status TEXT, winner INTEGER, rank_a TEXT, rank_b TEXT''' + mode_column + ')')
        ranked = '{"tier":3}'
        rows = [
            ('rank-a', 1, 2, 'settled', 0, ranked, ranked, 'ranked'),
            ('rank-b', 2, 1, 'settled', 1, ranked, ranked, 'ranked'),
            ('rank-c', 1, 2, 'settled', 1, ranked, ranked, 'ranked'),
            ('outside-top20', 2, 23, 'settled', 1, ranked, ranked, 'ranked'),
            ('cancelled', 1, 2, 'cancelled', 0, ranked, ranked, 'ranked'),
            ('playing', 1, 2, 'playing', 0, ranked, ranked, 'ranked'),
            ('pending', 1, 2, 'pending', 0, ranked, ranked, 'ranked'),
            ('invalid', 1, 2, 'settled', 2, ranked, ranked, 'ranked'),
            ('no-winner', 1, 2, 'settled', None, ranked, ranked, 'ranked'),
            ('old-elo', 1, 2, 'settled', 0, None, None, 'ranked'),
            ('missing-rank', 1, 2, 'settled', 0, ranked, None, 'ranked'),
            ('empty-rank', 1, 2, 'settled', 0, '', ranked, 'ranked'),
            ('self-match', 1, 1, 'settled', 0, ranked, ranked, 'ranked'),
            ('casual', 1, 2, 'settled', 0, None, None, 'casual'),
            ('exploration', 1, 2, 'settled', 0, None, None, 'exploration'),
        ]
        if with_mode:
            # Even stale rank fields must not admit explicitly non-ranked games.
            rows += [('casual-with-ranks', 1, 2, 'settled', 0, ranked, ranked, 'casual'),
                     ('exploration-with-ranks', 1, 2, 'settled', 0, ranked, ranked, 'exploration')]
        conn.executemany('INSERT INTO rating_matches VALUES (' + ','.join('?' * (8 if with_mode else 7)) + ')',
                         rows if with_mode else [row[:-1] for row in rows])
        conn.commit()
        conn.close()
        original = database.read_bytes()
        output = io.StringIO()
        with patch.object(Path, 'home', return_value=Path(folder)), redirect_stdout(output):
            exec(reporter.REMOTE_QUERY, {})
        if database.read_bytes() != original:
            raise AssertionError('Report query modified the source database')
        snapshot = json.loads(output.getvalue())
        snapshot['server'] = 'example.invalid'
        return snapshot


class RankReportTests(unittest.TestCase):
    def test_both_seats_scope_and_opponents_outside_top20(self):
        snapshot = query_fixture()
        reporter.validate(snapshot)
        self.assertEqual(snapshot['total_players'], 23)
        self.assertEqual(snapshot['total_ranked_matches'], 4)
        self.assertEqual(snapshot['win_rate_scope'], 'all_recorded_ranked_settlements')
        self.assertEqual([row['player_id'] for row in snapshot['players']], list(range(1, 21)))
        first, second, unused = snapshot['players'][:3]
        self.assertEqual((first['ranked_matches'], first['wins'], first['losses']), (3, 2, 1))
        self.assertAlmostEqual(first['win_rate'], 2 / 3)
        self.assertEqual((second['ranked_matches'], second['wins'], second['losses']), (4, 1, 3))
        self.assertEqual(second['win_rate'], 0.25)
        self.assertEqual((unused['ranked_matches'], unused['wins'], unused['losses']), (0, 0, 0))
        self.assertIsNone(unused['win_rate'])

    def test_older_database_without_mode_uses_rank_settlements(self):
        snapshot = query_fixture(with_mode=False)
        reporter.validate(snapshot)
        self.assertEqual(snapshot['total_ranked_matches'], 4)
        self.assertEqual(snapshot['players'][0]['ranked_matches'], 3)

    def test_csv_txt_json_exports_agree(self):
        snapshot = query_fixture()
        with tempfile.TemporaryDirectory() as folder:
            paths = reporter.export(snapshot, folder)
            archive, latest = Path(paths['report']), Path(paths['latest'])
            self.assertEqual(archive.read_bytes(), latest.read_bytes())
            self.assertTrue(latest.read_bytes().startswith(b'\xef\xbb\xbf'))
            with latest.open(encoding='utf-8-sig', newline='') as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(len(rows), 20)
            self.assertEqual((rows[0]['段位对局数'], rows[0]['胜场'], rows[0]['负场'], rows[0]['胜率']),
                             ('3', '2', '1', '66.67%'))
            self.assertEqual(rows[1]['胜率'], '25.00%')
            self.assertEqual(rows[2]['胜率'], '暂无对局')
            text = latest.with_suffix('.txt').read_text(encoding='utf-8-sig')
            self.assertIn('66.67%', text)
            self.assertIn('取消、未结算、休闲、娱乐', text)
            data = json.loads(latest.with_suffix('.json').read_text(encoding='utf-8'))
            self.assertEqual(data, snapshot)

    def test_old_snapshot_is_missing_statistics_instead_of_zero(self):
        snapshot = query_fixture()
        for player in snapshot['players']:
            for field in ('ranked_matches', 'wins', 'losses', 'win_rate'):
                del player[field]
        with tempfile.TemporaryDirectory() as folder:
            paths = reporter.export(snapshot, folder)
            with Path(paths['latest']).open(encoding='utf-8-sig', newline='') as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(rows[0]['胜率'], '未采集')
            self.assertEqual(rows[0]['段位对局数'], '未采集')

    def test_zero_percent_differs_from_no_matches(self):
        snapshot = query_fixture()
        player = snapshot['players'][0]
        player.update(ranked_matches=2, wins=0, losses=2, win_rate=0.0)
        reporter.validate(snapshot)
        self.assertEqual(reporter.statistic_cells(player), (2, 0, 2, '0.00%'))
        player.update(wins=2, losses=0, win_rate=1.0)
        reporter.validate(snapshot)
        self.assertEqual(reporter.statistic_cells(player), (2, 2, 0, '100.00%'))

    def test_inconsistent_statistics_fail_before_export(self):
        snapshot = query_fixture()
        cases = [
            {'wins': -1}, {'wins': True}, {'wins': 4}, {'ranked_matches': 0},
            {'win_rate': 0.5}, {'win_rate': None}, {'win_rate': '66.67%'},
            {'ranked_matches': 0, 'wins': 0, 'losses': 0, 'win_rate': 0.0},
        ]
        for changes in cases:
            with self.subTest(changes=changes):
                invalid = json.loads(json.dumps(snapshot))
                invalid['players'][0].update(changes)
                with self.assertRaises(ValueError):
                    reporter.validate(invalid)
        del snapshot['players'][0]['wins']
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            reporter.validate(snapshot)


if __name__ == '__main__':
    unittest.main()
