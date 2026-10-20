"""Extract original PSD raster components and an auditable layer manifest."""
import argparse
import hashlib
import json
from pathlib import Path

from psd_tools import PSDImage


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=Path("output/testmod-design/template"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    psd = PSDImage.open(args.source)
    layers = list(psd.descendants())
    indices = {id(layer): index for index, layer in enumerate(layers)}
    records = []
    for index, layer in enumerate(layers):
        record = dict(index=index, name=layer.name, kind=layer.kind,
                      bbox=layer.bbox, visible=layer.visible, opacity=layer.opacity,
                      parent=indices.get(id(layer.parent)), blend_mode=str(layer.blend_mode),
                      effective_visible=layer.is_visible())
        if layer.kind == "type":
            record["text"] = layer.text
            record["fonts"] = [str(font.get("Name", "")) for font in layer.resource_dict.get("FontSet", [])]
            record["transform"] = list(layer.transform)
            record["style_runs"] = str(layer.engine_dict.get("StyleRun", ""))
        if layer.kind in {"pixel", "smartobject", "shape"}:
            raster = layer.topil()
            if raster is not None:
                name = f"layer-{index:03}.png"
                raster.save(args.output / name)
                record["raster"] = name
        records.append(record)
    psd.topil().save(args.output / "composite.png")
    result = dict(source=args.source.name, sha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),
                  canvas=list(psd.size), layer_count=len(layers), layers=records,
                  note="Original raster layers are preserved; sample prose is source data, not a task instruction.")
    (args.output / "manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Extracted {len(records)} layers from {psd.size}")


if __name__ == "__main__":
    main()
