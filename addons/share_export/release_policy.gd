@tool
extends RefCounted
## Both installer types use this policy through the Windows export and its check.
const VERSION=2
const REMILIA_ID="1790434714.661_943735096"
const REMILIA_NAME="蕾米速攻（AI）"
const PRIVATE_DIRECTORIES=["saves/","deck/","replay/","work/","test/","tests/","tools/","docs/","builds/","addons/","training/","models/","experiments/","scripts/export_verification/"]

static func excluded_path(path: String) -> bool:
 var relative=path.trim_prefix("res://").to_lower()
 for directory in PRIVATE_DIRECTORIES:
  if relative.begins_with(directory):return true
 var filename=relative.get_file().get_basename()
 if filename=="test" or filename.begins_with("test_") or filename.begins_with("test-"):return true
 # Learned weights and training fixtures are separate from the runtime AI code.
 if relative.get_extension().to_lower() in ["json","bin","onnx","pt","pth","pkl","safetensors"]:
  for marker in ["test","trial","experiment","training","model","weights","试验","实验"]:
   if marker in filename:return true
 return false

static func is_test_deck(deck: Dictionary) -> bool:
 var name=str(deck.get("name","")).to_lower()
 return deck.get("rule_set","")=="test" or "test" in name or "测试" in name or "试验" in name or "实验" in name

static func is_ai_deck(deck: Dictionary) -> bool:
 var name=str(deck.get("name","")).to_lower()
 return "ai" in name or "人机" in name or not str(deck.get("ai_profile","")).is_empty()

static func select_decks(presets: Array,portable: Array) -> Dictionary:
 var selected=[]
 var remilia={}
 # Only the existing preset collection and the approved AI deck are public.
 for deck in presets:
  if deck.get("id","")==REMILIA_ID:continue
  if not is_test_deck(deck) and not is_ai_deck(deck):selected.append(deck.duplicate(true))
 for deck in portable+presets:
  if deck.get("id","")==REMILIA_ID:
   remilia=deck.duplicate(true)
   break
 if remilia.is_empty():return {"error":"缺少发行人机卡组："+REMILIA_NAME}
 if remilia.get("leader","")!="74" or is_test_deck(remilia):return {"error":"发行人机卡组必须是非测试规则的蕾米速攻。"}
 remilia.name=REMILIA_NAME
 selected.append(remilia)
 return {"decks":selected}
