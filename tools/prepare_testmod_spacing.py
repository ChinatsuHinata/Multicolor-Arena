"""Read native text spacing and prepare a complete, reversible art revision."""
import hashlib
import json
import os
import shutil
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from psd_tools import PSDImage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT', 'output/testmod-spacing')
PACK = ROOT / 'examples/testmod'
RECEIVED = Path('C:/Users/Lenovo/Documents/Tencent Files/1329315537/FileRecv')
SPECS = [
    ('unit', Path('D:/叶子游戏/模板/教学用 天才教师上白泽慧音.psd'), 54),
    ('item', RECEIVED / 'UI模板 道具.psd', 9),
    ('spell', Path('D:/叶子游戏/模板/符卡 四重結界.psd'), 42),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').touch()
    for folder in ['illustrations', 'components', 'cards', 'psd']:
        (OUT / folder).mkdir(exist_ok=True)
    manifest = json.loads((PACK / 'manifest.json').read_text(encoding='utf8'))
    source_files = manifest['cards'] + ['abilities.gd', 'scarlet_moon.gd', 'manifest.json', 'README.txt']
    snapshot = OUT / 'source-rules.sha256.json'
    if not snapshot.exists():
        snapshot.write_text(json.dumps({name: digest(PACK / name) for name in source_files}, indent=2), encoding='utf8')
    backup = OUT / 'before-revision.zip'
    if not backup.exists():
        with ZipFile(backup, 'w', ZIP_DEFLATED) as archive:
            for location in ['examples/testmod', 'mod/testmod']:
                for path in sorted((ROOT / location).rglob('*')):
                    if path.is_file() and path.suffix not in ['.import', '.uid']:
                        archive.write(path, path.relative_to(ROOT))
    # Retain the successful originals, including both distinct Flandre artworks.
    for folder in ['output/testmod-design/illustrations', 'output/testmod-scarlet-moon/illustrations']:
        for path in (ROOT / folder).glob('*.png'):
            target = OUT / 'illustrations' / path.name
            if not target.exists():
                shutil.copy2(path, target)
    for path in (ROOT / 'output/testmod-typography-v5/components').glob('*.png'):
        shutil.copy2(path, OUT / 'components' / path.name)
    profile = {'templates': [], 'choice_reference': 'recourse/数据库/character-fdf-112.jpg',
               'choice_format': '①②；选项和续行与正文左侧对齐；换行不额外增加段距。'}
    for kind, source, index in SPECS:
        psd = PSDImage.open(source)
        layer = list(psd.descendants())[index]
        runs = []
        for run in layer.engine_dict['StyleRun']['RunArray']:
            data = run['StyleSheet']['StyleSheetData']
            runs.append({key: data[key].value for key in ['FontSize', 'Tracking', 'Leading', 'AutoLeading'] if key in data})
        profile['templates'].append({'kind': kind, 'source': str(source), 'sha256': digest(source),
                                     'layer': index, 'text': layer.text, 'bbox': list(layer.bbox), 'styles': runs})
        assert runs[0]['Tracking'] == (-50 if kind == 'spell' else -40)
        assert abs(runs[0]['Leading'] - (65 if kind == 'spell' else 58.33333)) < .001
    (OUT / 'spacing-profile.json').write_text(json.dumps(profile, ensure_ascii=False, indent=2), encoding='utf8')
    print('Prepared native spacing evidence, original illustrations and complete pre-revision backup.')


if __name__ == '__main__':
    main()
