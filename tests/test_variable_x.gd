extends "res://tests/support/rules_base.gd"
const Picker=preload("res://scripts/target_picker.gd")
const XInput=preload("res://scripts/x_value_input.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Gateway=preload("res://net/command_gateway.gd")
const Codec=preload("res://net/state_codec.gd")
const View=preload("res://scripts/duel_view.gd")
const StackPanel=preload("res://scripts/duel_stack.gd")

func legal_options(engine,c: Dictionary,who: int=0) -> Array:
 return engine.VariableChoice.payable(engine,who,engine.targets_for(c.card_id,who,c.uid),func(target):return engine.cast_cost_options(who,c,target))
func values(options: Array) -> Array:
 var result=[]
 for option in options:
  if int(option.x) not in result:result.append(int(option.x))
 result.sort();return result
func resources(ids: Array,who: int=0):
 for id in ids:put(id,"palette",who)
func run():
 bounds();cast_values();picker_flow();sacrifice_x();inputs();network()
 print("VARIABLE_X: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
func cast_values():
 for x in [0,1,3]:
  fresh();resources(["167","167","164","164","164"]);put("spell-fdf-018","field",1).timer=6
  var c=put("111","hand");var target={"player":0,"x":x,"mode":"X = %d" % x}
  expect(e.commit_cast(0,c.uid,target,e.payment(0,e.cast_cost(0,c,target)).plan).is_empty(),"Origin actually casts with X = %d" % x)
  expect(e.Extra.cost_value(e,c)==2+x,"Origin's stack cost includes declared X = %d" % x)
  var triggers=(e.triggers+e.stack).filter(func(t):return t.get("effect","")=="spell-fdf-018")
  expect(triggers.size()==(1 if x<=1 else 0),"Lie Detector uses the full cost before cast observers run: X = %d" % x)
  expect(e.Pack.spell_options(e,"spell-rei-012",1).is_empty()==(x>1),"three-cost counter eligibility uses the full X spell cost")
  var view=View.new();view.engine=e;var panel=StackPanel.new();panel.view=view
  expect(view.variable_cost_caption(c).contains("共 %d 费" % (2+x)) and panel.entry_caption(e.stack[0]).contains("共 %d 费" % (2+x)),"stack caption shows resolved numeric costs")
  panel.free();view.free()
  for seat in [0,1]:
   var remote=Remote.new();remote.seat=seat;remote.apply_snapshot(SeatView.build(e,seat))
   expect(remote.Extra.cost_value(remote,remote.find_card(c.uid))==2+x,"both network seats retain the full declared cost")
  var restored=Duel.new();Codec.restore(restored,Codec.capture(e))
  expect(restored.Extra.cost_value(restored,restored.find_card(c.uid))==2+x,"save/restore retains the declared X cost")

 fresh();mana();var ally=put("53");var spell=put("124","hand")
 var target=e.ref_target(ally);target.x=3;target.mode="X = 3"
 expect(e.commit_cast(0,spell.uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan).is_empty(),"double-X counters spell actually casts")
 expect(e.Extra.cost_value(e,spell)==7,"double-X includes fixed one plus twice the declared three")
 one();expect(ally.plus_counters==3 and spell.zone=="grave" and e.Extra.cost_value(e,spell)==1,"resolved spells use X for their effect and return to fixed cost outside the stack")

 fresh();mana();put("character-mar-021");put("24");put("24");put("spell-fdn-010")
 spell=put("spell-fdf-024","hand");target={"none":true,"x":3,"mode":"X = 3"}
 var plan=e.payment(0,e.cast_cost(0,spell,target)).plan
 expect(plan.size()==5 and e.commit_cast(0,spell.uid,target,plan).is_empty(),"discounted time spell actually pays its reduced cost")
 var keystones=(e.triggers+e.stack).filter(func(t):return t.get("effect","")=="spell-fdn-010")
 expect(keystones.size()==1 and keystones[0].data.value==7,"cast-trigger token count includes doubled X independently of discounts")
 settle();expect(e.players[0].field.filter(func(c):return c.get("token",false) and e.cards[c.card_id].kind=="结界").size()==7,"the cast trigger actually creates seven keystones")
 expect(spell.zone=="field" and spell.timer==3 and e.Extra.cost_value(e,spell)==1,"time spells retain X for timers while battlefield cost treats X as zero")

 fresh();mana();put("166").tapped=true;put("164").tapped=true;spell=put("character-fdf-ex03","hand");target={"none":true,"x":3,"mode":"X = 3"}
 expect(e.commit_cast(0,spell.uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan).is_empty() and e.Extra.cost_value(e,spell)==5,"variable-cost units include X while being used")
 settle();expect(spell.zone=="field" and spell.plus_counters==3 and e.Extra.cost_value(e,spell)==2,"unit entry still receives X counters and resets its battlefield cost")

 fresh();mana();spell=put("111","hand");target={"player":0,"x":3,"mode":"X = 3"}
 expect(e.commit_cast(0,spell.uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan).is_empty(),"Origin casts before copying")
 for copied_x in [-1,6]:
  var entry=e.stack[0];e.Cat.copy_spell(e,entry,copied_x)
  e.choose_effect(e.pending.options[0])
  expect(e.Extra.cost_value(e,e.stack.back().card)==(5 if copied_x<0 else 8),"spell copies use their inherited or changed X cost")
 var fixed=e.make_card("spell-fdf-012",0,"stack");fixed.cast_x=3
 expect(e.Extra.cost_value(e,fixed)==2,"X used for sacrifices does not add a nonexistent X color cost")

 fresh();mana();spell=put("111","exile");spell.free_exile_owner=0
 target={"player":0,"x":0,"mode":"X = 0"}
 expect(e.commit_cast(0,spell.uid,target,[]).is_empty() and e.Extra.cost_value(e,spell)==2,"free use declares zero X and retains the fixed color value")
func bounds():
 fresh();resources(["167","167","164","164","164","165","165"])
 var c=put("111","hand")
 var before=JSON.stringify([e.players,e.stack,e.revision,e.next_uid])
 expect(values(legal_options(e,c))==[0,1,2,3],"X max accounts for fixed blue costs and actual yellow resources")
 expect(before==JSON.stringify([e.players,e.stack,e.revision,e.next_uid]),"precomputing X does not spend resources or change the duel")
 fresh();put("53");resources(["166","164","164","164","164","164"]);c=put("124","hand")
 expect(values(legal_options(e,c))==[0,1,2],"two yellow per X rounds the affordable maximum down")
 fresh();resources(["167","166","166","166","166","166"]);c=put("151","hand")
 expect(values(legal_options(e,c))==[0,1,2],"two green per X also uses the multiplier")
 fresh();resources(["166","166","164","164","164"]);c=put("character-fdf-ex03","hand")
 expect(values(legal_options(e,c))==[0,1,2,3],"variable-cost units offer the same numeric declaration")
 fresh();put("68");resources(["164","167","167","167","167","167"]);c=put("spell-fdf-024","hand")
 expect(values(legal_options(e,c))==[0,1,2],"catalogue X spell includes its fixed yellow and double blue costs")
 var ran=put("24");put("24")
 expect(values(legal_options(e,c))==[0,1,2,3],"static blue discounts increase the legal X maximum")
 ran.ran_discount_disabled=true
 expect(values(legal_options(e,c))==[0,1,2,3],"odd blue remainder and one discount still permit X three")
 for unit in e.units(0):
  if unit.card_id=="24":unit.ran_discount_disabled=true
 expect(values(legal_options(e,c))==[0,1,2],"disabled discounts recompute the maximum")
 fresh();resources(["165","164","164"]);var permanent=put("164","field");permanent.tapped=true;c=put("spell-fdf-051","hand")
 var picker=Picker.new();var options=legal_options(e,c);picker.configure(options,"optional-X")
 expect(picker.x_values==[0,1,2],"optional-target X spell precomputes its legal range")
 picker.select({"kind":"x","value":2});picker.select_target(e.ref_target(permanent))
 expect(picker.ready() and picker.option().x==2 and e.Pack.choice_valid(e,options,picker.option()),"numeric X selects the correct optional-target specification")
 fresh();resources(["168","168","164"])
 for i in range(10):put("53","field",i%2)
 c=put("character-ucs-069","hand");c.leader=true
 expect(values(legal_options(e,c))==[0,1,2,3,4,5,6],"Miko's discount permits X greater than the number of resources")
 fresh();put("character-fdf-098");put("character-fdf-098");c=put("character-fdf-ex03","hand")
 expect(values(legal_options(e,c))==[2],"paired mana pays both colors together and permits only its exact payable X")
 fresh();resources(["167","167","164","164"]);put("spell-ucs-031","field",1);c=put("111","hand")
 expect(values(legal_options(e,c))==[0,1],"global additional costs reduce the X maximum")
 fresh();var oni=put("character-fdf-110","field",1);put("spell-fdn-015","field",1)
 resources(["166","164","164","164"]);c=put("124","hand")
 expect(values(legal_options(e,c))==[0],"mandatory taxed target is included in the precomputed X maximum")
 put("53","field",1)
 expect(values(legal_options(e,c))==[0,1],"an untaxed legal target can retain a higher X")
 fresh();put("character-fdf-ex03");var bearer=put("53");bearer.plus_counters=3
 resources(["164"]);c=put("spell-fdf-053","hand")
 e.stack=[{"kind":"card","id":27,"owner":1,"card":e.make_card("99",1,"stack"),"target":{"player":0},"name":"target"}]
 options=legal_options(e,c)
 expect(values(options)==[0,1,2,3] and options.all(func(option):return option.counter_payment==option.x),"counter payment permits X independently of spells currently on the stack")
 picker=Picker.new();picker.configure(options,"counter-payment")
 expect(picker.x_values==[0,1,2,3] and not picker.ready(),"X is entered before choosing counter payment")
 picker.select({"kind":"x","value":3})
 for i in range(12):
  if picker.ready():break
  var atoms=picker.available();if atoms.is_empty():break
  picker.select(atoms[0])
 expect(picker.ready() and e.Pack.choice_valid(e,options,picker.option()),"X selection retains the chosen counter-payment groups")
 var target=picker.option()
 expect(e.commit_cast(0,c.uid,target,e.payment(0,e.cast_cost(0,c,target)).plan).is_empty(),"the full counter-funded X declaration actually commits")
 fresh();resources(["167","167","164","164"]);c=put("111","hand")
 c.zone="exile";e.players[0].hand.erase(c);e.players[0].exile.append(c);c.free_exile_owner=0
 expect(values(legal_options(e,c))==[0],"free casts restrict X to zero")
 fresh();resources(["167","167","164","164"]);c=put("111","hand")
 target={"player":1,"x":2,"mode":"X = 2"}
 expect(e.commit_cast(0,c.uid,target,e.payment(0,e.cast_cost(0,c,target)).plan).is_empty(),"maximum affordable X casts with a chosen target")
 var copied=e.Cat.retarget_options(e,e.stack.back(),-1,true)
 expect(not copied.is_empty() and copied.all(func(option):return option.x==2),"retargeting preserves declared X after its resources were spent")
func picker_flow():
 var picker=Picker.new()
 picker.configure([{"none":true,"x":0,"mode":"X = 0"},{"none":true,"x":12,"mode":"X = 12"}],"simple")
 expect(picker.available().all(func(atom):return atom.kind=="x") and not picker.ready(),"X values are numeric steps instead of mode buttons")
 expect(not picker.select({"kind":"x","value":1}),"picker rejects a value outside the legal set")
 picker.select({"kind":"x","value":12})
 expect(picker.ready() and picker.option().x==12,"typed multi-digit X retains its original declaration")
 picker.select({"kind":"x","value":0})
 expect(picker.ready() and picker.option().x==0,"X can be revised before committing")
 picker.path=[];picker.normalize()
 expect(not picker.ready() and picker.selected_x()==-1,"reselect requires a fresh X declaration")
func sacrifice_x():
 fresh();put("53");put("53");var spell=put("spell-fdf-012","hand")
 var options=e.targets_for(spell.card_id,0,spell.uid);var picker=Picker.new();picker.configure(options,"cats-walk")
 expect(picker.x_values==[0,1,2],"Cat's Walk maximum follows available sacrifice units")
 picker.select({"kind":"x","value":2})
 for i in range(16):
  if picker.ready():break
  var atoms=picker.available();if atoms.is_empty():break
  picker.select(atoms[0])
 expect(picker.ready() and picker.option().picks[0].size()==2 and e.Pack.choice_valid(e,options,picker.option()),"Cat's Walk typed X requires exactly that many sacrifices")
 fresh();var alice=put("character-fdf-112")
 for i in range(3):e.Cat.tokens(e,0,1,"人偶",1,1,1,["黄"])
 options=e.activation_options(alice,"character-fdf-112");picker=Picker.new();picker.configure(options,"alice-mode")
 var branches=picker.available().filter(func(atom):return atom.kind=="mode" and atom.value=="牺牲人偶并检索")
 expect(branches.size()==1,"Alice keeps her creation and sacrifice ability modes")
 if branches.is_empty():return
 picker.select(branches[0])
 expect(e.commit_extension(0,alice.uid,picker.option(),[],"character-fdf-112").is_empty(),"Alice announces her sacrifice mode before resolution")
 one();options=e.pending.options;picker=Picker.new();picker.configure(options,"alice-sacrifice")
 expect(picker.available().map(func(atom):return atom.value)==[0,1,2,3],"Alice's sacrifice mode requests X with the available doll maximum")
 picker.select({"kind":"x_count","group":0,"value":2})
 for i in range(2):picker.select(picker.available().filter(func(atom):return atom.kind=="target")[0])
 expect(picker.ready() and picker.option().picks[0].size()==2 and e.Pack.choice_valid(e,options,picker.option()),"Alice typed X selects exactly two dolls and preserves the engine contract")
func inputs():
 var input=XInput.new();root.add_child(input);input.configure([0,1,2,3,10,12],0)
 for invalid in ["-1","1.5","abc","+2","2e0","2+1","4","13","999999999999999999999999"," 2","２"]:
  input.text=invalid;input.text_changed.emit(invalid)
  expect(input.text=="0" and input.is_legal(),"reject invalid input: "+invalid)
 input.text="";input.text_changed.emit("")
 expect(not input.is_legal(),"empty input disables submission")
 input.text="1";input.text_changed.emit("1");input.text="12";input.text_changed.emit("12")
 expect(input.text=="12" and input.is_legal(),"valid multi-digit X can be entered")
 expect(input.virtual_keyboard_type==LineEdit.KEYBOARD_TYPE_NUMBER,"Android requests the numeric keyboard")
 input.queue_free()
 input=XInput.new();root.add_child(input);input.configure([10,12],10)
 input.text="1";input.text_changed.emit("1")
 expect(input.text=="1" and not input.is_legal(),"unfinished prefix is editable but cannot be submitted")
 input.queue_free()
func network():
 for who in [0,1]:
  fresh();e.active=who;e.priority=who;resources(["167","167","164","164","165"],who)
  var c=put("111","hand",who);var remote=Remote.new();remote.seat=who;remote.apply_snapshot(SeatView.build(e,who))
  expect(values(legal_options(remote,remote.find_card(c.uid),who))==[0,1,2],"network seat %d computes the same legal X" % who)
  var target={"player":1-who,"x":2,"mode":"X = 2"}
  var plan=e.payment(who,e.cast_cost(who,c,target)).plan
  var before=JSON.stringify([e.players,e.stack,e.revision])
  for invalid in [-1,3,1.5,"2"]:
   var bad=target.duplicate();bad.x=invalid
   expect(not Gateway.apply(e,who,{"name":"commit_cast","args":[c.uid,bad,plan]}).is_empty(),"network rejects illegal X: "+str(invalid))
   expect(before==JSON.stringify([e.players,e.stack,e.revision]),"invalid X does not mutate authority state")
  expect(Gateway.apply(e,who,{"name":"commit_cast","args":[c.uid,target,plan]}).is_empty(),"network accepts the maximum typed X for seat %d" % who)
