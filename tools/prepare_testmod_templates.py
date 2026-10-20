"""Render native template components, preserving PSD clipping and effects."""
import json
from pathlib import Path
from psd_tools import PSDImage
from psd_tools.constants import Tag
from psd_tools.psd.descriptor import Descriptor, Bool, List

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/testmod-design-v2'
SOURCE = Path('C:/Users/Lenovo/Documents/Tencent Files/1329315537/FileRecv')
SPECS = {
    'unit': ('UI模板 单位 (2).psd', {
        'trim': [2], 'title': [76], 'bottom': [9], 'stats': [65,66],
        'type': [72,73], 'race': [69], 'spirit': [83], 'leader': [179],
        'main': [58], 'self': [61],
        'cost-blue':[86], 'cost-black':[92], 'cost-yellow':[98],
        'cost-red':[104], 'cost-green':[111],
    }),
    'item': ('UI模板 道具.psd', {
        'trim':[2], 'title':[61], 'body':[7,8], 'type':[58,59], 'main':[51],
        'cost-blue':[68], 'cost-white':[74], 'cost-black':[80],
        'cost-yellow':[86], 'cost-red':[92], 'cost-green':[99],
    }),
    'spell': ('UI模板 符卡.psd', {
        'trim':[2], 'title':[12], 'type':[29,30], 'character':[33,34],
        'main':[19], 'character-ability':[22],
        'cost-white':[37], 'cost-blue':[43], 'cost-black':[49],
        'cost-yellow':[55], 'cost-red':[61], 'cost-green':[68],
    }),
}

def main():
    OUT.mkdir(exist_ok=True)
    (OUT / '.gdignore').touch()
    for kind, (filename, components) in SPECS.items():
        psd = PSDImage.open(SOURCE / filename)
        layers = list(psd.descendants())
        # Older Photoshop descriptors omit the newer 'present' flag. psd-tools
        # otherwise ignores their enabled gradients, strokes and shadows.
        for layer in layers:
            for tag in (Tag.OBJECT_BASED_EFFECTS_LAYER_INFO,
                        Tag.OBJECT_BASED_EFFECTS_LAYER_INFO_V0,
                        Tag.OBJECT_BASED_EFFECTS_LAYER_INFO_V1):
                data = layer.tagged_blocks.get_data(tag)
                if isinstance(data, Descriptor):
                    for value in data.values():
                        for effect in value if isinstance(value,List) else [value]:
                            if isinstance(effect,Descriptor) and b'enab' in effect and b'present' not in effect:
                                effect[b'present'] = Bool(True)
        target = OUT / 'components' / kind
        target.mkdir(parents=True, exist_ok=True)
        records = {}
        for name, indices in components.items():
            selected = {id(layers[i]) for i in indices}
            for i in indices:
                root = layers[i]
                if root.is_group():
                    for child in root.descendants():
                        visible = child.visible
                        parent = child.parent
                        while parent is not root:
                            visible = visible and parent.visible
                            parent = parent.parent
                        if visible and child.kind != 'type':
                            selected.add(id(child))
                parent = root.parent
                while parent is not None:
                    selected.add(id(parent))
                    parent = parent.parent
            # Directly selected hidden groups are valid variants in these templates.
            # Do not include the sample text, art or attribution.
            bounds = [layers[i].bbox for i in indices]
            if name == 'trim':
                box = (0,0,*psd.size)
            else:
                # Group bounds are zero when their variant is hidden.
                for i in indices:
                    layers[i].visible = True
                bounds = [layers[i].bbox for i in indices]
                box = (min(b[0] for b in bounds), min(b[1] for b in bounds),
                       max(b[2] for b in bounds), max(b[3] for b in bounds))
            result = psd.composite(viewport=box, force=True, ignore_preview=True,
                                   layer_filter=lambda l: id(l) in selected and l.kind != 'type')
            result.save(target / f'{name}.png')
            records[name] = {'bbox':box, 'source_layers':indices}
            print(kind, name, box, flush=True)
        # Type layers carry original cached glyphs; retain reusable labels exactly.
        for i, layer in enumerate(layers):
            if layer.kind == 'type':
                raster = layer.topil()
                if raster is not None:
                    raster.save(target / f'text-{i:03}.png')
        (target / 'components.json').write_text(json.dumps(records, indent=2),encoding='utf-8')

if __name__ == '__main__':
    main()
