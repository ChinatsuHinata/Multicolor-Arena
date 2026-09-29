"""Classification, fallback, per-perspective evaluation and replay isolation."""
import copy
import json
import tempfile
import unittest
from pathlib import Path

from matchup_models import SCHEMA, identify, select, load_model
from information_set_uct import FeatureEvaluator
from train_matchups import train, save
from train_value import STRATEGIC_FEATURES, FEATURE_SCHEMA


def observation(own="74", enemy="71", seat=0):
    players = [{"leaders": [{"card_id": own}]}, {"leaders": [{"card_id": enemy}]}]
    if seat:
        players.reverse()
    return {"seat": seat, "players": players}


def model(weight=1.):
    return {"schema": "multicolor.ai.value.v2", "weights": dict.fromkeys(STRATEGIC_FEATURES, weight),
            "promotion": "experimental_only"}


def bundle():
    specialist = model(2.)
    specialist["matchup"] = identify(observation())
    return {"schema": SCHEMA, "generic": model(), "specialists": {"74::71": specialist}}


class MatchupModels(unittest.TestCase):
    def test_public_identity_is_stable_across_copy_zone_control_and_art(self):
        obs = observation()
        obs["players"][1]["leaders"][0].update(card_id="temporary_copy", copy_original="71",
                                              zone="grave", owner=0, art_id="alternate")
        self.assertEqual(identify(obs)["key"], "74::71")
        obs["players"][0]["hand"] = [{"card_id": "private"}]
        self.assertEqual(identify(obs)["key"], "74::71")

    def test_double_leaders_and_seat_perspective(self):
        obs = observation(seat=1)
        obs["players"][0]["leaders"].append({"card_id": "70"})
        self.assertEqual(identify(obs)["key"], "74::70+71")
        obs["players"][0]["leaders"].reverse()
        self.assertEqual(identify(obs)["key"], "74::70+71")
        self.assertEqual(identify(obs, 0)["key"], "70+71::74")

    def test_specialist_requires_exact_own_and_opposing_leaders(self):
        data = bundle()
        self.assertEqual(select(data, observation())["source"], "specialist")
        for obs in (observation(enemy="new"), observation(own="70"), observation(enemy="back")):
            selected = select(data, obs)
            self.assertEqual(selected["source"], "generic")
            self.assertEqual(selected["weights"], data["generic"]["weights"])
        bad = copy.deepcopy(data)
        bad["specialists"]["74::71"]["weights"]["mana"] = float("nan")
        self.assertEqual(select(bad, observation())["reason"], "invalid_specialist")
        bad = copy.deepcopy(data)
        bad["specialists"]["74::71"]["matchup"]["key"] = "74::70"
        self.assertEqual(select(bad, observation())["reason"], "mismatched_specialist")

    def test_search_evaluator_routes_both_seats_without_breaking_zero_sum(self):
        class State:
            def is_terminal(self): return False
            def features(self, player): return {"life_margin": 1 if player == 0 else -1}
            def observation(self, player): return {"observation": observation()}
        rewards = FeatureEvaluator(bundle()).evaluate(State())
        self.assertGreater(rewards[0], 0)
        self.assertEqual(rewards[1], -rewards[0])

    def test_loader_retains_legacy_models_and_rejects_invalid_generic(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "models.json"
            save(path, model())
            self.assertEqual(load_model(path), model()["weights"])
            data = bundle()
            del data["generic"]["weights"]["mana"]
            save(path, data)
            with self.assertRaises(ValueError): load_model(path)

    def test_training_preserves_global_holdout_and_sparse_classes_fall_back(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            groups = [str(i) * 64 for i in range(1, 5)]
            samples, docs, manifest = [], [], []
            zero = dict.fromkeys(STRATEGIC_FEATURES, 0.)
            for i, group in enumerate(groups):
                rows = []
                for frame in (0, 1):
                    obs = observation(enemy="71" if i < 3 else "new")
                    row = {"group": group, "frame_index": frame, "seat": 0, "game_id": "game",
                           "episode": group + ":game:0", "seed": i+1 if i < 3 else 1000,
                           "status": "terminal", "outcome": 1 if frame == 0 else -1,
                           "features": dict(zero, life_margin=5. if frame == 0 else -5.), "observation": obs}
                    samples.append(row); rows.append(row)
                name = f"{i}.json"
                save(base / "annotations" / name, {"annotations": rows})
                manifest.append({"sha256": group, "file": f"2026-09-27T0{i}.mreply", "annotation_file": name})
            save(base / "outcomes.json", {"schema": "multicolor.ai.episodes.v1", "feature_schema": FEATURE_SCHEMA,
                                         "validation_groups": [groups[-1]], "samples": samples, "games": []})
            save(base / "preferences.json", {"schema": "multicolor.ai.preferences.v1", "feature_schema": FEATURE_SCHEMA,
                                            "rules_hash": "fixture", "validation_groups": [groups[-1]],
                                            "pairs": [], "demonstrations": []})
            save(base / "manifest.json", {"failures": [], "replays": manifest})
            save(base / "behavior-split.json", {"records": []})
            for kind in ("outcome", "preference"):
                save(base / f"strategic-{kind}-value.json", model())
            report = train(base, epochs=2)
            known = report["classes"]["74::71"]
            self.assertEqual(set(known["training_groups"]), set(groups[:2]))
            self.assertEqual(known["validation_groups"], [groups[2]])
            self.assertEqual(known["models"]["outcome"]["status"], "experimental_specialist")
            self.assertEqual(report["classes"]["74::new"]["training_groups"], [])
            data = json.loads((base / "matchups/outcome-models.json").read_text(encoding="utf-8"))
            self.assertEqual(set(data["specialists"]), {"74::71"})
            self.assertEqual(select(data, observation(enemy="new"))["source"], "generic")


if __name__ == "__main__":
    unittest.main()
