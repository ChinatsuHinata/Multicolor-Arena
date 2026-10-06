extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const TutorialDuel=preload("res://scripts/tutorial/scripted_duel.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0

func expect(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);push_error(label)

func fixture(script):
 var deck=Store.blank("教程结算测试");deck.leader="70"
 for i in range(50):deck.main.append("164")
 var e=script.new();e.start(deck,deck,0,12)
 for p in e.players:
  p.hand=[];p.field=[];p.palette=[];p.grave=[];p.exile=[];p.potato=false;p.mulligan_done=true
 e.phase="main";e.turn=5;e.active=0;e.priority=0
 return e

func check_tutorial_settlement():
 var e=fixture(TutorialDuel)
 e.pending={"kind":"tutorial_choice"}
 e.lose(1,"效果胜利")
 expect(e.winner==-2 and e.phase=="main" and e.pending.kind=="tutorial_choice","effect victory leaves the tutorial state intact")
 e.pending={}
 e.players[0].deck.clear();e.draw(0)
 expect(e.winner==-2 and e.phase=="main","empty required draw does not end the tutorial")
 e.lose(0,"强制失败",true)
 expect(e.winner==-2 and e.phase=="main","forced loss does not end the tutorial")
 e.players[1].life=0;e.judge()
 expect(e.winner==-2 and e.phase=="main" and e.players[1].life==0,"opponent lethal remains visible to tutorial tasks")
 e.players[0].life=0;e.judge()
 expect(e.winner==-2 and e.phase=="main","simultaneous lethal does not settle a draw")
 e=fixture(TutorialDuel)
 var komachi=e.make_card("character-kmo-001",0,"hand");komachi.leader=true;e.enter_field(komachi,0)
 e.players[0].coins=3;e.players[1].coins=3;e.check_komachi_coins()
 expect(e.winner==-2 and e.phase=="main" and e.players[0].coins==3 and e.players[1].coins==3,"simultaneous coin losses keep the tutorial running")

func check_regular_settlement():
 var e=fixture(Duel)
 e.lose(1,"效果胜利")
 expect(e.winner==0 and e.phase=="over","ordinary effect victory still settles")
 e=fixture(Duel);e.players[0].life=0;e.players[1].life=0;e.judge()
 expect(e.winner==-1 and e.phase=="over","ordinary simultaneous lethal still settles a draw")

func check_task_progress():
 var loaded=Config.new().load_file("res://data/tutorial/beginner/t3.json",Store.CARDS)
 expect(loaded.ok,"T3 course loads")
 if not loaded.ok:return
 var flow=Runtime.new()
 var reason=flow.start(loaded.data,Store.CARDS)
 expect(reason.is_empty(),"T3 course starts: "+reason)
 if not reason.is_empty():flow.free();return
 flow.enter("r3")
 var e=flow.adapter.engine
 e.players[1].life=0;e.judge();e.note("测试致命伤害")
 flow.tick()
 expect(flow.current_step=="d17" and flow.running and e.winner==-2,"lethal completes the task without ending the tutorial match")
 flow.free()

func _initialize():
 check_tutorial_settlement()
 check_regular_settlement()
 check_task_progress()
 print("TUTORIAL MATCH SETTLEMENT: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
