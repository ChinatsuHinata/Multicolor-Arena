"""Prepare title calibration from the actual PSDs without changing older exports."""
import hashlib
import json
import os
import shutil
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from psd_tools import PSDImage
from outline_testmod_text import resolve_fonts

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT', 'output/testmod-titles')
BASE = ROOT / 'output/testmod-spacing'
SOURCES = {
    'unit': ('D:/叶子游戏/模板/教学用 天才教师上白泽慧音.psd', [76, 77]),
    'item': ('C:/Users/Lenovo/Documents/Tencent Files/1329315537/FileRecv/UI模板 道具.psd', [65, 66]),
    'spell': ('D:/叶子游戏/模板/符卡 四重結界.psd', [40]),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').touch()
    for folder in ['illustrations', 'components']:
        (OUT / folder).mkdir(exist_ok=True)
        for source in (BASE / folder).glob('*.png'):
            target = OUT / folder / source.name
            if not target.exists():
                shutil.copy2(source, target)
    for name in ['spacing-profile.json', 'prompt-set.json']:
        shutil.copy2(BASE / name, OUT / name)
    pack = ROOT / 'examples/testmod'
    manifest = json.loads((pack / 'manifest.json').read_text(encoding='utf8'))
    files = manifest['cards'] + ['abilities.gd', 'scarlet_moon.gd', 'manifest.json', 'README.txt']
    snapshot = OUT / 'source-rules.sha256.json'
    if not snapshot.exists():
        snapshot.write_text(json.dumps({name: digest(pack / name) for name in files}, indent=2), encoding='utf8')
    backup = OUT / 'before-revision.zip'
    if not backup.exists():
        with ZipFile(backup, 'w', ZIP_DEFLATED) as archive:
            for folder in ['examples/testmod', 'mod/testmod']:
                for source in sorted((ROOT / folder).rglob('*')):
                    if source.is_file() and source.suffix not in ['.uid', '.import']:
                        archive.write(source, source.relative_to(ROOT))
    profile = {'templates': {}, 'fonts': {}, 'baseline_revision': str(BASE.relative_to(ROOT)),
               'horizontal': {'size': 75, 'tracking': -5, 'max_ink_width': 1042,
                              'center': [784, 172], 'fit': 'horizontal-scale-only'},
               'vertical': {'max_size': 100, 'tracking': 220, 'faux_bold_ratio': .03,
                            'center': [1828, 745], 'max_ink_height': 1260,
                            'positioning': 'vmtx-origin-and-advance'}}
    for kind, (filename, indices) in SOURCES.items():
        source = Path(filename)
        psd = PSDImage.open(source)
        layers = list(psd.descendants())
        records = []
        for index in indices:
            layer = layers[index]
            fonts = [f['Name'].value for f in layer.resource_dict['FontSet']]
            styles = []
            for run in layer.engine_dict['StyleRun']['RunArray']:
                data = run['StyleSheet']['StyleSheetData']
                styles.append({'font': fonts[data['Font'].value], **{
                    key: data[key].value for key in ['FontSize', 'Tracking', 'FauxBold', 'StrokeFlag'] if key in data}})
            effects = [{'type': effect.name, 'size': effect.size, 'opacity': effect.opacity,
                        'choke': effect.choke} for effect in layer.effects if effect.enabled and effect.name == 'OuterGlow']
            records.append({'layer': index, 'text': layer.text, 'bbox': list(layer.bbox),
                            'transform': list(layer.transform), 'styles': styles, 'effects': effects})
        profile['templates'][kind] = {'source': str(source), 'sha256': digest(source), 'titles': records}
    for name, path in resolve_fonts().items():
        assert path and path.is_file(), (name, path)
        profile['fonts'][name] = {'path': str(path), 'sha256': digest(path)}
    assert profile['templates']['unit']['titles'][0]['effects'] == [
        {'type': 'OuterGlow', 'size': 10., 'opacity': 75., 'choke': 50.}]
    assert profile['templates']['spell']['titles'][0]['effects'] == [
        {'type': 'OuterGlow', 'size': 10., 'opacity': 100., 'choke': 0.}]
    (OUT / 'title-profile.json').write_text(json.dumps(profile, ensure_ascii=False, indent=2), encoding='utf8')
    print('Prepared source title faces, punctuation runs, native glow evidence and reversible backup.')


if __name__ == '__main__':
    main()
