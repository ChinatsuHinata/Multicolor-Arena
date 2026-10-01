extends SceneTree
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
var failed=[]
func _initialize():call_deferred("run")
func expect(ok: bool,title: String):
 if ok:print("PASS: "+title)
 else:failed.append(title);push_error(title)
func fixture():
 var d=Store.blank("境界疾行测试");d.leader="70"
 for i in range(50):d.main.append("164")
 var e=Duel.new();e.start(d,d,0,24)
 for p in e.players:
  p.hand=[];p.palette=[];p.field=[];p.grave=[];p.potato=false
 e.phase="main";e.turn=5;e.priority=0;e.active=0
 return e
func put(e,id: String,zone: String="field"):
 var c=e.make_card(id,0,zone);e.players[0][zone].append(c);return c
func resolve(e):
 e.pass_priority(e.priority);e.pass_priority(e.priority)
func run():
 for scenario in [{"id":"75","combat":false},{"id":"75","combat":true},{"id":"character-fdn-048","combat":false},{"id":"character-fdn-048","combat":true},{"id":"character-ucs-067","combat":false},{"id":"character-ucs-067","combat":true}]:
  var during_combat=scenario.combat
  var e=fixture();var attacker=put(e,scenario.id)
  e.attack(0,attacker.uid)
  expect(attacker.tapped and not e.combat.is_empty(),"haste unit attacks before Boundary")
  if not during_combat:
   for i in range(4):
    if e.combat.is_empty():break
    resolve(e)
  if scenario.id!="75":
   put(e,"170")
   var victim=e.make_card("70",1,"field");e.players[1].field.append(victim)
  e.priority=0
  for id in ["68","68","75"]:put(e,id,"palette")
  var spell=put(e,"114","hand");var old_ref=e.ref_target(attacker)
  var error=e.commit_cast(0,spell.uid,{"picks":[[old_ref]],"selection_id":"blink_two"},e.payment(0,e.cards["114"].cost).plan)
  expect(error.is_empty(),"Boundary can be cast: "+error)
  resolve(e)
  expect(attacker.zone=="field" and attacker.epoch!=old_ref.epoch and not attacker.tapped,"Boundary returns a fresh untapped unit")
  expect(e.has_haste(attacker) and not e.summoning_sick(attacker),"printed haste survives Boundary")
  for i in range(12):
   if e.pending.is_empty() and e.stack.is_empty():break
   if e.pending.get("kind","")=="effect_choice":
    var choice=e.pending.options[0].duplicate(true)
    if choice.has("selection"):
     choice.picks=[]
     for group in choice.selection:choice.picks.append(group.pool.slice(0,group.min))
     choice.erase("selection")
    e.choose_effect(choice)
   else:resolve(e)
  if scenario.id!="75":expect(e.players[1].field.is_empty(),"returned Remilia sacrifice trigger fully resolves")
  if during_combat:
   resolve(e)
   expect(e.combat.is_empty(),"old combat ends after attacker leaves")
  expect(e.can_attack(0,attacker.uid),"returned haste unit can attack again")
  e.attack(0,attacker.uid)
  expect(attacker.tapped and e.combat.get("attacker",{}).get("epoch",-1)==attacker.epoch,"second attack uses returned unit")
 quit(0 if failed.is_empty() else 1)
