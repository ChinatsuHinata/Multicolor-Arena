from pathlib import Path
import json,openpyxl
root=Path('.')
w=openpyxl.load_workbook(root/'recourse'/'极彩全牌表 - （圣版可检索）25-12-17.xlsx',read_only=True,data_only=True)
units=w['CHARACTER (单位)']; spells=w['SPELL （符卡）']
keyword_text={'annihilate':'死灭：在自己的主要阶段战斗中，在伤害判定中消灭对方单位后，同时对对方玩家造成等同于自身灵力值的战斗伤害。','brave':'英勇：攻击后的己方结束阶段开始时重置。'}
for id,rownum,handler in [('50',53,'annihilate'),('53',56,''),('54',57,'brave'),('56',59,'flash'),('57',60,'')]:
 row=list(next(units.iter_rows(min_row=rownum,max_row=rownum,values_only=True)))
 cost={c:int(row[8+i]) for i,c in enumerate(['红','蓝','绿','黄','黑']) if row[8+i]}
 ability=row[17] or '无特殊能力。'
 rules=ability+ ('\n\n'+keyword_text[handler] if handler in keyword_text else '')
 d={'格式版本':1,'卡牌ID':id,'名称':'「'+row[6]+'」','类别':'单位','颜色':list(cost),'费用':cost,'图片':f'res://recourse/demo素材/image{id}.png','完整说明':f'{row[2]}\n种族：{row[7]}\n攻击 {row[14]} / 血量 {row[15]} / 灵力 {row[16]}\n\n'+rules,'来源':f'极彩全牌表 CHARACTER (单位)!行{rownum}；demo素材/image{id}.png；CAPACITY(能力词条)图示','能力文字':rules,'构筑资格':{'允许常规构筑':True},'能力绑定':[{'实现':handler}] if handler else [],'角色名':'','称号':'','种族':[row[7]],'攻击力':int(row[14]),'血量':int(row[15]),'灵力':int(row[16])}
 if handler=='flash':d['高速']=True
 (root/'cards'/f'{id}.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for id,rownum,handler in [('96',4,'damage'),('112',20,'turn_buff')]:
 row=list(next(spells.iter_rows(min_row=rownum,max_row=rownum,values_only=True)))
 cost={c:int(row[6+i]) for i,c in enumerate(['红','蓝','绿','黄','黑']) if row[6+i]}
 rules=row[16]
 if handler=='turn_buff': rules+='\n\n疾行：可以在进入战场的回合进行攻击。'
 d={'格式版本':1,'卡牌ID':id,'名称':row[5],'类别':'符卡','颜色':list(cost),'费用':cost,'图片':f'res://recourse/demo素材/image{id}.png','完整说明':row[2]+'\n\n'+rules,'来源':f'极彩全牌表 SPELL （符卡）!行{rownum}；demo素材/image{id}.png','能力文字':rules,'构筑资格':{'允许常规构筑':True},'高速':True,'能力绑定':[{'实现':handler,'参数':{'数值':2} if handler=='damage' else {'攻击力':2,'血量':0,'灵力':1,'疾行':True}}]}
 (root/'cards'/f'{id}.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
w.close()
def edit(rel,old,new):
 p=root/rel;s=p.read_text(encoding='utf-8');assert old in s,(rel,old[:80]);p.write_text(s.replace(old,new),encoding='utf-8')
edit('scripts/card_database.gd','const IDS=["68","70","99","100","164","165","167","170"]','const IDS=["50","53","54","56","57","68","70","96","99","100","112","164","165","167","170"]')
edit('scripts/card_database.gd','"activated_damage"]','"activated_damage","annihilate","flash","turn_buff"]')
edit('scripts/card_database.gd','["marisa_enter","marisa_spell","brave","exterminate"]','["marisa_enter","marisa_spell","brave","exterminate","annihilate","flash"]')
edit('scripts/card_database.gd','["damage","counter_card"]','["damage","counter_card","turn_buff"]')
edit('scripts/card_database.gd','  if handler=="activated_damage":','''  if handler=="turn_buff":
   if not params is Dictionary: return "临时强化需要参数"
   for stat in ["攻击力","血量","灵力"]:
    if not integer_value(params.get(stat,0)): return "临时强化数值必须是非负整数"
   if not params.get("疾行",false) is bool: return "疾行必须为true或false"
  if handler=="activated_damage":''')
edit('scripts/rules/demo_abilities.gd','# Only the eight registered demo cards are supported in this ruleset.','# Explicit handlers for the registered card pool; text alone never executes effects.')
edit('scripts/rules/demo_abilities.gd','   "counter_card": engine.counter_entry(int(entry.target.get("stack_id",-1)))','   "counter_card": engine.counter_entry(int(entry.target.get("stack_id",-1)))\n   "turn_buff": engine.apply_turn_buff(entry.target,binding["参数"])')
p='scripts/rules/duel_engine.gd'
edit(p,'c.timer=0; c.attacked=false','c.timer=0; c.attacked=false; c.modifiers=[]')
edit(p,' elif DB.has_ability(cards[id],"damage"):', ''' elif DB.has_ability(cards[id],"turn_buff"):
  for who in range(2):
   for c in units(who): targets.append(ref_target(c))
 elif DB.has_ability(cards[id],"damage"):''')
edit(p,'func judge():','''func stat(c: Dictionary,key: String) -> int:
 var value=int(cards[c.card_id][key])
 var fields={"power":"攻击力","health":"血量","spirit":"灵力"}
 for modifier in c.get("modifiers",[]): value+=int(modifier.get(fields[key],0))
 return maxi(0,value)
func has_haste(c: Dictionary) -> bool:
 return c.get("modifiers",[]).any(func(m): return m.get("疾行",false))
func apply_turn_buff(target: Dictionary,params: Dictionary):
 if not target_valid(target,true): return
 var c=find_card(target.uid)
 if not c.has("modifiers"): c.modifiers=[]
 c.modifiers.append(params.duplicate(true))
func judge():''')
edit(p,'c.damage>=cards[c.card_id].health','c.damage>=stat(c,"health")')
edit(p,'for c in p.field: c.damage=0','for c in p.field: c.damage=0; c.modifiers=[]')
edit(p,'and not c.tapped and not summoning_sick(c)','and not c.tapped and (not summoning_sick(c) or has_haste(c))')
edit(p,'cards[find_card(combat.attacker.uid).card_id].power','stat(find_card(combat.attacker.uid),"power")')
edit(p,'var power=cards[attacker.card_id].power','var power=stat(attacker,"power")')
edit(p,'players[1-combat.owner].life-=cards[attacker.card_id].spirit','players[1-combat.owner].life-=stat(attacker,"spirit")')
edit(p,'   retaliation+=cards[blocker.card_id].power','   retaliation+=stat(blocker,"power")')
edit(p,'  attacker.damage+=retaliation','''  attacker.damage+=retaliation
  if active==combat.owner and phase=="main" and DB.has_ability(cards[attacker.card_id],"annihilate"):
   if combat.blockers.any(func(t): return find_card(t.uid).damage>=stat(find_card(t.uid),"health")):
    players[1-combat.owner].life-=stat(attacker,"spirit")
    note("死灭造成 %d 点战斗伤害" % stat(attacker,"spirit"))''')
edit(p,'cards[c.card_id].health-c.damage','stat(c,"health")-c.damage')
# Buffs and generic fast damage/flash units get explicit AI decisions instead of invalid target stalls.
edit(p,'  pass_priority(who); return\n if active==who', '  if ai_fast_action(who,choices): return\n  pass_priority(who); return\n if active==who')
edit(p,'''   var target={}
   if DB.has_ability(cards[c.card_id],"damage"):
    target={"player":opponent}
    var enemy=units(opponent)
    if players[opponent].life>5 and not enemy.is_empty(): target=ref_target(enemy[0])
   commit_cast(who,c.uid,target,payment(who,cards[c.card_id].cost).plan); return''','''   var target=ai_spell_target(who,c)
   if cards[c.card_id].kind=="符卡" and target.is_empty(): continue
   if commit_cast(who,c.uid,target,payment(who,cards[c.card_id].cost).plan).is_empty(): return''')
edit(p,' pass_priority(who)\nfunc ai_card_score',' if ai_fast_action(who,choices): return\n pass_priority(who)\nfunc ai_card_score')
edit(p,'func ai_card_score(c: Dictionary) -> int:','''func ai_spell_target(who: int,c: Dictionary) -> Dictionary:
 var info=cards[c.card_id]
 if DB.has_ability(info,"damage"):
  var amount=int(DB.ability(info,"damage")["数值"])
  if players[1-who].life<=amount: return {"player":1-who}
  var enemies=units(1-who)
  for enemy in enemies:
   if stat(enemy,"health")-enemy.damage<=amount: return ref_target(enemy)
  if not enemies.is_empty(): return ref_target(enemies[0])
  return {"player":1-who}
 if DB.has_ability(info,"turn_buff"):
  for unit in units(who):
   if not combat.is_empty() and (combat.attacker.uid==unit.uid or combat.blockers.any(func(t): return t.uid==unit.uid)): return ref_target(unit)
  for unit in units(who):
   if not unit.tapped: return ref_target(unit)
 return {}
func ai_fast_action(who: int,choices: Array) -> bool:
 for c in choices:
  var info=cards[c.card_id]
  if not info.fast: continue
  var target={}
  if DB.has_ability(info,"damage"):
   var amount=int(DB.ability(info,"damage")["数值"])
   if players[1-who].life<=amount: target={"player":1-who}
   else:
    for enemy in units(1-who):
     if stat(enemy,"health")-enemy.damage<=amount: target=ref_target(enemy); break
   if target.is_empty(): continue
  elif DB.has_ability(info,"turn_buff"):
   if combat.is_empty(): continue
   target=ai_spell_target(who,c)
   if target.is_empty(): continue
  elif is_unit(c):
   if combat.is_empty() or combat.owner==who or combat.step!="attack_window": continue
  else: continue
  if commit_cast(who,c.uid,target,payment(who,info.cost).plan).is_empty(): return true
 return false
func ai_card_score(c: Dictionary) -> int:''')
# Keep earlier eight-card strategy stable outside the new general spells.
edit(p,'  var amount=int(DB.ability(info,"damage")["数值"])\n  if players', '  var amount=int(DB.ability(info,"damage")["数值"])\n  if c.card_id=="99":\n   return ref_target(units(1-who)[0]) if players[1-who].life>5 and not units(1-who).is_empty() else {"player":1-who}\n  if players')
# Plain names for ordinary units never take the unique-title check.
edit(p,'if units(who).any(func(u): return cards[u.card_id].title==info.title): continue','if not info.title.is_empty() and units(who).any(func(u): return cards[u.card_id].title==info.title): continue')
edit(p,'if info.colors.any(func(color): return color not in colors): continue','if info.kind=="自机" and info.colors.any(func(color): return color not in colors): continue')
print('v0.7 database and rule updates written')
