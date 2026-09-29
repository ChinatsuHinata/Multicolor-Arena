extends RefCounted
## A bundle is opt-in. Every absent/invalid specialist falls back to its generic.
const SCHEMA="multicolor.ai.matchup_models.v1"
const Matchup=preload("res://scripts/ai/matchup.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
static func load_model(path: String) -> Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary:return {}
 if data.get("schema","")!=SCHEMA:return Value.validate_weights(data)
 if not data.get("generic") is Dictionary or Value.validate_weights(data.generic).is_empty():return {}
 if not data.get("specialists") is Dictionary:return {}
 return data
static func select(e,seat: int,model: Dictionary) -> Dictionary:
 var matchup=Matchup.identify(e,seat)
 var result={"matchup":matchup,"source":"generic","reason":"unclassified_weights","weights":model}
 if model.get("schema","")!=SCHEMA:return result
 result.weights=Value.validate_weights(model.get("generic",{}))
 result.reason="unknown_opponent" if matchup.key.is_empty() else "no_specialist"
 var candidate=model.get("specialists",{}).get(matchup.key,{})
 if not candidate is Dictionary or candidate.is_empty():return result
 if candidate.get("matchup",{}).get("key","")!=matchup.key:
  result.reason="mismatched_specialist";return result
 var weights=Value.validate_weights(candidate)
 if weights.is_empty() or candidate.get("schema")!=model.generic.get("schema"):
  result.reason="invalid_specialist";return result
 result.weights=weights;result.source="specialist";result.reason="known_matchup"
 return result
