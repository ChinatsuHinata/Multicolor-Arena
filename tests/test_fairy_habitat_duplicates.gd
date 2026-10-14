extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")

func ability_count(c,key):
 return e.cards[c.card_id].abilities.filter(func(a):return a.get("参数",{}).get("效果","")==key).size()
func trigger_count(c,key):
 return e.triggers.filter(func(t):return t.source.uid==c.uid and t.get("effect","")==key).size()

func run():
 fresh();var first=put("2");var second=put("2")
 var habitat=e.make_card("character-fdn-007",0,"hand");var life=e.players[0].life
 e.enter_field(habitat,0)
 expect(ability_count(habitat,"luna_life")==2,"habitat keeps both identical Luna abilities")
 expect(trigger_count(habitat,"luna_life")==2,"both inherited roster entry abilities trigger")
 settle()
 expect(e.players[0].life==life+4,"both inherited Luna abilities resolve independently")
 for i in range(3):e.judge()
 expect(ability_count(habitat,"luna_life")==2,"repeated synchronization does not accumulate abilities")
 e.move_to(first,"grave");e.judge()
 expect(ability_count(habitat,"luna_life")==1,"one same-name fairy leaving removes only its ability")
 e.move_to(second,"grave");e.judge()
 expect(ability_count(habitat,"luna_life")==0,"last same-name fairy leaving removes the ability")
 put("2","field",1);put("2","hand");e.judge()
 expect(ability_count(habitat,"luna_life")==0,"opponent fairies and fairies outside the battlefield do not grant abilities")

 fresh();first=put("1");put("1");habitat=e.make_card("character-fdn-007",0,"hand")
 e.enter_field(habitat,0)
 expect(trigger_count(habitat,"enter_haste")==2,"both inherited extension entry abilities trigger")
 settle();expect(e.has_haste(first) and e.stack.is_empty(),"inherited extension abilities resolve")

 fresh();habitat=put("character-fdn-007");put("character-rei-ex01");put("character-rei-ex01");e.judge()
 var hand=e.players[0].hand.size();e.move_to(habitat,"grave")
 expect(trigger_count(habitat,"larva_draw")==2,"both inherited precon death abilities trigger")
 settle();expect(e.players[0].hand.size()==hand+4,"two same-name Larvas let habitat draw four cards")
 fresh();habitat=put("character-fdn-007");put("character-rei-ex01");put("character-rei-ex01");put("spell-fdn-019").timer=2;e.judge()
 e.move_to(habitat,"grave")
 expect(trigger_count(habitat,"larva_draw")==4 and trigger_count(habitat,"crystal")==4,"extra death trigger applies separately to each inherited ability")
 settle();expect(e.players[0].hand.size()==8,"each inherited Larva ability resolves twice with an extra death trigger")

 fresh();habitat=put("character-fdn-007");first=put("character-fdn-013");second=put("character-fdn-013");e.judge()
 expect(e.stat(habitat,"power")==4 and e.stat(habitat,"spirit")==4,"both inherited forest fairy static bonuses apply")
 var copy=e.Cat.copy_token(e,0,habitat,"mountain_fairy");e.judge()
 expect(ability_count(copy,"character-fdn-013")==2 and e.stat(copy,"power")==4,"habitat copy inherits each static ability exactly once")
 e.move_to(first,"grave");e.judge()
 expect(e.stat(habitat,"power")==1 and e.stat(copy,"power")==1,"habitat and copy recalculate after one source leaves")

 fresh();habitat=put("character-fdn-007");put("80");put("80");var fairy=put("57");e.judge()
 expect(e.stat(fairy,"power")==int(e.cards[fairy.card_id].power)+4,"habitat grants two inherited Cirno auras alongside both originals")

 fresh();habitat=put("character-fdn-007");put("new-loc-001");put("new-loc-001");habitat.courage=2;e.judge()
 expect(e.stat(habitat,"power")==4 and e.stat(habitat,"spirit")==4,"both inherited ultimate Cirno counter bonuses apply")
 e.Roster.New.on_counter(e,habitat,1,0)
 expect(trigger_count(habitat,"n21:LOC-001:self")==2,"both inherited self abilities trigger without source leader status")

 fresh();habitat=put("character-fdn-007");put("character-fdn-014");put("character-fdn-014");e.judge()
 life=e.players[0].life;e.combat_hit(habitat,{"player":1},1)
 expect(e.players[0].life==life+2,"both inherited lifesteal keywords grant life")

 fresh();habitat=put("character-fdn-007");put("character-fdn-006");put("character-fdn-006");e.judge()
 mana();var discard=put("50","hand")
 var actions=e.available_actions(0,habitat.uid).filter(func(a):return a.get("key","")=="character-fdn-006")
 expect(actions.size()==1 and actions[0].label.begins_with("（×2）"),"identical activations show their inherited count")
 var choices=e.activation_options(habitat,"character-fdn-006")
 var target={"selection_id":choices[0].selection_id,"picks":[[e.Pack.ref(e,discard)]]}
 var error=e.commit_extension(0,habitat.uid,target,e.payment(0,e.extension_cost(0,habitat,"character-fdn-006",target)).plan,"character-fdn-006")
 expect(error.is_empty(),"one inherited activation pays its own costs")
 settle()
 expect(e.units(0).filter(func(c):return c.get("token",false)).size()==1,"activating one identical ability creates only one copy")
 e.move_to(habitat,"grave")
 expect(trigger_count(habitat,"crystal")==2,"both inherited crystal abilities trigger on death")

 fresh();habitat=put("character-fdn-007");put("2");put("2");e.judge()
 e.Roster.TriggerInventory.force(e,0)
 expect(trigger_count(habitat,"luna_life")==2,"forced triggers enumerate each inherited ability without squaring its count")
 expect(trigger_count(habitat,"crystal")==2,"forced triggers preserve each inherited crystal ability")
 var restored=Duel.new();Codec.restore(restored,bytes_to_var(var_to_bytes(Codec.capture(e))))
 e=restored;habitat=e.find_card(habitat.uid)
 expect(ability_count(habitat,"luna_life")==2 and trigger_count(habitat,"luna_life")==2,"state serialization preserves repeated abilities and queued triggers")
 first=e.players[0].field.filter(func(c):return c.card_id=="2")[0];e.move_to(first,"grave");e.judge()
 expect(ability_count(habitat,"luna_life")==1 and trigger_count(habitat,"luna_life")==2,"source loss after restoring changes current abilities while preserving queued triggers")

 print("FAIRY_HABITAT_DUPLICATES: ",checks," checks; ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
