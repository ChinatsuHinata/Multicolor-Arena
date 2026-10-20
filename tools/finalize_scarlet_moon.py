"""Install and package the checked expansion, preserving every previous card and artwork."""
import hashlib
import json
import shutil
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'examples/testmod'
TARGET=ROOT/'mod/testmod'
OUT=ROOT/'output/testmod-scarlet-moon'
IDS=['forbidden_game','forbidden_fruits','vlad_curse','scarlet_meister','chanting_youka','dragon_jewel','buddha_diamond','salamander_shield','life_spring','hourai_branch','eternal_night']

def main():
    manifest=json.loads((SOURCE/'manifest.json').read_text(encoding='utf8'))
    report=json.loads((OUT/'render-report.json').read_text(encoding='utf8'))
    assert {r['id'] for r in report}==set(IDS),'all requested art must be rendered'
    for key in IDS:
        assert (OUT/'illustrations'/f'{key}.png').is_file()
        image=OUT/'cards'/f'{key}.png'
        assert image.is_file()
        shutil.copy2(image,SOURCE/'art'/image.name)
        shutil.copy2(image,TARGET/'art'/image.name)
        shutil.copy2(SOURCE/f'{key}.json',TARGET/f'{key}.json')
    for name in ['scarlet_bat.json','scarlet_moon.gd','manifest.json','README.txt']:
        shutil.copy2(SOURCE/name,TARGET/name)
    for relative in manifest['cards']+['abilities.gd','scarlet_moon.gd','manifest.json','README.txt']:
        assert (SOURCE/relative).read_bytes()==(TARGET/relative).read_bytes(),f'installed rules differ: {relative}'
    zip_path=ROOT/'output'/f'testmod-{manifest["version"]}.zip'
    with ZipFile(zip_path,'w',ZIP_DEFLATED) as archive:
        for path in sorted(SOURCE.rglob('*')):
            if path.is_file() and path.suffix not in ['.uid','.import'] and not any(s.startswith('.') for s in path.relative_to(SOURCE).parts):
                archive.write(path,path.relative_to(SOURCE))
    hashes={str(path.relative_to(SOURCE)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(SOURCE.rglob('*')) if path.is_file() and path.suffix not in ['.uid','.import']}
    (OUT/'package-hashes.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'Installed and packaged {zip_path}: {len(IDS)} new full card artworks, one bat token; original cards preserved.')

if __name__=='__main__':main()
