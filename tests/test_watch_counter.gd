extends "res://tests/support/rules_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")

func aya_response():
 for who in [0,1]:
  fresh()
  var aya=put("79","field",who);aya.leader=true
  var target=put("53","field",who)
  var barrier=put("field-rei-003","field",1-who)
  e.priority=who
  expect(e.commit_extension(who,aya.uid,e.ref_target(target),[],"leader_bounce").is_empty(),"文启动回手能力（玩家%d）" % who)
  expect(e.stack.size()==1 and e.stack.back().get("activation",false),"文的回手在堆叠标记为启动能力")
  var aim={"stack_id":e.stack.back().id}
  expect(aim in e.activation_options(barrier,"watch_counter"),"警醒阵识别文的回手能力")
  expect(e.extension_activation_error(1-who,barrier,"watch_counter").is_empty(),"警醒阵可以响应文的回手能力")
  expect(e.has_response(1-who),"默认响应模式保留警醒阵的响应窗口")
  var restored=Duel.new();Codec.restore(restored,Codec.capture(e))
  expect(aim in restored.activation_options(restored.find_card(barrier.uid),"watch_counter"),"存档恢复仍可选中文的能力")
  var remote=Remote.new();remote.seat=1-who;remote.apply_snapshot(SeatView.build(e,1-who))
  expect(remote.has_response(1-who),"联机客户端收到可响应状态")
  expect(remote.available_actions(1-who,barrier.uid).any(func(a):return a.get("key","")=="watch_counter"),"联机客户端收到警醒阵可启动行动")
  expect(aim in remote.activation_options(remote.find_card(barrier.uid),"watch_counter"),"联机客户端可选择文的能力")
  expect(e.commit_extension(1-who,barrier.uid,aim,[],"watch_counter").is_empty(),"警醒阵成功提交反制")
  expect(barrier.zone=="grave" and e.stack.size()==2,"警醒阵支付牺牲费用并进入堆叠")
  one()
  expect(e.stack.is_empty() and target.zone=="field","警醒阵反制回手，目标留在战场")
  expect(e.usage_count(aya.uid,"leader_bounce")==1,"被反制后文仍消耗本回合次数")

func run():
 aya_response()
 print("WATCH COUNTER: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
