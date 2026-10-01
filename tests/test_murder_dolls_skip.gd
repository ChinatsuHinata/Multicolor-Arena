extends "res://tests/support/rules_base.gd"

const Gateway=preload("res://net/command_gateway.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Observer=preload("res://net/observer_projection.gd")
const Codec=preload("res://net/state_codec.gd")
class RecordingSession:
 extends RefCounted
 var command={}
 func submit(value: Dictionary) -> String:
  command=value;return ""

func put_dolls(who: int=0):
 var c=put("spell-fdf-017","field",who);c.timer=2;return c

func select_unit(c: Dictionary):
 if e.pending.get("kind","")!="effect_choice":return
 var target=e.pending.options[0].duplicate(true)
 target.erase("selection");target.picks=[[e.Pack.ref(e,c)]]
 e.choose_effect(target)

func run():
 fresh()
 var dolls=put_dolls();var own=put("27")
 var actions=e.available_actions(0,dolls.uid)
 expect(actions.size()==1 and actions[0].type=="murder_dolls_skip" and actions[0].label.contains("关闭"),"杀人玩偶默认开启独立的空场跳过开关")
 expect(not e.has_response(0),"开关不计为启动式能力或可响应动作")
 var priority=e.priority;var passes=e.passes;var revision=e.revision
 expect(Gateway.apply(e,0,{"name":"toggle_murder_dolls_skip","args":[dolls.uid]}).is_empty(),"联机命令可关闭自己的开关")
 expect(dolls.get("murder_dolls_skip_disabled",false) and e.stack.is_empty() and not dolls.tapped and e.priority==priority and e.passes==passes and e.revision>revision,"切换不进入对抗、不横置、不改变执行权")
 var restored=Duel.new();Codec.restore(restored,Codec.capture(e))
 expect(restored.find_card(dolls.uid).get("murder_dolls_skip_disabled",false),"存档恢复每张牌的开关")
 for seat in [0,1]:
  var projection=SeatView.build(e,seat)
  expect(projection.state.players[0].field.any(func(c):return c.uid==dolls.uid and c.get("murder_dolls_skip_disabled",false)),"席位 "+str(seat)+" 同步开关状态")
  if seat==0:expect(projection.queries.actions[dolls.uid].any(func(a):return a.type=="murder_dolls_skip" and a.label.contains("开启")),"本方联机菜单提供重新开启")
 expect(Observer.build(e).state.players[0].field.any(func(c):return c.uid==dolls.uid and c.get("murder_dolls_skip_disabled",false)),"观战同步开关状态")
 var remote=Remote.new();remote.seat=0;remote.apply_snapshot(SeatView.build(e,0));remote.session=RecordingSession.new()
 remote.toggle_murder_dolls_skip(0,dolls.uid)
 expect(remote.session.command.name=="toggle_murder_dolls_skip" and remote.session.command.args==[dolls.uid] and remote.find_card(dolls.uid).get("murder_dolls_skip_disabled",false),"客户端只提交命令，等待权威状态")
 expect(not Gateway.apply(e,1,{"name":"toggle_murder_dolls_skip","args":[dolls.uid]}).is_empty(),"对手不能切换本方开关")
 expect(not Gateway.apply(e,0,{"name":"toggle_murder_dolls_skip","args":[str(dolls.uid)]}).is_empty(),"拒绝错误格式的开关命令")
 expect(not e.toggle_murder_dolls_skip(0,own.uid).is_empty(),"其他永久物不能使用此开关")
 dolls.tapped=true;dolls.entered_turns=e.players[0].turns
 e.players[0].night_lock=e.turn
 expect(e.toggle_murder_dolls_skip(0,dolls.uid).is_empty() and not dolls.get("murder_dolls_skip_disabled",false),"横置、刚进场及启动能力限制不妨碍开关")
 e.players[0].erase("night_lock")
 e.stack.append({"kind":"ability","owner":1})
 var before=Codec.capture(e)
 expect(not Gateway.apply(e,0,{"name":"toggle_murder_dolls_skip","args":[dolls.uid]}).is_empty() and Codec.capture(e)==before,"对抗非空时拒绝切换且状态不变")
 var blocked=e.available_actions(0,dolls.uid,true).filter(func(a):return a.type=="murder_dolls_skip")
 expect(blocked.size()==1 and not blocked[0].enabled and blocked[0].reason.contains("对抗为空"),"禁用菜单显示对抗必须为空")
 e.stack.clear();e.pending={"kind":"block","owner":0}
 expect(not e.toggle_murder_dolls_skip(0,dolls.uid).is_empty(),"待选状态不能切换")
 e.pending={};e.priority=1
 expect(not e.toggle_murder_dolls_skip(0,dolls.uid).is_empty(),"切换需要本方执行权")
 var enemy_dolls=put_dolls(1)
 expect(Gateway.apply(e,1,{"name":"toggle_murder_dolls_skip","args":[enemy_dolls.uid]}).is_empty(),"第二席位可切换自己的开关")
 e.priority=0;e.phase="mulligan"
 expect(not e.toggle_murder_dolls_skip(0,dolls.uid).is_empty(),"调度阶段不能切换")
 e.phase="main";e.winner=0
 expect(not e.toggle_murder_dolls_skip(0,dolls.uid).is_empty(),"对局结束后不能切换")

 fresh();dolls=put_dolls();own=put("27")
 put_dolls();put("item-fdf-096","field",1)
 priority=e.priority;passes=e.passes
 e.add_timer(own,2);e.pump_choices()
 expect(own.timer==2 and own.damage==0 and e.pending.is_empty() and e.stack.is_empty() and e.triggers.is_empty(),"对方无单位时自动跳过所有副本，无目标或排序弹窗")
 expect(e.priority==priority and e.passes==passes,"自动跳过保留执行权与连续让过次数")
 e.add_timer(e.players[0].leader,1);e.pump_choices()
 expect(e.pending.is_empty() and e.stack.is_empty(),"自机区放置计时同样支持自动跳过")
 e.add_timer(own,1);e.queue_trigger(0,own,1,"其他触发");e.pump_choices()
 expect(e.pending.get("kind","")=="trigger" and e.triggers.is_empty(),"自动跳过不妨碍其他触发且不加入排序")
 e.choose_trigger({})
 expect(e.toggle_murder_dolls_skip(0,dolls.uid).is_empty(),"可关闭其中一个副本")
 e.add_timer(own,1);e.pump_choices()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.source.uid==dolls.uid and e.triggers.is_empty(),"各副本开关独立，关闭的副本保留选择")
 select_unit(own);one()
 expect(own.damage==1 and e.stack.is_empty(),"关闭后可以实际对己方单位造成伤害")
 e.priority=0;e.move_to(dolls,"hand")
 expect(not dolls.has("murder_dolls_skip_disabled") and not e.toggle_murder_dolls_skip(0,dolls.uid).is_empty(),"离场清除开关且不能在场外切换")
 e.detach(dolls);e.shift(dolls,"field");e.players[0].field.append(dolls);dolls.timer=2
 e.add_timer(own,1);e.pump_choices()
 expect(e.pending.is_empty() and e.stack.is_empty(),"重新进场默认开启自动跳过")

 fresh();dolls=put_dolls();own=put("27")
 var enemy=put("27","field",1)
 e.add_timer(own,3);e.pump_choices()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.data.amount==3,"对方有单位时仍照常询问并保留计时数量")
 select_unit(enemy);one()
 expect(enemy.zone=="grave","正常触发仍对敌方单位造成正确伤害")

 fresh();dolls=put_dolls();own=put("27");enemy=put("27","field",1)
 e.add_timer(own,1);e.pump_choices();select_unit(own)
 e.move_to(enemy,"grave");one()
 expect(own.damage==1,"已经确认的触发不会因响应期间敌方空场被跳过")

 fresh();dolls=put_dolls();own=put("27");enemy=put("27","field",1)
 e.add_timer(own,1);enemy.damage=e.stat(enemy,"health");e.pump_choices()
 expect(enemy.zone=="grave" and e.pending.is_empty() and e.stack.is_empty(),"状态动作消灭最后敌方单位后再判断自动跳过")

 fresh();dolls=put_dolls(1);own=put("27","field",1)
 e.add_timer(own,1);e.pump_choices()
 expect(e.pending.is_empty() and e.stack.is_empty(),"第二席位根据其对方场上的单位判断")
 enemy=put("27");e.add_timer(own,1);e.pump_choices()
 expect(e.pending.get("owner",-1)==1 and e.pending.trigger.effect=="cat:murder_dolls","第二席位有敌方单位时正常选择")
 e.choose_effect({})
 print("MURDER_DOLLS_SKIP: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
