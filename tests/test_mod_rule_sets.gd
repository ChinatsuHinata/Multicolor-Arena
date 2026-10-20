extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")
const Series=preload("res://net/series_controller.gd")
const Registry=preload("res://scripts/rules/mod_registry.gd")
var checks=0
var failures=[]

func check(ok: bool,title: String):
 checks+=1
 if ok:print("PASS "+title)
 else:failures.append(title);push_error(title)

func start(series):
 for seat in [0,1]:check(series.ready(seat).is_empty(),"ready under selected mod rules")
 check(series.prepare_choice(),"both players advance preparation")
 if series.state.status=="sideboarding":
  var original=series.state.decks[0].duplicate(true)
  var swapped=original.duplicate(true);swapped.main[0]="testmod/fuel";swapped.side[0]="testmod/control"
  check(series.set_deck(0,swapped).is_empty(),"BO1 pregame accepts registered mod reserve")
  swapped.main[0]="testmod/ship"
  check(not series.set_deck(0,swapped).is_empty(),"sideboarding rejects cards outside registered pool")
  var invalid=original.duplicate(true);invalid.main.fill("testmod/fuel");invalid.side.fill("testmod/control")
  check(series.set_deck(0,invalid).contains("最多从备牌换入 3 张"),"mod BO1 sideboarding keeps three-card limit")
  for seat in [0,1]:check(series.ready(seat).is_empty(),"confirm mod sideboarding")
  check(series.prepare_choice(),"mod sideboarding advances to first-player choice")
 check(series.choose_first(series.state.chooser,true).is_empty() and series.start_game(),"chosen normal format starts with mod rules")

func _initialize():
 Registry._shared=Registry.new()
 check(Registry.shared().register_pack("res://examples/testmod").is_empty(),"load mod fixture")
 Store.CARDS=Store.Database.load_cards()
 var deck=Store.blank("模组规则测试");deck.rule_set=Rules.MOD;deck.leader="70"
 deck.main=["testmod/control","testmod/control","testmod/control","testmod/control"]
 deck.side=["testmod/fuel","testmod/fuel","testmod/fuel","testmod/fuel"]
 check(Store.validate(deck,false,Rules.MOD).is_empty(),"mod rules allow ordinary leader and mod cards")
 check(not Store.validate(deck,true,Rules.MOD).is_empty(),"strict mod construction still requires fifty main cards")
 var excess=deck.duplicate(true);excess.side.append("testmod/control")
 check(not Store.validate(excess,false,Rules.MOD).is_empty(),"mod rules retain total copy limit across main and side")
 for rule_set in Rules.IDS:
  if rule_set==Rules.MOD:continue
  var ordinary=Series.new();ordinary.setup(Series.BO3,false,rule_set)
  check(not ordinary.set_deck(0,deck).is_empty(),"non-mod room rejects mod deck despite deck tag: "+rule_set)
  ordinary.state.decks[0]=deck.duplicate(true)
  check(not ordinary.ready(0).is_empty(),"ready rechecks mod boundary: "+rule_set)
  check(ordinary.state.mods.is_empty(),"ordinary room does not require installed pack equality: "+rule_set)
 for format_value in [Series.BO1,Series.BO1_SIDEBOARD,Series.BO3]:
  var series=Series.new();series.setup(format_value,false,Rules.MOD)
  check(series.state.format==format_value and series.state.mods==Registry.shared().manifest(),"mod rule retains format and locks manifest")
  for seat in [0,1]:check(series.set_deck(seat,deck).is_empty(),"register mod deck for "+Series.format_label(format_value))
  start(series)
  check(series.record_result(0),"first win recorded")
  if format_value==Series.BO3:
   check(series.state.status=="between" and series.state.scores==[1,0],"mod BO3 needs a second win")
   var swapped=deck.duplicate(true);swapped.main.fill("testmod/fuel");swapped.side.fill("testmod/control")
   check(series.set_deck(0,swapped).is_empty(),"BO3 permits four mod reserve swaps")
   start(series);check(series.record_result(0),"second win recorded")
  check(series.state.status=="complete","mod rules preserve format victory threshold")
  check(series.rematch().is_empty() and series.state.format==format_value and series.state.rule_set==Rules.MOD and series.state.mods==Registry.shared().manifest(),"rematch retains format, mod rules and manifest")
 var entertainment=Series.new();entertainment.setup(Series.EXPLORATION,false,Rules.MOD)
 check(entertainment.state.rule_set==Rules.UNRESTRICTED and entertainment.state.mods.is_empty(),"fixed entertainment remains on its own construction rules")
 print("MOD_RULE_SETS: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
