from pathlib import Path
root=Path(__file__).resolve().parent.parent
p=root/'scripts/duel_view.gd';s=p.read_text('utf-8')
s=s.replace('var host','var debug_mode=false\nvar debug_root: Control\nvar debug_open=false\nvar host',1)
s=s.replace('host=parent; engine=Duel.new(); engine.start(a,b,first,seed_value)','host=parent; debug_mode=host.debug_mode; engine=Duel.new(); engine.debug_enabled=debug_mode; engine.start(a,b,first,seed_value)',1)
s=s.replace('table.inspect_cards(engine.players[who].grave.map(func(c): return c.card_id)))','browse_zone(who,"grave")\n  elif debug_mode and zone in ["pdeck","adeck"]: browse_zone(0 if zone=="pdeck" else 1,"deck"))',1)
# Keep board ownership and life labels fixed; only decisions follow the acting seat.
for old,new in [
 ('engine.active==0 and engine.phase=="main"','engine.active==acting_player() and engine.phase=="main"'),
 ('engine.priority==0','engine.priority==acting_player()'),
 ('engine.has_response(0)','engine.has_response(acting_player())'),
 ('engine.pending.get("owner",-1)==0','engine.pending.get("owner",-1)==acting_player()'),
 ('engine.pending.owner==0','engine.pending.owner==acting_player()'),
 ('engine.players[0].mulligan_done','engine.players[acting_player()].mulligan_done'),
 ('engine.players[0].hand','engine.players[acting_player()].hand'),
 ('engine.players[0].palette','engine.players[acting_player()].palette'),
 ('engine.players[0].field','engine.players[acting_player()].field'),
 ('engine.legal_casts(0)','engine.legal_casts(acting_player())'),
 ('engine.available_actions(0,','engine.available_actions(acting_player(),'),
 ('engine.payment_valid(0,','engine.payment_valid(acting_player(),'),
 ('engine.payment(0,','engine.payment(acting_player(),'),
 ('engine.source_resources(0)','engine.source_resources(acting_player())'),
 ('engine.mulligan(0,','engine.mulligan(acting_player(),'),
 ('engine.pass_priority(0)','engine.pass_priority(acting_player())'),
 ('engine.cast_error(0,','engine.cast_error(acting_player(),'),
 ('c.owner==0','c.owner==acting_player()'),
 ('engine.attack(0,','engine.attack(acting_player(),'),
 ('engine.commit_ability(0,','engine.commit_ability(acting_player(),'),
 ('engine.commit_cast(0,','engine.commit_cast(acting_player(),')]: s=s.replace(old,new)
s=s.replace('if observing or modal or not local.is_empty()','if debug_open or observing or modal or not local.is_empty()',1)
s=s.replace('if engine.phase=="mulligan":\n  if not engine.players[1].mulligan_done: engine.ai_step()','if debug_mode:\n  if in_response_window() and not should_ask_response(): engine.pass_priority(acting_player())\n elif engine.phase=="mulligan":\n  if not engine.players[1].mulligan_done: engine.ai_step()',1)
s=s.replace('sync_hand_nodes(1,enemy_nodes,opponent_layer,[])','sync_hand_nodes(1,enemy_nodes,opponent_layer,available if debug_mode else [])')
s=s.replace('else Vector2(54,75)','else Vector2(88,123) if debug_mode else Vector2(54,75)',1)
s=s.replace('else minf(52,660.0/maxi(1,cards.size()))','else minf(90 if debug_mode else 52,750.0/maxi(1,cards.size()))',1)
s=s.replace('tile.build(self,c,who==1)','tile.build(self,c,who==1 and not debug_mode)',1)
s=s.replace('if who==0:\n    node.art.texture','if who==0 or debug_mode:\n    node.art.texture',1)
s=s.replace('if observing or modal or table.combat_animating or not local.is_empty() or response_disabled(): return','if debug_open or observing or modal or table.combat_animating or not local.is_empty() or response_disabled(): return\n if engine.find_card(uid).owner!=acting_player(): return',1)
s=s.replace('if not HAND.has_point(at): request_cast(uid)','if not hand_area(engine.find_card(uid).owner).has_point(at): request_cast(uid)',1)
s=s.replace('if not c.tapped).map','if not c.tapped and engine.can_possess(c)).map',1)
s=s.replace('and not c.tapped: select_possession','and not c.tapped and engine.can_possess(c): select_possession',1)
s=s.replace('text="你的行动"','text=("你" if acting_player()==0 else "人机")+"的行动"',1)
s=s.replace('btn("设置",Rect2(1460,12,116,40),settings_menu)','btn("设置",Rect2(1460,12,116,40),settings_menu)\n if debug_mode:\n  btn("调试",Rect2(325,12,92,38),debug_menu)\n  btn("你的牌库",Rect2(1045,53,125,34),func(): browse_zone(0,"deck"))\n  btn("人机牌库",Rect2(1180,53,125,34),func(): browse_zone(1,"deck"))\n  txt("操作："+("你" if acting_player()==0 else "人机"),Rect2(1115,15,158,32),18,host.GOLD)\n elif engine.legal_casts(0).any(func(c): return c.zone=="deck"):\n  btn("牌库可用牌",Rect2(1155,53,150,34),func(): browse_zone(0,"deck"))',1)
s=s.replace('if local.mode=="payment":\n   var valid=', 'if local.mode=="target":\n   btn("选择目标",Rect2(1330,745,237,50),open_local_choices,true)\n  if local.mode=="payment":\n   var valid=',1)
s=s.replace('"possession":\n    text="凭依"','"effect_choice":\n    text=engine.pending.trigger.name\n    btn("选择",Rect2(1330,735,237,52),open_effect_choices,true)\n    if engine.pending.trigger.optional: btn("不使用",Rect2(1330,803,237,45),func(): engine.choose_effect({}); render())\n   "timer":\n    text="计时指示物"\n    for i in range(3):\n     var delta=i-1\n     btn(["−1","不改变","+1"][i],Rect2(1330+i*80,770,75,50),func(): engine.choose_timer(delta); render())\n   "possession":\n    text="凭依"',1)
s=s.replace('if action.type=="attack": selection=[]; engine.attack(acting_player(),action.uid); render()\n else:', 'if action.type=="attack": selection=[]; engine.attack(acting_player(),action.uid); render()\n elif action.type=="extension":\n  local={"uid":action.uid,"action":"extension","key":action.key,"mode":"target","target":{},"plan":[]}\n  if local_targets()==[{"none":true}]: local.target={"none":true}; start_payment()\n  else: render(); open_local_choices()\n else:',1)
s=s.replace('func local_cost() -> Dictionary:\n','func local_cost() -> Dictionary:\n if local.get("action","")=="extension": return engine.Extra.activation_cost(local.key)\n',1)
s=s.replace('return engine.cards[engine.find_card(local.uid).card_id].cost','return engine.cast_cost(acting_player(),engine.find_card(local.uid))',1)
s=s.replace('func local_targets() -> Array:\n','func local_targets() -> Array:\n if local.get("action","")=="extension": return engine.Extra.activation_options(engine,engine.find_card(local.uid),local.key)\n',1)
s=s.replace('return engine.targets_for(engine.find_card(local.uid).card_id)','return engine.targets_for(engine.find_card(local.uid).card_id,acting_player())',1)
s=s.replace('if engine.cards[c.card_id].kind=="符卡": render()','if engine.cards[c.card_id].kind=="符卡":\n  if local_targets()==[{"none":true}]: local.target={"none":true}; start_payment()\n  else:\n   render()\n   if engine.Extra.spell_options(engine,c.card_id,acting_player())!=null: open_local_choices()',1)
s=s.replace('var error=engine.commit_ability(', 'var error=engine.commit_extension(acting_player(),local.uid,local.target,local.plan) if local.get("action","")=="extension" else engine.commit_ability(',1)
# Multi-mode / additional cost spells choose their complete declaration in the selector.
s=s.replace('if target not in local_targets(): message="目标不合法"; render(); return','if target not in local_targets():\n  var candidates=local_targets().filter(func(t): return t.get("uid",-1)==target.get("uid",-2) or t.get("player",-1)==target.get("player",-2) or t.get("stack_id",-1)==target.get("stack_id",-2))\n  if not candidates.is_empty(): choose_options("选择",candidates,func(chosen): local.target=chosen; start_payment()); return\n  message="目标不合法"; render(); return',1)
s=s.replace('image.texture=load("res://assets/card_back.svg") if inspect_id=="back" else host.texture(inspect_id)','image.texture=load("res://assets/card_back.svg") if inspect_id=="back" else host.texture(inspect_id)',1)
s+='''
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
func debug_panel(title: String) -> Panel:
 close_debug(); debug_open=true
 debug_root=Control.new(); debug_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(debug_root)
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); debug_root.add_child(shade)
 var panel=host.box(debug_root,Rect2(295,110,1280,745),Color("#101c28"),host.GOLD)
 txt(title,Rect2(25,14,1000,43),27,host.GOLD,panel)
 btn("返回",Rect2(1110,15,140,42),close_debug,false,panel)
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
  var tile=Control.new(); tile.custom_minimum_size=Vector2(162,286); grid.add_child(tile)
  var art=host.card(tile,c.card_id,Rect2(0,0,160,224),func(): inspect_card(c.card_id,c.uid))
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: inspect_card(c.card_id,c.uid))
  var name=txt(engine.cards[c.card_id].name,Rect2(0,230,160,50),16,host.WHITE,tile)
  name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  if not debug_mode and c.owner==acting_player() and not response_disabled() and engine.pending.is_empty():
   var action=engine.extra_action(c)
   if zone=="grave" and not action.is_empty() and engine.extension_activation_error(c.owner,c).is_empty():
    btn("发动",Rect2(30,232,100,40),func(): close_debug(); execute_action(action),true,tile)
   elif zone=="deck" and engine.cast_error(c.owner,c.uid).is_empty():
    btn("使用",Rect2(30,232,100,40),func(): close_debug(); request_cast(c.uid),true,tile)
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
'''
p.write_text(s,'utf-8')
# Native generated tokens have explicit text and use existing blank art, not fabricated card art.
p=root/'scripts/main.gd';s=p.read_text('utf-8').replace('if id=="potato": return load("res://assets/potato.svg")','if id in ["potato","token_ufo","token_halfghost"]: return load("res://assets/potato.svg")',1);p.write_text(s,'utf-8')
p=root/'scripts/duel_table.gd';s=p.read_text('utf-8').replace('["deck","hand","field","palette","grave"]','["deck","hand","field","palette","grave","exile"]')
s=s.replace('duel.pending.get("owner",-1)==0 and d.owner==0','duel.pending.get("owner",-1)==d.owner').replace('not duel.find_card(d.uid).tapped','not duel.find_card(d.uid).tapped and duel.can_possess(duel.find_card(d.uid))',1)
s=s.replace('duel.combat.get("step","")=="damage_window" and last_combat.get("step","")!="damage_window"','duel.combat.get("step","") in ["damage_window","first_damage_window"] and last_combat.get("step","")!=duel.combat.get("step","")',1)
p.write_text(s,'utf-8')
