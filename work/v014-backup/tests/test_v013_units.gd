extends "res://tests/test_v013_contracts.gd"
func run():
 var args=OS.get_cmdline_user_args();var offset=int(args[0]) if not args.is_empty() else 0
 var ids=JSON.parse_string(FileAccess.get_file_as_string("res://work/v013/new-ids.json")).filter(func(id):return not id.begins_with("spell-"))
 for id in ids.slice(offset,offset+45):
  board();e.stack=[];print("UNIT CONTRACT ",id)
  var c=put(id);c.leader_counters=1
  e.Extra.on_enter(e,c);settle()
  for phase in ["prepare","main","end"]:e.Roster.on_phase(e,phase);settle()
  if c.zone=="field":
   e.Roster.on_attack(e,c);e.Cat.Units.on_block(e,c);e.Cat.Units.on_blocked(e,c);settle()
   for stat in ["power","health","spirit"]:e.stat(c,stat)
   e.move_to(c,"grave",false);settle()
  expect(e.pending.is_empty(),"entry/phase/death continuations complete "+id)
 print("V013_UNITS: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
