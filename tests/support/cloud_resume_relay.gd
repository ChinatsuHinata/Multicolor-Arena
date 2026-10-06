extends "res://relay/server.gd"
## Loopback-only packet-switch fixture. Authentication is outside this test.
func start():
 var args=OS.get_cmdline_user_args()
 var bind=args.find("--bind")
 if not args.has("--test-resume") or bind<0 or bind+1>=args.size() or args[bind+1]!="127.0.0.1":
  push_error("Cloud resume fixture requires --test-resume --bind 127.0.0.1");quit(2);return
 super.start()

func verify_client(id: int,token: String,next_message: Dictionary={}):
 if not clients.has(id):return
 var index=["1".repeat(64),"2".repeat(64),"3".repeat(64),"4".repeat(64)].find(token)
 if index<0:reject(id,"Unknown test-only identity");return
 var name="TEST_ONLY_RESUME_"+str(index)
 clients[id].account=name;clients[id].device=name;clients[id].platform="android";clients[id].nickname=name;clients[id].token=token
 if not next_message.is_empty():register(id,next_message)
