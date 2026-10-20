"""Audit exported glyph caches against card definitions and actual UI geometry."""
import json
import hashlib
import os
import re
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/os.environ.get('TESTMOD_OUTPUT','output/testmod-typography-v4')
NS={'s':'http://www.w3.org/2000/svg'}
PUNCT=str.maketrans({'﹁':'「','﹂':'」','︻':'【','︼':'】','︵':'（','︶':'）','︒':'。','︐':'，','︓':'：','︔':'；'})

def normalize(s):
    return re.sub(r'\s+','',s.translate(PUNCT))


def semantic_rules(node):
    role=node.get('data-role')
    if role=='rules-symbol':
        return node.get('data-source-text','')
    if role=='rules':
        return (node.text or '') if node.text!='：' else ''
    return ''.join(semantic_rules(child) for child in node)

def main():
    report=json.loads((OUT/'render-report.json').read_text(encoding='utf8'))
    profile_path=OUT/'spacing-profile.json'
    profile=json.loads(profile_path.read_text(encoding='utf8')) if profile_path.exists() else None
    title_profile_path=OUT/'title-profile.json'
    title_profile=json.loads(title_profile_path.read_text(encoding='utf8')) if title_profile_path.exists() else None
    if title_profile:
        for entry in [*title_profile['fonts'].values(), *title_profile['templates'].values()]:
            path=Path(entry.get('path',entry.get('source')))
            assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],('title source changed',path)
    assert report and len({card['id'] for card in report})==len(report)
    result=[]
    for card in report:
        identifier=card['id']
        definition=json.loads((ROOT/'examples/testmod'/f'{identifier}.json').read_text(encoding='utf8'))
        records=json.loads((OUT/'layers'/identifier/'text-layers.json').read_text(encoding='utf8'))
        rules=[r for r in records if r['attrs'].get('data-role')=='rules']
        expected=re.sub(r'(自机能力|主要能力)：','',definition['能力文字'])
        expected=re.sub(r'(?m)^([1-9])[，,、.．]',lambda m:chr(0x2460+int(m[1])-1),expected)
        svg=ET.parse(OUT/'layouts'/f'{identifier}.text.svg').getroot()
        actual=semantic_rules(svg)
        assert normalize(expected)==normalize(actual),(identifier,'rules changed')
        x,y,w,h=card['bodyBox']
        for r in rules:
            assert r['left']>=x-1 and r['top']>=y-1,(identifier,'above/left of panel',r)
            assert r['left']+r['width']<=x+w+1 and r['top']+r['height']<=y+h+1,(identifier,'outside panel',r)
            size=float(r['attrs'].get('font-size',0))
            assert size<=card['bodySize'] and (size==card['bodySize'] or re.fullmatch(r'\d{2}',r['text'])),(identifier,'unexpected rules size',r)
            assert float(r['attrs'].get('data-embolden',0)) < 58.33333*.033
        title=[r for r in records if r['attrs'].get('data-role')=='title']
        assert title
        title_font='DFJinWen-W3-WIN-BF' if card['kind']=='spell' else 'SlideTownsoul-Regular'
        assert all(r['attrs']['font-family']==title_font for r in title)
        if card['kind']!='spell':assert all(float(r['attrs']['font-size'])<=75 for r in title)
        title_bounds=None
        if title_profile:
            assert all(r.get('nativeCache') and r['attrs'].get('data-title-calibration')=='native' and not r['attrs'].get('stroke') for r in title)
            expected_title=definition['名称'].replace('【','「').replace('】','」').replace('の','ノ')
            assert normalize(''.join(r['text'] for r in title))==normalize(expected_title),(identifier,'title text changed')
            if card['kind']=='spell':
                assert not any(r['text'] in ('（','）') for r in title),(identifier,'horizontal title punctuation')
                for r in title:
                    if r['text']=='-':
                        assert all(abs(a-b)<1e-6 for a,b in zip(r['transform'][:4],[0,1,-1,0])),(identifier,'unrotated Latin dash')
            if card['kind']!='spell':
                assert all(float(r['attrs']['font-size'])==title_profile['horizontal']['size'] for r in title)
            title_bounds=[min(r['left'] for r in title),min(r['top'] for r in title),
                          max(r['left']+r['width'] for r in title),max(r['top']+r['height'] for r in title)]
            assert all(Image.open(OUT/'layers'/identifier/r['nativeCache']['file']).getbbox() for r in title),(identifier,'invisible title glyph')
            region=(1716,37,1944,1455) if card['kind']=='spell' else (205,101,1313,242)
            assert title_bounds[0]>=region[0] and title_bounds[1]>=region[1] and title_bounds[2]<=region[2] and title_bounds[3]<=region[3],(identifier,'title outside capsule',title_bounds)
            if title_profile.get('preserve_non_title_pixels',True):
                current=np.asarray(Image.open(OUT/'cards'/f'{identifier}.png').convert('RGB'))
                before=np.asarray(Image.open(ROOT/title_profile['baseline_revision']/'cards'/f'{identifier}.png').convert('RGB'))
                changed=np.any(current!=before,axis=2)
                changed[region[1]:region[3],region[0]:region[2]]=False
                assert not changed.any(),(identifier,'non-title pixels changed',int(changed.sum()))
        if 'modifierTokens' in card:
            if card['kind']=='spell':
                assert all(float(r['attrs']['font-size'])<=100 and r['attrs'].get('data-native-tracking')=='220' for r in title)
            symbols=[n for n in svg.iter() if n.get('data-role')=='rules-symbol']
            assert [n.get('data-source-text') for n in symbols]==card['modifierTokens']
            assert all(n.get('data-symbol-style') in ['attack-health-and-spirit','token-attack-health-and-spirit'] for n in symbols)
            for symbol in symbols:
                parts=symbol.get('data-source-text').split('/')
                values=[n.text for n in symbol.iter() if n.get('data-role')=='symbol-value']
                joins=[n.text for n in symbol.iter() if n.get('data-role')=='symbol-join']
                token=symbol.get('data-symbol-style')=='token-attack-health-and-spirit'
                assert values==['/'.join(parts[:2]),parts[2]] and joins==([] if token else ['与']),(identifier,'incorrect symbol values')
            if card['kind']=='spell':
                for r in records:
                    if r['attrs'].get('data-role')=='symbol-join':
                        assert r['attrs'].get('data-upright')=='true'
                        assert all(abs(a-b)<1e-6 for a,b in zip(r['transform'][:4],[1,0,0,1])),(identifier,'rotated Chinese joiner')
            assert not any(re.search(r'[+-]?(?:\d+|X)/[+-]?(?:\d+|X)/[+-]?(?:\d+|X)|[+-](?:\d+|X)/[+-](?:\d+|X)',r['text']) for r in rules)
            symbol_report=json.loads((OUT/'layers'/identifier/'symbols.json').read_text(encoding='utf8'))
            assert len(symbol_report)==len(symbols)
            for symbol in symbol_report:
                box=Image.open(OUT/'layers'/identifier/symbol['file']).getbbox()
                assert box and box[0]>=x-1 and box[1]>=y-1 and box[2]<=x+w+1 and box[3]<=y+h+1,(identifier,'symbol outside panel',box)
        fonts=json.loads((OUT/'layouts'/f'{identifier}.fonts.json').read_text(encoding='utf8'))
        assert not fonts['missing'] and not fonts['fallback_glyphs'],(identifier,'unintended font substitution',fonts)
        underlines=[n for n in svg.findall('.//s:path',NS) if n.get('data-role')=='keyword-underline']
        if card['kind']=='spell':
            keywords=[r for r in rules if r['attrs'].get('data-keyword')=='true']
            for line in underlines:
                assert line.get('data-side')=='left'
                lx,ly,ly2=map(float,re.fullmatch(r'M([^ ]+) ([^V]+)V(.+)',line.get('d')).groups())
                adjacent=[r for r in keywords if abs(float(r['attrs']['x'])-lx)<40 and float(r['attrs']['x'])>lx and r['top']<ly2+4 and r['top']+r['height']>ly-4]
                assert adjacent,(identifier,'underline has no keyword on its right')
                assert all(lx<=r['left']-1 for r in adjacent),(identifier,'line intersects glyph')
        separator_gap=None
        if card.get('paragraphGap') is not None:
            rule_lines=[n for n in svg.iter() if n.get('data-role')=='rules-line']
            baselines=[float(n.get('data-baseline')) for n in rule_lines]
            assert all(abs(b-a-card['leading'])<.001 for a,b in zip(baselines,baselines[1:])),(identifier,'incorrect line/paragraph spacing')
            assert all(abs(float(r['attrs']['x'])-card['rulesLeft'])<.001 for r in rules if r['text']!='：' and not r['attrs'].get('data-keyword') and any(r['text'].startswith(x) for x in '①②③④⑤⑥⑦⑧⑨')),(identifier,'choice indentation')
        if profile:
            native=next(t for t in profile['templates'] if t['kind']==card['kind'])['styles'][0]
            assert card['bodySize']==native['FontSize'] and card['tracking']==native['Tracking'] and card['leading']==native['Leading'],(identifier,'native spacing mismatch')
            for r in rules:
                size=float(r['attrs']['font-size'])
                assert abs(float(r['attrs']['letter-spacing'])-size*native['Tracking']/1000)<.00001,(identifier,'incorrect glyph tracking')
        if definition['类别']=='自机':
            # The leader separator's actual raster ends at panel y + 33.
            separator_gap=min(r['top'] for r in rules)-(y+33)
            assert separator_gap>=24,(identifier,'separator overlap',separator_gap)
        assert Image.open(OUT/'cards'/f'{identifier}.png').size==tuple(card['dimensions'])
        result.append({'id':identifier,'rules_exact':True,'rules_within_panel':True,
            'title_font':title_font,'unintended_font_fallback':False,
            'keyword_underline_count':len(underlines),'vertical_underline_side':'left' if card['kind']=='spell' else None,
            'separator_clearance_px':separator_gap,'modifier_symbols':card.get('modifierTokens',[]),
            'native_spacing_verified':bool(profile),'font_size_px':card['bodySize'],'tracking':card['tracking'],
            'line_advance_px':card.get('leading'),'paragraph_gap_px':card.get('paragraphGap'),
            'first_ink_clearance_px':min(r['top'] for r in rules)-y,
            'last_ink_clearance_px':y+h-max(r['top']+r['height'] for r in rules),
            'choice_reference':card.get('choiceReference')})
        if title_profile:
            result[-1].update(title_native_styles_verified=True,title_bounds=title_bounds,
                              non_title_pixels_unchanged=True if title_profile.get('preserve_non_title_pixels',True) else None)
    (OUT/'typography-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    print(f'PASS: {len(result)} cards; exact rules, native faces, panel bounds, left underlines, separator clearance.')

if __name__=='__main__':main()
