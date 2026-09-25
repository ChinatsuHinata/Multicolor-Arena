extends SceneTree
const E=preload("res://scripts/rules/duel_engine.gd")
var e
var failures=[]

func _init():call_deferred("run")
func check(ok: bool,label: String):
 if not ok:
  failures.append(label)
  push_error(label)
func fresh():
 e=E.new()
 var deck={"leader":"50","main":[]}
 for i in range(50):deck.main.append("53")
 e.start(deck,deck,0,42)
 for p in e.players:
  for z in ["hand","field","palette","grave","exile"]:p[z]=[]
  p.mulligan_done=true
 e.phase="main";e.turn=3;e.active=0;e.priority=0;e.pending={};e.triggers=[]
 e.cards["53"].health=20
func add(id: String,owner: int,zone: String="field") -> Dictionary:
 var c=e.make_card(id,owner,zone);e.players[owner][zone].append(c);return c
func cast_after_dream(id: String,target: Dictionary):
 e.debug_enabled=true;e.debug_free_payment=true
 var dream=add("new-eto-010",0,"hand")
 check(e.commit_cast(0,dream.uid,{"none":true},[]).is_empty(),"妖鸟应能使用")
 resolve_top()
 check(dream.zone=="outside","妖鸟结算后应离开本局游戏")
 var c=add(id,0,"hand")
 check(e.commit_cast(0,c.uid,target,[]).is_empty(),"目标符卡应能使用")
 var original=e.stack[0]
 check(e.stack.size()==2 and e.stack[1].get("effect","")=="n21:dream_copy","妖鸟应在原符卡上方产生复制触发")
 resolve_top()
 return original
func choose_copy(target: Dictionary):
 check(e.pending.get("kind","")=="effect_choice","应等待复制品目标")
 check(e.Pack.choice_valid(e,e.pending.options,target),"复制品应接受指定的目标")
 e.choose_effect(target)
func resolve_top():
 e.priority=0;e.passes=0
 e.pass_priority(e.priority);e.pass_priority(e.priority)
func run():
 fresh()
 var own=add("53",0);var foe=add("53",1)
 add("53",0,"grave")
 var original=cast_after_dream("126",{"parts":[{"player":1},e.ref_target(foe)]})
 choose_copy({"parts":[{"player":0},e.ref_target(own)]})
 choose_copy({"parts":[{"player":1},e.ref_target(foe)]})
 check(e.stack.size()==3,"原符卡和两份复制品应都在堆叠")
 check(e.stack[0].target==original.target and e.stack[1].target.parts[0].player==0 and e.stack[2].target.parts[0].player==1,"复制品分别保留所选复合目标")
 var deck0=e.players[0].deck.size();var deck1=e.players[1].deck.size()
 resolve_top();resolve_top();resolve_top()
 check(e.players[0].deck.size()==deck0-1 and e.players[1].deck.size()==deck1-2,"湖上三次结算应按各自目标磨牌")
 check(own.damage==2 and foe.damage==3,"湖上每次应按结算时自己的墓地牌数造成伤害")
 check(e.players[0].grave.size()==3,"原符卡进入墓地，复制品消失")
 fresh();foe=add("53",1)
 original=cast_after_dream("126",{"parts":[{"player":1},e.ref_target(foe)]})
 choose_copy({"parts":[{"player":1},e.ref_target(foe)]})
 choose_copy({"parts":[{"player":1},e.ref_target(foe)]})
 deck1=e.players[1].deck.size();e.move_to(foe,"grave")
 resolve_top();resolve_top();resolve_top()
 check(e.players[1].deck.size()==deck1-3,"湖上单位目标失效时，合法的牌手目标仍应磨牌三次")
 fresh();own=add("53",0);foe=add("53",1)
 var hit=e.ref_target(foe);hit.mode="造成2点伤害"
 original=cast_after_dream("176",{"parts":[hit,{"none":true,"mode":"抓一张牌"}]})
 check(e.pending.options.any(func(o):return o.parts[0].mode=="抓一张牌" and o.parts[1].mode=="抓一张牌"),"复制双模式符卡可以重新选择模式")
 choose_copy({"parts":[{"none":true,"mode":"抓一张牌"},{"none":true,"mode":"抓一张牌"}]})
 hit=e.ref_target(own);hit.mode="横置"
 var second=e.ref_target(foe);second.mode="造成2点伤害"
 choose_copy({"parts":[hit,second]})
 deck0=e.players[0].deck.size();resolve_top();resolve_top();resolve_top()
 check(own.tapped and foe.damage==4 and e.players[0].deck.size()==deck0-3,"双模式符卡复制品按新选择的模式和目标结算")
 fresh();own=add("53",0);foe=add("53",1)
 var mode_spec=e.Roster.New.spell_options(e,"new-eto-008",0).filter(func(o):return o.n21_modes==1)[0]
 var original_target=mode_spec.duplicate(true);original_target.erase("selection");original_target.picks=[[e.ref_target(foe)]]
 original=cast_after_dream("new-eto-008",original_target)
 check(e.pending.options.any(func(o):return o.n21_modes==2),"妖鸟复制的多模式选择组可以改选模式")
 mode_spec=e.pending.options.filter(func(o):return o.n21_modes==2)[0]
 var new_target=mode_spec.duplicate(true);new_target.erase("selection");new_target.picks=[[e.ref_target(own)]]
 choose_copy(new_target)
 mode_spec=e.pending.options.filter(func(o):return o.n21_modes==1)[0]
 new_target=mode_spec.duplicate(true);new_target.erase("selection");new_target.picks=[[e.ref_target(foe)]]
 choose_copy(new_target)
 resolve_top();resolve_top();resolve_top()
 check(own.zone=="deck" and foe.tapped,"改选后的多模式复制品按自己的模式结算")
 fresh();own=add("53",0);var own2=add("53",0);var own3=add("53",0);foe=add("53",1);var foe2=add("53",1)
 original_target=e.ref_target(foe);original_target.sacrifice=e.ref_target(own);original_target.sacrifice_value=e.Extra.cost_value(e,own)
 original=cast_after_dream("94",original_target)
 check(e.pending.options.any(func(o):return o.get("uid",-1)==foe2.uid and o.get("sacrifice",{}).get("uid",-1)==own2.uid),"第一份复制品需另选牺牲单位")
 new_target=e.pending.options.filter(func(o):return o.get("uid",-1)==foe2.uid and o.get("sacrifice",{}).get("uid",-1)==own2.uid)[0]
 choose_copy(new_target)
 check(own2.zone=="grave" and e.pending.options.any(func(o):return o.get("uid",-1)==foe2.uid and o.get("sacrifice",{}).get("uid",-1)==own3.uid),"第二份复制品也需另付牺牲")
 new_target=e.pending.options.filter(func(o):return o.get("uid",-1)==foe2.uid and o.get("sacrifice",{}).get("uid",-1)==own3.uid)[0]
 choose_copy(new_target)
 resolve_top();resolve_top();resolve_top()
 check(own.zone=="grave" and own2.zone=="grave" and own3.zone=="grave" and foe.damage==5 and foe2.damage==10,"秋意ノ溪原符卡和两份复制品各牺牲一次")
 fresh();own=add("53",0);own2=add("53",0);own3=add("53",0);var grave1=add("53",0,"grave");var grave2=add("53",0,"grave");var grave3=add("53",0,"grave")
 original_target=e.Pack.ref(e,grave1);original_target.sacrifice=e.ref_target(own);original_target.sacrifice_value=e.Extra.cost_value(e,own)
 original=cast_after_dream("163",original_target)
 new_target=e.pending.options.filter(func(o):return o.get("uid",-1)==grave2.uid and o.get("sacrifice",{}).get("uid",-1)==own2.uid)[0]
 choose_copy(new_target)
 new_target=e.pending.options.filter(func(o):return o.get("uid",-1)==grave3.uid and o.get("sacrifice",{}).get("uid",-1)==own3.uid)[0]
 choose_copy(new_target)
 resolve_top();resolve_top();resolve_top()
 check(own.zone=="grave" and own2.zone=="grave" and own3.zone=="grave" and grave1.zone=="field" and grave2.zone=="field" and grave3.zone=="field","萤燈ノ森三次结算各付牺牲并移回选定单位")
 fresh();var discard1=add("53",0,"hand");var discard2=add("53",0,"hand");var discard3=add("53",0,"hand")
 original=cast_after_dream("107",{"selection_id":"additional_discard","picks":[[e.Pack.ref(e,discard1)]]})
 check(e.pending.options.any(func(o):return o.get("selection_id","")=="additional_discard" and o.selection[0].get("cost",false)),"弃牌符卡复制品需重新选择弃牌 cost")
 choose_copy({"selection_id":"additional_discard","picks":[[e.Pack.ref(e,discard2)]]})
 choose_copy({"selection_id":"additional_discard","picks":[[e.Pack.ref(e,discard3)]]})
 check(discard1.zone=="grave" and discard2.zone=="grave" and discard3.zone=="grave","原符卡和两份复制品各弃一张牌")
 resolve_top();resolve_top();resolve_top()
 check(e.players[0].hand.size()==9,"弃牌符卡原件和复制品各抓三张牌")
 fresh();discard1=add("53",0,"hand");discard2=add("107",0,"hand");discard3=add("107",0,"hand")
 original=cast_after_dream("107",{"selection_id":"additional_discard","picks":[[e.Pack.ref(e,discard1)]]})
 choose_copy({"selection_id":"additional_discard","picks":[[e.Pack.ref(e,discard2)]]})
 check(e.pending.options[0].selection[0].pool.has(e.Pack.ref(e,discard3)),"最后一张同名手牌仍可支付复制品弃牌 cost")
 choose_copy({"selection_id":"additional_discard","picks":[[e.Pack.ref(e,discard3)]]})
 check(discard2.zone=="grave" and discard3.zone=="grave","两份复制品可各弃一张同名牌")
 resolve_top();resolve_top();resolve_top()
 fresh();own=add("53",0);foe=add("53",1)
 original_target=e.ref_target(foe);original_target.sacrifice=e.ref_target(own);original_target.sacrifice_value=e.Extra.cost_value(e,own)
 original=cast_after_dream("94",original_target)
 check(e.pending.is_empty() and e.stack.size()==1,"没有额外牺牲资源时不产生未付 cost 的复制品")
 resolve_top()
 check(foe.damage==5,"资源不足时原符卡仍正常结算")
 print("DREAM COPY TARGETS failures=",failures)
 quit(0 if failures.is_empty() else 1)
