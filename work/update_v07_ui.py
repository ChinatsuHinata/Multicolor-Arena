from pathlib import Path
root=Path('.')
def edit(rel,old,new):
 p=root/rel;s=p.read_text(encoding='utf-8');assert old in s,(rel,old[:80]);p.write_text(s.replace(old,new),encoding='utf-8')
p='scripts/duel_view.gd'
s=(root/p).read_text(encoding='utf-8')
start=s.index('func cost_chips(');end=s.index('func render_hands(',start)
s=s[:start]+s[end:]
s=s.replace('   if who==0: cost_chips(tile,engine.cards[c.card_id].cost,Vector2(2,-19))\n','')
start=s.index('func rebuild_badges():');end=s.index('func projected_card_rect(',start)
s=s[:start]+'''func rebuild_badges():
 clear_children(badges); card_badges={}
 for key in table.descriptors:
  var d=table.descriptors[key]
  if d.zone not in ["field","leader"]: continue
  var c=engine.find_card(d.uid)
  if c.is_empty(): continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  var parts={"root":root,"zone":d.zone,"owner":d.owner}
  if d.zone=="field" and engine.is_unit(c):
   var panel=host.box(root,Rect2(0,0,99,25),Color("#111d2b"),Color("#aaa080")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   var label=txt("%d / %d · %d" % [engine.stat(c,"power"),engine.stat(c,"health")-c.damage,engine.stat(c,"spirit")],Rect2(1,0,97,25),16,host.WHITE,panel); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   parts.stats=panel
   if engine.summoning_sick(c) and not engine.has_haste(c): parts.sick=txt("召唤失调",Rect2(0,0,100,22),14,Color("#b6cdf3"),root)
  elif d.zone=="leader" and c.timer>0:
   parts.sick=txt("计时 %d" % c.timer,Rect2(0,0,100,24),17,host.GOLD,root)
  card_badges[key]=parts
 for key in table.piles:
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  card_badges[key]={"root":root,"zone":"pile"}
  var is_deck="deck" in key
  var who=0 if key.begins_with("p") else 1
  var label=txt(("牌库 " if is_deck else "墓地 ")+str(engine.players[who].deck.size() if is_deck else engine.players[who].grave.size()),Rect2(-48,0,96,26),17,host.WHITE,root)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 update_badge_positions()
''' + s[end:]
s=s.replace('   if parts.has("cost"):\n    var inside=parts.zone=="field" and not parts.has("stats")\n    parts.cost.position=Vector2(-parts.cost_width/2.0,-rect.size.y/2+(1 if inside else -23))\n','')
s=s.replace('parts.stats.position=Vector2(-49.5,rect.size.y/2+1)','parts.stats.position=Vector2(-49.5,rect.size.y/2-25)')
s=s.replace('parts.sick.position=Vector2(-49,rect.size.y/2+27)','parts.sick.position=Vector2(-49,rect.size.y/2+1)')
s=s.replace('   if parts.has("palette"): parts.palette.position.y=rect.size.y/2+1\n','')
s=s.replace('root.position=project(table.piles[key].position+Vector3(0,table.stack_heights[key]+0.1,0.0))','root.position=project(table.piles[key].position+Vector3(0,0.03,1.3))')
s=s.replace(' var panel=host.box(banner,Rect2(465,292,735,115),Color(0.05,0.09,0.15,0.94),host.GOLD)\n panel.mouse_filter=Control.MOUSE_FILTER_IGNORE\n','')
s=s.replace('var label=txt(caption,Rect2(20,22,695,68),36,host.GOLD,panel)','var label=txt(caption,Rect2(420,314,850,76),42,Color("#fff2c0"),banner)\n label.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.03,0.95))\n label.add_theme_constant_override("shadow_offset_x",3)\n label.add_theme_constant_override("shadow_offset_y",4)\n label.add_theme_constant_override("outline_size",5)\n label.add_theme_color_override("font_outline_color",Color("#151a24"))')
s=s.replace('if engine.pending.kind=="possession": return engine.players[0].palette.filter(func(c): return not c.tapped).map(func(c): return c.uid)','if engine.pending.kind=="possession": return []')
s=s.replace('   "possession":\n    text="凭依：选择颜色盘与手牌"\n    btn("跳过凭依",Rect2(1330,770,237,55),func(): engine.possession(); selection=[]; render(),true)', '''   "possession":
    text="凭依"
    var confirm=btn("确定凭依",Rect2(1330,735,237,52),confirm_possession,true)
    confirm.disabled=selected_in_zone("palette")==0 or selected_in_zone("hand")==0
    btn("跳过凭依",Rect2(1330,803,237,45),func(): engine.possession(); selection=[]; render())''')
s=s.replace('''  if selection.size()==1 and engine.find_card(selection[0]).zone=="palette":
   engine.possession(selection[0],uid); selection=[]; render()
  return''','''  if selected_in_zone("palette")!=0: select_possession(uid,"hand")
  return''')
s=s.replace('if not c.is_empty() and c.owner==0 and c.zone=="palette" and not c.tapped: selection=[uid]; render()','if not c.is_empty() and c.owner==0 and c.zone=="palette" and not c.tapped: select_possession(uid,"palette")')
s=s.replace('func right_cancel():','''func selected_in_zone(zone: String) -> int:
 for uid in selection:
  var c=engine.find_card(uid)
  if not c.is_empty() and c.zone==zone and c.owner==0: return uid
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
func right_cancel():''')
s=s.replace(' elif is_instance_valid(table.inspect_root): table.inspect_root.queue_free()',' elif engine.pending.get("kind","")=="possession": selection=[]; render()\n elif is_instance_valid(table.inspect_root): table.inspect_root.queue_free()')
s=s.replace('if engine.summoning_sick(current):','if engine.summoning_sick(current) and not engine.has_haste(current):')
(root/p).write_text(s,encoding='utf-8')
p='scripts/duel_hand_card.gd'
edit(p,' add_theme_stylebox_override("panel",view.host.style(Color("#27313d"),view.host.GOLD if ready or selected else Color("#405167")))',''' var style=view.host.style(Color("#27313d"),view.host.GOLD if ready or selected else Color("#405167"))
 style.set_border_width_all(5 if ready or selected else 1)
 if ready or selected:
  style.border_color=Color("#ffd65c")
  style.shadow_color=Color(1.0,0.67,0.13,0.72)
  style.shadow_size=10 if selected else 7
 add_theme_stylebox_override("panel",style)''')
edit(p,'art.position=Vector2(4,4); art.size=size-Vector2(8,8)','art.position=Vector2(7,7); art.size=size-Vector2(14,14)')
p='scripts/duel_table.gd'
edit(p,'const LAYER_HEIGHT=0.026','const LAYER_HEIGHT=0.012\nconst SLOT_SCALE=0.82\nconst BOARD_SIZE=Vector2(23,16)\n# Normalized centers measured from the printed zones on playmat 3.\nconst MAT_SLOTS={"deck":Vector2(1070.0/1200.0,809.0/1200.0),"grave":Vector2(1070.0/1200.0,1027.0/1200.0),"leader":Vector2(124.0/1200.0,809.0/1200.0)}')
edit(p,'Vector2(23,16),mat','BOARD_SIZE,mat')
start=(root/p).read_text(encoding='utf-8').index('func zone_position(')
s=(root/p).read_text(encoding='utf-8');end=s.index('func card_snapshot()',start)
s=s[:start]+'''func zone_position(zone: String, who: int) -> Vector3:
 var side=1.0 if who==0 else -1.0
 var slot="leader" if zone=="return_pending" else zone
 if MAT_SLOTS.has(slot):
  var uv=MAT_SLOTS[slot]
  return Vector3((uv.x-0.5)*BOARD_SIZE.x*side,0.035,(uv.y-0.5)*BOARD_SIZE.y*side)
 match zone:
  "hand": return Vector3(0,1,10*side)
  "palette": return Vector3(0,0.035,5.7*side)
 return Vector3.ZERO

''' + s[end:]
s=s.replace('description(p.leader,zone_position("leader",who))','description(p.leader,zone_position("leader",who),SLOT_SCALE)')
s=s.replace('Vector3(-5.4+(unit_index%3)*2.6,0.1,(2.3+(unit_index/3)*2.2)*side)','Vector3(-6.2+unit_index*2.46,0.035,1.65*side)')
s=s.replace('d=description(c,at); unit_index+=1','d=description(c,at,0.95); unit_index+=1')
s=s.replace('Vector3(0.3+group*1.9+n*0.22,0.12+n*0.045,3.6*side),0.64','Vector3(-4.8+group*2.7+n*0.25,0.035+n*0.028,3.9*side),0.48')
s=s.replace('Vector3(-6.1+(i%8)*1.67,0.1+(i/8)*0.1,(6.1+(i/8)*0.25)*side)','Vector3(-6.1+(i%8)*1.67,0.035+(i/8)*0.04,(5.7+(i/8)*0.25)*side)')
s=s.replace('Vector3(7.4,0.1,6.1*side)','Vector3(7.35,0.035,5.7*side)')
s=s.replace('  if c.uid in chosen: d.at.y+=0.24','  if c.uid in chosen: d.at.y+=0.055')
s=s.replace('  node.get_node("Outline").visible=d.gold','''  var can_possess=duel.pending.get("kind","")=="possession" and duel.pending.get("owner",-1)==0 and d.owner==0 and d.zone=="palette" and d.uid>0 and not duel.find_card(d.uid).tapped
  var outline=node.get_node("Outline")
  outline.visible=d.gold or can_possess
  outline.material_override=material("#ffd65c" if d.gold else "#359bff")
  var halo=node.get_node("Halo")
  halo.visible=outline.visible
  halo.material_override=material("#785415" if d.gold else "#184878")''')
s=s.replace(' plane(root,Vector3(0,-0.02,0),CARD_SIZE+Vector2(0.18,0.18),material("#edc363")).name="Outline"',''' plane(root,Vector3(0,-0.015,0),CARD_SIZE+Vector2(0.48,0.48),material("#785415")).name="Halo"
 plane(root,Vector3(0,-0.009,0),CARD_SIZE+Vector2(0.27,0.27),material("#ffd65c")).name="Outline"''')
# Real pile height remains proportional to count; footprint fits the printed slot.
s=s.replace('var mesh=BoxMesh.new(); mesh.size=Vector3(CARD_SIZE.x,LAYER_HEIGHT*0.88,CARD_SIZE.y)','var mesh=BoxMesh.new(); mesh.size=Vector3(CARD_SIZE.x*SLOT_SCALE,LAYER_HEIGHT*0.88,CARD_SIZE.y*SLOT_SCALE)')
s=s.replace('plane(root,Vector3.ZERO,CARD_SIZE,material("back")).name="Top"','plane(root,Vector3.ZERO,CARD_SIZE*SLOT_SCALE,material("back")).name="Top"')
s=s.replace('area(root,Vector3.ZERO,Vector3(CARD_SIZE.x,0.2,CARD_SIZE.y))','area(root,Vector3.ZERO,Vector3(CARD_SIZE.x*SLOT_SCALE,0.2,CARD_SIZE.y*SLOT_SCALE))')
(root/p).write_text(s,encoding='utf-8')
# Update obsolete fixed card-pool assertions only, retain behavioral regression tests.
edit('tests/test_duel_rules.gd','db.load_cards().size()==8,"all eight definitions pass schema and image validation"','db.load_cards().size()==15,"all fifteen definitions pass schema and image validation"')
edit('tests/test_v06.gd','==app.GOLD,"playable hand card has gold border"','==Color("#ffd65c"),"playable hand card has gold border"')
print('v0.7 view, possession, outlines and mat alignment written')
