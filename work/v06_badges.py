from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/duel_view.gd';s=f.read_text(encoding='utf-8-sig')
a=s.index('func rebuild_badges():');b=s.index('func show_phase_banner():',a)
s=s[:a]+'''func rebuild_badges():
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
  var parts={"root":root,"zone":d.zone}
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
   if parts.has("cost"): parts.cost.position=Vector2(-parts.cost_width/2.0,-rect.size.y/2-23)
   if parts.has("stats"): parts.stats.position=Vector2(-49.5,rect.size.y/2+1)
   if parts.has("sick"): parts.sick.position=Vector2(-49,rect.size.y/2+27)
   if parts.has("palette"): parts.palette.position.y=rect.size.y/2+1
  elif table.piles.has(key):
   root.position=project(table.piles[key].position+Vector3(0,table.stack_heights[key]+0.1,1.65))
  root.visible=root.position.x>292 and root.position.y>140 and root.position.y<635
  if parts.zone!="stack" and stack_rects.any(func(r): return r.has_point(root.position)): root.visible=false

'''+s[b:]
f.write_text(s,encoding='utf-8')
