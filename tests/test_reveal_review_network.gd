extends "res://tests/support/network_base.gd"
const Fixture=preload("res://tests/support/reveal_review_fixtures.gd")
const Remote=preload("res://net/remote_duel.gd")

func send(seat: int,command: Dictionary):
 sync_views()
 var session=host if seat==0 else guest
 check(session.submit(command).is_empty(),"submit "+command.name+" from seat "+str(seat))
 check(await until(func():return host.sequence==guest.sequence and not session.busy),"command receipt and shared state synchronize")
 sync_views()

func run():
 var directory="res://work/reveal-review-network/"+str(Time.get_ticks_usec())
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize(directory+"/host");guest.initialize(directory+"/guest")
 host.error_raised.connect(func(_message):pass);guest.error_raised.connect(func(_message):pass)
 check(host.create_room(3,true,48048,"127.0.0.1","test").is_empty(),"create a local two-player room")
 guest.join_room("127.0.0.1",48048)
 check(await until(func():return not host.applicant.is_empty()),"guest requests connection")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both players connect")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 check(await until(func():return guest.sequence==host.sequence),"deck registration synchronizes")
 await prepare()
 for who in [0,1]:
  var fixture=Fixture.ability(host.authority,who)
  var declaration=host.authority.stack.back().history_index
  host.sequence+=1;host.persist();host.publish(host.authority.presentation_events);host.authority.presentation_events.clear()
  check(await until(func():return guest.sequence==host.sequence),"ability announcement synchronizes")
  await send(host.authority.priority,{"name":"pass_priority","args":[]})
  await send(host.authority.priority,{"name":"pass_priority","args":[]})
  check(host.authority.pending.kind=="effect_choice" and guest.latest_snapshot.projection.state.pending.get("kind","")!="reveal_review","the opponent is not asked to confirm before the owner's selection")
  var spec=host.authority.pending.options[0]
  await send(who,{"name":"choose_effect","args":[{"selection_id":spec.get("selection_id",""),"picks":[[]]}]})
  check(host.authority.pending.kind=="reveal_review" and guest.latest_snapshot.projection.state.pending.kind=="reveal_review","both seats enter the authoritative review state")
  check(guest.latest_snapshot.projection.state.pending.cards.size()==fixture.shown.size(),"all shown cards reach the remote opponent")
  check(guest.latest_snapshot.projection.state.history[declaration].revealed_cards.size()==3,"the original ability record synchronizes every revealed card")
  var serial=host.authority.pending.serial
  var before=host.Codec.capture(host.authority)
  await send(who,{"name":"confirm_revealed","args":[serial]})
  await send(1-who,{"name":"pass_priority","args":[]})
  check(host.Codec.capture(host.authority)==before,"wrong-seat confirmation and ordinary actions leave the review locked")
  var recovery=host.make_snapshot(1-who,[],true)
  var remote=Remote.new();remote.seat=1-who;remote.apply_snapshot(recovery.projection)
  check(remote.pending.kind=="reveal_review" and remote.pending.cards.size()==3,"recovery without animations restores the complete confirmation panel")
  await send(1-who,{"name":"confirm_revealed","args":[serial]})
  check(host.authority.pending.is_empty() and guest.latest_snapshot.projection.state.pending.is_empty(),"the correct confirmation releases both players together")
  var historical=guest.latest_snapshot.projection.state.history[declaration].revealed_cards
  check(historical.size()==3 and historical.map(func(c):return c.uid)==fixture.shown.map(func(c):return c.uid),"remote history retains all revealed cards after confirmation")
  var confirmed=host.make_snapshot(1-who,[],true).projection
  check(confirmed.state.history[declaration].revealed_cards==historical and historical.all(func(c):return confirmed.definitions.has(c.card_id)),"reconnect without presentation events retains history artwork and card definitions")
  var sequence=host.sequence
  await send(1-who,{"name":"confirm_revealed","args":[serial]})
  check(host.sequence==sequence,"duplicate confirmation cannot resolve another effect")
 var final_card=host.authority.make_card("164",0,"hand");host.authority.players[0].hand.append(final_card)
 host.authority.begin_reveal_resolution({"id":999,"kind":"ability","owner":0,"source":final_card,"name":"终局展示"})
 host.authority.reveal_card(final_card);host.authority.lose(1,"生命为零");host.authority.pump_choices()
 host.sequence+=1;host.persist();host.publish(host.authority.presentation_events);host.authority.presentation_events.clear()
 check(await until(func():return guest.sequence==host.sequence),"the final review synchronizes before match results")
 check(host.series.state.status=="playing" and host.series.state.scores==[0,0],"the series does not score the game before confirmation")
 await send(1,{"name":"confirm_revealed","args":[host.authority.pending.serial]})
 check(host.series.state.status=="between" and host.series.state.scores==[1,0],"confirmation publishes the final result exactly once")
 host.transport.close();guest.transport.close();host.queue_free();guest.queue_free();await process_frame
 print("REVEAL REVIEW NETWORK: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
