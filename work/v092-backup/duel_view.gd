extends Control
const Duel=preload("res://scripts/rules/duel_engine.gd")
const STAGE=Rect2(0,72,1600,598)
const HAND=Rect2(300,668,1010,232)
const COLOR_INK={"红":Color("#cf5b60"),"蓝":Color("#4d94d5"),"绿":Color("#48996d"),"黄":Color("#d9b54f"),"黑":Color("#77758b")}
var debug_mode=false
var debug_controls: Control
var debug_root: Control
var debug_open=false
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
enum ResponseMode { DEFAULT, ON, OFF }
const RESPONSE_LABELS=["默认","开","关"]
var response_mode=ResponseMode.DEFAULT
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
var observing=false
var observe_button: Button
var building_prompt=false
var effects: Control
var damage_values={}
var damage_controls={}
var damage_signature=""
var damage_remainder: Label
var phase_names={"mulligan":"起手调度","reset":"重置阶段","prepare":"准备阶段","draw":"抓牌阶段","possession":"凭依阶段","main":"主要阶段","end":"结束阶段","over":"对局结束"}

func layer(parent: Node) -> Control:
 var node=Control.new(); node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node)
 return node
func begin(parent,a: Dictionary,b: Dictionary,first: int,seed_value: int=0):
 host=parent; debug_mode=host.debug_mode; engine=Duel.new(); engine.debug_enabled=debug_mode; engine.start(a,b,first,seed_value)
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
 table.combat_animation_finished.connect(render)
 table.combat_impact.connect(show_combat_impact)
 table.stack_selected.connect(func(id): choose_target({"stack_id":id}))
 table.card_inspected.connect(inspect_card)
 table.empty_right_clicked.connect(right_cancel)
 table.pile_selected.connect(func(zone):
  if zone in ["pgrave","agrave","pexile","aexile"]:
   var who=0 if zone.begins_with("p") else 1
   browse_zone(who,"exile" if "exile" in zone else "grave")
  elif debug_mode and zone in ["pdeck","adeck"]: browse_zone(0 if zone=="pdeck" else 1,"deck"))
 ui=layer(self); badges=layer(ui)
 var hand_bg=host.box(ui,HAND,Color("#101b29"),Color("#26374a"))
 hand_bg.mouse_filter=Control.MOUSE_FILTER_STOP
 hand_layer=layer(ui); opponent_layer=layer(ui); hud=layer(ui)
 inspection=Control.new(); inspection.position=Vector2(16,83); inspection.size=Vector2(267,580); ui.add_child(inspection)
 effects=layer(ui)
 banner=layer(ui)
 observe_button=btn("观察战场",Rect2(1280,12,162,40),toggle_observation,false,ui)
 observe_button.visible=false
 if debug_mode:
  debug_controls=layer(ui)
  btn("调试",Rect2(325,12,92,38),debug_menu,false,debug_controls)
  btn("你的牌库",Rect2(1045,53,125,34),func(): browse_zone(0,"deck"),false,debug_controls)
  btn("人机牌库",Rect2(1180,53,125,34),func(): browse_zone(1,"deck"),false,debug_controls)
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
 if (modal and not observing) or dragging: return
 if event is InputEventMouseButton:
  var converted=event.duplicate()
  converted.position=event.position/STAGE.size*Vector2(viewport.size)
  table.pointer(converted)
func free_main() -> bool:
 return engine.active==acting_player() and engine.phase=="main" and engine.stack.is_empty() and engine.combat.is_empty()
func in_response_window() -> bool:
 return engine!=null and engine.winner==-2 and engine.priority==acting_player() and engine.phase!="mulligan" and engine.pending.is_empty() and not free_main()
func should_ask_response() -> bool:
 if not in_response_window(): return false
 match response_mode:
  ResponseMode.ON: return true
  ResponseMode.OFF: return false
 return engine.has_response(acting_player())
func response_disabled() -> bool:
 return response_mode==ResponseMode.OFF and in_response_window()
func cycle_response_mode():
 set_response_mode((response_mode+1)%RESPONSE_LABELS.size())
func set_response_mode(mode: int):
 response_mode=clampi(mode,ResponseMode.DEFAULT,ResponseMode.OFF)
 if response_disabled():
  # Uncommitted response selections are private and can be discarded without paying.
  local={}; selection=[]; message=""; drag_uid=0; dragging=false
  if is_instance_valid(drag_art): drag_art.queue_free()
 clock_time=0
 render()
func _process(delta):
 if engine==null: return
 update_badge_positions()
 if debug_open or observing or modal or not local.is_empty() or drag_uid!=0 or engine.winner!=-2: return
 if not fast_mode and (table.is_animating() or Time.get_ticks_msec()<banner_until): return
 clock_time+=delta
 if clock_time<(0.02 if fast_mode else 0.48): return
 clock_time=0
 var before=engine.revision
 if debug_mode:
  if in_response_window() and not should_ask_response(): engine.pass_priority(acting_player())
 elif engine.phase=="mulligan":
  if not engine.players[1].mulligan_done: engine.ai_step()
 elif not engine.pending.is_empty():
  if engine.pending.owner==1: engine.ai_step()
 elif engine.priority==1: engine.ai_step()
 elif in_response_window() and not should_ask_response(): engine.pass_priority(acting_player())
 if before!=engine.revision or last_revision!=engine.revision: render()

func clear_children(node: Node):
 for child in node.get_children(): node.remove_child(child); child.queue_free()
func txt(text: String,rect: Rect2,font: int=18,color: Color=Color("#e8edf0"),parent: Node=null):
 var label=host.label(hud if parent==null else parent,text,rect,font,color)
 if building_prompt and parent==null: label.set_meta("choice_widget",true)
 return label
func btn(text: String,rect: Rect2,action: Callable,accent: bool=false,parent: Node=null):
 var button=host.button(hud if parent==null else parent,text,rect,action,accent)
 if building_prompt and parent==null: button.set_meta("choice_widget",true)
 return button
func highlights() -> Array:
 var result=[]
 if engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done:
  return engine.players[acting_player()].hand.map(func(c): return c.uid)
 if not local.is_empty():
  if local.mode=="payment":
   for resource in payment_sources(): result.append(resource.uid)
  else:
   for target in local_targets():
    if target.has("uid"): result.append(target.uid)
  return result
 if engine.pending.get("owner",-1)==acting_player():
  if engine.pending.kind=="block": return engine.legal_blockers().map(func(c): return c.uid)
  if engine.pending.kind=="discard": return engine.players[acting_player()].hand.map(func(c): return c.uid)
  if engine.pending.kind=="trigger": return (engine.units(0)+engine.units(1)).map(func(c): return c.uid)
  if engine.pending.kind=="possession":
   result=engine.players[acting_player()].palette.filter(func(c): return not c.tapped and engine.can_possess(c)).map(func(c): return c.uid)
   if selected_in_zone("palette")!=0: result.append_array(engine.players[acting_player()].hand.filter(func(c): return engine.can_possess(c)).map(func(c): return c.uid))
   return result
 if response_disabled(): return result
 for c in engine.legal_casts(acting_player()): result.append(c.uid)
 for c in engine.players[acting_player()].field:
  if not engine.available_actions(acting_player(),c.uid).is_empty(): result.append(c.uid)
 return result
func render():
 if not is_instance_valid(ui): return
 close_overlay()
 clear_children(hud)
 last_revision=engine.revision
 var available=highlights()
 table.sync(local.get("plan",[]),selected_uids(),available,not previous_snapshot.is_empty())
 render_hands(available)
 rebuild_badges()
 txt("极 彩",Rect2(24,10,140,42),26,host.GOLD)
 btn("响应："+RESPONSE_LABELS[response_mode],Rect2(180,12,136,38),cycle_response_mode,response_mode==ResponseMode.ON)
 txt("第 %d 回合  ·  %s  ·  %s" % [engine.turn,"你" if engine.active==0 else "人机",phase_names[engine.phase]],Rect2(430,12,790,42),23,host.GOLD)
 btn("设置",Rect2(1460,12,116,40),settings_menu)
 if debug_mode:
  txt("操作："+("你" if acting_player()==0 else "人机"),Rect2(1115,15,158,32),18,host.GOLD)
 elif engine.legal_casts(0).any(func(c): return c.zone=="deck"):
  btn("牌库可用牌",Rect2(1155,53,150,34),func(): browse_zone(0,"deck"))
 btn("人机  %d" % engine.players[1].life,Rect2(1350,92,214,45),func(): choose_target({"player":1}))
 btn("你  %d" % engine.players[0].life,Rect2(27,785,243,58),func(): choose_target({"player":0}))
 txt("手牌 %d" % engine.players[1].hand.size(),Rect2(1070,88,170,30),18,host.WHITE)
 if not engine.stack.is_empty():
  txt("堆叠  %d" % engine.stack.size(),Rect2(1330,552,255,34),22,host.GOLD)
 building_prompt=true
 render_prompt()
 building_prompt=false
 if not message.is_empty(): txt(message,Rect2(307,639,995,28),18,Color("#f0cf93"))
 if not engine.log.is_empty(): txt(engine.log.back(),Rect2(320,53,990,26),15,host.MUTED)
 update_inspection()
 if last_phase!=engine.phase or last_turn!=engine.turn:
  show_phase_banner()
 last_phase=engine.phase; last_turn=engine.turn
 previous_snapshot=table.card_snapshot()
 if engine.winner!=-2 and not table.combat_animating: result_overlay()
 elif engine.pending.get("kind","")=="damage_assignment" and engine.pending.owner==acting_player() and not table.combat_animating: damage_dialog()
 refresh_observation()

func render_hands(available: Array):
 sync_hand_nodes(0,hand_nodes,hand_layer,available)
 sync_hand_nodes(1,enemy_nodes,opponent_layer,available if debug_mode else [])
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
  var tile_size=Vector2(146,204) if who==0 else Vector2(88,123) if debug_mode else Vector2(54,75)
  var stride=minf(154,950.0/maxi(1,cards.size())) if who==0 else minf(90 if debug_mode else 52,750.0/maxi(1,cards.size()))
  var target=Vector2(315+i*stride,687) if who==0 else Vector2(780-(cards.size()-1)*stride/2+i*stride,70)
  var fresh=not nodes.has(c.uid)
  if fresh:
   var tile=preload("res://scripts/duel_hand_card.gd").new()
   tile.size=tile_size; parent.add_child(tile); tile.build(self,c,who==1 and not debug_mode)
   nodes[c.uid]=tile
   var old=previous_snapshot.get(c.uid,{})
   tile.position=project(table.zone_position(old.get("zone","deck"),who)) if not previous_snapshot.is_empty() else target+Vector2(0,65 if who==0 else -65)
   tile.modulate.a=0.1
  var node=nodes[c.uid]
  if node.card_id!=c.card_id:
   node.card_id=c.card_id
   if who==0 or debug_mode:
    node.art.texture=host.texture(c.card_id); node.tooltip_text=engine.cards[c.card_id].name
  node.update_style(c.uid in available,c.uid in selected_uids())
  if fresh or node.get_meta("target",Vector2(-999,-999))!=target:
   if hand_tweens.has(c.uid) and hand_tweens[c.uid].is_valid(): hand_tweens[c.uid].kill()
   var tween=create_tween().set_parallel(true)
   tween.tween_property(node,"position",target,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   tween.tween_property(node,"modulate:a",1.0,0.3)
   hand_tweens[c.uid]=tween; node.set_meta("target",target)

func rebuild_badges():
 clear_children(badges); card_badges={}
 for key in table.descriptors:
  var d=table.descriptors[key]
  if d.zone not in ["field","leader"]: continue
  var c=table.old_cards.get(d.uid,{}) if table.combat_animating else engine.find_card(d.uid)
  if c.is_empty(): continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  var parts={"root":root,"zone":d.zone,"owner":d.owner}
  if d.zone=="field" and engine.is_unit(c):
   var panel=host.box(root,Rect2(0,0,90,26),Color("#111d2b"),Color("#aaa080")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   var stat_names=["power","health","spirit"]
   var positions=[0,32,63]
   parts.values={}
   for index in range(3):
    var key_name=stat_names[index]
    var value=engine.stat(c,key_name)-(c.damage if key_name=="health" else 0)
    var base=int(engine.cards[c.card_id][key_name])
    var label=txt(str(value),Rect2(positions[index],0,27,26),16,stat_color(value,base),panel)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    parts.values[key_name]=label
   txt("/",Rect2(27,0,7,26),16,host.WHITE,panel)
   txt("·",Rect2(58,0,7,26),16,host.WHITE,panel)
   parts.stats=panel
   var marker=combat_marker(c.uid)
   if not marker.is_empty():
    var icon=TextureRect.new(); icon.size=Vector2(42,42)
    icon.texture=load("res://assets/combat_"+marker+".svg")
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    icon.set_meta("combat_role",marker); root.add_child(icon); parts.marker=icon
  elif d.zone=="leader" and c.timer>0:
   parts.sick=txt("计时 %d" % c.timer,Rect2(0,0,100,24),17,host.GOLD,root)
  card_badges[key]=parts
 for key in table.piles:
  if "exile" in key and engine.players[0 if key.begins_with("p") else 1].exile.is_empty(): continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  card_badges[key]={"root":root,"zone":"pile"}
  var zone_name="deck" if "deck" in key else "exile" if "exile" in key else "grave"
  var who=0 if key.begins_with("p") else 1
  var label=txt({"deck":"牌库 ","grave":"墓地 ","exile":"除外 "}[zone_name]+str(engine.players[who][zone_name].size()),Rect2(-48,0,96,26),17,host.WHITE,root)
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
   if parts.has("stats"): parts.stats.position=Vector2(-45,rect.size.y/2-25)
   if parts.has("marker"): parts.marker.position=Vector2(rect.size.x/2-32,-rect.size.y/2-10)
   if parts.has("sick"): parts.sick.position=Vector2(-49,rect.size.y/2+1)
  elif table.piles.has(key):
   root.position=project(table.piles[key].position+Vector3(0,0.03,1.3))
  root.visible=root.position.x>292 and root.position.y>140 and root.position.y<635
  if parts.zone!="stack" and stack_rects.any(func(r): return r.has_point(root.position)): root.visible=false

func show_phase_banner():
 clear_children(banner)
 if is_instance_valid(banner_tween): banner_tween.kill()
 var caption=phase_names[engine.phase]
 if engine.turn!=last_turn: caption=("你的回合" if engine.active==0 else "对手回合")+" · "+caption
 var label=txt(caption,Rect2(420,314,850,76),42,Color("#fff2c0"),banner)
 label.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.03,0.95))
 label.add_theme_constant_override("shadow_offset_x",3)
 label.add_theme_constant_override("shadow_offset_y",4)
 label.add_theme_constant_override("outline_size",5)
 label.add_theme_color_override("font_outline_color",Color("#151a24"))
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
 var signature=inspect_id+str(inspect_uid)+inspect_caption+str(engine.summoning_sick(current))+str(engine.has_haste(current))
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
 scroll.add_child(text)

func render_prompt():
 if table.combat_animating: return
 var text=""
 if not local.is_empty():
  text=local_prompt()
  btn("取消使用",Rect2(1330,680,237,45),cancel_cast)
  if local.mode=="target":
   btn("选择目标",Rect2(1330,745,237,50),open_local_choices,true)
  if local.mode=="payment":
   var valid=engine.payment_valid(acting_player(),local_cost(),local.plan)
   var b=btn("确认支付",Rect2(1330,738,237,50),commit_local,true); b.disabled=not valid
   btn("重选费用",Rect2(1330,805,237,43),func(): local.plan=[]; render())
 elif engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done:
  text="选择要调度的手牌"
  btn("保留" if selection.is_empty() else "调度 %d 张" % selection.size(),Rect2(1330,770,237,55),func(): engine.mulligan(acting_player(),selection); selection=[]; render(),true)
 elif engine.pending.get("owner",-1)==acting_player():
  match engine.pending.kind:
   "effect_choice":
    text=engine.pending.trigger.name
    btn("选择",Rect2(1330,735,237,52),open_effect_choices,true)
    if engine.pending.trigger.optional: btn("不使用",Rect2(1330,803,237,45),func(): engine.choose_effect({}); render())
   "timer":
    text="计时指示物"
    for i in range(3):
     var delta=i-1
     btn(["−1","不改变","+1"][i],Rect2(1330+i*80,770,75,50),func(): engine.choose_timer(delta); render())
   "possession":
    text="凭依"
    var confirm=btn("确定凭依",Rect2(1330,735,237,52),confirm_possession,true)
    confirm.disabled=selected_in_zone("palette")==0 or selected_in_zone("hand")==0
    btn("跳过凭依",Rect2(1330,803,237,45),func(): engine.possession(); selection=[]; render())
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
 elif engine.priority==acting_player() and engine.winner==-2:
  if free_main():
   text=("你" if acting_player()==0 else "人机")+"的行动"
   btn("结束主要阶段",Rect2(1330,770,237,55),func(): engine.pass_priority(acting_player()); message=""; render(),true)
  elif should_ask_response():
   text="响应窗口"
   btn("不响应 / 继续",Rect2(1330,770,237,55),func(): engine.pass_priority(acting_player()); message=""; render(),true)
 txt(text,Rect2(310,605,1000,37),21,host.GOLD)

func begin_hand_drag(uid: int,at: Vector2):
 if debug_open or observing or modal or table.combat_animating or not local.is_empty() or response_disabled(): return
 if engine.find_card(uid).owner!=acting_player(): return
 drag_uid=uid; drag_origin=at; drag_pointer=at; dragging=false
func _input(event: InputEvent):
 if observing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var point=make_input_local(event).position
  if not observe_button.get_global_rect().has_point(point) and not STAGE.has_point(point) and not inspection.get_global_rect().has_point(point):
   get_viewport().set_input_as_handled(); return
 if action_menu_open and not observing and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
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
   if engine.pending.is_empty() and engine.phase!="mulligan":
    selection=[drag_uid]
    if hand_nodes.has(drag_uid): hand_nodes[drag_uid].update_style(true,true)
   drag_art=host.card(ui,engine.find_card(drag_uid).card_id,Rect2(at-Vector2(82,115),Vector2(164,230)))
   drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; drag_art.modulate.a=0.9
   var drag_style=host.style(Color("#27313d"),Color("#ffd65c")); drag_style.set_border_width_all(5)
   drag_art.add_theme_stylebox_override("panel",drag_style)
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
 if cancelled:
  selection=[]; render(); return
 if moved:
  if not hand_area(engine.find_card(uid).owner).has_point(at): request_cast(uid)
  else: selection=[]; render()
 else: hand_clicked(uid)
func hand_clicked(uid: int):
 if response_disabled(): return
 message=""
 if engine.phase=="mulligan" or engine.pending.get("kind","")=="discard": toggle_selection(uid); return
 if engine.pending.get("kind","")=="possession" and engine.pending.owner==acting_player():
  if selected_in_zone("palette")!=0 and engine.can_possess(engine.find_card(uid)): select_possession(uid,"hand")
  return
 # Select without casting. Casting remains a drag outside the hand zone.
 if engine.cast_error(acting_player(),uid).is_empty():
  selection=[] if uid in selection else [uid]
  render()
func selected_in_zone(zone: String) -> int:
 for uid in selection:
  var c=engine.find_card(uid)
  if not c.is_empty() and c.zone==zone and c.owner==acting_player(): return uid
 return 0
func select_possession(uid: int,zone: String):
 var old=selected_in_zone(zone)
 if old!=0: selection.erase(old)
 if old!=uid: selection.append(uid)
 if zone=="palette" and old==uid: selection=[]
 render()
func confirm_possession():
 var p=selected_in_zone("palette"); var h=selected_in_zone("hand")
 if p==0 or h==0: return
 engine.possession(p,h); selection=[]; render()
func right_cancel():
 if observing:
  if is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
  return
 if not local.is_empty(): cancel_cast()
 elif engine.pending.get("kind","")=="possession": selection=[]; render()
 elif is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
func object_clicked(uid: int):
 if observing or table.combat_animating: return
 message=""
 if not local.is_empty():
  if local.mode=="payment": reserve_resource(uid)
  else:
   var target=engine.find_card(uid)
   if not target.is_empty(): choose_target(engine.ref_target(target))
  return
 var c=engine.find_card(uid)
 if engine.pending.get("owner",-1)==acting_player():
  match engine.pending.kind:
   "trigger":
    if not c.is_empty(): choose_target(engine.ref_target(c))
   "block":
    if c in engine.legal_blockers(): toggle_selection(uid)
   "possession":
    if not c.is_empty() and c.owner==acting_player() and c.zone=="palette" and not c.tapped and engine.can_possess(c): select_possession(uid,"palette")
  return
 if c.is_empty(): return
 if c.owner==acting_player() and c.zone=="leader": request_cast(uid)
 elif c.owner==acting_player() and c.zone=="field": open_actions(c)
func open_actions(c: Dictionary):
 if response_disabled(): return
 var actions=engine.available_actions(acting_player(),c.uid)
 if actions.size()==1 and actions[0].type=="attack":
  execute_action(actions[0]); return
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
  var label=txt(action.label,Rect2(20+i*206,321,185,74),18,host.GOLD if action.enabled else host.MUTED,panel)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func execute_action(action: Dictionary):
 if response_disabled() or not action.enabled: return
 close_overlay()
 if action.type=="attack": selection=[]; engine.attack(acting_player(),action.uid); render()
 elif action.type=="extension":
  local={"uid":action.uid,"action":"extension","key":action.key,"mode":"target","target":{},"plan":[]}
  if local_targets()==[{"none":true}]: local.target={"none":true}; start_payment()
  else: render(); open_local_choices()
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
 if local.get("action","")=="extension": return engine.Extra.activation_cost(local.key)
 if local.get("action","")=="ability": return engine.ability_parameters(local.uid,local.index).get("费用",{})
 return engine.cast_cost(acting_player(),engine.find_card(local.uid))
func local_targets() -> Array:
 if local.get("action","")=="extension": return engine.Extra.activation_options(engine,engine.find_card(local.uid),local.key)
 if local.get("action","")=="ability": return engine.ability_targets()
 return engine.targets_for(engine.find_card(local.uid).card_id,acting_player())
func payment_sources() -> Array:
 var sources=engine.source_resources(acting_player())
 if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false):
  sources=sources.filter(func(r): return r.uid!=local.uid)
 var cost=local_cost()
 return sources.filter(func(r):
  if local.plan.any(func(p): return p.uid==r.uid): return true
  return r.colors.any(func(color): return local.plan.filter(func(p): return p.color==color).size()<int(cost.get(color,0))))
func close_overlay():
 modal=false; action_menu_open=false; observing=false
 for child in hud.get_children():
  if child.has_meta("choice_widget"): child.visible=true
 if is_instance_valid(modal_root):
  modal_root.get_parent().remove_child(modal_root); modal_root.queue_free()
 modal_root=null
 refresh_observation()

func request_cast(uid: int):
 if observing or table.combat_animating or response_disabled(): return
 var error=engine.cast_error(acting_player(),uid)
 if not error.is_empty(): message=error; render(); return
 local={"uid":uid,"target":{},"plan":[],"mode":"target"}
 var c=engine.find_card(uid)
 if engine.cards[c.card_id].kind=="符卡":
  if local_targets()==[{"none":true}]: local.target={"none":true}; start_payment()
  else:
   render()
   if engine.Extra.spell_options(engine,c.card_id,acting_player())!=null: open_local_choices()
 else: start_payment()
func choose_target(target: Dictionary):
 if observing or table.combat_animating: return
 if engine.pending.get("kind","")=="trigger" and engine.pending.owner==acting_player():
  if engine.target_valid(target,true): engine.choose_trigger(target); render()
  return
 if local.is_empty() or local.mode!="target": return
 if target not in local_targets():
  var candidates=local_targets().filter(func(t): return t.get("uid",-1)==target.get("uid",-2) or t.get("player",-1)==target.get("player",-2) or t.get("stack_id",-1)==target.get("stack_id",-2))
  if not candidates.is_empty(): choose_options("选择",candidates,func(chosen): local.target=chosen; start_payment()); return
  message="目标不合法"; render(); return
 local.target=target
 start_payment()
func start_payment():
 var c=engine.find_card(local.uid)
 var excluded=[local.uid] if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false) else []
 var solution=engine.payment(acting_player(),local_cost(),excluded)
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
 if local.is_empty() or response_disabled(): return
 var error=engine.commit_extension(acting_player(),local.uid,local.target,local.plan) if local.get("action","")=="extension" else engine.commit_ability(acting_player(),local.uid,local.index,local.target,local.plan) if local.get("action","")=="ability" else engine.commit_cast(acting_player(),local.uid,local.target,local.plan)
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
 refresh_observation()
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
 if engine.pending.get("kind","")!="damage_assignment": return
 var targets=engine.combat.blockers
 var signature=str(engine.combat.attacker)+str(targets)+str(engine.pending.total)
 if signature!=damage_signature:
  damage_signature=signature; damage_values={}
  for target in targets.slice(0,-1): damage_values[str(target.uid)]=0
 var panel=overlay("分配 %d 点战斗伤害" % engine.pending.total)
 var count=targets.size()-1
 var width=maxf(510,count*178+44)
 panel.position=Vector2(800-width/2,208); panel.size=Vector2(width,457)
 panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 damage_controls={}
 for i in range(count):
  var c=engine.find_card(targets[i].uid); var key=str(c.uid)
  var at=Vector2((width-(count*178-28))/2+i*178,73)
  var art=TextureRect.new(); art.position=at; art.size=Vector2(150,210)
  art.texture=host.texture(c.card_id); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.set_meta("damage_card",c.uid); panel.add_child(art)
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: inspect_card(c.card_id,c.uid))
  var value=txt("0",Rect2(at.x+48,293,54,40),27,host.WHITE,panel); value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  var minus=btn("−",Rect2(at.x,295,40,37),func(): change_damage(key,-1),false,panel)
  var plus=btn("+",Rect2(at.x+110,295,40,37),func(): change_damage(key,1),false,panel)
  damage_controls[key]={"value":value,"minus":minus,"plus":plus}
 damage_remainder=txt("",Rect2(24,343,width-48,47),19,host.WHITE,panel)
 damage_remainder.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 btn("确定分配",Rect2(width/2-105,400,210,49),confirm_damage,true,panel)
 update_damage_controls()
 refresh_observation()
func change_damage(key: String,delta: int):
 var remaining=damage_remaining()
 if delta>0 and remaining<=0: return
 damage_values[key]=maxi(0,int(damage_values[key])+delta)
 update_damage_controls()
func damage_remaining() -> int:
 var used=0
 for value in damage_values.values(): used+=int(value)
 return maxi(0,int(engine.pending.get("total",0))-used)
func update_damage_controls():
 var remaining=damage_remaining()
 for key in damage_controls:
  var controls=damage_controls[key]
  controls.value.text=str(damage_values[key]); controls.minus.disabled=damage_values[key]==0; controls.plus.disabled=remaining==0
 var last=engine.find_card(engine.combat.blockers.back().uid)
 damage_remainder.text=engine.cards[last.card_id].name+"：剩余 %d 点" % remaining
func confirm_damage():
 if observing or engine.pending.get("kind","")!="damage_assignment": return
 var allocation=damage_values.duplicate()
 allocation[str(engine.combat.blockers.back().uid)]=damage_remaining()
 engine.combat_damage(allocation); damage_values={}; damage_signature=""; modal=false; render()

func selected_uids() -> Array:
 var selected=selection.duplicate()
 if not local.is_empty():
  if local.uid not in selected: selected.append(local.uid)
  var target=local.get("target",{})
  if target.has("uid") and target.uid not in selected: selected.append(target.uid)
 return selected
func stat_color(value: int,base: int) -> Color:
 return Color("#69e59a") if value>base else Color("#ff737b") if value<base else host.WHITE
func combat_marker(uid: int) -> String:
 if engine.combat.is_empty(): return ""
 if engine.combat.attacker.uid==uid: return "sword"
 if engine.combat.blockers.any(func(t): return t.uid==uid): return "shield"
 if engine.pending.get("kind","")=="block" and uid in selection: return "shield"
 return ""
func show_combat_impact(attacker_uid: int,blocker_uid: int):
 var attacker=table.visuals.get("card_"+str(attacker_uid))
 if not is_instance_valid(attacker): return
 var at=attacker.global_position
 var blocker=table.visuals.get("card_"+str(blocker_uid))
 if is_instance_valid(blocker): at=(at+blocker.global_position)*0.5
 var point=project(at)
 var flash=txt("✦",Rect2(point-Vector2(45,50),Vector2(90,100)),72,Color("#fff0bc"),effects)
 flash.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var tween=create_tween(); tween.tween_property(flash,"modulate:a",0.0,0.28); tween.tween_callback(flash.queue_free)
func choice_active() -> bool:
 return engine!=null and engine.winner==-2 and not table.combat_animating and (debug_open or modal or not local.is_empty() or engine.pending.get("owner",-1)==acting_player() or (engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done))
func refresh_observation():
 if not is_instance_valid(observe_button): return
 observe_button.visible=choice_active() or observing
 observe_button.text="返回选择" if observing else "观察战场"
 ui.move_child(inspection,-1)
 ui.move_child(observe_button,-1)
 if is_instance_valid(debug_controls): ui.move_child(debug_controls,-1)
func toggle_observation():
 observing=not observing
 if is_instance_valid(modal_root): modal_root.visible=not observing
 if is_instance_valid(debug_root): debug_root.visible=not observing
 for child in hud.get_children():
  if child.has_meta("choice_widget"): child.visible=not observing
 refresh_observation()

func acting_player() -> int:
 if not debug_mode or engine==null: return 0
 if not engine.pending.is_empty(): return int(engine.pending.owner)
 if engine.phase=="mulligan": return 0 if not engine.players[0].mulligan_done else 1
 return engine.priority
func hand_area(who: int) -> Rect2:
 return HAND if who==0 else Rect2(320,60,1000,150)
func target_caption(t: Dictionary) -> String:
 if t.has("parts"): return " + ".join(t.parts.map(func(x): return target_caption(x)))
 var parts=[]
 if t.has("mode"): parts.append(t.mode)
 if t.has("color"): parts.append(t.color)
 if t.has("uid"):
  var c=engine.find_card(t.uid)
  if not c.is_empty(): parts.append(("你 · " if c.owner==0 else "人机 · ")+engine.cards[c.card_id].name)
 elif t.has("player"): parts.append("你" if t.player==0 else "人机")
 elif t.has("stack_id"):
  for entry in engine.stack:
   if entry.id==t.stack_id: parts.append(entry.name)
 if t.has("sacrifice"):
  var c=engine.find_card(t.sacrifice.uid)
  if not c.is_empty(): parts.append("牺牲："+engine.cards[c.card_id].name)
 return " · ".join(parts) if not parts.is_empty() else "使用"
func choose_options(title: String,options: Array,callback: Callable):
 var panel=overlay(title)
 panel.position=Vector2(345,155); panel.size=Vector2(915,590)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(25,77); scroll.size=Vector2(865,424); panel.add_child(scroll)
 var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
 for option in options:
  var row=Button.new(); row.text=target_caption(option); row.custom_minimum_size=Vector2(825,54)
  row.add_theme_font_size_override("font_size",18); column.add_child(row)
  row.pressed.connect(func(): close_overlay(); callback.call(option))
  row.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and option.has("uid"):
    var c=engine.find_card(option.uid)
    if not c.is_empty(): inspect_card(c.card_id,c.uid))
 btn("返回",Rect2(660,520,220,46),func(): close_overlay(),false,panel)
func open_local_choices():
 var options=local_targets()
 if not options.is_empty() and options[0].has("parts"):
  var first=[]
  for option in options:
   if option.parts[0] not in first: first.append(option.parts[0])
  choose_options("选择第一项",first,func(a):
   var second=[]
   for option in options:
    if option.parts[0]==a: second.append(option.parts[1])
   choose_options("选择第二项",second,func(b): local.target={"parts":[a,b]}; start_payment()))
 else: choose_options("选择目标",options,func(target): local.target=target; start_payment())
func open_effect_choices():
 choose_options(engine.pending.trigger.name,engine.pending.options,func(target): engine.choose_effect(target); render())
func close_debug():
 if is_instance_valid(debug_root): debug_root.queue_free()
 debug_root=null; debug_open=false
 if observing:
  observing=false
  if is_instance_valid(modal_root): modal_root.visible=true
  for widget in hud.get_children():
   if widget.has_meta("choice_widget"): widget.visible=true
 refresh_observation()
func debug_panel(title: String) -> Panel:
 close_debug(); debug_open=true
 debug_root=Control.new(); debug_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(debug_root)
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); debug_root.add_child(shade)
 var panel=host.box(debug_root,Rect2(295,110,1280,745),Color("#101c28"),host.GOLD)
 txt(title,Rect2(25,14,1000,43),27,host.GOLD,panel)
 btn("返回",Rect2(1110,15,140,42),close_debug,false,panel)
 refresh_observation()
 return panel
func browse_zone(who: int,zone: String):
 var hidden=zone=="deck" and not debug_mode
 var cards=engine.players[who][zone]
 if hidden: cards=cards.filter(func(c): return engine.Extra.has(engine.cards[c.card_id],"deck_damage"))
 var title=("你" if who==0 else "人机")+" · "+{"deck":"牌库","grave":"墓地","exile":"除外区"}.get(zone,zone)
 var panel=debug_panel(title+"  %d" % cards.size())
 var scroll=ScrollContainer.new(); scroll.position=Vector2(20,74); scroll.size=Vector2(1235,645); panel.add_child(scroll)
 var grid=GridContainer.new(); grid.columns=7; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",15); scroll.add_child(grid)
 for c in cards:
  var tile=Control.new(); tile.custom_minimum_size=Vector2(162,354); grid.add_child(tile)
  var art=host.card(tile,c.card_id,Rect2(0,0,160,224),func(): inspect_card(c.card_id,c.uid))
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: inspect_card(c.card_id,c.uid))
  var name=txt(engine.cards[c.card_id].name,Rect2(0,230,160,74),16,host.WHITE,tile)
  name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  if c.owner==acting_player() and not response_disabled() and engine.pending.is_empty():
   var action=engine.extra_action(c)
   if zone=="grave" and not action.is_empty() and engine.extension_activation_error(c.owner,c).is_empty():
    btn("发动",Rect2(30,309,100,40),func(): close_debug(); execute_action(action),true,tile)
   elif zone=="deck" and engine.cast_error(c.owner,c.uid).is_empty():
    btn("使用",Rect2(30,309,100,40),func(): close_debug(); request_cast(c.uid),true,tile)
func debug_menu():
 if not debug_mode: return
 var panel=debug_panel("调试")
 for who in range(2):
  btn(("你" if who==0 else "人机")+"的牌库",Rect2(30+who*220,73,200,42),func(): browse_zone(who,"deck"),false,panel)
 var picker=OptionButton.new(); picker.position=Vector2(30,141); picker.size=Vector2(1210,48); panel.add_child(picker)
 var entries=[]
 var zones={"hand":"手牌","deck":"牌库","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外区","leader":"自机区","stack":"堆叠"}
 var seen=[]
 for who in range(2):
  var list=[engine.players[who].leader]
  for zone in ["hand","deck","field","palette","grave","exile"]: list+=engine.players[who][zone]
  for entry in engine.stack:
   if entry.kind=="card" and entry.owner==who: list.append(entry.card)
  for c in list:
   if c.uid in seen: continue
   seen.append(c.uid); entries.append(c.uid)
   picker.add_item(("你" if who==0 else "人机")+" / "+zones.get(c.zone,c.zone)+" / "+engine.cards[c.card_id].name+" #%d" % c.uid)
 var destination=OptionButton.new(); destination.position=Vector2(30,224); destination.size=Vector2(440,48); panel.add_child(destination)
 var destinations=["hand","deck","field","palette","grave","exile","leader","stack"]
 for zone in destinations: destination.add_item(zones[zone])
 var status_label=txt("",Rect2(30,362,1190,120),22,host.GOLD,panel); status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 btn("移动",Rect2(510,224,200,48),func():
  if entries.is_empty(): return
  var uid=entries[picker.selected]; var target=destinations[destination.selected]
  if target=="stack":
   close_debug(); request_cast(uid); return
  if not local.is_empty(): status_label.text="请先完成或取消当前使用"; return
  var error=engine.debug_move(uid,target)
  if error.is_empty(): close_debug(); selection=[]; render(); debug_menu()
  else: status_label.text=error,true,panel)
 btn("查看卡牌",Rect2(750,224,210,48),func():
  if not entries.is_empty():
   var c=engine.find_card(entries[picker.selected]); inspect_card(c.card_id,c.uid),false,panel)
 btn("双方墓地 / 除外区",Rect2(30,307,280,46),func():
  close_debug()
  var options=[]
  for who in range(2):
   for zone in ["grave","exile"]: options.append({"player":who,"mode":zone})
  choose_options("查看区域",options,func(t): browse_zone(t.player,t.mode)),false,panel)
