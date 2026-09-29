"""Integration tests run real Godot rules, not mocked state transitions."""
import unittest
from godot_env import GodotClient, RLCardDecisionEnv
from information_set_uct import search
from train_value import STRATEGIC_FEATURES


class AlgorithmBridge(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = GodotClient()

    @classmethod
    def tearDownClass(cls):
        cls.client.close()

    def test_rlcard_style_reset_step_back_and_visibility(self):
        env = RLCardDecisionEnv(self.client, seed=313)
        state, player = env.reset()
        self.assertEqual(len(state["obs"]), len(STRATEGIC_FEATURES))
        self.assertFalse(state["raw_obs"]["players"][1-player]["hand"])
        self.assertNotIn("deck", state["raw_obs"]["players"][0])
        before = env.state.information_state_string()
        action = next(iter(state["legal_actions"]))
        env.step(action)
        env.step_back()
        self.assertEqual(env.state.information_state_string(), before)
        self.assertFalse(env.get_payoffs())

    def test_search_resamples_worlds_and_executes_legal_decision(self):
        state = self.client.reset(seed=313)
        for _ in range(24):
            if len(state.legal_actions()) > 1:
                break
            state.apply_action(state.legal_actions()[0])
        self.assertGreater(len(state.legal_actions()), 1)
        before = state.information_state_string()
        result = search(state, simulations=8, max_depth=3, seconds=15, seed=17)
        self.assertEqual(result["completed_simulations"], 8)
        self.assertFalse(result["errors"])
        self.assertEqual(sum(row["visits"] for row in result["root_actions"]), 8)
        self.assertEqual(before, state.information_state_string())
        self.assertIn(result["action"], state.legal_actions())
        self.assertTrue(state.apply_action(result["action"])["complete"])

    def test_sampling_and_illegal_action_rejection(self):
        state = self.client.reset(seed=31)
        before = state.information_state_string()
        a, b = state.sample(917), state.sample(917)
        self.assertEqual(a.information_state_string(), before)
        self.assertEqual(a.observation_string(1-state.player), b.observation_string(1-state.player))
        with self.assertRaisesRegex(ValueError, "Illegal"):
            state.apply_action(-1)
        self.assertEqual(state.information_state_string(), before)
        a.close(); b.close(); state.close()


if __name__ == "__main__":
    unittest.main()
