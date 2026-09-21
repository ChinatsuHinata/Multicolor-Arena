extends Control
const Duel=preload("res://scripts/rules/duel_engine.gd")
const AbilityCaption=preload("res://scripts/rules/ability_caption.gd")
const STAGE=Rect2(246,100,1030,558)
const HAND=Rect2(246,663,1030,232)
const SIDEBAR=Rect2(1290,163,294,477)
const COLOR_INK={"红":Color("#cf5b60"),"蓝":Color("#4d94d5"),"绿":Color("#48996d"),"黄":Color("#d9b54f"),"黑":Color("#77758b")}
var debug_mode=false
var debug_controls: Control
var debug_button: Button
var debug_root: Control
var debug_open=false
var history_open=false
var history_root: Control
var history_panel: Panel
var region_selected: Dictionary={}
var region_tiles={}
var inspection_text: RichTextLabel
const ZONE_NAMES={"deck":"牌库","grave":"墓地","exile":"除外区","field":"战场","palette":"颜色盘","hand":"手牌","leader":"自机区","stack":"堆叠"}
var hand_zones={0:"hand",1:"hand"}
var hand_zone_tabs={}
var debug_drag_browser=false
var browser_owner=0
var browser_zone="deck"
var browser_scroll: ScrollContainer
var browser_cards: GridContainer
var browser_panel: Panel
var debug_drag_uid=0
var debug_drag_epoch=0
var debug_dragging=false
var debug_drag_origin=Vector2.ZERO
var debug_drag_pointer=Vector2.ZERO
var debug_drag_art: Control
var debug_drop_hint: Label
var attack_preview_uid=0
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
var picker=preload("res://scripts/target_picker.gd").new()
var life_widgets={}
var arrow_layer: Control
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
 table.combat_damage_shown.connect(rebuild_badges)
 table.combat_impact.connect(show_combat_impact)
 table.stack_selected.connect(func(id): choose_target({"stack_id":id}))
 table.card_inspected.connect(inspect_card)
 table.empty_right_clicked.connect(right_cancel)
 table.pile_selected.connect(func(zone):
  if zone in ["pgrave","agrave","pexile","aexile"]:
   var who=0 if zone.begins_with("p") else 1
   browse_zone(who,"exile" if "exile" in zone else "grave")
  elif zone in ["pdeck","adeck"]: browse_zone(0 if zone=="pdeck" else 1,"deck"))
 ui=layer(self); badges=layer(ui)
 arrow_layer=preload("res://scripts/stack_arrows.gd").new(); arrow_layer.view=self; arrow_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(arrow_layer)
 var hand_bg=host.box(ui,HAND,Color("#101b29"),Color("#26374a"))
 hand_bg.mouse_filter=Control.MOUSE_FILTER_STOP
 hand_layer=layer(ui); opponent_layer=layer(ui); hud=layer(ui)
 ui.move_child(arrow_layer,-1)
 inspection=Control.new(); inspection.position=Vector2(16,100); inspection.size=Vector2(218,660); ui.add_child(inspection)
 effects=layer(ui)
 banner=layer(ui)
 observe_button=btn("观察战场",Rect2(1290,12,152,40),toggle_observation,false,ui)
 observe_button.visible=false
 if debug_mode:
  debug_controls=layer(ui)
  debug_button=btn("调试",Rect2(1460,57,116,34),debug_menu,false,debug_controls)
  debug_button.toggle_mode=true
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
 if table.combat_animating: return
 if debug_mode and can_begin_debug_drag() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  var uid=table.card_at(event.position/STAGE.size*Vector2(viewport.size))
  if uid>0:
   begin_debug_drag(uid,STAGE.position+event.position); return
 if history_open or (modal and not observing) or dragging or debug_drag_uid!=0: return
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
 if table.combat_animating or history_open or debug_drag_uid!=0 or observing or modal or not local.is_empty() or drag_uid!=0 or engine.winner!=-2: return
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
  elif local.mode=="target":
   for target in picker.available_refs():
    if target.has("uid"): result.append(target.uid)
  return result
 if engine.pending.get("owner",-1)==acting_player():
  if engine.pending.kind=="block": return engine.legal_blockers().map(func(c): return c.uid)
  if engine.pending.kind=="discard": return engine.players[acting_player()].hand.map(func(c): return c.uid)
  if engine.pending.kind in ["trigger","effect_choice"]: return picker.available_refs().filter(func(t): return t.has("uid")).map(func(t): return t.uid)
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
 if attack_preview_uid!=0 and not engine.can_attack(acting_player(),attack_preview_uid):
  selection.erase(attack_preview_uid); attack_preview_uid=0
 close_overlay()
 clear_children(hud)
 last_revision=engine.revision
 sync_picker()
 var available=highlights()
 table.targetable_stacks=picker.available_refs().filter(func(t): return t.has("stack_id")).map(func(t): return t.stack_id) if picker_active() else []
 table.selected_stacks=picker.selected_refs().filter(func(t): return t.has("stack_id")).map(func(t): return t.stack_id)
 table.sync(local.get("plan",[]),selected_uids(),available,not previous_snapshot.is_empty())
 render_hands(available)
 rebuild_badges()
 btn("响应："+RESPONSE_LABELS[response_mode],Rect2(1144,12,136,38),cycle_response_mode,response_mode==ResponseMode.ON)
 txt("第 %d 回合  ·  %s  ·  %s" % [engine.turn,"你" if engine.active==0 else "人机",phase_names[engine.phase]],Rect2(310,12,790,42),23,host.GOLD)
 btn("设置",Rect2(1460,12,116,40),settings_menu)
 btn("对局记录",Rect2(1310,99,266,40),open_history)
 if debug_mode:
  txt("操作："+("你" if acting_player()==0 else "人机"),Rect2(970,15,158,32),18,host.GOLD)
 life_widgets={}
 render_life(1,Rect2(18,18,218,61))
 render_life(0,Rect2(18,793,218,70))
 txt("手牌 %d" % engine.players[1].hand.size(),Rect2(1070,78,170,30),18,host.WHITE)
 if not engine.stack.is_empty():
  txt("堆叠  %d" % engine.stack.size(),Rect2(1330,552,255,34),22,host.GOLD)
 building_prompt=true
 if not table.combat_animating: render_prompt()
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
 elif engine.pending.get("kind","")=="trigger_order" and engine.pending.owner==acting_player() and not table.combat_animating: trigger_order_menu()
 elif region_picker_needed() and not table.combat_animating: region_picker()
 refresh_observation()
 if debug_open and is_instance_valid(debug_root): ui.move_child(debug_root,-1); ui.move_child(observe_button,-1)
 if debug_open and not debug_dragging and not observing and not table.combat_animating:
  var scroll_at=browser_scroll.scroll_vertical
  browse_zone(browser_owner,browser_zone,scroll_at)
 update_browser_styles()
 if history_open and is_instance_valid(history_root): ui.move_child(history_root,-1)

func render_hands(available: Array):
 render_hand_zone_tabs()
 sync_hand_nodes(0,hand_nodes,hand_layer,available)
 sync_hand_nodes(1,enemy_nodes,opponent_layer,available if debug_mode else [])
func sync_hand_nodes(who: int,nodes: Dictionary,parent: Control,available: Array):
 var cards=displayed_hand_cards(who)
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
  var target=Vector2(261+i*stride,680) if who==0 else Vector2(760-(cards.size()-1)*stride/2+i*stride,83)
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
  node.update_style(c.uid in available or (c.zone!="hand" and can_use_region_card(c)),c.uid in selected_uids())
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
  if d.zone=="stack":
   for entry in engine.stack:
    if entry.id!=d.stack_id or entry.kind!="ability": continue
    var caption=AbilityCaption.text(entry)
    var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
    var label=txt(caption,Rect2(-118,0,236,68),16,host.WHITE,root)
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label.size=Vector2(236,68)
    label.add_theme_color_override("font_shadow_color",Color("#081019")); label.add_theme_constant_override("shadow_offset_y",2)
    label.add_theme_color_override("font_outline_color",Color("#081019")); label.add_theme_constant_override("outline_size",5)
    card_badges[key]={"root":root,"zone":"stack","caption":label,"stack_index":engine.stack.find(entry)}
   continue
  if d.zone not in ["field","leader"]: continue
  var c=(table.combat_display_cards.get(d.uid,table.old_cards.get(d.uid,{})) if table.damage_revealed else table.old_cards.get(d.uid,{})) if table.combat_animating else engine.find_card(d.uid)
  if c.is_empty(): continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  var parts={"root":root,"zone":d.zone,"owner":d.owner}
  if d.zone=="field" and engine.is_unit(c):
   var panel=host.box(root,Rect2(0,0,76,25),Color("#111d2b"),Color("#aaa080")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   var stat_names=["power","health","spirit"]
   var positions=[0,27,52]
   parts.values={}
   for index in range(3):
    var key_name=stat_names[index]
    var value=c.get("display_stats",{}).get(key_name,engine.stat(c,key_name)-(c.damage if key_name=="health" else 0))
    var base=int(engine.cards[c.card_id][key_name])
    var label=txt(str(value),Rect2(positions[index],0,24,25),15,stat_color(value,base),panel)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    parts.values[key_name]=label
   txt("/",Rect2(23,0,7,25),15,host.WHITE,panel)
   txt("·",Rect2(48,0,7,25),15,host.WHITE,panel)
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
  var count=table.piles[key].get_meta("count",0) if table.combat_animating else engine.players[who][zone_name].size()
  var label=txt({"deck":"牌库 ","grave":"墓地 ","exile":"除外 "}[zone_name]+str(count),Rect2(-48,0,96,26),17,host.WHITE,root)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 update_badge_positions()
func projected_card_rect(node: Node3D) -> Rect2:
 var rect=Rect2(project(node.to_global(Vector3(-0.975,0,-1.36))),Vector2.ZERO)
 for corner in [Vector3(0.975,0,-1.36),Vector3(-0.975,0,1.36),Vector3(0.975,0,1.36)]: rect=rect.expand(project(node.to_global(corner)))
 return rect
func update_badge_positions():
 if not is_instance_valid(table): return
 var stack_rects=[]
 var caption_rects=[]
 for key in table.descriptors:
  if table.descriptors[key].zone=="stack": stack_rects.append(projected_card_rect(table.visuals[key]).grow(6))
 for key in card_badges:
  var parts=card_badges[key]; var root=parts.root
  if table.visuals.has(key):
   var node=table.visuals[key]
   var rect=projected_card_rect(node)
   root.position=rect.get_center()
   if parts.has("stats"): parts.stats.position=Vector2(-38,rect.size.y/2-24)
   if parts.has("marker"): parts.marker.position=Vector2(rect.size.x/2-32,-rect.size.y/2-10)
   if parts.has("sick"): parts.sick.position=Vector2(-49,rect.size.y/2+1)
   if parts.has("caption"):
    root.position=Vector2(clampf(rect.get_center().x,STAGE.position.x+118,STAGE.end.x-118),rect.end.y+6)
    var occupied=Rect2(root.position+parts.caption.position,parts.caption.size)
    for earlier in caption_rects:
     if occupied.grow(4).intersects(earlier):
      root.position.y=earlier.end.y+8; occupied.position.y=root.position.y
    caption_rects.append(occupied)
  elif table.piles.has(key):
   root.position=project(table.piles[key].position+Vector3(0,0.03,1.3))
  root.visible=root.position.x>292 and root.position.y>140 and root.position.y<(790 if parts.zone=="stack" else 635)
  if parts.zone!="stack" and stack_rects.any(func(r): return r.has_point(root.position)): root.visible=false

func show_phase_banner():
 clear_children(banner)
 if is_instance_valid(banner_tween): banner_tween.kill()
 var caption=phase_names[engine.phase]
 if engine.turn!=last_turn: caption=("你的回合" if engine.active==0 else "对手回合")+" · "+caption
 var label=txt(caption,Rect2(375,314,850,76),42,Color("#fff2c0"),banner)
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
 var enabled=not current.is_empty() and engine.has_leader_ability(current)
 inspection.visible=not inspect_id.is_empty()
 var signature=inspect_id+str(inspect_uid)+inspect_caption+str(enabled)
 if signature==inspection_signature: return
 inspection_signature=signature
 clear_children(inspection)
 if inspect_id.is_empty(): return
 var bg=host.box(inspection,Rect2(0,0,218,660),Color("#101d2c"),Color("#52677e"))
 var image=TextureRect.new(); image.position=Vector2(10,10); image.size=Vector2(198,277)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture=load("res://assets/card_back.svg") if inspect_id=="back" else host.texture(inspect_id)
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE; bg.add_child(image)
 var info=engine.cards.get(inspect_id,{})
 var name=inspect_caption if inspect_id=="back" else "红薯" if inspect_id=="potato" else info.name
 var title=txt(name,Rect2(10,296,198,74),18,host.GOLD,bg)
 title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.size=Vector2(198,74)
 inspection_text=RichTextLabel.new(); inspection_text.position=Vector2(10,378); inspection_text.size=Vector2(198,270)
 inspection_text.add_theme_font_size_override("normal_font_size",17); inspection_text.add_theme_color_override("default_color",host.WHITE)
 inspection_text.scroll_active=true; bg.add_child(inspection_text)
 var rules="未公开" if inspect_id=="back" else "任选一种颜色支付 1 点，使用后消失。" if inspect_id=="potato" else info.rules_text
 if info.get("fast",false): inspection_text.add_text("高速\n")
 var at=rules.find("自机能力：")
 if at>=0:
  inspection_text.add_text(rules.left(at))
  inspection_text.push_color(host.WHITE if enabled else Color("#78818b"))
  inspection_text.add_text(rules.substr(at)); inspection_text.pop()
 else: inspection_text.add_text(rules)
 inspection_text.set_meta("leader_enabled",enabled)

func render_prompt():
 if table.combat_animating: return
 var text=""
 if not local.is_empty():
  text=local_prompt()
  if local.mode=="target": render_inline_picker(confirm_declaration)
  elif local.mode=="payment_offer":
   btn("自动支付",Rect2(1330,690,237,49),pay_automatically,true)
   btn("手动支付",Rect2(1330,752,237,49),func(): local.mode="payment"; render())
  elif local.mode=="payment_color":
   for i in range(local.colors.size()):
    var color=local.colors[i]
    btn(color,Rect2(1330+(i%2)*120,676+(i/2)*49,112,43),func(): local.plan.append({"uid":local.resource,"color":color}); local.mode="payment"; render(),true)
  if local.mode!="target": btn("取消使用",Rect2(1330,833,237,43),cancel_cast)
  if local.mode=="payment":
   var valid=engine.payment_valid(acting_player(),local_cost(),local.plan)
   var b=btn("确认支付",Rect2(1330,689,237,50),commit_local,true); b.disabled=not valid
   btn("重选费用",Rect2(1330,761,237,43),func(): local.plan=[]; render())
 elif engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done:
  text="选择要调度的手牌"
  btn("保留" if selection.is_empty() else "调度 %d 张" % selection.size(),Rect2(1330,770,237,55),func(): engine.mulligan(acting_player(),selection); selection=[]; render(),true)
 elif engine.pending.get("owner",-1)==acting_player():
  match engine.pending.kind:
   "effect_choice":
    render_inline_picker(confirm_trigger,engine.pending.trigger.optional)
    if engine.pending.trigger.optional: optional_trigger_prompt()
   "trigger_order": pass
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
    var confirm=btn("不阻挡" if selection.is_empty() else "确认阻挡 %d 个" % selection.size(),Rect2(1330,770,237,55),func(): engine.block(selection); selection=[]; render(),true)
    confirm.disabled=selection.size()==1 and engine.Extra.keyword(engine,engine.find_card(engine.combat.attacker.uid),"威吓")
   "grave_replacement":
    text="改为移回战场？"
    btn("移回战场",Rect2(1330,741,237,49),func(): engine.choose_grave_replacement(true); render(),true)
    btn("移回手牌",Rect2(1330,804,237,43),func(): engine.choose_grave_replacement(false); render())
   "trigger":
    render_inline_picker(confirm_trigger,true)
    optional_trigger_prompt()
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
  if attack_preview_uid!=0:
   btn("攻击",Rect2(1330,770,237,55),confirm_attack,true)
  elif free_main():
   text=("你" if acting_player()==0 else "人机")+"的行动"
   btn("结束主要阶段",Rect2(1330,770,237,55),func(): engine.pass_priority(acting_player()); message=""; render(),true)
  elif should_ask_response():
   text="响应窗口"
   btn("不响应 / 继续",Rect2(1330,770,237,55),func(): engine.pass_priority(acting_player()); message=""; render(),true)
 txt(text,Rect2(310,605,1000,37),21,host.GOLD)

func begin_hand_drag(uid: int,at: Vector2):
 if debug_open or observing or modal or table.combat_animating or not local.is_empty() or response_disabled(): return
 if engine.find_card(uid).owner!=acting_player(): return
 clear_attack_preview()
 drag_uid=uid; drag_origin=at; drag_pointer=at; dragging=false
func _input(event: InputEvent):
 if is_instance_valid(table) and table.combat_animating:
  get_viewport().set_input_as_handled(); return
 if history_open:
  if event is InputEventMouseButton and event.pressed:
   var at=make_input_local(event).position
   if not history_panel.get_global_rect().has_point(at):
    if event.button_index==MOUSE_BUTTON_RIGHT: close_history()
    get_viewport().set_input_as_handled()
  return
 if debug_open and debug_drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if not browser_panel.get_global_rect().has_point(make_input_local(event).position):
   if not local.is_empty(): cancel_cast()
   close_debug(); get_viewport().set_input_as_handled(); return

 if debug_drag_uid!=0:
  handle_debug_drag(event)
  return
 if debug_open and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  close_debug(); get_viewport().set_input_as_handled(); return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and modal:
  var at=make_input_local(event).position
  for uid in region_tiles:
   var art=region_tiles[uid]
   if is_instance_valid(art) and art.is_visible_in_tree() and art.get_global_rect().has_point(at):
    var card=engine.find_card(uid)
    if not card.is_empty(): inspect_card(card.card_id,uid)
    get_viewport().set_input_as_handled(); return
 if attack_preview_uid!=0 and not observing and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  clear_attack_preview(); render()
 if observing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var point=make_input_local(event).position
  var on_debug_toggle=is_instance_valid(debug_button) and debug_button.get_global_rect().has_point(point)
  if not on_debug_toggle and not observe_button.get_global_rect().has_point(point) and not STAGE.has_point(point) and not inspection.get_global_rect().has_point(point):
   get_viewport().set_input_as_handled(); return
 if not observing and drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if not local.is_empty(): cancel_cast()
  elif picker_active() and not picker.path.is_empty(): picker.path=[]; picker.normalize(); render()
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
 if history_open or observing or response_disabled(): return
 message=""
 if picker_active():
  var c=engine.find_card(uid)
  if not c.is_empty(): choose_target(engine.ref_target(c))
  return
 if engine.phase=="mulligan" or engine.pending.get("kind","")=="discard": toggle_selection(uid); return
 if engine.pending.get("kind","")=="possession" and engine.pending.owner==acting_player():
  if selected_in_zone("palette")!=0 and engine.can_possess(engine.find_card(uid)): select_possession(uid,"hand")
  return
 var card=engine.find_card(uid)
 if card.is_empty(): return
 if engine.cast_error(acting_player(),uid).is_empty():
  close_debug(); request_cast(uid)
 elif card.zone!="hand" and engine.extension_activation_error(acting_player(),card).is_empty():
  close_debug(); execute_action(engine.extra_action(card))
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
 if attack_preview_uid!=0: clear_attack_preview(); render()
 elif not local.is_empty(): cancel_cast()
 elif picker_active(): picker.path=[]; picker.normalize(); render()
 elif engine.pending.get("kind","")=="possession": selection=[]; render()
 elif is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
func object_clicked(uid: int):
 if history_open or observing or table.combat_animating: return
 message=""
 if not local.is_empty():
  if local.mode=="payment": reserve_resource(uid)
  elif local.mode=="target":
   var target=engine.find_card(uid)
   if not target.is_empty(): choose_target(engine.ref_target(target))
  return
 var c=engine.find_card(uid)
 if engine.pending.get("owner",-1)==acting_player():
  match engine.pending.kind:
   "trigger", "effect_choice":
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
  clear_attack_preview(); attack_preview_uid=c.uid; selection=[c.uid]; render(); return
 clear_attack_preview()
 if actions.is_empty(): inspect_card(c.card_id,c.uid); return
 var panel=overlay("选择行动")
 action_menu_open=true
 panel.size=Vector2(728,470); center_panel(panel)
 panel.set_meta("action_card_uid",c.uid)
 var content=choice_card_content(panel,actions.size(),Vector2(688,375))
 for i in range(actions.size()):
  var action=actions[i]
  var at=choice_card_position(i,actions.size())
  var tile=host.card(content,c.card_id,Rect2(at,Vector2(173,241)),func(): execute_action(action))
  if not action.enabled: tile.modulate=Color(0.55,0.55,0.55)
  var label=txt(action.label,Rect2(at+Vector2(-4,251),Vector2(185,74)),18,host.GOLD if action.enabled else host.MUTED,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.size=Vector2(185,74)
func choice_card_content(panel: Control,count: int,dimensions: Vector2) -> Control:
 var scroll=ScrollContainer.new(); scroll.position=Vector2(20,75); scroll.size=dimensions
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
 var content=Control.new(); content.custom_minimum_size=Vector2(dimensions.x-16,ceili(count/3.0)*335)
 scroll.add_child(content); return content
func choice_card_position(index: int,count: int,card_width: float=173.0) -> Vector2:
 var row=index/3
 var row_count=mini(3,count-row*3)
 var row_width=(row_count-1)*222+card_width
 return Vector2((688-row_width)*0.5+(index%3)*222,row*335)
func trigger_order_menu():
 var panel=overlay("选择入堆叠顺序")
 panel.size=Vector2(728,495); center_panel(panel)
 panel.set_meta("trigger_order",true)
 var options=engine.pending.options
 var content=choice_card_content(panel,options.size(),Vector2(688,395))
 for i in range(options.size()):
  var t=options[i]; var at=choice_card_position(i,options.size())
  var tile=host.card(content,t.source.card_id,Rect2(at,Vector2(173,241)),func():
   if observing or engine.pending.get("kind","")!="trigger_order": return
   engine.choose_trigger_order(i); picker.reset(); render())
  tile.set_meta("trigger_index",i)
  var label=txt(AbilityCaption.text(t),Rect2(at+Vector2(-4,251),Vector2(194,78)),17,host.WHITE,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.size=Vector2(194,78)
func optional_trigger_prompt():
 var inline_rows=picker.available().any(func(atom):
  if atom.kind!="target": return true
  if not atom.value.has("uid"): return false
  var c=engine.find_card(atom.value.uid)
  return not c.is_empty() and c.zone not in ["field","palette","leader","stack","hand"])
 var label=txt("是否发动%s的触发效果" % engine.cards[engine.pending.trigger.source.card_id].name,Rect2(1330,586 if inline_rows else 702,237,78),17,host.GOLD)
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size=Vector2(237,78)
 label.set_meta("optional_trigger_prompt",true)
func execute_action(action: Dictionary):
 if response_disabled() or not action.enabled: return
 close_overlay()
 clear_attack_preview()
 if action.type=="attack": selection=[]; engine.attack(acting_player(),action.uid); render()
 elif action.type=="extension":
  local={"uid":action.uid,"action":"extension","key":action.key,"mode":"target","target":{},"plan":[]}
  picker.reset(); render()
 else:
  local={"uid":action.uid,"action":"ability","index":action.index,"mode":"target","target":{},"plan":[]}
  picker.reset(); render()
func toggle_selection(uid: int):
 if uid in selection: selection.erase(uid)
 else: selection.append(uid)
 render()

func clear_attack_preview():
 if attack_preview_uid!=0: selection.erase(attack_preview_uid)
 attack_preview_uid=0
func confirm_attack():
 var uid=attack_preview_uid
 if uid==0 or observing: return
 clear_attack_preview()
 if engine.can_attack(acting_player(),uid): engine.attack(acting_player(),uid)
 message=""
 render()

func local_prompt() -> String:
 if local.mode=="target": return engine.cards[engine.find_card(local.uid).card_id].name
 if local.mode=="payment_offer": return "自动选择费用？"
 if local.mode=="payment_color": return "选择颜色"
 var cost=local_cost(); var result=engine.ColorCost.remaining(cost,local.get("plan",[])); var pieces=[]
 for group in cost:
  var paid=int(cost[group])-int(result.remaining.get(group,cost[group]))
  pieces.append("%s %d / %d" % [group,paid,cost[group]])
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
  return r.colors.any(func(color): return engine.ColorCost.allows(cost,local.plan,color)))
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
 clear_attack_preview()
 var error=engine.cast_error(acting_player(),uid)
 if not error.is_empty(): message=error; render(); return
 local={"uid":uid,"target":{},"plan":[],"mode":"target"}
 picker.reset(); region_selected={}; selection=[]; message=""; render()

func choose_target(target: Dictionary):
 if observing or table.combat_animating or not picker_active(): return
 sync_picker()
 if picker.select_target(target):
  if not local.is_empty(): local.target=picker.option()
  message=""; render()

func start_payment():
 if local.is_empty(): return
 var c=engine.find_card(local.uid)
 var excluded=[local.uid] if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false) else []
 var solution=engine.payment(acting_player(),local_cost(),excluded)
 if solution.ways==0: message="可用颜色费用不足"; render(); return
 local.mode="payment"
 if local_cost().values().all(func(n): return n==0) or (auto_pay and (solution.ways==1 or (local.get("action","")=="" and engine.cards[c.card_id].kind!="符卡"))):
  local.plan=solution.plan; commit_local(); return
 if auto_pay: local.mode="payment_offer"
 render()

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
  if engine.ColorCost.allows(cost,local.plan,color): colors.append(color)
 if colors.is_empty(): message="不需要这张牌的颜色"; render(); return
 if colors.size()==1: local.plan.append({"uid":uid,"color":colors[0]}); render(); return
 local.mode="payment_color"; local.resource=uid; local.colors=colors; render()

func commit_local():
 if local.is_empty() or local.mode!="payment" or response_disabled(): return
 var error=engine.commit_extension(acting_player(),local.uid,local.target,local.plan) if local.get("action","")=="extension" else engine.commit_ability(acting_player(),local.uid,local.index,local.target,local.plan) if local.get("action","")=="ability" else engine.commit_cast(acting_player(),local.uid,local.target,local.plan)
 if error.is_empty(): local={}; selection=[]; picker.reset(); message=""; close_debug()
 else: message=error
 modal=false; render()
func cancel_cast():
 local={}; selection=[]; region_selected={}; picker.reset(); modal=false; message=""; render()
func overlay(title: String) -> Panel:
 close_overlay()
 modal=true
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.65); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(shade)
 modal_root=shade
 var panel=host.box(shade,Rect2(475,285,650,330),Color("#101c28"),host.GOLD)
 var heading=txt(title,Rect2(30,18,590,42),27,host.GOLD,panel)
 heading.name="DialogTitle"; heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 refresh_observation()
 return panel
func settings_menu():
 var panel=overlay("对战设置")
 panel.position=Vector2(475,285)
 var cb=CheckButton.new(); cb.text="自动支付"; cb.position=Vector2(30,86); cb.size=Vector2(280,46); cb.button_pressed=auto_pay; panel.add_child(cb)
 cb.toggled.connect(func(value): auto_pay=value)
 btn("继续游戏",Rect2(30,180,260,48),func(): modal=false; render(),true,panel)
 btn("投降",Rect2(330,180,260,48),func():
  var confirm=overlay("确认投降")
  confirm.position=Vector2(475,285)
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
 var width=728.0
 panel.size=Vector2(width,650); center_panel(panel)
 panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 var content=choice_card_content(panel,count,Vector2(688,426))
 damage_controls={}
 for i in range(count):
  var c=engine.find_card(targets[i].uid); var key=str(c.uid)
  var at=choice_card_position(i,count,150)
  var art=TextureRect.new(); art.position=at; art.size=Vector2(150,210)
  art.texture=host.texture(c.card_id); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.set_meta("damage_card",c.uid); content.add_child(art)
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: inspect_card(c.card_id,c.uid))
  var value=txt("0",Rect2(at.x+48,at.y+220,54,40),27,host.WHITE,content); value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  var minus=btn("−",Rect2(at.x,at.y+222,40,37),func(): change_damage(key,-1),false,content)
  var plus=btn("+",Rect2(at.x+110,at.y+222,40,37),func(): change_damage(key,1),false,content)
  damage_controls[key]={"value":value,"minus":minus,"plus":plus}
 damage_remainder=txt("",Rect2(24,512,width-48,47),19,host.WHITE,panel)
 damage_remainder.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 btn("确定分配",Rect2(width-247,582,210,49),confirm_damage,true,panel)
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
 for target in picker.selected_refs():
  if target.has("uid") and target.uid not in selected: selected.append(target.uid)
 if not local.is_empty():
  if local.uid not in selected: selected.append(local.uid)
  var target=local.get("target",{})
  if target.has("uid") and target.uid not in selected: selected.append(target.uid)
 return selected
func stat_color(value: int,base: int) -> Color:
 return Color("#69e59a") if value>base else Color("#ff737b") if value<base else host.WHITE
func combat_marker(uid: int) -> String:
 if attack_preview_uid==uid: return "sword"
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
 return engine!=null and engine.winner==-2 and not table.combat_animating and (attack_preview_uid!=0 or debug_open or modal or not local.is_empty() or engine.pending.get("owner",-1)==acting_player() or (engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done))
func refresh_observation():
 if not is_instance_valid(observe_button): return
 if is_instance_valid(debug_button):
  debug_button.set_pressed_no_signal(debug_open)
  debug_button.tooltip_text="收起调试，返回对局" if debug_open else "查看或移动区域卡牌"
 observe_button.visible=choice_active() or observing
 observe_button.text="返回选择" if observing else "观察战场"
 ui.move_child(inspection,-1)
 ui.move_child(observe_button,-1)
 if is_instance_valid(debug_controls): ui.move_child(debug_controls,-1)
 if history_open and is_instance_valid(history_root): ui.move_child(history_root,-1)
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
 panel.size=Vector2(728,590); center_panel(panel)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(25,77); scroll.size=Vector2(678,424); panel.add_child(scroll)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
 for option in options:
  var row=Button.new(); row.text=target_caption(option); row.custom_minimum_size=Vector2(650,54); row.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  row.add_theme_font_size_override("font_size",18); column.add_child(row)
  row.pressed.connect(func(): close_overlay(); callback.call(option))
  row.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and option.has("uid"):
    var c=engine.find_card(option.uid)
    if not c.is_empty(): inspect_card(c.card_id,c.uid))
 btn("返回",Rect2(480,520,220,46),func(): close_overlay(),false,panel)
func open_local_choices():
 # Compatibility entry point: choices are rendered in the battlefield HUD.
 render()

func open_effect_choices():
 render()

func open_deck_casts():
 # The region tab remains part of the hand area, so browsing never traps priority.
 hand_zones[acting_player()]="deck"
 render()
func close_debug():
 if debug_drag_uid!=0: finish_debug_drag(true)
 if is_instance_valid(debug_root):
  debug_root.get_parent().remove_child(debug_root); debug_root.queue_free()
 debug_root=null; browser_panel=null; browser_scroll=null; browser_cards=null; debug_open=false
 if observing:
  observing=false
  if is_instance_valid(modal_root): modal_root.visible=true
  for widget in hud.get_children():
   if widget.has_meta("choice_widget"): widget.visible=true
 refresh_observation()
func zone_cards(who: int,zone: String) -> Array:
 if zone=="leader":
  var c=engine.players[who].leader
  return [c] if c.zone=="leader" else []
 if zone=="stack": return engine.stack.filter(func(e): return e.kind=="card" and e.owner==who).map(func(e): return e.card)
 var result=engine.players[who][zone].duplicate()
 # Deck front is the next draw; graveyard/exile back is the visible top card.
 if zone in ["grave","exile"]: result.reverse()
 return result
func browse_zone(who: int,zone: String,scroll_position: int=0):
 if history_open or table.combat_animating: return
 close_debug(); debug_open=true; browser_owner=who; browser_zone=zone
 debug_root=layer(ui)
 browser_panel=host.box(debug_root,SIDEBAR,Color("#101c28"),Color("#637a93")); browser_panel.name="PileBrowser"
 var cards=zone_cards(who,zone)
 txt(("你" if who==0 else "人机")+" · "+ZONE_NAMES[zone]+" · %d" % cards.size(),Rect2(12,10,212,35),20,host.GOLD,browser_panel)
 var close=btn("×",Rect2(242,10,40,32),close_debug,false,browser_panel)
 close.name="ClosePileBrowser"; close.tooltip_text="返回对局"
 var top=53
 if debug_mode:
  var owner_picker=OptionButton.new(); owner_picker.position=Vector2(10,49); owner_picker.size=Vector2(104,34); browser_panel.add_child(owner_picker)
  owner_picker.add_item("你"); owner_picker.add_item("人机"); owner_picker.selected=who
  owner_picker.item_selected.connect(func(index): browse_zone(index,browser_zone))
  var zone_picker=OptionButton.new(); zone_picker.position=Vector2(122,49); zone_picker.size=Vector2(160,34); browser_panel.add_child(zone_picker)
  var zones=ZONE_NAMES.keys()
  for key in zones: zone_picker.add_item(ZONE_NAMES[key])
  zone_picker.selected=zones.find(zone)
  zone_picker.item_selected.connect(func(index): browse_zone(browser_owner,zones[index]))
  top=92
 browser_scroll=ScrollContainer.new(); browser_scroll.position=Vector2(8,top); browser_scroll.size=Vector2(278,SIDEBAR.size.y-top-8)
 browser_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; browser_panel.add_child(browser_scroll)
 browser_cards=GridContainer.new(); browser_cards.columns=3; browser_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 browser_cards.add_theme_constant_override("h_separation",5); browser_cards.add_theme_constant_override("v_separation",7); browser_scroll.add_child(browser_cards)
 var hidden=zone=="deck" and not debug_mode or zone=="hand" and who!=0 and not debug_mode
 for c in cards:
  var tile=Control.new(); tile.custom_minimum_size=Vector2(83,117); browser_cards.add_child(tile)
  tile.set_meta("display_id","back" if hidden else c.card_id)
  var art=host.card(tile,"back" if hidden else c.card_id,Rect2(0,0,83,116)); art.name="PileCard"
  art.set_meta("browser_uid",c.uid); art.set_meta("hidden",hidden)
  art.tooltip_text="未公开" if hidden else engine.cards[c.card_id].name
  art.gui_input.connect(func(event):
   if not event is InputEventMouseButton or not event.pressed: return
   if event.button_index==MOUSE_BUTTON_RIGHT: inspect_card("back",0,"未公开") if hidden else inspect_card(c.card_id,c.uid)
   elif event.button_index==MOUSE_BUTTON_LEFT:
    if debug_mode and can_begin_debug_drag(): begin_debug_drag(c.uid,art.get_global_transform()*event.position)
    elif not hidden: browse_card_action(c))
 if cards.is_empty(): txt("空",Rect2(110,top+35,60,35),22,host.MUTED,browser_panel)
 browser_scroll.set_deferred("scroll_vertical",scroll_position)
 update_browser_styles(); refresh_observation()

func update_browser_styles():
 if not is_instance_valid(browser_cards): return
 for row in browser_cards.get_children():
  var art=row.get_node_or_null("PileCard")
  if art==null or art.get_meta("hidden",true): continue
  var c=engine.find_card(art.get_meta("browser_uid",0))
  if c.is_empty(): continue
  var selected=c.uid in selected_uids()
  var legal=c.owner==acting_player() and not response_disabled() and (engine.cast_error(c.owner,c.uid).is_empty() or not engine.extra_action(c).is_empty() and engine.extension_activation_error(c.owner,c).is_empty())
  var style=host.style(Color("#172936"),Color("#ffd65c") if selected else Color("#359bff") if legal else Color("#304657"))
  style.set_border_width_all(4 if selected or legal else 1); art.add_theme_stylebox_override("panel",style)
func browse_card_action(c: Dictionary):
 inspect_card(c.card_id,c.uid)
 if picker_active(): choose_target(engine.ref_target(c)); return
 if c.owner!=acting_player() or response_disabled(): return
 if not local.is_empty(): return
 if engine.cast_error(c.owner,c.uid).is_empty(): request_cast(c.uid); return
 var action=engine.extra_action(c)
 if not action.is_empty() and engine.extension_activation_error(c.owner,c).is_empty(): execute_action(action)

func debug_menu():
 if not debug_mode or history_open or table.combat_animating: return
 if debug_open: close_debug()
 else: browse_zone(acting_player(),"deck")
func begin_debug_drag(uid: int,at: Vector2):
 if not debug_mode or observing: return
 var c=engine.find_card(uid)
 if c.is_empty(): return
 inspect_card(c.card_id,uid)
 if not local.is_empty() or not engine.pending.is_empty() or modal or table.combat_animating:
  message="请先完成或取消当前选择"; return
 if attack_preview_uid!=0: clear_attack_preview(); render()
 debug_drag_browser=is_instance_valid(browser_panel) and browser_panel.get_global_rect().has_point(at)
 debug_drag_uid=uid; debug_drag_epoch=c.epoch; debug_drag_origin=at; debug_drag_pointer=at; debug_dragging=false
func debug_destination(at: Vector2,owner: int) -> String:
 if is_instance_valid(browser_panel) and browser_panel.visible and browser_panel.get_global_rect().has_point(at): return ""
 var board_zone=table.debug_drop_zone((at-STAGE.position)/STAGE.size*Vector2(viewport.size),owner) if STAGE.has_point(at) else ""
 if board_zone in ["deck","grave","exile","leader"]: return board_zone
 if hand_area(owner).has_point(at): return "hand"
 return board_zone
func handle_debug_drag(event: InputEvent):
 if event is InputEventMouseMotion:
  debug_drag_pointer=make_input_local(event).position
  if not debug_dragging and debug_drag_pointer.distance_to(debug_drag_origin)>10:
   debug_dragging=true
   if is_instance_valid(browser_panel): browser_panel.hide()
   debug_drag_art=host.card(ui,engine.find_card(debug_drag_uid).card_id,Rect2(debug_drag_pointer-Vector2(70,97),Vector2(140,195)))
   debug_drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; debug_drag_art.modulate.a=0.82
   debug_drop_hint=txt("",Rect2(0,0,170,38),22,host.GOLD,debug_drag_art)
   debug_drop_hint.position=Vector2(-15,-43); debug_drop_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   debug_drop_hint.add_theme_constant_override("outline_size",6); debug_drop_hint.add_theme_color_override("font_outline_color",Color("#101c28"))
  if debug_dragging:
   debug_drag_art.position=debug_drag_pointer-Vector2(70,97)
   var c=engine.find_card(debug_drag_uid)
   var destination=debug_destination(debug_drag_pointer,c.owner) if not c.is_empty() else ""
   debug_drop_hint.text="放入"+ZONE_NAMES[destination]+("顶" if destination=="deck" else "") if not destination.is_empty() else "取消移动"
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton:
  debug_drag_pointer=make_input_local(event).position
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   finish_debug_drag(true); get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   finish_debug_drag(false); get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  finish_debug_drag(true); get_viewport().set_input_as_handled()
func finish_debug_drag(cancelled: bool):
 var uid=debug_drag_uid; var moved=debug_dragging; var at=debug_drag_pointer
 debug_drag_uid=0; debug_dragging=false
 if is_instance_valid(debug_drag_art): debug_drag_art.queue_free()
 debug_drag_art=null
 var c=engine.find_card(uid)
 var destination=debug_destination(at,c.owner) if not c.is_empty() and moved and not cancelled else ""
 if is_instance_valid(browser_panel): browser_panel.visible=not observing
 if cancelled or c.is_empty() or c.epoch!=debug_drag_epoch: return
 if not moved:
  if c.zone in ["field","leader"]: object_clicked(c.uid)
  elif c.zone=="hand": hand_clicked(c.uid)
  else: browse_card_action(c)
  return
 if destination.is_empty(): return
 var error=engine.debug_move(uid,destination)
 message=error
 var scroll_position=browser_scroll.scroll_vertical if is_instance_valid(browser_scroll) else 0
 if error.is_empty(): selection=[]
 render()
 if debug_drag_browser: browse_zone(browser_owner,browser_zone,scroll_position)

func picker_active() -> bool:
 if not local.is_empty(): return local.mode=="target"
 return engine.pending.get("owner",-1)==acting_player() and engine.pending.get("kind","") in ["trigger","effect_choice"]
func sync_picker():
 if not local.is_empty():
  if local.mode!="target": return
  var options=local_targets()
  if local.get("action","")=="" and engine.cards[engine.find_card(local.uid).card_id].kind!="符卡": options=[{"none":true}]
  picker.configure(options,"local:"+str(local.uid)+":"+local.get("action","")+":"+str(local.get("index",-1))+":"+str(engine.revision))
 elif picker_active():
  var options=engine.pending.options if engine.pending.kind=="effect_choice" else (engine.units(0)+engine.units(1)).map(func(c): return engine.ref_target(c))
  picker.configure(options,"trigger:"+str(engine.revision)+JSON.stringify(engine.pending),engine.pending.trigger.get("effect","")=="death_poverty")
 else: picker.reset()
func confirm_declaration():
 if observing or local.is_empty() or local.mode!="target" or response_disabled(): return
 sync_picker()
 if not picker.ready(): return
 local.target=picker.option()
 start_payment()
func confirm_trigger():
 if observing or not local.is_empty() or not picker_active(): return
 sync_picker()
 if not picker.ready(): return
 var target=picker.option()
 if engine.pending.kind=="effect_choice": engine.choose_effect(target)
 else: engine.choose_trigger(target)
 picker.reset(); selection=[]; render()
func decline_trigger():
 if observing or not picker_active() or not local.is_empty(): return
 if engine.pending.kind=="trigger": engine.choose_trigger({})
 elif engine.pending.trigger.optional: engine.choose_effect({})
 picker.reset(); selection=[]; render()
func pay_automatically():
 if observing or local.is_empty() or local.mode!="payment_offer" or response_disabled(): return
 local.mode="payment"
 var excluded=[local.uid] if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false) else []
 local.plan=engine.payment(acting_player(),local_cost(),excluded).plan
 commit_local()
func inline_pick(atom: Dictionary):
 if observing or not picker_active(): return
 if picker.select(atom):
  if not local.is_empty(): local.target=picker.option()
  render()
func render_inline_picker(confirm: Callable,optional: bool=false):
 var options=[]
 for atom in picker.available():
  if atom.kind!="target": options.append(atom); continue
  if atom.value.has("uid"):
   var c=engine.find_card(atom.value.uid)
   if not c.is_empty() and c.zone not in ["field","palette","leader","stack","hand"]: continue
 if not options.is_empty():
  var scroll=ScrollContainer.new(); scroll.position=Vector2(1330,664); scroll.size=Vector2(237,123)
  scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.set_meta("choice_widget",true); hud.add_child(scroll)
  var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
  for atom in options:
   var row=Button.new(); row.custom_minimum_size=Vector2(215,45); column.add_child(row)
   row.text=target_caption(atom.value) if atom.kind=="target" else str(atom.value)
   row.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; row.add_theme_font_size_override("font_size",17)
   row.pressed.connect(func(): inline_pick(atom))
   row.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and atom.kind=="target" and atom.value.has("uid"):
     var c=engine.find_card(atom.value.uid)
     if not c.is_empty(): inspect_card(c.card_id,c.uid))
 if picker.available().any(func(atom): return atom.get("role","")=="sacrifice"):
  txt("选择牺牲的单位",Rect2(1330,620,237,32),18,host.GOLD)
 var button=btn("确定",Rect2(1330,799,237,49),confirm,true)
 button.disabled=not picker.ready()
 if optional: btn("不使用",Rect2(1330,853,115,36),decline_trigger)
 if not picker.path.is_empty(): btn("重选",Rect2(1452,853,115,36),func(): picker.path=[]; picker.normalize(); render())
func render_life(who: int,rect: Rect2):
 var selected=picker.selected_refs().any(func(t): return t.get("player",-1)==who)
 var legal=picker_active() and picker.available_refs().any(func(t): return t.get("player",-1)==who)
 var color=Color("#ffd65c") if selected else Color("#359bff") if legal else Color("#486376")
 var button=btn(("你" if who==0 else "人机")+"  %d" % engine.players[who].life,rect,func(): choose_target({"player":who}))
 var panel=host.style(Color("#192a38"),color); panel.set_border_width_all(4 if selected or legal else 1)
 for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,panel)
 var bar=ProgressBar.new(); bar.position=Vector2(10,rect.size.y-15)
 bar.min_value=0; bar.max_value=20; bar.value=clampf(engine.players[who].life,0,20); bar.show_percentage=false
 bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var background=StyleBoxFlat.new(); background.bg_color=Color("#09121d"); background.set_corner_radius_all(3)
 var fill=StyleBoxFlat.new(); fill.bg_color=Color("#a94752") if who==1 else Color("#43b59a"); fill.set_corner_radius_all(3)
 bar.add_theme_stylebox_override("background",background); bar.add_theme_stylebox_override("fill",fill); button.add_child(bar)
 bar.add_theme_font_size_override("font_size",1); bar.size=Vector2(rect.size.x-20,7)
 life_widgets[who]={"button":button,"bar":bar,"legal":legal,"selected":selected}
func target_rect(target: Dictionary) -> Rect2:
 if target.has("player") and life_widgets.has(int(target.player)): return life_widgets[int(target.player)].button.get_global_rect()
 if target.has("stack_id"):
  for key in table.descriptors:
   if table.descriptors[key].get("stack_id",-1)==target.stack_id: return projected_card_rect(table.visuals[key])
 if target.has("uid"):
  var c=engine.find_card(target.uid)
  if c.is_empty() or c.epoch!=target.get("epoch",-1): return Rect2()
  var key="card_"+str(c.uid)
  if table.visuals.has(key): return projected_card_rect(table.visuals[key])
  var nodes=hand_nodes if c.owner==0 else enemy_nodes
  if c.zone=="hand" and nodes.has(c.uid): return nodes[c.uid].get_global_rect()
  if c.zone in ["deck","grave","exile"]:
   return Rect2(project(table.zone_position(c.zone,c.owner))-Vector2(25,30),Vector2(50,60))
 return Rect2()
func arrow_targets(target: Dictionary) -> Array:
 if target.has("parts"):
  var result=[]
  for part in target.parts: result.append_array(arrow_targets(part))
  return result
 var actual={}
 for field in ["uid","epoch","zone","player","stack_id"]:
  if target.has(field): actual[field]=target[field]
 return [actual] if not actual.is_empty() else []
func rect_edge(rect: Rect2,toward: Vector2) -> Vector2:
 var direction=(toward-rect.get_center()).normalized()
 var distance=minf(rect.size.x*0.5/maxf(0.001,absf(direction.x)),rect.size.y*0.5/maxf(0.001,absf(direction.y)))
 return rect.get_center()+direction*(distance+5)
func stack_target_arrows() -> Array:
 var result=[]
 if not is_instance_valid(table): return result
 for entry in engine.stack:
  var key="card_"+str(entry.card.uid) if entry.kind=="card" else "ability_"+str(entry.id)
  if not table.visuals.has(key): continue
  var origin=projected_card_rect(table.visuals[key])
  var seen=[]
  for target in arrow_targets(entry.target):
   if target in seen: continue
   seen.append(target)
   var destination=target_rect(target)
   if destination.size==Vector2.ZERO: continue
   var from=rect_edge(origin,destination.get_center())
   var to=rect_edge(destination,origin.get_center())
   # Overlapping stack cards expose their left edge; a center-to-center line
   # would otherwise cross the target's far edge and appear to point backwards.
   if target.has("stack_id") and origin.intersects(destination):
    from=Vector2(origin.position.x,origin.get_center().y-25)
    to=Vector2(destination.position.x+7,destination.get_center().y)
   result.append({"entry":entry.id,"target":target,"from":from,"to":to})
 return result

func open_history():
 if history_open: return
 history_open=true; history_root=layer(ui)
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.38); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); history_root.add_child(shade)
 history_panel=host.box(history_root,Rect2(1100,75,480,807),Color("#0f1b29"),Color("#637a93"))
 txt("对局流程记录",Rect2(20,15,435,40),26,host.GOLD,history_panel)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(14,66); scroll.size=Vector2(453,724); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; history_panel.add_child(scroll)
 var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
 var events=engine.history.duplicate(); events.reverse()
 for entry in events:
  var row=PanelContainer.new(); row.custom_minimum_size=Vector2(432,96 if entry.art.is_empty() else 136); column.add_child(row)
  row.add_theme_stylebox_override("panel",host.style(Color("#162636"),Color("#2d455a")))
  var content=Control.new(); row.add_child(content)
  txt("第%d回合 · %s" % [entry.turn,phase_names.get(entry.phase,entry.phase)],Rect2(0,0,400,23),14,host.MUTED,content)
  var left=0
  if not entry.art.is_empty():
   var art=entry.art[0]; var hidden=art.get("hidden",false) and art.owner!=0 and not debug_mode
   var card=host.card(content,"back" if hidden else art.card_id,Rect2(0,28,62,87))
   card.set_meta("history_display_id","back" if hidden else art.card_id); left=74
   card.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and not hidden: inspect_card(art.card_id))
  var label=txt(entry.text,Rect2(left,29,398-left,74),17,host.WHITE,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size=Vector2(398-left,74)
 refresh_observation()
func close_history():
 if is_instance_valid(history_root): history_root.queue_free()
 history_root=null; history_open=false; clock_time=0
func region_atoms() -> Array:
 if not picker_active(): return []
 return picker.available().filter(func(atom):
  if atom.kind!="target" or not atom.value.has("uid"): return false
  var c=engine.find_card(atom.value.uid)
  return not c.is_empty() and c.zone in ["deck","grave","exile"])
func region_picker_needed() -> bool:
 return picker_active() and not picker.ready() and not region_atoms().is_empty()
func region_picker():
 var atoms=region_atoms()
 if atoms.is_empty(): return
 if region_selected not in atoms: region_selected={}
 var panel=overlay("选择卡牌")
 panel.size=Vector2(895,460); center_panel(panel); panel.set_meta("region_picker",true)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(20,72); scroll.size=Vector2(855,308)
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",12); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.alignment=BoxContainer.ALIGNMENT_CENTER; scroll.add_child(row); region_tiles={}
 for atom in atoms:
  var c=engine.find_card(atom.value.uid)
  var tile=Control.new(); tile.custom_minimum_size=Vector2(142,292); row.add_child(tile)
  var title=txt(("你 · " if c.owner==0 else "人机 · ")+ZONE_NAMES[c.zone],Rect2(0,0,142,28),16,host.GOLD,tile)
  title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  var art=host.card(tile,c.card_id,Rect2(0,33,142,198),func(): select_region_atom(atom))
  art.set_meta("region_uid",c.uid)
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: inspect_card(c.card_id,c.uid))
  var name=txt(engine.cards[c.card_id].name,Rect2(0,237,142,54),15,host.WHITE,tile)
  name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; name.size=Vector2(142,54)
  region_tiles[c.uid]=art
 var confirm=btn("确定",Rect2(624,392,243,48),confirm_region_atom,true,panel)
 confirm.name="RegionConfirm"; confirm.disabled=region_selected.is_empty()
 update_region_styles()
func select_region_atom(atom: Dictionary):
 if observing: return
 region_selected=atom if region_selected!=atom else {}
 update_region_styles()
func update_region_styles():
 for uid in region_tiles:
  var selected=region_selected.get("value",{}).get("uid",-1)==uid
  var style=host.style(Color("#172936"),Color("#ffd65c") if selected else Color("#359bff")); style.set_border_width_all(4)
  region_tiles[uid].add_theme_stylebox_override("panel",style)
 if is_instance_valid(modal_root):
  var confirm=modal_root.find_child("RegionConfirm",true,false)
  if confirm: confirm.disabled=region_selected.is_empty()
func confirm_region_atom():
 if observing or region_selected.is_empty(): return
 var atom=region_selected.duplicate(true); region_selected={}
 inline_pick(atom)

func center_panel(panel: Control):
 panel.position=(Vector2(1600,900)-panel.size)*0.5
 if panel.has_node("DialogTitle"): panel.get_node("DialogTitle").size.x=panel.size.x-60


func can_begin_debug_drag() -> bool:
 return debug_mode and not observing and not history_open and not modal and local.is_empty() and engine.pending.is_empty() and engine.phase!="mulligan" and not table.combat_animating


func can_use_region_card(c: Dictionary) -> bool:
 if c.owner!=acting_player() or response_disabled(): return false
 return engine.cast_error(c.owner,c.uid).is_empty() or not engine.extra_action(c).is_empty() and engine.extension_activation_error(c.owner,c).is_empty()


func region_action_cards(who: int,zone: String) -> Array:
 if who!=acting_player() or response_disabled(): return []
 return engine.players[who][zone].filter(func(c): return can_use_region_card(c))


func available_hand_zones(who: int) -> Array:
 var zones=["hand"]
 for zone in ["grave","exile","deck"]:
  if not region_action_cards(who,zone).is_empty(): zones.append(zone)
 return zones


func displayed_hand_cards(who: int) -> Array:
 var zones=available_hand_zones(who)
 if hand_zones[who] not in zones: hand_zones[who]="hand"
 return engine.players[who].hand if hand_zones[who]=="hand" else region_action_cards(who,hand_zones[who])


func render_hand_zone_tabs():
 hand_zone_tabs={}
 for who in [0,1]:
  if who==1 and not debug_mode: continue
  var zones=available_hand_zones(who)
  if hand_zones[who] not in zones: hand_zones[who]="hand"
  if zones.size()<2: continue
  for i in range(zones.size()):
   var zone=zones[i]
   var at=Vector2(HAND.position.x+i*119,HAND.position.y-32) if who==0 else Vector2(560+i*119,52)
   var title=ZONE_NAMES[zone]
   var button=btn(title,Rect2(at,Vector2(112,29)),func(): hand_zones[who]=zone; render(),hand_zones[who]==zone)
   button.set_meta("hand_zone",zone); button.set_meta("hand_zone_owner",who)
   hand_zone_tabs[str(who)+":"+zone]=button

