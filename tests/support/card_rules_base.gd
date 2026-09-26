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
