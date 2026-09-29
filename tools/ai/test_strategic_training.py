"""Meaningful contracts for expanded features, chronological splits and user constraints."""
import copy
import unittest
from train_value import STRATEGIC_FEATURES, FEATURE_SCHEMA, fit
from train_preferences import fit as preference_fit
from train_replay_corpus import split


def outcomes():
    samples = []
    for group, seed in (("a" * 64, 1), ("b" * 64, 1000)):
        for seat in (0, 1):
            features = dict.fromkeys(STRATEGIC_FEATURES, 0.)
            features["life_margin"] = 5. if seat == 0 else -5.
            samples.append({"group":group, "seed":seed, "episode":f"{group}:game:{seat}",
                            "features":features, "status":"terminal", "outcome":1 if seat == 0 else -1})
    return {"schema":"multicolor.ai.episodes.v1", "feature_schema":FEATURE_SCHEMA,
            "replay_groups":["a" * 64, "b" * 64], "samples":samples,
            "games":[{"episode":g + ":game", "seed":s, "status":"terminal"} for g,s in (("a" * 64,1),("b" * 64,1000))]}


class StrategicTraining(unittest.TestCase):
    def test_expanded_artifact_and_training_only_scales(self):
        data = outcomes()
        first = fit(data, 10)
        self.assertEqual(first["schema"], "multicolor.ai.value.v2")
        self.assertEqual(set(first["weights"]), set(STRATEGIC_FEATURES))
        for row in data["samples"]:
            if row["seed"] >= 1000:
                row["features"]["life_margin"] *= 100000
        second = fit(data, 10)
        self.assertEqual(first["scales"], second["scales"])
        self.assertEqual(first["weights"], second["weights"])

    def test_whole_replay_split_keeps_seats_together(self):
        data = outcomes()
        preferences = {"pairs":[], "demonstrations":[]}
        remapped, _ = split(data, preferences, {"a" * 64})
        for group in data["replay_groups"]:
            seeds = {r["seed"] for r in remapped["samples"] if r["group"] == group}
            self.assertEqual(len(seeds), 1)
            self.assertEqual(next(iter(seeds)) >= 1000, group == "a" * 64)

    def test_pressure_sign_constraints_prevent_reversing_user_goal(self):
        zero = dict.fromkeys(STRATEGIC_FEATURES, 0.)
        # A deliberately contradictory weak label cannot make greater opponent
        # life desirable when the user explicitly requested life pressure.
        pairs = [{"group":g, "preferred":dict(zero, opponent_life=20.),
                  "alternative":dict(zero, opponent_life=10.), "confidence":"medium"}
                 for g in ("a", "b")]
        data = {"schema":"multicolor.ai.preferences.v1", "feature_schema":FEATURE_SCHEMA,
                "rules_hash":"fixture", "validation_groups":["b"], "pairs":pairs,
                "weight_constraints":{"opponent_life":"nonpositive"}}
        result = preference_fit(data, 20)
        self.assertLessEqual(result["weights"]["opponent_life"], 0.)
        self.assertEqual(result["training"]["validation"]["strict_preference_accuracy"], 0.)
        self.assertEqual(result["promotion"], "experimental_only")

    def test_unfinished_game_without_outcome_positions_keeps_group(self):
        data = outcomes()
        data["samples"] = [r for r in data["samples"] if r["group"] != "b" * 64]
        data["games"][1]["status"] = "unfinished"
        result, _ = split(data, {"pairs":[], "demonstrations":[]}, {"b" * 64})
        self.assertGreaterEqual(result["games"][1]["seed"], 1000)

    def test_missing_expanded_feature_fails_instead_of_zero_filling(self):
        data = outcomes()
        del data["samples"][0]["features"]["required_gungnir_reserve"]
        with self.assertRaisesRegex(ValueError, "feature vector"):
            fit(data)


if __name__ == "__main__":
    unittest.main()
