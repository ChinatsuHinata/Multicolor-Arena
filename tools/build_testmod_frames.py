"""Build transparent card frames from extracted PSD pixels, without opening PSDs."""
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageColor, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT', 'output/testmod-frames')
TEMPLATES = ROOT / 'output/testmod-design-v2/templates'
MAIN = {'红':'#ff0000', '蓝':'#392ec8', '绿':'#00d21e', '黄':'#ffe600', '黑':'#3a3a3a'}
SINGLE = {'红':['#ff2a1a','#c8322c'], '蓝':['#1fa8d8','#3a5cc0'],
          '绿':['#00e01e','#00a896'], '黄':['#ffe600','#ffb83a'], '黑':['#8a8a8a','#1e1e1e']}


def gradient(length, stops, scale=1):
    t = np.clip((np.linspace(0, 1, length, dtype=np.float32)-(1-scale)/2)/scale, 0, 1)
    at = t*(len(stops)-1)
    index = np.minimum(at.astype(int), len(stops)-2)
    fraction = (at-index)[:, None]
    return stops[index]*(1-fraction)+stops[index+1]*fraction


def overlay(layer, stops, op, scale=1, horizontal=False):
    result = layer.copy()
    h, w = layer.shape[:2]
    grad = gradient(w if horizontal else h, stops, scale)
    grad = grad[None, ::-1, :] if horizontal else grad[:, None, :]
    result[:,:,:3] = layer[:,:,:3]*(1-op)+grad*op
    return result


def over(dst, src, x, y):
    h, w = src.shape[:2]
    left, top = max(0, x), max(0, y)
    right, bottom = min(dst.shape[1], x+w), min(dst.shape[0], y+h)
    if left >= right or top >= bottom:
        return
    source = src[top-y:bottom-y, left-x:right-x]
    target = dst[top:bottom, left:right]
    alpha, base_alpha = source[:,:,3:]/255, target[:,:,3:]/255
    combined = alpha+base_alpha*(1-alpha)
    target[:,:,:3] = (source[:,:,:3]*alpha+target[:,:,:3]*base_alpha*(1-alpha))/np.maximum(combined, 1e-8)
    target[:,:,3:] = combined*255


def clip(base, pattern, bx, by, px, py, op):
    result = base.copy()
    placed = np.zeros_like(base)
    over(placed, pattern, px-bx, py-by)
    placed[:,:,3] *= op*base[:,:,3]/255
    over(result, placed, 0, 0)
    return result


def place(canvas, layer, x, y, shadow=False):
    if shadow:
        # Pad before blurring so the shadow extends outside the layer bbox.
        padding = 12
        alpha = Image.fromarray(np.rint(layer[:,:,3]).clip(0,255).astype(np.uint8))
        mask = Image.new('L', (alpha.width+padding*2, alpha.height+padding*2))
        mask.paste(alpha, (padding, padding))
        mask = mask.filter(ImageFilter.GaussianBlur(2.5))
        shade = np.zeros((mask.height, mask.width, 4), dtype=np.float32)
        shade[:,:,3] = np.asarray(mask)*.75
        over(canvas, shade, x+3-padding, y+4-padding)
    over(canvas, layer, x, y)


class Template:
    def __init__(self, kind):
        self.kind = kind
        directory = TEMPLATES / kind
        manifest = json.loads((directory/'manifest.json').read_text(encoding='utf8'))
        self.records = {layer['index']:layer for layer in manifest['layers']}
        self.directory = directory
        self.pixels = {}

    def load(self, index):
        if index not in self.pixels:
            record = self.records[index]
            image = Image.open(self.directory/record['raster']).convert('RGBA')
            x, y, right, bottom = record['bbox']
            assert image.size == (right-x, bottom-y), (self.kind, index, image.size)
            self.pixels[index] = np.asarray(image, dtype=np.float32)
        return self.pixels[index]

    def build(self, card, stops):
        w, h = (1488, 2079) if self.kind == 'unit' else (2079, 1488)
        canvas = np.zeros((h, w, 4), dtype=np.float32)

        def draw(index, op=None, shadow=False, pattern=None, pattern_op=1, scale=1, colors=stops, dy=0):
            layer = self.load(index)
            x, y = self.records[index]['bbox'][:2]
            if op is not None:
                layer = overlay(layer, colors, op, scale, self.kind == 'spell')
            if pattern is not None:
                px, py = self.records[pattern]['bbox'][:2]
                layer = clip(layer, self.load(pattern), x, y, px, py, pattern_op)
            place(canvas, layer, x, y+dy, shadow)

        if self.kind == 'unit':
            draw(10, .70, pattern=11, pattern_op=125/255)
            draw(12, 1., shadow=True)
            draw(77, .58, shadow=True, pattern=78)
            draw(79, 1.)
            fan = self.load(71).copy()
            first, second = petal_masks(fan)
            fan[first, :3] = stops[0]
            fan[second, :3] = stops[1]
            place(canvas, fan, *self.records[71]['bbox'][:2], shadow=True)
            draw(72)
            draw(73, 1., shadow=True)
            draw(65)
            draw(66, 1., shadow=True, colors=np.array([[0,0,0], stops[-1]], dtype=np.float32))
            draw(83, 1., shadow=True)
        else:
            draw(13, .47, pattern=14, pattern_op=74/255, scale=.73)
            draw(15, 1., shadow=True)
            dy = (464 if card['类别'] == '结界' else 872)-self.records[29]['bbox'][1]
            draw(29, dy=dy)
            draw(30, 1., shadow=True, dy=dy)
            if card.get('角色约束'):
                draw(33)
                draw(34, 1., shadow=True)
        return Image.fromarray(np.rint(canvas).clip(0,255).astype(np.uint8), 'RGBA')


# layer-071 petals are flat #069f7e (first) and #5cbda9 (second); the hub and handle keep their colors.
PETALS = np.array([[6,159,126], [92,189,169]], dtype=np.float32)


def petal_masks(fan):
    distance = np.linalg.norm(fan[:,:,None,:3]-PETALS, axis=3)
    near = distance.min(axis=2) < 60
    return [near&(distance.argmin(axis=2)==i) for i in range(2)]


def main():
    directory = OUT/'frames'
    directory.mkdir(parents=True, exist_ok=True)
    pack = ROOT/'examples/testmod'
    manifest = json.loads((pack/'manifest.json').read_text(encoding='utf8'))
    templates = {kind:Template(kind) for kind in ['unit', 'spell']}
    fan = templates['unit'].load(71)
    fan_masks = [int(mask.sum()) for mask in petal_masks(fan)]
    print(f'Fan source mask pixels: first={fan_masks[0]}, second={fan_masks[1]}', flush=True)
    report = []
    for filename in manifest['cards']:
        card = json.loads((pack/filename).read_text(encoding='utf8'))
        if card['类别'] not in ['单位', '自机', '符卡', '结界'] or card['图片'].startswith('res://'):
            continue
        identifier = card['卡牌ID'].split('/')[-1]
        colors = card['颜色']
        hex_stops = SINGLE[colors[0]] if len(colors) == 1 else [MAIN[color] for color in colors]
        stops = np.array([ImageColor.getrgb(color) for color in hex_stops], dtype=np.float32)
        kind = 'unit' if card['类别'] in ['单位', '自机'] else 'spell'
        image = templates[kind].build(card, stops)
        image.save(directory/f'{identifier}.png')
        report.append({'id':identifier, 'kind':kind, 'stops':hex_stops, 'dimensions':list(image.size)})
        if kind == 'unit':
            report[-1]['fan_recolor_mask_pixels'] = fan_masks
        print(identifier, kind, hex_stops, flush=True)
    (OUT/'frame-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(f'PASS: {len(report)} transparent frames from extracted raster layers; no PSD reads.')


if __name__ == '__main__':
    main()
