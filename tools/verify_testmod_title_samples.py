"""Compare the actual source PSD's cached glyphs with same-text outlines."""
import json
import os
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape

import numpy as np
from PIL import Image
from fontTools.pens.boundsPen import BoundsPen
from psd_tools import PSDImage

from outline_testmod_text import convert, font, resolve_fonts

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT', 'output/testmod-titles')


def main():
    profile = json.loads((OUT/'title-profile.json').read_text(encoding='utf8'))
    directory = OUT/'title-samples'
    directory.mkdir(exist_ok=True)
    options = resolve_fonts()
    node = Path(os.environ.get('USERPROFILE', 'C:/Users/Lenovo'))/'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
    results = []
    for kind in ['unit', 'spell']:
        template = profile['templates'][kind]
        source = PSDImage.open(template['source'])
        layer = list(source.descendants())[template['titles'][0]['layer']]
        text = layer.text.strip('\r')
        if kind == 'unit':
            body = f'<text x="30" y="100" font-size="75" font-family="SlideTownsoul-Regular" letter-spacing="-.375" fill="white">{escape(text)}</text>'
        else:
            f,cmap,gs = font(str(options['DFJinWen-W3-WIN-BF']))
            units = f['head'].unitsPerEm
            body,at = '',30.
            for ch in text:
                glyph = cmap[ord(ch)]
                pen = BoundsPen(gs)
                gs[glyph].draw(pen)
                advance,top = f['vmtx'][glyph]
                origin = (pen.bounds[3]+top)/units*100
                body += f'<text x="150" y="{at+origin}" text-anchor="middle" font-size="100" font-family="DFJinWen-W3-WIN-BF" fill="white" data-embolden="3">{escape(ch)}</text>'
                at += advance/units*100+22
        svg = directory/f'{kind}.text.svg'
        curves = directory/f'{kind}.svg'
        target = directory/f'{kind}.png'
        svg.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="450" height="1450">'+body+'</svg>', encoding='utf8')
        convert(svg, curves, options)
        subprocess.run([str(node), '-e', "require('sharp')(process.argv[1]).trim().png().toFile(process.argv[2]).catch(e=>{console.error(e);process.exit(1)})", str(curves), str(target)], check=True)
        cached = layer.topil().convert('RGBA')
        cached.save(directory/f'{kind}.source.png')
        a = np.asarray(cached)[:,:,3]>127
        b = np.asarray(Image.open(target).convert('RGBA'))[:,:,3]>127
        h,w = max(a.shape[0],b.shape[0])+16,max(a.shape[1],b.shape[1])+16
        aa = np.zeros((h,w),bool)
        aa[8:8+a.shape[0],8:8+a.shape[1]] = a
        best,shift = 0.,None
        for dy in range(-4,5):
            for dx in range(-4,5):
                bb = np.zeros((h,w),bool)
                bb[8+dy:8+dy+b.shape[0],8+dx:8+dx+b.shape[1]] = b
                overlap = float(np.logical_and(aa,bb).sum()/np.logical_or(aa,bb).sum())
                if overlap>best:
                    best,shift = overlap,[dx,dy]
        threshold = .93 if kind=='unit' else .90
        assert best>=threshold, (kind,'source glyph mismatch',best)
        results.append({'kind':kind,'text':text,'source_layer':template['titles'][0]['layer'],
                        'source_sha256':template['sha256'],'source_cache_size':list(cached.size),
                        'outline_size':[b.shape[1],b.shape[0]],'alpha_mask_iou':best,
                        'alignment_offset_px':shift,'threshold':threshold,'passed':True})
    (OUT/'title-glyph-validation.json').write_text(json.dumps(results,ensure_ascii=False,indent=2), encoding='utf8')
    print('PASS: same-text native PSD glyph overlap: '+', '.join(f"{r['kind']} {r['alpha_mask_iou']:.3%}" for r in results), flush=True)


if __name__=='__main__':
    main()
