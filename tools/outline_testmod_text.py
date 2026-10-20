"""Resolve template fonts directly and outline SVG text; no OS font fallback."""
import argparse
import json
import os
from functools import lru_cache
from pathlib import Path
import xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen

ROOT=Path(__file__).resolve().parents[1]
DESIGN=ROOT/'output/testmod-design-v2'
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)
JINWEN_VARIANTS={**dict(zip('热莲诵鸣归戏乡莱红绯诅梦','熱蓮誦鳴歸戲鄉萊紅緋詛夢')),'·':'‧'}

@lru_cache(None)
def font(path):
    f=TTFont(path,fontNumber=0)
    return f,f.getBestCmap(),f.getGlyphSet()


def title_character(ch,cmap,glyphs):
    """A cmap entry can exist while its outline is empty in the B5 font."""
    def available(value):
        glyph=cmap.get(ord(value))
        if glyph is None:return False
        if not value.strip():return True
        pen=BoundsPen(glyphs);glyphs[glyph].draw(pen)
        return pen.bounds is not None
    if available(ch):return ch
    replacement=JINWEN_VARIANTS.get(ch)
    if replacement and available(replacement):return replacement
    raise ValueError(f'No visible native JinWen glyph for {ch!r}')

def names(path):
    try:
        f=TTFont(path,fontNumber=0,lazy=True)
        result={n.toUnicode() for n in f['name'].names if n.nameID in (1,4,6,16)}
        f.close()
        return result
    except Exception:
        return set()

def resolve_fonts():
    options={
        'SlideTownsoul-Regular': None,
        'DFJinWen-W3-WIN-BF': None,
        'MaoKenTangYuan-beta': DESIGN/'fonts/TangYuan/MaoKenTangYuan-beta0.12-20210702.ttf',
        'Slideqiuhong-Regular': DESIGN/'fonts/Slideqiuhong-Regular.ttf',
        'SimSun': Path('C:/Windows/Fonts/simsun.ttc'),
    }
    candidates=[]
    for directory in [DESIGN/'fonts',Path('C:/Windows/Fonts'),Path(os.environ.get('LOCALAPPDATA',''))/'Microsoft/Windows/Fonts',Path('D:/叶子游戏/font')]:
        if directory.is_dir():
            candidates.extend(p for p in directory.rglob('*') if p.suffix.lower() in ('.ttf','.otf','.ttc'))
    for p in candidates:
        for name in names(p):
            if name in options: options[name]=p
    return options

def metrics(options, output=None):
    result={}
    aliases={'body':'MaoKenTangYuan-beta','brush':'SlideTownsoul-Regular','title':'DFJinWen-W3-WIN-BF'}
    for key,name in aliases.items():
        f,cmap,gs=font(str(options[name] or options['Slideqiuhong-Regular']))
        units=f['head'].unitsPerEm
        result[key]={str(cp):f['hmtx'][glyph][0]/units for cp,glyph in cmap.items()}
        if key=='brush':
            for ch in '/「」﹁﹂':
                extra='Slideqiuhong-Regular' if ch=='/' else 'SimSun'
                ff,cc,_=font(str(options[extra]))
                if ord(ch) in cc: result[key][str(ord(ch))]=ff['hmtx'][cc[ord(ch)]][0]/ff['head'].unitsPerEm
    # Actual ink and vertical origins matter for display faces with overhangs.
    # A generic .85em baseline displaces the JinWen brackets and CJK glyphs.
    for key,name in [('brushInk','SlideTownsoul-Regular'),('titleInk','DFJinWen-W3-WIN-BF')]:
        f,cmap,gs=font(str(options[name])); units=f['head'].unitsPerEm
        result[key]={}
        characters=set(''.join(json.loads(p.read_text(encoding='utf8')).get('名称','') for p in (ROOT/'examples/testmod').glob('*.json')))
        characters.update('「」﹁﹂︵︶熱蓮誦鳴歸戲鄉萊紅緋詛夢ノ‧')
        for ch in characters:
            ff,cc,glyphs=f,cmap,gs
            actual=ch
            if key=='titleInk':
                try:actual=title_character(ch,cc,glyphs)
                except ValueError:continue
            if ord(ch) not in cc and key=='brushInk':ff,cc,glyphs=font(str(options['SimSun']))
            if ord(actual) not in cc:continue
            glyph=cc[ord(actual)];u=ff['head'].unitsPerEm
            pen=BoundsPen(glyphs);glyphs[glyph].draw(pen)
            bounds=pen.bounds or (0,0,0,0)
            xmin,ymin,xmax,ymax=bounds
            item={'bounds':[v/u for v in bounds],'advance':ff['hmtx'][glyph][0]/u}
            if 'vmtx' in ff:
                advance,top=ff['vmtx'][glyph]
                item.update(verticalAdvance=advance/u,verticalOrigin=(ymax+top)/u)
            result[key][ch]=item
    (output or DESIGN/'font-metrics.json').write_text(json.dumps(result),encoding='utf8')

def convert(source,output,options):
    tree=ET.parse(source)
    fallback=ROOT/'assets/fonts/NotoSansSC.ttf'
    used=set()
    missing=set()
    variants={}
    fallbacks=set()
    native_fallbacks={}
    for text_index,el in enumerate(list(tree.getroot().iter('{'+NS+'}text'))):
        s=el.text or ''
        family=el.get('font-family','')
        requested=('DFJinWen-W3-WIN-BF' if 'DFJinWen' in family else
                   'Slideqiuhong-Regular' if 'Slideqiuhong' in family else
                   'SlideTownsoul-Regular' if 'SlideTownsoul' in family else
                   'MaoKenTangYuan-beta' if 'MaoKen' in family else None)
        selected=options.get(requested) if requested else fallback
        if selected is None:
            missing.add(requested)
            selected=options['Slideqiuhong-Regular']
        selected=str(selected)
        used.add(selected)
        size=float(el.get('font-size','16'))
        spacing=float(el.get('letter-spacing','0'))
        x=float(el.get('x','0'));y=float(el.get('y','0'))
        glyphs=[];advance=0
        for ch in s:
            f,cmap,gs=font(selected)
            # This B5 font has these traditional glyphs but no simplified cmap
            # entries. Use its corresponding glyph, retaining one title face.
            if requested=='DFJinWen-W3-WIN-BF':
                replacement=title_character(ch,cmap,gs)
                if replacement!=ch:
                    variants[ch]=replacement;ch=replacement
            if ord(ch) not in cmap:
                native=('Slideqiuhong-Regular' if ch=='/' else 'SimSun') if requested=='SlideTownsoul-Regular' else None
                substitute=options.get(native) if native else fallback
                f,cmap,gs=font(str(substitute))
                if native: native_fallbacks[ch]=native
                else: fallbacks.add(ch)
                used.add(str(substitute))
            glyph=cmap.get(ord(ch),'.notdef')
            units=f['head'].unitsPerEm
            pen=SVGPathPen(gs)
            gs[glyph].draw(pen)
            scale=size/units
            glyphs.append((advance,scale,pen.getCommands()))
            advance+=f['hmtx'][glyph][0]*scale+spacing
        if glyphs: advance-=spacing
        if el.get('text-anchor')=='middle':x-=advance/2
        elif el.get('text-anchor')=='end':x-=advance
        el.tag='{'+NS+'}g'
        el.text=None
        el.set('data-text-id',str(text_index))
        for attr in ['x','y','font-family','font-size','text-anchor','letter-spacing']:
            el.attrib.pop(attr,None)
        # Stroke was specified in output pixels; transformed glyph paths need
        # a compensating stroke width to keep native label outlines intact.
        stroke=el.attrib.pop('stroke-width',None)
        weight=float(el.attrib.pop('data-embolden','0'))
        for offset,scale,d in glyphs:
            attrs={'d':d,'transform':f'translate({x+offset:.4f} {y:.4f}) scale({scale:.7f} {-scale:.7f})'}
            if weight and stroke:
                # One calibrated native faux-bold pass; keep its outer halo separate.
                bold=weight
                outer=attrs.copy()
                outer['stroke-width']=str((float(stroke or 0)+bold)/scale)
                ET.SubElement(el,'{'+NS+'}path',outer)
                attrs['stroke']=el.get('fill','#000')
                attrs['stroke-width']=str(bold/scale)
                attrs['stroke-linejoin']='round'
                ET.SubElement(el,'{'+NS+'}path',attrs)
                continue
            if stroke:attrs['stroke-width']=str(float(stroke)/scale)
            if weight:
                attrs['stroke']=el.get('fill','#000')
                attrs['stroke-width']=str(weight/scale)
                attrs['stroke-linejoin']='round'
            ET.SubElement(el,'{'+NS+'}path',attrs)
    tree.write(output,encoding='utf-8',xml_declaration=True)
    return {'used':sorted(used),'missing':sorted(missing),'same_font_variants':variants,'native_fallbacks':native_fallbacks,'fallback_glyphs':sorted(fallbacks)}

def main():
    p=argparse.ArgumentParser()
    p.add_argument('source',type=Path,nargs='?')
    p.add_argument('output',type=Path,nargs='?')
    p.add_argument('--metrics',action='store_true')
    p.add_argument('--metrics-output',type=Path)
    args=p.parse_args()
    options=resolve_fonts()
    if args.metrics:
        metrics(options,args.metrics_output)
        return
    result=convert(args.source,args.output,options)
    (args.output.with_suffix('.fonts.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')

if __name__=='__main__':main()
