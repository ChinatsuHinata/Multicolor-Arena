"""Build the cosmetic art catalogue from the offline single-card gallery.

Run with the source directory as an optional argument. Gameplay definitions are
never imported: only images and their audited association with current cards.
"""
import argparse
import csv
import json
import re
import shutil
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def normalize(value):
    return re.sub(r"[\s·・。．，,：:（）()]", "", value or "").replace("斯卡雷特", "斯卡蕾特").replace("封兽ぬえ", "封兽鵺")


def build(source):
    gallery = json.loads((source / "cards_database.json").read_text(encoding="utf-8"))
    cards = {p.stem: json.loads(p.read_text(encoding="utf-8")) for p in (ROOT / "cards").glob("*.json")}
    groups = defaultdict(list)
    audit = []

    def canonical(card_id):
        return cards[card_id].get("同卡异版", card_id)

    for card_id, card in cards.items():
        key = canonical(card_id)
        if key != card_id:
            groups[key].append({"id": card_id, "image": card["图片"], "label": "已有异版 · " + card_id, "source": "项目保留的同卡异版"})

    for asset_id, asset in gallery["assets"].items():
        proto_id = gallery["card_to_proto"][str(asset["tts_card_ids"][0])]
        proto = gallery["protos"][proto_id]
        candidates = []
        status = asset["identification_status"]
        if proto_id in cards:
            candidates = [proto_id]
        elif asset.get("ambiguous_project_ids"):
            candidates = asset["ambiguous_project_ids"]
        else:
            # A complete printed title avoids confusing different cards featuring
            # the same character. Number alone can occur in cross-reference notes.
            candidates = [i for i, c in cards.items() if normalize(c["名称"]) == normalize(proto.get("名称"))]
        keys = sorted({canonical(i) for i in candidates})
        row = {"asset_id": asset_id, "name": proto.get("名称", ""), "code": proto.get("来源编号", ""), "card_id": "", "status": "", "identification": status, "source_image": asset["image"]}
        if len(keys) != 1:
            row["status"] = "未对应当前卡池"
        elif status in ("project_image_match", "variant_ambiguous"):
            row["card_id"] = keys[0]
            row["status"] = "已有卡面／重复裁切"
        else:
            key = keys[0]
            card = cards[key]
            # A face transcription without a verified rules record cannot become
            # a selectable variant. Check colors, cost and unit stats as well.
            numeric = ["攻击力", "血量", "灵力"]
            compatible = status != "face_transcription" and proto.get("费用") == card.get("费用") and set(proto.get("颜色", [])) == set(card.get("颜色", [])) and all(proto.get(k) == card.get(k) for k in numeric)
            if not compatible:
                row["card_id"] = key
                row["status"] = "待核对规则／数值"
            else:
                target = ROOT / "recourse" / "异画" / (asset_id + Path(asset["image"]).suffix)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source / asset["image"], target)
                label = " · ".join(str(proto[k]) for k in ["来源编号", "罕贵度", "画师"] if proto.get(k))
                groups[key].append({"id": asset_id, "image": "res://recourse/异画/" + target.name, "label": label or asset_id, "source": asset["image"], "printed_code": proto.get("来源编号", ""), "artist": proto.get("画师", ""), "identification": status})
                row["card_id"] = key
                row["status"] = "已收录异画"
        audit.append(row)

    for key, variants in groups.items():
        variants.insert(0, {"id": key, "image": cards[key]["图片"], "label": "默认卡面", "source": "当前卡牌数据库"})
    manifest = {"version": 1, "source": str(source), "groups": dict(sorted(groups.items()))}
    (ROOT / "data" / "alternate_art.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (ROOT / "docs" / "异画素材核对.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(audit[0]))
        writer.writeheader()
        writer.writerows(audit)
    (ROOT / "docs" / "异画素材核对.csv.import").write_text('[remap]\n\nimporter="keep"\n', encoding="utf-8")
    lines = ["# 异画表", "", "来源：`" + str(source) + "`。异画仅替换卡面，规则以游戏当前卡牌定义为准。", "", "组卡器中用鼠标中键点击仓库、主卡组、副卡组或自机位的牌，选择卡面。选择只保存在当前卡组；该卡组所有对应牌使用同一卡面。联机、观战、回放和卡组截图沿用所选卡面。", "", "原卡面及同图裁切不重复导入；完整素材核对结果见 [异画素材核对.csv](异画素材核对.csv)。未实装或数值无法对应的素材保留在核对表中。", "", "| 卡牌 ID | 卡牌名称 | 可选版本（含默认） |", "| --- | --- | --- |"]
    for key, variants in sorted(groups.items()):
        lines.append("| " + key + " | " + cards[key]["名称"] + " | " + "；".join(v["label"] + " (`" + v["id"] + "`)" for v in variants) + " |")
    lines += ["", f"共 {len(groups)} 张牌有可选版本，{sum(len(v)-1 for v in groups.values())} 个非默认版本。", ""]
    (ROOT / "docs" / "异画表.md").write_text("\n".join(lines), encoding="utf-8")
    from collections import Counter
    print(json.dumps({"groups": len(groups), "alternate_versions": sum(len(v)-1 for v in groups.values()), "audit": dict(Counter(r['status'] for r in audit))}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", type=Path, default=Path(r"D:\极彩单卡"))
    build(parser.parse_args().source)
