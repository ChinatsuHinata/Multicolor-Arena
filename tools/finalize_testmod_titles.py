"""Package verified title corrections and a same-scale source/before/after view."""
import json
import os
import shutil
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageFont
from prepare_testmod_titles import digest

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT', 'output/testmod-titles')
BASE = ROOT / 'output/testmod-spacing'
PACK = ROOT / 'examples/testmod'


def load(path):
    return json.loads(path.read_text(encoding='utf8'))


def comparisons(report):
    samples = ['byakuren', 'visitor', 'dragon_jewel', 'blade', 'hourai_branch']
    canvas = Image.new('RGB', (1800, 1080), '#17202b')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 26)
    small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 21)
    for col, label in enumerate(['原卡参考（同倍率）', '原工作流', '修正后工作流']):
        draw.text((col*600+20, 16), label, font=font, fill='white')
    for row, identifier in enumerate(samples):
        card = next(c for c in report if c['id'] == identifier)
        y = 70 + row*190
        draw.text((20, y), card['name'], font=small, fill='#cbdcec')
        sources = [ROOT/'recourse/数据库'/card['reference'], BASE/'cards'/f'{identifier}.png', OUT/'cards'/f'{identifier}.png']
        for col, source in enumerate(sources):
            image = Image.open(source).convert('RGB')
            if card['kind'] == 'spell':
                if col == 0:
                    image = image.rotate(90, expand=True)
                image = image.resize((2079, 1488), Image.Resampling.LANCZOS)
                image = image.crop((1716, 37, 1944, 1455)).rotate(90, expand=True)
                # The same .4 scale in every column; do not stretch titles.
                scale = .4
            else:
                image = image.resize((1488, 2079), Image.Resampling.LANCZOS).crop((205, 101, 1313, 242))
                scale = .5
            image = image.resize((round(image.width*scale), round(image.height*scale)), Image.Resampling.LANCZOS)
            canvas.paste(image, (col*600+18, y+45))
    draw.text((20, 1040), 'PSD 保留原始字形透明度与原生外发光；未在 Photoshop 内验证重新排版。', font=small, fill='#b5c9da')
    canvas.save(OUT/'title-comparison.png')


def main():
    report = load(OUT/'render-report.json')
    typography = load(OUT/'typography-validation.json')
    psds = load(OUT/'psd-validation.json')
    glyphs = load(OUT/'title-glyph-validation.json')
    manifest = load(PACK/'manifest.json')
    expected = {load(PACK/name)['卡牌ID'].split('/')[-1] for name in manifest['cards'] if not load(PACK/name)['图片'].startswith('res://')}
    assert {r['id'] for r in report} == {r['id'] for r in typography} == {r['id'] for r in psds} == expected
    assert all(r['rules_exact'] and r['native_spacing_verified'] and r['title_native_styles_verified'] and r['non_title_pixels_unchanged'] for r in typography)
    assert all(r['title_raw_caches_exact'] and r['source_title_effects_exact'] for r in psds)
    assert len(glyphs)==2 and all(r['passed'] for r in glyphs)
    snapshot = load(OUT/'source-rules.sha256.json')
    assert all(digest(PACK/name) == value for name, value in snapshot.items()), 'card definitions changed'
    comparisons(report)
    notes = '''PSD 制卡：标题字体与原卡呈现校准

横排标题：演示镇魂行楷 75px、字距 -5；引号按原 PSD 使用宋体。
按字形实际边界居中，长标题只收窄横向宽度，保持字高。
恢复教学 PSD 的深色外发光（10px、75% 不透明度、50% 扩展），取消旧硬描边。
道具沿用同一横排标题呈现；两类模板的字体与标点设置分别记录。

符卡／结界：华康金文体，最大 100px、字距 220，保留原模板伪粗体。
使用字体 vmtx 的竖排原点与前进量，修正括号及各字的摆放；英文串旋转并应用同样的字距。
白色外发光沿用四重結界 PSD（10px、100% 不透明度），取消旧白色硬描边。
缺少简体编码的字继续使用同字体繁体字形，映射记录在 layouts/*.fonts.json。
有编码但无轮廓的“梦”和间隔点分别使用同字体的“夢”和“‧”，避免静默漏字；竖排圆括号和短横线一并校正方向。

PSD 标题缓存只存字形，不烘焙外发光；原生图层样式直接复制自源 PSD。
字形 alpha 写入透明通道，避免用矩形像素蒙版影响原生文字外发光。
PSD 保存后逐层核验字形缓存、原生样式与文本；合并预览单独保存。
psd-tools 不支持外发光合成，本版未做 Photoshop 内重新排版／渲染验证；PNG 外发光为参数近似。

24 张卡的非标题区域逐像素保持与 testmod-spacing 一致；牌文、插画和能力脚本不变。
title-comparison.png：原卡参考／原工作流／修正后工作流，同倍率展示。
title-profile.json：源 PSD 标题图层、字号、字距、字体文件哈希与外发光证据。
title-glyph-validation.json：源 PSD 同文标题的字形掩模与新流程轮廓重合度校验。
typography-validation.json：正文、边界、非标题像素与标题设置校验。
psd-validation.json：可编辑文字层、透明度、原生图层样式和合并预览校验。
before-revision.zip：修改前工作区示例与启用模组的备份。

复现：powershell -File tools/build_testmod_titles.ps1
同步到当前工作区模组：powershell -File tools/build_testmod_titles.ps1 -Install
工作流说明：docs/PSD制卡工作流.md
'''
    (OUT/'使用说明.txt').write_text(notes, encoding='utf8')
    gallery = OUT/'comparison-gallery.html'
    value = gallery.read_text(encoding='utf8')
    value = value.replace('<h1>testmod · 正确模板重制逐张对照</h1>', '<h1>testmod · 标题字体与原卡呈现校准</h1><p><a href="使用说明.txt">制作说明</a> · <a href="title-profile.json">源 PSD 标题参数</a></p><img src="title-comparison.png" alt="原卡、原工作流与修正后标题对比">')
    for row in report:
        identifier = row['id']
        value = value.replace(f'cards/{identifier}.png">原尺寸 PNG</a>', f'cards/{identifier}.png">原尺寸 PNG</a> · <a href="psd/{identifier}.psd">分层 PSD</a>')
    gallery.write_text(value, encoding='utf8')
    install = '--install' in sys.argv
    if install:
        active = ROOT/'mod/testmod'
        assert all(digest(active/name) == value for name, value in snapshot.items()), 'active mod definitions differ'
        for row in report:
            relative = Path('art')/f"{row['id']}.png"
            for target in [PACK, active]:
                shutil.copy2(OUT/'cards'/relative.name, target/relative)
                assert digest(OUT/'cards'/relative.name) == digest(target/relative)
    modzip = ROOT/'output'/f'testmod-{manifest["version"]}-titles.zip'
    with ZipFile(modzip, 'w', ZIP_DEFLATED, compresslevel=3) as archive:
        for source in sorted(PACK.rglob('*')):
            if source.is_file() and source.suffix not in ['.uid', '.import'] and not any(p.startswith('.') for p in source.relative_to(PACK).parts):
                relative = source.relative_to(PACK)
                replacement = OUT/'cards'/relative.name if relative.parts[0] == 'art' and source.stem in expected else source
                archive.write(replacement, relative)
    files = [p for directory in ['cards', 'psd', 'comparisons'] for p in sorted((OUT/directory).glob('*')) if p.is_file() and not p.name.endswith('.preview.png')]
    files += sorted((OUT/'layouts').glob('*.fonts.json'))
    files += [OUT/name for name in ['使用说明.txt','title-profile.json','title-glyph-validation.json','spacing-profile.json','source-rules.sha256.json','render-report.json','typography-validation.json','psd-validation.json','title-comparison.png','comparison-gallery.html','overview.png']]
    (OUT/'sha256.json').write_text(json.dumps({str(p.relative_to(OUT)).replace('\\','/'):digest(p) for p in files}, indent=2), encoding='utf8')
    bundle = ROOT/'output/testmod-titles.zip'
    with ZipFile(bundle, 'w', ZIP_DEFLATED, compresslevel=3) as archive:
        for source in files+[OUT/'sha256.json']:
            archive.write(source, Path('testmod-titles')/source.relative_to(OUT))
    print(f'PASS: {len(report)} title revisions, native PSD title caches/effects, unchanged non-title pixels; installed={install}; {modzip}; {bundle}', flush=True)


if __name__ == '__main__':
    main()
