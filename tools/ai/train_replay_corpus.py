"""Train recent replay features with a frozen chronological, whole-replay split.

The 9-feature baseline and 36-feature candidate use identical examples and splits.
Reviewed route preferences remain distinct from recorded behavior and outcomes.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from prepare_human_training import prepare
from train_value import fit as fit_outcomes, FEATURE_SCHEMA, FEATURES, STRATEGIC_FEATURES
from train_preferences import fit as fit_preferences


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def split(outcomes, preferences, heldout):
    outcomes, preferences = copy.deepcopy(outcomes), copy.deepcopy(preferences)
    ordered = outcomes["replay_groups"]
    ids = {g: (1000 + ordered.index(g) if g in heldout else ordered.index(g) + 1) for g in ordered}
    for row in outcomes["samples"]:
        row["seed"] = ids[row["group"]]
    for game in outcomes["games"]:
        game["seed"] = ids[game["episode"].split(":", 1)[0]]
    for collection in ("pairs", "demonstrations"):
        for row in preferences[collection]:
            row["seed"] = ids[row["group"]]
    for dataset in (outcomes, preferences):
        dataset["validation_groups"] = sorted(heldout)
    return outcomes, preferences


def prepare_corpus(base, heldout_count=3):
    manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    if manifest["failures"]:
        raise ValueError("Extraction checks failed")
    documents = [json.loads((base / "annotations" / Path(r["annotation_file"]).name).read_text(encoding="utf-8"))
                 for r in manifest["replays"] if r["samples"]]
    for doc in documents:
        for row in doc["annotations"]:
            reserve = any(tag.startswith("reserve_gungnir") for tag in row.get("tags", []))
            teacher, comparison = row.get("teacher_action", {}), row.get("comparison_action", {})
            if (reserve and row["features"]["upcoming_gungnir_threat"] == 0
                    and teacher.get("action", {}).get("kind") == "pass"
                    and comparison.get("action", {}).get("card_id") in ("169", "129", "spell-fdf-037")):
                row["teacher_action"], row["comparison_action"] = comparison, teacher
                row["confidence"] = "medium"
                row["tags"].append("user_directive_overrides_unforecast_reserve")
                row["annotation_source"]["latest_user_directive"] = "Prioritize life pressure and Castle/bats; no forced reserve without forecast high-risk entry"
            if "user_directive_overrides_unforecast_reserve" in row.get("tags", []):
                row["annotation_source"]["kind"] = "latest_user_directive_override"
        stem = doc["replay"]["file"].removesuffix(".mreply") + "_" + doc["replay"]["sha256"][:12] + ".training.json"
        save(base / "annotations" / stem, doc)
    # Never silently mix recorded rule versions.
    outcomes, preferences = prepare(documents)
    mapping = {doc["replay"]["sha256"]: doc["replay"]["file"] for doc in documents}
    ordered = sorted(mapping, key=mapping.get)
    if len(ordered) <= heldout_count:
        raise ValueError("Need more independent replays than held-out groups")
    heldout = set(ordered[-heldout_count:])
    outcomes, preferences = split(outcomes, preferences, heldout)
    preferences["weight_constraints"] = {"opponent_life":"nonpositive", "aura_haste_damage":"nonnegative",
                                          "required_gungnir_reserve":"nonnegative", "needless_gungnir_reserve":"nonpositive",
                                          "queen_combo_ready":"nonnegative"}
    for data in (outcomes, preferences):
        data["extraction_provenance"] = {k: manifest[k] for k in ("feature_code_hash", "action_code_hash", "extraction_hash")}
        root = Path(__file__).resolve().parents[2]
        data["extraction_provenance"]["pressure_code_hash"] = hashlib.sha256((root / "scripts/ai/pressure_policy.gd").read_bytes()).hexdigest()
        data["extraction_provenance"]["preparation_code_hash"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    return outcomes, preferences, mapping, heldout


def train(base, epochs=150, heldout_count=3):
    outcomes, preferences, mapping, heldout = prepare_corpus(base, heldout_count)
    save(base / "outcomes.json", outcomes)
    save(base / "preferences.json", preferences)
    summary = {"schema": "multicolor.ai.training_report.v2", "feature_count": len(STRATEGIC_FEATURES),
               "replays": len(mapping), "samples": len(outcomes["samples"]), "pairs": len(preferences["pairs"]),
               "split": f"last {heldout_count} chronological replays held out; both seats and all frames stay grouped",
               "train_replays": [mapping[g] for g in sorted(set(mapping) - heldout, key=mapping.get)],
               "validation_replays": [mapping[g] for g in sorted(heldout, key=mapping.get)],
               "promotion": "experimental_only", "default_ai_changed": False, "models": {},
               "limits": ["Reviewed older validation examples informed feature design; do not claim untouched generalization.",
                          "Terminal accuracy measures correlated positions, not playing strength.",
                          "No hypothetical branch is relabeled as a recorded win.",
                          "Behavior payment plans were not recorded; labels accept all matching payment variants.",
                          "Main-decision environment uses frozen AI in response/choice windows."]}
    for name, schema in (("baseline", "multicolor.ai.value.v1"), ("strategic", FEATURE_SCHEMA)):
        source = copy.deepcopy(outcomes)
        source["feature_schema"] = schema
        model = fit_outcomes(source, epochs)
        save(base / (name + "-outcome-value.json"), model)
        summary["models"][name + "_outcome"] = model["training"]
        source = copy.deepcopy(preferences)
        source["feature_schema"] = schema
        try:
            pref = fit_preferences(source, epochs)
            save(base / (name + "-preference-value.json"), pref)
            keys = STRATEGIC_FEATURES if schema == FEATURE_SCHEMA else FEATURES
            ranking = []
            for pair in source["pairs"]:
                margin = sum(pref["weights"][k] * (pair["preferred"][k] - pair["alternative"][k]) for k in keys)
                ranking.append({"replay": mapping[pair["group"]], "group": pair["group"],
                                "frame": pair["frame_index"], "seat": pair["seat"],
                                "heldout": pair["group"] in heldout, "margin": margin,
                                "preferred_ranked_higher": margin > 0})
            source_counts = {}
            for pair, rank in zip(source["pairs"], ranking):
                key = ("validation:" if rank["heldout"] else "train:") + pair.get("label_source", "human_review")
                count = source_counts.setdefault(key, {"pairs":0,"correct":0})
                count["pairs"] += 1
                count["correct"] += rank["preferred_ranked_higher"]
            summary["models"][name + "_preference"] = {**pref["training"], "ranking": ranking, "by_label_source":source_counts}
        except ValueError as error:
            summary["models"][name + "_preference"] = {"unavailable": str(error)}
    behavior = json.loads((base / "behavior.json").read_text(encoding="utf-8"))
    for row in behavior["records"]:
        row["split"] = "validation" if row["group"] in heldout else "train"
    behavior["validation_groups"] = sorted(heldout)
    behavior["training_groups"] = sorted(set(mapping) - heldout)
    save(base / "behavior-split.json", behavior)
    summary["behavior_records"] = len(behavior["records"])
    save(base / "training-results.json", summary)
    from train_matchups import train as train_matchups
    matchup_report = train_matchups(base, epochs)
    summary["matchup_classes"] = len(matchup_report["classes"])
    summary["matchup_report"] = "matchups/classification-report.json"
    save(base / "training-results.json", summary)
    compact = {k: summary[k] for k in ("replays", "samples", "pairs", "feature_count", "behavior_records")}
    compact["models"] = {name:{k:model.get(k) for k in ("train", "validation", "by_label_source", "unavailable") if k in model}
                         for name, model in summary["models"].items()}
    print(json.dumps(compact, ensure_ascii=False))
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("corpus", type=Path)
    parser.add_argument("--epochs", type=int, default=150)
    args = parser.parse_args()
    train(args.corpus, args.epochs)
