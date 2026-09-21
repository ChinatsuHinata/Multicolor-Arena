extends SceneTree
const Metrics=preload("res://net/connection_metrics.gd")
var checks=0
var failures=[]
func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)
func _init():
 var a=Metrics.new();var b=Metrics.new()
 check(a.caption(0)=="你 测量中 · 对手 测量中","no fabricated initial latency")
 var request=a.make_ping(1000)
 # The peer's local clock is deliberately unrelated to the sender's clock.
 var reply=b.make_pong(request,100000)
 a.accept_pong(reply,1120)
 check(a.local_ms==120,"RTT ignores remote clock offset")
 request=b.make_ping(100010);reply=a.make_pong(request,1130);b.accept_pong(reply,100150)
 check(b.local_ms==140 and b.remote_ms==120,"both directions measured and exchanged")
 request=a.make_ping(2000);reply=b.make_pong(request,101000);a.accept_pong(reply,2100)
 check(a.local_ms==113 and a.remote_ms==140,"smoothed latency includes peer measurement")
 var old=a.local_ms;a.accept_pong(reply,2200)
 check(a.local_ms==old,"duplicate pong cannot alter measurement")
 a.accept_pong({"probe":900000,"rtt":-500},2300)
 check(a.local_ms==old and a.remote_ms==140,"unmatched pong ignored")
 a.read_remote({"rtt":"fast"},2400);a.read_remote({"rtt":900000},2400)
 check(a.remote_ms==140,"invalid peer latency rejected")
 check(a.caption(9000)=="你 测量中 · 对手 测量中","stale samples not shown as current")
 a.reset();check(a.pending.is_empty() and a.local_ms==-1 and a.remote_ms==-1,"disconnect clears stale latency")
 print("V0181 LATENCY ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
