"""Verify recording-era sample selection and CSV report exports."""
import csv
from datetime import datetime
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('character_report', Path(__file__).resolve().parents[1] / 'download-cloud-character-report.py')
reporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reporter)


def fixture():
    cutoff = int(datetime.fromisoformat(reporter.DEFAULT_SINCE).timestamp())
    timestamp = cutoff + 3600
    def match(match_id, winner=0, status='settled', ranked=True, created=None):
        return {'match_id':match_id, 'created_at':timestamp if created is None else created,
                'status':status, 'winner':winner,
                'rank_a':'{"tier":0}' if ranked else None, 'rank_b':'{"tier":0}' if ranked else None}
    return {
        'server':'example.invalid',
        'snapshot_time_china':datetime.fromtimestamp(timestamp + 3600, reporter.CHINA_TZ).isoformat(),
        'cards':{'a':{'canonical':'a','leader':True,'name':'自机 A'},
                 'a-art':{'canonical':'a','leader':True,'name':'自机 A 异画'},
                 'b':{'canonical':'b','leader':True,'name':'自机 B'}},
        'matches':[match('normal'),match('mirror',1),match('missing'),match('cancelled',status='cancelled'),
                   match('ongoing',status='playing'),match('elo',ranked=False),
                   match('before',created=cutoff - 1)],
        'leader_records':[{'match_id':'normal','leaders':['a-art','b']},
                          {'match_id':'normal','leaders':['a','b']},
                          {'match_id':'mirror','leaders':['a','a-art']}],
        'leader_log_exists':True, 'recorder_installed':True, 'invalid_log_lines':0,
    }


class CharacterStatisticsTests(unittest.TestCase):
    def test_mirror_aliases_and_ranked_scope(self):
        result = reporter.calculate(fixture())
        self.assertEqual(result['eligible_matches'],3)
        self.assertEqual(result['covered_matches'],2)
        self.assertEqual(result['missing_leader_matches'],1)
        self.assertEqual(result['participations'],4)
        rows = {row['leader_id']:row for row in result['rows']}
        self.assertEqual((rows['a']['uses'],rows['a']['wins'],rows['a']['losses']),(3,2,1))
        self.assertEqual(rows['a']['usage_rate'],0.75)
        self.assertAlmostEqual(rows['a']['win_rate'],2/3)
        self.assertEqual(rows['b']['win_rate'],0)
        self.assertEqual(result['excluded'],{'cancelled':1,'playing':1,'no_ranked_settlement':1,'before_character_recording':1})

    def test_rollout_boundary_ignores_earlier_matches_and_missing_metadata(self):
        snapshot = fixture()
        cutoff = int(datetime.fromisoformat(reporter.DEFAULT_SINCE).timestamp())
        snapshot['matches'][0]['created_at'] = cutoff
        for match in snapshot['matches'][1:3]:
            match['created_at'] = cutoff - 1
        result = reporter.calculate(snapshot)
        self.assertEqual((result['eligible_matches'], result['covered_matches']), (1, 1))
        self.assertEqual(result['missing_leader_matches'], 0)
        self.assertEqual(result['coverage_rate'], 1)
        self.assertEqual(result['status'], 'complete')
        self.assertEqual(result['excluded']['before_character_recording'], 3)
        self.assertEqual(result['participations'], 2)
        self.assertEqual(result['statuses_since_character_recording']['settled'], 2)
        self.assertEqual([(row['uses'], row['wins']) for row in result['rows']], [(1, 1), (1, 0)])
        earlier = datetime.fromtimestamp(cutoff - 86400, reporter.CHINA_TZ).isoformat()
        self.assertEqual(reporter.calculate(snapshot, earlier), result)

    def test_later_start_and_timezone_validation(self):
        snapshot = fixture()
        later = snapshot['snapshot_time_china']
        result = reporter.calculate(snapshot, later)
        self.assertEqual(result['since_china'], later)
        self.assertEqual(result['eligible_matches'], 0)
        self.assertIsNone(result['coverage_rate'])
        self.assertEqual(result['rows'], [])
        with self.assertRaises(ValueError):
            reporter.calculate(snapshot, '2026-10-12T00:00:00')

    def test_no_metadata_is_missing_not_zero_win_rate(self):
        snapshot = fixture()
        snapshot['leader_records'] = []
        result = reporter.calculate(snapshot)
        self.assertEqual(result['status'],'insufficient_data')
        self.assertEqual(result['covered_matches'],0)
        self.assertEqual(result['rows'],[])
        self.assertEqual(result['missing_leader_matches'],3)

    def test_conflicting_pair_is_excluded(self):
        snapshot = fixture()
        snapshot['leader_records'].append({'match_id':'normal','leaders':['b','a']})
        result = reporter.calculate(snapshot)
        self.assertEqual(result['covered_matches'],1)
        self.assertEqual(result['coverage_missing_reasons']['conflicting_leaders'],1)
        self.assertEqual(result['rows'][0]['win_rate'],0.5)

    def test_unknown_character_excludes_whole_match(self):
        snapshot = fixture()
        snapshot['leader_records'] = [{'match_id':'normal','leaders':['a','unknown']}]
        result = reporter.calculate(snapshot)
        self.assertEqual(result['covered_matches'],0)
        self.assertEqual(result['invalid_leader_records'],1)

    def test_character_csv_has_percentages_scope_and_no_blank_records(self):
        snapshot = fixture()
        snapshot['cards']['a']['name'] = '自机,"甲"\n异画'
        result = reporter.calculate(snapshot)
        with tempfile.TemporaryDirectory() as folder:
            paths = reporter.export(result, folder)
            archive = Path(paths['report'])
            latest = Path(paths['latest'])
            self.assertEqual(archive.suffix, '.csv')
            self.assertEqual(archive.read_bytes(), latest.read_bytes())
            self.assertTrue(archive.read_bytes().startswith(b'\xef\xbb\xbf'))
            self.assertNotIn(b'\r\r\n', archive.read_bytes())
            with archive.open(encoding='utf-8-sig', newline='') as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows[0]['自机'], snapshot['cards']['a']['name'])
            self.assertEqual(rows[0]['样本内使用率'], '75.00%')
            self.assertEqual(rows[0]['胜率'], '66.67%')
            self.assertEqual(rows[0]['统计起始版本'], result['start_version'])
            self.assertEqual(rows[0]['统计起始时间（北京时间）'], result['since_china'])
            self.assertEqual(rows[0]['数据时间（北京时间）'], result['snapshot_time_china'])

    def test_no_samples_csv_contains_only_header(self):
        snapshot = fixture()
        snapshot['leader_records'] = []
        with tempfile.TemporaryDirectory() as folder:
            paths = reporter.export(reporter.calculate(snapshot), folder)
            with Path(paths['latest']).open(encoding='utf-8-sig', newline='') as stream:
                rows = list(csv.reader(stream))
            self.assertEqual(len(rows), 1)
            self.assertIn('胜率', rows[0])

    def test_rank_csv_preserves_order_and_text_cells(self):
        rank = reporter.rank_report
        snapshot = {
            'server': 'example.invalid', 'snapshot_time_china': fixture()['snapshot_time_china'],
            'total_players': 3, 'sage_players': 2,
            'players': [
                {'position': 1, 'player_id': 20, 'nickname': '玩家,"甲"\n中文', 'username': 'user_a',
                 'rank_step': 11, 'rank_stars': 0, 'elo': 1500},
                {'position': 2, 'player_id': 10, 'nickname': '=1+1', 'username': '@user_b',
                 'rank_step': 11, 'rank_stars': 3, 'elo': 1400},
                {'position': 3, 'player_id': 30, 'nickname': '玩家丙', 'username': 'user_c',
                 'rank_step': 10, 'rank_stars': 2, 'elo': 1800},
            ],
        }
        with tempfile.TemporaryDirectory() as folder:
            paths = rank.export(snapshot, folder)
            archive = Path(paths['report'])
            self.assertEqual(archive.suffix, '.csv')
            self.assertEqual(archive.read_bytes(), Path(paths['latest']).read_bytes())
            self.assertTrue(archive.read_bytes().startswith(b'\xef\xbb\xbf'))
            self.assertNotIn(b'\r\r\n', archive.read_bytes())
            with archive.open(encoding='utf-8-sig', newline='') as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual([row['账号 ID'] for row in rows], ['20', '10', '30'])
            self.assertEqual(rows[0]['昵称'], snapshot['players'][0]['nickname'])
            self.assertEqual(rows[0]['段位'], '妖怪贤者')
            self.assertEqual(rows[1]['昵称'], "'=1+1")
            self.assertEqual(rows[1]['账号名'], "'@user_b")
            self.assertEqual(rows[2]['段位'], '妖怪级 1 · 2 星')


class RecorderInstallationTests(unittest.TestCase):
    def test_relay_patch_preserves_other_online_code_and_is_idempotent(self):
        installer_spec = importlib.util.spec_from_file_location('installer',Path(__file__).resolve().parents[1]/'install-cloud-character-recorder.py')
        installer = importlib.util.module_from_spec(installer_spec)
        installer_spec.loader.exec_module(installer)
        source = (Path(__file__).resolve().parents[2]/'relay/server.gd').read_text(encoding='utf-8')
        self.assertEqual(installer.patch_source(source),source)
        original = source.replace(installer.DECLARATION,'').replace(installer.LOG_PATH,'').replace(installer.OBSERVED_FORWARD,installer.FORWARD)
        patched = installer.patch_source(original)
        self.assertEqual(installer.patch_source(patched),patched)
        restored = patched.replace(installer.DECLARATION,'').replace(installer.LOG_PATH,'').replace(installer.OBSERVED_FORWARD,installer.FORWARD)
        self.assertEqual(restored,original)
        with self.assertRaises(ValueError):
            installer.patch_source(original.replace(installer.FORWARD,''))


if __name__ == '__main__':
    unittest.main()
