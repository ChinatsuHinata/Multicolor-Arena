"""Build layered PSDs with original-font type metadata and verified glyph caches."""
import copy
import os
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageColor
from psd_tools import PSDImage
from psd_tools.api.layers import TypeLayer
from psd_tools.constants import Tag, ChannelID
from psd_tools.psd import engine_data as ed
from psd_tools.psd.descriptor import String

from outline_testmod_text import resolve_fonts, font, title_character

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('TESTMOD_OUTPUT','output/testmod-typography-v4')
SOURCE = Path(os.environ.get('TESTMOD_SOURCE_UNIT', 'C:/Users/Lenovo/Documents/Tencent Files/1329315537/FileRecv/UI模板 单位 (2).psd'))


def engine(value):
    if isinstance(value, dict):
        result = ed.Dict()
        for key, item in value.items():
            result[key] = engine(item)
        return result
    if isinstance(value, list):
        return ed.List([engine(item) for item in value])
    if isinstance(value, bool):
        return ed.Bool(value)
    if isinstance(value, int):
        return ed.Integer(value)
    if isinstance(value, float):
        return ed.Float(value)
    if isinstance(value, str):
        return ed.String(value)
    raise TypeError(type(value))


def color(value):
    return {'Type': 1, 'Values': [1., *[v / 255 for v in ImageColor.getrgb(value)]]}


def type_layer(parent, record, folder, prototype, options):
    attrs = record['attrs']
    size = float(attrs['font-size'])
    family = attrs.get('font-family', '')
    face = ('DFJinWen-W3-WIN-BF' if 'DFJinWen' in family else
            'Slideqiuhong-Regular' if 'Slideqiuhong' in family else
            'SlideTownsoul-Regular' if 'SlideTownsoul' in family else 'MaoKenTangYuan-beta')
    s = record['text']
    f, cmap, _ = font(str(options[face]))
    # Match the existing outliner's same-font traditional title glyph mapping.
    if face == 'DFJinWen-W3-WIN-BF':
        s = ''.join(title_character(ch,cmap,f.getGlyphSet()) for ch in s)
    spacing = float(attrs.get('letter-spacing', 0))
    advance = 0
    for ch in s:
        glyph_font, glyph_cmap = f, cmap
        if face=='SlideTownsoul-Regular' and ord(ch) not in cmap:
            fallback='Slideqiuhong-Regular' if ch=='/' else 'SimSun'
            glyph_font, glyph_cmap, _ = font(str(options[fallback]))
        advance += glyph_font['hmtx'][glyph_cmap.get(ord(ch), '.notdef')][0] * size / glyph_font['head'].unitsPerEm
    advance += max(0, len(s)-1)*spacing
    x, y = float(attrs.get('x', 0)), float(attrs.get('y', 0))
    if attrs.get('text-anchor') == 'middle':
        x -= advance / 2
    elif attrs.get('text-anchor') == 'end':
        x -= advance
    a, b, c, d, tx, ty = record['transform']
    transform = (a, b, c, d, a*x+c*y+tx, b*x+d*y+ty)
    pixels = record.get('nativeCache', record)
    image = Image.open(folder / pixels['file']).convert('RGBA')
    cache = parent.create_pixel_layer(image, name=s, left=pixels['left'], top=pixels['top'])
    if 'nativeCache' in record and cache.has_mask():
        # Recent psd-tools stores imported RGBA alpha in a pixel mask. Native
        # type effects need glyph transparency, rather than a masked rectangle.
        mask_index = next(i for i,c in enumerate(cache._record.channel_info) if c.id == ChannelID.USER_LAYER_MASK)
        alpha_data = copy.deepcopy(cache._channels[mask_index])
        cache.remove_mask()
        alpha_index = next(i for i,c in enumerate(cache._record.channel_info) if c.id == ChannelID.TRANSPARENCY_MASK)
        cache._channels[alpha_index] = alpha_data
        cache._record.channel_info[alpha_index].length = alpha_data._length
    data = copy.deepcopy(prototype)
    data.transform = transform
    data.left, data.top, data.right, data.bottom = cache.bbox
    data.text_data[b'Txt '] = String(s + '\x00')
    raw = data.text_data[b'EngineData'].value
    e = raw['EngineDict']
    count = len((s+'\r').encode('utf-16-be')) // 2
    e['Editor'] = engine({'Text': s+'\r'})
    keyword = attrs.get('data-keyword') == 'true'
    weight = float(attrs.get('data-embolden', 0))
    stroke = float(attrs.get('stroke-width', 0))
    style = {
        'Font': 0, 'FontSize': size, 'FauxBold': attrs.get('data-native-faux-bold')=='true',
        'FauxItalic': False, 'AutoLeading': False, 'Leading': float(attrs.get('data-native-leading', size)),
        'HorizontalScale': 1., 'VerticalScale': 1., 'Tracking': int(attrs.get('data-native-tracking', round(spacing/size*1000))),
        'AutoKerning': False, 'Kerning': 0, 'BaselineShift': 0., 'FontCaps': 0, 'FontBaseline': 0,
        # Underlines are a separate, named layer so vertical side rules keep their exact position.
        'Underline': False, 'Strikethrough': False, 'Ligatures': False, 'Language': 14,
        'FillColor': color(attrs.get('fill', '#000')), 'FillFlag': True,
        'StrokeFlag': bool(stroke), 'StrokeColor': color(attrs.get('stroke', attrs.get('fill', '#000'))),
        'OutlineWidth': stroke, 'FillFirst': False, 'HindiNumbers': False,
    }
    # Use the source PSD's punctuation faces in editable text too. Otherwise a
    # reopened title silently replaces cached SimSun brackets with another face.
    font_faces=[face]
    runs=[]
    lengths=[]
    for ch in s+'\r':
        actual=face
        if face=='SlideTownsoul-Regular' and ord(ch) not in cmap and ch!='\r':
            actual='Slideqiuhong-Regular' if ch=='/' else 'SimSun'
        if actual not in font_faces:font_faces.append(actual)
        font_index=font_faces.index(actual)
        length=len(ch.encode('utf-16-be'))//2
        if runs and runs[-1]['StyleSheet']['StyleSheetData']['Font']==font_index:
            lengths[-1]+=length
        else:
            run_style={**style,'Font':font_index}
            runs.append({'StyleSheet':{'StyleSheetData':run_style}})
            lengths.append(length)
    e['StyleRun'] = engine({'DefaultRunData': {'StyleSheet': {'StyleSheetData': style}},
        'RunArray': runs, 'RunLengthArray': lengths, 'IsJoinable': 2})
    paragraph = {'Justification': 0, 'FirstLineIndent': 0., 'StartIndent': 0., 'EndIndent': 0.,
        'SpaceBefore': 0., 'SpaceAfter': 0., 'AutoHyphenate': False, 'EveryLineComposer': False,
        'AutoLeading': 1.08, 'LeadingType': 0, 'Hanging': False, 'Burasagari': False,
        'WordSpacing': [.8, 1., 1.33], 'LetterSpacing': [0., 0., 0.], 'GlyphSpacing': [1., 1., 1.]}
    paragraph_run = {'ParagraphSheet': {'DefaultStyleSheet': 0, 'Properties': paragraph},
        'Adjustments': {'Axis': [1., 0., 1.], 'XY': [0., 0.]}}
    e['ParagraphRun'] = engine({'DefaultRunData': paragraph_run, 'RunArray': [paragraph_run],
        'RunLengthArray': [count], 'IsJoinable': 1})
    e['Rendered'] = engine({'Version': 1, 'Shapes': {'WritingDirection': 0, 'Children': [{
        'ShapeType': 0, 'Procession': 0, 'Lines': {'WritingDirection': 0, 'Children': []},
        'Cookie': {'Photoshop': {'ShapeType': 0, 'PointBase': [0., 0.], 'Base': {
            'ShapeType': 0, 'TransformPoint0': [1., 0.], 'TransformPoint1': [0., 1.], 'TransformPoint2': [0., 0.]}}}}]}})
    for section in ('ResourceDict', 'DocumentResources'):
        resources = raw[section]
        resources['FontSet'] = engine([{'Name': name, 'Script': 2 if name.startswith('DFJinWen') else 3, 'FontType': 1, 'Synthetic': 0} for name in font_faces])
        resources['StyleSheetSet'] = engine([{'Name': 'Card text', 'StyleSheetData': style}])
        resources['ParagraphSheetSet'] = engine([{'Name': 'Card paragraph', 'DefaultStyleSheet': 0, 'Properties': paragraph}])
    cache.tagged_blocks[Tag.TYPE_TOOL_OBJECT_SETTING] = copy.deepcopy(prototype_tag)
    cache.tagged_blocks[Tag.TYPE_TOOL_OBJECT_SETTING].data = data
    effect_kind = attrs.get('data-native-effect')
    if effect_kind:
        # Raw glyph caches plus the original editable glow, with no baked halo
        # and no second text stroke when Photoshop renders the layer again.
        assert record.get('nativeCache') and not stroke
        cache.tagged_blocks[Tag.OBJECT_BASED_EFFECTS_LAYER_INFO] = copy.deepcopy(effect_prototypes[effect_kind])
    native = TypeLayer(parent, cache._record, cache._channels)
    parent.remove(cache)
    parent.append(native)
    if keyword:
        native.name = '[关键词·加粗] ' + s
    return native


def cropped_layer(parent, source, name):
    image = Image.open(source).convert('RGBA')
    box = image.getbbox()
    if box:
        return parent.create_pixel_layer(image.crop(box), name=name, left=box[0], top=box[1])


def main():
    global prototype_tag, effect_prototypes
    original = PSDImage.open(SOURCE)
    source_layers = list(original.descendants())
    source_type = next((layer for layer in source_layers if layer.kind=='type' and '该单位进战场时' in layer.text),
                       next(layer for layer in source_layers if layer.kind=='type'))
    prototype_tag = source_type.tagged_blocks[Tag.TYPE_TOOL_OBJECT_SETTING]
    options = resolve_fonts()
    profile_path = OUT / 'title-profile.json'
    title_profile = json.loads(profile_path.read_text(encoding='utf8')) if profile_path.exists() else None
    effect_prototypes = {}
    if title_profile:
        for kind in ['unit', 'spell']:
            template = title_profile['templates'][kind]
            source = PSDImage.open(template['source'])
            layer = list(source.descendants())[template['titles'][0]['layer']]
            effect_prototypes[kind] = layer.tagged_blocks[Tag.OBJECT_BASED_EFFECTS_LAYER_INFO]
    report = json.loads((OUT/'render-report.json').read_text(encoding='utf8'))
    audit = []
    for card in report:
        if len(sys.argv)>1 and card['id'] not in sys.argv[1:]:
            continue
        folder = OUT/'layers'/card['id']
        records = json.loads((folder/'text-layers.json').read_text(encoding='utf8'))
        psd = PSDImage.new('RGB', tuple(card['dimensions']))
        cropped_layer(psd, folder/'illustration.png', '01 插画')
        cropped_layer(psd, folder/'ui.png', '02 原模板框体与装饰')
        labels = psd.create_group(name='03 卡名、数值与类型文字')
        body = psd.create_group(name='04 正文（猫啃糖圆体）')
        if (folder/'symbols.json').exists():
            symbols = psd.create_group(name='05 属性升降符号（攻防胶囊与灵力印章）')
            for symbol in json.loads((folder/'symbols.json').read_text(encoding='utf8')):
                cropped_layer(symbols, folder/symbol['file'], symbol['name'])
        for r in records:
            role = r['attrs'].get('data-role')
            parent = symbols if role in ('symbol-value','symbol-join') else body if role=='rules' else labels
            type_layer(parent, r, folder, source_type._data, options)
        cropped_layer(psd, folder/'underlines.png', '06 关键词下划线（竖排为左侧线）')
        # Unicode names live in luni; retain an ASCII legacy Pascal-string fallback.
        for layer_index, layer in enumerate(psd.descendants()):
            layer._record.name = f'Layer {layer_index+1}'
        target = OUT/'psd'/f"{card['id']}.psd"
        if title_profile:
            # psd-tools does not render outer glow. Preserve the normal PSD
            # merged preview separately, as Photoshop does, while retaining
            # raw per-layer glyphs and the source's live effect descriptors.
            preview = Image.open(OUT/'cards'/f"{card['id']}.png").convert('RGB')
            psd._record.image_data.set_data([channel.tobytes() for channel in preview.split()], psd._record.header)
            psd._updated = False
        psd.save(target)
        reopened = PSDImage.open(target)
        types = [layer for layer in reopened.descendants() if layer.kind=='type']
        assert len(types)==len(records), (card['id'],len(types),len(records))
        for layer in types:
            length = len(layer.engine_dict['Editor']['Text'].value.encode('utf-16-be'))//2
            assert sum(x.value for x in layer.engine_dict['StyleRun']['RunLengthArray'])==length
        native_titles = 0
        if title_profile:
            for record in records:
                if 'nativeCache' not in record:
                    continue
                pixels = record['nativeCache']
                matches = [l for l in types if l.bbox == (pixels['left'], pixels['top'], pixels['left']+pixels['width'], pixels['top']+pixels['height'])
                           and l.has_effects()]
                assert len(matches) == 1, (card['id'], 'missing native title cache', record['text'])
                layer = matches[0]
                cached = np.asarray(layer.topil().convert('RGBA'))
                exported = np.asarray(Image.open(folder/pixels['file']).convert('RGBA'))
                assert np.array_equal(cached[:,:,3], exported[:,:,3])
                assert np.array_equal(cached[:,:,:3][exported[:,:,3]>0], exported[:,:,:3][exported[:,:,3]>0])
                style = layer.engine_dict['StyleRun']['RunArray'][0]['StyleSheet']['StyleSheetData']
                assert not style['StrokeFlag'].value
                # EngineData serializes decimal values to five places.
                assert abs(style['FontSize'].value - float(record['attrs']['font-size'])) < .00001
                assert style['Tracking'].value == int(record['attrs']['data-native-tracking'])
                assert style['FauxBold'].value == (record['attrs'].get('data-native-faux-bold') == 'true')
                faces = [entry['Name'].value for entry in layer.resource_dict['FontSet']]
                expected_face = 'DFJinWen-W3-WIN-BF' if card['kind'] == 'spell' else 'SlideTownsoul-Regular'
                assert faces[0] == expected_face
                assert not layer.has_mask()
                kind = record['attrs']['data-native-effect']
                assert layer.tagged_blocks[Tag.OBJECT_BASED_EFFECTS_LAYER_INFO].tobytes() == effect_prototypes[kind].tobytes()
                native_titles += 1
        actual = np.asarray(reopened.topil().convert('RGB')).astype(np.int16)
        expected = np.asarray(Image.open(OUT/'cards'/f"{card['id']}.png").convert('RGB')).astype(np.int16)
        difference = np.abs(actual-expected)
        row = {'id':card['id'], 'native_text_layers':len(types), 'psd_bytes':target.stat().st_size,
            'dimensions':list(reopened.size), 'mean_channel_difference':float(difference.mean()),
            'pixels_over_3':int((difference.max(axis=2)>3).sum())}
        if title_profile:
            row.update(native_title_layers=native_titles, title_raw_caches_exact=True,
                       source_title_effects_exact=True, merged_preview='stored; outer glow not rendered by psd-tools')
        assert row['mean_channel_difference'] < .5, row
        reopened.topil().save(OUT/'psd'/f"{card['id']}.preview.png")
        audit.append(row)
        print(json.dumps(row),flush=True)
    target=OUT/'psd-validation.json'
    if len(sys.argv)>1 and target.exists():
        old=json.loads(target.read_text(encoding='utf8'))
        by_id={row['id']:row for row in old}
        by_id.update({row['id']:row for row in audit})
        audit=[by_id[card['id']] for card in report if card['id'] in by_id]
    target.write_text(json.dumps(audit,indent=2),encoding='utf8')


if __name__ == '__main__':
    main()
