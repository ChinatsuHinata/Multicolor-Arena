extends RefCounted
## One deadline per priority window, shared by local play and the room authority.
const LIMIT_SECONDS=240.0
const DISPLAY_SECONDS=30

static func window_key(e) -> String:
 if e==null or e.winner!=-2 or e.phase in ["mulligan","over"] or not e.pending.is_empty() or not e.entry_choices.is_empty():return ""
 if e.phase=="main" and e.active==e.priority and e.stack.is_empty() and e.combat.is_empty():return ""
 return JSON.stringify([e.turn,e.phase,e.active,e.priority,e.passes,e.stack.map(func(entry):return entry.id),e.combat.get("step",""),e.combat.get("attacker",{}).get("uid",0)])

static func sync(e,now: float=-1.0):
 if now<0:now=Time.get_unix_time_from_system()
 var key=window_key(e)
 if key.is_empty():e.response_clock={}
 elif e.response_clock.get("key","")!=key:
  e.response_clock={"key":key,"owner":e.priority,"deadline":now+LIMIT_SECONDS}

static func remaining(e,now: float=-1.0) -> int:
 if now<0:now=Time.get_unix_time_from_system()
 if e.response_clock.is_empty() or e.response_clock.get("key","")!=window_key(e):return -1
 return maxi(0,ceili(float(e.response_clock.deadline)-now))

static func expired(e,now: float=-1.0) -> bool:
 return remaining(e,now)==0

static func caption(e,viewer: int,now: float=-1.0) -> String:
 var seconds=remaining(e,now)
 if seconds<0 or seconds>DISPLAY_SECONDS:return ""
 return ("响应剩余 %d 秒" if e.priority==viewer else "对手响应剩余 %d 秒") % seconds
