extends RefCounted
## The definition follows public snapshots; leaving the field restores the original.
const CanvasNoise=preload("res://assets/unknown_card_art_canvas.gdshader")
static func active(e,c: Dictionary) -> bool:
 if c.is_empty() or c.get("network_hidden",false) or c.get("zone","")!="field" or not e.is_unit(c):return false
 var info=e.cards.get(c.card_id,{})
 if not info.get("nightmare_rename",false) or info.get("name","")!="不明物体":return false
 var id=c.card_id;var visited={}
 while e.cards.has(id) and not visited.has(id):
  if id in ["token_ufo","token-fdf-131","character-fdf-115"]:return false
  visited[id]=true
  id=e.cards[id].get("copy_source_id","")
 return true

static func apply(image: TextureRect,hover: Control,e,c: Dictionary):
 if not active(e,c):return
 var noise=ShaderMaterial.new();noise.shader=CanvasNoise
 image.material=noise
 hover.mouse_entered.connect(func():image.material=null)
 hover.mouse_exited.connect(func():image.material=noise)
