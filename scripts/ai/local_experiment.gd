extends RefCounted
## Opt-in source-project opponent. Exported templates cannot enable it.
const Agent=preload("res://scripts/ai/decision_agent.gd")
const Models=preload("res://scripts/ai/matchup_models.gd")
const Tactics=preload("res://scripts/rules/remilia_aggro_ai.gd")
const DEFAULT_MODEL="res://work/ai-training/strategic-2026-09-27/matchups/preference-models.json"
var enabled=false
var weights: Dictionary={}
var last_decision: Dictionary={}

static func available() -> bool:
 return OS.has_feature("editor")

static func default_model_path() -> String:
 return DEFAULT_MODEL if available() and FileAccess.file_exists(DEFAULT_MODEL) else ""

static func read_model(path: String) -> Dictionary:
 if not available():return {"error":"试验 AI 仅限本机测试端使用。"}
 if path.is_empty():return {"weights":{}}
 if not FileAccess.file_exists(path):return {"error":"试验 AI 模型文件不存在，请重新选择。"}
 var model=Models.load_model(path)
 if model.is_empty():return {"error":"模型格式无效，请选择 AI 权重或分类模型包 JSON。"}
 return {"weights":model}

func configure(requested: bool,path: String,manual: bool=false,session=null) -> String:
 enabled=false;weights={};last_decision={}
 if not available() or not requested or manual or session!=null:return ""
 var result=read_model(path)
 if result.has("error"):return result.error
 weights=result.weights;enabled=true
 return ""

func step(e,manual: bool=false,session=null) -> Dictionary:
 if session!=null or manual:return {}
 if enabled and available():
  last_decision=Agent.step(e,1,Tactics,weights)
  if last_decision.get("applied",true)==false:
   e.ai_step(1);last_decision.fallback=true
  return last_decision
 e.ai_step(1)
 return {"fallback":true}
