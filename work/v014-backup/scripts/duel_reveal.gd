extends Control
## Public presentation snapshots; no rule mutations or hidden-zone permissions.
signal card_shown(serial: int)
signal card_hidden(serial: int)
const HOLD_SECONDS=1.0
var view
var busy=false
var queue: Array=[]
var current: Dictionary={}
var public_uids: Array=[]
var completed: Array=[]
var face: TextureRect
var sequence: Tween
var hand_node
var saved_hand: Dictionary={}
var shown_at=0

func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE

func enqueue(events: Array):
 queue.append_array(events.duplicate(true))
 if busy:return
 busy=true
 view.close_overlay()
 if is_instance_valid(view.banner):view.banner.hide()
 call_deferred("next_card")

func next_card():
 if queue.is_empty():
  busy=false;current={}
  if is_instance_valid(view.banner):view.banner.show()
  view.clock_time=0
  view.render()
  return
 current=queue.pop_front()
 var c=current.card
 view.ui.move_child(self,-1)
 hand_node=null;saved_hand={}
 var nodes=view.hand_nodes if c.owner==0 else view.enemy_nodes
 var from=view.project(view.table.zone_position(c.zone,c.owner))
 var initial_size=Vector2(65,91)
 if c.zone=="hand" and nodes.has(c.uid):
  hand_node=nodes[c.uid]
  from=hand_node.position+hand_node.size/2
  initial_size=hand_node.size
  saved_hand={"texture":hand_node.art.texture,"hidden":hand_node.hidden_card,"tooltip":hand_node.tooltip_text,"visible":hand_node.visible}
  hand_node.hide()
 face=TextureRect.new();face.name="RevealCard"
 face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 face.mouse_filter=Control.MOUSE_FILTER_IGNORE
 face.texture=load("res://assets/card_back.svg")
 face.size=initial_size;face.position=from-initial_size/2;add_child(face)
 var large=Vector2(194,272)
 var center=view.STAGE.get_center()
 if c.zone=="hand":
  large=Vector2(146,204)
  center=Vector2(clampf(from.x,view.HAND.position.x+large.x/2,view.HAND.end.x-large.x/2),190 if c.owner==1 else 771)
 elif current.get("edge","")=="bottom":
  face.position.y+=12
 sequence=create_tween()
 sequence.set_parallel(true)
 sequence.tween_property(face,"position",center-large/2,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 sequence.tween_property(face,"size",large,0.22)
 sequence.chain().tween_callback(func():face.pivot_offset=face.size/2)
 sequence.tween_property(face,"scale:x",0.0,0.12)
 sequence.tween_callback(func():face.texture=view.host.texture(c.card_id))
 sequence.tween_property(face,"scale:x",1.0,0.12)
 sequence.tween_callback(show_public)
 sequence.tween_interval(HOLD_SECONDS)
 sequence.tween_callback(hide_public)
 sequence.tween_property(face,"scale:x",0.0,0.10)
 sequence.tween_callback(func():face.texture=load("res://assets/card_back.svg"))
 sequence.tween_property(face,"scale:x",1.0,0.10)
 sequence.tween_property(face,"modulate:a",0.0,0.12)
 sequence.tween_callback(finish_card)

func show_public():
 shown_at=Time.get_ticks_msec()
 public_uids=[current.card.uid]
 if is_instance_valid(hand_node):
  hand_node.hidden_card=false
  hand_node.art.texture=view.host.texture(current.card.card_id)
  hand_node.tooltip_text=view.engine.cards[current.card.card_id].name
 card_shown.emit(current.serial)

func hide_public():
 public_uids.clear()
 completed.append({"serial":current.serial,"uid":current.card.uid,"zone":current.card.zone,"edge":current.get("edge",""),"seconds":(Time.get_ticks_msec()-shown_at)/1000.0})
 if is_instance_valid(hand_node) and not saved_hand.is_empty():
  hand_node.art.texture=saved_hand.texture;hand_node.hidden_card=saved_hand.hidden;hand_node.tooltip_text=saved_hand.tooltip
 card_hidden.emit(current.serial)

func finish_card():
 if is_instance_valid(hand_node) and not saved_hand.is_empty():hand_node.visible=saved_hand.visible
 hand_node=null;saved_hand={}
 if is_instance_valid(face):face.queue_free()
 call_deferred("next_card")
