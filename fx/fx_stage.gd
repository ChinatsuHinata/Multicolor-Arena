extends Node3D
## One stage per duel table. It owns three named layers so entrance, foil and
## spell effects can never fight over z-order, and it is the only node the
## bridge has to place in the 3D scene.

const RegistryScript=preload("res://fx/fx_registry.gd")

const LAYERS={"entrance":0,"foil":1,"spell":2}

var registry
var active: Array[Node]=[]
## 等待卡牌落场的 after 入场特效：{def, ctx, wait}，wait 归零时才生成模块。
var pending: Array[Dictionary]=[]
## Tests step the clock by hand; the real game leaves this false.
var auto_step=false
var last_flight_seconds=0.0

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
## their own layer. `context.card_id` filters by each manifest's `cards`.
## Entrance effects split by timing: `before` starts now, while the card is
## still flying in from the stack; `after` waits `context.travel` seconds
## until the card has landed. `context.timings` (optional) limits entrance
## effects to those timings, so the departure and the landing can each play
## their own half. Only modules started now are returned.
func play(category: String,context: Dictionary,products: Dictionary={}) -> Array:
 last_flight_seconds=0.0
 var started: Array=[]
 var timings=context.get("timings",[])
 var proxy_taken=false
 for def in registry.enabled(category,products,str(context.get("card_id",""))):
  if category=="entrance" and timings is Array and not timings.is_empty() and not timings.has(RegistryScript.timing(def)):continue
  var ctx=context.duplicate(true)
  if category=="entrance" and RegistryScript.flight(def)=="proxy" and not proxy_taken and ctx.get("flight") is Dictionary and (ctx.flight.get("texture") is Texture2D or ctx.flight.get("color") is Color):
   ctx["flight_proxy"]=true;proxy_taken=true
   if RegistryScript.flight_ms(def)>0.0:
    var seconds=RegistryScript.flight_ms(def)/1000.0
    ctx["travel"]=seconds
    var flight: Dictionary=ctx.flight
    flight["seconds"]=seconds
    if def.has("flight_ease"):flight["ease"]=str(def.flight_ease)
    ctx["flight"]=flight
    last_flight_seconds=seconds
  else:ctx["flight_proxy"]=false
  if not ctx.has("parent") or ctx.parent==null:ctx["parent"]=layer(category)
  var wait=maxf(float(ctx.get("travel",0.0)),0.0)
  if category=="entrance" and RegistryScript.timing(def)=="after" and wait>0.0:
   pending.append({"def":def,"ctx":ctx,"wait":wait})
   continue
  var module=spawn_module(def,ctx)
  if module!=null:started.append(module)
 return started

func landed(uid: int) -> void:
 for module in active:
  if is_instance_valid(module) and module.category=="entrance" and int(module.ctx.get("uid",0))==uid and module.has_method("card_landed"):module.card_landed()

## 回合结束：持续到回合结束的入场特效开始收尾。
func turn_ended() -> void:
 for module in active:
  if is_instance_valid(module) and module.has_method("release"):module.release()

## 单位离场：该单位的入场特效（含持续到回合结束的）立即进入收尾；
## 还在等落场的 after 特效直接丢弃。
func released(uid: int) -> void:
 pending=pending.filter(func(entry):return int(entry.ctx.get("uid",0))!=uid)
 for module in active:
  if is_instance_valid(module) and module.category=="entrance" and int(module.ctx.get("uid",0))==uid and module.has_method("release"):module.release()

func spawn_module(def: Dictionary,ctx: Dictionary) -> Node:
 var module=registry.spawn(def,ctx)
 if module==null:return null
 module.auto_advance=not auto_step
 module.done.connect(_on_done)
 add_child(module)
 if not module.start():
  module.queue_free()
  return null
 active.append(module)
 return module

## 落场计时；卡牌在落场前离场（父节点已释放）时直接丢弃，不留孤儿。
func tick_pending(delta: float) -> void:
 if pending.is_empty():return
 var due: Array[Dictionary]=[]
 var kept: Array[Dictionary]=[]
 for entry in pending:
  entry.wait-=delta
  if entry.wait>0.0:kept.append(entry)
  else:due.append(entry)
 pending=kept
 for entry in due:
  var parent=entry.ctx.get("parent")
  if is_instance_valid(parent) and parent is Node and parent.is_inside_tree():spawn_module(entry.def,entry.ctx)

func advance_all(delta: float) -> void:
 if auto_step:tick_pending(delta)
 for module in active.duplicate():
  if not is_instance_valid(module):active.erase(module);continue
  if module.auto_advance:continue
  module.advance(delta)
  if module.finished:active.erase(module)

## 卡牌离场后 holder 会悬空；每帧扫一遍，让常驻的闪卡模块自己收尾。
func _process(delta: float) -> void:
 if not auto_step:tick_pending(delta)
 if active.is_empty():return
 for module in active.duplicate():
  if not is_instance_valid(module):active.erase(module);continue
  if module.auto_advance:continue
  module.advance(delta)
  if module.finished:active.erase(module)

func stop_all() -> void:
 pending.clear()
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
