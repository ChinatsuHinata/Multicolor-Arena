extends "res://tests/support/rules_base.gd"
const Picker=preload("res://scripts/target_picker.gd")

func choose_path(picker) -> bool:
 for step in range(80):
  if picker.ready():return true
  var choices=picker.available()
  if choices.is_empty():return false
  var chosen=choices[0]
  for atom in choices:
   if atom.kind=="target":chosen=atom;break
  if not picker.select(chosen):return false
 return false

func check_options(options: Array,label: String):
 if options.is_empty():return
 var picker=Picker.new()
 picker.configure(options,label)
 var first=choose_path(picker)
 var target=picker.option() if first else {}
 expect(first and not target.is_empty(),label+" initial choice completes")
 picker.path=[];picker.normalize()
 var second=choose_path(picker)
 expect(second and picker.option()==target,label+" reset and same choice completes")
 if second and label.begins_with("spell "):
  expect(e.Pack.choice_valid(e,options,picker.option()),label+" choice remains legal")

func check_fixed_branch(options: Array,label: String):
 var picker=Picker.new();picker.configure(options,label)
 var fixed=picker.available().filter(func(atom):return atom.kind=="spec" and picker.specs[atom.index].has("fixed_options"))
 expect(not fixed.is_empty(),label+" has a fixed branch")
 if fixed.is_empty():return
 picker.select(fixed[0]);var first=choose_path(picker);var target=picker.option()
 picker.path=[];picker.normalize();picker.select(fixed[0])
 expect(first and choose_path(picker) and picker.option()==target,label+" fixed branch survives reset")

func check_partial(options: Array,label: String):
 var picker=Picker.new();picker.configure(options,label)
 var targets=picker.available().filter(func(atom):return atom.kind=="target")
 expect(not targets.is_empty(),label+" offers a target")
 if targets.is_empty():return
 picker.select(targets[0])
 var finish=picker.available().filter(func(atom):return atom.kind=="finish_group")
 expect(not finish.is_empty(),label+" can finish before its maximum")
 if finish.is_empty():return
 picker.select(finish[0]);var target=picker.option()
 picker.path=[];picker.normalize();picker.select(targets[0])
 finish=picker.available().filter(func(atom):return atom.kind=="finish_group")
 if not finish.is_empty():picker.select(finish[0])
 expect(picker.ready() and picker.option()==target,label+" partial choice survives reset")

func run():
 fresh()
 var a=put("character-soi-006")
 var b=put("53","field",1)
 var c=put("74","field")
 put("7")
 put("165","palette")
 put("166","palette")
 put("spell-fdf-055","grave")
 put("spell-fdf-055","grave")
 put("spell-fdf-055","grave")
 put("spell-fdf-055","hand")
 var refs=[e.ref_target(a),e.ref_target(b),e.ref_target(c)]
 var pack=e.Pack
 check_options(pack.selection([pack.group(refs,0,1,"optional one")],"optional_one"),"optional single target")
 check_options(pack.selection([pack.group(refs,1,1,"required one")],"required_one"),"required single target")
 check_options(pack.selection([pack.group(refs,0,2,"up to two")],"optional_two"),"optional two targets")
 check_partial(pack.selection([pack.group(refs,0,2,"up to two")],"partial_two"),"optional two targets")
 check_options(pack.selection([pack.group(refs,2,2,"two")],"required_two"),"required two targets")
 check_options(pack.selection([pack.group(refs,1,1,"first"),pack.group(refs,1,1,"second")],"stages"),"two stage targets")
 check_options([{"none":true,"mode":"skip"}]+pack.selection([pack.group(refs,0,1,"one")],"mixed"),"fixed and dynamic options")
 var source=put("field-smm-004")
 var trigger={"owner":0,"effect":"castle_exile","source":source.duplicate(true)}
 check_options(pack.trigger_options(e,trigger),"castle exile")
 trigger.effect="tewi_counters"
 check_options(pack.trigger_options(e,trigger),"Tewi counters")
 check_options(e.targets_for("spell-mar-012",0),"shoot moon")
 trigger.effect="field-rei-013"
 check_options(e.Cat.Units.options(e,trigger),"alternate castle")
 for effect in ["character-fdf-119","item-ucs-005","komachi_exile","kyouko_shuffle","n21:SPX-007"]:
  trigger.effect=effect
  trigger.data={"event":"enter"}
  check_options(e.Roster.trigger_options(e,trigger),"trigger "+effect)
 for effect in ["item-ucs-017","spell-fdn-019","character-fdf-112","n21:frog_tap","n21:SPX-005:self"]:
  check_options(e.Roster.activation_options(e,source,effect),"activation "+effect)
 check_fixed_branch(e.Roster.activation_options(e,source,"character-fdf-112"),"doll activation")
 var spell_specs=0
 for id in e.cards:
  if e.cards[id].kind!="符卡":continue
  var options=e.targets_for(id,0)
  if options.any(func(option):return option.has("selection")):
   check_options(options,"spell "+id)
   spell_specs+=1
 expect(spell_specs>0,"actual spell selections were audited")
 print("TARGET_RESELECTION: ",checks," checks; ",failures.size()," failures; ",spell_specs," spell option sets")
 quit(0 if failures.is_empty() else 1)
