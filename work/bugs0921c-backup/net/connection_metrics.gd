extends RefCounted
## RTT uses only this device's monotonic clock; peer clock offsets do not matter.
const STALE_MS=6500
var serial=0
var pending={}
var local_ms=-1
var remote_ms=-1
var local_at=-1
var remote_at=-1
func reset():
 pending.clear();local_ms=-1;remote_ms=-1;local_at=-1;remote_at=-1
func make_ping(now: int) -> Dictionary:
 for id in pending.keys():
  if now-int(pending[id])>10000:pending.erase(id)
 serial+=1;pending[serial]=now
 return {"type":"ping","probe":serial,"rtt":local_ms if local_at>=0 and now-local_at<STALE_MS else -1}
func read_remote(packet: Dictionary,now: int):
 var value=packet.get("rtt",-1)
 if value is int and value>=0 and value<=30000:remote_ms=value;remote_at=now
func make_pong(packet: Dictionary,now: int) -> Dictionary:
 read_remote(packet,now)
 return {"type":"pong","probe":packet.get("probe",-1),"rtt":local_ms if local_at>=0 and now-local_at<STALE_MS else -1}
func accept_pong(packet: Dictionary,now: int):
 var id=packet.get("probe",-1)
 if not id is int or not pending.has(id):return
 var elapsed=now-int(pending[id]);pending.erase(id)
 if elapsed<0 or elapsed>10000:return
 var sample=maxi(1,elapsed)
 local_ms=sample if local_at<0 or now-local_at>=STALE_MS else roundi(lerpf(float(local_ms),float(sample),0.35))
 local_at=now;read_remote(packet,now)
func caption(now: int) -> String:
 var own=str(local_ms)+" ms" if local_at>=0 and now-local_at<STALE_MS else "测量中"
 var other=str(remote_ms)+" ms" if remote_at>=0 and now-remote_at<STALE_MS else "测量中"
 return "你 "+own+" · 对手 "+other
