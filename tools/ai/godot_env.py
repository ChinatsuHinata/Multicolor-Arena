"""Persistent loopback bridge to the authoritative Godot main-decision environment.

Planning MUST call sample(): clone() alone keeps the offline simulator's hidden
world. Chance is sampled inside Godot, and response choices use a frozen policy.
"""
import json
import os
import secrets
import socket
import subprocess
import time
from collections import OrderedDict
from pathlib import Path
from types import SimpleNamespace

from train_value import STRATEGIC_FEATURES

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DECK = "res://deck/未命名卡组_7c906ca3ca80.mdeck"


class GodotClient:
    def __init__(self, root=ROOT, executable=None, timeout=30):
        self.root = Path(root)
        executable = executable or self.root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
        self.token = secrets.token_hex(24)
        self.states = set()
        self.log_path = self.root / "work" / ("ai-env-" + self.token[:8] + ".log")
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.process_log = self.log_path.open("wb")
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        self.process = subprocess.Popen(
            [str(executable), "--headless", "--path", str(self.root),
             "--script", "res://tools/ai/environment_server.gd", "--",
             f"--port={port}", f"--token={self.token}"],
            cwd=self.root, stdout=self.process_log, stderr=subprocess.STDOUT,
            creationflags=flags)
        deadline = time.monotonic() + timeout
        while True:
            try:
                self.socket = socket.create_connection(("127.0.0.1", port), timeout=timeout)
                self.socket.settimeout(timeout)
                self.stream = self.socket.makefile("rwb")
                break
            except OSError:
                if self.process.poll() is not None or time.monotonic() >= deadline:
                    self.process.terminate()
                    self.process.wait(timeout=5)
                    self.process_log.close()
                    diagnostics = self.log_path.read_text(encoding="utf-8", errors="replace")[-3000:]
                    raise RuntimeError("Godot environment failed to start: " + diagnostics)
                time.sleep(.05)
        self.description = self.request("describe")

    def request(self, op, **fields):
        self.stream.write((json.dumps({"op": op, "token": self.token, **fields},
                                      ensure_ascii=False) + "\n").encode("utf-8"))
        self.stream.flush()
        line = self.stream.readline()
        if not line:
            raise RuntimeError("Godot environment disconnected")
        result = json.loads(line)
        if "error" in result:
            raise ValueError(result["error"])
        return result

    def state(self, result):
        self.states.add(result["state"])
        return RemoteState(self, result)

    def reset(self, decks=(DEFAULT_DECK, DEFAULT_DECK), first=0, seed=7):
        return self.state(self.request("reset", decks=list(decks), first=first, seed=seed))

    def load_replay(self, path, frame, priors=()):
        return self.state(self.request("load_replay", path=path, frame=frame, priors=list(priors)))

    def release(self, state_id):
        if state_id in self.states:
            self.request("release", state=state_id)
            self.states.remove(state_id)

    def close(self):
        try:
            if hasattr(self, "stream"):
                self.request("shutdown")
        except (OSError, ValueError, RuntimeError):
            pass
        finally:
            if hasattr(self, "stream"):
                self.stream.close()
                self.socket.close()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)
            self.process_log.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


class RemoteState:
    def __init__(self, client, result):
        self.client, self.id = client, result["state"]
        self.terminal, self.player = result["terminal"], result["current_player"]
        self._menu = None

    def current_player(self):
        return self.player

    def is_terminal(self):
        return self.terminal

    def is_chance_node(self):
        # RNG is a sampled transition, NOT an explicitly enumerated chance node.
        return False

    def get_game(self):
        import pyspiel  # optional upstream integration; native UCT needs no package
        return SimpleNamespace(get_type=lambda: SimpleNamespace(
            dynamics=pyspiel.GameType.Dynamics.SEQUENTIAL,
            information=pyspiel.GameType.Information.IMPERFECT_INFORMATION))

    def menu(self):
        if self._menu is None:
            self._menu = self.client.request("legal_actions", state=self.id)
        return self._menu

    def legal_actions(self, player=None):
        if player is not None and player != self.player:
            return []
        return [row["id"] for row in self.menu()["actions"]]

    def policy_actions(self):
        return self.client.request("policy_actions", state=self.id)

    def action_to_string(self, player, action):
        return json.dumps(next(r["action"] for r in self.menu()["actions"] if r["id"] == action), ensure_ascii=False)

    def observation(self, player=None):
        player = self.player if player is None else player
        return self.client.request("observation", state=self.id, player=player)

    def information_state_string(self, player=None):
        return self.observation(player)["information_state"]

    def observation_string(self, player=None):
        return json.dumps(self.observation(player)["observation"], sort_keys=True, ensure_ascii=False)

    def observation_tensor(self, player=None):
        features = self.features(self.player if player is None else player)
        return [features[k] for k in STRATEGIC_FEATURES]

    def features(self, player):
        return self.client.request("features", state=self.id, player=player)["features"]

    def clone(self):
        return self.client.state(self.client.request("clone", state=self.id))

    def sample(self, seed, player=None):
        player = self.player if player is None else player
        return self.client.state(self.client.request("sample", state=self.id, player=player, seed=seed))

    def apply_action(self, action):
        result = self.client.request("step", state=self.id, action=int(action))
        self.terminal, self.player = result["terminal"], result["current_player"]
        self._menu = None
        return result

    def returns(self):
        return self.client.request("returns", state=self.id)["returns"]

    def close(self):
        self.client.release(self.id)


class RLCardDecisionEnv:
    """RLCard-shaped MAIN-DECISION API, not a registered full RLCard game.

    Legal action ids are sparse and dynamic; DQN/PPO must encode candidate action
    descriptors rather than allocating a fixed 2**48 output layer.
    """
    num_players = 2

    def __init__(self, client, decks=(DEFAULT_DECK, DEFAULT_DECK), seed=7):
        self.client, self.decks, self.seed = client, decks, seed
        self.state = None
        self.history = []

    def reset(self):
        if self.state:
            self.state.close()
        for previous in self.history:
            previous.close()
        self.history = []
        self.state = self.client.reset(self.decks, seed=self.seed)
        return self.get_state(self.state.player), self.state.player

    def get_state(self, player_id):
        return {"obs": self.state.observation_tensor(player_id),
                "raw_obs": self.state.observation(player_id)["observation"],
                "legal_actions": OrderedDict((a, None) for a in self.state.legal_actions(player_id)),
                "raw_legal_actions": self.state.menu()["actions"],
                "action_space_truncated": self.state.menu()["truncated"]}

    def step(self, action):
        previous = self.state.clone()
        try:
            self.state.apply_action(action)
        except Exception:
            previous.close()
            raise
        self.history.append(previous)
        return self.get_state(max(0, self.state.player)), self.state.player

    def step_back(self):
        if not self.history:
            return None
        self.state.close()
        self.state = self.history.pop()
        return self.get_state(self.state.player), self.state.player

    def is_over(self):
        return self.state.is_terminal()

    def get_payoffs(self):
        return self.state.returns()
