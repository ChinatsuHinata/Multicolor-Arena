"""Original bounded information-set UCT baseline using the Godot state API.

Each simulation resamples from explicit deck priors. Nodes are shared by player
and information history, never by true hidden hands. This searches the declared
main-decision abstraction; it is not an exact equilibrium or atomic-rule solver.
"""
import math
import random
import time

from train_value import FEATURES, EXTRA_FEATURES
from matchup_models import SCHEMA as MATCHUP_SCHEMA, select

BASE_WEIGHTS = dict(zip(FEATURES, [12., 2., 6., 35., 12., 10., -18., -5., 1.]))


class FeatureEvaluator:
    def __init__(self, weights=None):
        self.weights = weights or BASE_WEIGHTS

    def prior(self, state):
        actions = state.legal_actions()
        if not actions:
            return []
        if not hasattr(state, "menu"):
            return [(a, 1. / len(actions)) for a in actions]
        observation = state.observation()["observation"]
        player = state.current_player()
        if observation["players"][player]["leaders"][0]["card_id"] != "74":
            return [(a, 1. / len(actions)) for a in actions]
        f = state.features(player)
        descriptors = {row["id"]:row["action"] for row in state.menu()["actions"]}
        has_bats = any(a.get("card_id") in ("129", "spell-fdf-037") for a in descriptors.values())
        scores = {}
        for action in actions:
            a = descriptors[action]
            score = 1.
            if a.get("card_id") == "143" and a.get("target", {}).get("mode") == "失去生命":
                score = 200. if f["opponent_life"] <= 3 else 25. if f["opponent_life"] <= 12 else 4.
            elif a.get("card_id") == "169" and (has_bats or f["ready_damage"] > 0):
                score = 100.
            elif a.get("card_id") == "spell-fdf-037":
                score = 90. if f["castle_count"] > 0 or f["role_ready"] else 25.
            elif a.get("card_id") == "129":
                score = 45. if f["mana"] <= 4 else 20.
            elif a.get("kind") == "attack":
                score = 30.
            elif a.get("kind") == "pass":
                score = 75. if f["required_gungnir_reserve"] else .5
            scores[action] = score
        total = sum(scores.values())
        return [(a, scores[a] / total) for a in actions]

    def evaluate(self, state):
        if state.is_terminal():
            return state.returns()
        vectors = [state.features(p) for p in (0, 1)]
        weights = [select(self.weights, state.observation(p)["observation"], p)["weights"]
                   if self.weights.get("schema") == MATCHUP_SCHEMA else self.weights for p in (0, 1)]
        scores = [sum(float(vector.get(k, 0)) * model.get(k, 0)
                      for k in model) for vector, model in zip(vectors, weights)]
        # Exported learned coefficients are logits; legacy values have larger units.
        scale = 1. if any(k in weights[0] for k in EXTRA_FEATURES) else 150.
        value = math.tanh((scores[0] - scores[1]) / (2. * scale))
        return [value, -value]


def search(root, evaluator=None, simulations=32, max_depth=4, seed=7, uct_c=1.4, seconds=30):
    if simulations < 1 or max_depth < 1 or seconds <= 0:
        raise ValueError("Positive search budgets required")
    if root.is_terminal():
        raise ValueError("Cannot search a terminal state")
    evaluator = evaluator or FeatureEvaluator()
    rng = random.Random(seed)
    nodes, completed, errors = {}, 0, []
    root_key = (root.current_player(), root.information_state_string())
    root_actions = root.legal_actions()
    deadline = time.monotonic() + seconds
    start = time.monotonic()
    for _ in range(simulations):
        if time.monotonic() >= deadline:
            break
        world = None
        path = []
        try:
            world = root.sample(rng.randrange(1, 2**31))
            if (world.current_player(), world.information_state_string()) != root_key:
                raise ValueError("Sample changed root information state")
            for depth in range(max_depth):
                if world.is_terminal():
                    break
                if time.monotonic() >= deadline:
                    break
                key = (world.current_player(), world.information_state_string())
                node = nodes.setdefault(key, {"visits": 0, "actions": {}})
                actions = world.policy_actions()["ids"] if hasattr(world, "policy_actions") else world.legal_actions()
                if not actions:
                    raise ValueError("Nonterminal state has no supported actions")
                unvisited = [a for a in actions if not node["actions"].get(a, {}).get("visits", 0)]
                if unvisited:
                    priors = dict(evaluator.prior(world))
                    maximum = max(priors.get(a, 0.) for a in unvisited)
                    action = rng.choice([a for a in unvisited if priors.get(a, 0.) == maximum])
                else:
                    def ucb(action):
                        child = node["actions"][action]
                        return child["sum"] / child["visits"] + uct_c * math.sqrt(
                            math.log(max(1, node["visits"])) / child["visits"])
                    action = max(actions, key=ucb)
                child = node["actions"].setdefault(action, {"visits": 0, "sum": 0.})
                path.append((world.current_player(), node, child))
                world.apply_action(action)
                if unvisited:
                    # A bounded random continuation gives newly expanded routes
                    # an endpoint without treating a cutoff as a terminal draw.
                    for _ in range(max_depth - depth - 1):
                        if world.is_terminal() or time.monotonic() >= deadline:
                            break
                        rollout_actions = world.policy_actions()["ids"] if hasattr(world, "policy_actions") else world.legal_actions()
                        priors = dict(evaluator.prior(world))
                        world.apply_action(rng.choices(rollout_actions, weights=[priors.get(a, 1.) for a in rollout_actions])[0])
                    break
            reward = evaluator.evaluate(world)
            for player, node, child in path:
                node["visits"] += 1
                child["visits"] += 1
                child["sum"] += reward[player]
            completed += 1
        except (ValueError, RuntimeError) as error:
            errors.append(str(error))
        finally:
            if world:
                world.close()
    children = nodes.get(root_key, {}).get("actions", {})
    stats = [{"action": a, "visits": children.get(a, {}).get("visits", 0),
              "mean_value": children[a]["sum"] / children[a]["visits"]
              if children.get(a, {}).get("visits", 0) else None} for a in root_actions]
    explored = [row for row in stats if row["visits"]]
    if not explored:
        raise ValueError("No completed search branch: " + "; ".join(errors[:3]))
    best = max(explored, key=lambda row: (row["visits"], row["mean_value"]))
    return {"algorithm": "information_set_uct", "action": best["action"],
            "completed_simulations": completed, "nodes": len(nodes), "root_actions": stats,
            "milliseconds": round((time.monotonic() - start) * 1000),
            "menu_truncated": root.menu()["truncated"], "errors": errors,
            "budgets": {"simulations": simulations, "depth": max_depth, "seconds": seconds}}
