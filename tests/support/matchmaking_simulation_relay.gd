extends "res://relay/server.gd"
## Only the initial pairing batch is held. Authentication and the 60-second clock are real.
var batch_released=false

func start():
 var args=OS.get_cmdline_user_args();var bind=args.find("--bind")
 if not args.has("--test-matchmaking-simulation") or bind<0 or bind+1>=args.size() or args[bind+1]!="127.0.0.1":
  push_error("Matchmaking simulation requires --test-matchmaking-simulation --bind 127.0.0.1");quit(2);return
 super.start()

func tick_matches(now: int):
 if batch_released:super.tick_matches(now)

func handle_packet(id: int,data: PackedByteArray,channel: int):
 if data.size()>=4 and data.size()<=2048 and data.slice(0,4).get_string_from_ascii()=="MCR1":
  var input=JSON.parse_string(data.slice(4).get_string_from_utf8())
  if input is Dictionary and input.get("kind","")=="test_release_batch":
   if clients.has(id) and clients[id].role=="queue" and match_queue.entries.size()==6:batch_released=true
   return
 super.handle_packet(id,data,channel)
