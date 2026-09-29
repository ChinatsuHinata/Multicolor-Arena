"""Run a real search decision through Godot, or optionally upstream OpenSpiel ISMCTS.

The optional path imports the installed upstream package directly; no third-party
algorithm is copied, and no package is silently installed.
"""
import argparse
import json
import random
import time
from pathlib import Path

from godot_env import GodotClient
from information_set_uct import search, FeatureEvaluator
from matchup_models import load_model, select


def run(algorithm="uct", simulations=32, depth=4, weights_path=None, seed=313):
    weights = load_model(weights_path) if weights_path else None
    evaluator = FeatureEvaluator(weights)
    with GodotClient() as client:
        state = client.reset(seed=seed)
        for _ in range(24):
            if state.is_terminal() or len(state.legal_actions()) > 1:
                break
            state.apply_action(state.legal_actions()[0])
        if state.is_terminal() or len(state.legal_actions()) < 2:
            raise ValueError("Demo did not reach a choice between multiple actions")
        root_before = state.information_state_string()
        routing = select(weights or {}, state.observation()["observation"], state.player)
        routing.pop("weights")
        owned_states = set(client.states)
        if algorithm == "uct":
            result = search(state, evaluator, simulations, depth, seed=seed)
        else:
            try:
                import numpy as np
                from open_spiel.python.algorithms import ismcts
            except ImportError as error:
                raise ValueError("Optional upstream OpenSpiel package is not installed in this Python runtime") from error
            rng = np.random.RandomState(seed)
            bot = ismcts.ISMCTSBot(state.get_game(), evaluator, 1.4, simulations,
                                   random_state=rng, allow_inconsistent_action_sets=True)
            bot.set_resampler(lambda original, player: original.sample(int(rng.randint(1, 2**31)), player))
            start = time.monotonic()
            policy, action = bot.step_with_policy(state)
            result = {"algorithm": "upstream_open_spiel.ISMCTSBot", "action": int(action),
                      "policy": [(int(a), float(p)) for a, p in policy],
                      "milliseconds": round((time.monotonic() - start) * 1000)}
        for state_id in client.states - owned_states:
            client.release(state_id)
        assert state.information_state_string() == root_before, "Search mutated live root"
        result["chosen_action"] = json.loads(state.action_to_string(state.player, result["action"]))
        result["root_player"] = state.player
        result["model_routing"] = routing
        result["legal_action_count"] = len(state.legal_actions())
        result["feature_count"] = len(state.features(state.player))
        result["transition"] = state.apply_action(result["action"])
        result["environment"] = client.description
        return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--algorithm", choices=("uct", "openspiel"), default="uct")
    parser.add_argument("--simulations", type=int, default=32)
    parser.add_argument("--depth", type=int, default=4)
    parser.add_argument("--weights", type=Path)
    parser.add_argument("--seed", type=int, default=313)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = run(args.algorithm, args.simulations, args.depth, args.weights, args.seed)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
