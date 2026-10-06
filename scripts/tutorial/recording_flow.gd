extends "res://scripts/tutorial/runtime.gd"
## The native battle UI needs a tutorial host for its isolated engine.
func permits_match_actions() -> bool:return true
func allows_turn_end() -> bool:return true
func playing_sequence() -> bool:return false
func submit_mulligan_selection(uids: Array) -> bool:
 adapter.engine.mulligan(0 if not adapter.engine.players[0].mulligan_done else 1,uids);return true
func submit_effect_choice(target: Dictionary) -> bool:
 adapter.engine.choose_effect(target);return true
