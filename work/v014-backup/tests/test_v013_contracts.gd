extends "res://tests/test_v011_rules.gd"
func board():
 fresh()
 for who in [0,1]:
  for id in ["164","165","166","167","168"]:
   for i in range(3):put(id,"palette",who)
  for id in ["7","character-fdf-091","character-fdn-038","82","character-fdf-098"]:put(id,"field",who)
  for id in ["7","8","character-mar-023","spell-fdf-028","spell-fdf-047","spell-fdf-049","character-fdf-029","spell-fdf-045","character-fdn-045"]:put(id,"grave",who)
  for id in ["7","8","53","spell-fdf-049","spell-mar-002"]:put(id,"hand",who)
  put("170","field",who)
  put("164","field",who)
  var timed=put("spell-fdf-040","field",who);timed.timer=2
 var pending_card=e.make_card("96",1,"stack")
 e.stack.append({"id":777,"kind":"card","card":pending_card,"owner":1,"name":"待反制符卡","target":{"player":0}})
func run():
 var args=OS.get_cmdline_user_args();var start=int(args[0]) if not args.is_empty() else 0;var limit=int(args[1]) if args.size()>1 else 40
 var ids=e.Cat.SPELLS if e!=null else Roster.Cat.SPELLS
 var completed=[]
 for id in ids.slice(start,start+limit):
  board();print("CONTRACT ",id)
  var choices=e.targets_for(id,0);var t=e.Pack.ai_target(e,0,choices,id)
  if t.is_empty():print("NO LEGAL TARGET ",id);continue
  expect(e.Pack.choice_valid(e,choices,t),"valid choice "+id)
  var c=e.make_card(id,0,"stack");c.cast_x=t.get("x",0)
  e.damage_context={"source":c,"combat":false,"single":false}
  expect(e.Cat.spell_resolve(e,{"card":c,"owner":0,"target":t,"kind":"card"}),"contract resolves "+id)
  settle();expect(e.pending.is_empty(),"continuations complete "+id);completed.append(id)
 print("V013_CONTRACTS: ",checks," checks; ",failures," failures; resolved ",completed.size())
 quit(1 if failures else 0)
