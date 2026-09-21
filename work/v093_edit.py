from pathlib import Path
p=Path('scripts/duel_view.gd'); s=p.read_text(encoding='utf-8')
def replace(a,b):
 global s
 assert a in s,a[:100]
 s=s.replace(a,b,1)
def function(name,new):
 global s
 start=s.index('func '+name+'('); end=s.find('\nfunc ',start+1)
 if end<0:end=len(s)
 s=s[:start]+new.rstrip()+'\n'+s[end:]
replace('var local: Dictionary={}','var picker=preload("res://scripts/target_picker.gd").new()\nvar life_widgets={}\nvar arrow_layer: Control\nvar local: Dictionary={}')
replace('ui=layer(self); badges=layer(ui)','ui=layer(self); badges=layer(ui)\n arrow_layer=preload("res://scripts/stack_arrows.gd").new(); arrow_layer.view=self; arrow_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(arrow_layer)')
replace('last_revision=engine.revision\n var available=highlights()','last_revision=engine.revision\n sync_picker()\n var available=highlights()\n table.targetable_stacks=picker.available_refs().filter(func(t): return t.has("stack_id")).map(func(t): return t.stack_id)\n table.selected_stacks=picker.selected_refs().filter(func(t): return t.has("stack_id")).map(func(t): return t.stack_id)')
replace('btn("人机  %d" % engine.players[1].life,Rect2(1350,92,214,45),func(): choose_target({"player":1}))\n btn("你  %d" % engine.players[0].life,Rect2(27,785,243,58),func(): choose_target({"player":0}))','life_widgets={}\n render_life(1,Rect2(1350,80,214,61))\n render_life(0,Rect2(27,781,243,70))')
# All target outlines derive from the same legal inline choice step.
replace('else:\n   for target in local_targets():\n    if target.has("uid"): result.append(target.uid)','elif local.mode=="target":\n   for target in picker.available_refs():\n    if target.has("uid"): result.append(target.uid)')
replace('if engine.pending.kind=="trigger": return (engine.units(0)+engine.units(1)).map(func(c): return c.uid)\n  if engine.pending.kind=="effect_choice": return engine.pending.options.filter(func(t): return t.has("uid")).map(func(t): return t.uid)','if engine.pending.kind in ["trigger","effect_choice"]: return picker.available_refs().filter(func(t): return t.has("uid")).map(func(t): return t.uid)')
replace('  btn("取消使用",Rect2(1330,680,237,45),cancel_cast)\n  if local.mode=="target":\n   btn("选择目标",Rect2(1330,745,237,50),open_local_choices,true)','  if local.mode=="target": render_inline_picker(confirm_declaration)\n  elif local.mode=="payment_offer":\n   btn("自动支付",Rect2(1330,690,237,49),pay_automatically,true)\n   btn("手动支付",Rect2(1330,752,237,49),func(): local.mode="payment"; render())\n  elif local.mode=="payment_color":\n   for i in range(local.colors.size()):\n    var color=local.colors[i]\n    btn(color,Rect2(1330+(i%2)*120,676+(i/2)*49,112,43),func(): local.plan.append({"uid":local.resource,"color":color}); local.mode="payment"; render(),true)\n  if local.mode!="target": btn("取消使用",Rect2(1330,833,237,43),cancel_cast)')
replace('btn("确认支付",Rect2(1330,738,237,50),commit_local,true)','btn("确认支付",Rect2(1330,689,237,50),commit_local,true)')
replace('btn("重选费用",Rect2(1330,805,237,43)','btn("重选费用",Rect2(1330,761,237,43)')
replace('btn("选择",Rect2(1330,735,237,52),open_effect_choices,true)\n    if engine.pending.trigger.optional: btn("不使用",Rect2(1330,803,237,45),func(): engine.choose_effect({}); render())','render_inline_picker(confirm_trigger,engine.pending.trigger.optional)')
replace('btn("不使用能力",Rect2(1330,770,237,55),func(): engine.choose_trigger({}); selection=[]; render())','render_inline_picker(confirm_trigger,true)')
replace(' if action_menu_open and not observing and event is InputEventMouseButton',' if not observing and drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:\n  if not local.is_empty(): cancel_cast()\n  elif picker_active() and not picker.path.is_empty(): picker.path=[]; picker.normalize(); render()\n if action_menu_open and not observing and event is InputEventMouseButton')
replace('if response_disabled(): return\n message=""\n if engine.phase=="mulligan"','if response_disabled(): return\n message=""\n if picker_active():\n  var c=engine.find_card(uid)\n  if not c.is_empty(): choose_target(engine.ref_target(c))\n  return\n if engine.phase=="mulligan"')
replace('elif not local.is_empty(): cancel_cast()\n elif engine.pending.get','elif not local.is_empty(): cancel_cast()\n elif picker_active(): picker.path=[]; picker.normalize(); render()\n elif engine.pending.get')
replace('if local.mode=="payment": reserve_resource(uid)\n  else:','if local.mode=="payment": reserve_resource(uid)\n  elif local.mode=="target":')
replace('if local_targets()==[{"none":true}]: local.target={"none":true}; start_payment()\n  else: render(); open_local_choices()','picker.reset(); render()')
replace('local={"uid":action.uid,"action":"ability","index":action.index,"mode":"target","target":{},"plan":[]}\n  render()','local={"uid":action.uid,"action":"ability","index":action.index,"mode":"target","target":{},"plan":[]}\n  picker.reset(); render()')
replace('if local.mode=="target": return "选择目标："+engine.cards[engine.find_card(local.uid).card_id].name','if local.mode=="target": return engine.cards[engine.find_card(local.uid).card_id].name\n if local.mode=="payment_offer": return "自动选择费用？"\n if local.mode=="payment_color": return "选择颜色"')
function('request_cast','''func request_cast(uid: int):
 if observing or table.combat_animating or response_disabled(): return
 clear_attack_preview()
 var error=engine.cast_error(acting_player(),uid)
 if not error.is_empty(): message=error; render(); return
 local={"uid":uid,"target":{},"plan":[],"mode":"target"}
 picker.reset(); selection=[]; message=""; render()''')
function('choose_target','''func choose_target(target: Dictionary):
 if observing or table.combat_animating or not picker_active(): return
 sync_picker()
 if picker.select_target(target):
  if not local.is_empty(): local.target=picker.option()
  message=""; render()''')
function('start_payment','''func start_payment():
 if local.is_empty(): return
 var c=engine.find_card(local.uid)
 var excluded=[local.uid] if local.get("action","")=="ability" and engine.ability_parameters(local.uid,local.index).get("横置",false) else []
 var solution=engine.payment(acting_player(),local_cost(),excluded)
 if solution.ways==0: message="可用颜色费用不足"; render(); return
 local.mode="payment"
 if local_cost().values().all(func(n): return n==0) or (auto_pay and (solution.ways==1 or (local.get("action","")=="" and engine.cards[c.card_id].kind!="符卡"))):
  local.plan=solution.plan; commit_local(); return
 if auto_pay: local.mode="payment_offer"
 render()''')
a=s.index(' var panel=overlay("选择支付颜色")',s.index('func reserve_resource'));b=s.index('\nfunc commit_local',a)
s=s[:a]+''' local.mode="payment_color"; local.resource=uid; local.colors=colors; render()
'''+s[b:]
replace('if local.is_empty() or response_disabled(): return\n var error=engine.commit_extension','if local.is_empty() or local.mode!="payment" or response_disabled(): return\n var error=engine.commit_extension')
replace('if error.is_empty(): local={}; selection=[]; message=""','if error.is_empty(): local={}; selection=[]; picker.reset(); message=""')
replace('local={}; selection=[]; modal=false; message=""; render()','local={}; selection=[]; picker.reset(); modal=false; message=""; render()')
replace('var selected=selection.duplicate()\n if not local.is_empty():','var selected=selection.duplicate()\n for target in picker.selected_refs():\n  if target.has("uid") and target.uid not in selected: selected.append(target.uid)\n if not local.is_empty():')
function('open_local_choices','''func open_local_choices():
 # Compatibility entry point: choices are rendered in the battlefield HUD.
 render()''')
function('open_effect_choices','''func open_effect_choices():
 render()''')
p.write_text(s,encoding='utf-8')
p=Path('scripts/duel_table.gd'); s=p.read_text(encoding='utf-8').replace('var highlighted=[]','var highlighted=[]\nvar targetable_stacks=[]\nvar selected_stacks=[]').replace('d.gold=false; d.blue=false; d.tapped=false','d.gold=entry.id in selected_stacks; d.blue=entry.id in targetable_stacks; d.tapped=false');p.write_text(s,encoding='utf-8')
