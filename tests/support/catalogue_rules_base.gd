extends "res://tests/support/selection_rules_base.gd"
const Roster=preload("res://scripts/rules/excel_abilities.gd")
func roster_trigger(c: Dictionary,k: String,t: Dictionary={"none":true},data: Dictionary={}):
 Roster.resolve_trigger(e,{"roster":true,"extended":true,"source":c.duplicate(true),"effect":k,"owner":c.owner,"target":t,"data":data})
func resolve_spell(id: String,t: Dictionary={"none":true}):
 var c=e.make_card(id,0,"stack")
 e.damage_context={"source":c,"single":e.Pack.flatten(t).size()==1,"combat":false}
 var result=Roster.spell_resolve(e,{"card":c,"owner":0,"target":t,"kind":"card"})
 e.damage_context={};expect(result,"explicit resolution "+id);return c
func selection(id: String,picks: Array) -> Dictionary:return selected(e.targets_for(id,0),picks)
func act(c: Dictionary,k: String,t: Dictionary={"none":true}):
 e.priority=c.owner
 var error=e.commit_extension(c.owner,c.uid,t,e.payment(c.owner,e.Extra.activation_cost(k)).plan,k)
 expect(error.is_empty(),"activate "+k+" "+error);settle();e.priority=0
func dict(a: Dictionary,b: Dictionary) -> Dictionary:
 var result=a.duplicate(true);result.merge(b,true);return result
func choose_groups(options: Array,picks: Array,index: int=0) -> Dictionary:
 var t=options[index].duplicate(true);t.erase("selection");t.picks=picks;return t
