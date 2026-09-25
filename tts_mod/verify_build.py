"""Verify the generated TTS save against the Godot card pool and source mod."""

from __future__ import annotations

import json
import re
from pathlib import Path

from build_tts_deckbuilder import HERE, ROOT, read_json, registered_ids


def embedded_json(lua: str, name: str):
    pattern = rf"local {name} = JSON.decode\(\[====\[(.*?)\]====\]\)"
    match = re.search(pattern, lua, re.DOTALL)
    assert match, f"Missing embedded {name}"
    return json.loads(match.group(1))


def main():
    reports = [HERE / "build_report.json", HERE / "current_save_report.json"]
    for report_path in reports:
        if not report_path.is_file():
            continue
        report = read_json(report_path)
        source = read_json(Path(report["source_mod"]))
        output = read_json(Path(report["output"]))
        assert output["ObjectStates"] == source["ObjectStates"], "The original mod's objects changed"
        assert output["SaveName"] == "极彩同人卡牌 · 组卡器移植"
        catalog = embedded_json(output["LuaScript"], "cards")
        assets = embedded_json(output["LuaScript"], "assets")
        by_id = {card["id"]: card for card in catalog}
        assert len(catalog) == len(by_id) == len(registered_ids()) == 513
        assert set(by_id) == set(registered_ids())
        assert report["existing_tts_faces"] + report["local_faces"] == len(catalog)
        assert report["local_faces"] == len(read_json(HERE / "local_art_manifest.json"))
        for card in catalog:
            assert card["canonical"] in by_id
            assert card["deck_id"] in assets
            asset = assets[card["deck_id"]]
            assert asset["FaceURL"] and asset["BackURL"]
            assert int(card["card_id"]) // 100 == int(card["deck_id"])
            if card["local_art"]:
                assert Path(asset["FaceURL"]).is_file(), card["id"]
            else:
                assert asset["FaceURL"].startswith(("http://", "https://")), card["id"]

    # The shipped preconstructed decks exercise JSON import and physical face coverage.
    precons = list((ROOT / "deck/预设卡组").glob("*.mdeck"))
    assert precons
    for path in precons:
        deck = read_json(path)["deck"]
        assert len(deck["main"]) == 50, path
        assert len(deck["side"]) <= 10, path
        assert deck["leader"] in by_id, path
        assert all(card_id in by_id for card_id in deck["main"] + deck["side"]), path

    print(f"Verified {len(reports)} save variants, {len(catalog)} registered cards, "
          f"{len(assets)} image sheets, {len(precons)} preconstructed decks, "
          "and unchanged source objects.")


if __name__ == "__main__":
    main()
