extends "res://tests/support/rules_base.gd"
const Counterplay=preload("res://scripts/ai/release_counterplay.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Policy=preload("res://addons/share_export/release_policy.gd")

func setup(opponent: String="70"):
 fresh()
 e.players[0].leader=e.make_card("74",0,"leader",true)
 e.players[1].leader=e.make_card(opponent,1,"leader",true)
 e.ai_profiles=[AI.PROFILE,""];e.ai_memory=[{},{}]
 e.players[1].life=40

func field_leader(who: int=0):
 var c=e.players[who].leader
 c.zone="field";c.entered_turns=0;e.players[who].field.append(c)
 return c

func resources(red: int,black: int,yellow: int=0,who: int=0):
 for pair in [["165",red],["168",black],["164",yellow]]:
  for i in range(pair[1]):put(pair[0],"palette",who)

func played() -> String:
 for s in e.stack:
  if s.kind=="card":return s.card.card_id
 return ""

func bound(c: Dictionary):
 var source=put("field-rei-005","field",1)
 c.tapped=true;c.lock_sources=[e.Pack.ref(e,source)]
 return source

func run():
 routing()
 reimu()
 locked_sacrifice()
 print("Release counterplay: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func routing():
 setup("71")
 var bundle=Counterplay.library()
 expect(bundle.get("schema","")==Counterplay.SCHEMA,"authored release library loads")
 var ids=e.cards.keys()
 for id in ids:
  var info=e.cards[id]
  if info.kind!="自机" or info.get("canonical_id",id)!=id or not info.constructible:continue
  e.players[1].leader=e.make_card(id,1,"leader",true);e.players[1].extra_leaders=[]
  var route=Counterplay.select(e,0)
  expect(route.source=="counterplay" and not route.label.is_empty(),"registered leader has authored counterplay: "+id)
  expect(Counterplay.select(e,1).source==("counterplay" if id=="74" else "generic"),"routing remains scoped to actual own leader: "+id)
 e.players[1].leader=e.make_card("71",1,"leader",true)
 var original=Counterplay.select(e,0)
 var c=e.players[1].leader;c.copy_original="71";c.card_id="70";c.zone="grave";c.owner=0;c.art_id="alternate"
 expect(Counterplay.select(e,0).matchup.key==original.matchup.key,"copy artwork zone and control preserve classification")
 c.card_id="71";c.erase("copy_original");c.owner=1;c.zone="leader"
 e.players[1].extra_leaders=[e.make_card("70",1,"leader",true)]
 expect(Counterplay.select(e,0).source=="generic","unlisted double leader falls back instead of using either single entry")
 e.players[1].leader=e.make_card("new-eto-002",1,"leader",true);e.players[1].extra_leaders=[e.make_card("new-eto-001",1,"leader",true)]
 expect(Counterplay.select(e,0).matchup.opponent_key=="new-eto-001+new-eto-002" and Counterplay.select(e,0).source=="counterplay","Sumireko double leader gets distinct sorted combination")
 var deck=Store.blank("双自机路由");deck.leader="new-eto-001"
 for i in range(50):deck.main.append("164")
 var own=deck.duplicate(true);own.leader="74"
 var actual=Duel.new();actual.start(own,deck,0,33)
 expect(Counterplay.select(actual,0).matchup.opponent_key=="new-eto-001+new-eto-002" and Counterplay.select(actual,0).source=="counterplay","actual game-start second leader routes to combination entry")
 e.players[0].extra_leaders=[e.make_card("70",0,"leader",true)]
 expect(Counterplay.select(e,0).reason=="unsupported_own_leaders","own double leader cannot use single Remilia tactics")
 setup("71")
 var broken=bundle.duplicate(true);broken.entries["74::71"].policy.target_bonus=NAN
 expect(Counterplay.select(e,0,broken).reason=="invalid_counterplay" and Counterplay.select(e,0,broken).policy==broken.generic,"invalid tactic falls back to generic")
 broken=bundle.duplicate(true);broken.entries["74::71"].opponent_leaders=["70"]
 expect(Counterplay.select(e,0,broken).reason=="mismatched_counterplay","mismatched tactic rejected")
 expect(Counterplay.select(e,0,{}).reason=="invalid_library","missing library retains built-in generic")
 c=e.players[1].leader;c.card_id="back"
 expect(Counterplay.select(e,0).reason=="unknown_opponent","unknown identity retains generic")
 setup("71");c=field_leader(1)
 expect(Counterplay.target_bonus(e,c)>0,"present registered core receives target priority")
 c.zone="grave";e.players[1].field=[]
 expect(Counterplay.field_policy(e,0)==Counterplay.DEFAULT_POLICY,"absent core does not change field policy")
 setup("74");field_leader();c=field_leader(1);resources(3,3)
 put(AI.FAIRY)
 put(AI.CASTLE,"hand");var queen=put(AI.QUEEN,"hand")
 var specialized=[AI.castle_priority(e,0),AI.queen_priority(e,0,queen)]
 e.players[1].leader=e.make_card("70",1,"leader",true)
 var generic=[AI.castle_priority(e,0),AI.queen_priority(e,0,queen)]
 expect(specialized[0]>generic[0] and specialized[1]>generic[1],"live mirror increases useful six-mana Castle and Queen pressure")
 setup("85");field_leader();field_leader(1);e.players[1].life=14
 expect(AI.aurora_pressure_target(e,0).get("mode","")=="失去生命","Kaguya entry opens fourteen-life Aurora pressure")
 setup("71");field_leader(1)
 var night=AI.night_priority(e,0)
 e.players[1].leader=e.make_card("70",1,"leader",true)
 expect(night>AI.night_priority(e,0),"Yuyuko entry increases Night sealing priority")
 for path in [Counterplay.PATH,"res://scripts/ai/release_counterplay.gd"]:
  expect(not Policy.excluded_path(path),"release includes runtime counterplay: "+path)
 var config=ConfigFile.new();config.load("res://export_presets.cfg")
 expect("data/*.json" in config.get_value("preset.0","include_filter",""),"Windows export includes counterplay data")

func reimu():
 for id in ["70","character-rei-001"]:
  setup(id);field_leader();var enemy=field_leader(1);resources(3,3);resources(0,0,2,1)
  put("100","hand",1);var gun=put(AI.GUNGNIR,"hand");put(AI.AURORA,"hand");e.players[1].life=3
  e.ai_step(0)
  expect(played()==AI.GUNGNIR and e.stack.back().target.uid==enemy.uid,"Reimu removal precedes lethal/pressure planning: "+id)
  var seal=e.players[1].hand[0]
  expect(not e.cast_error(1,seal.uid).is_empty(),"Gungnir prevents Dreams Seal response: "+id)
  settle()
  expect(enemy.zone!="field" and not Counterplay.reimu_seal_risk(e,0),"removing Reimu closes Seal role window: "+id)
  expect(e.ai_memory[0].counterplay_routing.source=="counterplay","release decisions record selected library entry")
 setup();field_leader();var enemy=field_leader(1);enemy.wards=[{"amount":2,"turn":-1}]
 resources(4,4);resources(0,0,2,1);put("100","hand",1)
 var castle=put(AI.QUEEN,"hand");put(AI.GUNGNIR,"hand")
 expect(Counterplay.reimu_seal_risk(e,0),"two available yellow and unknown hand imply possible Seal")
 expect(not AI.cast(e,0,castle,{"none":true},false),"direct four-mana Queen held while protected Reimu can enable Seal")
 expect(not AI.execute(e,0,{"kind":"cast","uid":castle.uid,"card_id":castle.card_id,"target":{"none":true}}),"search and cached execution cannot bypass expensive-cast guard")
 var before=Counterplay.select(e,0)
 e.players[1].hand[0].card_id="164";e.players[1].deck.reverse()
 expect(Counterplay.reimu_seal_risk(e,0) and Counterplay.select(e,0)==before,"hidden identity and deck order cannot alter routing or Seal risk")
 for c in e.players[1].palette:c.tapped=true
 expect(not Counterplay.reimu_seal_risk(e,0) and AI.cast(e,0,castle,{"none":true},false),"spent Seal mana releases expensive cast")
 setup();field_leader();field_leader(1);resources(2,3);resources(0,0,1,1);put("100","hand",1)
 expect(not Counterplay.reimu_seal_risk(e,0),"one yellow cannot pay two-yellow Seal")
 setup();field_leader();field_leader(1);resources(2,3);resources(0,0,2,1)
 expect(not Counterplay.reimu_seal_risk(e,0),"empty opponent hand does not invent Seal")
 setup();field_leader();field_leader(1);resources(2,3);resources(0,0,2,1)
 var known=put("164","palette",1);e.move_to(known,"hand")
 expect(not Counterplay.reimu_seal_risk(e,0),"fully known noncounter hand does not invent Seal")
 setup();field_leader();enemy=field_leader(1);enemy.wards=[{"amount":2,"turn":-1}]
 resources(3,3);resources(0,0,2,1);put("100","hand",1);put(AI.MIST,"hand")
 expect(Counterplay.reimu_seal_risk(e,0),"protected Reimu still enables possible Dreams Seal")
 e.ai_step(0)
 expect(played()==AI.MIST and e.stack.back().target.uid==enemy.uid,"four-mana Mist removal remains first and allowed despite Seal risk")
 setup();field_leader();field_leader(1);resources(2,4);resources(0,0,4,1);put("100","hand",1)
 var night=put(AI.NIGHT,"palette");var big=put(AI.BIG_REMILIA,"hand")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(night.zone=="hand" and big.zone=="palette","possession retrieves payable Night against reserved Reimu mana")
 e.ai_step(0)
 expect(played()==AI.NIGHT and e.stack.back().target.uid==e.players[0].leader.uid and e.phase=="possession","Night targets Remilia inside possession response window")
 settle()
 expect(e.players[1].get("night_lock",-1)==e.turn and not Counterplay.reimu_seal_risk(e,0),"resolved Night closes Seal window for rest of turn")
 setup();field_leader();field_leader(1);resources(3,3);resources(0,0,4,1);put("100","hand",1);e.players[1].life=3
 var gun=put(AI.GUNGNIR,"palette");night=put(AI.NIGHT,"palette");put(AI.BIG_REMILIA,"hand")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(gun.zone=="hand" and night.zone=="palette","possession retrieves safe Reimu removal before Night or an assumed burn lethal")
 setup();field_leader();field_leader(1);resources(3,3);put(AI.MIST,"hand")
 e.ai_step(0)
 expect(played()==AI.MIST,"other effective removal also precedes planning when Seal is unavailable")

func locked_sacrifice():
 for health in [4,5]:
  setup("93");field_leader();var enemy=field_leader(1)
  enemy.damage=e.stat(enemy,"health")-health
  var locked=put(AI.LILY);bound(locked);put(AI.FAIRY)
  resources(3,3);put(AI.GUNGNIR,"hand");var autumn=put(AI.AUTUMN,"hand");put(AI.MIST,"hand")
  e.ai_step(0)
  expect(played()==AI.AUTUMN and e.stack.back().target.uid==enemy.uid,"bound ally makes Autumn first against four/five-health core: "+str(health))
  expect(locked.zone=="grave" and e.players[0].leader.zone=="field","Autumn pays with bound non-Remilia instead of aura")
  settle();expect(enemy.zone!="field","five damage actually removes selected core")
 setup("93");field_leader();var enemy=field_leader(1);enemy.damage=1
 var locked=put(AI.LILY);var source=bound(locked);resources(2,2);var autumn=put(AI.AUTUMN,"hand")
 source.zone="grave";e.players[1].field.erase(source)
 expect(AI.bound_autumn_target(e,0,autumn).is_empty(),"departed Bind field does not force sacrifice priority")
 setup("93");var remilia=field_leader();field_leader(1);bound(remilia);resources(2,2);autumn=put(AI.AUTUMN,"hand")
 expect(AI.bound_autumn_target(e,0,autumn).is_empty(),"bound Remilia is never preferred sacrifice")
 setup("93");field_leader();enemy=field_leader(1);enemy.wards=[{"amount":1,"turn":-1}]
 locked=put(AI.LILY);bound(locked);resources(2,2);autumn=put(AI.AUTUMN,"hand")
 expect(AI.bound_autumn_target(e,0,autumn).is_empty(),"five-health core with prevention cannot be killed by five damage")
 setup("93");field_leader();enemy=field_leader(1);enemy.damage=2
 locked=put(AI.LILY);bound(locked);resources(2,2);autumn=put(AI.AUTUMN,"hand")
 expect(AI.bound_autumn_target(e,0,autumn).is_empty(),"special priority is limited to four/five-health core")
