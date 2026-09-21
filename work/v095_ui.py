from pathlib import Path
p=Path(__file__).resolve().parents[1]/'scripts/duel_view.gd'
s=p.read_text('utf-8')
def replace_func(name,body):
 global s
 start=s.index('func '+name+'(')
 end=s.find('\nfunc ',start+1)
 if end<0: end=len(s)
 s=s[:start]+body.rstrip()+'\n'+s[end:]
replace_func('update_inspection', '''func update_inspection():
 var current=engine.find_card(inspect_uid)
 var enabled=not current.is_empty() and engine.has_leader_ability(current)
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
 if info.get("fast",false): inspection_text.add_text("高速\\n")
 var at=rules.find("自机能力：")
 if at>=0:
  inspection_text.add_text(rules.left(at))
  inspection_text.push_color(host.WHITE if enabled else Color("#78818b"))
  inspection_text.add_text(rules.substr(at)); inspection_text.pop()
 else: inspection_text.add_text(rules)
 inspection_text.set_meta("leader_enabled",enabled)
''')
replace_func('browse_zone','''func browse_zone(who: int,zone: String,scroll_position: int=0):
 if history_open: return
 close_debug(); debug_open=true; browser_owner=who; browser_zone=zone
 debug_root=layer(ui)
 browser_panel=host.box(debug_root,SIDEBAR,Color("#101c28"),Color("#637a93")); browser_panel.name="PileBrowser"
 var cards=zone_cards(who,zone)
 for i in range(3):
  var tab=["deck","grave","exile"][i]
  btn(ZONE_NAMES[tab],Rect2(8+i*94,10,88,36),func(): browse_zone(browser_owner,tab),tab==zone,browser_panel)
 var owner_picker=OptionButton.new(); owner_picker.position=Vector2(10,54); owner_picker.size=Vector2(107,35); browser_panel.add_child(owner_picker)
 owner_picker.add_item("你"); owner_picker.add_item("人机"); owner_picker.selected=who
 owner_picker.item_selected.connect(func(index): browse_zone(index,browser_zone))
 txt("%s · %d" % [ZONE_NAMES[zone],cards.size()],Rect2(125,57,155,30),18,host.GOLD,browser_panel)
 var top=98
 if debug_mode:
  var zone_picker=OptionButton.new(); zone_picker.position=Vector2(10,94); zone_picker.size=Vector2(270,33); browser_panel.add_child(zone_picker)
  var zones=ZONE_NAMES.keys()
  for key in zones: zone_picker.add_item(ZONE_NAMES[key])
  zone_picker.selected=zones.find(zone)
  zone_picker.item_selected.connect(func(index): browse_zone(browser_owner,zones[index]))
  top=137
 browser_scroll=ScrollContainer.new(); browser_scroll.position=Vector2(8,top); browser_scroll.size=Vector2(278,SIDEBAR.size.y-top-8)
 browser_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; browser_panel.add_child(browser_scroll)
 browser_cards=VBoxContainer.new(); browser_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL; browser_cards.add_theme_constant_override("separation",6); browser_scroll.add_child(browser_cards)
 var hidden=zone=="deck" and not debug_mode or zone=="hand" and who!=0 and not debug_mode
 for i in range(cards.size()):
  var c=cards[i]
  var tile=Control.new(); tile.custom_minimum_size=Vector2(258,116); browser_cards.add_child(tile)
  tile.set_meta("display_id","back" if hidden else c.card_id)
  var art=host.card(tile,"back" if hidden else c.card_id,Rect2(0,0,80,112)); art.name="PileCard"
  art.gui_input.connect(func(event):
   if not event is InputEventMouseButton or not event.pressed: return
   if event.button_index==MOUSE_BUTTON_RIGHT: inspect_card("back",0,"未公开") if hidden else inspect_card(c.card_id,c.uid)
   elif event.button_index==MOUSE_BUTTON_LEFT:
    if debug_mode: begin_debug_drag(c.uid,art.get_global_transform()*event.position)
    elif not hidden: browse_card_action(c))
  var caption=txt(str(i+1)+" · "+("未公开" if hidden else engine.cards[c.card_id].name),Rect2(88,0,166,42),15,host.WHITE,tile)
  caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; caption.size=Vector2(166,42)
  if not hidden:
   var rules=txt(engine.cards[c.card_id].rules_text,Rect2(88,47,166,61),13,host.MUTED,tile)
   rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; rules.size=Vector2(166,61)
 if cards.is_empty(): txt("空",Rect2(110,top+35,60,35),22,host.MUTED,browser_panel)
 browser_scroll.set_deferred("scroll_vertical",scroll_position)
 refresh_observation()
func browse_card_action(c: Dictionary):
 inspect_card(c.card_id,c.uid)
 if picker_active(): choose_target(engine.ref_target(c)); return
 if c.owner!=acting_player() or response_disabled(): return
 if engine.cast_error(c.owner,c.uid).is_empty(): close_debug(); request_cast(c.uid); return
 var action=engine.extra_action(c)
 if not action.is_empty() and engine.extension_activation_error(c.owner,c).is_empty(): close_debug(); execute_action(action)
''')
# Intercept topmost log and outside-sidebar dismissals before any cast cancellation.
s=s.replace('func _input(event: InputEvent):','''func _input(event: InputEvent):
 if history_open:
  if event is InputEventMouseButton and event.pressed:
   var at=make_input_local(event).position
   if not history_panel.get_global_rect().has_point(at):
    if event.button_index==MOUSE_BUTTON_RIGHT: close_history()
    get_viewport().set_input_as_handled()
  return
 if debug_open and debug_drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if not browser_panel.get_global_rect().has_point(make_input_local(event).position):
   close_debug(); get_viewport().set_input_as_handled(); return
''',1)
# Zone targets are presented in a card window, never as name rows.
s=s.replace('if not c.is_empty() and c.zone not in ["field","palette","leader","stack","hand"]: options.append(atom)','if not c.is_empty() and c.zone not in ["field","palette","leader","stack","hand"]: continue')
s=s.replace('if is_instance_valid(debug_controls): ui.move_child(debug_controls,-1)','if is_instance_valid(debug_controls): ui.move_child(debug_controls,-1)\n if history_open and is_instance_valid(history_root): ui.move_child(history_root,-1)')
s+='''
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
 panel.position=Vector2(380,190); panel.size=Vector2(895,460); panel.set_meta("region_picker",true)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(20,72); scroll.size=Vector2(855,308)
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",12); scroll.add_child(row); region_tiles={}
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
'''
p.write_text(s,'utf-8')
