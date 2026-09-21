extends "res://tests/test_bugs0921_rules.gd"
func selected(options,groups):
 var target=options[0].duplicate(true);target.erase("selection");target.picks=groups;return target
func effect(id,aim):
 var card=e.make_card(id,0,"stack")
 e.Effects.resolved(e,{"id":e.next_stack,"kind":"card","card":card,"owner":0,"target":aim,"name":e.cards[id].name})
 return card
func run():
 fresh()
 expect(int(e.cards["spell-fdf-009"].cost.get("红",0))==2 and int(e.cards["spell-fdf-009"].cost.get("蓝",0))==2,"新史2红2蓝")
 expect(int(e.cards["spell-fdn-012"].cost.get("绿",0))==2 and int(e.cards["spell-fdn-012"].cost.get("黑",0))==2 and int(e.cards["spell-fdn-012"].cost.get("黄",0))==1 and not e.cards["spell-fdn-012"].cost.has("蓝"),"魂魄2绿2黑1黄")
 expect(e.cards["character-fdf-029"].power==4 and e.cards["character-fdf-029"].health==2 and e.cards["character-fdf-029"].spirit==3,"小町4攻击2血3灵力")
 expect(e.cards["character-fdn-071"].canonical_id=="character-ucs-068","隐岐奈归并为单一卡名")
 fresh();var receiver=plain();receiver.plus_counters=3;receiver.damage=1
 effect("137",e.ref_target(receiver));e.pump_choices()
 expect(receiver.zone=="grave","百万先移除再伤判：目标自身死亡后不放回指示物")
 fresh();receiver=plain(0,2,6);var giver=plain(1,2,6);giver.plus_counters=2;giver.drunk_counters=3;giver.madness=4
 effect("137",e.ref_target(receiver))
 expect(receiver.plus_counters==9 and giver.get("drunk_counters",0)==0 and giver.get("madness",0)==0,"百万收集特殊111并转为普通111")
 expect(receiver.get("drunk_counters",0)==0 and receiver.get("madness",0)==0,"百万转移不继承醉醺醺狂气")
 fresh();receiver=plain(0,2,6);receiver.plus_counters=2;receiver.drunk_counters=3;receiver.madness=4;receiver.dream=1
 var aim=e.ref_target(receiver);aim.mode="指示物翻倍";effect("spell-lof-025",aim)
 expect(receiver.plus_counters==4 and receiver.drunk_counters==6 and receiver.madness==8 and receiver.dream==2,"蜜桃翻倍所有指示物且保留种类")
 fresh();var poverty=put("164","palette");poverty.poverty=2;var tojiko=put("38");var trigger={"effect":"death_poverty","source":tojiko.duplicate(true),"owner":0,"target":e.Pack.ref(e,poverty),"data":{}}
 e.Extra.resolve_trigger(e,trigger);expect(poverty.poverty==3,"屠自古累加贫乏指示物")
 fresh();put("spell-fdn-012");var half=e.Extra.create_token(e,0,"token_halfghost");e.pending={};e.triggers=[];e.phase="end"
 var ghost=e.units(0).filter(func(c):return e.Cat.character(e,c,"半灵"))[0];var keine=put("character-fdf-ex05")
 var options=e.Pack.activation_options(e,keine,"keine_devour")
 expect(options.is_empty() or not options[0].selection[0].pool.any(func(r):return r.uid==ghost.uid),"结束阶段慧音不能选择牺牲受保护半灵")
 e.sacrifice(ghost);expect(ghost.zone=="field","结束阶段直接牺牲也受半灵保护")
 e.phase="main";e.sacrifice(ghost);expect(ghost.zone!="field","主要阶段仍能牺牲半灵")
 for home in [false,true]:
  fresh();var leader=e.players[0].leader;e.enter_field(leader,0);e.pending={};e.triggers=[]
  effect("114",{"picks":[[e.ref_target(leader)]]});e.pump_choices()
  expect(e.pending.get("kind")=="leader_return" and leader.zone=="return_pending","境界先询问自机去向")
  e.choose_return(home);expect(leader.zone==("leader" if home else "field"),"境界尊重自机去向 "+str(home))
 fresh();var leader=e.players[0].leader;e.enter_field(leader,0);e.pending={};e.triggers=[];e.Pack.blink(e,leader,0);e.pump_choices();e.choose_return(false)
 e.phase="prepare";e.run_delayed("prepare");e.pump_choices()
 expect(e.stack.size()==1 and e.stack[0].effect=="delayed_return","紫延迟回场进入对抗")
 if not e.stack.is_empty():e.counter_entry(e.stack[0].id);e.pump_choices()
 expect(e.pending.get("kind")=="leader_return","自机延迟回场被反制后重新询问回自机区")
 if e.pending.get("kind")=="leader_return":e.choose_return(true)
 expect(leader.zone=="leader","延迟回场失败后可回自机区")
 fresh();var momiji=put("character-ucs-056")
 e.Cat.Units.resolve(e,{"effect":"character-ucs-056","owner":0,"source":momiji.duplicate(true),"target":{"player":1},"data":{}})
 e.move_to(momiji,"hand");e.triggers=[];e.phase="end";e.active=1;e.players[1].attacked_player_turn=e.turn;e.Cat.Units.on_phase(e,"end")
 expect(not e.triggers.any(func(t):return t.get("effect")=="cat:tengu_watch"),"椛离场后不再执行监视效果")
 for id in DB.IDS.filter(func(cid):return "时符" in e.cards[cid].spell_type or "乐章" in e.cards[cid].spell_type):
  fresh();var original=e.make_card(id,0,"stack");original.cast_x=2;e.stack.append({"id":e.next_stack,"kind":"card","card":original,"owner":0,"target":{"none":true},"name":e.cards[id].name});e.next_stack+=1
  effect("spell-fdn-066",{"stack_id":e.stack[0].id})
  expect(e.stack[0].get("rewritten_fairy",false),"真实巡礼牌改写对抗 "+id)
  one()
  expect(original.zone=="field" and e.units(0).any(func(c):return e.cards[c.card_id].character=="妖精"),"真实巡礼改写后留场并造妖精 "+id)
  if "时符" in e.cards[id].spell_type:expect(original.timer==(2 if id=="spell-fdf-024" else e.cards[id].time),"巡礼时符恢复计时 "+id)
 fresh();var old=effect("119",{"none":true});e.players[0].exile_free={"turn":e.turn,"remaining":2};put("character-fdf-ex05");many_mana(0)
 expect(old.zone=="exile" and not e.cast_error(0,old.uid).is_empty(),"古代史本体结算移除后不能再次使用")
 # Catadioptric: stop, return from an impossible target, and successful copy.
 fresh();var victim=put("164");var x=e.Extra.cost_value(e,victim)
 effect("spell-fdf-051",{"picks":[[e.Pack.ref(e,victim)]],"x":x})
 expect(e.pending.get("kind")=="effect_choice" and e.pending.trigger.effect=="cat:copy_x","禁弹消灭后打开复制菜单")
 expect(e.pending.options.any(func(o):return o.get("copy_stop",false)),"复制菜单有停止")
 e.choose_effect(e.pending.options[0]);expect(e.pending.trigger.effect=="cat:spell_copy","翻倍后进入复制目标选择")
 e.choose_effect({"none":true,"mode":"返回","copy_back":true})
 expect(e.pending.trigger.effect=="cat:copy_x","目标选择返回翻倍减半菜单")
 e.choose_effect({"none":true,"mode":"停止","copy_stop":true})
 expect(e.pending.is_empty() and e.stack.is_empty(),"停止解除选择且不创建复制")
 fresh();victim=plain();e.cards[victim.card_id].cost={"红":2};var next=plain(1);e.cards[next.card_id].cost={"红":4}
 effect("spell-fdf-051",{"picks":[[e.Pack.ref(e,victim)]],"x":2})
 e.choose_effect(e.pending.options[0]);var spec=e.pending.options.filter(func(o):return o.has("selection"))[0]
 aim=spec.duplicate(true);aim.erase("selection");aim.picks=[[e.Pack.ref(e,next)]];e.choose_effect(aim)
 expect(e.stack.size()==1 and e.stack[0].card.cast_x==4,"禁弹仍能实际复制并把X翻倍")
 one();expect(next.zone=="grave" and e.pending.trigger.effect=="cat:copy_x","复制结算消灭目标并可继续复制")
 e.choose_effect({"none":true,"mode":"停止","copy_stop":true})
 # Leader decision survives serialization and declining it does not re-enter exile.
 fresh();leader=e.players[0].leader;e.enter_field(leader,0);e.pending={};e.triggers=[];e.Pack.blink(e,leader,0);e.pump_choices();e.choose_return(false)
 e.phase="prepare";e.run_delayed("prepare");e.pump_choices();e.counter_entry(e.stack[0].id);e.pump_choices()
 leader.dream=2;var epoch=leader.epoch
 var codec=load("res://net/state_codec.gd");var recovered=Duel.new();codec.restore(recovered,codec.capture(e));e=recovered;leader=e.players[0].leader
 expect(e.pending.card==leader and leader.zone=="exile","反制后的自机选择可序列化恢复")
 e.choose_return(false);expect(leader.zone=="exile" and leader.epoch==epoch and leader.dream==2 and e.players[0].exile.count(leader)==1,"拒绝回自机区保持原除外对象及指示物")
 fresh();victim=plain();e.cards[victim.card_id].cost={"红":2}
 effect("spell-fdf-051",{"picks":[[e.Pack.ref(e,victim)]],"x":2});e.ai_step(0)
 expect(e.pending.is_empty(),"AI没有复制目标时停止，不会卡住")
 print("V11 BUGS ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
