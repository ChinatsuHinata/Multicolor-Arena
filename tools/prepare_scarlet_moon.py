"""Build the user-authored Scarlet Moon expansion definitions without touching old cards."""
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'examples/testmod'

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf8')

def main():
    backup = ROOT / 'output/testmod-before-scarlet-moon.zip'
    if not backup.exists():
        with ZipFile(backup, 'w', ZIP_DEFLATED) as archive:
            for path in (ROOT / 'mod/testmod').rglob('*'):
                if path.is_file() and path.suffix not in ['.uid', '.import']:
                    archive.write(path, path.relative_to(ROOT / 'mod/testmod'))
    manifest = json.loads((PACK / 'manifest.json').read_text(encoding='utf8'))
    definitions = [
        ('forbidden_game', '禁忌「被禁止的游戏」', '符卡', ['红','黄'], {'红':4,'黄':2}, '目标你操控的吸血鬼与另一个对手操控的目标单位进行一次战斗判定。本回合中，你可以从你墓地使用该牌且以此法使用该牌时不需要支付颜色值。', ['forbidden_game'], '芙兰朵露', False, '', [], 0),
        ('forbidden_fruits', '禁忌「Forbidden Fruits」（禁果）', '符卡', ['黄','红'], {'黄':2,'红':2}, '你抓3张牌，然后选择目标吸血鬼自机单位，如果描述中有能触发的自机能力，则该能力触发3次。（不论其是否是你的自机）', ['forbidden_fruits'], '芙兰朵露', False, '', [], 0),
        ('vlad_curse', '诅咒「弗拉德·特佩斯的诅咒」', '符卡', ['红','黑'], {'红':1,'黑':1}, '计时3。\n若「蕾米莉亚」是你套牌自机，该牌在你墓地中有「蕾米莉亚」时也能使用。\n选择目标你墓地中的吸血鬼单位牌，将其放进你的战场。若该牌离开战场，牺牲该单位。', ['vlad_curse','curse_permission'], '蕾米莉亚', False, '时符角色符卡', [], 3),
        ('scarlet_meister', '红符「Scarlet Meister」（绯红之主）', '符卡', ['红','黑'], {'红':4,'黑':4}, '该牌对任意目标造成6点伤害，你创造等同于该牌造成伤害数量的红黑双色的1/1的不计战场格的蝙蝠衍生物，本回合中你操控的单位获得疾行。', ['scarlet_meister'], '蕾米莉亚', True, '', [], 0),
        ('chanting_youka', '「诵经的妖怪」', '单位', ['黄','绿'], {'黄':2,'绿':2}, '该单位进战场时，选择目标你操控其他的黄绿双色单位，选择一项：\n1，放置两个+1/+1/+1指示物。\n2，将其移回拥有者手上，你抓两张牌。', ['chanting_youka'], '', False, '', [], 0),
        ('hourai_branch', '神宝「蓬莱的玉枝　-梦色之乡-」', '符卡', ['黑'], {'黑':2}, '支援，计时3。你使用的道具牌具有极彩。\n你的准备阶段开始时，你可以从你的牌库中搜寻一张道具牌，将其置于你的手上，然后将你牌库洗牌。', ['hourai_search','hourai_chromatic'], '蓬莱山辉夜', False, '时符角色符卡', ['支援'], 3),
        ('eternal_night', '「永夜归返　-寅之刻-」', '符卡', ['蓝'], {'蓝':1}, '支援，该牌只能于你的准备阶段中使用。抓一张牌，获得5点生命。然后结束本回合。', ['eternal_night','night_timing'], '蓬莱山辉夜', True, '', ['支援'], 0),
    ]
    for key, name, color, cost, effect in [
        ('dragon_jewel','耀眼的龙玉','蓝',1,'目标玩家磨一张牌'),
        ('buddha_diamond','佛体的金刚石','黄',2,'获得2点生命'),
        ('salamander_shield','火蜥蜴之盾','红',3,'对任意目标造成3点伤害'),
        ('life_spring','无限的生命之泉','绿',4,'你可以移除你的牌库顶牌，本回合中你可以减少任意2点颜色值来使用这些牌'),
    ]:
        rules=f'你获得一个额外的准备阶段。\n你的准备阶段开始时，{effect}。\n你的结束阶段开始时，该牌对你造成3点伤害。\n你只能操控一张该名称的道具。'
        definitions.append((key,'「月之神宝-'+name+'」','道具',[color],{color:cost},rules,['treasure_extra','treasure_prepare','treasure_end'],'',False,'',['唯一'],0))
    for key,name,kind,colors,cost,rules,abilities,character,fast,spell_type,words,timer in definitions:
        card={'格式版本':1,'卡牌ID':'testmod/'+key,'名称':name,'类别':kind,'颜色':colors,'费用':cost,'图片':'art/'+key+'.png','完整说明':rules,'能力文字':rules,'来源':'testmod · 用户牌文；imagegen 原创 AI 插画；沿用现有 PSD 卡面模板','构筑资格':{'允许常规构筑':True},'关键词':words,'能力绑定':[{'实现':'mod','实例键':'ability_'+str(i),'参数':{'能力':'testmod/'+ability}} for i,ability in enumerate(abilities)],'高速':fast,'角色约束':character,'符卡类型':spell_type or ('角色高速符卡' if fast else '角色符卡') if kind=='符卡' else '', '计时':timer,'角色名':'诵经的妖怪' if kind=='单位' else '', '称号':'','种族':['妖怪'] if kind=='单位' else [],'攻击力':1 if kind=='单位' else 0,'血量':6 if kind=='单位' else 0,'灵力':1 if kind=='单位' else 0}
        write(PACK/(key+'.json'),card)
        if key+'.json' not in manifest['cards']:manifest['cards'].append(key+'.json')
    bat=json.loads((ROOT/'cards/token-kmo-027.json').read_text(encoding='utf8'))
    bat.update({'卡牌ID':'testmod/scarlet_bat','名称':'「绯红蝙蝠」','颜色':['红','黑'],'关键词':['不占战场格'],'完整说明':'该单位不计入战场格。','能力文字':'该单位不计入战场格。','图片':'res://recourse/数据库/token-kmo-027.jpg','来源':'testmod · 红黑1/1蝙蝠，灵力沿用原版蝙蝠衍生物的1。'})
    write(PACK/'scarlet_bat.json',bat)
    if 'scarlet_bat.json' not in manifest['cards']:manifest['cards'].append('scarlet_bat.json')
    specs={
        'forbidden_game':('spell',['stack'],{}), 'forbidden_fruits':('spell',['stack'],{}),
        'vlad_curse':('spell',['stack'],{}), 'scarlet_meister':('spell',['stack'],{}),
        'curse_permission':('static',['hand','grave','exile'],{}),
        'chanting_youka':('triggered',['field'],{'events':['self_enter'],'forced':'empty_event'}),
        'treasure_extra':('static',['field'],{}),
        'treasure_prepare':('triggered',['field'],{'events':['phase'],'forced':'empty_event'}),
        'treasure_end':('triggered',['field'],{'events':['phase'],'forced':'empty_event'}),
        'hourai_search':('triggered',['field'],{'events':['phase'],'optional':True,'forced':'empty_event'}),
        'hourai_chromatic':('static',['field'],{}), 'eternal_night':('spell',['stack'],{}),
        'night_timing':('static',['hand','grave','exile'],{}),
    }
    texts={'forbidden_game':'吸血鬼与对手单位进行战斗判定，本回合可从墓地免费使用该牌。','forbidden_fruits':'抓3张牌，然后令目标吸血鬼的可触发自机能力触发3次。','vlad_curse':'计时3，复活墓地目标吸血鬼；此时符离场时牺牲该单位。','scarlet_meister':'对任意目标造成6点伤害，按实际伤害创造蝙蝠，本回合己方单位获得疾行。','chanting_youka':'目标其他黄绿单位放两个三维指示物，或移回手牌并抓两张。','treasure_prepare':'准备阶段开始时，发动月之神宝的效果。','treasure_end':'自己的结束阶段开始时，该道具对你造成3点伤害。','hourai_search':'准备阶段开始时，可以搜寻一张道具牌入手并洗牌。'}
    texts.update({'curse_permission':'套牌自机为蕾米莉亚且墓地有蕾米莉亚时，满足本牌的角色条件。','treasure_extra':'你获得一个额外的准备阶段。','hourai_chromatic':'你使用的道具牌具有极彩。','eternal_night':'抓一张牌，获得5点生命，然后结束本回合。','night_timing':'支援。该牌只能于你的准备阶段中使用。'})
    for key,(kind,zones,extra) in specs.items():
        manifest['abilities'][key]={'script':'scarlet_moon.gd','kind':kind,'role':'main','zones':zones,'text':texts.get(key,key),**({'optional':False} if kind=='triggered' else {}),**extra}
    manifest.update({'version':'1.1.0','api':4,'name':'核热、魔法与绯红永夜 · testmod'})
    write(PACK/'manifest.json',manifest)
    print('Prepared 11 playable cards and one non-constructible bat token; testmod 1.1.0, API 4.')

if __name__=='__main__':main()
