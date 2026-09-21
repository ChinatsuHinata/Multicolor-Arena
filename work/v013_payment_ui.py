from pathlib import Path
R=Path.cwd()
def edit(p,f):
 p=R/p;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
def view(s):
 s=s.replace('if local.get("action","") in ["attack","direct_attack"]: return engine.attack_cost','if local.get("action","")=="choice_payment": return local.choice_cost\n if local.get("action","") in ["attack","direct_attack"]: return engine.attack_cost')
 s=s.replace(' if local.get("action","") in ["attack","direct_attack"]:\n  engine.attack',' if local.get("action","")=="choice_payment":\n  var paid_target=local.target.duplicate(true);paid_target.payment=local.plan.duplicate(true)\n  if not engine.payment_valid(acting_player(),local.choice_cost,local.plan):message="支付方案已失效";render();return\n  local={};engine.choose_effect(paid_target);picker.reset();selection=[];render();return\n if local.get("action","") in ["attack","direct_attack"]:\n  engine.attack')
 s=s.replace(' if engine.pending.kind=="effect_choice": engine.choose_effect(target)',' if engine.pending.kind=="effect_choice" and engine.pending.trigger.effect in ["cat:grant","cat:trigger_pay"] and (engine.pending.trigger.effect=="cat:grant" or target.get("pay",false)):\n  var t=engine.pending.trigger;var cost=engine.Cat.granted_cost(engine,t,target) if t.effect=="cat:grant" else t.data.cost\n  local={"uid":t.source.uid,"action":"choice_payment","choice_cost":cost,"target":target,"mode":"payment","plan":[]}\n  start_payment();return\n if engine.pending.kind=="effect_choice": engine.choose_effect(target)')
 s=s.replace('  if options.size()>16:\n   search=', '  if options.size()>16:\n   scroll.position.y=350;scroll.size.y=437\n   search=')
 return s
edit('scripts/duel_view.gd',view)
def engine(s):
 old=' if not target.is_empty() and not Pack.choice_valid(self,pending.options,target): return\n if t.get("continuation",false):'
 new=' var checked_target=target.duplicate(true);checked_target.erase("payment")\n if not target.is_empty() and not Pack.choice_valid(self,pending.options,checked_target): return\n if target.has("payment"):\n  var cost=Cat.granted_cost(self,t,target) if t.effect=="cat:grant" else t.data.get("cost",{})\n  if not payment_valid(t.owner,cost,target.payment):return\n if t.get("continuation",false):'
 assert old in s;s=s.replace(old,new)
 return s
edit('scripts/rules/duel_engine.gd',engine)
edit('scripts/rules/catalogue_units.gd',lambda s:s.replace('var plan=e.payment(who,d.cost)\n    if plan.ways>0:\n     C.pay(e,who,plan.plan)','var plan=a.get("payment",e.payment(who,d.cost).plan)\n    if e.payment_valid(who,d.cost,plan):\n     C.pay(e,who,plan)'))
edit('scripts/rules/catalogue_spells.gd',lambda s:s.replace('var plan=e.payment(who,e.cast_cost(who,u,a))\n    if plan.ways>0:e.commit_cast(who,u.uid,a,plan.plan)','var plan=a.get("payment",e.payment(who,e.cast_cost(who,u,a)).plan);a.erase("payment")\n    if e.payment_valid(who,e.cast_cost(who,u,a),plan):e.commit_cast(who,u.uid,a,plan)'))
def cat(s):
 s=s.replace(' var error=e.cast_error(who,c.uid);e.forced_cast={}',' var old_priority=e.priority;e.priority=who\n var error=e.cast_error(who,c.uid);e.forced_cast={};e.priority=old_priority')
 s+='''
static func granted_cost(e,t,target):
 var previous=e.forced_cast.duplicate(true);var c=e.find_card(t.data.ref.uid)
 if c.is_empty():return {}
 e.forced_cast={"owner":t.owner,"uid":c.uid,"free":t.data.free,"cost":t.data.cost,"ignore":false}
 var cost=e.cast_cost(t.owner,c,target);e.forced_cast=previous;return cost
'''
 return s
edit('scripts/rules/catalogue_abilities.gd',cat)
