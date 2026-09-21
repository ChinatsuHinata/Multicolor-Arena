from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def edit(path,old,new):
 p=root/path;s=p.read_text(encoding='utf-8-sig')
 assert old in s,(path,old[:120])
 p.write_text(s.replace(old,new),encoding='utf-8')
def card(id,**values):
 p=root/'cards'/f'{id}.json';d=json.loads(p.read_text(encoding='utf-8-sig'));d.update(values)
 d['修订裁定']='2026-09-21 玩家测试勘误'
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for id,colors,cost in [
 ('character-mar-023',['红','蓝'],{'红':1,'蓝':1}),
 ('character-fdn-026',['蓝','绿','黑'],{'蓝':1,'绿':1,'黑':1}),
 ('spell-fdf-021',['绿','黑'],{'绿':1,'黑':1}),
 ('spell-fdf-036',['蓝','黄'],{'蓝':2,'黄':2}),
 ('spell-fdn-010',['红','蓝','绿'],{'红':3,'蓝':2,'绿':1}),
 ('character-fdf-117',['红','蓝','绿','黑'],{'红/蓝/绿':4,'黑':1})]:card(id,颜色=colors,费用=cost)
card('90',灵力=2)
card('79',高速=True)
card('spell-rec-056',名称='塞符「天上天下的照国」',同卡异版='spell-kmo-003',别名=['塞符「天上天下ノ照国」'])
for id in ['character-rei-026','character-smm07']:
 p=root/'cards'/f'{id}.json';d=json.loads(p.read_text(encoding='utf-8-sig'))
 for field in ['完整说明','能力文字']:d[field]=d[field].replace('该能力每位玩家一局游戏只能使用一次','该能力每个单位一局游戏只能使用一次')
 for a in d['能力绑定']:a['名称']=a.get('名称','').replace('该能力每位玩家一局游戏只能使用一次','该能力每个单位一局游戏只能使用一次')
 card(id,**d)
edit('scripts/card_database.gd','"aliases":d.get("别名",[])','"canonical_id":d.get("同卡异版",id),"aliases":d.get("别名",[])')
edit('scripts/main.gd','if not info.constructible: continue','if not info.constructible or info.get("canonical_id",id)!=id: continue')
edit('scripts/rules/excel_abilities.gd','return (has(e.cards[c.card_id],"kogasa_flash")','return (Cat.enabled(e,c,"character-fdn-036:self")) or (has(e.cards[c.card_id],"kogasa_flash")')
edit('scripts/rules/duel_engine.gd','   for color in info.colors:\n    if color not in provided: return "战场永久物尚未满足自机颜色约束"','   var requirements=info.cost.keys() if info.cost.keys().any(func(k):return "/" in k) else info.colors\n   for requirement in requirements:\n    if not Array(str(requirement).split("/")).any(func(color):return color in provided): return "战场永久物尚未满足自机颜色约束"')
edit('scripts/rules/excel_abilities.gd','e.players[c.owner].get("sanae_used",false)','c.get("sanae_used",false)')
edit('scripts/rules/excel_abilities.gd','if k=="sanae_search":e.players[c.owner].sanae_used=true','if k=="sanae_search":c.sanae_used=true')
edit('scripts/rules/duel_engine.gd','"locked_name","rank_target"','"sanae_used","brave_attack_turn","locked_name","rank_target"')
edit('scripts/rules/duel_engine.gd','  c.return_death_observers=return_death_observers','  c.owner=c.get("original_owner",c.owner)\n  c.return_death_observers=return_death_observers')
edit('scripts/rules/duel_engine.gd',' tap_card(c); c.attacked=true',' c.brave_attack_turn=turn if DB.has_ability(cards[c.card_id],"brave") or Extra.keyword(self,c,"英勇") else -1\n tap_card(c); c.attacked=true')
edit('scripts/rules/duel_engine.gd','    if c.attacked and (DB.has_ability(cards[c.card_id],"brave") or Extra.keyword(self,c,"英勇")) and not Pack.response_locked(self):\n     Cat.enqueue(self,{"source":c.duplicate(true),"owner":active,"effect":"untap","optional":false,"name":cards[c.card_id].name+" · 英勇"})','    if c.get("brave_attack_turn",-1)==turn and (DB.has_ability(cards[c.card_id],"brave") or Extra.keyword(self,c,"英勇")) and Roster.reset_allowed(self,c):\n     c.tapped=false\n     note(cards[c.card_id].name+" · 英勇重置",history_art(c))')
edit('scripts/rules/catalogue_units.gd','if u.zone=="field":C.buff(e,u,0,0,0,["疾行"]);C.delay(e,u)','if u.zone=="field":\n     C.buff(e,u,0,0,0,["疾行"]);C.delay(e,u);e.delayed.back().expires_turn=e.turn')
edit('scripts/rules/excel_abilities.gd',' # Finishing immediately skips end-step events but still performs cleanup/discard.',' # The jade branch sacrifice is consumed by this skipped end step.\n e.delayed=e.delayed.filter(func(d):return int(d.get("expires_turn",2147483647))>e.turn)\n # Finishing immediately skips end-step events but still performs cleanup/discard.')
edit('scripts/rules/excel_abilities.gd','  "reset_four":options=pick(e,e.Pack.zone(e,who,"palette"),0,4,"重置至多四张颜色盘中的牌",k)','  "reset_four":options=e.Pack.none()')
edit('scripts/rules/excel_abilities.gd','  "reset_four":\n   for r in e.Pack.picked(t):\n    if valid(e,r):e.find_card(r.uid).tapped=false','  "reset_four":\n   continue_choice(e,entry,"reset_four_choose",pick(e,e.Pack.zone(e,who,"palette"),0,4,"重置至多四张颜色盘中的牌"))')
edit('scripts/rules/excel_abilities.gd',' match t.effect:\n  "coin_damage":',' match t.effect:\n  "coin_damage":') # assert location, actual continuation below
edit('scripts/rules/excel_abilities.gd','static func resolve_trigger(e,t: Dictionary):','static func resolve_trigger(e,t: Dictionary):\n if t.effect=="reset_four_choose":\n  for r in e.Pack.picked(t.target):\n   if valid(e,r) and e.find_card(r.uid).zone=="palette":e.find_card(r.uid).tapped=false\n  return')
edit('scripts/rules/catalogue_abilities.gd',' var who=t.owner;var c=t.source\n',' var who=t.owner;var c=t.source\n if e.stack.any(func(s):return s.kind=="card" and s.owner!=who and e.Roster.has(e.cards[s.card.card_id],"gungnir")):return\n if t.get("effect","")=="field-ucs-064":\n  var entering=e.find_card(t.data.ref.uid)\n  if not entering.is_empty():\n   t.ability_text="由 "+e.cards[entering.card_id].name+" 进场触发：\\n"+t.get("ability_text","")\n   t.name+=" · "+e.cards[entering.card_id].name\n')
edit('scripts/rules/precon_abilities.gd','"zone":"exile"})\nstatic func token','"zone":"exile","source":c.duplicate(true)})\nstatic func token')
edit('scripts/rules/duel_engine.gd','  Extra.event(self,source,"token_sacrifice" if d.effect=="token_sacrifice" else "delayed_return",false,d)','  var effect="token_sacrifice" if d.effect=="token_sacrifice" else "delayed_return"\n  Extra.event(self,source,effect,false,d)\n  if effect=="delayed_return" and not triggers.is_empty():\n   triggers.back().ability_text="将 "+cards[c.card_id].name+" 在拥有者操控下移回战场。"')
# Extended delayed triggers are abilities already; target_valid must accept ALL stack objects.
edit('scripts/rules/duel_engine.gd','if e.id==target.stack_id and e.kind=="card": return true','if e.id==target.stack_id: return true')
edit('scripts/rules/mask_abilities.gd',' e.enter_field(e.make_card(id,entry.owner,"token"),entry.owner);e.move_to(entry.card,"grave")',' e.enter_field(e.make_card(id,entry.owner,"token"),entry.owner)\n var info=e.cards[entry.card.card_id]\n if "时符" in info.get("spell_type","") or "乐章" in info.get("spell_type",""):\n  e.enter_field(entry.card,entry.owner)\n else:e.move_to(entry.card,"grave")')
edit('scripts/rules/catalogue_abilities.gd','static func copy_token(e,who,template):','static func copy_token(e,who,template,copy_counters=false):')
edit('scripts/rules/catalogue_abilities.gd',' var c=e.make_card(id,who,"token");return c if e.enter_field(c,who) else {}',' var c=e.make_card(id,who,"token")\n if not e.enter_field(c,who):return {}\n if copy_counters:c.plus_counters=int(template.get("plus_counters",0))\n return c')
edit('scripts/rules/catalogue_units.gd','"character-fdn-006":C.copy_token(e,who,t.source)','"character-fdn-006":C.copy_token(e,who,c if same else t.source,true)')
edit('scripts/rules/expanded_abilities.gd','    e.Effects.spell_used(e,who)\n\nstatic func spell_resolve','    e.Roster.on_cast(e,c,who,"hand")\n    e.Pack.on_cast(e,c,who,{"none":true})\n    if e.cards[c.card_id].kind=="符卡":e.Effects.spell_used(e,who)\n\nstatic func spell_resolve')
edit('scripts/rules/duel_engine.gd','func judge():\n Cat.State.state_checks(self)','var judging=false\nfunc judge():\n if judging or players.size()!=2 or winner!=-2:return\n judging=true\n Cat.State.state_checks(self)')
edit('scripts/rules/duel_engine.gd',' for batch in range(64):\n  var dying=',' for batch in range(64):\n  Cat.State.state_checks(self);Pack.state_checks(self)\n  var dying=')
edit('scripts/rules/duel_engine.gd',' elif dead.size()==1: lose(dead[0],"生命归零")',' elif dead.size()==1: lose(dead[0],"生命归零")\n judging=false')
edit('scripts/rules/duel_engine.gd','func pump_choices():\n if not pending','func pump_choices():\n judge()\n if not pending')
# Before publishing a cast the costs may have removed counters / continuous support.
edit('scripts/rules/duel_engine.gd',' if info.kind=="符卡": Effects.spell_used(self,who)\n pump_choices()',' if info.kind=="符卡": Effects.spell_used(self,who)\n judge();pump_choices()')
print('rule/data patch complete')
