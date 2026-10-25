extends Node3D
## One stage per duel table. It owns three named layers so entrance, foil and
## spell effects can never fight over z-order, and it is the only node the
## bridge has to place in the 3D scene.

const RegistryScript=preload("res://fx/fx_registry.gd")

const LAYERS={"entrance":0,"foil":1,"spell":2}

var registry
var active: Array[Node]=[]
## Tests step the clock by hand; the real game leaves this false.
var auto_step=false

func _init():
 registry=RegistryScript.new()

func use_registry(value) -> void:
 if value!=null:registry=value

func layer(category: String) -> Node3D:
 var layer_name="FxLayer_"+category
 var existing=get_node_or_null(layer_name)
 if existing is Node3D:return existing
 var node=Node3D.new();node.name=layer_name
 node.position.y=float(LAYERS.get(category,1))*0.001
 add_child(node)
 return node

## Spawns every enabled effect of a category. `context` may carry `parent`;
## the entrance and foil effects default to the card visual, spell effects to
## their own layer.
func play(category: String,context: Dictionary,products: Dictionary={}) -> Array:
 var started: Array=[]
 for def in registry.enabled(category,products):
  var ctx=context.duplicate(true)
  if not ctx.has("parent") or ctx.parent==null:ctx["parent"]=layer(category)
  var module=registry.spawn(def,ctx)
  if module==null:continue
  module.auto_advance=not auto_step
  module.done.connect(_on_done)
  add_child(module)
  if module.start():
   active.append(module)
   started.append(module)
  else:
   module.queue_free()
 return started

func advance_all(delta: float) -> void:
 for module in active.duplicate():
  if not is_instance_valid(module):active.erase(module);continue
  if module.auto_advance:continue
  module.advance(delta)
  if module.finished:active.erase(module)

## 卡牌离场后 holder 会悬空；每帧扫一遍，让常驻的闪卡模块自己收尾。
func _process(delta: float) -> void:
 if active.is_empty():return
 for module in active.duplicate():
  if not is_instance_valid(module):active.erase(module);continue
  if module.auto_advance:continue
  module.advance(delta)
  if module.finished:active.erase(module)

func stop_all() -> void:
 for module in active.duplicate():
  if is_instance_valid(module):module.stop()
 active.clear()

func clear() -> void:
 stop_all()
 for child in get_children():
  if str(child.name).begins_with("FxLayer_"):continue
  child.queue_free()

func _on_done(_id: String) -> void:
 var kept: Array[Node]=[]
 for module in active:
  if is_instance_valid(module) and not module.finished:kept.append(module)
 active=kept
