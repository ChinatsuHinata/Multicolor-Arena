"""Build a Tabletop Simulator save with the Multicolour deck builder.

The source Workshop save is read only. The resulting save is written inside this
repository and can be imported by Tabletop Simulator without changing Workshop
subscriptions or the Godot project.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
DEFAULT_MOD = Path.home() / "Documents/My Games/Tabletop Simulator/Mods/Workshop/2629086384.json"
DEFAULT_MAPPING_SOURCE = Path.home() / "Documents/Codex/2026-09-25/xun/outputs/multicolour_cards_database.json"
RULE_IDS = ("unrestricted", "official", "official_spx", "test")


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def registered_ids() -> list[str]:
    source = (ROOT / "scripts/card_database.gd").read_text(encoding="utf-8")
    match = re.search(r"^const IDS=(\[[^\n]+\])", source, re.MULTILINE)
    if not match:
        raise ValueError("Cannot find the registered card IDs in card_database.gd")
    return json.loads(match.group(1))


def collect_cards(value, found: dict[int, dict]):
    if isinstance(value, dict):
        card_id = value.get("CardID")
        if isinstance(card_id, int) and value.get("CustomDeck"):
            found.setdefault(card_id, value)
        for key in ("ObjectStates", "ContainedObjects"):
            for child in value.get(key, []):
                collect_cards(child, found)
        for child in value.get("States", {}).values():
            collect_cards(child, found)


def mapped_card_ids(source: dict) -> dict[str, list[int]]:
    result: dict[str, list[int]] = {}
    for tts_id, project_id in source["card_to_proto"].items():
        if isinstance(project_id, str) and not project_id.startswith("workbook:"):
            result.setdefault(project_id, []).append(int(tts_id))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod", type=Path, default=DEFAULT_MOD)
    parser.add_argument("--asset-mod", type=Path, default=DEFAULT_MOD,
                        help="Save containing the original TTS image sheets")
    parser.add_argument("--mapping-source", type=Path, default=DEFAULT_MAPPING_SOURCE)
    parser.add_argument("--output", type=Path, default=HERE / "Multicolour_Deck_Builder.json")
    parser.add_argument("--report", type=Path, default=HERE / "build_report.json")
    args = parser.parse_args()

    mod = read_json(args.mod)
    source = read_json(args.mapping_source)
    source_cards: dict[int, dict] = {}
    collect_cards(read_json(args.asset_mod), source_cards)
    tts_ids = mapped_card_ids(source)
    ids = registered_ids()
    source_back = next(iter(source_cards.values()))["CustomDeck"]
    back_url = next(iter(source_back.values()))["BackURL"]

    assets: dict[str, dict] = {}
    catalog: list[dict] = []
    local_assets: list[dict] = []
    for project_id in ids:
        definition = read_json(ROOT / "cards" / (project_id + ".json"))
        if definition["卡牌ID"] != project_id:
            raise ValueError(f"Card ID mismatch: {project_id}")
        art = ROOT / definition["图片"].replace("res://", "")
        if not art.is_file():
            raise FileNotFoundError(art)

        mapped = next((card_id for card_id in tts_ids.get(project_id, []) if card_id in source_cards), None)
        if mapped is None:
            deck_id = str(9000 + len(local_assets))
            mapped = int(deck_id) * 100
            assets[deck_id] = {
                "FaceURL": str(art.resolve()),
                "BackURL": back_url,
                "NumWidth": 1,
                "NumHeight": 1,
                "BackIsHidden": False,
                "UniqueBack": False,
                "Type": 0,
            }
            local_assets.append({"id": project_id, "name": definition["名称"], "path": str(art.resolve())})
        else:
            deck_id = str(mapped // 100)
            card_source = source_cards[mapped]
            image = card_source["CustomDeck"].get(deck_id)
            if image is None:
                raise ValueError(f"Missing custom deck {deck_id} for {project_id}")
            if deck_id in assets and assets[deck_id] != image:
                raise ValueError(f"Conflicting TTS image sheet {deck_id}")
            assets[deck_id] = image

        cost = sum(int(v) for v in definition["费用"].values())
        catalog.append({
            "id": project_id,
            "name": definition["名称"],
            "kind": definition["类别"],
            "colors": definition["颜色"],
            "cost": cost,
            "keywords": definition.get("关键词", []),
            "canonical": definition.get("同卡异版", project_id),
            "aliases": definition.get("别名", []),
            "constructible": definition["构筑资格"]["允许常规构筑"],
            "token": definition.get("衍生物", False),
            "unlimited": definition.get("同名数量无限制", False),
            "rules": definition["能力文字"],
            "card_id": mapped,
            "deck_id": deck_id,
            "sideways": definition.get("横向卡图", definition["类别"] in ("符卡", "结界")),
            "local_art": mapped >= 900000,
        })

    # The Godot browser omits alternate printings; keep their IDs for old deck imports.
    if len(catalog) != len(ids) or len({c["id"] for c in catalog}) != len(ids):
        raise ValueError("Catalog does not match the registered card pool")
    for card in catalog:
        if card["canonical"] not in ids:
            raise ValueError(f"Unknown canonical card: {card['id']}")

    compact = lambda value: json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    template = (HERE / "deck_builder.lua").read_text(encoding="utf-8")
    lua = template.replace("__CATALOG_JSON__", compact(catalog)).replace("__ASSETS_JSON__", compact(assets))
    if lua == template or "__CATALOG_JSON__" in lua or "__ASSETS_JSON__" in lua:
        raise ValueError("Lua template placeholders were not replaced")

    mod["SaveName"] = "极彩同人卡牌 · 组卡器移植"
    mod["LuaScript"] = lua
    mod["LuaScriptState"] = ""
    mod["XmlUI"] = ""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(mod, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (HERE / "local_art_manifest.json").write_text(json.dumps(local_assets, ensure_ascii=False, indent=2), encoding="utf-8")
    report = {
        "registered_cards": len(catalog),
        "constructible_cards": sum(c["constructible"] and not c["token"] for c in catalog),
        "existing_tts_faces": len(catalog) - len(local_assets),
        "local_faces": len(local_assets),
        "rule_sets": RULE_IDS,
        "types": dict(Counter(c["kind"] for c in catalog)),
        "source_mod": str(args.mod),
        "asset_mod": str(args.asset_mod),
        "output": str(args.output),
    }
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
