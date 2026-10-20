"""Update only cosmetic card metadata and package the finished mod."""
import json
import argparse
import shutil
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'examples/testmod'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', default='1.0.2')
    parser.add_argument('--cards-dir', type=Path, default=ROOT/'output/testmod-design-v2/cards')
    args = parser.parse_args()
    manifest_path = PACK / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for filename in manifest['cards']:
        file = PACK / filename
        card = json.loads(file.read_text(encoding='utf-8'))
        identifier = card['卡牌ID'].split('/')[1]
        image = f'art/{identifier}.png'
        rendered = args.cards_dir / f'{identifier}.png'
        if not rendered.is_file():
            raise FileNotFoundError(rendered)
        shutil.copy2(rendered, PACK / image)
        if not (PACK / image).is_file():
            raise FileNotFoundError(image)
        card['图片'] = image
        card['名称'] = card['名称'].replace('【','「').replace('】','」').replace('の','ノ')
        card['来源'] = 'testmod · 用户提供牌文；imagegen 原创 AI 插画；使用 UI模板 道具／符卡／单位 PSD 和用户提供字体制作；结界使用符卡模板'
        file.write_text(json.dumps(card, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    manifest['version'] = args.version
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    output = ROOT / f'output/testmod-{args.version}.zip'
    with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
        for file in sorted(PACK.rglob('*')):
            if file.is_file() and file.suffix not in {'.import', '.uid'}:
                archive.write(file, Path('testmod') / file.relative_to(PACK))
    print(f'Updated {len(manifest["cards"])} cosmetic definitions; package: {output}')


if __name__ == '__main__':
    main()
