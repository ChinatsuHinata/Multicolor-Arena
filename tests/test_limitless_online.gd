extends SceneTree
const Account=preload("res://scripts/account_client.gd")
const Tournament=preload("res://scripts/tournament_client.gd")
var fixture: Dictionary={}
var failures: Array=[]
var checks=0
var server="ws://127.0.0.1:48065"

func _initialize():call_deferred("run")

func check(value: bool,label: String):
 checks+=1
 if value:print("PASS: ",label)
 else:failures.append(label);push_error(label)

func api(action: String,user: String,extra: Dictionary={}) -> Dictionary:
 var client=Tournament.new();root.add_child(client);client.server_url=server
 var payload={"action":action,"id":int(fixture.limitless_tournament)};payload.merge(extra)
 client.call_deferred("request",payload,fixture.logins[user].token)
 var answer=await client.finished;client.queue_free();return answer

func save_id(user: String,value: String) -> Dictionary:
 var client=Account.new();root.add_child(client);client.server_url=server
 client.call_deferred("update_limitless",value,fixture.logins[user].token)
 var answer=await client.finished
 var result={"ok":answer[0],"id":client.limitless_id};client.queue_free();return result

func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--fixture":fixture=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
 if fixture.is_empty():push_error("Run tests/run_tournaments.py --limitless-only");quit(1);return
 var answer=await api("join","first_player")
 check(not answer.ok,"relay blocks started-source join without a saved ID")
 answer=await save_id("first_player"," DoctorBlack ")
 check(answer.ok and answer.id=="doctorblack","encrypted account action saves normalized Limitless ID")
 var client=Account.new();root.add_child(client);client.server_url=server
 client.call_deferred("submit","login","first_player","TEST_ONLY_password123!")
 var result=await client.finished
 check(result[0] and client.limitless_id=="doctorblack","fresh login restores Limitless ID over relay")
 fixture.logins.first_player.token=client.session_token
 var remember=client.remember_token;client.queue_free()
 client=Account.new();root.add_child(client);client.server_url=server;client.call_deferred("resume",remember)
 result=await client.finished
 check(result[0] and client.limitless_id=="doctorblack","remembered login also restores Limitless ID")
 fixture.logins.first_player.token=client.session_token;client.queue_free()
 answer=await api("join","first_player")
 check(answer.ok and not answer.tournament.joined and answer.tournament.limitless_admission.status=="pending","join submits a pending request without membership")
 answer=await api("checkin","first_player")
 check(not answer.ok,"pending applicant cannot bypass approval with check-in")
 answer=await api("detail","bigcake")
 check(answer.ok and answer.join_requests.total==1,"organizer sees the pending identity request")
 var entry=answer.join_requests.entries[0]
 answer=await api("review_limitless_join","second_player",{"player_id":entry.player_id,"revision":entry.revision,"approve":true})
 check(not answer.ok,"relay rejects unauthorized reviewer")
 answer=await api("review_limitless_join","bigcake",{"player_id":entry.player_id,"revision":entry.revision,"approve":true})
 check(answer.ok and answer.tournament.roster_count==1,"approval enrolls the real source player after registration closed")
 answer=await api("detail","first_player")
 check(answer.ok and answer.tournament.joined and answer.tournament.in_roster,"approved member sees admitted status")
 check(answer.join_requests.is_empty(),"ordinary players cannot read others' applications")
 answer=await save_id("first_player","sss_naoh")
 check(not answer.ok,"approved player cannot swap identity mid-tournament")
 print("LIMITLESS ONLINE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
