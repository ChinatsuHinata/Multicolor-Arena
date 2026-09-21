from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/rules/duel_engine.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace('func payment(who: int, cost: Dictionary) -> Dictionary:','func payment(who: int, cost: Dictionary, excluded: Array=[]) -> Dictionary:')
s=s.replace('return payment_search(source_resources(who),0,needs)','return payment_search(source_resources(who).filter(func(r): return r.uid not in excluded),0,needs)')
s=s.replace('shift(c,"field"); c.entered=turn; players[who].field.append(c)','shift(c,"field"); c.entered=turn; c.entered_turns=players[who].turns; players[who].field.append(c)')
s=s.replace('and not c.tapped and c.entered<turn','and not c.tapped and not summoning_sick(c)')
s+='''
func summoning_sick(c: Dictionary) -> bool:
 if c.is_empty() or c.zone!="field" or not is_unit(c): return false
 if c.has("entered_turns"): return c.entered_turns>=players[c.owner].turns
 return c.entered>=turn

func ability_parameters(uid: int,index: int) -> Dictionary:
 var c=find_card(uid)
 if c.is_empty(): return {}
 var bindings=cards[c.card_id].abilities
 if index<0 or index>=bindings.size(): return {}
 return bindings[index].get("参数",{})

func activation_error(who: int,uid: int,index: int) -> String:
 if winner!=-2 or phase=="mulligan" or not pending.is_empty(): return "当前不能发动"
 if priority!=who: return "等待执行权"
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who or c.zone!="field": return "需要操控该永久物"
 var bindings=cards[c.card_id].abilities
 if index<0 or index>=bindings.size() or bindings[index].get("实现")!="activated_damage": return "不是可启动的异能"
 var params=ability_parameters(uid,index)
 if params.get("横置",false):
  if c.tapped: return "已经横置"
  if summoning_sick(c): return "召唤失调"
 var excluded=[uid] if params.get("横置",false) else []
 if payment(who,params.get("费用",{}),excluded).ways==0: return "可用颜色费用不足"
 return ""

func available_actions(who: int,uid: int,include_disabled: bool=false) -> Array:
 var result=[]
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who or c.zone!="field": return result
 if is_unit(c):
  var enabled=can_attack(who,uid)
  if enabled or include_disabled:
   result.append({"type":"attack","uid":uid,"label":"攻击","enabled":enabled,"reason":"召唤失调" if summoning_sick(c) else "当前不能攻击" if not enabled else ""})
 var bindings=cards[c.card_id].abilities
 for index in range(bindings.size()):
  if bindings[index].get("实现")!="activated_damage": continue
  var error=activation_error(who,uid,index)
  if error.is_empty() or include_disabled:
   result.append({"type":"ability","uid":uid,"index":index,"label":bindings[index].get("名称","对目标造成 %d 点伤害" % bindings[index]["参数"]["数值"]),"enabled":error.is_empty(),"reason":error})
 return result

func has_response(who: int) -> bool:
 if not legal_casts(who,true).is_empty(): return true
 for c in players[who].field:
  if available_actions(who,c.uid).any(func(a): return a.type=="ability"): return true
 return false

func ability_targets() -> Array:
 var result=[{"player":0},{"player":1}]
 for who in range(2):
  for c in units(who): result.append(ref_target(c))
 return result

func commit_ability(who: int,uid: int,index: int,target: Dictionary,plan: Array) -> String:
 var error=activation_error(who,uid,index)
 if not error.is_empty(): return error
 if target not in ability_targets(): return "目标已失效"
 var params=ability_parameters(uid,index)
 if not payment_valid(who,params.get("费用",{}),plan): return "支付方案已失效"
 if params.get("横置",false) and plan.any(func(r): return r.uid==uid): return "不能重复横置同一来源"
 var c=find_card(uid)
 for reservation in plan:
  if reservation.uid<0: players[who].potato=false
  else: find_card(reservation.uid).tapped=true
 if params.get("横置",false): c.tapped=true
 stack.append({"id":next_stack,"kind":"ability","source":c.duplicate(true),"owner":who,"amount":int(params["数值"]),"target":target.duplicate(),"name":cards[c.card_id].name+" · 启动异能"})
 next_stack+=1; passes=0; priority=1-who
 note("发动 "+cards[c.card_id].name+"的异能")
 return ""
'''
f.write_text(s,encoding='utf-8')
f=p/'scripts/card_database.gd';s=f.read_text(encoding='utf-8-sig').replace('"grant_leader_abilities"]','"grant_leader_abilities","activated_damage"]',1)
marker='  var params=binding.get("参数",{})'
s=s.replace(marker,marker+'''
  if handler=="activated_damage":
   if d["类别"] not in ["单位","自机","道具","结界"]: return "启动异能需要永久物"
   if not params is Dictionary or not integer_value(params.get("数值")): return "启动伤害异能需要整数数值"
   if not params.get("费用",{}) is Dictionary or not params.get("横置",false) is bool: return "启动异能费用格式错误"
   for color in params.get("费用",{}):
    if color not in COLORS or not integer_value(params["费用"][color]): return "启动异能费用无效"
   if not params.get("横置",false) and params.get("费用",{}).values().all(func(v): return v==0): return "此实现需要横置或颜色费用"
''')
f.write_text(s,encoding='utf-8')
f=p/'scripts/main.gd';s=f.read_text(encoding='utf-8-sig').replace('if img.get_width() > 700: img.resize(700,int(float(img.get_height())*700/img.get_width()),Image.INTERPOLATE_LANCZOS)','if img.get_width() > 1200: img.resize(1200,int(float(img.get_height())*1200/img.get_width()),Image.INTERPOLATE_LANCZOS)\n if not img.has_mipmaps(): img.generate_mipmaps()');f.write_text(s,encoding='utf-8')
