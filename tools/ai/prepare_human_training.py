"""Convert replay annotations into outcome and explicit preference datasets.

Text stays as teacher commentary. It never becomes a fabricated win or action.
All seats, rounds and alternative actions from one replay share a split group.
"""
import argparse
import json
import math
from pathlib import Path

from train_value import FEATURES, feature_keys
from matchup_models import identify

SCHEMA = "multicolor.ai.human_annotations.v1"


def vector(value, keys=FEATURES):
    if not isinstance(value, dict) or any(
        key not in value or isinstance(value[key], bool)
        or not isinstance(value[key], (float, int)) or not math.isfinite(value[key])
        for key in keys
    ):
        raise ValueError("Invalid numerical feature vector")
    return {key: float(value[key]) for key in keys}


def prepare(documents):
    if not documents:
        raise ValueError("No annotation files supplied")
    schemas = {doc.get("feature_schema", "multicolor.ai.value.v1") for doc in documents}
    if len(schemas) != 1:
        raise ValueError("Do not mix feature schemas; re-extract older replays")
    schema = next(iter(schemas))
    keys = feature_keys({"feature_schema": schema})
    groups, rules, rows, seen = set(), set(), [], set()
    for doc in documents:
        if doc.get("schema") != SCHEMA or not isinstance(doc.get("annotations"), list):
            raise ValueError("Unsupported annotation schema")
        replay = doc.get("replay", {})
        group = replay.get("sha256", "")
        if len(group) != 64 or any(c not in "0123456789abcdef" for c in group):
            raise ValueError("Missing replay SHA-256 group")
        rules.add(replay.get("rules_hash", ""))
        groups.add(group)
        for row in doc["annotations"]:
            if row.get("seat") not in (0, 1) or row.get("group") != group:
                raise ValueError("Annotation seat or group does not match replay")
            key = (group, row["frame_index"], row["seat"])
            if key in seen:
                raise ValueError("Duplicate annotation; supply each replay once")
            seen.add(key)
            rows.append((group, row))
    if len(rules) != 1 or "" in rules:
        raise ValueError("Do not mix missing or different rules versions")
    ordered = sorted(groups)
    heldout = {ordered[-1]} if len(ordered) > 1 else set()
    seed_ids = {group: (1000 if group in heldout else i + 1) for i, group in enumerate(ordered)}
    samples, games, pairs, demonstrations, ignored = [], {}, [], [], []
    for group, row in rows:
        identity = {"group": group, "frame_index": row["frame_index"], "seat": row["seat"],
                    "matchup": identify(row.get("observation", {}), row["seat"])}
        if row.get("hindsight", False):
            ignored.append({**identity, "reason": "hindsight"})
            continue
        features = vector(row["features"], keys)
        sample = {**identity, "seed": seed_ids[group], "first": None,
                  "episode": f"{group}:{row['game_id']}:{row['seat']}",
                  "turn": row["turn"], "features": features,
                  "observation": row["observation"], "status": row["status"],
                  "outcome": row["outcome"], "comment": row.get("comment", ""),
                  "recommended_text": row.get("recommended_text", "")}
        if row["status"] == "terminal":
            if row["outcome"] not in (-1, 0, 1):
                raise ValueError("Terminal annotation must have an actual outcome")
            samples.append(sample)
        else:
            ignored.append({**identity, "reason": "no_actual_terminal_outcome"})
        game_key = f"{group}:{row['game_id']}"
        games[game_key] = {"episode": game_key, "seed": seed_ids[group], "status": row["status"]}
        teacher, comparison = row.get("teacher_action", {}), row.get("comparison_action", {})
        if teacher.get("action"):
            demonstrations.append({**sample, "action": teacher["action"],
                                   "confidence": row.get("confidence", "high")})
        if not teacher.get("action") or not comparison.get("action"):
            continue
        if teacher["action"] == comparison["action"]:
            raise ValueError("Preference requires two different actions")
        if not teacher.get("endpoint_complete") or not comparison.get("endpoint_complete"):
            ignored.append({**identity, "reason": "incomplete_preference_endpoint"})
            continue
        if teacher.get("endpoint_policy") != comparison.get("endpoint_policy"):
            raise ValueError("Preference endpoints must use the same policy")
        if (teacher.get("rng_policy") != comparison.get("rng_policy")
                or teacher.get("rng_seed") != comparison.get("rng_seed")):
            raise ValueError("Preference endpoints must use the same random scenario")
        pairs.append({**identity, "seed": seed_ids[group],
                      "preferred": vector(teacher["features"], keys),
                      "alternative": vector(comparison["features"], keys),
                      "confidence": row.get("confidence", "high"),
                      "endpoint_policy": teacher["endpoint_policy"],
                      "label_source":row.get("annotation_source",{}).get("kind","human_review")})
        if "rng_policy" in teacher:
            pairs[-1].update(rng_policy=teacher["rng_policy"], rng_seed=teacher["rng_seed"])
    provenance = {"rules_hash": next(iter(rules)), "mode": "human_replay", "feature_schema":schema,
                  "replay_groups": ordered, "validation_groups": sorted(heldout),
                  "ignored": ignored}
    outcomes = {"schema": "multicolor.ai.episodes.v1", **provenance,
                "samples": samples, "games": list(games.values())}
    preferences = {"schema": "multicolor.ai.preferences.v1", **provenance,
                   "pairs": pairs, "demonstrations": demonstrations}
    return outcomes, preferences


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("annotations", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preferences-output", required=True, type=Path)
    args = parser.parse_args()
    try:
        documents = [json.loads(path.read_text(encoding="utf-8")) for path in args.annotations]
        outcomes, preferences = prepare(documents)
        for path, data in [(args.output, outcomes), (args.preferences_output, preferences)]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({"outcome_samples": len(outcomes["samples"]),
                      "preference_pairs": len(preferences["pairs"]),
                      "demonstrations": len(preferences["demonstrations"]),
                      "replays": len(outcomes["replay_groups"]),
                      "ignored": len(outcomes["ignored"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
