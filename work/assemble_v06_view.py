from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
old=(p/'work/v06-backup/duel_view.gd').read_text(encoding='utf-8-sig')
top=(p/'work/v06_view_top.txt').read_text(encoding='utf-8-sig')
prompt=old[old.index('func local_prompt()'):old.index('func hand_clicked(')]
prompt=prompt.replace('var cost=engine.cards[engine.find_card(local.uid).card_id].cost','var cost=local_cost()')
bottom=old[old.index('func request_cast('):]
bottom=bottom.replace('if target not in engine.targets_for(engine.find_card(local.uid).card_id):','if target not in local_targets():')
bottom=bottom.replace('var solution=engine.payment(0,engine.cards[c.card_id].cost)','var excluded=[local.uid] if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false) else []\n var solution=engine.payment(0,local_cost(),excluded)')
bottom=bottom.replace('if auto_pay and (solution.ways==1 or engine.cards[c.card_id].kind!="符卡"):','if auto_pay and (solution.ways==1 or (local.get("action","")!="ability" and engine.cards[c.card_id].kind!="符卡")):')
bottom=bottom.replace('var sources=engine.source_resources(0)','var sources=payment_sources()')
bottom=bottom.replace('var cost=engine.cards[engine.find_card(local.uid).card_id].cost','var cost=local_cost()')
bottom=bottom.replace(' var error=engine.commit_cast(0,local.uid,local.target,local.plan)',' var error=engine.commit_ability(0,local.uid,local.index,local.target,local.plan) if local.get("action","")=="ability" else engine.commit_cast(0,local.uid,local.target,local.plan)')
bottom=bottom.replace(' modal=true\n if is_instance_valid(modal_root):\n  modal_root.get_parent().remove_child(modal_root); modal_root.queue_free()',' close_overlay()\n modal=true')
extra='''func local_cost() -> Dictionary:
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
'''
(p/'scripts/duel_view.gd').write_text(top+'\n'+prompt+'\n'+extra+'\n'+bottom,encoding='utf-8')
