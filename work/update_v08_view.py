from pathlib import Path
p=Path('scripts/duel_view.gd');s=p.read_text(encoding='utf-8')
s=s.replace('var frame_count=0','''var frame_count=0
var observing=false
var observe_button: Button
var building_prompt=false
var effects: Control
var damage_values={}
var damage_controls={}
var damage_signature=""
var damage_remainder: Label''')
s=s.replace(' table.object_selected.connect(object_clicked)',' table.object_selected.connect(object_clicked)\n table.combat_animation_finished.connect(render)\n table.combat_impact.connect(show_combat_impact)')
s=s.replace(' banner=layer(ui)',''' effects=layer(ui)
 banner=layer(ui)
 observe_button=btn("观察战场",Rect2(1280,12,162,40),toggle_observation,false,ui)
 observe_button.visible=false''')
s=s.replace(' if modal or dragging: return',' if (modal and not observing) or dragging: return')
s=s.replace(' if modal or not local.is_empty() or drag_uid!=0 or engine.winner!=-2: return',' if observing or modal or not local.is_empty() or drag_uid!=0 or engine.winner!=-2: return')
s=s.replace(' return host.label(hud if parent==null else parent,text,rect,font,color)',''' var label=host.label(hud if parent==null else parent,text,rect,font,color)
 if building_prompt and parent==null: label.set_meta("choice_widget",true)
 return label''')
s=s.replace(' return host.button(hud if parent==null else parent,text,rect,action,accent)',''' var button=host.button(hud if parent==null else parent,text,rect,action,accent)
 if building_prompt and parent==null: button.set_meta("choice_widget",true)
 return button''')
s=s.replace(' var result=[]\n if not local.is_empty():',''' var result=[]
 if engine.phase=="mulligan" and not engine.players[0].mulligan_done:
  return engine.players[0].hand.map(func(c): return c.uid)
 if not local.is_empty():''',1)
s=s.replace('  if engine.pending.kind=="possession": return []','''  if engine.pending.kind=="discard": return engine.players[0].hand.map(func(c): return c.uid)
  if engine.pending.kind=="trigger": return (engine.units(0)+engine.units(1)).map(func(c): return c.uid)
  if engine.pending.kind=="possession":
   result=engine.players[0].palette.filter(func(c): return not c.tapped).map(func(c): return c.uid)
   if selected_in_zone("palette")!=0: result.append_array(engine.players[0].hand.map(func(c): return c.uid))
   return result''')
s=s.replace('table.sync(local.get("plan",[]),selection,available','table.sync(local.get("plan",[]),selected_uids(),available')
s=s.replace(' render_prompt()',' building_prompt=true\n render_prompt()\n building_prompt=false',1)
s=s.replace(' if engine.winner!=-2: result_overlay()',''' if engine.winner!=-2 and not table.combat_animating: result_overlay()
 elif engine.pending.get("kind","")=="damage_assignment" and engine.pending.owner==0 and not table.combat_animating: damage_dialog()
 refresh_observation()''')
s=s.replace('node.update_style(c.uid in available,c.uid in selection)','node.update_style(c.uid in available,c.uid in selected_uids())')
s=s.replace('  var c=engine.find_card(d.uid)\n  if c.is_empty(): continue','''  var c=table.old_cards.get(d.uid,{}) if table.combat_animating else engine.find_card(d.uid)
  if c.is_empty(): continue''',1)
start=s.index('   var panel=host.box(root,Rect2(0,0,99,25)');end=s.index('  elif d.zone=="leader"',start)
s=s[:start]+'''   var panel=host.box(root,Rect2(0,0,109,26),Color("#111d2b"),Color("#aaa080")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   var stat_names=["power","health","spirit"]
   var positions=[3,40,78]
   parts.values={}
   for index in range(3):
    var key_name=stat_names[index]
    var value=engine.stat(c,key_name)-(c.damage if key_name=="health" else 0)
    var base=int(engine.cards[c.card_id][key_name])
    var label=txt(str(value),Rect2(positions[index],0,28,26),16,stat_color(value,base),panel)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    parts.values[key_name]=label
   txt("/",Rect2(31,0,10,26),16,host.WHITE,panel)
   txt("·",Rect2(69,0,9,26),16,host.WHITE,panel)
   parts.stats=panel
   var marker=combat_marker(c.uid)
   if not marker.is_empty():
    var icon=TextureRect.new(); icon.size=Vector2(42,42)
    icon.texture=load("res://assets/combat_"+marker+".svg")
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    icon.set_meta("combat_role",marker); root.add_child(icon); parts.marker=icon
''' + s[end:]
s=s.replace('parts.stats.position=Vector2(-49.5,rect.size.y/2-25)','parts.stats.position=Vector2(-54.5,rect.size.y/2-25)')
s=s.replace('   if parts.has("sick"):','   if parts.has("marker"): parts.marker.position=Vector2(rect.size.x/2-32,-rect.size.y/2-10)\n   if parts.has("sick"):')
s=s.replace(' var c=engine.find_card(inspect_uid)\n if not c.is_empty() and engine.summoning_sick(c) and not engine.has_haste(c): text.text="召唤失调\\n\\n"+text.text\n','')
s=s.replace('func render_prompt():\n var text=""','func render_prompt():\n if table.combat_animating: return\n var text=""')
s=s.replace('    btn("分配伤害",Rect2(1330,770,237,55),damage_dialog,true)\n','')
s=s.replace(' if modal or not local.is_empty(): return',' if observing or modal or table.combat_animating or not local.is_empty(): return',1)
s=s.replace('func _input(event: InputEvent):','''func _input(event: InputEvent):
 if observing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var point=make_input_local(event).position
  if not observe_button.get_global_rect().has_point(point) and not STAGE.has_point(point) and not inspection.get_global_rect().has_point(point):
   get_viewport().set_input_as_handled(); return''')
s=s.replace(' if action_menu_open and event',' if action_menu_open and not observing and event',1)
s=s.replace('   dragging=true\n   drag_art','''   dragging=true
   if engine.pending.is_empty() and engine.phase!="mulligan":
    selection=[drag_uid]
    if hand_nodes.has(drag_uid): hand_nodes[drag_uid].update_style(true,true)
   drag_art''',1)
s=s.replace('   drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; drag_art.modulate.a=0.9','''   drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; drag_art.modulate.a=0.9
   var drag_style=host.style(Color("#27313d"),Color("#ffd65c")); drag_style.set_border_width_all(5)
   drag_art.add_theme_stylebox_override("panel",drag_style)''')
s=s.replace(' if cancelled: return\n if moved:\n  if not HAND.has_point(at): request_cast(uid)',''' if cancelled:
  selection=[]; render(); return
 if moved:
  if not HAND.has_point(at): request_cast(uid)
  else: selection=[]; render()''')
s=s.replace(' # A plain click does not cast a hand card.',''' # Select without casting. Casting remains a drag outside the hand zone.
 if engine.cast_error(0,uid).is_empty():
  selection=[] if uid in selection else [uid]
  render()''')
s=s.replace('func right_cancel():\n if not local','''func right_cancel():
 if observing:
  if is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
  return
 if not local''')
s=s.replace('func object_clicked(uid: int):\n message=""','func object_clicked(uid: int):\n if observing or table.combat_animating: return\n message=""')
s=s.replace(' var actions=engine.available_actions(0,c.uid,true)\n if actions.is_empty()', ''' var actions=engine.available_actions(0,c.uid)
 if actions.size()==1 and actions[0].type=="attack":
  execute_action(actions[0]); return
 if actions.is_empty()''')
s=s.replace('action.label+("\\n"+action.reason if not action.enabled else "")','action.label')
s=s.replace(' if action.type=="attack": engine.attack(0,action.uid); render()',' if action.type=="attack": selection=[]; engine.attack(0,action.uid); render()')
s=s.replace(' modal=false; action_menu_open=false',' modal=false; action_menu_open=false; observing=false\n for child in hud.get_children():\n  if child.has_meta("choice_widget"): child.visible=true',1)
s=s.replace(' modal_root=null\n',' modal_root=null\n refresh_observation()\n',1)
s=s.replace('func request_cast(uid: int):\n var error','func request_cast(uid: int):\n if observing or table.combat_animating: return\n var error')
s=s.replace('func choose_target(target: Dictionary):\n if engine','func choose_target(target: Dictionary):\n if observing or table.combat_animating: return\n if engine')
s=s.replace(' txt(title,Rect2(30,18,590,42),27,host.GOLD,panel)\n return panel',' txt(title,Rect2(30,18,590,42),27,host.GOLD,panel)\n refresh_observation()\n return panel')
start=s.index('func damage_dialog():')
s=s[:start]+'''func damage_dialog():
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
  var at=Vector2(24+i*178,73)
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
 return engine!=null and engine.winner==-2 and not table.combat_animating and (modal or not local.is_empty() or engine.pending.get("owner",-1)==0 or (engine.phase=="mulligan" and not engine.players[0].mulligan_done))
func refresh_observation():
 if not is_instance_valid(observe_button): return
 observe_button.visible=choice_active() or observing
 observe_button.text="返回选择" if observing else "观察战场"
 ui.move_child(observe_button,-1)
func toggle_observation():
 observing=not observing
 if is_instance_valid(modal_root): modal_root.visible=not observing
 for child in hud.get_children():
  if child.has_meta("choice_widget"): child.visible=not observing
 refresh_observation()
'''
p.write_text(s,encoding='utf-8')
print('Battle interaction, colored stats, observation and card-based damage allocation written')
