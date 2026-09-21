from pathlib import Path
R=Path(__file__).resolve().parents[1]
def patch(path,changes):
 p=R/path;s=p.read_text(encoding='utf-8-sig')
 for old,new in changes:
  assert old in s,(path,old);s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
patch('scripts/rules/duel_engine.gd',[
 (' Pack.on_attack_or_block(self,c,true)',' Pack.on_attack_or_block(self,c,true);Roster.on_attack(self,c)'),
 ('  if c.tapped: continue\n  if Extra.keyword(self,attacker','  if c.tapped: continue\n  if Roster.has(cards[attacker.card_id],"wriggle_evasion") and Pack.colors(self,c).any(func(color):return color in ["黑","绿"]):continue\n  if Extra.keyword(self,attacker'),
 ('  var retaliation=0\n  for t in combat.blockers:','  var retaliation=0;var counter_power={}\n  for r in combat.blockers:\n   var b=find_card(r.uid);counter_power[b.uid]=stat(b,"power") if deals_combat_damage(b) else 0\n  for t in combat.blockers:'),
 ('combat_hit(blocker,combat.attacker,stat(blocker,"power")) if deals_combat_damage(blocker) else 0','combat_hit(blocker,combat.attacker,counter_power[blocker.uid])'),
 ('func ai_extended_ability(who: int) -> bool:\n','func ai_extended_ability(who: int) -> bool:\n for c in players[who].field:\n  for a in available_actions(who,c.uid):\n   if a.type!="extension" or a.key not in Roster.ACTIVATIONS or usage_count(c.uid,"ai_"+a.key)>0:continue\n   if a.key in ["hatate_return","kaguya_end","clown_sweep"]:continue\n   var target=Pack.ai_target(self,who,Extra.activation_options(self,c,a.key),a.key)\n   if not target.is_empty() and commit_extension(who,c.uid,target,payment(who,Extra.activation_cost(a.key)).plan,a.key).is_empty():use_once(c.uid,"ai_"+a.key);return true\n'),
])
patch('scripts/rules/precon_abilities.gd',[
 ('has(e.cards[s.card.card_id],"silent_spark"))','(has(e.cards[s.card.card_id],"silent_spark") or e.Roster.has(e.cards[s.card.card_id],"gungnir")))'),
 ('u.plus_counters=u.get("plus_counters",0)+1','e.Roster.plus(e,u,1)'),
 ('c.plus_counters=c.get("plus_counters",0)+2','e.Roster.plus(e,c,2)'),
])
patch('scripts/duel_view.gd',[
 ('engine.commit_extension(acting_player(),local.uid,local.target,local.plan)','engine.commit_extension(acting_player(),local.uid,local.target,local.plan,local.get("key",""))'),
 ('c.zone in ["deck","grave","exile"])','c.zone in ["deck","grave","exile","hand"])'),
])
patch('scripts/main.gd',[
 (' if not Store.CARDS.has(id): return null',' if not Store.CARDS.has(id):\n  if is_instance_valid(duel_view) and duel_view.engine.cards.has(id):\n   var info=duel_view.engine.cards[id]\n   if info.has("copy_source_id"):return texture(info.copy_source_id)\n   if info.get("token",false):return load("res://assets/roster_token.svg")\n  return null'),
])
print('Integration hooks 2 complete')
