extends SceneTree
const E=preload("res://scripts/rules/duel_engine.gd")
const N=E.Roster.New
const Store=preload("res://scripts/deck_store.gd")
var e
var checks=0
var failures=[]
func _init():call_deferred("run")
func check(ok,title):
 checks+=1
 if ok:print("PASS "+title)
 else:failures.append(title);push_error(title)
func fresh(leader="50"):
 e=E.new();var deck={"leader":leader,"main":[]}
 for i in range(50):deck.main.append("53")
 e.start(deck,deck,0,42)
 for p in e.players:
  for z in ["hand","field","palette","grave","exile"]:p[z]=[]
  p.potato=false;p.turns=2;p.mulligan_done=true
 e.phase="main";e.turn=3;e.pending={};e.triggers=[];e.presentation_events=[]
func add(code,zone="field",who=0):
 var key=N.id(code) if code.contains("-") and not e.cards.has(code) else code
 var c=e.make_card(key,who,zone);e.players[who][zone].append(c);return c
func enter(code,who=0):
 var c=e.make_card(N.id(code),who,"void");e.enter_field(c,who);return c
func entry(c,target={"none":true},key=""):
 return {"id":e.next_stack,"kind":"card" if key.is_empty() else "ability","card":c,"source":c.duplicate(true),"owner":c.owner,"effect":key,"target":target,"name":e.cards[c.card_id].name,"data":{},"optional":false}
func resolve_spell(code,target={"none":true}):
 var c=e.make_card(N.id(code),0,"stack");var t=entry(c,target);e.damage_context={"source":c,"combat":false};N.spell_resolve(e,t);return c
func picks(spec,groups):
 var t=spec.duplicate(true);t.erase("selection");t.picks=groups;return t
func run():
 fresh()
 var defs=e.DB.load_cards();check(defs.size()==511,"511 validated definitions")
 for code in ["ETO-001","ETO-002","ETO-003","ETO-004","ETO-005","ETO-006","ETO-007","ETO-008","ETO-009","ETO-010","ETO-011","ETO-012","ETO-S001","LOC-001","LOC-002","LOC-003","LOC-004","LOC-005","SPX-001","SPX-002","SPX-003","SPX-004","SPX-005","SPX-006","SPX-007"]:
  var image=load(defs[N.id(code)].image).get_image()
  check(image.get_width()<900 and image.get_height()<900,"cropped face "+code)
 check(defs[N.id("SPX-003")].cost.蓝==4 and defs[N.id("SPX-003")].cost.绿==4,"Suwako corrected cost")
 check(defs[N.id("ETO-005")].cost.黄==2 and defs[N.id("ETO-005")].cost.蓝==1 and defs[N.id("LOC-001")].spirit==0,"missing TXT values read from card image")
 fresh(N.id("ETO-001"))
 check(e.leaders(0).size()==2 and e.leaders(1).size()==2,"both leaders generated at game start")
 var double=e.leaders(0)[1]
 check(e.find_card(double.uid)==double and double.leader and double.zone=="leader","second leader registered")
 var projection=preload("res://net/seat_projection.gd").build(e,0,[])
 check(projection.state.players[0].extra_leaders.size()==1 and projection.queries.cast.has(double.uid),"second leader included in network queries")
 var graph=preload("res://net/state_codec.gd").capture(e);var other=E.new();preload("res://net/state_codec.gd").restore(other,graph)
 check(other.leaders(0).size()==2 and other.find_card(double.uid)==other.leaders(0)[1],"additional leader survives snapshot restore")
 var sumireko=e.players[0].leader
 N.on_cast(e,sumireko,0,"leader");var t=e.triggers.pop_back();t.target={"none":true};N.resolve_trigger(e,t)
 check(e.players[0].hand.size()==2 and e.players[0].hand.all(func(c):return c.card_id==N.id("ETO-S001")),"cast generates two occult balls")
 e.choose_effect({"none":true,"x":3,"mode":"洗入3张灵异珠"})
 check(e.players[0].deck.filter(func(c):return c.card_id==N.id("ETO-S001")).size()==3,"choose number to shuffle from outside")
 fresh();var road=enter("LOC-005");var u=enter("LOC-001")
 check(e.triggers.any(func(t):return t.effect=="n21:LOC-005") and e.usage_count(road.uid,"n21:LOC-005")==1,"road sees self-unit entering once")
 var count=e.triggers.size();enter("ETO-003");check(e.triggers.filter(func(t):return t.effect=="n21:LOC-005").size()==1,"road limit applies to this permanent")
 t=entry(road,{"uid":u.uid,"epoch":u.epoch,"mode":"防避2"},"n21:LOC-005");N.resolve_trigger(e,t)
 check(u.get("wards",[]).size()==1,"road shield mode")
 fresh();u=enter("LOC-001");u.leader=true;e.triggers=[]
 e.Roster.Batch.counter(e,u,"courage",3,0)
 check(e.stat(u,"power")==4 and e.stat(u,"health")==3 and e.stat(u,"spirit")==3,"Cirno all-counter power and spirit bonus")
 check(e.triggers.any(func(t):return t.effect=="n21:LOC-001:self"),"counter placement triggers leader ability")
 N.on_attack(e,u);check(e.triggers.any(func(t):return t.effect=="n21:LOC-001"),"Cirno attack trigger")
 fresh();var suika=enter("SPX-001");suika.leader=true;e.triggers=[]
 check(suika.plus_counters==1,"Suika enters with X plus one counters")
 N.on_target(e,e.ref_target(suika));t=e.triggers.pop_back();t.target={"none":true};N.resolve_trigger(e,t)
 e.pump_choices();check(e.pending.get("kind","")=="leader_return","Suika leader retains return-home choice");e.choose_return(false)
 check(suika.zone=="exile" and e.units(0).any(func(c):return e.Cat.race(e,c,"鬼") and c.token),"Suika creates ghosts then exiles")
 for ghost in e.units(0).duplicate():e.move_to(ghost,"grave",false)
 N.on_phase(e,"end");t=e.triggers.back();t.target={"none":true};N.resolve_trigger(e,t)
 check(suika.zone=="field","Suika returns when no ghost remains")
 fresh();var suwako=enter("SPX-003");suwako.leader=true;e.triggers=[];N.on_phase(e,"end")
 t=e.triggers.pop_back();t.target={"none":true};N.resolve_trigger(e,t)
 var frog=e.units(0).filter(func(c):return c.token)[0]
 check(e.stat(frog,"power")==4 and e.stat(frog,"spirit")==2 and e.Extra.keyword(e,frog,"不占战场格"),"Suwako blue-green frog token")
 var enemy=add("53","field",1)
 var opts=e.activation_options(suwako,"n21:frog_tap");var aim=picks(opts[0],[[e.Pack.ref(e,frog)],[e.ref_target(enemy)]])
 check(e.commit_extension(0,suwako.uid,aim,[],"n21:frog_tap").is_empty(),"Suwako activation pays sacrifice")
 e.pass_priority(e.priority);e.pass_priority(e.priority)
 check(enemy.tapped,"frog tap resolves")
 fresh();var gourd=enter("SPX-002");u=add("53")
 check(e.commit_extension(0,gourd.uid,e.ref_target(u),[],"n21:gourd_counter").is_empty(),"gourd tap activation")
 e.pass_priority(e.priority);e.pass_priority(e.priority)
 check(gourd.tapped and u.get("drunk_counters",0)==1 and e.stat(u,"power")==e.cards[u.card_id].power+1,"drunk counter applies all stats")
 N.on_phase(e,"end");t=e.triggers.back();t.target={"none":true};N.resolve_trigger(e,t)
 check(u.zone=="deck" and e.players[0].deck.back().uid==u.uid,"drunk unit placed at library bottom")
 fresh();var time=enter("LOC-003");enemy=add("53","field",1);e.triggers=[]
 N.tap_effect(e,enemy,0);check(time.timer==3 and e.triggers.filter(func(t):return t.effect=="n21:LOC-003").size()==1,"Blizzard sees effect tapping opponent")
 enemy.tapped=false;N.tap_effect(e,enemy,0);check(e.triggers.size()==1,"Blizzard trigger limited once per turn")
 fresh();enemy=add("53","field",1);resolve_spell("LOC-002",{"player":1})
 check(enemy.tapped and e.players[1].life==16 and not e.Roster.reset_allowed(e,enemy),"freeze ray damages and locks next reset")
 e.players[1].turns+=1;u=enter("ETO-003",1);check(u.tapped,"opponent next-turn entrants enter tapped")
 fresh();var train=enter("SPX-007");var train2=enter("SPX-007");enemy=add("53","field",1);e.cards[enemy.card_id].health=1;e.triggers=[]
 t=entry(train,{"picks":[[e.ref_target(enemy)]]},"n21:SPX-007");N.resolve_trigger(e,t)
 check(enemy.damage==2 and e.players[1].life==19,"train excess damage reaches controller")
 e.move_to(train,"grave");check(e.triggers.any(func(v):return v.effect=="n21:SPX-007"),"train leave trigger")
 var deck={"name":"train","leader":"68","main":[],"side":[]}
 for i in range(50):deck.main.append(N.id("SPX-007"))
 check(Store.validate(deck,true).is_empty(),"unlimited train deck accepted")
 fresh();var ball=add("ETO-S001","hand");e.move_to(ball,"palette");t=e.triggers.back();t.target={"none":true};N.resolve_trigger(e,t)
 check(ball.zone=="field" and e.players[0].palette.size()==1,"occult ball swaps palette entry for deck top")
 fresh();add("ETO-S001");var app=enter("ETO-006");e.triggers=[];N.on_phase(e,"prepare");t=e.triggers.back();t.target={"none":true};N.resolve_trigger(e,t)
 check(app.timer==3 and e.players[1].life==19,"Psychokinesis upkeep life loss")
 fresh();var dead=add("53","grave",1);var child=enter("ETO-012");t=entry(child,e.Pack.ref(e,dead),"n21:ETO-012");N.resolve_trigger(e,t)
 check(dead.zone=="field" and dead.owner==0 and dead.original_owner==1,"Child Festival reanimates opponent-owned unit")
 e.move_to(child,"grave");check(child.zone=="outside" and e.players[0].grave.is_empty() and e.players[0].exile.is_empty(),"dream spell grave replacement leaves game")
 fresh();add("ETO-011","grave");resolve_spell("ETO-007");check(e.players[0].life==23 and e.players[0].hand[0].card_id==N.id("ETO-008"),"railway generates sky spell and gains life")
 fresh();add("ETO-007","grave");resolve_spell("ETO-009");check(e.players[0].hand.size()==3 and e.pending.kind=="effect_choice","night walk generates copy spell and draws two before discard")
 fresh();add("ETO-009","grave");enemy=add("53","field",1);resolve_spell("ETO-011",{"picks":[[e.ref_target(enemy)]]})
 check(e.players[0].hand[0].card_id==N.id("ETO-012") and enemy.zone=="grave","science century generates Festival and checks lethal debuff immediately")
 check(not e.resolving_spell,"spell resolution context cleared before later abilities")
 fresh();resolve_spell("ETO-010");var cast=e.make_card("177",0,"stack");u=add("53");var original=entry(cast,e.ref_target(u));e.stack.append(original);N.on_cast(e,cast,0,"hand")
 t=e.triggers.back();t.target={"none":true};N.resolve_trigger(e,t)
 for i in range(2):
  var option=e.pending.options[0];e.choose_effect(option)
 check(e.stack.filter(func(s):return s.get("copy",false)).size()==2 and e.players[0].n21_copies.is_empty(),"dream generates two separately retargeted spell copies once")
 fresh();enemy=add("53","field",1);var spec=N.spell_options(e,N.id("ETO-008"),0).filter(func(o):return o.n21_modes==3)[0]
 resolve_spell("ETO-008",picks(spec,[[e.ref_target(enemy)],[e.ref_target(enemy)]]))
 check(enemy.zone=="deck" and enemy.owner==1,"multimode sky resolves selected effects in order")
 fresh();var duo=enter("ETO-003");duo.leader=true;e.triggers=[];var spell=add("ETO-008","hand")
 # Any two colored requirements can be reduced; palette supports the remaining blue/yellow mix.
 for i in range(3):var resource=add("50","palette");resource.extra_colors=["蓝","黄"]
 var cost=N.cost(e,spell,0,e.cards[spell.card_id].cost)
 check(cost.values().reduce(func(n,v):return n+v,0)==3,"dream discount removes any two colored points")
 fresh();var kokoro=add("character-htk-001");var little=add("100");N.force_main_triggers(e,0)
 check(e.triggers.filter(func(v):return v.source.uid==kokoro.uid and v.effect=="kokoro_mood").size()==2,"Kokoro single triggered ability fires twice without event")
 check(not e.triggers.any(func(v):return v.effect=="untap"),"static brave does not enter stack")
 print("UPDATE0921 CARDS ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)

