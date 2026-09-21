from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]/'scripts/duel_view.gd'
s=p.read_text('utf-8')
def func(name,body):
 global s
 pat=rf'^func {name}\([^\n]*\n.*?(?=^func |\Z)'
 new=body.strip()+'\n\n'
 if re.search(pat,s,re.M|re.S): s=re.sub(pat,lambda _:new,s,count=1,flags=re.M|re.S)
 else: s+='\n'+new
s=s.replace('var browser_cards: VBoxContainer','var browser_cards: GridContainer')
s=s.replace('var browser_owner=0','var hand_zones={0:"hand",1:"hand"}\nvar hand_zone_tabs={}\nvar debug_drag_browser=false\nvar browser_owner=0')
s=s.replace('table.combat_animation_finished.connect(render)','table.combat_animation_finished.connect(render)\n table.combat_damage_shown.connect(rebuild_badges)')
s=s.replace('  btn("你的牌库",Rect2(1185,57,125,34),func(): browse_zone(0,"deck"),false,debug_controls)\n','').replace('  btn("人机牌库",Rect2(1320,57,125,34),func(): browse_zone(1,"deck"),false,debug_controls)\n','')
s=s.replace(' if history_open or debug_open or observing or modal or not local.is_empty()', ' if table.combat_animating or history_open or debug_drag_uid!=0 or observing or modal or not local.is_empty()')
# Pile browsing is non-modal. A deck ability should never trap automatic priority passing.
s=s.replace(' var side_bg=host.box(hud,SIDEBAR,Color("#0d1825"),Color("#304657")); side_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE\n for i in range(3):\n  var zone=["deck","grave","exile"][i]\n  btn(ZONE_NAMES[zone],Rect2(1298+i*94,173,88,36),func(): browse_zone(acting_player(),zone))\n','')
s=s.replace(' elif engine.legal_casts(0).any(func(c): return c.zone=="deck"):\n  btn("牌库可用牌",Rect2(1155,53,150,34),open_deck_casts)\n','')
s=s.replace(' render_prompt()\n building_prompt=false',' if not table.combat_animating: render_prompt()\n building_prompt=false')
s=s.replace(' update_browser_styles()\n if history_open', ' if debug_open and not debug_dragging:\n  var scroll_at=browser_scroll.scroll_vertical\n  browse_zone(browser_owner,browser_zone,scroll_at)\n update_browser_styles()\n if history_open',1)
s=s.replace(' var cards=engine.players[who].hand\n var ids=cards.map', ' var cards=displayed_hand_cards(who)\n var ids=cards.map',1)
s=s.replace('func render_hands(available: Array):\n', 'func render_hands(available: Array):\n render_hand_zone_tabs()\n')
s=s.replace('  node.update_style(c.uid in available,c.uid in selected_uids())','  node.update_style(c.uid in available or (c.zone!="hand" and can_use_region_card(c)),c.uid in selected_uids())')
s=s.replace(' var c=table.old_cards.get(d.uid,{}) if table.combat_animating else engine.find_card(d.uid)',' var c=(table.combat_display_cards.get(d.uid,table.old_cards.get(d.uid,{})) if table.damage_revealed else table.old_cards.get(d.uid,{})) if table.combat_animating else engine.find_card(d.uid)')
s=s.replace('    var value=engine.stat(c,key_name)-(c.damage if key_name=="health" else 0)','    var value=c.get("display_stats",{}).get(key_name,engine.stat(c,key_name)-(c.damage if key_name=="health" else 0))')
s=s.replace(' var signature=inspect_id+str(inspect_uid)+inspect_caption+str(enabled)',' inspection.visible=not inspect_id.is_empty()\n var signature=inspect_id+str(inspect_uid)+inspect_caption+str(enabled)')
s=s.replace(' var label=txt(caption,Rect2(420,314,850,76)', ' var label=txt(caption,Rect2(375,314,850,76)')
# Center modal panels after their final dimensions, independent of content size.
s=s.replace('Rect2(920,240,650,330)','Rect2(475,285,650,330)')
s=re.sub(r'panel.position=Vector2\(\d+,\d+\); panel.size=Vector2\(([^\n;]+)\)',r'panel.size=Vector2(\1); center_panel(panel)',s)
s=s.replace('func stage_input(event: InputEvent):\n','func stage_input(event: InputEvent):\n if table.combat_animating: return\n if debug_mode and can_begin_debug_drag() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:\n  var uid=table.card_at(event.position/STAGE.size*Vector2(viewport.size))\n  if uid>0:\n   begin_debug_drag(uid,STAGE.position+event.position); return\n')
s=s.replace('func _input(event: InputEvent):\n','func _input(event: InputEvent):\n if is_instance_valid(table) and table.combat_animating:\n  get_viewport().set_input_as_handled(); return\n')
s=s.replace(' if engine.cast_error(acting_player(),uid).is_empty():\n  close_debug(); request_cast(uid)',' var card=engine.find_card(uid)\n if card.is_empty(): return\n if engine.cast_error(acting_player(),uid).is_empty():\n  close_debug(); request_cast(uid)\n elif card.zone!="hand" and engine.extension_activation_error(acting_player(),card).is_empty():\n  close_debug(); execute_action(engine.extra_action(card))')
func('local_prompt','''func local_prompt() -> String:
 if local.mode=="target": return engine.cards[engine.find_card(local.uid).card_id].name
 if local.mode=="payment_offer": return "自动选择费用？"
 if local.mode=="payment_color": return "选择颜色"
 var cost=local_cost(); var result=engine.ColorCost.remaining(cost,local.get("plan",[])); var pieces=[]
 for group in cost:
  var paid=int(cost[group])-int(result.remaining.get(group,cost[group]))
  pieces.append("%s %d / %d" % [group,paid,cost[group]])
 return "手动支付  ·  "+"    ".join(pieces)''')
s=s.replace('return r.colors.any(func(color): return local.plan.filter(func(p): return p.color==color).size()<int(cost.get(color,0))))','return r.colors.any(func(color): return engine.ColorCost.allows(cost,local.plan,color)))')
s=s.replace('if local.plan.filter(func(r): return r.color==color).size()<int(cost.get(color,0)): colors.append(color)','if engine.ColorCost.allows(cost,local.plan,color): colors.append(color)')
func('browse_zone','''func browse_zone(who: int,zone: String,scroll_position: int=0):
 if history_open or table.combat_animating: return
 close_debug(); debug_open=true; browser_owner=who; browser_zone=zone
 debug_root=layer(ui)
 browser_panel=host.box(debug_root,SIDEBAR,Color("#101c28"),Color("#637a93")); browser_panel.name="PileBrowser"
 var cards=zone_cards(who,zone)
 txt(("你" if who==0 else "人机")+" · "+ZONE_NAMES[zone]+" · %d" % cards.size(),Rect2(12,10,270,35),20,host.GOLD,browser_panel)
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
 update_browser_styles(); refresh_observation()''')
s=s.replace(' if not debug_mode or observing: return\n var c=engine.find_card(uid)',' if not debug_mode or observing: return\n var c=engine.find_card(uid)')
s=s.replace(' debug_drag_uid=uid; debug_drag_epoch=c.epoch;', ' debug_drag_browser=is_instance_valid(browser_panel) and browser_panel.get_global_rect().has_point(at)\n debug_drag_uid=uid; debug_drag_epoch=c.epoch;')
s=s.replace('   browser_panel.hide()','   if is_instance_valid(browser_panel): browser_panel.hide()')
s=s.replace('debug_drop_hint.position=Vector2(-15,199)','debug_drop_hint.position=Vector2(-15,-43)')
s=s.replace(' if not moved: browse_card_action(c); return',' if not moved:\n  if c.zone in ["field","leader"]: object_clicked(c.uid)\n  elif c.zone=="hand": hand_clicked(c.uid)\n  else: browse_card_action(c)\n  return')
s=s.replace(' render()\n browse_zone(browser_owner,browser_zone,scroll_position)',' render()\n if debug_drag_browser: browse_zone(browser_owner,browser_zone,scroll_position)')
# Do not reset view-only state when a card grid is refreshed by an advancing duel.
s=s.replace(' if observing:\n  observing=false\n  if is_instance_valid(modal_root): modal_root.visible=true',' if observing:\n  observing=false\n  if is_instance_valid(modal_root): modal_root.visible=true',1)
func('center_panel','''func center_panel(panel: Control):
 panel.position=(Vector2(1600,900)-panel.size)*0.5''')
func('can_begin_debug_drag','''func can_begin_debug_drag() -> bool:
 return debug_mode and not observing and not history_open and not modal and local.is_empty() and engine.pending.is_empty() and engine.phase!="mulligan" and not table.combat_animating''')
func('can_use_region_card','''func can_use_region_card(c: Dictionary) -> bool:
 if c.owner!=acting_player() or response_disabled(): return false
 return engine.cast_error(c.owner,c.uid).is_empty() or not engine.extra_action(c).is_empty() and engine.extension_activation_error(c.owner,c).is_empty()''')
func('region_action_cards','''func region_action_cards(who: int,zone: String) -> Array:
 if who!=acting_player() or response_disabled(): return []
 return engine.players[who][zone].filter(func(c): return can_use_region_card(c))''')
func('available_hand_zones','''func available_hand_zones(who: int) -> Array:
 var zones=["hand"]
 for zone in ["grave","exile","deck"]:
  if not region_action_cards(who,zone).is_empty(): zones.append(zone)
 return zones''')
func('displayed_hand_cards','''func displayed_hand_cards(who: int) -> Array:
 var zones=available_hand_zones(who)
 if hand_zones[who] not in zones: hand_zones[who]="hand"
 return engine.players[who].hand if hand_zones[who]=="hand" else region_action_cards(who,hand_zones[who])''')
func('render_hand_zone_tabs','''func render_hand_zone_tabs():
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
   hand_zone_tabs[str(who)+":"+zone]=button''')
p.write_text(s,'utf-8')
print('v096 UI functions updated')
