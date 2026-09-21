"""Audit only registered cards; never import or scan the new-card queue."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
ART_DIRECTORY = 'res://recourse/数据库/'
INDEX_PATH = ROOT / 'recourse/数据库/卡图索引.json'


def registered_ids():
    source = (ROOT / 'scripts/card_database.gd').read_text(encoding='utf-8-sig')
    match = re.search(r'^const IDS\s*=\s*(\[[^\]]*\])', source, re.M)
    if not match:
        raise ValueError('找不到已登记卡牌ID清单')
    ids = json.loads(match[1])
    if len(ids) != len(set(ids)):
        raise ValueError('已登记卡牌ID重复')
    return ids


def build_index():
    result = []
    for card_id in registered_ids():
        definition = ROOT / 'cards' / f'{card_id}.json'
        card = json.loads(definition.read_text(encoding='utf-8-sig'))
        if card.get('卡牌ID') != card_id:
            raise ValueError(f'{definition.name}: 卡牌ID不符')
        image = card.get('图片', '')
        if not image.startswith(ART_DIRECTORY):
            raise ValueError(f'{card_id}: 卡图未归档至数据库: {image}')
        relative = PurePosixPath(image.removeprefix('res://'))
        if relative.stem != card_id or relative.parent.as_posix() != 'recourse/数据库':
            raise ValueError(f'{card_id}: 卡图必须以稳定ID命名，且直接位于数据库目录')
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError(f'{card_id}: 图片不存在: {image}')
        item = {'卡牌ID': card_id, '名称': card['名称'], '数据': f'res://cards/{card_id}.json',
                '图片': image, 'SHA256': hashlib.sha256(path.read_bytes()).hexdigest().upper()}
        if path.suffix == '.tres':
            resource = path.read_text(encoding='utf-8-sig')
            if 'type="AtlasTexture"' not in resource:
                raise ValueError(f'{card_id}: 不支持的卡图资源类型')
            sources = re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)"', resource)
            if not sources:
                raise ValueError(f'{card_id}: 裁剪卡图缺少原图')
            item['图集来源'] = []
            for source in sources:
                if not source.startswith(ART_DIRECTORY):
                    raise ValueError(f'{card_id}: 裁剪原图必须位于数据库')
                original = (ROOT / source.removeprefix('res://')).resolve()
                if not original.is_relative_to(ROOT) or not original.is_file():
                    raise ValueError(f'{card_id}: 裁剪原图不存在')
                item['图集来源'].append({'图片': source, 'SHA256': hashlib.sha256(original.read_bytes()).hexdigest().upper()})
        result.append(item)
    return {'格式版本': 1, '说明': '仅登记已经进入游戏的卡牌；新增卡片目录不属于运行时数据库。', '卡牌': result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-index', action='store_true', help='通过检查后重建已有卡牌的图片清单，不新增ID或导入卡牌')
    args = parser.parse_args()
    index = build_index()
    if args.write_index:
        INDEX_PATH.write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    else:
        saved = json.loads(INDEX_PATH.read_text(encoding='utf-8-sig'))
        if saved != index:
            raise ValueError('卡图清单与实际文件不一致；核对修改后使用 --write-index 更新清单')
    print(f"Database OK: {len(index['卡牌'])} registered cards; all images exist; hashes match.")


if __name__ == '__main__':
    main()
