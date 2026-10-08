extends "res://tests/support/network_base.gd"
const Series=preload("res://net/series_controller.gd")
const Directory=preload("res://net/cloud_directory.gd")
const ENDPOINT="ws://127.0.0.1:48035"
const Fixtures=preload("res://tests/support/sideboard_fixtures.gd")

func cloud_ready():
 host.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act()),"host preparation acknowledged")
 guest.room_action({"name":"ready"})
 check(await until(func():return host.can_act() and guest.can_act()),"guest preparation acknowledged")

func run():
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 var run_id=str(Time.get_ticks_usec())
 host.initialize("res://work/bo1-sideboard-cloud/%s-host" % run_id);guest.initialize("res://work/bo1-sideboard-cloud/%s-guest" % run_id)
 host.cloud_token="1".repeat(64);guest.cloud_token="2".repeat(64)
 host.cloud_nickname="TEST_ONLY_BO1_HOST";guest.cloud_nickname="TEST_ONLY_BO1_GUEST"
 check(host.create_relay_room(ENDPOINT,Series.BO1_SIDEBOARD,true,"test","TEST_ONLY_BO1").is_empty(),"create new format over local WebSocket relay")
 if not await until(func():return host.transport.relay_seat==1):
  check(false,"local relay fixture is running");host.leave(false);quit(1);return
 guest.join_relay_room(ENDPOINT,host.relay_code,false,2)
 check(await until(func():return host.can_act() and guest.can_act()),"cloud seats synchronize")
 if not failures.is_empty():host.leave(false);guest.leave(false);quit(1);return
 var decks=[Fixtures.deck("70"),Fixtures.deck("68")]
 host.room_action({"name":"deck","deck":decks[0]})
 await until(func():return host.can_act() and guest.can_act())
 guest.room_action({"name":"deck","deck":decks[1]})
 check(await until(func():return host.can_act() and guest.can_act() and guest.room.own_deck==decks[1]),"cloud registered decks acknowledged")
 await cloud_ready()
 check(host.room.status=="sideboarding" and guest.room.status=="sideboarding" and guest.room.leaders==[decks[0].leader,decks[1].leader] and host.authority==null,"relay carries leader reveal and stops before battle")
 var directory=Directory.new();root.add_child(directory);directory.start(ENDPOINT,"3".repeat(64))
 check(await until(func():return directory.rooms.any(func(info):return info.id==host.relay_code and info.format==Series.BO1_SIDEBOARD and info.status=="sideboarding")),"directory publishes new format and preparation status")
 directory.stop()
 var revised=Fixtures.swapped(decks[1],3)
 guest.room_action({"name":"deck","deck":revised})
 check(await until(func():return guest.can_act() and host.can_act() and guest.room.own_deck==revised),"cloud accepts three-card sideboard selection")
 await cloud_ready()
 check(host.room.status=="choosing" and guest.room.status=="choosing","both confirmations open cloud first-player choice")
 var chooser=host if host.series.state.chooser==0 else guest
 chooser.room_action({"name":"first","first":true})
 check(await until(func():return host.can_act() and guest.can_act() and guest.room.status=="playing"),"cloud battle starts after preparation")
 sync_views()
 var cards=host.authority.players[1].deck+host.authority.players[1].hand
 check(cards.filter(func(card):return card.card_id=="100").size()==3,"cloud battle uses the selected reserve cards")
 await concede(1)
 check(host.room.status=="complete" and guest.room.status=="complete","single victory ends the cloud match")
 host.leave(false);guest.leave(false)
 print("BO1 SIDEBOARD CLOUD ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
