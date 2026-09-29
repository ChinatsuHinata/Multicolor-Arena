"""Public leader classification and fail-closed experimental model routing."""
import json
import math
from pathlib import Path

from train_value import FEATURES, STRATEGIC_FEATURES

SCHEMA = "multicolor.ai.matchup_models.v1"
CONTEXT_SCHEMA = "multicolor.ai.matchup.v1"


def leader_ids(leaders, cards=None):
    ids = []
    for card in leaders:
        if not isinstance(card, dict):
            return []
        card_id = card.get("copy_original", card.get("habitat_base", card.get("card_id", "")))
        card_id = (cards or {}).get(card_id, {}).get("canonical_id", card_id)
        if not isinstance(card_id, str) or card_id in ("", "back"):
            return []
        ids.append(card_id)
    return sorted(ids)


def identify(observation, seat=None, cards=None):
    seat = observation.get("seat") if seat is None else seat
    players = observation.get("players", [])
    own, enemy = [], []
    if seat in (0, 1) and len(players) == 2:
        own = leader_ids(players[seat].get("leaders", []), cards)
        enemy = leader_ids(players[1-seat].get("leaders", []), cards)
    own_key, enemy_key = "+".join(own), "+".join(enemy)
    return {"schema": CONTEXT_SCHEMA, "own_leaders": own, "opponent_leaders": enemy,
            "own_key": own_key, "opponent_key": enemy_key,
            "key": own_key + "::" + enemy_key if own and enemy else ""}


def validate_weights(model):
    if not isinstance(model, dict):
        return {}
    keys = {"multicolor.ai.value.v1": FEATURES, "multicolor.ai.value.v2": STRATEGIC_FEATURES}.get(model.get("schema"))
    weights = model.get("weights")
    if not keys or not isinstance(weights, dict):
        return {}
    if any(isinstance(weights.get(k), bool) or not isinstance(weights.get(k), (int, float))
           or not math.isfinite(weights[k]) or abs(weights[k]) > 10000 for k in keys):
        return {}
    return dict(weights)


def load_model(path):
    model = json.loads(Path(path).read_text(encoding="utf-8"))
    if model.get("schema") == SCHEMA:
        if not validate_weights(model.get("generic")) or not isinstance(model.get("specialists"), dict):
            raise ValueError("Invalid matchup model bundle")
        return model
    weights = validate_weights(model)
    if not weights:
        raise ValueError("Invalid value model")
    return weights


def select(model, observation, seat=None):
    matchup = identify(observation, seat)
    result = {"matchup": matchup, "source": "generic", "reason": "unclassified_weights", "weights": model}
    if model.get("schema") != SCHEMA:
        return result
    result.update(weights=validate_weights(model.get("generic")),
                  reason="unknown_opponent" if not matchup["key"] else "no_specialist")
    candidate = model.get("specialists", {}).get(matchup["key"], {})
    if not isinstance(candidate, dict) or not candidate:
        return result
    if candidate.get("matchup", {}).get("key") != matchup["key"]:
        result["reason"] = "mismatched_specialist"
        return result
    weights = validate_weights(candidate)
    if not weights or candidate.get("schema") != model["generic"].get("schema"):
        result["reason"] = "invalid_specialist"
        return result
    result.update(weights=weights, source="specialist", reason="known_matchup")
    return result
