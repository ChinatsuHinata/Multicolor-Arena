"""Package the checked typography revision and refresh workspace mod images."""
import hashlib
import json
import shutil
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'output/testmod-typography-v4'
PACK = ROOT/'examples/testmod'


def main():
    report = json.loads((OUT/'render-report.json').read_text(encoding='utf8'))
    validation = json.loads((OUT/'psd-validation.json').read_text(encoding='utf8'))
    typography = json.loads((OUT/'typography-validation.json').read_text(encoding='utf8'))
    assert {c['id'] for c in report} == {c['id'] for c in validation}
    assert {c['id'] for c in report} == {c['id'] for c in typography}
    assert all(c['rules_exact'] and c['rules_within_panel'] and not c['unintended_font_fallback'] for c in typography)
    assert len(report) == 13
    notes = '''核热与魔法 · 13张卡面字体排版修订 v4 / testmod 1.0.4

本轮修改：
正文采用用户提供的猫啃糖圆体，字号58.33333，字距-40，按原版PSD使用正常字重，无额外描边。
横向卡名使用原模板的演示镇魂行楷与75px字号（长标题仅为适应框宽缩小），字距-5；符卡卡名使用華康金文體。
括号按原PSD使用宋体，属性斜线使用演示秋鸿楷；消除Noto替代字体造成的卡名和数值字形不一致。
依据原PSD缓存字形校准符卡卡名与关键词粗细，减少额外膨胀；正文保持正常字重。
PSD关键词只保留原生FauxBold，取消叠加的同色文字描边，避免编辑时重复加粗。
竖排关键词下划线统一位于文字左侧。
自机正文首行下移，分割花纹与正文实际字形间保留至少24px空隙；普通单位同步增加正文上边距。
13张牌文已逐字与卡牌定义核对，正文边界、关键词和下划线方向已检查。

文件：
psd/：13张分层PSD。插画、框体、卡名数值、正文、关键词下划线分别组织。
cards/：对应全尺寸PNG。
layouts/：含文字的SVG排版源，以及转曲SVG。
comparisons/：修订卡面与数据库原卡的逐张对照。
comparison-gallery.html：对照索引。

PSD编辑说明：
文字保留Type图层；横排按文字段分层，竖排按字定位。
关键词下划线是独立图层，移动或改写关键词时需要同步调整，竖排为左侧线。
文字缓存及合成图已经保存后重新打开核对；当前电脑未安装Photoshop，未做Photoshop内重新排字测试。
继续编辑文字需使用原字体：猫啃糖圆体、演示镇魂行楷、華康金文體、宋体、演示秋鸿楷。
原字体位于 D:/叶子游戏/font；本包未附字体文件。
'''
    (OUT/'使用说明.txt').write_text(notes,encoding='utf8')
    backup=OUT/'workspace-mod-before.zip'
    if not backup.exists():
        with ZipFile(backup,'w',ZIP_DEFLATED) as z:
            z.write(PACK/'manifest.json','testmod/manifest.json')
            for card in report:
                z.write(PACK/'art'/f"{card['id']}.png",f"testmod/art/{card['id']}.png")
    for card in report:
        shutil.copy2(OUT/'cards'/f"{card['id']}.png",PACK/'art'/f"{card['id']}.png")
    manifest=json.loads((PACK/'manifest.json').read_text(encoding='utf8'))
    manifest['version']='1.0.4'
    (PACK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    with ZipFile(ROOT/'output/testmod-1.0.4.zip','w',ZIP_DEFLATED) as z:
        for f in sorted(PACK.rglob('*')):
            if f.is_file() and f.suffix not in ('.import','.uid'):
                z.write(f,Path('testmod')/f.relative_to(PACK))
    deliverables=[]
    for directory,pattern in [('psd','*.psd'),('cards','*.png'),('layouts','*.svg'),('layouts','*.fonts.json'),('comparisons','*.png')]:
        deliverables.extend(sorted((OUT/directory).glob(pattern)))
    deliverables.extend(OUT/name for name in ['使用说明.txt','comparison-gallery.html','overview.png','typography-detail.png','font-profile.json','render-report.json','typography-validation.json','psd-validation.json'])
    hashes={str(f.relative_to(OUT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in deliverables}
    (OUT/'sha256.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2),encoding='utf8')
    bundle=ROOT/'output/testmod-typography-v4.zip'
    with ZipFile(bundle,'w',ZIP_DEFLATED,compresslevel=6) as z:
        for f in [*deliverables,OUT/'sha256.json']:
            z.write(f,Path('testmod-typography-v4')/f.relative_to(OUT))
    print(f'13 cards packaged: {bundle}; {bundle.stat().st_size:,} bytes')


if __name__=='__main__':
    main()
