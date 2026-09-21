from pathlib import Path
root=Path(__file__).resolve().parent.parent
p=root/'scripts/rules/expanded_abilities.gd';s=p.read_text('utf-8')
s=s.replace('for unit in e.units(0)+e.units(1):\n  if has(e.cards[unit.card_id],"death_devour")','for unit in e.death_observers if not e.death_observers.is_empty() else e.units(0)+e.units(1):\n  if has(e.cards[unit.card_id],"death_devour")',1)
s=s.replace('var observers=e.units(c.owner).duplicate()','var observers=(e.death_observers.filter(func(u): return u.owner==c.owner) if not e.death_observers.is_empty() else e.units(c.owner)).duplicate()',1)
s=s.replace('if has(info,"leader_death_damage"): observers.append(before)','if has(info,"leader_death_damage") and not observers.any(func(u): return u.uid==before.uid): observers.append(before)',1)
s=s.replace('"enter_grave_damage": return zone_refs(e,"grave",who).filter(func(x): return e.is_unit(e.find_card(x.uid)))','''"enter_grave_damage":
   var result=[]
   for dead in zone_refs(e,"grave",who).filter(func(x): return e.is_unit(e.find_card(x.uid))):
    for aim in e.ability_targets(): result.append({"parts":[dead,aim]})
   return result''',1)
s=s.replace('''if valid(e,target):
    var picked=e.find_card(target.uid); var spirit=e.stat(picked,"spirit")
    e.move_to(picked,"hand")
    event(e,source,"returned_spirit_damage",false,{"amount":spirit})''','''if valid(e,target.parts[0]):
    var picked=e.find_card(target.parts[0].uid); var spirit=e.stat(picked,"spirit")
    e.move_to(picked,"hand")
    e.damage_target(target.parts[1],spirit)''',1)
s=s.replace('if original and valid(e,target):\n    e.combat_queue.append','if original and valid(e,target) and e.combat.is_empty():\n    e.combat_queue.append',1)
s=s.replace('"token_sacrifice":\n   if original:','"combat_exile_target":\n   if e.target_valid(data.ref,true): e.move_to(e.find_card(data.ref.uid),"exile")\n  "token_sacrifice":\n   if original:',1)
s=s.replace('for c in p.field.duplicate(): e.move_to(c,"exile")','for c in p.field.duplicate():\n     if e.cards[c.card_id].kind!="符卡": e.move_to(c,"exile")',1)
# Zone changes caused by an effect keep a card in its original zone when field entry is illegal.
s=s.replace('if valid(e,t):\n      var c=e.find_card(t.uid); e.detach(c); e.enter_field(c,who)','if valid(e,t):\n      var c=e.find_card(t.uid)\n      if e.field_error(c,who).is_empty(): e.detach(c); e.enter_field(c,who)',1)
s=s.replace('if valid(e,t):\n    var c=e.find_card(t.uid); e.detach(c); e.enter_field(c,who)','if valid(e,t):\n    var c=e.find_card(t.uid)\n    if e.field_error(c,who).is_empty(): e.detach(c); e.enter_field(c,who)',1)
s=s.replace('if same and c.zone=="grave":\n    e.detach(c)','if same and c.zone=="grave" and e.field_error(c,c.owner).is_empty():\n    e.detach(c)',1)
# Source may have left, but an on-death trigger still has its last known spirit value.
p.write_text(s,'utf-8')
p=root/'scripts/rules/duel_engine.gd';s=p.read_text('utf-8').replace('var cleanup_done=false','var cleanup_done=false\nvar death_observers=[]',1)
s=s.replace('if resolving_spell and amount>0: c.spell_damage=true','if amount>0: c.spell_damage=resolving_spell',1)
s=s.replace('func judge():\n for who','func judge():\n death_observers=(units(0)+units(1)).duplicate(true)\n for who',1)
s=s.replace('to_grave(c); note(cards[c.card_id].name+"离开战场")','if resolving_spell: c.spell_damage=true\n    to_grave(c); note(cards[c.card_id].name+"离开战场")',1)
s=s.replace('var dead=[]\n for who','death_observers=[]\n var dead=[]\n for who',1)
s=s.replace('elif e.get("activation",false): Extra.resolve_activation(self,e)','elif e.get("activation",false): Extra.resolve_activation(self,e)',1)
# Target legality is checked again when resolving, including mode-specific restrictions.
s=s.replace('not Extra.valid(self,e.target):','not spell_target_valid(e.card.card_id,e.target):',1)
s+='''
func spell_target_valid(id: String,target: Dictionary) -> bool:
 if not Extra.valid(self,target): return false
 if id=="130": return target_valid(target,true) and stat(find_card(target.uid),"spirit")>=3
 if id=="139": return target_valid(target,true) and cards[find_card(target.uid).card_id].kind!="自机"
 return true
'''
p.write_text(s,'utf-8')
p=root/'scripts/duel_view.gd';s=p.read_text('utf-8').replace('var debug_root: Control','var debug_controls: Control\nvar debug_root: Control',1)
start=s.index(' if debug_mode:\n  btn("调试",');end=s.index(' btn("人机  %d"',start)
s=s[:start]+''' if debug_mode:
  txt("操作："+("你" if acting_player()==0 else "人机"),Rect2(1115,15,158,32),18,host.GOLD)
 elif engine.legal_casts(0).any(func(c): return c.zone=="deck"):
  btn("牌库可用牌",Rect2(1155,53,150,34),func(): browse_zone(0,"deck"))
'''+s[end:]
s=s.replace('observe_button.visible=false\n get_viewport()', '''observe_button.visible=false
 if debug_mode:
  debug_controls=layer(ui)
  btn("调试",Rect2(325,12,92,38),debug_menu,false,debug_controls)
  btn("你的牌库",Rect2(1045,53,125,34),func(): browse_zone(0,"deck"),false,debug_controls)
  btn("人机牌库",Rect2(1180,53,125,34),func(): browse_zone(1,"deck"),false,debug_controls)
 get_viewport()''',1)
s=s.replace('ui.move_child(observe_button,-1)','ui.move_child(observe_button,-1)\n if is_instance_valid(debug_controls): ui.move_child(debug_controls,-1)',1)
s=s.replace('panel)\n return panel\nfunc browse_zone','panel)\n refresh_observation()\n return panel\nfunc browse_zone',1)
s=s.replace('if not debug_mode and c.owner==acting_player()','if c.owner==acting_player()',1)
s=s.replace('palette.filter(func(c): return not c.tapped)','palette.filter(func(c): return not c.tapped and engine.can_possess(c))',1)
s=s.replace('engine.players[acting_player()].hand.map(func(c): return c.uid))','engine.players[acting_player()].hand.filter(func(c): return engine.can_possess(c)).map(func(c): return c.uid))',1)
s=s.replace('if selected_in_zone("palette")!=0: select_possession(uid,"hand")','if selected_in_zone("palette")!=0 and engine.can_possess(engine.find_card(uid)): select_possession(uid,"hand")',1)
# Inspectors are opened independently of a pending choice, retaining its state underneath.
s=s.replace('if engine==null: return\n update_badge_positions()','if engine==null: return\n update_badge_positions()',1)
s=s.replace('if zone in ["pgrave","agrave"]:\n   var who=0 if zone=="pgrave" else 1\n   browse_zone(who,"grave")','if zone in ["pgrave","agrave","pexile","aexile"]:\n   var who=0 if zone.begins_with("p") else 1\n   browse_zone(who,"exile" if "exile" in zone else "grave")',1)
s=s.replace('var is_deck="deck" in key','var zone_name="deck" if "deck" in key else "exile" if "exile" in key else "grave"',1)
s=s.replace('("牌库 " if is_deck else "墓地 ")+str(engine.players[who].deck.size() if is_deck else engine.players[who].grave.size())','{"deck":"牌库 ","grave":"墓地 ","exile":"除外 "}[zone_name]+str(engine.players[who][zone_name].size())',1)
p.write_text(s,'utf-8')
p=root/'scripts/duel_table.gd';s=p.read_text('utf-8').replace('const MAT_SLOTS={','const MAT_SLOTS={"exile":Vector2(1070.0/1200.0,590.0/1200.0),',1)
s=s.replace('var at=Vector3(-6.2+unit_index*2.46,0.035,1.65*side)\n    d=description(c,at,0.95); unit_index+=1','var crowded=duel.units(who).size()>6\n    var columns=maxi(6,ceili(duel.units(who).size()/2.0)) if crowded else 6\n    var at=Vector3(-6.2+(unit_index%columns)*12.3/maxi(5,columns-1),0.035,(1.05+(unit_index/columns)*1.7)*side) if crowded else Vector3(-6.2+unit_index*2.46,0.035,1.65*side)\n    d=description(c,at,0.62 if crowded else 0.95); unit_index+=1',1)
s=s.replace('update_pile("pgrave" if who==0 else "agrave",duel.players[who].grave,zone_position("grave",who),true)','update_pile("pgrave" if who==0 else "agrave",duel.players[who].grave,zone_position("grave",who),true)\n  update_pile("pexile" if who==0 else "aexile",duel.players[who].exile,zone_position("exile",who),true)',1)
p.write_text(s,'utf-8')
for name,color in [('token_ufo','#b15369'),('token_halfghost','#538e78')]:
 (root/f'assets/{name}.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1676" viewBox="0 0 1200 1676"><rect x="12" y="12" width="1176" height="1652" rx="70" fill="#162732" stroke="{color}" stroke-width="24"/><rect x="55" y="55" width="1090" height="1566" rx="48" fill="none" stroke="#e8d8a5" stroke-width="5"/><circle cx="600" cy="780" r="260" fill="{color}" opacity="0.6"/><path d="M600 360L860 780L600 1200L340 780Z" fill="none" stroke="#ecdfbe" stroke-width="18"/></svg>''','utf-8')
p=root/'scripts/main.gd';s=p.read_text('utf-8').replace('if id in ["potato","token_ufo","token_halfghost"]: return load("res://assets/potato.svg")','if id=="potato": return load("res://assets/potato.svg")\n if id in ["token_ufo","token_halfghost"]: return load("res://assets/"+id+".svg")',1);p.write_text(s,'utf-8')
