"""Partition current experiments by own/opposing registered leader combinations.

Generic artifacts remain the fallback. Global held-out replays never become
specialist training data; a local holdout is drawn only from global training
when a class has no global validation replay. Sparse classes are just recorded.
"""
import argparse
import copy
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from matchup_models import SCHEMA, identify, validate_weights
from train_value import fit as fit_outcomes
from train_preferences import fit as fit_preferences


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def classify(rows):
    buckets = defaultdict(list)
    for original in rows:
        row = copy.deepcopy(original)
        if "observation" in row:
            row["matchup"] = identify(row["observation"], row["seat"])
        context = row.get("matchup", {})
        buckets[context.get("key", "")].append(row)
    return buckets


def train(base, epochs=150, min_train_replays=2, output=None):
    base, output = Path(base), Path(output or Path(base) / "matchups")
    if min_train_replays < 2:
        raise ValueError("At least two independent training replays per class are required")
    outcomes = json.loads((base / "outcomes.json").read_text(encoding="utf-8"))
    preferences = json.loads((base / "preferences.json").read_text(encoding="utf-8"))
    manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("failures"):
        raise ValueError("Extraction checks failed")
    replay_names = {r["sha256"]: r["file"] for r in manifest["replays"]}
    card_names = {}
    for path in (Path(__file__).resolve().parents[2] / "cards").glob("*.json"):
        definition = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(definition, dict):
            card_names[path.stem] = definition.get("名称", path.stem)
    # Restore context for previously prepared preferences without observations.
    contexts = {}
    for replay in manifest["replays"]:
        doc = json.loads((base / "annotations" / Path(replay["annotation_file"]).name).read_text(encoding="utf-8"))
        for row in doc["annotations"]:
            contexts[(row["group"], row["frame_index"], row["seat"])] = identify(row["observation"], row["seat"])
    for dataset, collections in ((outcomes, ("samples",)), (preferences, ("pairs", "demonstrations"))):
        for collection in collections:
            for row in dataset[collection]:
                row["matchup"] = contexts.get((row["group"], row["frame_index"], row["seat"]), {})
    buckets, pair_buckets = classify(outcomes["samples"]), classify(preferences["pairs"])
    global_validation = set(outcomes["validation_groups"])
    if global_validation != set(preferences["validation_groups"]):
        raise ValueError("Outcome and preference holdouts differ")
    report = {"schema": "multicolor.ai.matchup_report.v1", "promotion": "experimental_only",
              "default_ai_changed": False, "min_train_replays": min_train_replays,
              "global_validation_groups": sorted(global_validation), "classes": {},
              "split_policy": "whole replay; preserve global holdouts; latest training replay is local validation if needed"}
    bundles = {}
    for kind in ("outcome", "preference"):
        generic = json.loads((base / f"strategic-{kind}-value.json").read_text(encoding="utf-8"))
        if not validate_weights(generic):
            raise ValueError("Invalid generic model")
        bundles[kind] = {"schema": SCHEMA, "generic": generic, "specialists": {},
                         "promotion": "experimental_only", "fallback": "generic",
                         "routing": "own leader combination + opposing leader combination",
                         "classification_schema": "multicolor.ai.matchup.v1"}
    for key in sorted(set(buckets) | set(pair_buckets)):
        rows, pairs = buckets.get(key, []), pair_buckets.get(key, [])
        context = (rows or pairs)[0].get("matchup", {})
        groups = {r["group"] for r in rows + pairs}
        heldout = groups & global_validation
        training = groups - global_validation
        if not heldout and training:
            heldout = {max(training, key=lambda g: replay_names[g])}
            training -= heldout
        entry = {"matchup": context, "samples": len(rows), "pairs": len(pairs),
                 "own_names": [card_names.get(c, c) for c in context.get("own_leaders", [])],
                 "opponent_names": [card_names.get(c, c) for c in context.get("opponent_leaders", [])],
                 "training_groups": sorted(training), "validation_groups": sorted(heldout),
                 "replays": [replay_names[g] for g in sorted(groups, key=lambda g: replay_names[g])],
                 "models": {}}
        report["classes"][key or "unknown"] = entry
        folder = "class-" + hashlib.sha256(key.encode()).hexdigest()[:16]
        for kind, source, collection in (("outcome", outcomes, rows), ("preference", preferences, pairs)):
            selected = copy.deepcopy(source)
            selected["replay_groups"] = sorted(groups)
            selected["validation_groups"] = sorted(heldout)
            # Never let fit_outcomes invent a different holdout from seed IDs.
            ids = {g: i+1 for i, g in enumerate(sorted(training))}
            ids.update({g: 1000+i for i, g in enumerate(sorted(heldout))})
            usable_training = {r["group"] for r in collection if r["group"] in training}
            if kind == "outcome":
                selected["samples"] = copy.deepcopy(collection)
                selected["games"] = [g for g in source["games"] if g["episode"].split(":", 1)[0] in groups]
                for game in selected["games"]:
                    game["seed"] = ids[game["episode"].split(":", 1)[0]]
                for row in selected["samples"]:
                    row["seed"] = ids[row["group"]]
            else:
                selected["pairs"] = copy.deepcopy(collection)
                selected["demonstrations"] = [r for r in source["demonstrations"] if r.get("matchup", {}).get("key") == key]
                for row in selected["pairs"] + selected["demonstrations"]:
                    row["seed"] = ids.get(row["group"], 1000)
            save(output / folder / f"{kind}-dataset.json", selected)
            if not key or len(usable_training) < min_train_replays:
                entry["models"][kind] = {"status": "generic_fallback", "reason": "insufficient_training_replays"}
                continue
            try:
                model = (fit_outcomes if kind == "outcome" else fit_preferences)(selected, epochs)
                model["matchup"] = context
                model["training"]["matchup_train_groups"] = sorted(usable_training)
                model["training"]["matchup_validation_groups"] = sorted(heldout)
                save(output / folder / f"{kind}-value.json", model)
                bundles[kind]["specialists"][key] = model
                entry["models"][kind] = {"status": "experimental_specialist", "training": model["training"]}
            except ValueError as error:
                entry["models"][kind] = {"status": "generic_fallback", "reason": str(error)}
    behavior = json.loads((base / "behavior-split.json").read_text(encoding="utf-8"))
    # Some behavior frames were not sampled for terminal labels. Recover their
    # public leader combination from the same replay/seat, never another game.
    replay_contexts = defaultdict(dict)
    for (group, _, seat), ctx in contexts.items():
        replay_contexts[(group, seat)][ctx.get("key", "")] = ctx
    for row in behavior["records"]:
        options = replay_contexts[(row["group"], row["seat"])]
        row["matchup"] = contexts.get((row["group"], row["frame_index"], row["seat"]),
                                      next(iter(options.values())) if len(options) == 1 else {})
    save(output / "behavior-classified.json", behavior)
    save(output / "outcomes-classified.json", outcomes)
    save(output / "preferences-classified.json", preferences)
    for kind, bundle in bundles.items():
        save(output / f"{kind}-models.json", bundle)
    save(output / "classification-report.json", report)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("corpus", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--epochs", type=int, default=150)
    parser.add_argument("--min-train-replays", type=int, default=2)
    args = parser.parse_args()
    report = train(args.corpus, args.epochs, args.min_train_replays, args.output)
    print(json.dumps({key: {"samples": r["samples"], "pairs": r["pairs"],
                           "models": {k: m["status"] for k, m in r["models"].items()}}
                      for key, r in report["classes"].items()}, ensure_ascii=False))
