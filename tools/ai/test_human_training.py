"""Contract checks; synthetic labels are not evidence of strength."""
import copy
import unittest

from prepare_human_training import prepare
from train_preferences import fit
from train_value import FEATURES, fit as fit_outcomes


def fixture(group, seat=0):
    features = dict.fromkeys(FEATURES, 0)
    better = dict(features, board_margin=8)
    return {"schema": "multicolor.ai.human_annotations.v1",
            "replay": {"sha256": group * 64, "rules_hash": "same-rules"},
            "annotations": [{"group": group * 64, "frame_index": 3, "seat": seat,
                             "game_id": "game", "turn": 5, "status": "terminal",
                             "outcome": 1 if seat == 0 else -1, "features": features,
                             "observation": {}, "confidence": "high", "hindsight": False,
                             "comment": "教师点评", "recommended_text": "先展开",
                             "teacher_action": {"action": {"kind": "cast", "uid": 42},
                                                "features": better, "endpoint_complete": True,
                                                "endpoint_policy": "public_heuristic_v1"},
                             "comparison_action": {"action": {"kind": "pass"}, "features": features,
                                                   "endpoint_complete": True,
                                                   "endpoint_policy": "public_heuristic_v1"}}]}


class HumanTraining(unittest.TestCase):
    def test_replay_grouping_and_actual_outcomes(self):
        a, b = fixture("a"), fixture("b")
        second = copy.deepcopy(a["annotations"][0]); second.update(seat=1, outcome=-1)
        a["annotations"].append(second)
        outcomes, preferences = prepare([a, b])
        self.assertEqual(outcomes["samples"][0]["seed"], outcomes["samples"][1]["seed"])
        self.assertEqual(preferences["validation_groups"], ["b" * 64])
        self.assertEqual([row["outcome"] for row in outcomes["samples"]], [1, -1, 1])
        self.assertEqual(fit_outcomes(outcomes, 5)["promotion"], "experimental_only")

    def test_preference_training_and_reproducibility(self):
        _, data = prepare([fixture("a"), fixture("b")])
        artifact = fit(data, 30)
        self.assertGreater(artifact["weights"]["board_margin"], 0)
        self.assertEqual(artifact, fit(data, 30))
        self.assertEqual(artifact["training"]["validation"]["strict_preference_accuracy"], 1)

    def test_hindsight_and_unfinished_game(self):
        a, b = fixture("a"), fixture("b")
        a["annotations"][0]["hindsight"] = True
        b["annotations"][0].update(status="unfinished", outcome=None)
        outcomes, preferences = prepare([a, b])
        self.assertFalse(outcomes["samples"])
        self.assertEqual(len(preferences["pairs"]), 1)
        self.assertEqual(len(outcomes["ignored"]), 2)

    def test_no_fabricated_pair_from_text_or_incomplete_endpoint(self):
        a, b = fixture("a"), fixture("b")
        a["annotations"][0]["teacher_action"] = {}
        b["annotations"][0]["teacher_action"]["endpoint_complete"] = False
        _, preferences = prepare([a, b])
        self.assertFalse(preferences["pairs"])
        self.assertEqual(len(preferences["demonstrations"]), 1)

    def test_bad_inputs_and_insufficient_independent_replays(self):
        a = fixture("a")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            prepare([a, a])
        b = fixture("b"); b["replay"]["rules_hash"] = "other-rules"
        with self.assertRaisesRegex(ValueError, "rules"):
            prepare([a, b])
        _, preferences = prepare([a])
        with self.assertRaisesRegex(ValueError, "separate"):
            fit(preferences)
        b = fixture("b"); b["annotations"][0]["features"]["mana"] = float("nan")
        with self.assertRaisesRegex(ValueError, "feature"):
            prepare([a, b])

    def test_random_endpoint_provenance(self):
        a, b = fixture("a"), fixture("b")
        for doc in (a, b):
            for key in ("teacher_action", "comparison_action"):
                doc["annotations"][0][key].update(rng_policy="public_sequence_seed_v1", rng_seed=42)
        _, preferences = prepare([a, b])
        self.assertEqual(preferences["pairs"][0]["rng_seed"], 42)
        b["annotations"][0]["comparison_action"]["rng_seed"] = 43
        with self.assertRaisesRegex(ValueError, "random scenario"):
            prepare([a, b])


if __name__ == "__main__":
    unittest.main()
