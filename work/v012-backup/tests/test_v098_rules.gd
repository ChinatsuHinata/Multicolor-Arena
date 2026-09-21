extends "res://tests/test_v09_rules.gd"
func youmu():
 var c=e.players[0].leader
 c.card_id="87"; e.shift(c,"field"); e.players[0].field.append(c); c.entered_turns=0
 return c
func fight(a: Dictionary,b: Dictionary):
 e.attack(0,a.uid); one(); e.block([b.uid]); one()
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 # Actual designated Youmu, not an ordinary copy of a leader card.
 fresh(); var a=youmu(); var b=put("54","field",1)
 expect(e.has_leader_ability(a),"designated Youmu has her commander ability")
 fight(a,b)
 expect(b.zone=="field" and b.damage==2 and a.damage==0,"first strike hurts a surviving defender before it retaliates")
 expect(e.stack.size()==1 and e.stack[0].effect=="combat_exile_target" and e.pending.is_empty(),"mandatory exile enters stack in the first-strike response window")
 expect(e.combat.step=="first_damage_window","ordinary damage waits for the trigger and responses")
 var batch=e.combat.damage_batch
 one()
 expect(b.zone=="exile" and a.damage==0 and e.stack.is_empty(),"surviving defender is exiled by the ability without dealing damage")
 one(); expect(e.combat.is_empty() and a.damage==0,"exiled defender cannot participate in the ordinary damage step")
 expect(e.next_damage_batch==batch+1,"exiled defender does not cause a second damage batch")
 # A lethal hit is death, not exile. The victim's death trigger still resolves.
 fresh(); a=youmu(); b=put("23","field",1); fight(a,b)
 expect(b.zone=="grave" and e.players[1].exile.is_empty(),"lethal first strike sends Parsee to grave before trigger resolution")
 expect(e.stack.size()==2 and e.stack.any(func(t): return t.effect=="death_drain") and e.stack.any(func(t): return t.effect=="combat_exile_target"),"death trigger and Youmu trigger both enter stack")
 expect(e.players[0].life==20 and e.players[1].life==20,"death trigger is queued rather than bypassing the stack")
 settle()
 expect(e.players[0].life==18 and e.players[1].life==21,"Parsee death ability resolves once")
 expect(b.zone=="grave" and e.players[1].exile.is_empty(),"Youmu does not exile the dead graveyard object")
 one(); expect(e.combat.is_empty() and a.damage==0,"dead defender does not retaliate")
 # An optional death ability can bring back a NEW instance; the old trigger
 # and old combat participant ref must not follow it into its new epoch.
 fresh(); a=youmu(); b=put("48","field",1); var old_epoch=b.epoch; fight(a,b)
 expect(b.zone=="grave" and e.pending.get("kind")=="effect_choice" and e.pending.trigger.effect=="death_undying","optional death return is offered after the lethal hit")
 e.choose_effect(e.pending.options[0]); one()
 expect(b.zone=="field" and b.epoch>old_epoch and b.plus_counters==1,"death return creates a new field instance")
 one(); expect(b.zone=="field","old Youmu trigger cannot exile the returned instance")
 one(); expect(e.combat.is_empty() and a.damage==0,"returned unit does not rejoin its previous combat")
 # If exile is countered, a surviving ordinary defender MUST retaliate.
 fresh(); a=youmu(); b=put("54","field",1); fight(a,b)
 e.counter_entry(e.stack[0].id); batch=e.combat.damage_batch; one()
 expect(a.zone=="return_pending" and e.combat.damage_batch>batch,"surviving normal defender deals its full damage after exile is countered")
 expect(e.combat.damage_snapshot[a.uid].display_stats.health==-1 and e.combat.damage_snapshot[b.uid].damage==2,"ordinary damage is shown separately and Youmu never strikes twice")
 expect(e.pending.get("kind")=="leader_return","lethal retaliation keeps the actual leader return choice")
 e.choose_return(false); one(); expect(e.combat.is_empty() and b.zone=="field","countered-exile combat finishes after leader choice")
 # Plain first-strike copies also allow surviving non-first-strikers to hit.
 fresh(); a=put("87"); b=put("54","field",1); fight(a,b)
 expect(e.stack.is_empty() and not e.has_leader_ability(a),"ordinary Youmu copy does not inherit commander exile")
 one(); expect(a.zone=="grave" and b.zone=="field" and b.damage==2,"ordinary defender retaliates after unmarked Youmu's first strike")
 # Defensive first strike: the surviving attacker gets its ordinary hit.
 fresh(); a=put("54"); b=put("53","field",1); b.modifiers=[{"先制":true}]; fight(a,b)
 expect(a.damage==2 and b.damage==0,"defensive first strike is the only first damage")
 one(); expect(a.zone=="field" and a.damage==2 and b.zone=="grave","surviving attacker deals ordinary damage and receives no duplicate first strike")
 one(); expect(e.combat.is_empty(),"defensive first strike completes")
 # Half-ghost shares the designated leader's exile ability.
 fresh(); a=youmu(); var ghost=put("token_halfghost"); b=put("54","field",1); b.modifiers=[{"血量":3}]; fight(ghost,b)
 expect(e.stack.size()==1 and b.damage==4 and ghost.damage==0,"half-ghost first strike triggers the leader's exile ability")
 one(); one(); expect(b.zone=="exile" and ghost.damage==0 and e.combat.is_empty(),"half-ghost exile prevents subsequent retaliation")
 # Prevented damage never triggers exile; both first strikers hit simultaneously.
 fresh(); a=youmu(); b=put("53","field",1); b.modifiers=[{"防止伤害":true}]; fight(a,b)
 expect(b.damage==0 and e.stack.is_empty(),"prevented first-strike damage creates no exile trigger")
 one(); expect(a.damage==2 and b.zone=="field","protected ordinary blocker can still retaliate")
 fresh(); a=youmu(); b=put("53","field",1); b.modifiers=[{"先制":true,"血量":3}]; fight(a,b)
 expect(a.damage==2 and b.damage==2,"two first strikers deal simultaneous damage before exile")
 one(); one(); expect(b.zone=="exile" and a.damage==2 and e.combat.is_empty(),"exile cannot undo damage already dealt simultaneously")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"saved decks unchanged")
 var report="%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)]
 FileAccess.open("res://work/v098-rules-tests.txt",FileAccess.WRITE).store_string(report)
 print("V098_RULES: "+report); quit(0 if failures.is_empty() else 1)
