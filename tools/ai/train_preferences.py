"""Fit experimental value weights to human route preferences, split by replay.

This learns numerical endpoint ranking, not natural-language strategy or a full policy.
"""
import argparse
import hashlib
import json
import math
import random
from pathlib import Path

from prepare_human_training import vector
from train_value import FEATURES, STRATEGIC_FEATURES, feature_keys, sigmoid


def fit(data, epochs=150):
    if data.get("schema") != "multicolor.ai.preferences.v1":
        raise ValueError("Unsupported preference schema")
    if epochs < 1:
        raise ValueError("epochs must be positive")
    heldout = data.get("validation_groups", [])
    if not isinstance(heldout, list):
        raise ValueError("Invalid validation groups")
    pairs = data["pairs"]
    keys = feature_keys(data)
    rows = []
    for pair in pairs:
        better, worse = vector(pair["preferred"],keys), vector(pair["alternative"],keys)
        delta = [better[key] - worse[key] for key in keys]
        if pair.get("confidence") not in ("high", "medium", "low"):
            raise ValueError("Unknown confidence label")
        # Identical representations cannot learn this preference.
        if any(delta):
            rows.append((pair, delta))
    train = [row for row in rows if row[0]["group"] not in heldout]
    validation = [row for row in rows if row[0]["group"] in heldout]
    if not train or not validation:
        raise ValueError("Need usable preference pairs in separate training and validation replays")
    scales = {key: max(1.0, math.sqrt(sum(delta[i]**2 for _,delta in train)/len(train)))
              if keys == STRATEGIC_FEATURES else 20.0 for i,key in enumerate(keys)}
    train = [(pair, [d/scales[k] for k,d in zip(keys,delta)]) for pair,delta in train]
    validation = [(pair, [d/scales[k] for k,d in zip(keys,delta)]) for pair,delta in validation]
    weights, rng = [0.0] * len(keys), random.Random(7)
    counts = {}
    for pair, _ in train:
        counts[pair["group"]] = counts.get(pair["group"], 0) + 1
    for epoch in range(epochs):
        rng.shuffle(train)
        rate = .2 / (1 + epoch * .015)
        for pair, delta in train:
            prediction = sigmoid(sum(a * b for a, b in zip(weights, delta)))
            importance = {"high": 1.0, "medium": .5, "low": .2}[pair["confidence"]]
            importance *= len(train) / (len(counts) * counts[pair["group"]])
            for i in range(len(weights)):
                weights[i] -= rate * ((prediction - 1) * delta[i] * importance + .002 * weights[i])
                sign = data.get("weight_constraints", {}).get(keys[i])
                if sign == "nonnegative":weights[i] = max(0.0, weights[i])
                if sign == "nonpositive":weights[i] = min(0.0, weights[i])

    def metrics(group):
        probabilities = [sigmoid(sum(a * b for a, b in zip(weights, delta))) for _, delta in group]
        return {"pairs": len(group), "cross_entropy": sum(-math.log(max(p, 1e-12)) for p in probabilities) / len(group),
                "strict_preference_accuracy": sum(p > .5 for p in probabilities) / len(group)}

    return {"schema": "multicolor.ai.value.v2" if keys == STRATEGIC_FEATURES else "multicolor.ai.value.v1",
            "feature_schema":data.get("feature_schema","multicolor.ai.value.v1"), "scales":scales,
            "weight_constraints":data.get("weight_constraints", {}),
            "weights": {key:weight/scales[key] for key,weight in zip(keys,weights)},
            "dataset_hash": hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest(),
            "provenance": {"rules_hash": data["rules_hash"], "mode": "human_preference"},
            "training": {"method": "pairwise_logistic_preference", "epochs": epochs,
                         "train_groups": sorted(counts), "validation_groups": data["validation_groups"],
                         "train": metrics(train), "validation": metrics(validation),
                         "indistinguishable_pairs": len(pairs) - len(rows),
                         "warnings": ["Experimental ranking weights; promotion requires independent arena evaluation."]},
            "promotion": "experimental_only"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=150)
    args = parser.parse_args()
    try:
        data = json.loads(args.dataset.read_text(encoding="utf-8"))
        artifact = fit(data, args.epochs)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(artifact, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(artifact["training"], ensure_ascii=False))


if __name__ == "__main__":
    main()
