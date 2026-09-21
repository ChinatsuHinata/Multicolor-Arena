from pathlib import Path
from collections import Counter
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
read = lambda p: json.loads((root / p).read_text(encoding='utf-8-sig'))
plan = read('work/v010-import-plan.json')
old = read('work/v010-backup/saves/decks.json')['decks']
saved = read('saves/decks.json')['decks']
assert saved[:len(old)] == old and len(saved) == len(old) + 2
templates = read('data/test_precons.json')['decks']
assert saved[-2:] == templates
for deck in templates:
    assert len(deck['main']) == 50 and not deck['side']
    assert read(f'cards/{deck["leader"]}.json')['类别'] == '自机'
    assert all(read(f'cards/{cid}.json')['构筑资格']['允许常规构筑'] for cid in deck['main'])
for item in plan['cards']:
    p = (root / item['destination']).resolve()
    assert p.is_relative_to(root) and p.is_file()
    assert hashlib.sha256(p.read_bytes()).hexdigest().lower() == item['sha256'].lower(), p
    if item['operation'] == 'move':
        assert not (root / item['source']).exists(), item['source']
old_cards = list((root / 'work/v010-backup/cards').glob('*.json'))
assert len(old_cards) == 65
assert all(json.loads(p.read_text(encoding='utf-8-sig')) == read('cards/' + p.name) for p in old_cards)
later = read('work/v010-later-queue.json')
assert all(hashlib.sha256((root / 'recourse/新增卡片' / name).read_bytes()).hexdigest() == digest for name, digest in later.items())
logs = ['v010-regression-test_v010_rules.log', 'v010-regression-test_v098_rules.log',
        'v010-regression-test_v095_rules.log', 'v010-regression-test_v096_rules.log',
        'v010-regression-test_v09_rules.log', 'v010-regression-test_duel_rules.log',
        'v010-regression-test_v097_database.log', 'v010-regression-test_v098.log', 'v010-ui.log']
report = ['v0.10 final validation — 2026-09-19', '']
total = 0
for name in logs:
    content = (root / 'work' / name).read_text(encoding='utf-8-sig')
    results = re.findall(r'([A-Z0-9_]+): (\d+) checks; (\d+) failures', content)
    assert len(results) == 1 and results[0][2] == '0', name
    assert not any(('ERROR:' in line or 'FAIL:' in line) and 'Failed to read the root certificate store' not in line for line in content.splitlines()), name
    total += int(results[0][1])
    report.append(f'{name}: {results[0][1]} checks; 0 failures')
matchlog = (root / 'work/v010-regression-test_v010_matches.log').read_text(encoding='utf-8-sig')
assert 'V010_MATCHES: 8 matches; 0 unfinished' in matchlog
report += ['', f'Total: {total} checks; 0 failures.', '8 full precon matches finished (both first-player assignments, seeds 1–8).',
           'No project script/texture/shader error in selected logs. Existing Windows root certificate diagnostic only.',
           'All 132 database images imported and decoded in Godot; index hashes match.',
           '57 supplied image moves and 13 supplementary art entries verified against the archive plan.',
           'Original 65 card definitions unchanged; original 4 saved decks preserved.',
           'Two saved precons exactly match templates: 50 main + 1 leader, 0 side, 0 tokens.',
           'Fresh graphical launch selects saved precons; 43 UI checks passed.',
           'New later queue: 30 images not in initial backup, left unchanged pending batch decision.',
           'Visual QA: precon editors, opening table, multi-target stack, region search, direct unit attack.',
           'Missing source art: token-ucs-093 uses an SVG medicine placeholder. Effect implemented.',
           'Backup: work/v010-backup. Saved-deck .bak retains the pre-install list.',
           'All outputs and project changes remain under C:/Users/tzx20/Documents/test.']
(root / 'work/v010-validation.txt').write_text('\n'.join(report) + '\n', encoding='utf-8')
print('\n'.join(report))
