"""Package checked PSDs and PNGs, then refresh the workspace mod art."""
import hashlib
import json
import shutil
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/testmod-typography-v5'
PACK=ROOT/'examples/testmod'


def main():
    report=json.loads((OUT/'render-report.json').read_text(encoding='utf8'))
    typography=json.loads((OUT/'typography-validation.json').read_text(encoding='utf8'))
    psds=json.loads((OUT/'psd-validation.json').read_text(encoding='utf8'))
    assert len(report)==len(typography)==len(psds)==13
    assert {c['id'] for c in report}=={c['id'] for c in typography}=={c['id'] for c in psds}
    assert all(c['rules_exact'] and c['rules_within_panel'] and not c['unintended_font_fallback'] for c in typography)
    assert all(c['mean_channel_difference']<.5 for c in psds)
    assert sum(len(c['modifier_symbols']) for c in typography)==5
    assert {c['id'] for c in typography if c['modifier_symbols']}=={'utsuho','recitation','resonance','ship','superhuman'}
    snapshot=json.loads((OUT/'source-rules.sha256.json').read_text(encoding='utf8'))
    assert all(hashlib.sha256((PACK/name).read_bytes()).hexdigest()==digest for name,digest in snapshot.items())
    manifest=json.loads((PACK/'manifest.json').read_text(encoding='utf8'))
    version=manifest['version']
    notes=f'''核热与魔法 · 教学 PSD / 原版圣白莲对照修订 v5（testmod {version}）

模板来源：
D:/叶子游戏/模板/教学用 天才教师上白泽慧音.psd
D:/叶子游戏/模板/符卡 四重結界.psd
font-profile.json 记录源文件 SHA256、图层号、原文字体、字号、字距和字重。

本次修正：
1. 单位、自机和道具标题按教学单位模板使用演示镇魂行楷，最大75px，字距-5；引号按源PSD使用宋体。
   按教学模板标题的黑色外缘调整轮廓。超长标题适度缩小以留在标题框内。
2. 符卡和结界标题按四重結界PSD第40层使用華康金文體，最大100px，原生字距220，保留模板伪粗体。
   竖排按1.22em安排字位；同字体繁体字形替代已记录在各字体报告。
3. 原版圣白莲FDF-EX03与SOI-085用于观察攻防、灵力符号。
   +1/+1/+1 显示为黑底攻防胶囊「+1/+1」与原生轮廓的灵力印章「+1」。
   对复诵、共鸣、星莲之船和超人四张牌应用；灵乌路空的-X/-X/-X也使用对应下降符号。
   竖排属性符号随文本方向旋转，汉字连接词“与”保持直立。灵力印章轮廓直接提取教学PSD第79层，依原版圣白莲采用绿金色。
4. 修复X颜色值的字体分派，使用原模板的演示秋鸿楷，不再被转曲流程错误归入演示镇魂行楷。
5. 导出时逐个核对13张当前卡牌JSON与abilities.gd的校验值，保持卡面与当前规则一致。
   无前缀卡名使用日文书名号，の显示为ノ；灵乌路空的下降数值外没有额外括号。

文件：
cards/：13张全尺寸PNG。
psd/：13份分层PSD及重新打开后的预览。
layouts/：文字SVG、转曲SVG和字体解析报告。
components/：本次从模板提取的灵力轮廓和字体样张。
reference-comparison.png：原版圣白莲、v4、v5标题与属性符号对照。
comparison-gallery.html：13张牌与原卡逐张对照。
typography-validation.json：语义还原、文字和符号边界、字体和下划线检查。
psd-validation.json：13份PSD重新打开、文字层数量、文字运行长度与合成图差异检查。
source-rules.sha256.json：源规则文件校验值；sha256.json：交付文件校验值。

PSD编辑：
插画、框体、标题数值、正文、属性符号、关键词下划线分组。
属性符号的框体与符号数值文字分离，数值仍为可编辑文字层。
竖排文字按字定位，关键词下划线为独立层；修改文字时同步调整相关符号与下划线。
当前机器未安装Photoshop；已经用psd-tools保存、重新打开并核对合成图，未做Photoshop内部重排验证。
需要的字体为D:/叶子游戏/font中的字体，以及系统宋体和已有演示秋鸿楷。本包不分发字体。

复现：在项目根目录运行 powershell -File tools/build_testmod_v5.ps1
加 -Install 可在规则文件完全相同时备份并同步 D:/叶子游戏/testmod。
'''
    (OUT/'使用说明.txt').write_text(notes,encoding='utf8')
    backup=OUT/'workspace-mod-before.zip'
    if not backup.exists():
        with ZipFile(backup,'w',ZIP_DEFLATED) as z:
            z.write(PACK/'manifest.json','testmod/manifest.json')
            z.write(PACK/'README.txt','testmod/README.txt')
            for c in report:z.write(PACK/'art'/f"{c['id']}.png",f"testmod/art/{c['id']}.png")
    for c in report:shutil.copy2(OUT/'cards'/f"{c['id']}.png",PACK/'art'/f"{c['id']}.png")
    modzip=ROOT/f'output/testmod-{version}.zip'
    with ZipFile(modzip,'w',ZIP_DEFLATED) as z:
        for f in sorted(PACK.rglob('*')):
            if f.is_file() and f.suffix not in ('.import','.uid'):z.write(f,Path('testmod')/f.relative_to(PACK))
    files=[]
    for directory,pattern in [('psd','*.psd'),('psd','*.preview.png'),('cards','*.png'),('layouts','*.svg'),('layouts','*.fonts.json'),('comparisons','*.png'),('components','*.png')]:
        files.extend(sorted((OUT/directory).glob(pattern)))
    files.extend(OUT/name for name in ['使用说明.txt','comparison-gallery.html','overview.png','reference-comparison.png','font-profile.json','render-report.json','typography-validation.json','psd-validation.json','source-rules.sha256.json'])
    (OUT/'sha256.json').write_text(json.dumps({str(f.relative_to(OUT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},indent=2),encoding='utf8')
    bundle=ROOT/'output/testmod-typography-v5.zip'
    with ZipFile(bundle,'w',ZIP_DEFLATED,compresslevel=6) as z:
        for f in [*files,OUT/'sha256.json']:z.write(f,Path('testmod-typography-v5')/f.relative_to(OUT))
    print(f'13 checked cards; {bundle.stat().st_size:,} bytes; mod package {modzip}')


if __name__=='__main__':main()
