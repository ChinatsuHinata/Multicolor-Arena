extends "res://tests/support/rules_base.gd"

const SPELL="98"
const Codec=preload("res://net/state_codec.gd")

func setup_pair(who: int=0,leaders: bool=false) -> Dictionary:
 fresh();e.debug_enabled=true;e.debug_free_payment=true;e.active=who;e.priority=who
 var units=[]
 for owner in [who,1-who]:
  var unit=e.players[owner].leader if leaders else put("53","field",owner)
  if leaders:e.enter_field(unit,owner)
  units.append(unit)
 return {"who":who,"units":units,"spell":put(SPELL,"hand",who)}

func announce(board: Dictionary) -> Dictionary:
 var target={"parts":board.units.map(func(u):return e.ref_target(u))}
 expect(target in e.targets_for(SPELL,board.who,board.spell.uid),"不同操控者的同类单位可成为晴岚的两个目标")
 var error=e.commit_cast(board.who,board.spell.uid,target,[])
 expect(error.is_empty() and board.spell.zone=="stack","晴岚声明两个目标后进入响应窗口："+error)
 return target

func lose_target(unit: Dictionary,response: String):
 if response=="shroud":e.players[unit.owner].shroud_turn=e.turn
 elif response=="blink":
  var owner=unit.owner;e.move_to(unit,"exile",false);e.detach(unit);e.enter_field(unit,owner)
 else:e.move_to(unit,response,false)

func normal_resolution():
 for who in [0,1]:
  var board=setup_pair(who);announce(board);one()
  expect(board.units.all(func(u):return u.zone=="hand" and e.players[u.owner].hand.has(u)),"双方目标有效时均回拥有者手牌，使用席位%d" % who)
  expect(board.spell.zone=="grave" and e.stack.is_empty() and e.pending.is_empty(),"晴岚正常结算后进墓地")
  board=setup_pair(who)
  for u in board.units:u.original_owner=1-u.owner
  announce(board);one()
  expect(board.units.all(func(u):return u.zone=="hand" and u.owner==u.original_owner and e.players[u.original_owner].hand.has(u)),"被夺取操控权的两个目标均回各自拥有者手牌")

func lost_targets():
 for who in [0,1]:
  for lost in [0,1]:
   for response in ["grave","hand","exile","palette","blink","shroud"]:
    var board=setup_pair(who);announce(board)
    lose_target(board.units[lost],response)
    one()
    var label="席位%d / 目标%d / %s" % [who,lost,response]
    expect(board.units[1-lost].zone=="field",label+"：一个目标失效时另一目标不回手")
    expect(board.units[lost].zone==("field" if response in ["blink","shroud"] else response),label+"：不再作用于失效目标")
    expect(board.spell.zone=="grave" and e.stack.is_empty() and e.pending.is_empty(),label+"：符卡送墓且没有残留选择")
    expect(e.log.any(func(line):return line.contains("目标失效") and line.contains(e.cards[SPELL].name)),label+"：记录晴岚因目标失效不结算")
 var board=setup_pair();announce(board)
 for u in board.units:e.move_to(u,"exile")
 one()
 expect(board.units.all(func(u):return u.zone=="exile") and board.spell.zone=="grave","两个目标都丢失时晴岚同样不执行回手")

func leader_returns():
 for who in [0,1]:
  for first_home in [false,true]:
   for second_home in [false,true]:
    var board=setup_pair(who,true);announce(board);one()
    for home in [first_home,second_home]:
     expect(e.pending.get("kind","")=="leader_return","合法的双自机回手分别询问返回区域")
     if e.pending.get("kind","")!="leader_return":break
     e.choose_return(home)
    expect(board.units.filter(func(u):return u.zone=="leader").size()==int(first_home)+int(second_home),"自机各自选择回手或返回自机区")
    expect(board.units.all(func(u):return u.zone in ["leader","hand"]) and e.pending.is_empty(),"第一个自机离场不妨碍第二个合法目标回手")
  for lost in [0,1]:
   var board=setup_pair(who,true);announce(board);lose_target(board.units[lost],"exile");one()
   expect(board.units[1-lost].zone=="field" and e.pending.is_empty(),"自机目标丢失时另一自机留场且不询问返回区域")

func restored_resolution():
 for who in [0,1]:
  for response in ["none","grave","blink","shroud"]:
   var board=setup_pair(who);announce(board)
   if response!="none":lose_target(board.units[who],response)
   var uids=board.units.map(func(u):return u.uid);var spell_uid=board.spell.uid
   var saved=Codec.capture(e);e=Duel.new();Codec.restore(e,saved);one()
   expect(e.find_card(uids[1-who]).zone==("hand" if response=="none" else "field"),"存档恢复后仍检查晴岚的完整目标对："+response)
   expect(e.find_card(spell_uid).zone=="grave" and e.stack.is_empty() and e.pending.is_empty(),"存档恢复后的晴岚完成结算处理")

func run():
 normal_resolution();lost_targets();leader_returns();restored_resolution()
 print("TENGU_CLEAR_STORM: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
