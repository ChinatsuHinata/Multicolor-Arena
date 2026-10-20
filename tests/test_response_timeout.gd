extends "res://tests/support/response_ui_base.gd"
const Store=preload("res://scripts/deck_store.gd")
const Clock=preload("res://scripts/response_clock.gd")
const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")
const ObserverView=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func check_boundaries():
 stack_fixture(true)
 Clock.sync(e,1000)
 expect(Clock.remaining(e,1000)==240,"each response starts with 240 seconds")
 expect(Clock.caption(e,0,1209.999).is_empty(),"remaining time stays hidden above 30 seconds")
 expect(Clock.caption(e,0,1210)=="响应剩余 30 秒","countdown starts at exactly 30 seconds")
 expect(Clock.caption(e,1,1210)=="对手响应剩余 30 秒","the waiting opponent sees whose response is expiring")
 expect(not Clock.expired(e,1239.999) and Clock.remaining(e,1239.999)==1,"last fraction of a second remains available")
 expect(Clock.expired(e,1240),"response expires at exactly 240 seconds")
 e.revision+=1;Clock.sync(e,1100)
 expect(e.response_clock.deadline==1240,"unrelated revisions cannot extend the response")
 var saved=Codec.capture(e)
 var restored=view.Duel.new();Codec.restore(restored,saved);Clock.sync(restored,1200)
 expect(restored.response_clock.deadline==1240,"saving and restoring preserves the original deadline")
 e.pass_priority(0);Clock.sync(e,1240)
 expect(e.priority==1 and Clock.remaining(e,1240)==240,"next priority window gets a fresh 240 seconds")
 e.pending={"kind":"effect_choice","owner":1};Clock.sync(e,1250)
 expect(e.response_clock.is_empty(),"required resolution choices have no response countdown")
 e.pending={};e.stack=[];e.combat={};e.phase="main";e.priority=e.active;Clock.sync(e,1260)
 expect(e.response_clock.is_empty(),"main phase free actions have no response countdown")
 e.priority=1-e.active;Clock.sync(e,1260)
 expect(Clock.remaining(e,1260)==240,"opponent's main phase response still has a time limit")
 e.phase="mulligan";Clock.sync(e,1270)
 expect(e.response_clock.is_empty(),"mulligans have no response countdown")
 e.phase="prepare";e.winner=0;Clock.sync(e,1280)
 expect(e.response_clock.is_empty(),"finished games have no response countdown")

func check_projection():
 stack_fixture(true)
 var now=Time.get_unix_time_from_system()
 Clock.sync(e,now)
 e.response_clock.deadline=now+30
 for seat in [0,1,-1]:
  var projection=SeatView.build(e,seat) if seat>=0 else ObserverView.build(e)
  var original_deadline=e.response_clock.deadline
  # Simulate a client whose wall clock is one hour ahead, with five seconds queued.
  projection.response_clock_received_at=float(projection.response_clock_sampled_at)+3600
  var remote=Remote.new();remote.apply_snapshot(projection)
  expect(Clock.remaining(remote,now+3605.25)==25,"seat %d translates host time and retains queued elapsed time" % seat)
  expect(e.response_clock.deadline==original_deadline,"client clock conversion does not mutate the authority")

func check_ui():
 var counter=stack_fixture(true)
 e.presentation_events.clear();view.reveal_player.reset()
 view.set_response_mode(view.ResponseMode.ON)
 var now=Time.get_unix_time_from_system()
 view.render()
 var deadline=float(e.response_clock.deadline)
 expect(not "剩余" in view.response_prompt.text,"response UI hides the initial 240-second countdown")
 view.update_response_clock(deadline-30.001)
 expect(not "剩余" in view.response_prompt.text,"response UI remains hidden just above the threshold")
 view.update_response_clock(deadline-30)
 expect("响应剩余 30 秒" in view.response_prompt.text,"response UI shows the final 30 seconds")
 view.set_response_mode(view.ResponseMode.DEFAULT)
 view.set_response_mode(view.ResponseMode.ON)
 expect(e.response_clock.deadline==deadline,"response mode changes and rendering do not restart the timer")
 view.settings_menu()
 view.local={"mode":"payment","uid":counter.uid,"plan":[]};view.selection=[counter.uid];e.paid_cast_uid=counter.uid
 var hand_size=e.players[0].hand.size()
 view.update_response_clock(deadline)
 expect(e.priority==1 and e.stack.size()==1,"timeout passes priority exactly once while preserving the unresolved spell")
 expect(view.local.is_empty() and view.selection.is_empty() and not view.modal and e.paid_cast_uid==-1,"timeout cancels private selections even with settings open")
 expect(e.players[0].hand.size()==hand_size and not e.players[0].palette.any(func(card):return card.tapped),"uncommitted response is never paid or cast on timeout")
 expect(Clock.remaining(e,deadline)==240,"following response receives a full deadline after timeout")

func run():
 var directory="res://work/test-response-timeout/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(directory)
 app=load("res://main.tscn").instantiate()
 app.settings_path=directory+"/settings.json";app.account_session_path=directory+"/account.json"
 app.tutorial_local_directory=directory+"/tutorials"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(app.tutorial_local_directory))
 root.add_child(app);await process_frame
 app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);view.fast_mode=true;e=view.engine
 check_boundaries()
 check_projection()
 check_ui()
 # The same HUD path is used on Android; verify its native layout as well.
 app.is_android=true;view.is_android=true;app.refresh_ui_metrics();view.responsive.measure(view)
 stack_fixture(true);e.presentation_events.clear();view.reveal_player.reset()
 view.set_response_mode(view.ResponseMode.ON);view.render()
 view.update_response_clock(float(e.response_clock.deadline)-30)
 expect("响应剩余 30 秒" in view.response_prompt.text,"Android response prompt shows the final countdown")
 expect(view.response_prompt.get_rect().size.x>0,"Android countdown keeps a usable prompt area")
 print("RESPONSE TIMEOUT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
