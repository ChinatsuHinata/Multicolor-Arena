"""Fit a small outcome model from finished game trajectories, using only public features.

No third-party runtime is needed. Split by seed so mirrored games and adjacent
positions stay together. The artifact is experimental; promotion is a separate arena gate.
"""
import argparse
import json
import math
import random
import hashlib
from pathlib import Path

FEATURES = ["life_margin", "board_margin", "hand_margin", "role_ready", "color_sources",
            "ready_damage", "incoming_damage", "fragile_units", "mana"]
EXTRA_FEATURES = ["color_min_sources", "color_redundancy", "colors_after_one_damage",
                  "colors_after_two_damage", "leader_health", "leader_timer",
                  "leader_replay_ready", "leader_recovery_ready", "recovery_cards",
                  "hard_removal_cards", "gungnir_cards", "gungnir_payable",
                  "leader_response_reserve", "enemy_core_count", "enemy_core_value",
                  "enemy_small_bodies", "permanent_ready_damage", "temporary_ready_damage",
                  "castle_count", "queen_combo_ready", "free_field_slots", "hand_playable_count",
                  "upcoming_gungnir_threat", "required_gungnir_reserve", "needless_gungnir_reserve",
                  "aura_haste_damage", "opponent_life"]
STRATEGIC_FEATURES = FEATURES + EXTRA_FEATURES
FEATURE_SCHEMA = "multicolor.ai.features.v2"

def feature_keys(data):
    schema = data.get("feature_schema", "multicolor.ai.value.v1")
    if schema in ("multicolor.ai.value.v1", "multicolor.ai.features.v1"):
        return FEATURES
    if schema == FEATURE_SCHEMA:
        return STRATEGIC_FEATURES
    raise ValueError("Unsupported feature schema")

def sigmoid(x):
    x = max(-40.0, min(40.0, x))
    return 1.0 / (1.0 + math.exp(-x))

def metrics(rows, weights, keys=FEATURES, scales=None):
    if not rows:
        return None
    losses, right = [], 0
    for row in rows:
        x = [float(row["features"].get(k, 0)) / (scales[k] if scales else 20.0) for k in keys]
        probability = sigmoid(sum(a*b for a,b in zip(weights, x)))
        label = (float(row["outcome"]) + 1.0) / 2.0
        losses.append(-(label*math.log(max(probability,1e-12)) + (1-label)*math.log(max(1-probability,1e-12))))
        right += (probability >= .5) == (label >= .5)
    return {"positions":len(rows), "cross_entropy":sum(losses)/len(losses), "accuracy":right/len(rows)}

def fit(data, epochs=150, seed=7):
    if data.get("schema") != "multicolor.ai.episodes.v1":
        raise ValueError("Unsupported dataset schema")
    if epochs < 1:
        raise ValueError("epochs must be positive")
    keys = feature_keys(data)
    rows = [r for r in data["samples"] if r.get("status")=="terminal" and r.get("outcome") is not None]
    for row in rows:
        if row["outcome"] not in [-1, 0, 1] or any(k not in row["features"] or isinstance(row["features"][k], bool) or not math.isfinite(float(row["features"][k])) for k in keys):
            raise ValueError("Invalid outcome or feature vector")
    seeds = sorted({int(r["seed"]) for r in rows})
    if len(seeds) < 2:
        raise ValueError("At least two completed seed groups are required; truncated games cannot train a value model.")
    heldout = {s for s in seeds if s >= 1000}
    if not heldout:
        heldout = {seeds[-1]}
    train = [r for r in rows if int(r["seed"]) not in heldout]
    validation = [r for r in rows if int(r["seed"]) in heldout]
    if not train or not validation:
        raise ValueError("Both training and held-out seed groups must contain completed games.")
    def coverage(group):
        return {name:sum(r["outcome"]==value for r in group) for name,value in [("win",1),("loss",-1),("draw",0)]}
    train_coverage, validation_coverage = coverage(train), coverage(validation)
    if not train_coverage["win"] or not train_coverage["loss"]:
        raise ValueError("Training needs both wins and losses; collect both perspectives or stronger opponent diversity.")
    # One weight per position would let long games dominate. Balance episodes.
    counts = {}
    for row in train:
        counts[row["episode"]] = counts.get(row["episode"],0)+1
    # Derive feature scales exclusively from the training split.
    scales = {key: max(1.0, math.sqrt(sum(float(r["features"][key])**2 for r in train)/len(train)))
              if keys == STRATEGIC_FEATURES else 20.0 for key in keys}
    weights = [0.0]*len(keys)
    rng = random.Random(seed)
    order = list(train)
    for epoch in range(epochs):
        rng.shuffle(order)
        rate = .2 / (1 + epoch*.015)
        for row in order:
            x = [float(row["features"][k])/scales[k] for k in keys]
            prediction = sigmoid(sum(a*b for a,b in zip(weights,x)))
            label = (float(row["outcome"])+1)/2
            importance = len(train)/(len(counts)*counts[row["episode"]])
            for i in range(len(weights)):
                weights[i] -= rate * ((prediction-label)*x[i]*importance + .002*weights[i])
    # Export raw-feature coefficients so runtime scores equal the fitted logits.
    warnings = ["Smoke experiment only: fewer than 20 independent seed groups."] if len(seeds)<20 else []
    if not validation_coverage["win"] or not validation_coverage["loss"]:
        warnings.append("Held-out data lacks both outcome classes; accuracy is not a useful strength estimate.")
    artifact = {"schema":"multicolor.ai.value.v2" if keys == STRATEGIC_FEATURES else "multicolor.ai.value.v1",
                "feature_schema":data.get("feature_schema", "multicolor.ai.value.v1"),
                "weights":{key:w/scales[key] for key,w in zip(keys,weights)}, "scales":scales,
                "provenance":{k:data[k] for k in ["rules_hash","agent_hash","deck_hash","opponent_hash","weights_hash","mode","opponent_round","record_seats"] if k in data},
                "dataset_hash":hashlib.sha256(json.dumps(data,sort_keys=True,ensure_ascii=False).encode("utf-8")).hexdigest(),
                "training":{"method":"regularized_logistic_outcome", "epochs":epochs, "seed":seed,
                            "train_seeds":[s for s in seeds if s not in heldout], "validation_seeds":sorted(heldout),
                            "train":metrics(train,weights,keys,scales), "validation":metrics(validation,weights,keys,scales),
                            "train_outcomes":train_coverage, "validation_outcomes":validation_coverage,"warnings":warnings,
                            "completed_games":sum(g["status"]=="terminal" for g in data["games"]),
                            "excluded_games":sum(g["status"]!="terminal" for g in data["games"])},
                "promotion":"experimental_only"}
    return artifact

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("dataset",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--epochs",type=int,default=150)
    args=parser.parse_args()
    data=json.loads(args.dataset.read_text(encoding="utf-8"))
    if data.get("schema")!="multicolor.ai.episodes.v1":
        parser.error("Unsupported dataset schema")
    try:
        artifact=fit(data,args.epochs)
    except ValueError as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(artifact["training"],ensure_ascii=False))

if __name__=="__main__":
    main()
