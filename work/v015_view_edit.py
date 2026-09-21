from pathlib import Path
def edit(n,a,b):
 p=Path(n);s=p.read_text('utf-8');assert a in s,(n,a[:70]);p.write_text(s.replace(a,b),encoding='utf-8')
v='scripts/duel_view.gd';e='scripts/rules/duel_engine.gd'
edit(e,'func cast_cost(who: int,c: Dictionary,target: Dictionary={}) -> Dictionary:', '''func offers_free_cast(who: int,c: Dictionary) -> bool:
 if c.is_empty():return false
 var previous=paid_cast_uid;paid_cast_uid=-1
 var offered=Roster.free_cast(self,c,who) or c.zone=="exile" and c.get("free_exile_owner",-1)==who
 paid_cast_uid=previous
 return offered and cards[c.card_id].cost.values().any(func(n):return n>0)
func set_granted_payment(pay_colors: bool):
 if pending.get("kind","")!="effect_choice" or pending.trigger.effect!="cat:grant":return
 var t=pending.trigger;var c=find_card(t.data.ref.uid)
 if c.is_empty():return
 paid_cast_uid=c.uid if pay_colors else -1
 var previous=forced_cast.duplicate(true)
 forced_cast={"owner":t.owner,"uid":c.uid,"free":t.data.free,"cost":t.data.cost,"ignore":false}
 pending.options=targets_for(c.card_id,t.owner,c.uid)
 forced_cast=previous
 t.data.payment_chosen=true
 revision+=1
func cast_cost(who: int,c: Dictionary,target: Dictionary={}) -> Dictionary:''')
# Preference survives through actual grant commit then is reset; cancelling is private.
edit(e,'  revision+=1; pump_choices()','  revision+=1; pump_choices()') if False else None
edit(e,'func cancel_cast', 'func cancel_cast') if False else None
edit(v,'func render():\n if not is_instance_valid(ui): return','''func render():
 if not is_instance_valid(ui): return
 # Finish damage/collision display before showing subsequent zone changes.
 if table.combat_animating:return
 if engine.combat.get("damage_batch",0)>0 and engine.combat.damage_batch!=table.last_damage_batch and table.visuals.has("card_"+str(engine.combat.attacker.uid)):
  table.sync();return''')
edit(v,' render_hands(available)\n rebuild_badges()',' render_hands(available)\n table.presented_moves.clear()\n rebuild_badges()')
edit(v,'  var node=nodes[uid]; nodes.erase(uid)\n','  var node=nodes[uid]; nodes.erase(uid)\n  if table.presented_moves.has(uid):node.queue_free();continue\n')
edit(v,'  node.update_style(c.uid in available','  node.show()\n  if table.presented_moves.has(c.uid):\n   node.position=target;node.modulate.a=1;node.set_meta("target",target);fresh=false\n  node.update_style(c.uid in available')
edit(v,'  if local.mode=="target": render_inline_picker(confirm_declaration)','''  if local.mode=="free_offer":
   btn("不支付颜色使用",Rect2(1330,690,237,49),func(): choose_cast_payment(false),true)
   btn("支付颜色使用",Rect2(1330,752,237,49),func(): choose_cast_payment(true))
  elif local.mode=="target": render_inline_picker(confirm_declaration)''')
edit(v,'    "effect_choice":\n     render_inline_picker(confirm_trigger,engine.pending.trigger.optional)\n     if engine.pending.trigger.optional: optional_trigger_prompt()','''    "effect_choice":
     var t=engine.pending.trigger
     if t.effect=="cat:grant" and t.data.get("free",false) and not t.data.get("payment_chosen",false):
      text="是否支付颜色使用？"
      btn("不支付颜色使用",Rect2(1330,675,237,49),func(): engine.set_granted_payment(false);picker.reset();render(),true)
      btn("支付颜色使用",Rect2(1330,736,237,49),func(): engine.set_granted_payment(true);picker.reset();render())
      btn("不使用",Rect2(1330,803,237,43),decline_trigger)
     else:
      render_inline_picker(confirm_trigger,t.optional)
      if t.optional: optional_trigger_prompt()''')
edit(v,'     text="计时指示物"','     text=engine.pending.change.get("source_name","")+" · 计时替代"')
edit(v,' if local.mode=="target": return engine.cards',' if local.mode=="free_offer":return "是否支付颜色使用？"\n if local.mode=="target": return engine.cards')
edit(v,'  local={}; selection=[]; message=""; drag_uid=0; dragging=false','  engine.paid_cast_uid=-1\n  local={}; selection=[]; message=""; drag_uid=0; dragging=false')
edit(v,'  local={"uid":uid,"target":{},"plan":[],"mode":"target"}','  local={"uid":uid,"target":{},"plan":[],"mode":"target"}') if False else None
edit(v,' local={"uid":uid,"target":{},"plan":[],"mode":"target"}',' engine.paid_cast_uid=-1\n local={"uid":uid,"target":{},"plan":[],"mode":"free_offer" if engine.offers_free_cast(acting_player(),engine.find_card(uid)) else "target"}')
edit(v,'func choose_target(target: Dictionary):','''func choose_cast_payment(pay_colors: bool):
 if local.get("mode","")!="free_offer":return
 engine.paid_cast_uid=local.uid if pay_colors else -1
 local.mode="target";local.target={};local.plan=[]
 picker.reset();render()
func choose_target(target: Dictionary):''')
edit(v,'  local={};engine.choose_effect(paid_target);picker.reset();selection=[];render();return','  local={};engine.choose_effect(paid_target);engine.paid_cast_uid=-1;picker.reset();selection=[];render();return')
edit(v,' if error.is_empty(): local={}; selection=[]; picker.reset(); message=""; close_debug()',' if error.is_empty(): engine.paid_cast_uid=-1;local={}; selection=[]; picker.reset(); message=""; close_debug()')
edit(v,'func cancel_cast():\n local={};','func cancel_cast():\n engine.paid_cast_uid=-1\n local={};')
edit(v,' var options=engine.pending.options if engine.pending.kind=="effect_choice" else (engine.units(0)+engine.units(1)).map(func(c): return engine.ref_target(c))',' var options=engine.pending.options')
edit(v,'func decline_trigger():\n if observing','func decline_trigger():\n engine.paid_cast_uid=-1\n if observing')
t='scripts/duel_table.gd'
edit(t,'var old_cards={}','var old_cards={}\nvar presented_moves={}')
edit(t,'  var node=visuals[key]\n  var prev=','  var node=visuals[key]\n  node.show()\n  var prev=')
edit(t,'   move_card(key,node,d,animate)','   move_card(key,node,d,animate and not presented_moves.has(d.uid))')
edit(t,'  if animate:\n   var c=now.get(d.uid,{})','  if animate and not presented_moves.has(d.uid):\n   var c=now.get(d.uid,{})')
# Fixtures reset queued initial draws; actual game still animates them.
edit('tests/test_v09_rules.gd',' e.phase="main"; e.active=0;',' e.presentation_events.clear()\n e.phase="main"; e.active=0;')
edit('tests/test_v092.gd',' e.phase="main"; e.turn=6;',' e.presentation_events.clear();view.reveal_player.reset()\n e.phase="main"; e.turn=6;')
print('view edited')
