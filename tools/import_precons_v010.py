"""Explicit, reviewed v0.10 batch. Plan first; archive art before writing definitions.

Uses only the project's cached catalog/art; never downloads or scans a future batch.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'work/v010-import-plan.json'
COLORS = dict(red='红', blue='蓝', green='绿', yellow='黄', black='黑')
MANUAL = {'image4.png': 'character-soi-006', 'image16.png': 'character-soi-018',
          'image95.png': 'spell-soi-098'}
EXISTING = {'spell-rei-009': '100', 'field-rei-016': '170', 'character-rei-020': '29',
            'spell-rei-025': '177', 'spell-mar-009': '99', 'item-mar-016': '164'}
REI = ['spell-rei-002', 'field-rei-003', 'field-rei-004', 'field-rei-005',
       'spell-rei-006', 'character-rei-007', 'spell-rei-008', 'spell-rei-009',
       'spell-rei-010', 'spell-rei-011', 'spell-rei-012', 'field-rei-013',
       'spell-rei-014', 'spell-rei-015', 'field-rei-016', 'character-rei-017',
       'character-rei-018', 'character-rei-019', 'character-rei-020', 'character-rei-021',
       'character-rei-022', 'character-rei-023', 'character-rei-024', 'spell-rei-025',
       'character-rei-026', 'character-rei-ex01']
MAR = ['spell-mar-002', 'spell-mar-003', 'spell-mar-004', 'spell-mar-005',
       'spell-mar-007', 'field-mar-006', 'spell-mar-008', 'spell-mar-009',
       'spell-mar-010', 'spell-mar-011', 'spell-mar-012', 'spell-mar-013',
       'spell-mar-014', 'spell-mar-015', 'item-mar-016', 'item-mar-017',
       'character-mar-018', 'character-mar-019', 'character-mar-020', 'character-mar-021',
       'character-mar-022', 'character-mar-023', 'character-mar-024', 'character-mar-025',
       'character-mar-026', 'character-mar-ex01']


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def full_name(card):
    if card['card_type'] == 'character':
        return card.get('title', '') + '「' + card['name'].strip() + '」'
    return card['name'].strip()


def identity(card):
    # This is one printed card, with two transcriptions in the supplied sources.
    return full_name(card).replace('辉光之城', '辉光ノ城')


def checked(relative):
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError('Path outside permitted project: ' + str(path))
    return path


def make_plan():
    catalog = {c['id']: c for c in read(ROOT / 'recourse/爬虫/cards_index.json')}
    manifest = read(ROOT / 'recourse/爬虫/download_manifest.json')['cards']
    by_file = {v['file']: k for k, v in manifest.items()}
    queue = ROOT / 'recourse/新增卡片'
    rows = []
    for path in sorted(queue.iterdir()):
        if path.suffix.lower() not in ['.jpg', '.jpeg', '.png']:
            continue
        sid = MANUAL.get(path.name, by_file.get(path.name))
        assert sid in catalog, (path.name, sid)
        c = catalog[sid]
        rows.append({'source_id': sid, 'name': full_name(c), 'identity': identity(c),
                     'source': path.relative_to(ROOT).as_posix(), 'operation': 'move',
                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    available = {r['identity'] for r in rows}
    for sid in ['character-rei-001', 'character-mar-001'] + REI + MAR:
        if sid in EXISTING or identity(catalog[sid]) in available:
            continue
        path = ROOT / 'recourse/爬虫' / manifest[sid]['file']
        assert path.is_file(), path
        rows.append({'source_id': sid, 'name': full_name(catalog[sid]), 'identity': identity(catalog[sid]),
                     'source': path.relative_to(ROOT).as_posix(), 'operation': 'copy',
                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        available.add(identity(catalog[sid]))
    groups = {}
    for row in rows:
        groups.setdefault(row['identity'], []).append(row)
    mapping = {identity(catalog[k]): v for k, v in EXISTING.items()}
    selected = []
    for name, group in groups.items():
        # Prefer the supplied REI print when duplicate reprints were supplied.
        chosen = next((r for r in group if '-rei-' in r['source_id']), group[0])
        cid = chosen['source_id']
        mapping[name] = cid
        selected.append(cid)
        for row in group:
            row['card_id'] = cid
            row['primary'] = row is chosen
            row['destination'] = 'recourse/数据库/' + (cid if row is chosen else '异画与重复/v0.10/' + row['source_id']) + Path(row['source']).suffix.lower()
    decks = []
    for name, leader, ids in [('灵梦', 'character-rei-001', REI), ('魔理沙', 'character-mar-001', MAR)]:
        deck = {'id': 'precon_reimu_v1' if name == '灵梦' else 'precon_marisa_v1',
                'name': '预组-' + name, 'leader': mapping[identity(catalog[leader])], 'main': [], 'side': []}
        counts = []
        for sid in ids:
            n = 2
            if sid in ['spell-rei-008', 'field-rei-016', 'character-rei-ex01', 'spell-mar-008', 'character-mar-ex01']:
                n = 1
            if sid == 'spell-rei-011':
                n = 3
            cid = mapping[identity(catalog[sid])]
            deck['main'].extend([cid] * n)
            counts.append({'source_code': catalog[sid]['code'], 'card_id': cid, 'name': full_name(catalog[sid]), 'count': n})
        assert len(deck['main']) == 50
        decks.append({'deck': deck, 'counts': counts})
    plan = {'version': 1, 'cards': rows, 'registered_new_ids': selected, 'precons': decks,
            'note': '照片MAR-006灵击符与MAR-007雾雨魔法店的编号顺序和缓存卡目相反，按牌名核对。衍生物不进入预组。'}
    write(PLAN, plan)
    print(f'Plan: {len(rows)} images ({sum(r["operation"] == "move" for r in rows)} moved), {len(selected)} definitions; two 50+1 precons.')


def archive():
    plan = read(PLAN)
    for row in plan['cards']:
        source, dest = checked(row['source']), checked(row['destination'])
        assert source.is_file(), source
        assert hashlib.sha256(source.read_bytes()).hexdigest() == row['sha256']
        assert not dest.exists(), dest
    # All resolved paths were verified above before the first move.
    for row in plan['cards']:
        source, dest = checked(row['source']), checked(row['destination'])
        dest.parent.mkdir(parents=True, exist_ok=True)
        (shutil.move if row['operation'] == 'move' else shutil.copy2)(str(source), str(dest))
        # Preserve old import metadata in the batch backup; Godot reimports the new path.
        imp = Path(str(source) + '.import')
        if row['operation'] == 'move' and imp.exists():
            backup = ROOT / 'work/v010-backup/import-metadata' / imp.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(imp), str(backup))
        assert hashlib.sha256(dest.read_bytes()).hexdigest() == row['sha256']
    print('Archived all art, byte-for-byte hashes verified. Definitions have not been changed.')


# These keys are explicit engine contracts, not text interpreted as executable code.
EFFECTS = {
 'character-soi-018': ['ramp_enter'], 'character-soi-006': ['all_colors'],
 'spell-soi-098': ['ramp_one'], 'spell-rei-015': ['ramp_two'],
 'spell-fdf-054': ['cloud_modes'], 'spell-mar-007': ['reveal_counter'],
 'field-fdn-016': ['brave_aura'], 'spell-fdf-ex05': ['scarlet_anthem'],
 'spell-rei-006': ['promise'], 'spell-mar-005': ['shuffle_field'],
 'character-fdf-ex05': ['keine_devour'], 'token-fdf-133': ['vampire_lifesteal'],
 'character-rei-ex01': ['larva_draw'], 'character-fdf-ex04': ['tenshi_tap', 'tenshi_ping'],
 'character-rei-001': ['reimu_search', 'reimu_leader'], 'spell-rei-010': ['spirit_four'],
 'character-mar-020': ['marisa_untap'], 'token-smm-025': [],
 'character-rei-017': [], 'character-rei-007': ['sand_add'],
 'field-rei-004': ['standing_blast'], 'character-rec-096': ['tewi_counters'],
 'character-fdf-070': ['letty_shield'], 'token-fdn-085': ['illusion_check'],
 'spell-mar-002': ['double_spark'], 'spell-mar-003': ['laser'],
 'character-fdf-ex01': ['flandre_direct'], 'field-fdf-108': ['old_city'],
 'spell-fdf-019': ['escape'], 'spell-fdf-023': ['meteor'],
 'character-fdf-116': ['eirin_return', 'eirin_medicine'], 'token-fdf-132': [],
 'spell-fdf-011': ['barrier_base'], 'character-rei-022': ['shou_shield'],
 'spell-rei-011': ['dream_orbs'], 'spell-rei-012': ['counter_three'],
 'character-fdf-099': ['mike_swap'], 'spell-fdf-007': ['palette_three'],
 'character-fdf-ex02': ['yukari_blink', 'yukari_active'],
 'character-rei-026': ['sanae_end'], 'field-rei-005': ['bind_field'],
 'spell-rei-002': ['spread_damage'], 'character-mar-ex': ['marisa_search', 'marisa_recover'],
 'token-kmo-027': [], 'field-rei-003': ['watch_counter'],
 'character-rec-104': ['kosuzu_destroy'], 'field-smm-004': ['castle_exile'],
 'spell-mar-004': ['silent_spark'], 'field-mar-006': ['shop_discount'],
 'character-ucs-060': [], 'token-fdf-130': ['oni_attack'],
 'character-fdf-ex03': ['byakuren_x', 'byakuren_leader'],
 'spell-fdf-036': ['stardust'], 'character-fdf-095': ['miyoi_wine'],
 'character-rei-023': ['minoriko_untap'], 'spell-mar-012': ['shoot_moon'],
 'spell-mar-013': ['spring'], 'spell-mar-014': ['paranoid'], 'item-mar-017': ['furnace'],
 'character-mar-021': ['patch_exchange'], 'character-mar-022': ['seiran_exile'],
 'character-mar-023': ['koakuma_palette'], 'character-mar-024': ['iku_flash'],
 'character-mar-025': ['tokiko_search'], 'character-mar-ex01': ['patch_topthree', 'patch_chromatic'],
 'token-fdf-128': ['wine_discount'], 'token-ucs-093': ['medicine_return']
}
KEYWORDS = {
 'character-soi-018': ['歼灭'], 'character-soi-006': ['极彩'],
 'character-rei-017': ['退治'], 'character-fdf-070': ['高速移动'],
 'character-rei-ex01': ['奇迹', '结晶'], 'character-fdf-ex04': ['英勇'],
 'character-fdf-ex01': ['先制', '歼灭'], 'character-ucs-060': ['追击'],
 'spell-mar-003': ['支援'], 'spell-fdf-023': ['支援'],
 'spell-mar-013': ['极彩'], 'spell-mar-004': ['限制级'], 'spell-fdf-007': ['限制级'],
 'spell-fdf-ex05': ['终言'], 'token-fdf-132': ['疾行', '不占战场格'],
 'token-fdf-133': ['吸血1', '不占战场格'], 'token-fdn-085': ['先制']
}


def define():
    plan = read(PLAN)
    catalog = {c['id']: c for c in read(ROOT / 'recourse/爬虫/cards_index.json')}
    manifest = read(ROOT / 'recourse/爬虫/download_manifest.json')['cards']
    # Two tokens are required by the imported units. They are not deck contents.
    for sid in ['token-fdf-128', 'token-ucs-093']:
        if sid in plan['registered_new_ids']:
            continue
        source = ROOT / 'recourse/爬虫' / manifest[sid]['file']
        dest = ROOT / 'recourse/数据库' / (sid + ('.svg' if sid == 'token-ucs-093' else source.suffix))
        if sid == 'token-ucs-093':
            # The local catalog records a missing/404 original. Code-native placeholder.
            dest.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="344" height="480" viewBox="0 0 344 480"><rect width="344" height="480" rx="14" fill="#142a44"/><rect x="10" y="10" width="324" height="460" rx="10" fill="none" stroke="#88bdde" stroke-width="3"/><path d="M142 125h60v55l45 80q8 18-8 22H105q-16-4-8-22l45-80z" fill="#4b95bf" stroke="#cfedf2" stroke-width="5"/><path d="M133 116h78v18h-78z" fill="#deb674"/><path d="M112 247h120l8 20H103z" fill="#8ad3b3"/><text x="172" y="57" text-anchor="middle" fill="#eefaff" font-size="27" font-family="sans-serif">蓬莱之药</text><text x="172" y="410" text-anchor="middle" fill="#aaccdd" font-size="22" font-family="sans-serif">道具 · 衍生物</text></svg>', encoding='utf-8')
        else:
            assert source.is_file()
            if not dest.exists(): shutil.copy2(source, dest)
            assert dest.read_bytes() == source.read_bytes()
        plan['cards'].append({'source_id': sid, 'card_id': sid, 'name': full_name(catalog[sid]),
          'identity': identity(catalog[sid]), 'source': source.relative_to(ROOT).as_posix(),
          'destination': dest.relative_to(ROOT).as_posix(), 'operation': 'copy', 'primary': True,
          'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
        plan['registered_new_ids'].append(sid)
    write(PLAN, plan)
    for row in plan['cards']:
        if not row['primary']:
            continue
        path = checked(row['destination'])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256']
        sid = row['source_id']; c = catalog[sid].copy()
        cid = row['card_id']; assert cid in EFFECTS
        main = c.get('active_ability', '').strip()
        leader = c.get('protagonist_ability', '').strip()
        if cid == 'character-rei-001':
            leader = '退治。若你颜色盘中的博丽灵梦的角色符卡数量不少于3，则该单位便具有疾行。'
        if cid == 'spell-rei-006':
            main = '若你刚好操控2个不同名称的自机单位，则该牌可以减少2个黄色来使用。你抓3张牌。'
        if cid == 'token-fdf-133':
            main = '吸血1。该单位不计战场格。'
            c.update(attack=2, defense=2, spirit=2)
        cost = {}; variable = ''
        for item in c['color_breakdown']:
            color = COLORS[item['color']]
            if item['count'] == 'X': variable = color
            else: cost[color] = int(item['count'])
        colors = list(cost)
        if variable and variable not in colors: colors.append(variable)
        token = c['card_type'] == 'token'
        kind = {'character': '自机' if leader else '单位', 'spell': '符卡', 'field': '结界', 'item': '道具', 'token': '单位'}[c['card_type']]
        if cid in ['token-fdf-128', 'token-ucs-093']: kind = '道具'; colors = ['蓝']
        text = main + ('\n自机能力：' + leader if leader else '')
        display = re.sub(r'（(?:当具有|具有|依然|其对应).*?）', '', text)
        d = {'格式版本': 1, '卡牌ID': cid, '名称': full_name(c), '类别': kind,
             '颜色': colors, '费用': cost, '图片': 'res://' + row['destination'],
             '完整说明': text or full_name(c), '能力文字': display,
             '来源': f"本次卡图核对 · 本地缓存 {sid} · {c['code']}",
             '来源编号': c['code'], '来源卡目ID': sid, '衍生物': token,
             '构筑资格': {'允许常规构筑': not token}, '关键词': KEYWORDS.get(cid, []),
             '能力绑定': [{'实现': 'precon', '名称': (leader if key in ['reimu_leader','marisa_recover','tenshi_ping','eirin_medicine','yukari_active','byakuren_leader','patch_chromatic'] else main), '参数': {'效果': key}} for key in EFFECTS[cid]]}
        if kind in ['单位', '自机']:
            d.update({'角色名': c['name'].strip(), '称号': c.get('title', ''),
                      '种族': [x for x in re.split(r'[·、/，, ]+', c.get('race', '') or '') if x and x != '/'],
                      '攻击力': int(c.get('attack') or 0), '血量': int(c.get('defense') or 0), '灵力': int(c.get('spirit') or 0)})
        if variable: d['可变费用'] = variable
        category = c.get('spell_category', '')
        d['高速'] = '高速' in category or cid in ['character-rei-017','character-fdf-070']
        d['角色约束'] = c.get('linked_character', '') or ''
        d['符卡类型'] = '·'.join(x for x in category.split('·') if x != '符卡')
        d['计时'] = int(c.get('time_count') or 0)
        if cid in ['spell-mar-002','spell-mar-004']: d['别名'] = ['恋符「极限火花」']
        write(ROOT / 'cards' / (cid + '.json'), d)
    db = ROOT / 'scripts/card_database.gd'
    source = db.read_text('utf-8-sig')
    found = re.search(r'^const IDS=(\[[^\]]*\])', source, re.M)
    ids = json.loads(found[1]); ids += [x for x in plan['registered_new_ids'] if x not in ids]
    source = source[:found.start(1)] + json.dumps(ids, ensure_ascii=False, separators=(',', ':')) + source[found.end(1):]
    db.write_text(source, encoding='utf-8')
    write(ROOT / 'data/test_precons.json', {'version': 1, 'decks': [x['deck'] for x in plan['precons']]})
    print(f'Wrote {len(plan["registered_new_ids"])} definitions and precon templates. Saved user decks unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['plan', 'archive', 'define'])
    args = parser.parse_args()
    {'plan': make_plan, 'archive': archive, 'define': define}[args.action]()
