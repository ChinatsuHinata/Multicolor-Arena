extends Control
const Duel=preload("res://scripts/rules/duel_engine.gd")
const STAGE=Rect2(0,72,1600,598)
const HAND=Rect2(300,668,1010,232)
const COLOR_INK={"红":Color("#cf5b60"),"蓝":Color("#4d94d5"),"绿":Color("#48996d"),"黄":Color("#d9b54f"),"黑":Color("#77758b")}
var host
var engine
var table
var viewport: SubViewport
var stage: TextureRect
var ui: Control
var hud: Control
var hand_layer: Control
var opponent_layer: Control
var badges: Control
var inspection: Control
var hand_nodes={}
var enemy_nodes={}
var card_badges={}
var hand_tweens={}
var local: Dictionary={}
var selection: Array=[]
var auto_pay=true
var full_response=false
var modal=false
var modal_root: Control
var action_menu_open=false
var clock_time=0.0
var last_revision=-1
var message=""
var fast_mode=false
var last_phase=""
var last_turn=0
var banner: Control
var banner_tween: Tween
var banner_until=0
var inspect_id=""
var inspect_uid=0
var inspect_caption=""
var inspection_signature=""
var drag_uid=0
var drag_origin=Vector2.ZERO
var drag_pointer=Vector2.ZERO
var dragging=false
var drag_art: Control
var previous_snapshot={}
var frame_count=0
var phase_names={"mulligan":"起手调度","reset":"重置阶段","prepare":"准备阶段","draw":"抓牌阶段","possession":"凭依阶段","main":"主要阶段","end":"结束阶段","over":"对局结束"}

func layer(parent: Node) -> Control:
 var node=Control.new(); node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node)
 return node
func begin(parent,a: Dictionary,b: Dictionary,first: int,seed_value: int=0):
 host=parent; engine=Duel.new(); engine.start(a,b,first,seed_value)
 viewport=SubViewport.new(); viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
 viewport.msaa_3d=Viewport.MSAA_4X; add_child(viewport)
 resize_world()
 stage=TextureRect.new(); stage.position=STAGE.position; stage.size=STAGE.size
 stage.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; stage.texture=viewport.get_texture()
 stage.stretch_mode=TextureRect.STRETCH_SCALE; add_child(stage)
 stage.gui_input.connect(stage_input)
 table=preload("res://scripts/duel_table.gd").new(); viewport.add_child(table)
 table.build(engine,host.texture,host.battlefield_background)
 table.object_selected.connect(object_clicked)
 table.stack_selected.connect(func(id): choose_target({"stack_id":id}))
 table.card_inspected.connect(inspect_card)
 table.empty_right_clicked.connect(right_cancel)
 table.pile_selected.connect(func(zone):
  if zone in ["pgrave","agrave"]:
   var who=0 if zone=="pgrave" else 1
   table.inspect_cards(engine.players[who].grave.map(func(c): return c.card_id)))
 ui=layer(self); badges=layer(ui)
 var hand_bg=host.box(ui,HAND,Color("#101b29"),Color("#26374a"))
 hand_bg.mouse_filter=Control.MOUSE_FILTER_STOP
 hand_layer=layer(ui); opponent_layer=layer(ui); hud=layer(ui)
 inspection=Control.new(); inspection.position=Vector2(16,83); inspection.size=Vector2(267,580); ui.add_child(inspection)
 banner=layer(ui)
 get_viewport().size_changed.connect(resize_world)
 render()

func resize_world():
 if not is_instance_valid(viewport): return
 var window_size=Vector2(get_window().size)
 var scale_value=clampf(minf(window_size.x/1600.0,window_size.y/900.0),1.0,2.2)
 viewport.size=Vector2i(STAGE.size*scale_value)
func project(at: Vector3) -> Vector2:
 return STAGE.position+table.camera.unproject_position(at)/Vector2(viewport.size)*STAGE.size
func stage_input(event: InputEvent):
 if modal or dragging: return
 if event is InputEventMouseButton:
  var converted=event.duplicate()
  converted.position=event.position/STAGE.size*Vector2(viewport.size)
  table.pointer(converted)
func free_main() -> bool:
 return engine.active==0 and engine.phase=="main" and engine.stack.is_empty() and engine.combat.is_empty()
func _process(delta):
 if engine==null: return
 update_badge_positions()
 if modal or not local.is_empty() or drag_uid!=0 or engine.winner!=-2: return
 if not fast_mode and (table.is_animating() or Time.get_ticks_msec()<banner_until): return
 clock_time+=delta
 if clock_time<(0.02 if fast_mode else 0.48): return
 clock_time=0
 var before=engine.revision
 if engine.phase=="mulligan":
  if not engine.players[1].mulligan_done: engine.ai_step()
 elif not engine.pending.is_empty():
  if engine.pending.owner==1: engine.ai_step()
 elif engine.priority==1: engine.ai_step()
 elif not full_response and not free_main() and not engine.has_response(0): engine.pass_priority(0)
 if before!=engine.revision or last_revision!=engine.revision: render()

func clear_children(node: Node):
 for child in node.get_children(): node.remove_child(child); child.queue_free()
func txt(text: String,rect: Rect2,font: int=18,color: Color=Color("#e8edf0"),parent: Node=null):
 return host.label(hud if parent==null else parent,text,rect,font,color)
func btn(text: String,rect: Rect2,action: Callable,accent: bool=false,parent: Node=null):
 return host.button(hud if parent==null else parent,text,rect,action,accent)
func highlights() -> Array:
 var result=[]
 if not local.is_empty():
  if local.mode=="payment":
   for resource in payment_sources(): result.append(resource.uid)
  else:
   for target in local_targets():
    if target.has("uid"): result.append(target.uid)
  return result
 if engine.pending.get("owner",-1)==0:
  if engine.pending.kind=="block": return engine.legal_blockers().map(func(c): return c.uid)
  if engine.pending.kind=="possession": return engine.players[0].palette.filter(func(c): return not c.tapped).map(func(c): return c.uid)
 for c in engine.legal_casts(0): result.append(c.uid)
 for c in engine.players[0].field:
  if not engine.available_actions(0,c.uid).is_empty(): result.append(c.uid)
 return result
func render():
 if not is_instance_valid(ui): return
 close_overlay()
 clear_children(hud)
 last_revision=engine.revision
 var available=highlights()
 table.sync(local.get("plan",[]),selection,available,not previous_snapshot.is_empty())
 render_hands(available)
 rebuild_badges()
 txt("极 彩",Rect2(24,10,140,42),26,host.GOLD)
 btn("响应：开" if full_response else "响应：关",Rect2(180,12,136,38),func(): full_response=not full_response; render(),full_response)
 txt("第 %d 回合  ·  %s  ·  %s" % [engine.turn,"你" if engine.active==0 else "人机",phase_names[engine.phase]],Rect2(430,12,790,42),23,host.GOLD)
 btn("设置",Rect2(1460,12,116,40),settings_menu)
 btn("人机  %d" % engine.players[1].life,Rect2(1350,92,214,45),func(): choose_target({"player":1}))
 btn("你  %d" % engine.players[0].life,Rect2(27,785,243,58),func(): choose_target({"player":0}))
 txt("手牌 %d" % engine.players[1].hand.size(),Rect2(1070,88,170,30),18,host.WHITE)
 if not engine.stack.is_empty():
  txt("堆叠  %d" % engine.stack.size(),Rect2(1330,552,255,34),22,host.GOLD)
 render_prompt()
 if not message.is_empty(): txt(message,Rect2(307,639,995,28),18,Color("#f0cf93"))
 if not engine.log.is_empty(): txt(engine.log.back(),Rect2(320,53,990,26),15,host.MUTED)
 update_inspection()
 if last_phase!=engine.phase or last_turn!=engine.turn:
  show_phase_banner()
 last_phase=engine.phase; last_turn=engine.turn
 previous_snapshot=table.card_snapshot()
 if engine.winner!=-2: result_overlay()

func cost_chips(parent: Node,cost: Dictionary,at: Vector2,font: int=16):
 var x=at.x
 for color in cost:
  var panel=host.box(parent,Rect2(x,at.y,48,26),COLOR_INK.get(color,Color.GRAY),Color("#ead7ab"))
  panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
  txt(color+str(int(cost[color])),Rect2(3,0,42,25),font,Color("#ffffff"),panel)
  x+=51
func render_hands(available: Array):
 sync_hand_nodes(0,hand_nodes,hand_layer,available)
 sync_hand_nodes(1,enemy_nodes,opponent_layer,[])
func sync_hand_nodes(who: int,nodes: Dictionary,parent: Control,available: Array):
 var cards=engine.players[who].hand
 var ids=cards.map(func(c): return c.uid)
 for uid in nodes.keys():
  if uid in ids: continue
  var node=nodes[uid]; nodes.erase(uid)
  if hand_tweens.has(uid) and hand_tweens[uid].is_valid(): hand_tweens[uid].kill()
  node.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var tween=create_tween().set_parallel(true)
  tween.tween_property(node,"modulate:a",0.0,0.18)
  tween.tween_property(node,"position:y",node.position.y-45,0.18)
  tween.chain().tween_callback(node.queue_free)
 for i in range(cards.size()):
  var c=cards[i]
  var tile_size=Vector2(146,204) if who==0 else Vector2(54,75)
  var stride=minf(154,950.0/maxi(1,cards.size())) if who==0 else minf(52,660.0/maxi(1,cards.size()))
  var target=Vector2(315+i*stride,687) if who==0 else Vector2(780-(cards.size()-1)*stride/2+i*stride,70)
  var fresh=not nodes.has(c.uid)
  if fresh:
   var tile=preload("res://scripts/duel_hand_card.gd").new()
   tile.size=tile_size; parent.add_child(tile); tile.build(self,c,who==1)
   nodes[c.uid]=tile
   var old=previous_snapshot.get(c.uid,{})
   tile.position=project(table.zone_position(old.get("zone","deck"),who)) if not previous_snapshot.is_empty() else target+Vector2(0,65 if who==0 else -65)
   tile.modulate.a=0.1
   if who==0: cost_chips(tile,engine.cards[c.card_id].cost,Vector2(2,-19))
  var node=nodes[c.uid]
  node.update_style(c.uid in available,c.uid in selection)
  if fresh or node.get_meta("target",Vector2(-999,-999))!=target:
   if hand_tweens.has(c.uid) and hand_tweens[c.uid].is_valid(): hand_tweens[c.uid].kill()
   var tween=create_tween().set_parallel(true)
   tween.tween_property(node,"position",target,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   tween.tween_property(node,"modulate:a",1.0,0.3)
   hand_tweens[c.uid]=tween; node.set_meta("target",target)

func rebuild_badges():
 clear_children(badges); card_badges={}
 var group_top={}
 for key in table.descriptors:
  var d=table.descriptors[key]
  if d.zone=="field" and not engine.is_unit(engine.find_card(d.uid)):
   group_top[str(d.owner)+d.card_id]=key
 for key in table.descriptors:
  var d=table.descriptors[key]
  if d.zone=="field" and not engine.is_unit(engine.find_card(d.uid)) and group_top[str(d.owner)+d.card_id]!=key: continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  var parts={"root":root,"zone":d.zone,"owner":d.owner}
  var info=engine.cards.get(d.card_id,{})
  if d.zone=="palette":
   var colors=["任意"] if d.card_id=="potato" else info.colors
   var pieces="/".join(colors)
   var width=35 if colors.size()==1 else 57
   if d.card_id=="potato": width=46
   var panel=host.box(root,Rect2(-width/2.0,0,width,21),Color("#14222e"),Color("#53667f")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   var label=txt(pieces,Rect2(0,0,width,21),13,host.GOLD,panel); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   parts.palette=panel
  else:
   var cost=Control.new(); cost.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(cost)
   var x=0
   for color in info.get("cost",{}):
    var chip=host.box(cost,Rect2(x,0,35,22),COLOR_INK[color],Color("#edddbd")); chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    txt(color+str(int(info.cost[color])),Rect2(2,0,33,22),13,Color.WHITE,chip)
    x+=37
   parts.cost=cost; parts.cost_width=maxi(x-2,0)
   if d.zone=="field":
    var c=engine.find_card(d.uid)
    if not c.is_empty() and engine.is_unit(c):
     var panel=host.box(root,Rect2(0,0,99,25),Color("#111d2b"),Color("#aaa080")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
     var label=txt("%d / %d · %d" % [info.power,info.health-c.damage,info.spirit],Rect2(1,0,97,25),16,host.WHITE,panel); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
     parts.stats=panel
     if engine.summoning_sick(c): parts.sick=txt("召唤失调",Rect2(0,0,100,22),14,Color("#b6cdf3"),root)
   if d.zone=="leader":
    var c=engine.find_card(d.uid)
    if c.timer>0: parts.sick=txt("计时 %d" % c.timer,Rect2(0,0,100,24),17,host.GOLD,root)
  card_badges[key]=parts
 for key in table.piles:
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  card_badges[key]={"root":root,"zone":"pile"}
  var is_deck="deck" in key
  var who=0 if key.begins_with("p") else 1
  var label=txt(("牌库 " if is_deck else "墓地 ")+str(engine.players[who].deck.size() if is_deck else engine.players[who].grave.size()),Rect2(-48,0,96,26),17,host.WHITE,root)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 update_badge_positions()
func projected_card_rect(node: Node3D) -> Rect2:
 var rect=Rect2(project(node.to_global(Vector3(-0.975,0,-1.36))),Vector2.ZERO)
 for corner in [Vector3(0.975,0,-1.36),Vector3(-0.975,0,1.36),Vector3(0.975,0,1.36)]: rect=rect.expand(project(node.to_global(corner)))
 return rect
func update_badge_positions():
 if not is_instance_valid(table): return
 var stack_rects=[]
 for key in table.descriptors:
  if table.descriptors[key].zone=="stack": stack_rects.append(projected_card_rect(table.visuals[key]).grow(6))
 for key in card_badges:
  var parts=card_badges[key]; var root=parts.root
  if table.visuals.has(key):
   var node=table.visuals[key]
   var rect=projected_card_rect(node)
   root.position=rect.get_center()
   if parts.has("cost"):
    var inside=parts.zone=="field" and not parts.has("stats")
    parts.cost.position=Vector2(-parts.cost_width/2.0,-rect.size.y/2+(1 if inside else -23))
   if parts.has("stats"): parts.stats.position=Vector2(-49.5,rect.size.y/2+1)
   if parts.has("sick"): parts.sick.position=Vector2(-49,rect.size.y/2+27)
   if parts.has("palette"): parts.palette.position.y=rect.size.y/2+1
  elif table.piles.has(key):
   root.position=project(table.piles[key].position+Vector3(0,table.stack_heights[key]+0.1,0.0))
  root.visible=root.position.x>292 and root.position.y>140 and root.position.y<635
  if parts.zone!="stack" and stack_rects.any(func(r): return r.has_point(root.position)): root.visible=false

func show_phase_banner():
 clear_children(banner)
 if is_instance_valid(banner_tween): banner_tween.kill()
 var panel=host.box(banner,Rect2(465,292,735,115),Color(0.05,0.09,0.15,0.94),host.GOLD)
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var caption=phase_names[engine.phase]
 if engine.turn!=last_turn: caption=("你的回合" if engine.active==0 else "对手回合")+" · "+caption
 var label=txt(caption,Rect2(20,22,695,68),36,host.GOLD,panel)
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 banner.modulate.a=0
 banner_tween=create_tween()
 banner_tween.tween_property(banner,"modulate:a",1.0,0.14)
 banner_tween.tween_interval(0.6)
 banner_tween.tween_property(banner,"modulate:a",0.0,0.3)
 banner_until=Time.get_ticks_msec()+1050

func inspect_card(id: String,uid: int=0,caption: String=""):
 inspect_id=id; inspect_uid=uid; inspect_caption=caption; update_inspection()
func update_inspection():
 var current=engine.find_card(inspect_uid)
 var signature=inspect_id+str(inspect_uid)+inspect_caption+str(engine.summoning_sick(current))
 if signature==inspection_signature: return
 inspection_signature=signature
 clear_children(inspection)
 if inspect_id.is_empty(): return
 var bg=host.box(inspection,Rect2(0,0,267,580),Color("#101d2c"),Color("#52677e"))
 var image=TextureRect.new(); image.position=Vector2(11,10); image.size=Vector2(245,341)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture=load("res://assets/card_back.svg") if inspect_id=="back" else host.texture(inspect_id)
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE; bg.add_child(image)
 var info=engine.cards.get(inspect_id,{})
 var name=inspect_caption if inspect_id=="back" else "红薯" if inspect_id=="potato" else info.name
 var title=txt(name,Rect2(12,355,242,54),20,host.GOLD,bg); title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.clip_text=false
 var scroll=ScrollContainer.new(); scroll.position=Vector2(12,416); scroll.size=Vector2(242,149); bg.add_child(scroll)
 var text=Label.new(); text.custom_minimum_size.x=220; text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; text.add_theme_font_size_override("font_size",17)
 text.text="未公开" if inspect_id=="back" else "任选一种颜色支付 1 点，使用后消失。" if inspect_id=="potato" else info.rules_text
 if engine.cards.has(inspect_id) and info.fast: text.text="高速\n"+text.text
 var c=engine.find_card(inspect_uid)
 if not c.is_empty() and engine.summoning_sick(c): text.text="召唤失调\n\n"+text.text
 scroll.add_child(text)

func render_prompt():
 var text=""
 if not local.is_empty():
  text=local_prompt()
  btn("取消使用",Rect2(1330,680,237,45),cancel_cast)
  if local.mode=="payment":
   var valid=engine.payment_valid(0,local_cost(),local.plan)
   var b=btn("确认支付",Rect2(1330,738,237,50),commit_local,true); b.disabled=not valid
   btn("重选费用",Rect2(1330,805,237,43),func(): local.plan=[]; render())
 elif engine.phase=="mulligan" and not engine.players[0].mulligan_done:
  text="选择要调度的手牌"
  btn("保留" if selection.is_empty() else "调度 %d 张" % selection.size(),Rect2(1330,770,237,55),func(): engine.mulligan(0,selection); selection=[]; render(),true)
 elif engine.pending.get("owner",-1)==0:
  match engine.pending.kind:
   "possession":
    text="凭依：选择颜色盘与手牌"
    btn("跳过凭依",Rect2(1330,770,237,55),func(): engine.possession(); selection=[]; render(),true)
   "block":
    text="选择阻挡单位"
    btn("不阻挡" if selection.is_empty() else "确认阻挡 %d 个" % selection.size(),Rect2(1330,770,237,55),func(): engine.block(selection); selection=[]; render(),true)
   "trigger":
    text=engine.pending.trigger.name+"：选择目标单位"
    btn("不使用能力",Rect2(1330,770,237,55),func(): engine.choose_trigger({}); selection=[]; render())
   "leader_return":
    text="将自机放回自机区？"
    btn("返回自机区",Rect2(1330,740,237,49),func(): engine.choose_return(true); render(),true)
    btn("送入墓地",Rect2(1330,810,237,43),func(): engine.choose_return(false); render())
   "discard":
    text="弃置 %d 张手牌" % engine.pending.count
    var b=btn("确认弃牌",Rect2(1330,770,237,55),func(): engine.discard(selection); selection=[]; render(),true)
    b.disabled=selection.size()!=engine.pending.count
   "damage_assignment":
    text="分配战斗伤害"
    btn("分配伤害",Rect2(1330,770,237,55),damage_dialog,true)
 elif engine.priority==0 and engine.winner==-2:
  if free_main():
   text="你的行动"
   btn("结束主要阶段",Rect2(1330,770,237,55),func(): engine.pass_priority(0); message=""; render(),true)
  elif full_response or engine.has_response(0):
   text="响应窗口"
   btn("不响应 / 继续",Rect2(1330,770,237,55),func(): engine.pass_priority(0); message=""; render(),true)
 txt(text,Rect2(310,605,1000,37),21,host.GOLD)

func begin_hand_drag(uid: int,at: Vector2):
 if modal or not local.is_empty(): return
 drag_uid=uid; drag_origin=at; drag_pointer=at; dragging=false
func _input(event: InputEvent):
 if action_menu_open and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  var at=make_input_local(event).position
  var panel=modal_root.get_child(0)
  var inspected=false
  for child in panel.get_children():
   if child is Panel and child.get_global_rect().has_point(at):
    var uid=panel.get_meta("action_card_uid",0)
    var c=engine.find_card(uid)
    if not c.is_empty(): inspect_card(c.card_id,uid); inspected=true
  if not inspected: close_overlay()
  get_viewport().set_input_as_handled(); return
 if drag_uid==0: return
 if event is InputEventMouseMotion:
  var at=make_input_local(event).position
  drag_pointer=at
  if at.distance_to(drag_origin)>10 and not dragging:
   dragging=true
   drag_art=host.card(ui,engine.find_card(drag_uid).card_id,Rect2(at-Vector2(82,115),Vector2(164,230)))
   drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; drag_art.modulate.a=0.9
  if dragging: drag_art.position=at-Vector2(82,115)
 elif event is InputEventMouseButton:
  drag_pointer=make_input_local(event).position
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   finish_drag(true); get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   finish_drag(false); get_viewport().set_input_as_handled()
func finish_drag(cancelled: bool):
 var uid=drag_uid; var moved=dragging; var at=drag_pointer
 drag_uid=0; dragging=false
 if is_instance_valid(drag_art): drag_art.queue_free()
 if cancelled: return
 if moved:
  if not HAND.has_point(at): request_cast(uid)
 else: hand_clicked(uid)
func hand_clicked(uid: int):
 message=""
 if engine.phase=="mulligan" or engine.pending.get("kind","")=="discard": toggle_selection(uid); return
 if engine.pending.get("kind","")=="possession" and engine.pending.owner==0:
  if selection.size()==1 and engine.find_card(selection[0]).zone=="palette":
   engine.possession(selection[0],uid); selection=[]; render()
  return
 # A plain click does not cast a hand card.
func right_cancel():
 if not local.is_empty(): cancel_cast()
 elif is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
func object_clicked(uid: int):
 message=""
 if not local.is_empty():
  if local.mode=="payment": reserve_resource(uid)
  else:
   var target=engine.find_card(uid)
   if not target.is_empty(): choose_target(engine.ref_target(target))
  return
 var c=engine.find_card(uid)
 if engine.pending.get("owner",-1)==0:
  match engine.pending.kind:
   "trigger":
    if not c.is_empty(): choose_target(engine.ref_target(c))
   "block":
    if c in engine.legal_blockers(): toggle_selection(uid)
   "possession":
    if not c.is_empty() and c.owner==0 and c.zone=="palette" and not c.tapped: selection=[uid]; render()
  return
 if c.is_empty(): return
 if c.owner==0 and c.zone=="leader": request_cast(uid)
 elif c.owner==0 and c.zone=="field": open_actions(c)
func open_actions(c: Dictionary):
 var actions=engine.available_actions(0,c.uid,true)
 if actions.is_empty(): inspect_card(c.card_id,c.uid); return
 var panel=overlay("选择行动")
 action_menu_open=true
 panel.position=Vector2(maxf(295,800-actions.size()*103),228)
 panel.size=Vector2(maxf(360,actions.size()*206+40),415)
 panel.set_meta("action_card_uid",c.uid)
 for i in range(actions.size()):
  var action=actions[i]
  var tile=host.card(panel,c.card_id,Rect2(24+i*206,70,173,241),func(): execute_action(action))
  if not action.enabled: tile.modulate=Color(0.55,0.55,0.55)
  var label=txt(action.label+("\n"+action.reason if not action.enabled else ""),Rect2(20+i*206,321,185,74),18,host.GOLD if action.enabled else host.MUTED,panel)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func execute_action(action: Dictionary):
 if not action.enabled: return
 close_overlay()
 if action.type=="attack": engine.attack(0,action.uid); render()
 else:
  local={"uid":action.uid,"action":"ability","index":action.index,"mode":"target","target":{},"plan":[]}
  render()
func toggle_selection(uid: int):
 if uid in selection: selection.erase(uid)
 else: selection.append(uid)
 render()

func local_prompt() -> String:
 if local.mode=="target": return "选择目标："+engine.cards[engine.find_card(local.uid).card_id].name
 var cost=local_cost()
 var pieces=[]
 for color in cost:
  var paid=local.get("plan",[]).filter(func(r): return r.color==color).size()
  pieces.append("%s %d / %d" % [color,paid,cost[color]])
 return "手动支付  ·  "+"    ".join(pieces)

func local_cost() -> Dictionary:
 if local.get("action","")=="ability": return engine.ability_parameters(local.uid,local.index).get("费用",{})
 return engine.cards[engine.find_card(local.uid).card_id].cost
func local_targets() -> Array:
 if local.get("action","")=="ability": return engine.ability_targets()
 return engine.targets_for(engine.find_card(local.uid).card_id)
func payment_sources() -> Array:
 var sources=engine.source_resources(0)
 if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false):
  sources=sources.filter(func(r): return r.uid!=local.uid)
 var cost=local_cost()
 return sources.filter(func(r):
  if local.plan.any(func(p): return p.uid==r.uid): return true
  return r.colors.any(func(color): return local.plan.filter(func(p): return p.color==color).size()<int(cost.get(color,0))))
func close_overlay():
 modal=false; action_menu_open=false
 if is_instance_valid(modal_root):
  modal_root.get_parent().remove_child(modal_root); modal_root.queue_free()
 modal_root=null

func request_cast(uid: int):
 var error=engine.cast_error(0,uid)
 if not error.is_empty(): message=error; render(); return
 local={"uid":uid,"target":{},"plan":[],"mode":"target"}
 var c=engine.find_card(uid)
 if engine.cards[c.card_id].kind=="符卡": render()
 else: start_payment()
func choose_target(target: Dictionary):
 if engine.pending.get("kind","")=="trigger" and engine.pending.owner==0:
  if engine.target_valid(target,true): engine.choose_trigger(target); render()
  return
 if local.is_empty() or local.mode!="target": return
 if target not in local_targets(): message="目标不合法"; render(); return
 local.target=target
 start_payment()
func start_payment():
 var c=engine.find_card(local.uid)
 var excluded=[local.uid] if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false) else []
 var solution=engine.payment(0,local_cost(),excluded)
 local.mode="payment"
 if auto_pay and (solution.ways==1 or (local.get("action","")!="ability" and engine.cards[c.card_id].kind!="符卡")):
  local.plan=solution.plan; commit_local(); return
 if not auto_pay: render(); return
 render()
 var panel=overlay("支付费用")
 txt("自动选择费用？",Rect2(32,74,590,50),25,host.GOLD,panel)

 btn("自动支付",Rect2(32,218,190,50),func(): modal=false; local.plan=solution.plan; commit_local(),true,panel)
 btn("手动选择",Rect2(238,218,190,50),func(): modal=false; render(),false,panel)
 btn("取消使用",Rect2(444,218,170,50),cancel_cast,false,panel)
func reserve_resource(uid: int):
 var sources=payment_sources()
 var source={}
 for s in sources:
  if s.uid==uid: source=s
 if source.is_empty(): return
 for reservation in local.plan:
  if reservation.uid==uid: local.plan.erase(reservation); render(); return
 var cost=local_cost()
 var colors=[]
 for color in source.colors:
  if local.plan.filter(func(r): return r.color==color).size()<int(cost.get(color,0)): colors.append(color)
 if colors.is_empty(): message="不需要这张牌的颜色"; render(); return
 if colors.size()==1: local.plan.append({"uid":uid,"color":colors[0]}); render(); return
 var panel=overlay("选择支付颜色")
 for i in range(colors.size()):
  var color=colors[i]
  btn(color,Rect2(30+i*110,95,100,65),func(): local.plan.append({"uid":uid,"color":color}); modal=false; render(),true,panel)
 btn("返回",Rect2(440,218,170,50),func(): modal=false; render(),false,panel)
func commit_local():
 if local.is_empty(): return
 var error=engine.commit_ability(0,local.uid,local.index,local.target,local.plan) if local.get("action","")=="ability" else engine.commit_cast(0,local.uid,local.target,local.plan)
 if error.is_empty(): local={}; selection=[]; message=""
 else: message=error
 modal=false; render()
func cancel_cast():
 local={}; selection=[]; modal=false; message=""; render()
func overlay(title: String) -> Panel:
 close_overlay()
 modal=true
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.65); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(shade)
 modal_root=shade
 var panel=host.box(shade,Rect2(450,240,650,330),Color("#101c28"),host.GOLD)
 txt(title,Rect2(30,18,590,42),27,host.GOLD,panel)
 return panel
func settings_menu():
 var panel=overlay("对战设置")
 var cb=CheckButton.new(); cb.text="自动支付"; cb.position=Vector2(30,86); cb.size=Vector2(280,46); cb.button_pressed=auto_pay; panel.add_child(cb)
 cb.toggled.connect(func(value): auto_pay=value)
 btn("继续游戏",Rect2(30,180,260,48),func(): modal=false; render(),true,panel)
 btn("投降",Rect2(330,180,260,48),func():
  var confirm=overlay("确认投降")
  btn("投降",Rect2(35,155,260,50),func(): modal=false; local={}; engine.surrender(0); render(),true,confirm)
  btn("返回",Rect2(330,155,260,50),func(): modal=false; render(); settings_menu(),false,confirm),false,panel)
func result_overlay():
 var panel=overlay("平局" if engine.winner==-1 else "胜利" if engine.winner==0 else "对局结束")
 txt(engine.log.back(),Rect2(30,90,590,80),22,host.WHITE,panel)
 btn("返回对局准备",Rect2(160,220,330,56),func(): host.setup(),true,panel)
func damage_dialog():
 var panel=overlay("分配 %d 点战斗伤害" % engine.pending.total)
 var inputs={}
 for i in range(engine.combat.blockers.size()):
  var t=engine.combat.blockers[i]; var c=engine.find_card(t.uid)
  txt(engine.cards[c.card_id].name,Rect2(25,76+i*53,455,45),17,host.WHITE,panel)
  var spin=SpinBox.new(); spin.min_value=0; spin.max_value=engine.pending.total; spin.step=1; spin.position=Vector2(500,76+i*53); spin.size=Vector2(115,45); panel.add_child(spin); inputs[str(c.uid)]=spin
 btn("确认",Rect2(220,263,200,46),func():
  var allocation={}; var total=0
  for key in inputs: allocation[key]=int(inputs[key].value); total+=allocation[key]
  if total!=engine.pending.total: return
  engine.combat_damage(allocation); modal=false; render(),true,panel)
