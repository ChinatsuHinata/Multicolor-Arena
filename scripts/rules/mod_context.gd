extends RefCounted
## API v1. Queries return detached data. Commands are buffered until resolve returns.
var _engine
var _frame: Dictionary
var _writable=false
var operations: Array=[]
var error=""
func _init(engine,frame: Dictionary,writable: bool=false):
 _engine=engine;_frame=frame.duplicate(true);_writable=writable
func source() -> Dictionary:return _frame.source.duplicate(true)
func controller() -> int:return _frame.owner
func ref(card: Dictionary) -> Dictionary:return {"uid":card.uid,"epoch":card.epoch,"zone":card.zone}
func card(target: Dictionary) -> Dictionary:
 var c=_engine.find_card(int(target.get("uid",-1)))
 return c.duplicate(true) if not c.is_empty() and c.epoch==target.get("epoch",-1) else {}
func cards_in(who: int,zone: String) -> Array:
 if who not in [0,1] or zone not in ["hand","deck","field","grave","exile","palette"]:return []
 return _engine.players[who][zone].duplicate(true)
func top(who: int,count: int) -> Array:return cards_in(who,"deck").slice(0,clampi(count,0,100))
func stat(target: Dictionary,key: String) -> int:
 var c=card(target)
 return _engine.stat(c,key) if not c.is_empty() and key in ["power","health","spirit"] else 0
func damage_targets() -> Array:
 var targets=[{"player":0},{"player":1}]
 for unit in _engine.units(0)+_engine.units(1):targets.append(_engine.ref_target(unit))
 return _engine.Roster.filter_options(_engine,targets,controller(),false).duplicate(true)
func state(key: String) -> Variant:
 return _engine.Mods.read_state(_engine,_frame,key)
func info(card_id: String) -> Dictionary:return _engine.cards.get(card_id,{}).duplicate(true)
func active_player() -> int:return _engine.active
func turn() -> int:return _engine.turn
func x_casts(who: int) -> int:return int(_engine.mod_x_casts.get(str(who),0))
func used_this_turn(key: String) -> bool:return _engine.usage_count(_frame.source.uid,"mod:"+_frame.ability_id+":"+_frame.instance+":"+key)>0
func leaders(who: int) -> Array:return _engine.leaders(who).duplicate(true)
func units(who: int=-1) -> Array:return (_engine.units(0)+_engine.units(1) if who<0 else _engine.units(who)).duplicate(true)
func x_limit() -> int:return _engine.VariableChoice.limit(_engine,_frame.source.card_id,controller())
func event() -> Dictionary:return _frame.get("event",{}).duplicate(true)
func _command(op: String,data: Dictionary) -> bool:
 if not _writable:error="查询上下文不允许执行操作";return false
 data.op=op;operations.append(data.duplicate(true));return true
func damage(target: Dictionary,amount: int,result_key: String="") -> bool:return _command("damage",{"target":target,"amount":amount,"result_key":result_key})
func draw(who: int,count: int=1) -> bool:return _command("draw",{"owner":who,"count":count})
func move(target: Dictionary,zone: String,tapped: bool=false) -> bool:return _command("move",{"target":target,"zone":zone,"tapped":tapped})
func sacrifice(target: Dictionary) -> bool:return _command("sacrifice",{"target":target})
func set_state(key: String,value: Variant) -> bool:return _command("state",{"key":key,"value":value})
func reorder_top(who: int,ordered: Array) -> bool:return _command("reorder_top",{"owner":who,"cards":ordered})
func life(who: int,amount: int) -> bool:return _command("life",{"owner":who,"amount":amount})
func counters(target: Dictionary,amount: int) -> bool:return _command("counters",{"target":target,"amount":amount})
func tap(target: Dictionary,tapped: bool) -> bool:return _command("tap",{"target":target,"tapped":tapped})
func deck_move(target: Dictionary,bottom: bool=false) -> bool:return _command("deck_move",{"target":target,"bottom":bottom})
func enter(target: Dictionary,timer: int=-1) -> bool:return _command("enter",{"target":target,"timer":timer})
func buff(target: Dictionary,stats: Dictionary) -> bool:return _command("buff",{"target":target,"stats":stats})
func random_damage(targets: Array,amount: int) -> bool:return _command("random_damage",{"targets":targets,"amount":amount})
func result(key: String) -> Variant:return _frame.get("results",{}).get(key,0)
func phase() -> String:return _engine.phase
func colors(target: Dictionary) -> Array:
 var c=card(target)
 return _engine.Pack.colors(_engine,c).duplicate() if not c.is_empty() else []
func fight(first: Dictionary,second: Dictionary) -> bool:return _command("fight",{"first":first,"second":second})
func force_leader(target: Dictionary,count: int=1) -> bool:return _command("force_leader",{"target":target,"count":count})
func tokens(who: int,card_id: String,count: int) -> bool:return _command("tokens",{"owner":who,"card_id":card_id,"count":count})
func mill(who: int,count: int=1) -> bool:return _command("mill",{"owner":who,"count":count})
func shuffle_deck(who: int) -> bool:return _command("shuffle",{"owner":who})
func end_turn() -> bool:return _command("end_turn",{})
func grant_cast(target: Dictionary,discount: int=0,free: bool=false,zone: String="") -> bool:return _command("grant_cast",{"target":target,"discount":discount,"free":free,"zone":zone})
func cast_now(target: Dictionary,free: bool=false) -> bool:return _command("cast_now",{"target":target,"free":free})
func linked_enter(target: Dictionary,anchor: Dictionary) -> bool:return _command("linked_enter",{"target":target,"anchor":anchor})
