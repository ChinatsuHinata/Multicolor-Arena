extends "res://tests/support/network_base.gd"
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
const Series=preload("res://net/series_controller.gd")
const Codec=preload("res://net/state_codec.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")

var random_mode="--random" in OS.get_cmdline_user_args()
var format_value=Series.EXPLORATION_RANDOM if random_mode else Series.EXPLORATION
var preset=G.deck(random_mode)
var spells=G.RANDOM_SPELLS if random_mode else G.SPELLS

func run():
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 var run_id=str(Time.get_ticks_usec())
 host.initialize("res://work/gensokyo-exploration/network/"+run_id+"-host")
 guest.initialize("res://work/gensokyo-exploration/network/"+run_id+"-guest")
 check(host.create_room(format_value,true,48071,"127.0.0.1","official").is_empty(),"fixed-mode room listens on loopback")
 check(guest.join_room("127.0.0.1",48071).is_empty(),"guest joins fixed mode")
 if not await until(func():return not host.applicant.is_empty()):
  check(false,"fixed-mode approval arrives: "+host.notice+" / "+guest.notice);host.leave(false);guest.leave(false);quit(1);return
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both fixed-mode clients connect")
 check(guest.room.format==format_value and guest.room.own_deck==preset,"guest receives format and preset without deck registration")
 await prepare()
 check(host.authority.players.all(func(p):return p.leader.card_id==preset.leader and (p.deck+p.hand).size()==50),"authority starts both fixed decks")
 var e=host.authority
 for p in e.players:
  for zone in ["hand","palette","field","grave","exile"]:p[zone]=[]
  p.potato=false;p.mulligan_done=true;p.turns=3
 e.phase="main";e.active=1;e.priority=1;e.turn=6;e.pending={};e.presentation_events.clear()
 var resource=e.make_card(spells[0],1,"palette");e.players[1].palette.append(resource)
 for i in range(2):e.players[1].palette.append(e.make_card(spells[1],1,"palette"))
 var source=e.make_card(spells[2],1,"hand");e.players[1].hand.append(source)
 host.sequence+=1;host.publish([])
 check(await until(func():return guest.sequence==host.sequence and not guest.snapshots.is_empty()),"discovery fixture synchronized")
 sync_views()
 check(guest.submit({"name":"commit_cast","args":[source.uid,{"none":true},e.payment(1,e.cast_cost(1,source)).plan]}).is_empty(),"guest submits discovery cast")
 check(await until(func():return source.zone=="stack" and guest.can_act() and guest.sequence==host.sequence),"authority accepts guest discovery cast")
 sync_views()
 check(host.submit({"name":"pass_priority","args":[]}).is_empty(),"host passes response")
 check(await until(func():return host.can_act() and guest.can_act() and e.priority==1),"response pass acknowledged")
 sync_views();guest.submit({"name":"pass_priority","args":[]})
 check(await until(func():return e.pending.get("trigger",{}).get("effect","")=="exploration:take" and guest.sequence==host.sequence and guest.can_act()),"network resolution opens three-card discovery")
 sync_views()
 var spec=e.pending.options[0];var offers=spec.selection[0].pool
 check(offers.size()==3 and offers.all(func(offer):return e.cards[offer.outside_id].kind in ["道具","结界"]),"network travel bag offers three items or barriers")
 if not random_mode:check(G.budgets(e,1)[0]==2 and e.cards[offers[0].outside_id].get("variable_cost","").is_empty() and G.full_budget_payment(e,1,offers[0].outside_id,2),"network authority guarantees a payable fixed card using the post-cast remaining budget")
 check(guest.latest_snapshot.projection.state.pending.options==e.pending.options,"guest sees exact authority-generated choices")
 check(host.latest_snapshot.projection.state.pending.kind=="network_wait","host waits while guest discovers")
 var saved=host.Journal.load_from(host.storage+"/host.bin");var restored=Duel.new()
 Codec.restore(restored,saved.engine)
 check(restored.pending==e.pending and restored.rng.state==e.rng.state,"persisted room restores discovery and RNG")
 var selection=spec.duplicate(true);selection.erase("selection");selection.picks=[[offers[1]]]
 guest.submit({"name":"choose_effect","args":[selection]})
 check(await until(func():return e.players[1].hand.size()==1 and e.pending.get("kind","")=="reveal_review" and guest.sequence==host.sequence and guest.can_act()),"guest selection adds one card and begins reveal review")
 check(e.players[1].hand[0].card_id==offers[1].outside_id,"authority grants only chosen discovery")
 sync_views();host.submit({"name":"confirm_revealed","args":[e.pending.serial]})
 check(await until(func():return e.pending.is_empty() and host.can_act() and guest.can_act()),"opponent acknowledgment completes network resolution")
 sync_views();await concede(1)
 check(host.room.status=="complete" and guest.room.status=="complete","single game completes on both clients")
 host.room_action({"name":"rematch"})
 check(await until(func():return guest.room.status=="lobby" and host.can_act() and guest.can_act()),"network rematch returns to fixed mode")
 check(guest.room.format==format_value and guest.room.own_deck==preset,"network rematch restores preset")
 host.leave(false);guest.leave(false);host.queue_free();guest.queue_free();await process_frame
 print("GENSOKYO EXPLORATION NETWORK: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
