extends Control
## Ordered public presentations; these snapshots never mutate rules or visibility permissions.
signal card_shown(serial: int)
signal card_hidden(serial: int)
const HOLD_SECONDS=0.22
const REVEAL_SECONDS=0.5
const MOVE_SECONDS=0.30
const RESULT_SECONDS=1.25
var view
var busy=false
var queue: Array=[]
var current: Dictionary={}
var public_uids: Array=[]
var completed: Array=[]
var movements: Array=[]
var results: Array=[]
var face: TextureRect
var result_label: Label
var sequence: Tween
var hand_node
var saved_hand: Dictionary={}
var shown_at=0
var started_at=0
var move_ends={}

func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func reset():
 if is_instance_valid(sequence) and sequence.is_valid():sequence.kill()
 if is_instance_valid(face):face.queue_free()
 if is_instance_valid(result_label):result_label.queue_free()
 if is_instance_valid(hand_node) and not saved_hand.is_empty():
  hand_node.visible=saved_hand.visible;hand_node.hidden_card=saved_hand.hidden;hand_node.art.texture=saved_hand.texture
 queue.clear();current={};public_uids.clear();completed.clear();movements.clear();results.clear();move_ends.clear();busy=false
 hand_node=null;saved_hand={}
func enqueue(events: Array):
 queue.append_array(events.duplicate(true))
 if busy:return
 busy=true
 view.close_overlay()
 if is_instance_valid(view.banner):view.banner.hide()
 call_deferred("next_card")
func next_card():
 if not busy:return
 if queue.is_empty():
  busy=false;current={};move_ends.clear()
  if is_instance_valid(view.banner):view.banner.show()
  view.clock_time=0;view.render();return
 current=queue.pop_front();started_at=Time.get_ticks_msec()
 view.ui.move_child(self,-1)
 if current.type=="result":show_result();return
 if current.type=="move":show_move();return
 var c=current.card
 hand_node=null;saved_hand={}
 var nodes=view.hand_nodes if c.owner==view.local_seat else view.enemy_nodes
 var from=view.project(view.table.zone_position(c.zone,c.owner))
 if c.zone=="hand" and c.owner!=view.local_seat and not view.debug_mode:from=view.OPPONENT_HAND_COUNT.get_center()
 var initial_size=Vector2(65,91)
 if c.zone=="hand" and nodes.has(c.uid):
  hand_node=nodes[c.uid];from=hand_node.position+hand_node.size/2;initial_size=hand_node.size
  saved_hand={"texture":hand_node.art.texture,"hidden":hand_node.hidden_card,"tooltip":hand_node.tooltip_text,"visible":hand_node.visible}
  hand_node.hide()
 create_face(initial_size,from,view.host.texture("back"))
 var large=Vector2(194,272);var center=view.STAGE.get_center()
 if c.zone=="hand":
  large=Vector2(146,204)
  center=Vector2(clampf(from.x,view.HAND.position.x+large.x/2,view.HAND.end.x-large.x/2),190 if c.owner!=view.local_seat else 771)
 elif current.get("edge","")=="bottom":face.position.y+=12
 # One tween timeline prevents extra frame delays between flip/hold steps.
 var origin=face.position;var destination=center-large/2
 var texture=view.card_texture(c);var opened=[false];var concealed=[false]
 sequence=create_tween()
 sequence.tween_method(func(time:float):
  var travel=clampf(time/0.07,0,1)
  face.position=origin.lerp(destination,travel);face.size=initial_size.lerp(large,travel);face.pivot_offset=face.size/2
  if time<0.07:face.scale.x=1
  elif time<0.13:face.scale.x=1-(time-0.07)/0.06
  elif time<0.19:face.texture=texture;face.scale.x=(time-0.13)/0.06
  elif time<0.41:face.texture=texture;face.scale.x=1
  elif time<0.45:face.scale.x=1-(time-0.41)/0.04
  else:face.texture=view.host.texture("back");face.scale.x=minf(1,(time-0.45)/0.025)
  face.modulate.a=1-clampf((time-0.475)/0.025,0,1)
  if time>=0.19 and not opened[0]:opened[0]=true;show_public()
  if time>=0.41 and not concealed[0]:concealed[0]=true;hide_public()
 ,0.0,REVEAL_SECONDS,REVEAL_SECONDS)
 sequence.tween_callback(finish_card)
func create_face(dimensions: Vector2,center: Vector2,texture: Texture2D):
 face=TextureRect.new();face.name="PresentationCard";face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;face.mouse_filter=Control.MOUSE_FILTER_IGNORE
 face.texture=texture;face.size=dimensions;face.position=center-dimensions/2;add_child(face)
func show_result():
 result_label=Label.new();result_label.name="PublicResult";result_label.text=current.text
 result_label.position=view.STAGE.position+Vector2(30,view.STAGE.size.y/2-70);result_label.size=Vector2(view.STAGE.size.x-60,140)
 result_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;result_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result_label.add_theme_font_size_override("font_size",32)
 result_label.add_theme_color_override("font_color",view.host.GOLD);result_label.add_theme_color_override("font_shadow_color",Color.BLACK)
 result_label.add_theme_constant_override("shadow_outline_size",5);result_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(result_label)
 sequence=create_tween();sequence.tween_interval(RESULT_SECONDS)
 sequence.tween_callback(func():results.append({"text":current.text,"seconds":(Time.get_ticks_msec()-started_at)/1000.0});result_label.queue_free();next_card())
func zone_rect(zone: String,owner: int,uid: int,source: bool) -> Rect2:
 var key="card_"+str(uid)
 if source and move_ends.has(uid):return move_ends[uid]
 if zone=="hand" and owner!=view.local_seat and not view.debug_mode:
  var dimensions=Vector2(54,75)
  return Rect2(view.OPPONENT_HAND_COUNT.get_center()-dimensions/2,dimensions)
 if zone=="stack":
  var stack_rect=view.stack_panel.card_rect(uid) if source else Rect2()
  return stack_rect if stack_rect.has_area() else view.stack_panel.arrival_rect()
 if source and zone=="hand":
  var nodes=view.hand_nodes if owner==view.local_seat else view.enemy_nodes
  if nodes.has(uid):return nodes[uid].get_global_rect()
 if source and view.table.visuals.has(key):return view.projected_card_rect(view.table.visuals[key])
 if source and zone=="field":
  for group_key in view.table.descriptors:
   if uid in view.table.descriptors[group_key].get("members",[]) and view.table.visuals.has(group_key):
    return view.projected_card_rect(view.table.visuals[group_key])
 if not source:
  var layout=view.table.layout()
  var destination=layout.get(key,{})
  if destination.is_empty() and zone=="field":
   for d in layout.values():
    if uid in d.get("members",[]):destination=d;break
  if not destination.is_empty() and destination.zone==zone:
   var dimensions=Vector2(80,112) if zone!="stack" else Vector2(180,252)
   return Rect2(view.project(destination.at)-dimensions/2,dimensions)
 if zone=="hand":
  var cards=view.engine.players[owner].hand;var index=cards.map(func(c):return c.uid).find(uid);index=maxi(0,index)
  var dimensions=Vector2(146,204) if owner==view.local_seat else Vector2(70,98) if view.debug_mode else Vector2(54,75)
  var stride=minf(154,(view.HAND.size.x-80)/maxi(1,cards.size())) if owner==view.local_seat else minf(74 if view.debug_mode else 52,750.0/maxi(1,cards.size()))
  var at=Vector2(view.HAND.position.x+15+index*stride,680) if owner==view.local_seat else Vector2(view.STAGE.get_center().x-dimensions.x/2-(cards.size()-1)*stride/2+index*stride,64)
  return Rect2(at,dimensions)
 var dimensions=Vector2(66,92)
 return Rect2(view.project(view.table.zone_position(zone,owner))-dimensions/2,dimensions)
func show_move():
 var c=current.card;var from=zone_rect(current.from,c.owner,c.uid,true);var to=zone_rect(current.to,current.to_owner,c.uid,false)
 var hidden=current.from in ["hand","deck"] and current.to in ["hand","deck"] and (c.owner!=view.local_seat or current.from=="deck" and current.to=="deck") and not view.debug_mode
 var texture=view.host.texture("back") if hidden else view.card_texture(c)
 create_face(from.size,from.get_center(),texture)
 var stack_rect=view.stack_panel.card_rect(c.uid)
 if current.from=="stack" and stack_rect.has_area():
  for id in view.stack_panel.tiles:
   if view.stack_panel.tiles[id].tile.get_meta("uid")==c.uid:view.stack_panel.tiles[id].tile.modulate.a=0
 var key="card_"+str(c.uid)
 if view.table.visuals.has(key):view.table.stop_tween(key);view.table.visuals[key].hide()
 for nodes in [view.hand_nodes,view.enemy_nodes]:
  if nodes.has(c.uid):nodes[c.uid].hide()
 view.table.presented_moves[c.uid]=true
 if current.from==current.to and current.from=="deck":to.position.y-=20
 sequence=create_tween().set_parallel(true)
 sequence.tween_property(face,"position",to.position,MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 sequence.tween_property(face,"size",to.size,MOVE_SECONDS)
 if current.to in ["void","token"]:sequence.tween_property(face,"modulate:a",0.0,MOVE_SECONDS)
 sequence.chain().tween_callback(func():
  move_ends[c.uid]=to
  movements.append({"uid":c.uid,"from":current.from,"to":current.to,"hidden":hidden})
  face.queue_free();next_card())
func show_public():
 shown_at=Time.get_ticks_msec();public_uids=[current.card.uid]
 if is_instance_valid(hand_node):
  hand_node.hidden_card=false;hand_node.art.texture=view.card_texture(current.card);hand_node.tooltip_text=view.engine.cards[current.card.card_id].name
 card_shown.emit(current.serial)
func hide_public():
 public_uids.clear()
 completed.append({"serial":current.serial,"uid":current.card.uid,"zone":current.card.zone,"edge":current.get("edge",""),"seconds":(Time.get_ticks_msec()-shown_at)/1000.0,"duration":REVEAL_SECONDS})
 if is_instance_valid(hand_node) and not saved_hand.is_empty():
  hand_node.art.texture=saved_hand.texture;hand_node.hidden_card=saved_hand.hidden;hand_node.tooltip_text=saved_hand.tooltip
 card_hidden.emit(current.serial)
func finish_card():
 if is_instance_valid(hand_node) and not saved_hand.is_empty():hand_node.visible=saved_hand.visible
 hand_node=null;saved_hand={}
 if is_instance_valid(face):face.queue_free()
 call_deferred("next_card")
