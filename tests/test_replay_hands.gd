extends "res://tests/support/network_base.gd"
const Archive=preload("res://scripts/replay_archive.gd")
const Observer=preload("res://net/observer_projection.gd")
var watcher
var expected={}
class CaptureTransport:
 extends RefCounted
 var sent=[]
 func send_to(_id,message):sent.append(message)
func remember():
 expected[host.series.state.game_id+":"+str(host.sequence)]=host.authority.players.map(func(p):return p.hand.duplicate(true))
func verify(archive,title: String):
 check(archive.metadata.get("hands","")=="both",title+" declares complete hands")
 var checked=0
 for i in range(archive.frames.size()):
  var packet=archive.frame(i);var key=packet.game_id+":"+str(packet.sequence)
  var players=packet.projection.state.players
  check(players.all(func(p):return p.hand.all(func(c):return c.card_id!="back" and packet.projection.definitions.has(c.card_id))),title+" frame "+str(i)+" has readable hands and definitions")
  check(players.all(func(p):return p.deck.all(func(c):return c.card_id=="back")),title+" libraries remain hidden")
  if expected.has(key):
   check(players.map(func(p):return p.hand)==expected[key],title+" exact hands at "+key);checked+=1
 check(checked>0,title+" checked authoritative steps")
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/replay-hands/"+str(Time.get_ticks_usec()))
 var decks=Store.load_decks().decks
 host=Session.new();guest=Session.new();watcher=Session.new()
 for net in [host,guest,watcher]:root.add_child(net)
 host.initialize(Store.Paths.root().path_join("host"));guest.initialize(Store.Paths.root().path_join("guest"));watcher.initialize(Store.Paths.root().path_join("watcher"))
 var offers=[0,0,0]
 host.replay_finished.connect(func(_a):offers[0]+=1)
 guest.replay_finished.connect(func(_a):offers[1]+=1)
 watcher.replay_finished.connect(func(_a):offers[2]+=1)
 check(host.create_room(3,false,47993,"127.0.0.1").is_empty(),"host starts")
 guest.join_room("127.0.0.1",47993)
 check(await until(func():return not host.applicant.is_empty()),"guest requests seat")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"players connected")
 watcher.join_spectator("127.0.0.1",47993)
 check(await until(func():return watcher.connected),"watcher connected")
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 await until(func():return guest.sequence==host.sequence)
 for loser in [1,0,1]:
  await prepare();remember()
  check(await until(func():return watcher.sequence==host.sequence),"watcher sees new round")
  check(guest.latest_snapshot.projection.state.players[0].hand.all(func(c):return c.card_id=="back"),"live guest cannot see opponent hand")
  check(watcher.latest_snapshot.projection.state.players.all(func(p):return p.hand.all(func(c):return c.card_id=="back")),"live watcher cannot see either hand")
  var capture=CaptureTransport.new()
  host.replay_exchange.serve(1,{"room_id":host.room_id,"match_id":host.series.state.match_id,"offset":0,"keys":[host.recording.frame_key(0)]},capture)
  check(capture.sent.is_empty(),"full replay request refused before entire BO3 ends")
  var e=host.authority
  var c=e.make_card("53",1,"hand");c.art_id="replay-instance-art";c.counters={"power":2};e.players[1].hand.append(c)
  host.sequence+=1;check(host.persist(),"hand change persisted");host.publish([],false,true);remember()
  check(await until(func():return guest.sequence==host.sequence and watcher.sequence==host.sequence and host.can_act()),"hand change synchronized")
  sync_views()
  if loser==1 and host.room.round==1:
   for i in range(20):
    c.counters.power=i;host.sequence+=1;host.publish([],false,true);remember()
    check(await until(func():return guest.sequence==host.sequence and host.can_act()),"additional replay step synchronized")
    sync_views()
  await concede(loser);remember()
  if host.room.status!="complete":check(offers==[0,0,0],"no disclosure or save prompt between games")
 check(await until(func():return offers==[1,1,1],20),"all viewers receive complete replay before save prompt")
 for i in range(3):
  var net=[host,guest,watcher][i];var archive=net.recording
  verify(archive,["host","guest","watcher"][i])
  var path=Store.Paths.root().path_join("replay/"+str(i)+".mreply")
  check(archive.save(path).has("path"),"complete replay saves")
  var loaded=Archive.read(path)
  check(loaded.has("archive"),"complete replay reads and validates")
  if loaded.has("archive"):check(loaded.archive.frame(0)==archive.frame(0),"file reading preserves both hands exactly")
  var recovered=Archive.new();recovered.begin_capture(net.storage+"/capture.bin",host.series.state.match_id)
  check(recovered.frame(0)==archive.frame(0),"capture recovery preserves disclosed hands")
  var original=archive.frames[0].duplicate(true);var malformed=original.duplicate(true)
  malformed.game="another-game"
  check(not archive.replace_frame(0,malformed,archive.definitions) and archive.frames[0]==original,"disclosure rejects mismatched frame without changing recording")
 # Legacy projections remain readable without inventing hidden card identities.
 var old=Archive.new();var e=host.authority
 old.record({"game_id":"legacy","sequence":1,"room":host.room,"projection":Observer.build(e,[],0)},0)
 check(old.frame(0).projection.state.players[1].hand.all(func(c):return c.card_id=="back"),"legacy hidden cards remain hidden")
 old.record({"game_id":"legacy","sequence":2,"room":host.room,"projection":Observer.build(e,[],0,true)},0)
 check(old.metadata.get("hands","")!="both","mixed recovered legacy archive does not claim complete hands")
 for net in [host,guest,watcher]:net.leave(false);net.queue_free()
 print("REPLAY HANDS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
