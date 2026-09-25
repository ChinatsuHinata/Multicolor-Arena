extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Remote=preload("res://tests/lan_test_remote.gd")
const Store=preload("res://scripts/deck_store.gd")
const Driver=preload("res://tests/lan_test_driver.gd")
var session
var facade
var role="host"
var failures=[]
var actions=0
var started=0
var last_sequence=-1
var stable=0.0
var matches=0
func _init():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args();role=args[0] if not args.is_empty() else "host"
 session=Session.new();root.add_child(session);session.initialize("res://work/v018/process-"+role+"-"+args[1])
 session.error_raised.connect(func(message):failures.append(message);last_sequence=-1;print("COMMAND_ERROR ",role," ",message," command=",facade.last_request))
 facade=Remote.new();facade.session=session;facade.seat=0 if role=="host" else 1
 if role=="host":
  var err=session.create_room(1,false,int(args[1]) if args.size()>1 else 47973)
  if not err.is_empty():print(err);quit(1);return
 else:session.join_room("127.0.0.1",int(args[1]) if args.size()>1 else 47973)
 started=Time.get_ticks_msec()
 while Time.get_ticks_msec()-started<180000:
  await process_frame
  if role=="host" and not session.applicant.is_empty():session.accept_applicant(true)
  if not session.can_act():continue
  while not session.snapshots.is_empty():
   var packet=session.pop_snapshot();facade.apply_snapshot(packet.projection);facade.presentation_events.clear()
  var room=session.room
  if room.get("status","")=="lobby":
   if room.own_deck.is_empty():
    var decks=Store.load_decks().decks;var selected=decks.filter(func(d):return d.id==("precon_reimu_v1" if role=="host" else "precon_marisa_v1"))
    session.room_action({"name":"deck","deck":selected[0] if not selected.is_empty() else decks[session.seat]})
   elif not room.ready[session.seat]:session.room_action({"name":"ready"})
   await create_timer(0.04).timeout;continue
  if room.get("status","")=="choosing":
   if room.chooser==session.seat:session.room_action({"name":"first","first":true})
   await create_timer(0.04).timeout;continue
  if room.get("status","")=="complete" and not facade.players.is_empty():
   var report={"role":role,"score":room.scores,"winner":room.winner,"game_id":room.game_id,"sequence":session.view_sequence,"turn":facade.turn,"life":[facade.players[0].life,facade.players[1].life],"actions":actions,"errors":failures,"history":facade.log}
   var f=FileAccess.open("res://work/v018/process-"+role+"-result.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
   await create_timer(1).timeout;session.leave(false);print("PROCESS_COMPLETE ",role," turn=",facade.turn," actions=",actions," errors=",failures);quit(0 if failures.is_empty() else 1);return
  if facade.players.is_empty():continue
  if session.view_sequence==last_sequence:
   stable+=root.get_process_delta_time()
   if stable>4 and session.can_act() and (facade.priority==session.seat or facade.pending.get("owner",-1)==session.seat):
    failures.append("stalled "+str(facade.pending));break
   continue
  stable=0;last_sequence=session.view_sequence
  if actions%50==0:print("PROGRESS ",role," seq=",session.view_sequence," turn=",facade.turn)
  if not failures.is_empty():break
  if actions>2000:failures.append("action limit");break
  Driver.step(facade,session.seat);actions+=1
 print("PROCESS_FAILED ",role," ",failures," pending=",facade.pending," notice=",session.notice)
 quit(1)
