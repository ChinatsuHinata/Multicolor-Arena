"""Create visible comparisons, package verified PSDs and optionally install art."""
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT', 'output/testmod-spacing')
PACK = ROOT / 'examples/testmod'
TARGET = ROOT / 'mod/testmod'
FONT = Path('C:/Windows/Fonts/msyh.ttc')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf8'))


def old_folder(identifier):
    old = ROOT / 'output/testmod-scarlet-moon'
    return old if (old / 'cards' / f'{identifier}.png').exists() else ROOT / 'output/testmod-typography-v5'


def text_comparison(report):
    # All sources are normalized to the native 1488px canvas first. Crops
    # retain the same magnification, rather than stretching text to fill a box.
    labels = [('chanting_youka', '普通单位选项：原版爱丽丝 / 修订前 / 修订后', 'character-fdf-112.jpg', (33, 1395, 1451, 1776)),
              ('visitor', '普通单位：原版八桥 / 修订前 / 修订后', 'character-fdn-042.jpg', (33, 1450, 1451, 1776)),
              ('dragon_jewel', '道具：原版妖魔书 / 修订前 / 修订后', '164.png', (21, 1645, 1466, 2020)),
              ('life_spring', '道具长文：原版道具 / 修订前 / 修订后', '164.png', (21, 1645, 1466, 2020))]
    canvas = Image.new('RGB', (1920, 1240), '#17202b')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(str(FONT), 24)
    for row, (identifier, label, reference, original_box) in enumerate(labels):
        y = row * 310
        draw.text((18, y + 8), label, font=font, fill='white')
        before = old_folder(identifier)
        old = next(r for r in load(before / 'render-report.json') if r['id'] == identifier)
        current = next(r for r in report if r['id'] == identifier)
        def box(r):
            x, top, w, h = r['bodyBox']
            return (x, top, x+w, top+h)
        specs = [(ROOT / 'recourse/数据库' / reference, original_box),
                 (before / 'cards' / f'{identifier}.png', box(old)),
                 (OUT / 'cards' / f'{identifier}.png', box(current))]
        for col, (path, crop) in enumerate(specs):
            image = Image.open(path).convert('RGB').resize((1488, 2079), Image.Resampling.LANCZOS)
            image = image.crop(tuple(round(v) for v in crop))
            image = image.resize((round(image.width * .43), round(image.height * .43)), Image.Resampling.LANCZOS)
            canvas.paste(image, (col * 640 + 12, y + 54))
    canvas.save(OUT / 'text-spacing-comparison.png')


def art_comparison():
    ids = ['hourai_branch', 'eternal_night', 'vlad_curse', 'scarlet_meister']
    canvas = Image.new('RGB', (1520, 1160), '#17202b')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(str(FONT), 24)
    titles = ['辉夜：玉枝 · 宝物近景', '辉夜：永夜归返 · 湖畔远景', '蕾米：诅咒 · 墓室仪式', '蕾米：绯红之主 · 动态弹幕']
    for i, identifier in enumerate(ids):
        x, y = (i % 2) * 760, (i // 2) * 580
        draw.text((x+14, y+12), titles[i], font=font, fill='white')
        image = Image.open(OUT / 'cards' / f'{identifier}.png').convert('RGB')
        image.thumbnail((736, 526), Image.Resampling.LANCZOS)
        canvas.paste(image, (x+12, y+50))
    canvas.save(OUT / 'character-spell-comparison.png')


def main():
    manifest = load(PACK / 'manifest.json')
    expected = {load(PACK/name)['卡牌ID'].split('/')[-1] for name in manifest['cards'] if not load(PACK/name)['图片'].startswith('res://')}
    report = load(OUT / 'render-report.json')
    typography = load(OUT / 'typography-validation.json')
    psds = load(OUT / 'psd-validation.json')
    assert {r['id'] for r in report} == {r['id'] for r in typography} == {r['id'] for r in psds} == expected
    assert all(r['native_spacing_verified'] and r['rules_exact'] and r['rules_within_panel'] for r in typography)
    assert all(r['mean_channel_difference'] < .5 for r in psds)
    snapshot = load(OUT / 'source-rules.sha256.json')
    assert all(digest(PACK/name) == value for name, value in snapshot.items()), 'source rules changed during the art revision'
    text_comparison(report)
    art_comparison()
    notes = '''PSD 制卡：原版文字间距校准

普通单位、道具：正文猫啃糖圆体，58.33333px，字距 -40，行距 58.33333px。
撤销旧流程 1.08 倍行距及每个 JSON 换行额外添加的 14px。
正文可用宽度按原 PSD 设为 1247px；道具首行按源模板下移 35px。
自机保留分隔线安全距离。字号、字距、行距均由 spacing-profile.json 的原 PSD 图层记录核对。
符卡、结界按四重結界 PSD：54.16667px，字距 -50，列距 65px。
标题字体和字号沿用原教学模板；关键词加粗、下划线及属性符号继续分层。

选择一项：参照普通单位爱丽丝 FDF-112，使用 ①②，选项及续行与正文左侧对齐，无额外段距。
卡牌 JSON、能力脚本和规则原文不变；编号仅为卡面排版转换。

辉夜：保留玉枝宝物近景，将永夜归返改为湖畔背身远景、逆转星空。
蕾米：保留绯红之主动态弹幕，将诅咒改为墓室侧坐、红线复活仪式。
芙兰两张插画保留。新插画由内置 imagegen 根据角色参照生成，提示词见 prompt-set.json。

cards/ 为全部 24 张新卡面；psd/ 为可编辑文字与独立插画、框体、符号、下划线分组的 PSD。
text-spacing-comparison.png：普通单位、道具原版 / 修改前 / 修改后同倍率对比。
character-spell-comparison.png：辉夜与蕾米两组符卡的画面差异。
comparison-gallery.html：全部卡牌与同类别原版参照逐张对比。
typography-validation.json：规则原文、原版字体与间距、实际字形边界、分隔线距离校验。
psd-validation.json：每份 PSD 保存后重新打开，核对文字层与 PNG 合成差异。
before-revision.zip：工作区示例与当前启用模组的修改前备份。

复现：powershell -File tools/build_testmod_spacing.ps1
同步到当前启用的工作区模组：powershell -File tools/build_testmod_spacing.ps1 -Install
准备步骤保留本目录 illustrations 中已确认的插画。
PSD 已通过 psd-tools 重新打开核验；本机没有 Photoshop，未在 Photoshop 内验证重排。
'''
    (OUT / '使用说明.txt').write_text(notes, encoding='utf8')
    gallery = OUT / 'comparison-gallery.html'
    value = gallery.read_text(encoding='utf8')
    extra = '<p>文字间距已按原 PSD 分类核对；选择一项参照普通单位爱丽丝。</p><p><a href="使用说明.txt">制作说明</a> · <a href="spacing-profile.json">原 PSD 参数</a></p><img src="text-spacing-comparison.png" alt="原版、修改前与修改后文字对比"><img src="character-spell-comparison.png" alt="辉夜和蕾米两组符卡差异">'
    value = value.replace('<h1>testmod · 正确模板重制逐张对照</h1>', '<h1>testmod · 原版文字间距与符卡构图修订</h1>'+extra)
    for row in report:
        identifier = row['id']
        value = value.replace(f'cards/{identifier}.png">原尺寸 PNG</a>', f'cards/{identifier}.png">原尺寸 PNG</a> · <a href="psd/{identifier}.psd">分层 PSD</a>')
    gallery.write_text(value, encoding='utf8')
    install = '--install' in sys.argv
    if install:
        # Refuse to overwrite any rules that diverged in the active mod.
        assert all(digest(TARGET/name) == value for name, value in snapshot.items()), 'active mod rules differ'
        for row in report:
            relative = Path('art') / f"{row['id']}.png"
            for target in [PACK, TARGET]:
                shutil.copy2(OUT / 'cards' / relative.name, target / relative)
                assert digest(OUT/'cards'/relative.name) == digest(target/relative)
    modzip = ROOT / 'output' / f'testmod-{manifest["version"]}-spacing.zip'
    with ZipFile(modzip, 'w', ZIP_DEFLATED) as archive:
        for source in sorted(PACK.rglob('*')):
            if source.is_file() and source.suffix not in ['.uid', '.import'] and not any(p.startswith('.') for p in source.relative_to(PACK).parts):
                relative = source.relative_to(PACK)
                replacement = OUT/'cards'/relative.name if relative.parts[0] == 'art' and source.stem in expected else source
                archive.write(replacement, relative)
    files = [p for directory in ['cards', 'psd', 'illustrations', 'layouts', 'comparisons', 'components'] for p in sorted((OUT/directory).glob('*')) if p.is_file()]
    files += [OUT/name for name in ['使用说明.txt','spacing-profile.json','source-rules.sha256.json','render-report.json','typography-validation.json','psd-validation.json','prompt-set.json','text-spacing-comparison.png','character-spell-comparison.png','comparison-gallery.html','overview.png']]
    assert all(path.is_file() for path in files)
    (OUT/'sha256.json').write_text(json.dumps({str(p.relative_to(OUT)).replace('\\','/'):digest(p) for p in files}, indent=2), encoding='utf8')
    bundle = ROOT/'output/testmod-spacing.zip'
    with ZipFile(bundle, 'w', ZIP_DEFLATED) as archive:
        for path in files+[OUT/'sha256.json']:
            archive.write(path, Path('testmod-spacing')/path.relative_to(OUT))
    print(f'PASS: {len(report)} PNGs and layered PSDs; rules unchanged; installed={install}; {modzip}; {bundle}')


if __name__ == '__main__':
    main()
