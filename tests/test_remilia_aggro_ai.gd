extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Codec=preload("res://net/state_codec.gd")
var plain_serial=0
func remilia():
 fresh()
 e.players[0].leader=e.make_card(AI.REMILIA,0,"leader",true)
 e.ai_profiles=[AI.PROFILE,""];e.ai_memory=[{},{}]
 e.players[0].palette=[]
func resources(red: int,black: int,who: int=0):
 for i in range(red):put("165","palette",who)
 for i in range(black):put("168","palette",who)
func plain(who: int,power: int,health: int,spirit: int,words: Array=[]):
 plain_serial+=1
 var id="ai_fixture_"+str(plain_serial)
 e.cards[id]=e.cards["164"].duplicate(true)
 e.cards[id].merge({"kind":"单位","title":"","character":"测试单位","race":[],"colors":["黄"],"cost":{},"abilities":[],"power":power,"health":health,"spirit":spirit,"keywords":words},true)
 return put(id,"field",who)
func leader_on_field():
 var c=e.players[0].leader
 c.zone="field";c.entered_turns=0;e.players[0].field.append(c)
 return c
func resolve_ai(block_uid: int=-2,block_attacker: int=-1):
 for i in range(180):
  if e.winner!=-2:return
  e.pump_choices()
  if not e.pending.is_empty():
   if e.pending.owner==0 and AI.step(e,0):continue
   match e.pending.kind:
    "trigger_order":e.choose_trigger_order(0)
    "effect_choice":e.choose_effect(e.pending.options[0])
    "block":e.block(AI.simulated_blocks(e,0) if block_uid==-2 else [block_uid] if e.combat.attacker.uid==block_attacker else [])
    "leader_return":e.choose_return(true)
    "timer":e.choose_timer(0)
    "ward_order":e.choose_ward(e.pending.options[0])
    "damage_assignment":
     var allocation={};var left=e.pending.total
     for t in e.combat.blockers:
      var c=e.find_card(t.uid);var amount=mini(left,e.stat(c,"health")-c.damage)
      allocation[str(c.uid)]=amount;left-=amount
     if left>0:allocation[str(e.combat.blockers[0].uid)]+=left
     e.combat_damage(allocation)
    _:return
  elif not e.stack.is_empty() or not e.combat.is_empty():one()
  else:e.priority=0;return
 expect(false,"AI resolution completes")
func played() -> String:
 for entry in e.stack:
  if entry.kind=="card":return entry.card.card_id
 return ""
func known_spell(id: String):
 var c=put(id,"palette",1)
 e.move_to(c,"hand")
 return c

func requested_regressions():
 remilia();resources(2,2);leader_on_field()
 var queen=put(AI.QUEEN,"hand")
 plain(1,0,9,0)
 expect(AI.cast(e,0,queen,{"none":true}),"Queen can be cast with four open slots")
 resolve_ai()
 var bats=e.units(0).filter(func(c):return c.get("queen_midnight_bat",false))
 expect(bats.size()==4,"all four Queen bats carry their source marker")
 var attacked=[]
 for i in range(4):
  e.ai_step(0)
  var uid=e.combat.get("attacker",{}).get("uid",-1)
  expect(bats.any(func(c):return c.uid==uid) and uid not in attacked,"Queen bat "+str(i+1)+" attacks even into a blocker")
  attacked.append(uid)
  resolve_ai()
 expect(attacked.size()==4,"all four Queen bats attacked this turn")
 remilia();resources(1,1);var wings=put(AI.WINGS,"hand")
 for i in range(e.Cat.field_limit(e,0)-1):plain(0,1,1,1)
 expect(AI.spell_target(e,0,wings).is_empty(),"Wings refuses a single open battlefield slot")
 expect(AI.card_priority(e,0,wings)==0,"blocked Wings receives no opening priority")
 expect(AI.search_actions(e,0).all(func(a):return a.get("card_id","")!=AI.WINGS),"search excludes Wings with one slot")
 remilia();resources(0,3);var leader=e.players[0].leader
 leader.zone="grave";e.players[0].grave.append(leader)
 put(AI.AURORA,"hand");e.players[1].life=3
 e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="移回战场" and e.stack[0].target.get("uid",-1)==leader.uid,"Aurora revives grave Remilia before a direct lethal mode")
 resolve_ai()
 expect(leader.zone=="field","Aurora really restores Remilia")
 remilia();resources(0,3);leader=e.players[0].leader
 leader.zone="grave";e.players[0].grave.append(leader)
 for i in range(e.Cat.field_limit(e,0)):plain(0,1,1,1)
 put(AI.AURORA,"hand");e.players[1].life=3
 e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="失去生命","Aurora can finish when revival is blocked by battlefield slots")
 remilia()
 expect(AI.THINK_LIMIT_MSEC==30000,"one AI decision has a 30 second thinking limit")
 e.ai_memory[0]._think_deadline=Time.get_ticks_msec()-1
 expect(AI.think_expired(e,0) and AI.think_deadline(e,0,Time.get_ticks_msec()+1000)<Time.get_ticks_msec(),"nested searches share the expired decision deadline")
func reimu_next_turn():
 var support=put(AI.LILY,"field",1);support.color_counters=["红","黄"]
 resources(2,0,1);put("164","palette",1)
 for c in e.players[1].palette:c.tapped=true
func declare_block(attacker: Dictionary,blocker: Dictionary):
 e.attack(0,attacker.uid);one();e.block([blocker.uid])
func run():
 if "--request-only" in OS.get_cmdline_user_args():
  requested_regressions()
  print("Remilia requested tactics: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 if "--opening-only" in OS.get_cmdline_user_args():
  opening_regressions()
  print("Remilia opening curve: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 if "--hina-only" in OS.get_cmdline_user_args():
  hina_regressions()
  print("Remilia Hina protection: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 if "--public-blocks-only" in OS.get_cmdline_user_args():
  castle_and_block_regressions()
  print("Remilia public blockers: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 if "--core-only" in OS.get_cmdline_user_args():
  engine_removal_regressions()
  print("Remilia engine removal: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 if "--grave-only" in OS.get_cmdline_user_args():
  grave_regressions()
  death_damage_regressions()
  print("Remilia grave recovery: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 if "--pressure-only" in OS.get_cmdline_user_args():
  pressure_regressions()
  queen_priority_regressions()
  print("Remilia pressure: ",checks," checks, ",failures.size()," failures")
  quit(0 if failures.is_empty() else 1)
  return
 var deck=JSON.parse_string(FileAccess.get_file_as_string("res://deck/未命名卡组_7c906ca3ca80.mdeck")).deck
 hina_regressions()
 var generic=Store.blank("通用测试");generic.leader="70";generic.main=Array(deck.main)
 e=Duel.new();e.start(generic,deck,0,55)
 expect(e.ai_profiles==["",AI.PROFILE],"actual Remilia deck automatically selects dedicated AI")
 deck.name="改名卡组"
 expect(AI.profile(deck)==AI.PROFILE and AI.profile(generic).is_empty(),"deck copies recognized while other leaders retain generic AI")
 e.players[1].hand=[]
 var kept=[];var replaced=[]
 for id in [AI.LILY,AI.WINGS,AI.FAIRY,AI.MIST,AI.AURORA]:
  var c=put(id,"hand",1)
  if id in [AI.LILY,AI.WINGS]:kept.append(c.uid)
  else:replaced.append(c.uid)
 e.ai_step(1)
 expect(e.players[1].hand.filter(func(c):return c.uid in kept).size()==2 and e.players[1].hand.all(func(c):return c.uid not in replaced),"mulligan keeps one Lily and Wings while searching for Gungnir")
 remilia();var opening=[]
 for id in [AI.WINGS,AI.WINGS,AI.FAIRY,AI.GUNGNIR]:opening.append(put(id,"hand"))
 expect(AI.mulligan_uids(e,0)==opening.slice(1).map(func(c):return c.uid),"missing Lily replaces Fairy, Gungnir and duplicate Wings to find Lily")
 remilia();opening=[]
 for id in [AI.LILY,AI.LILY,AI.FAIRY,AI.GUNGNIR]:opening.append(put(id,"hand"))
 expect(AI.mulligan_uids(e,0)==opening.slice(1).map(func(c):return c.uid),"with one Lily secured every other card searches for Wings")
 remilia();opening=[]
 for id in [AI.LILY,AI.WINGS,AI.GUNGNIR,AI.FAIRY,AI.LILY]:opening.append(put(id,"hand"))
 expect(AI.mulligan_uids(e,0)==opening.slice(3).map(func(c):return c.uid),"Lily and Wings secured retains one Gungnir and replaces spare cards")
 opening_regressions()
 remilia();resources(2,1)
 var lily=put(AI.LILY);lily.color_counters=["红"]
 put(AI.CASTLE,"hand")
 e.ai_step(0);expect(played()==AI.REMILIA,"three mana uses leader before another permanent")
 resolve_ai();expect(e.players[0].leader.zone=="field" and e.stat(lily,"spirit")==2,"leader resolves and buffs the black board")
 remilia();var small=plain(0,2,2,1);plain(1,3,5,1)
 expect(AI.attack_choice(e,0).is_empty(),"hold attacker that would die while blocker survives")
 remilia();small=plain(0,3,3,1);plain(1,3,3,1)
 expect(AI.attack_choice(e,0).uid==small.uid,"mutual death is not an advantageous opposing block")
 remilia();small=plain(0,1,2,1,["威吓"]);plain(1,5,6,1)
 expect(AI.attack_choice(e,0).uid==small.uid,"menace cannot be blocked by a lone enemy")
 remilia();var enemy=plain(1,2,2,3);var low=plain(0,3,5,1);plain(0,6,6,5)
 e.combat={"attacker":e.ref_target(enemy),"owner":1}
 expect(AI.defensive_blocks(e)==[low.uid],"defense selects surviving blocker with lowest spirit")
 enemy=e.find_card(enemy.uid);enemy.base_override={"power":9,"health":9}
 e.cards[enemy.card_id].power=9;e.cards[enemy.card_id].health=9
 expect(AI.defensive_blocks(e).is_empty(),"defense rejects losing or mutual-death blocks")
 remilia();enemy=plain(1,1,4,2,["威吓"]);var a=plain(0,2,3,1);var b=plain(0,2,3,2);plain(0,5,5,5)
 e.combat={"attacker":e.ref_target(enemy),"owner":1}
 expect(AI.defensive_blocks(e)==[a.uid,b.uid],"menace defense uses cheapest favorable pair")
 remilia();small=plain(0,1,1,1);enemy=plain(1,1,1,1,["先制"])
 expect(AI.attack_choice(e,0).is_empty(),"first-strike blocker that survives holds back ordinary attacker")
 remilia();small=plain(0,3,2,1,["先制"]);enemy=plain(1,5,3,1)
 expect(AI.attack_choice(e,0).uid==small.uid,"first-strike attacker can kill blocker before retaliation")
 remilia();small=plain(0,8,4,3,["威吓"]);a=plain(1,4,3,1);b=plain(1,4,3,1)
 a.wards=[{"amount":3,"turn":e.turn}];b.wards=[{"amount":3,"turn":e.turn}]
 var allocation=AI.damage_allocation(e,small,[a,b],8)
 expect(allocation[str(a.uid)]==6 and allocation[str(b.uid)]==2,"multi-block damage allocation includes wards to kill a blocker")
 e.attack(0,small.uid);e.pass_priority(e.priority);e.pass_priority(e.priority);e.block([a.uid,b.uid])
 resolve_ai()
 expect(a.zone=="grave" and b.zone=="field","ward-aware damage allocation is used by live AI combat")
 remilia()
 for spirit in [6,4,3,2,1,5]:plain(0,1,2,spirit)
 plain(1,4,8,1);plain(1,4,8,1)
 var order=[]
 for i in range(4):
  var c=AI.attack_choice(e,0);order.append(e.stat(c,"spirit"));c.tapped=true
 expect(order==[1,2,3,4] and AI.attack_choice(e,0).is_empty(),"swarm attacks from weakest to strongest and stops at dangerous blocker count")
 remilia();resources(3,2);leader_on_field();plain(0,1,2,1);enemy=plain(1,4,4,2)
 put(AI.GUNGNIR,"hand");put(AI.MIST,"hand")
 e.ai_step(0);expect(played()==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"Gungnir removes dangerous blocker before Mist")
 resolve_ai();expect(enemy.zone=="grave","chosen Gungnir actually kills the blocker")
 remilia();resources(3,2);leader_on_field();plain(0,1,2,1);enemy=plain(1,4,5,2)
 put(AI.GUNGNIR,"hand");put(AI.MIST,"hand")
 e.ai_step(0);expect(played()==AI.MIST,"Mist replaces Gungnir when four damage cannot kill")
 remilia();resources(2,3);leader_on_field();low=plain(0,1,2,1);plain(0,2,3,2);plain(0,3,3,3);enemy=plain(1,4,5,2)
 put(AI.AUTUMN,"hand");e.ai_step(0)
 expect(played()==AI.AUTUMN and e.stack[0].target.sacrifice.uid==low.uid and low.zone=="grave","Autumn sacrifices only weakest body on wide board")
 remilia();resources(2,3);leader_on_field();low=plain(0,1,2,1);enemy=plain(1,4,5,2)
 var autumn=put(AI.AUTUMN,"hand")
 expect(AI.removal_target(e,0,autumn,[enemy]).is_empty(),"Autumn is held on a narrow board")
 remilia();resources(3,1);leader_on_field();put(AI.NUE,"hand");put(AI.CASTLE,"hand")
 e.ai_step(0);expect(played()==AI.NUE,"four mana with surviving leader expands with Nue first")
 remilia();resources(2,2);leader_on_field();put(AI.CASTLE,"hand");put(AI.FAIRY,"hand")
 e.ai_step(0);expect(played()==AI.CASTLE,"four mana prefers Scarlet Mansion to cheap units")
 remilia();var rem=leader_on_field();put(AI.AURORA,"hand");e.damage_target(e.ref_target(rem),3);e.pump_choices()
 e.ai_step(0);expect(rem.zone=="grave","dead leader stays in grave for Aurora without opposing counter mana")
 remilia();rem=leader_on_field();put(AI.AURORA,"hand");resources(0,0)
 put("167","palette",1);put("167","palette",1)
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="leader" and rem.timer==2,"two untapped blue sources send dead leader back to leader area")
 remilia();rem=leader_on_field();put(AI.AURORA,"hand");put("166","palette",1);put("166","palette",1)
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="leader","two untapped green sources also avoid grave recovery")
 remilia();resources(0,3);rem=e.players[0].leader;rem.zone="grave";e.players[0].grave.append(rem)
 e.ai_memory[0].death_turns=e.players[0].turns;var aurora=put(AI.AURORA,"hand")
 expect(AI.spell_target(e,0,aurora).is_empty(),"Aurora recovery waits until next own turn")
 e.players[0].turns+=1;e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.uid==rem.uid,"next turn Aurora prioritizes reviving the actual leader")
 resolve_ai();expect(rem.zone=="field" and is_same(rem,e.players[0].leader),"revived leader preserves leader identity")
 remilia();resources(1,1);leader_on_field();put(AI.DRAW,"hand")
 e.ai_step(0);expect(played()==AI.DRAW and e.stack[0].target.extra==3,"low hand uses paid role draw while reserving five life")
 resolve_ai();expect(e.players[0].life==8 and e.players[0].hand.size()==4,"role draw pays twelve life for four cards")
 remilia();resources(1,1);leader_on_field();e.players[0].life=8
 var draw=put(AI.DRAW,"hand")
 expect(AI.draw_target(e,0,draw).extra==0,"eight life keeps five-life reserve rather than drawing an extra card")
 e.players[0].life=5;expect(AI.draw_target(e,0,draw).extra==0,"five life still permits free first draw")
 put(AI.LILY,"hand");put(AI.FAIRY,"hand")
 expect(AI.draw_target(e,0,draw).is_empty(),"role draw is held when hand is not low")
 remilia();resources(3,3);leader_on_field();put(AI.BIG_REMILIA,"hand");put(AI.CASTLE,"hand")
 e.ai_step(0);expect(played()==AI.BIG_REMILIA,"six mana prioritizes big Remilia")
 remilia();resources(3,3);lily=put(AI.LILY);lily.color_counters=["红"]
 e.ai_memory[0].leader_died=true;put(AI.BIG_REMILIA,"hand")
 e.ai_step(0);expect(played()==AI.REMILIA,"after leader death expired timer prioritizes recasting leader")
 remilia();resources(2,3);rem=leader_on_field();rem.tapped=true
 var vampire=put(AI.FAIRY);enemy=plain(1,3,4,1)
 e.players[1].life=5;put(AI.NIGHT,"hand")
 var before=Codec.capture(e);var started=Time.get_ticks_msec()
 var action=AI.lethal_action(e,0)
 print("Night search: ",Time.get_ticks_msec()-started," ms")
 expect(action.get("card_id","")==AI.NIGHT and action.target.uid==vampire.uid,"lethal route prioritizes Night King and its annihilation buff")
 expect(e.players[1].life==5 and enemy.zone=="field" and not vampire.tapped and e.stack.is_empty(),"lethal simulation does not mutate live state")
 expect(Codec.capture(e).definitions==before.definitions,"lethal simulation leaves live card definitions unchanged")
 AI.execute(e,0,action);resolve_ai()
 for i in range(6):
  if e.winner!=-2:break
  e.priority=0;e.ai_step(0);resolve_ai()
 expect(e.winner==0,"Night King route executes to lethal through blocking unit")
 remilia();resources(2,1);rem=leader_on_field();rem.tapped=true
 put(AI.FAIRY);var bat=e.Roster.create_token(e,0,"bat",1,["红","黑"]);bat.entered_turns=0
 put(AI.RED,"hand");e.players[1].life=8
 for i in range(6):
  if e.winner!=-2:break
  e.priority=0;e.ai_step(0);resolve_ai()
 expect(e.winner==0,"lethal includes lifesteal gained during attacks followed by Scarlet RED damage")
 remilia();resources(0,3);rem=leader_on_field();rem.tapped=true;put(AI.FAIRY);put(AI.AURORA,"hand");e.players[1].life=5
 for i in range(4):
  if e.winner!=-2:break
  e.priority=0;e.ai_step(0);resolve_ai()
 expect(e.winner==0,"lethal combines Aurora life loss with attack damage")
 remilia();plain(0,1,3,5);plain(0,1,3,2);plain(1,0,10,1);e.players[1].life=3
 expect(AI.lethal_action(e,0).is_empty(),"search does not fake lethal by baiting blocker away from high-spirit attacker")
 e.players[1].life=2
 expect(not AI.lethal_action(e,0).is_empty(),"search finds low-spirit damage while enemy reserves blocker for highest spirit")
 # Remilia stays protected even when the swarm or a cached lethal route requests her.
 remilia();rem=leader_on_field();rem.modifiers=[{"灵力":-2}]
 a=plain(0,1,2,1);b=plain(0,1,2,1);enemy=plain(1,4,7,1)
 expect(AI.attack_choice(e,0).get("uid",-1)==a.uid,"swarm attacks a weak unit instead of sacrificing low-spirit Remilia")
 a.tapped=true;b.tapped=true;e.ai_memory[0].swarm_turn=e.turn
 expect(AI.attack_choice(e,0).is_empty(),"swarm continuation never sends Remilia into an advantageous blocker")
 expect(AI.search_actions(e,0).all(func(t):return t.kind!="attack" or t.uid!=rem.uid),"lethal search also excludes dangerous Remilia attacks")
 var unsafe={"kind":"attack","uid":rem.uid,"expected":AI.position_key(e,0)}
 expect(not AI.execute(e,0,unsafe) and not rem.tapped and e.combat.is_empty(),"execution rejects a stale route that exposes Remilia to a losing block")
 e.ai_memory[0].lethal_plan=[unsafe];e.players[1].life=20
 expect(AI.lethal_action(e,0).is_empty() and not e.ai_memory[0].has("lethal_plan"),"unsafe cached Remilia route is invalidated")
 remilia();var big=put(AI.BIG_REMILIA);enemy=plain(1,7,8,1)
 expect(AI.attack_allowed(e,big) and AI.attack_choice(e,0).get("uid",-1)==big.uid,"big Remilia keeps attacking through a losing block")
 enemy.tapped=true
 expect(AI.attack_allowed(e,big),"Remilia can attack after the dangerous blocker becomes tapped")
 remilia();resources(2,3);rem=leader_on_field();enemy=plain(1,4,7,1);put(AI.NIGHT,"hand");e.players[1].life=5
 action=AI.lethal_action(e,0)
 expect(action.get("card_id","")==AI.NIGHT,"Night King can first turn a dangerous Remilia attack into a safe lethal attack")
 # A legal Remilia revival takes precedence while she is actually in the grave.
 remilia();resources(0,3);rem=e.players[0].leader;rem.zone="grave";e.players[0].grave.append(rem)
 aurora=put(AI.AURORA,"hand");e.players[1].life=3
 expect(AI.spell_target(e,0,aurora).get("mode","")=="移回战场","Aurora targets graveyard Remilia before life loss")
 action=AI.lethal_action(e,0)
 expect(action.is_empty(),"lethal search does not override the available Remilia revival")
 remilia();resources(0,6);small=plain(0,1,3,2);var dead=put(AI.LILY,"grave")
 var spare=put(AI.AURORA,"hand");var finisher=put(AI.AURORA,"hand");e.players[1].life=5
 var revival=e.targets_for(AI.AURORA,0).filter(func(t):return t.get("uid",-1)==dead.uid)[0]
 var candidate=[{"kind":"cast","uid":spare.uid,"card_id":AI.AURORA,"target":revival},{"kind":"cast","uid":finisher.uid,"card_id":AI.AURORA,"target":{"player":1,"mode":"失去生命"}},{"kind":"attack","uid":small.uid}]
 var pruned=AI.prune_lethal_route(e,0,candidate)
 expect(pruned.size()==2 and pruned[0].uid==finisher.uid and pruned[0].expected==AI.position_key(e,0),"counterfactual replay removes useless Aurora revival and rebuilds route expectations")
 expect(spare.zone=="hand" and dead.zone=="grave" and e.players[1].life==5,"Aurora route pruning preserves the live game")
 for t in pruned:
  expect(AI.execute(e,0,t),"trimmed Aurora route action executes");resolve_ai()
 expect(e.winner==0 and spare.zone=="hand" and dead.zone=="grave","pruned route kills while keeping unused Aurora and pointless revival in grave")
 remilia();resources(0,3);rem=e.players[0].leader;rem.zone="grave";e.players[0].grave.append(rem)
 for i in range(4):
  var ally=plain(0,1,2,1);e.cards[ally.card_id].colors=["黑"]
 put(AI.AURORA,"hand");e.players[1].life=8
 action=AI.lethal_action(e,0)
 expect(action.get("target",{}).get("uid",-1)==rem.uid,"meaningful Aurora revival is retained when Remilia aura makes lethal possible")
 remilia();resources(0,3);rem=leader_on_field();rem.tapped=true;put(AI.CASTLE);put(AI.CASTLE)
 dead=put(AI.FAIRY,"grave");put(AI.AURORA,"hand");e.players[1].life=4
 action=AI.lethal_action(e,0)
 expect(action.get("target",{}).get("uid",-1)==dead.uid,"Aurora retains a hasty revival that attacks for lethal immediately")
 # Aurora sacrifice can remove isolated expensive bodies and deck leaders.
 remilia();resources(0,3);leader_on_field();enemy=plain(1,7,7,2);put(AI.AURORA,"hand")
 e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="牺牲单位","without a kill spell Aurora prioritizes sacrificing the sole large enemy")
 resolve_ai();expect(enemy.zone=="grave","Aurora sacrifice really removes the isolated high-value body")
 remilia();resources(0,3);enemy=plain(1,1,1,1);e.cards[enemy.card_id].cost={"黄":5}
 put(AI.AURORA,"hand");e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="牺牲单位","high color value alone is enough for isolated Aurora removal")
 remilia();resources(0,3);enemy=e.players[1].leader;enemy.zone="field";enemy.entered_turns=0;e.players[1].field.append(enemy)
 put(AI.AURORA,"hand");e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="牺牲单位","Aurora considers a deck leader valuable even without a large body")
 remilia();resources(0,3);plain(1,6,6,2);plain(1,5,5,2);put(AI.AURORA,"hand");e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="牺牲单位","Aurora may force a sacrifice when both enemy units are strong")
 remilia();resources(0,3);plain(1,6,6,2);plain(1,1,1,1);put(AI.AURORA,"hand")
 expect(AI.aurora_sacrifice_target(e,0).is_empty(),"Aurora is held when the opponent can sacrifice a weak companion")
 remilia();resources(2,3);leader_on_field();enemy=plain(1,4,4,2);e.cards[enemy.card_id].cost={"黄":4}
 put(AI.AURORA,"hand");put(AI.GUNGNIR,"hand")
 expect(AI.aurora_sacrifice_target(e,0).is_empty(),"an affordable effective Gungnir is used before Aurora sacrifice")
 e.ai_step(0);expect(played()==AI.GUNGNIR,"live AI retains Gungnir removal priority over isolated Aurora sacrifice")
 remilia();resources(2,3);leader_on_field();enemy=plain(1,7,7,2);put(AI.AURORA,"hand");put(AI.MIST,"hand")
 expect(AI.aurora_sacrifice_target(e,0).get("mode","")=="牺牲单位","three-mana Aurora sacrifice is preferred over affordable four-mana Mist")
 e.ai_step(0);expect(played()==AI.AURORA and e.stack[0].target.mode=="牺牲单位","live AI sacrifices the isolated large enemy before spending four mana on Mist")
 remilia();resources(0,3);enemy=plain(1,7,7,2);put(AI.AURORA,"hand");put(AI.MIST,"hand")
 expect(AI.aurora_sacrifice_target(e,0).get("mode","")=="牺牲单位","an unaffordable kill spell does not prevent useful Aurora sacrifice")
 remilia();resources(2,3);leader_on_field();put(AI.QUEEN,"hand");e.players[1].life=8
 action=AI.lethal_action(e,0)
 expect(action.get("card_id","")==AI.QUEEN,"lethal search includes four hasty Queen of Midnight bats")
 # Midgame regressions from the Sep 26 mirror: the player won on global turn 18.
 remilia();resources(2,2);rem=leader_on_field();lily=put(AI.LILY);lily.color_counters=["红"]
 for i in range(2):
  bat=e.Roster.create_token(e,0,"bat",1,["红","黑"]);bat.entered_turns=0
 e.players[1].leader=e.make_card(AI.REMILIA,1,"leader",true)
 enemy=e.players[1].leader;enemy.zone="field";enemy.entered_turns=0;e.players[1].field.append(enemy)
 var enemy_fairy=put(AI.FAIRY,"field",1)
 put(AI.NUE,"hand");var gun=put(AI.GUNGNIR,"hand")
 e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"replay turn seven removes enemy Remilia before spending four mana on Nue")
 resolve_ai()
 expect(enemy.zone=="leader" and e.stat(enemy_fairy,"power")==1 and e.Roster.lifesteal(e,enemy_fairy)==1,"removing opposing leader really disables black aura and shared lifesteal")
 # A tapped support leader matters even with no ready attacker or with a larger blocker.
 remilia();resources(3,2);leader_on_field().tapped=true
 plain(0,1,2,1)
 enemy=put(AI.REMILIA,"field",1);enemy.leader=true;enemy.tapped=true
 plain(1,4,4,2);put(AI.FAIRY,"field",1);put(AI.GUNGNIR,"hand");put(AI.CASTLE,"hand")
 e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"tapped enemy aura leader is removed before expansion even without attackers")
 # The third own-turn resources support a leader first, then removal, then expansion.
 remilia();resources(4,3);put(AI.CASTLE);enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 put("character-fdf-065","field",1);put(AI.FAIRY,"field",1)
 put(AI.WINGS,"hand");put(AI.GUNGNIR,"hand")
 e.ai_memory[0].leader_died=true;e.ai_step(0);expect(played()==AI.REMILIA,"replay turn thirteen recasts missing role source first")
 resolve_ai();e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"replay turn thirteen follows recast with leader removal before Wings")
 # Fast removal is useful before a buffed attack or while a new enemy card is on stack.
 remilia();resources(1,1);leader_on_field();enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 put(AI.FAIRY,"field",1);gun=put(AI.GUNGNIR,"hand");e.active=1;e.priority=0
 e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"opponent main phase offers proactive Gungnir removal without a combat object")
 remilia();resources(1,1);leader_on_field();enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 gun=put(AI.GUNGNIR,"hand");resources(1,1,1);var incoming=put(AI.FAIRY,"hand",1)
 e.active=1;e.priority=1;e.commit_cast(1,incoming.uid,{"none":true},e.payment(1,e.cast_cost(1,incoming)).plan)
 e.ai_step(0)
 expect(e.stack.back().get("card",{}).get("card_id","")==AI.GUNGNIR and e.stack.back().target.uid==enemy.uid,"Gungnir can strip enemy aura in response to new opposing unit")
 remilia();resources(1,1);leader_on_field();enemy=plain(1,1,1,1);gun=put(AI.GUNGNIR,"hand");e.active=1;e.priority=0
 e.ai_step(0)
 expect(gun.zone=="hand" and e.stack.is_empty(),"fast removal is held against an unrelated weak unit")
 remilia();resources(1,1);leader_on_field();enemy=put(AI.REMILIA,"field",1);enemy.leader=true;enemy.wards=[{"amount":2,"turn":e.turn}]
 gun=put(AI.GUNGNIR,"hand");e.ai_step(0)
 expect(gun.zone=="hand","proactive Gungnir respects prevention and does not deal insufficient damage")
 # Possession values an actual removal opportunity above routine expansion.
 remilia();resources(2,1);leader_on_field();enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 gun=put(AI.GUNGNIR,"palette");put(AI.NUE,"hand");e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(gun.zone=="hand","possession retrieves Gungnir to remove a public opposing leader")
 remilia();resources(2,1);leader_on_field();enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 gun=put(AI.GUNGNIR,"hand");put(AI.NUE,"palette");e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(gun.zone=="hand","possession keeps useful Gungnir instead of exchanging it for a four-mana unit")
 remilia();resources(3,3);put(AI.CASTLE);enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 gun=put(AI.GUNGNIR,"palette");put(AI.LILY,"hand");e.phase="possession";e.pending={"kind":"possession","owner":0}
 e.ai_step(0)
 expect(gun.zone=="hand","possession plans affordable leader recast plus role removal")
 remilia();resources(1,1);gun=put(AI.GUNGNIR,"palette");enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 var useless=AI.position_score(e,0);e.players[0].palette.erase(gun);gun.zone="hand";e.players[0].hand.append(gun);put(AI.NUE,"palette")
 expect(AI.position_score(e,0)-useless<1800,"unavailable role source does not grant a tactical removal bonus")
 # Nue's turn-eleven attack must not trade four mana for one of two cheap blockers.
 remilia();small=put(AI.NUE);enemy=put(AI.REMILIA,"field",1);enemy.leader=true
 a=put(AI.FAIRY,"field",1);b=put(AI.FAIRY,"field",1)
 expect(not AI.attack_allowed(e,small),"replay turn eleven holds Nue against a losing two-fairy block")
 expect(AI.search_actions(e,0).all(func(t):return t.kind!="attack" or t.uid!=small.uid),"lethal search shares costly-unit trade protection")
 enemy.tapped=true;a.tapped=true;b.tapped=true
 expect(AI.attack_allowed(e,small),"Nue resumes pressure when opposing blockers are tapped")
 # Remilia survives every legal blocking combination, including mutual trades.
 remilia();rem=leader_on_field();enemy=plain(1,3,3,1)
 expect(not AI.attack_allowed(e,rem) and AI.attack_choice(e,0).is_empty(),"Remilia refuses a single blocker that kills her even when it also dies")
 remilia();rem=leader_on_field();a=plain(1,2,2,1);b=plain(1,2,2,1)
 expect(not AI.fight(e,rem,[a]).attacker_dead and not AI.fight(e,rem,[b]).attacker_dead,"each small blocker alone is harmless to Remilia")
 expect(AI.fight(e,rem,[a,b]).attacker_dead and not AI.attack_allowed(e,rem),"combined blocking that kills Remilia is forbidden even if she kills one blocker")
 expect(AI.search_actions(e,0).all(func(t):return t.kind!="attack" or t.uid!=rem.uid),"lethal search excludes mutual-death combined blocks against Remilia")
 e.ai_memory[0].lethal_plan=[{"kind":"attack","uid":rem.uid,"expected":AI.position_key(e,0)}];e.players[1].life=20
 expect(AI.lethal_action(e,0).is_empty() and not e.ai_memory[0].has("lethal_plan"),"cached attack is discarded when a combined block can kill Remilia")
 expect(not AI.execute(e,0,{"kind":"attack","uid":rem.uid}) and not rem.tapped,"route execution independently refuses fatal combined blocking")
 b.tapped=true
 expect(AI.attack_choice(e,0).get("uid",-1)==rem.uid,"Remilia attacks when only the harmless single blocker remains available")
 remilia();rem=leader_on_field()
 e.cards[AI.REMILIA]=e.cards[AI.REMILIA].duplicate(true);e.cards[AI.REMILIA].keywords=["先制"]
 a=plain(1,2,2,1);b=plain(1,2,2,1)
 expect(AI.attack_allowed(e,rem),"first-strike Remilia may kill a blocker before surviving the remaining retaliation")
 remilia();big=put(AI.BIG_REMILIA);a=plain(1,3,3,1);b=plain(1,3,3,1)
 expect(AI.fight(e,big,[a,b]).attacker_dead and AI.attack_allowed(e,big),"big Remilia allows fatal combined blocking")
 expect(AI.attack_choice(e,0).get("uid",-1)==big.uid,"fatal combined blocking does not stop big Remilia's ordinary attack")
 expect(AI.search_actions(e,0).any(func(t):return t.kind=="attack" and t.uid==big.uid),"search includes big Remilia's fatal combined-block attack")
 expect(AI.execute(e,0,{"kind":"attack","uid":big.uid}),"route execution allows big Remilia's fatal combined-block attack")
 remilia();big=put("character-fdf-065");a=plain(1,3,5,1);b=plain(1,3,5,1)
 expect(AI.fight(e,big,[a,b]).attacker_dead and AI.attack_allowed(e,big),"Skyfire attacks despite a fatal menace block and unfavorable body exchange")
 expect(AI.attack_choice(e,0).get("uid",-1)==big.uid,"Skyfire's ordinary attack bypasses costly-unit trade protection")
 expect(AI.search_actions(e,0).any(func(t):return t.kind=="attack" and t.uid==big.uid),"search includes Skyfire's fatal combined-block attack")
 expect(AI.execute(e,0,{"kind":"attack","uid":big.uid}),"route execution allows Skyfire's fatal combined-block attack")
 remilia();resources(1,1);rem=leader_on_field();a=plain(1,2,2,1);b=plain(1,2,2,1);put(AI.GUNGNIR,"hand")
 e.ai_step(0)
 expect(played()==AI.GUNGNIR,"AI removes a member of a fatal combined block before attacking Remilia")
 resolve_ai()
 expect(AI.attack_allowed(e,rem),"removing one member reopens a safe Remilia attack")
 # Gungnir waits for thick blockers, keeping its colors and checking future casts.
 remilia();resources(1,1);rem=leader_on_field();enemy=plain(1,1,6,1)
 gun=put(AI.GUNGNIR,"hand");var small_target=plain(1,1,2,4)
 e.ai_step(0)
 expect(gun.zone=="hand" and played().is_empty() and e.combat.get("owner",-1)==0,"six-health target reserves Gungnir and attacks before considering a smaller threat")
 e.combat={};rem.tapped=false;e.priority=0;e.passes=0
 declare_block(rem,enemy)
 e.ai_step(0)
 expect(gun.zone=="hand" and e.stack.is_empty(),"Gungnir waits through declaration of a safe block")
 e.pass_priority(e.priority)
 expect(e.combat.get("step","")=="damage_window" and enemy.damage==3,"large blocker reaches the real post-damage response window")
 e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"Gungnir finishes the high-health blocker after combat lowers it to three health")
 resolve_ai();expect(enemy.zone=="grave" and rem.zone=="field","post-combat Gungnir actually kills the blocker and preserves Remilia")
 remilia();resources(1,1);rem=leader_on_field();enemy=plain(1,1,8,1);gun=put(AI.GUNGNIR,"hand")
 declare_block(rem,enemy);one();e.ai_step(0)
 expect(enemy.damage==3 and gun.zone=="hand" and e.stack.is_empty(),"five remaining health continues to hold Gungnir after blocking")
 remilia();resources(1,1);rem=leader_on_field();enemy=plain(1,1,4,1)
 enemy.wards=[{"amount":1,"turn":-1},{"amount":1,"turn":-1}];gun=put(AI.GUNGNIR,"hand")
 expect(AI.gungnir_reserve_score(e,0)>0,"stacked prevention counts a four-health body as six effective health")
 declare_block(rem,enemy);one();e.ai_step(0)
 expect(played()==AI.GUNGNIR and enemy.damage==1 and enemy.wards.is_empty(),"Gungnir waits until blocking consumes stacked prevention before finishing")
 resolve_ai();expect(enemy.zone=="grave","ward-inclusive post-block finishing agrees with real damage rules")
 remilia();resources(1,1);leader_on_field().tapped=true
 var sacrifice_attacker=plain(0,3,1,1);enemy=plain(1,1,6,1);gun=put(AI.GUNGNIR,"hand")
 declare_block(sacrifice_attacker,enemy);one();e.ai_step(0)
 expect(sacrifice_attacker.zone=="grave" and played()==AI.GUNGNIR,"a surviving large blocker can be finished even after the attacking unit dies")
 remilia();resources(3,2);leader_on_field();reimu_next_turn()
 gun=put(AI.GUNGNIR,"hand");var expansion=put(AI.NUE,"hand")
 var future_value=AI.upcoming_gungnir_value(e,0)
 expect(future_value>=AI.REIMU_PRIORITY and e.players[1].leader.zone=="leader" and e.players[1].palette.all(func(c):return c.tapped),"public Reimu is forecast after reset without mutating live leader or colors")
 e.ai_step(0)
 expect(expansion.zone=="hand" and gun.zone=="hand" and e.payment(0,{"红":1,"黑":1}).ways>0,"four-mana expansion cannot consume the colors reserved for next-turn Reimu")
 remilia();resources(3,2);leader_on_field();reimu_next_turn()
 gun=put(AI.GUNGNIR,"hand");var cheap_expansion=put(AI.FAIRY,"hand")
 expect(AI.cast(e,0,cheap_expansion,{"none":true}) and e.payment(0,{"红":1,"黑":1}).ways>0,"cheap expansion is still allowed when one red and one black remain for Gungnir")
 remilia();leader_on_field();reimu_next_turn();e.players[1].leader.timer=1
 expect(AI.upcoming_gungnir_value(e,0)==0,"a leader still on cooldown is not forecast as a legal next-turn cast")
 e.players[1].leader.timer=0;e.players[1].field[0].color_counters=[]
 expect(AI.upcoming_gungnir_value(e,0)==0,"future Reimu must satisfy actual battlefield colors")
 remilia();leader_on_field();known_spell(AI.CLOUD)
 for i in range(2):put("167","palette",1);put("166","palette",1)
 expect(AI.upcoming_gungnir_value(e,0)>0,"known four-health Cloud with the extra green for duel reserves Gungnir")
 var prediction_copy=Codec.capture(e)
 AI.upcoming_gungnir_value(e,0)
 expect(e.players[1].hand[0].zone=="hand" and e.players[1].field.is_empty() and e.cards==prediction_copy.definitions,"future unit preview leaves hand, battlefield and definitions untouched")
 remilia();leader_on_field()
 for i in range(2):put("167","palette",1);put("166","palette",1)
 var hidden_cloud=put(AI.CLOUD,"hand",1)
 expect(AI.upcoming_gungnir_value(e,0)==0,"unrevealed Cloud is not read from the opponent's hand")
 e.reveal_card(hidden_cloud)
 expect(AI.upcoming_gungnir_value(e,0)>0,"revealed Cloud enters future unit calculations")
 remilia();resources(1,1);rem=leader_on_field();gun=put(AI.GUNGNIR,"hand");var cloud=known_spell(AI.CLOUD)
 small_target=plain(1,1,2,4)
 for i in range(2):put("167","palette",1);put("166","palette",1)
 e.active=1;e.priority=1
 var cloud_mode={"none":true,"mode":"额外支付1绿","extra_green":true}
 expect(e.commit_cast(1,cloud.uid,cloud_mode,e.payment(1,e.cast_cost(1,cloud,cloud_mode)).plan).is_empty(),"opponent declares Cloud with paid duel")
 e.ai_step(0)
 expect(gun.zone=="hand" and e.stack.size()==1,"incoming paid Cloud reserves Gungnir instead of shooting an existing smaller unit")
 e.pass_priority(e.priority)
 if e.pending.get("kind","")=="trigger_order":e.choose_trigger_order(0)
 if e.pending.get("kind","")=="effect_choice":e.choose_effect(e.ref_target(rem))
 e.ai_step(0)
 expect(e.stack.back().get("card",{}).get("card_id","")==AI.GUNGNIR and e.stack.back().target.uid==cloud.uid,"Gungnir removes four-health Cloud before its duel with Remilia")
 resolve_ai();expect(cloud.zone=="grave" and rem.zone=="field" and rem.damage==0,"killing Cloud invalidates its pending duel and keeps Remilia safe")
 remilia();resources(1,1);leader_on_field();gun=put(AI.GUNGNIR,"hand")
 var opposing_rem=put(AI.REMILIA,"field",1);opposing_rem.leader=true
 var opposing_reimu=put("70","field",1);enemy=plain(1,1,6,1)
 e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==opposing_reimu.uid,"four-health Reimu has highest Gungnir priority over Remilia aura and a thick blocker")
 e.stack=[];e.players[0].hand.append(gun);gun.zone="hand";e.priority=0;resources(1,1)
 var gun_actions=AI.search_actions(e,0).filter(func(t):return t.get("card_id","")==AI.GUNGNIR)
 expect(not gun_actions.is_empty() and gun_actions[0].target.uid==opposing_reimu.uid,"lethal search tries four-health Reimu before other Gungnir targets")
 remilia();resources(1,1);rem=leader_on_field();reimu_next_turn();enemy=plain(1,1,6,1);gun=put(AI.GUNGNIR,"hand")
 declare_block(rem,enemy);one();e.ai_step(0)
 expect(enemy.damage==3 and gun.zone=="hand" and e.stack.is_empty(),"next-turn four-health Reimu takes priority over finishing an ordinary wounded blocker")
 remilia();resources(1,1);leader_on_field();reimu_next_turn();gun=put(AI.GUNGNIR,"hand")
 e.active=1;e.priority=1
 for c in e.players[1].palette:c.tapped=false
 var incoming_reimu=e.players[1].leader
 expect(e.commit_cast(1,incoming_reimu.uid,{"none":true},e.payment(1,e.cast_cost(1,incoming_reimu)).plan).is_empty(),"opponent legally casts its public four-health Reimu")
 e.ai_step(0);e.pass_priority(e.priority);e.pass_priority(e.priority);e.ai_step(0)
 expect(played()==AI.GUNGNIR and e.stack[0].target.uid==incoming_reimu.uid,"reserved Gungnir is used as soon as Reimu enters on the opposing turn")
 remilia();resources(1,1);leader_on_field();reimu_next_turn();gun=put(AI.GUNGNIR,"hand")
 small_target=plain(1,2,3,4)
 expect(not AI.use_gungnir(e,0,small_target,true),"finishing the turn still preserves Gungnir for a legal next-turn four-health Reimu")
 e.players[1].leader.timer=1
 expect(AI.use_gungnir(e,0,small_target,true),"lesser removal becomes available once the future high-priority opportunity disappears")
 remilia();resources(1,1);rem=leader_on_field();small_target=plain(1,1,2,1);gun=put(AI.GUNGNIR,"hand")
 declare_block(rem,small_target);e.ai_step(0)
 expect(gun.zone=="hand" and e.stack.is_empty(),"a small blocker that ordinary combat will kill does not consume Gungnir")
 # Public exchanges are remembered by identity, forgotten on hidden moves.
 remilia();var retrieved=put("112","palette",1);var exchanged=put(AI.FAIRY,"hand",1)
 e.phase="possession";e.pending={"kind":"possession","owner":1}
 e.possession(retrieved.uid,exchanged.uid)
 expect(AI.known_hand(e,0).get(str(retrieved.uid),{}).get("card_id","")=="112" and not AI.known_hand(e,0).has(str(exchanged.uid)),"possession remembers retrieved public spell but does not reveal unknown hand cards")
 var memory_copy=Duel.new(e.cards);Codec.restore(memory_copy,Codec.capture(e))
 expect(AI.known_hand(memory_copy,0)==AI.known_hand(e,0),"state codec preserves public opposing hand memory")
 e.move_to(retrieved,"deck");e.move_to(retrieved,"hand")
 expect(AI.known_hand(e,0).is_empty(),"returning a known card through hidden deck forgets its identity")
 e.reveal_card(retrieved)
 expect(AI.known_hand(e,0).has(str(retrieved.uid)),"explicit public hand reveal is remembered")
 e.move_to(retrieved,"grave")
 expect(AI.known_hand(e,0).is_empty(),"played or discarded known spell is removed from hand memory")
 # Remaining colors support damage/buffs only when jointly payable and legal.
 remilia();rem=leader_on_field();enemy=plain(1,1,2,1);resources(1,0,1)
 var sweet=known_spell("112")
 expect(not AI.attack_allowed(e,rem),"known Sweet Moment makes an otherwise harmless blocker kill Remilia")
 var red_source=e.players[1].palette[0];red_source.tapped=true
 expect(AI.attack_allowed(e,rem),"tapped red source removes the known attack buff risk")
 red_source.tapped=false;enemy.tapped=true
 expect(AI.attack_allowed(e,rem),"a buff cannot turn a tapped unit into a legal blocker")
 enemy.tapped=false;e.players[1].night_lock=e.turn
 expect(AI.attack_allowed(e,rem),"Night King response lock removes even an affordable known buff risk")
 remilia();rem=leader_on_field();enemy=plain(1,1,2,1);resources(1,0,1);put("164","palette",1)
 known_spell("177")
 expect(not AI.attack_allowed(e,rem),"Tower Light combines added blocker power and prevention")
 e.players[1].palette.back().tapped=true
 expect(AI.attack_allowed(e,rem),"Tower Light requires both untapped red and yellow")
 remilia();rem=leader_on_field();enemy=plain(1,1,2,1);resources(1,0,1);put("164","palette",1)
 var damage_spell=known_spell("96")
 expect(not AI.attack_allowed(e,rem),"two fast damage plus one blocking power is lethal even when neither is lethal alone")
 var unchanged=Codec.capture(e)
 AI.attack_allowed(e,rem)
 expect(e.players[1].hand.has(damage_spell) and damage_spell.zone=="hand" and not rem.tapped and e.stack.is_empty() and Codec.capture(e).definitions==unchanged.definitions,"response previews leave live fighters, resources, cards and definitions untouched")
 remilia();rem=leader_on_field();rem.modifiers=[{"血量":2}];enemy=plain(1,1,2,1)
 resources(1,0,1);put("164","palette",1);known_spell("96");known_spell("112")
 expect(AI.attack_allowed(e,rem),"damage and buff cannot both spend the same red source")
 resources(1,0,1)
 expect(not AI.attack_allowed(e,rem),"jointly affordable fast damage and buff are combined with blocking power")
 remilia();rem=leader_on_field();enemy=plain(1,1,2,1);resources(1,0,1)
 var hidden_spell=put("164","hand",1)
 expect(not AI.attack_allowed(e,rem),"unknown hand with reserved red considers a possible Sweet Moment")
 var hidden_key=AI.position_key(e,0);hidden_spell.card_id=AI.GUNGNIR
 expect(AI.position_key(e,0)==hidden_key and not AI.attack_allowed(e,rem),"changing hidden identity cannot change the color-based decision")
 var masked=AI.simulation(e,0)
 expect(masked.players[1].hand[0].card_id=="164","simulation masks an unobserved opposing spell")
 remilia();rem=leader_on_field();known_spell(AI.GUNGNIR);resources(1,1,1)
 expect(AI.attack_allowed(e,rem),"known Gungnir cannot be used without its character role")
 put(AI.REMILIA,"field",1)
 expect(not AI.attack_allowed(e,rem),"known affordable Gungnir prevents even an unblocked lethal Remilia attack")
 e.players[1].life=2
 expect(AI.lethal_action(e,0).is_empty() and AI.search_actions(e,0).all(func(t):return t.kind!="attack" or t.uid!=rem.uid),"lethal planning shares the known fast damage protection")
 # Known counters change recovery and lethal calculation using actual targets.
 remilia();resources(0,3);put(AI.AURORA,"hand");e.players[1].life=3
 known_spell("131");put("164","palette",1);put("164","palette",1);put("164","palette",1)
 expect(AI.lethal_action(e,0).is_empty(),"known counter prevents a false Aurora lethal route")
 e.players[1].palette[0].tapped=true
 expect(not AI.lethal_action(e,0).is_empty(),"spent counter color reopens Aurora lethal")
 remilia();known_spell("131");put("164","palette",1);put("164","palette",1);put("164","palette",1)
 expect(AI.counter_mana(e,1),"known yellow counter is considered even without double blue or green")
 e.players[1].palette[0].tapped=true
 expect(not AI.counter_mana(e,1),"known yellow counter needs all three remaining colors")
 remilia();known_spell("100");put("164","palette",1);put("164","palette",1)
 expect(not AI.counter_mana(e,1),"a known character counter without its role is not an available response")
 put("70","field",1)
 expect(AI.counter_mana(e,1),"known character counter becomes a threat after its role enters")
 e.cards["100"]=e.cards["100"].duplicate(true);e.cards["100"].cost={}
 for c in e.players[1].palette:c.tapped=true
 expect(AI.counter_mana(e,1),"free known counter is considered without remaining color sources")
 grave_regressions()
 death_damage_regressions()
 pressure_regressions()
 queen_priority_regressions()
 castle_and_block_regressions()
 lethal_regressions()
 engine_removal_regressions()
 # Combat and state codec are shared with network/replay paths.
 remilia();leader_on_field()
 var copy=Duel.new(e.cards);Codec.restore(copy,Codec.capture(e))
 expect(copy.ai_profiles[0]==AI.PROFILE and is_same(copy.players[0].leader,copy.players[0].field[0]),"AI state roundtrip preserves profile and leader identity")
 e=Duel.new();e.start(deck,deck,1,208)
 var stalled=false;var total_msec=Time.get_ticks_msec();var max_step=0
 for i in range(1600):
  if e.winner!=-2:break
  var owner=e.pending.owner if not e.pending.is_empty() else e.priority
  if e.phase=="mulligan":owner=0 if not e.players[0].mulligan_done else 1
  var revision=e.revision;var t=Time.get_ticks_msec()
  e.ai_step(owner);max_step=maxi(max_step,Time.get_ticks_msec()-t)
  if revision==e.revision:stalled=true;break
 print("AI match: winner=",e.winner,", turn=",e.turn,", elapsed=",Time.get_ticks_msec()-total_msec," ms, longest step=",max_step," ms")
 expect(not stalled and e.winner!=-2,"full Remilia mirror match completes with both seats using specialized AI")
 print("Remilia AI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func opening_regressions():
 remilia();resources(0,1);put(AI.LILY,"hand");put(AI.WINGS,"hand");put(AI.CASTLE,"hand")
 e.ai_step(0)
 expect(played()==AI.LILY,"first player with only one payable mana plays Lily Black")
 resolve_ai()
 expect(e.units(0)[0].get("color_counters",[])==["红"],"Lily Black chooses only red and resolves its entry trigger")
 # A potato on the one-palette turn does not replace Lily's opening priority.
 for source in ["168","165",AI.GUNGNIR,AI.NUE]:
  for hand in [[AI.LILY,AI.WINGS,AI.FAIRY],[AI.FAIRY,AI.WINGS,AI.LILY]]:
   remilia();e.first=1;put(source,"palette");e.players[0].potato=true
   for id in hand:put(id,"hand")
   e.ai_step(0)
   expect(played()==AI.LILY,"second player keeps the one-palette Lily opening: "+source)
   resolve_ai()
   expect(e.units(0).size()==1 and e.players[0].hand.any(func(c):return c.card_id==AI.WINGS),"one-palette opening resolves Lily and retains Wings")
 remilia();e.first=1;resources(0,1);e.players[0].potato=true;put(AI.LILY,"hand")
 e.ai_step(0);expect(played()==AI.LILY and e.players[0].potato,"without Wings the black palette pays Lily and keeps potato")
 remilia();e.first=1;put("164","palette");e.players[0].potato=true
 put(AI.LILY,"hand");put(AI.WINGS,"hand")
 e.ai_step(0);expect(played()==AI.LILY,"two sources lacking red plus black cannot cast Wings")
 remilia();e.first=1;resources(1,1);e.players[0].potato=true
 var early_lily=put(AI.LILY);early_lily.color_counters=["红"]
 put(AI.WINGS,"hand");put(AI.FAIRY,"hand");put(AI.GUNGNIR,"hand");plain(1,4,4,1)
 e.ai_step(0)
 expect(played()==AI.REMILIA and not e.players[0].potato,"second player uses potato for legal Remilia before Wings or removal")
 remilia();e.first=1;resources(1,1);e.players[0].potato=true;put(AI.WINGS,"hand")
 e.ai_step(0);expect(played()==AI.WINGS and e.players[0].potato,"potato does not bypass Remilia battlefield color requirements")
 remilia();resources(1,1)
 for id in [AI.FAIRY,AI.LILY,AI.WINGS]:put(id,"hand")
 e.ai_step(0);expect(played()==AI.WINGS,"two mana prefers Wings over Vampire Fairy and Lily")
 resolve_ai();expect(e.units(0).size()==2,"Wings actually creates two bats")
 remilia();resources(1,1);put(AI.LILY,"hand");put(AI.FAIRY,"hand")
 e.ai_step(0);expect(played()==AI.FAIRY,"two mana prefers Vampire Fairy over Lily without Wings")

func engine_removal_regressions():
 for id in ["71","character-fdf-ex05",AI.REMILIA]:
  remilia();resources(1,1);leader_on_field();put(AI.GUNGNIR,"hand")
  var core=put(id,"field",1);core.leader=true;core.tapped=true
  plain(1,1,6,1);var lesser=plain(1,1,2,4)
  e.ai_step(0)
  expect(played()==AI.GUNGNIR and e.stack.back().target.uid==core.uid,"Gungnir prioritizes tapped killable battlefield engine over thick blockers and ordinary threats: "+id)
  resolve_ai();expect(core.zone in ["leader","grave","return_pending"],"priority Gungnir actually removes the core: "+id)
  remilia();resources(1,1);leader_on_field();var gun=put(AI.GUNGNIR,"hand")
  core=put(id,"field",1);core.leader=true
  core.wards=[{"amount":5,"turn":-1}]
  expect(not AI.gungnir_engine(e,core),"protected engine does not receive killable Gungnir priority: "+id)
  e.ai_step(0);expect(gun.zone=="hand","Gungnir is not wasted into engine damage prevention: "+id)
 # Independently activated copies count even without an enabled self ability.
 for id in ["71","character-fdf-ex05"]:
  remilia();resources(1,1);leader_on_field();put(AI.GUNGNIR,"hand")
  var core=put(id,"field",1);core.tapped=true
  expect(not e.has_leader_ability(core) and AI.gungnir_engine(e,core),"activated non-leader copy remains a core target: "+id)
  e.active=1;e.priority=0;e.ai_step(0)
  expect(played()==AI.GUNGNIR and e.stack.back().target.uid==core.uid,"fast removal handles core on opposing turn: "+id)
 # Keep Reimu's existing top priority over other core engines.
 remilia();resources(1,1);leader_on_field();put(AI.GUNGNIR,"hand")
 var yuyuko=put("71","field",1);yuyuko.leader=true
 var reimu=put("70","field",1)
 e.ai_step(0);expect(played()==AI.GUNGNIR and e.stack.back().target.uid==reimu.uid,"Reimu retains highest Gungnir priority among core engines")
 remilia();resources(1,1);leader_on_field();put(AI.GUNGNIR,"hand")
 yuyuko=put("71","field",1);yuyuko.leader=true;yuyuko.base_override={"health":5}
 expect(not AI.gungnir_engine(e,yuyuko),"five remaining health does not count as a killable core")
 yuyuko.damage=1
 expect(AI.gungnir_engine(e,yuyuko),"a wounded engine becomes a priority at four remaining health")
 yuyuko.wards=[{"amount":1,"turn":-1}]
 expect(not AI.gungnir_engine(e,yuyuko),"four remaining health plus prevention still requires real lethal damage")
 # Reproduce the turn-eleven ordering problem with exact combined fees.
 for count in [5,6]:
  remilia();resources(count-2,2)
  var lily=put(AI.LILY);lily.color_counters=["红"]
  var gun=put(AI.GUNGNIR,"hand");var mist=put(AI.MIST,"hand")
  yuyuko=put("71","field",1);yuyuko.leader=true
  e.ai_step(0)
  expect(played()==AI.REMILIA and mist.zone=="hand","restore Remilia before four-mana Mist when leader plus Gungnir fits: "+str(count))
  resolve_ai();e.ai_step(0)
  expect(played()==AI.GUNGNIR and e.stack.back().target.uid==yuyuko.uid,"restoring leader really leaves colors for priority Gungnir: "+str(count))
  resolve_ai();expect(e.players[0].leader.zone=="field" and yuyuko.zone=="leader" and mist.zone=="hand","combined core removal keeps the Remilia aura and saves Mist: "+str(count))
 remilia();resources(2,2);var lily=put(AI.LILY);lily.color_counters=["红"]
 put(AI.GUNGNIR,"hand");put(AI.MIST,"hand");yuyuko=put("71","field",1);yuyuko.leader=true
 e.ai_step(0);expect(played()==AI.MIST,"insufficient combined fees do not pretend leader plus Gungnir is available")
 remilia();resources(3,2);lily=put(AI.LILY);lily.color_counters=["红"]
 put(AI.GUNGNIR,"hand");put(AI.MIST,"hand");yuyuko=put("71","field",1);yuyuko.leader=true
 e.players[0].leader.timer=1
 e.ai_step(0);expect(played()==AI.MIST,"cooldown still prevents priority leader restoration")

func replay_lethal_board():
 remilia();e.turn=9;e.players[0].turns=5;e.players[1].turns=4
 for id in ["character-fdf-065",AI.BIG_REMILIA,AI.BIG_REMILIA,"18",AI.MIST]:put(id,"palette")
 leader_on_field();var locked=put(AI.LILY);locked.color_counters=["红"];locked.tapped=true
 var bats=[]
 for i in range(2):
  var bat=e.Roster.create_token(e,0,"bat",1,["红","黑"]);bat.entered_turns=0;bats.append(bat)
 var enemy=put("character-ucs-060","field",1)
 for id in [AI.CASTLE,AI.LILY,"18",AI.NUE,AI.AURORA]:put(id,"hand")
 e.players[1].life=9
 for i in range(4):put("164","palette",1).tapped=true
 put("177","hand",1)
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 return {"bats":bats,"enemy":enemy}

func grave_regressions():
 for id in AI.BIG_UNITS:
  remilia();resources(1,0)
  var big=put(id,"palette");big.tapped=true
  put(id,"hand")
  var cheap=put(AI.AURORA,"palette");cheap.tapped=true
  put(AI.AYA,"hand")
  var fairy=put(AI.FAIRY)
  var before=JSON.stringify([e.players,e.stack,e.pending,e.revision])
  var options=[e.ref_target(cheap),e.ref_target(big)]
  expect(AI.effect_target(e,0,options,{"effect":"crystal","source":fairy}).uid==big.uid,"Fairy crystallizes a spare heavy unit "+id+" for Aya")
  expect(JSON.stringify([e.players,e.stack,e.pending,e.revision])==before,"crystal selection leaves live state unchanged")
  e.move_to(fairy,"grave");e.pump_choices();resolve_ai()
  expect(big.zone=="grave" and fairy.zone=="palette" and not fairy.tapped and cheap.zone=="palette","real Fairy death exchanges a spare large unit for upright Fairy")
  expect(AI.aya_target(e,0).parts[0].uid==big.uid,"crystallized unit becomes Aya's four-damage recovery target")
 remilia();resources(2,1);leader_on_field()
 var big=put(AI.BIG_REMILIA,"palette");big.tapped=true
 var cheap=put(AI.WINGS,"palette");cheap.tapped=true;put(AI.FAIRY,"hand")
 expect(AI.crystal_target(e,0,[e.ref_target(big),e.ref_target(cheap)]).uid==cheap.uid,"crystal preserves six-cost Remilia and prefers ordinary Wings")
 remilia();resources(1,1)
 big=put(AI.BIG_REMILIA,"palette");big.tapped=true
 var spear=put("character-fdf-065","palette");spear.tapped=true
 put(AI.AYA,"hand");leader_on_field()
 expect(AI.crystal_target(e,0,[e.ref_target(big),e.ref_target(spear)]).is_empty(),"even with Aya crystal keeps the last six-cost Remilia and seven-cost Spear")
 remilia();resources(2,2)
 var dead=put(AI.BIG_REMILIA,"grave");put(AI.FAIRY,"grave")
 var aya=put(AI.AYA,"hand");var enemy=plain(1,8,8,5)
 var target=AI.aya_target(e,0)
 expect(target.parts[0].uid==dead.uid and target.parts[1].get("player",-1)==1,"Aya prefers four-spirit recovery and damage to opposing player over their unit")
 e.ai_step(0);expect(played()==AI.AYA,"live AI plays Aya to turn a grave unit into player damage")
 resolve_ai();expect(dead.zone=="hand" and e.players[1].life==16 and enemy.damage==0,"Aya really returns the four-spirit unit and deals four to player")
 remilia();resources(2,2);aya=put(AI.AYA,"hand")
 expect(AI.spell_target(e,0,aya).is_empty() and AI.search_actions(e,0).all(func(a):return a.get("card_id","")!=AI.AYA),"Aya is held with no grave unit in both normal play and lethal search")
 for id in ["character-fdn-043","35"]:
  for recovery in [AI.AYA,AI.AURORA]:
   remilia();resources(3,3);var rem=leader_on_field();put(recovery,"hand");put(id,"field",1)
   e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
   expect(rem.zone=="leader","available grave remover "+id+" blocks death plan with "+recovery)
  remilia();resources(2,2);dead=put(AI.BIG_REMILIA,"grave");aya=put(AI.AYA,"hand");var remover=put(id,"field",1)
  expect(AI.spell_target(e,0,aya).is_empty() and AI.search_actions(e,0).all(func(a):return a.get("card_id","")!=AI.AYA),"available "+id+" excludes Aya from normal play and search")
  if id=="35":
   remover.tapped=true
   expect(not AI.spell_target(e,0,aya).is_empty(),"tapped Shiki cannot stop an immediate Aya recovery")
   remover.tapped=false;remover.entered_turns=e.players[1].turns
   expect(not AI.spell_target(e,0,aya).is_empty(),"summoning-sick Shiki cannot activate against immediate Aya recovery")
  else:
   remover.tapped=true;remover.entered_turns=e.players[1].turns
   expect(AI.spell_target(e,0,aya).is_empty(),"Fujimi sacrifice still threatens Aya while tapped and summoning sick")
  remover.tapped=false;remover.entered_turns=0
  var before=JSON.stringify([e.players,e.pending,e.revision])
  AI.grave_removal_ready(e,0,dead)
  expect(JSON.stringify([e.players,e.pending,e.revision])==before,"grave-removal legality probe preserves live state")
  var lock=put("character-fdf-101");lock.locked_name=e.cards[id].name
  expect(not AI.spell_target(e,0,aya).is_empty(),"named activation lock permits Aya against disabled "+id)
  lock.locked_name=""
  e.players[1].night_lock=e.turn
  expect(not AI.spell_target(e,0,aya).is_empty(),"Night lock permits immediate Aya recovery against "+id)
 remilia();resources(3,3);var rem=leader_on_field();put(AI.AYA,"hand");var shiki=put("35","field",1);shiki.tapped=true
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="leader","death on own turn anticipates Shiki untapping before the next recovery turn")
 remilia();resources(3,3);rem=leader_on_field();put(AI.AYA,"hand");put("35","field",1)
 e.active=1;e.players[1].night_lock=e.turn
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="leader","temporary opponent-turn Night lock expires before next-turn grave recovery")
 remilia();resources(3,3);rem=leader_on_field();put(AI.AYA,"hand");put("41","field",1)
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="leader","death-consuming grave trigger also prevents leaving Remilia in grave")
 remilia()
 for id in [AI.FAIRY,AI.FAIRY,"168"]:put(id,"palette").tapped=true
 rem=leader_on_field();aya=put(AI.AYA,"hand");var aurora=put(AI.AURORA,"hand")
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="grave","three-mana death keeps Remilia in grave with both recovery options")
 e.players[0].turns+=1;e.turn+=2;e.priority=0
 for c in e.players[0].palette:c.tapped=false
 resources(0,1)
 expect(e.payment(0,e.cast_cost(0,aya)).ways>0 and e.payment(0,e.cast_cost(0,aurora)).ways>0,"four-mana fixture can legally pay either Aya or Aurora")
 e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.get("mode","")=="移回战场" and e.stack[0].target.get("uid",-1)==rem.uid,"three-mana death prioritizes next-turn Aurora revival over Aya recovery")
 resolve_ai();expect(rem.zone=="field" and aya.zone=="hand","preferred Aurora restores Remilia immediately and keeps Aya for later")
 # Next-turn seven-cost recovery and three/four/five staggered recovery.
 for early in [false,true]:
  remilia();resources(2 if early else 3,1 if early else 3)
  rem=leader_on_field();aya=put(AI.AYA,"hand")
  for c in e.players[0].palette:c.tapped=true
  e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
  expect(rem.zone=="grave","Aya death plan enters grave for "+("three/four/five" if early else "next-turn seven mana"))
  e.players[0].turns+=1;e.turn+=2;e.priority=0
  for c in e.players[0].palette:c.tapped=false
  resources(0 if early else 1,1 if early else 0)
  e.ai_step(0);expect(played()==AI.AYA,"planned recovery casts Aya before expansion")
  resolve_ai();expect(rem.zone=="hand" and e.players[1].life==18,"Aya recovery keeps actual leader in hand and deals two to player")
  if early:
   expect(e.players[0].palette.all(func(c):return c.tapped),"four-mana Aya spends the whole early recovery turn")
   e.players[0].turns+=1;e.turn+=2
   for c in e.players[0].palette:c.tapped=false
   resources(1,0)
  e.priority=0;e.ai_step(0);expect(played()==AI.REMILIA,"recovered Remilia is replayed as soon as the planned turn can pay")
  resolve_ai();expect(rem.zone=="field" and rem.leader,"Aya combo preserves leader identity through grave, hand and battlefield")
 remilia();resources(2,2);rem=leader_on_field();put(AI.AYA,"hand")
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="leader","five-mana next turn cannot fund seven-cost combo and is outside early staggered branch")
 remilia();resources(2,2);rem=e.players[0].leader;rem.zone="grave";e.players[0].grave.append(rem)
 dead=put(AI.BIG_REMILIA,"grave");aya=put(AI.AYA,"hand");e.players[1].life=4
 expect(AI.aya_target(e,0).parts[0].uid==dead.uid,"immediate four-damage Aya lethal precedes two-damage leader recovery")
 var action=AI.lethal_action(e,0)
 expect(action.get("card_id","")==AI.AYA,"lethal search finds Aya recovery damage")
 expect(AI.execute(e,0,action),"Aya lethal action executes");resolve_ai()
 expect(e.winner==0,"Aya lethal uses actual grave recovery and player damage")

func death_damage_regressions():
 # A late death must not reserve an Aurora needed for a present/next-turn kill.
 for opponent_turn in [false,true]:
  for copies in [1,2]:
   remilia();resources(2,6);var rem=leader_on_field()
   for i in range(copies):put(AI.AURORA,"hand")
   e.players[1].life=3*copies
   if opponent_turn:
    e.active=1;e.priority=1
    for c in e.players[0].palette:c.tapped=true
   e.damage_target(e.ref_target(rem),3);e.pump_choices()
   var before=Codec.capture(e)
   expect(not AI.grave_recovery(e,0,e.pending.card),"late death preserves "+str(copies)+" Aurora(s) for "+("next-turn" if opponent_turn else "current-turn")+" lethal")
   expect(Codec.capture(e)==before,"late death planning preserves the complete live state")
   e.ai_step(0)
   expect(rem.zone=="leader","Aurora lethal returns Remilia home rather than reserving revival")
   if opponent_turn:
    e.active=0;e.priority=0;e.players[0].turns+=1;e.turn+=1
    for c in e.players[0].palette:c.tapped=false
   for i in range(copies):e.ai_step(0);resolve_ai()
   expect(e.winner==0,"held Aurora(s) execute the real lethal after the return choice")
 # Six colors cannot pay revival plus Queen. Home permits support through timer.
 for blocked in [false,true]:
  remilia();resources(2,4);var rem=leader_on_field();put(AI.CASTLE)
  put(AI.AURORA,"hand");var queen=put(AI.QUEEN,"hand")
  if blocked:plain(1,2,3,1)
  e.players[1].life=20;e.active=1;e.priority=1
  for c in e.players[0].palette:c.tapped=true
  e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
  expect(rem.zone=="leader","late death chooses next-turn Queen damage, blocker="+str(blocked))
  e.active=0;e.priority=0;e.players[0].turns+=1;e.turn+=1
  for c in e.players[0].palette:c.tapped=false
  expect(rem.timer>0 and e.cast_error(0,queen.uid).is_empty(),"Queen is really legal with Remilia counting down at home")
  for i in range(10):
   e.ai_step(0);resolve_ai()
   if e.phase!="main" or e.winner!=-2:break
  expect(queen.zone!="hand" and e.players[1].life<=14,"home route actually casts Queen and deals its projected damage")
 # When colors fund both revival and four bats, Remilia's aura is stronger.
 remilia();resources(2,5);var rem=leader_on_field();put(AI.CASTLE)
 put(AI.AURORA,"hand");put(AI.QUEEN,"hand");e.players[1].life=20
 e.active=1;e.priority=1
 for c in e.players[0].palette:c.tapped=true
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="grave","late death still takes revival when legal aura plus Queen deals more damage")
 e.active=0;e.priority=0;e.players[0].turns+=1;e.turn+=1
 for c in e.players[0].palette:c.tapped=false
 e.ai_step(0);expect(played()==AI.AURORA and e.stack[0].target.mode=="移回战场","better grave route pays for real revival first")
 resolve_ai()
 for i in range(10):
  e.ai_step(0);resolve_ai()
  if e.phase!="main" or e.winner!=-2:break
 expect(e.players[1].life<=8,"seven-color recovery route really produces the larger twelve-damage burst")
 # Wrong colors or insufficient slots cannot turn an impossible Queen into value.
 remilia();resources(0,6);rem=leader_on_field();put(AI.AURORA,"hand");put(AI.QUEEN,"hand")
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="grave","unpayable Queen does not displace useful Aurora recovery")
 remilia();resources(2,4);rem=leader_on_field();put(AI.AURORA,"hand");put(AI.QUEEN,"hand")
 for i in range(3):plain(0,0,1,0,["不能攻击"])
 e.damage_target(e.ref_target(rem),3);e.pump_choices();e.ai_step(0)
 expect(rem.zone=="grave","fewer than four free slots do not justify home for an impossible bat batch")

func pressure_regressions():
 # Above the old twelve-life gate, Queen + Castle pressures through a blocker.
 remilia();resources(3,3);var rem=leader_on_field();rem.tapped=true
 var big=put(AI.BIG_REMILIA,"hand");put(AI.QUEEN,"hand");put(AI.CASTLE,"hand")
 plain(1,4,6,1);e.players[1].life=20
 var before=Codec.capture(e);var action=AI.pressure_action(e,0)
 var route=[action]+e.ai_memory[0].get("pressure_plan",[])
 expect(route.any(func(a):return a.get("card_id","")==AI.QUEEN) and route.any(func(a):return a.get("card_id","")==AI.CASTLE) and route.all(func(a):return a.get("card_id","")!=AI.BIG_REMILIA),"high mana chooses Queen plus Castle pressure over a blocked big Remilia")
 expect(Codec.decode(Codec.capture(e)).players==Codec.decode(before).players and Codec.capture(e).definitions==before.definitions,"pressure planning preserves the live board, colors, life, hand and definitions")
 if not action.is_empty():AI.pressure_execute(e,0,action);resolve_ai()
 for i in range(12):
  if e.winner!=-2:break
  e.ai_step(0);resolve_ai()
  if e.phase!="main":break
 expect(e.players[1].life<=11 and big.zone=="hand","planned Queen and Castle really inflict damage without spending big Remilia")
 # RED extends the search gate with actual lifesteal, not a fixed life number.
 remilia();resources(4,3);rem=leader_on_field();put(AI.CASTLE)
 put(AI.QUEEN,"hand");put(AI.RED,"hand");e.players[1].life=20
 expect(AI.lethal_threshold(e,0)>=20,"Queen aura damage and RED lifesteal raise the lethal search gate above twelve")
 action=AI.lethal_action(e,0)
 route=[action]+e.ai_memory[0].get("lethal_plan",[])
 expect(not action.is_empty() and route.any(func(a):return a.get("card_id","")==AI.QUEEN) and route.any(func(a):return a.get("card_id","")==AI.RED),"dynamic search finds Queen plus lifesteal RED lethal from twenty life")
 for i in range(12):
  if e.winner!=-2:break
  if i==0 and not action.is_empty():AI.execute(e,0,action)
  else:e.ai_step(0)
  resolve_ai()
 expect(e.winner==0,"twenty-life Queen and RED route wins using real colors and damage")
 remilia();resources(4,2);leader_on_field().tapped=true
 e.players[0].life_gained={str(e.turn):10};put(AI.RED,"hand");put(AI.RED,"hand");e.players[1].life=25
 expect(AI.lethal_threshold(e,0)>=25,"multiple REDs count additional life gained from each preceding RED")
 for i in range(2):e.ai_step(0);resolve_ai()
 expect(e.winner==0,"dynamic gate finds two legal REDs dealing thirteen then sixteen damage from twenty-five life")
 for retrieved_id in [AI.RED,AI.QUEEN]:
  remilia();resources(4,2);leader_on_field();put(AI.CASTLE)
  var retrieved=put(retrieved_id,"palette");put(AI.QUEEN if retrieved_id==AI.RED else AI.RED,"hand");var exchanged=put(AI.WINGS,"hand")
  e.players[1].life=20;e.phase="possession";e.pending={"kind":"possession","owner":0}
  before=Codec.capture(e);e.ai_step(0)
  expect(retrieved.zone=="hand" and exchanged.zone=="palette","possession searches palette "+retrieved_id+" for a lethal route above twelve life")
  expect(e.players[1].life==20 and e.stack.is_empty() and e.players[0].leader.zone=="field","palette lethal search commits only the exchange, not simulated damage")
  one();e.priority=0
  for i in range(12):
   if e.winner!=-2:break
   e.ai_step(0);resolve_ai()
  expect(e.winner==0,"retrieved palette "+retrieved_id+" completes real Queen and RED lethal")
 remilia();resources(4,2);leader_on_field();put(AI.CASTLE)
 put(AI.QUEEN,"hand");put(AI.RED,"hand");e.players[1].life=20
 expect(AI.lethal_action(e,0).is_empty(),"individually affordable Queen and RED cannot fake lethal with insufficient combined black colors")
 remilia();resources(4,3);leader_on_field();put(AI.CASTLE)
 put(AI.QUEEN,"hand");put(AI.RED,"hand");e.players[1].life=20
 known_spell("100");put("70","field",1).tapped=true
 for i in range(2):put("164","palette",1)
 expect(AI.lethal_action(e,0).is_empty(),"raised search threshold still rejects Queen and RED lethal stopped by a known payable counter")
 # A full battlefield cannot create a partial batch of four Queen bats.
 remilia();resources(4,3);leader_on_field();put(AI.CASTLE);put(AI.QUEEN,"hand");put(AI.RED,"hand")
 for i in range(2):plain(0,0,1,0).tapped=true
 e.players[1].life=20
 expect(AI.lethal_threshold(e,0)<20 and AI.search_actions(e,0).all(func(a):return a.get("card_id","")!=AI.QUEEN),"insufficient slots neither inflate Queen's threshold nor offer an empty bat batch")
 # Sustained direct pressure works above lethal range and repeats next round.
 remilia();resources(0,6);leader_on_field().tapped=true
 put(AI.AURORA,"hand");put(AI.AURORA,"hand");e.players[1].life=20
 e.ai_step(0);expect(played()==AI.AURORA and e.stack[0].target.mode=="失去生命","high-mana pressure uses Aurora from twenty life")
 resolve_ai();e.ai_step(0);resolve_ai()
 expect(e.players[1].life==14,"two affordable Auroras combine for nonlethal six-life pressure")
 expect(AI.pressure_next_round(e,0),"public-board projection advances to another pressure round")
 put(AI.AURORA,"hand")
 for i in range(3):
  e.ai_step(0);resolve_ai()
  if e.players[1].life<=11:break
 expect(e.players[1].life<=11,"following round continues pressure instead of waiting for a large unit")
 # Next-round evaluation expires temporary bodies and current-turn buffs.
 remilia();resources(2,2);leader_on_field();var queen=put(AI.QUEEN,"hand")
 AI.cast(e,0,queen,{"none":true});resolve_ai()
 expect(e.units(0).size()==5,"Queen creates all four temporary bats")
 var sim=AI.simulation(e,0);AI.pressure_next_round(sim,0)
 expect(sim.units(0).size()==1 and e.units(0).size()==5,"next-round outlook removes temporary bats without touching the live board")
 # With no stronger pressure combination, persistent expensive bodies remain useful.
 remilia();resources(5,2);leader_on_field().tapped=true;var fire=put("character-fdf-065","hand")
 expect(AI.card_priority(e,0,fire)>AI.card_priority(e,0,put(AI.BIG_REMILIA,"hand")),"seven-mana Fire Blood Spear has higher expansion priority than big Remilia")
 e.ai_step(0);expect(played()==fire.card_id,"persistent Fire Blood Spear remains available when it is the useful high-mana play")
 resolve_ai()
 var fire_route=[{"kind":"cast","uid":fire.uid,"card_id":fire.card_id}]
 var fire_outlook=AI.simulation(e,0);var base_outlook=AI.simulation(e,0)
 var fire_score=AI.pressure_evaluate(fire_outlook,0,fire_route,e.players[1].life,e.players[0].life)
 var base_score=AI.Evaluator.legacy_pressure(base_outlook,0,AI,fire_route,e.players[1].life,e.players[0].life)
 expect(fire_score.score==base_score.score+180,"successful persistent Fire Blood Spear adds 180 pressure points")
 remilia();resources(4,2);fire=put("character-fdf-065","hand")
 expect(AI.card_priority(e,0,fire)==60,"unreachable Fire Blood Spear retains its low early priority")
 # Public unused colors and death abilities raise Night's protection value.
 remilia();resources(3,3);leader_on_field();put(AI.NIGHT,"hand");put(AI.BIG_REMILIA,"hand")
 var risk=AI.night_priority(e,0);put("165","palette",1)
 expect(AI.night_priority(e,0)>risk,"opponent's untapped mana raises Night King priority")
 risk=AI.night_priority(e,0);put("character-fdf-065","field",1)
 expect(AI.night_priority(e,0)>risk,"public death-trigger unit further raises Night King priority")
 e.ai_step(0)
 expect(played()==AI.NIGHT,"mana and a death-trigger blocker promote Night King before expensive expansion")
 e.players[1].night_lock=e.turn
 expect(AI.night_priority(e,0)==0,"already silenced opponent does not justify another Night protection bonus")
 # Possession moves heavy cards into early mana; late low-impact Wings gives
 # way to playable direct damage while preserving a useful Queen combination.
 remilia();resources(1,1);var lily=put(AI.LILY);lily.color_counters=["红"]
 big=put(AI.BIG_REMILIA,"hand");var wings=put(AI.WINGS,"palette")
 e.phase="possession";e.pending={"kind":"possession","owner":0};e.ai_step(0)
 expect(big.zone=="palette" and wings.zone=="hand","early possession exchanges an uncastable large unit for curve Wings")
 remilia();resources(4,2);leader_on_field().tapped=true
 var red=put(AI.RED,"palette");wings=put(AI.WINGS,"hand")
 e.phase="possession";e.pending={"kind":"possession","owner":0};e.ai_step(0)
 expect(wings.zone=="palette" and red.zone=="hand","late possession exchanges low-impact Wings for playable RED pressure")

func queen_priority_regressions():
 var priorities=[]
 for board in ["Remilia","Castle","both"]:
  for blockers in range(3):
   remilia();resources(2,2)
   if board!="Castle":leader_on_field().tapped=true
   else:e.players[0].leader.timer=2
   if board!="Remilia":put(AI.CASTLE)
   var queen=put(AI.QUEEN,"hand");put(AI.NUE,"hand");put(AI.FAIRY,"hand")
   for i in range(blockers):plain(1,1,1,0)
   var before=Codec.capture(e);var priority=AI.card_priority(e,0,queen)
   expect(priority>AI.card_priority(e,0,e.players[0].hand[1]),"Queen outranks expansion with "+board+" and "+str(blockers)+" weak blockers")
   expect(Codec.capture(e)==before,"Queen priority calculation preserves live state")
   if blockers==0:priorities.append(priority)
   e.ai_step(0)
   expect(played()==AI.QUEEN,"four-mana AI prioritizes real Queen burst with "+board+" and "+str(blockers)+" blockers")
   resolve_ai()
   expect(e.units(0).filter(func(c):return c.get("token",false)).size()==4,"prioritized Queen creates the complete four-bat batch")
 expect(priorities[2]>priorities[0] and priorities[2]>priorities[1],"both Remilia and Castle give Queen a larger priority boost than either alone")
 remilia();resources(2,2);leader_on_field();var queen=put(AI.QUEEN,"hand")
 for i in range(3):plain(1,4,5,1)
 expect(AI.card_priority(e,0,queen)==180 and AI.spell_target(e,0,queen).is_empty(),"crowded strong opposing board lowers Queen's priority")
 remilia();resources(2,2);leader_on_field();put(AI.CASTLE);plain(0,0,1,0);plain(0,0,1,0)
 queen=put(AI.QUEEN,"hand")
 expect(AI.card_priority(e,0,queen)==400 and AI.spell_target(e,0,queen).is_empty(),"insufficient slots disable boosted Queen priority and prevent a partial batch")
 remilia();resources(4,0);leader_on_field();queen=put(AI.QUEEN,"hand")
 expect(AI.card_priority(e,0,queen)==400,"wrong colors cannot receive a payable Queen priority boost")
 remilia();resources(2,2);put(AI.CASTLE);var rem=e.players[0].leader
 rem.zone="grave";e.players[0].grave.append(rem);queen=put(AI.QUEEN,"hand")
 expect(AI.card_priority(e,0,queen)==400,"Castle alone cannot bypass missing Remilia support permission")
 remilia();resources(2,2);queen=put(AI.QUEEN,"hand")
 expect(AI.card_priority(e,0,queen)==180,"unbuffed bats receive reduced priority")
 remilia();resources(2,2);leader_on_field();put(AI.CASTLE);queen=put(AI.QUEEN,"hand")
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 expect(AI.card_priority(e,0,queen)>1200,"possession retains enhanced Queen value for the upcoming legal main phase")

func castle_and_block_regressions():
 for zone in ["hand","palette"]:
  remilia();resources(3,1);leader_on_field().tapped=true
  var castle=put(AI.CASTLE,"hand");var ordinary=AI.card_priority(e,0,castle)
  put(AI.QUEEN,zone)
  expect(AI.card_priority(e,0,castle)>ordinary,"Castle priority rises with Queen in "+zone)
  put(AI.NUE,"hand");e.ai_step(0)
  expect(played()==AI.CASTLE,"four-mana AI chooses Castle over expansion when Queen is in "+zone)
 remilia();resources(2,2);var castle=put(AI.CASTLE,"hand")
 var ordinary=AI.card_priority(e,0,castle)
 plain(0,2,3,2);plain(0,2,3,2)
 expect(AI.card_priority(e,0,castle)>ordinary,"Castle priority rises on a board with multiple useful attacks")
 remilia();resources(2,2);leader_on_field().tapped=true
 var queen=put(AI.QUEEN,"hand");var boosted=AI.card_priority(e,0,queen)
 for i in range(3):
  var attacker=plain(0,1,2,1);var blocker=plain(1,0,5,0)
  e.attack(0,attacker.uid);one();e.block([blocker.uid]);resolve_ai()
  e.players[0].field.erase(attacker);e.players[1].field.erase(blocker)
 expect(AI.frequent_blocks(e,0) and AI.card_priority(e,0,queen)<boosted,"repeated actual opposing blocks lower Queen's use priority")
 var copy=AI.simulation(e,0)
 expect(AI.frequent_blocks(copy,0),"combat forecasts preserve observed block frequency")
 var saved=Duel.new(e.cards);Codec.restore(saved,Codec.capture(e))
 expect(AI.frequent_blocks(saved,0),"save and network state preserve observed block frequency")
 for i in range(6):AI.observe_block(e,0,[])
 expect(not AI.frequent_blocks(e,0) and AI.card_priority(e,0,queen)==boosted,"recent unblocked attacks remove the old block-frequency penalty")
 # Only known, legally payable flash units may enter the predicted field.
 for id in ["character-rei-022","character-fdf-069"]:
  remilia();var rem=leader_on_field();var response=known_spell(id)
  var colors=["165","165","164"] if id=="character-rei-022" else ["167","167","166"]
  for color in colors:put(color,"palette",1)
  var before=JSON.stringify([e.players,e.stack,e.pending,e.revision,e.cards])
  expect(AI.projected_blockers(e,0)==1,"known affordable flash unit joins blocker projection: "+id)
  expect(not AI.attack_allowed(e,rem),"known flash blocker prevents a fatal Remilia attack: "+id)
  expect(JSON.stringify([e.players,e.stack,e.pending,e.revision,e.cards])==before and response.zone=="hand","flash combat projection preserves real board, resources and hand: "+id)
  e.players[1].palette[0].tapped=true
  expect(AI.projected_blockers(e,0)==0 and AI.attack_allowed(e,rem),"tapped required color removes flash-blocker risk: "+id)
  e.players[1].palette[0].tapped=false;e.players[1].night_lock=e.turn
  expect(AI.projected_blockers(e,0)==0 and AI.attack_allowed(e,rem),"Night response lock disables flash projection: "+id)
  e.players[1].night_lock=-1
  put(id,"field",1).tapped=true
  expect(AI.projected_blockers(e,0)==0,"same-title restriction disables flash entry: "+id)
 remilia();var rem=leader_on_field()
 for id in ["165","165","164"]:put(id,"palette",1)
 var hidden=put("character-rei-022","hand",1)
 expect(AI.projected_blockers(e,0)==0 and AI.attack_allowed(e,rem),"unrevealed Tiger is not read or invented as a blocker")
 hidden.card_id="character-fdf-069"
 expect(AI.projected_blockers(e,0)==0 and AI.attack_allowed(e,rem),"changing hidden identity leaves flash-blocker decisions unchanged")
 remilia();known_spell("66")
 for id in ["167","166"]:put(id,"palette",1)
 expect(AI.projected_blockers(e,0)==0,"ordinary nonfast Kyouko is not treated as the flash version")
 remilia();rem=leader_on_field();rem.modifiers=[{"血量":1}]
 known_spell("character-fdf-069")
 for color in ["167","167","166"]:put(color,"palette",1)
 expect(not AI.attack_allowed(e,rem),"Kyouko's death damage is included when Remilia survives the initial block")
 var combat_copy=AI.simulation(e,0);combat_copy.attack(0,rem.uid);AI.settle_sim(combat_copy,0)
 expect(combat_copy.players[0].leader.zone!="field" and rem.zone=="field","real cloned combat resolves Kyouko's death damage without damaging the live Remilia")
 remilia();rem=leader_on_field();rem.modifiers=[{"血量":1}];put("character-fdf-069","field",1)
 expect(not AI.attack_allowed(e,rem),"an existing Kyouko death trigger is checked even with no opposing hand")
 e.players[1].night_lock=e.turn
 expect(AI.attack_allowed(e,rem),"Night suppresses Kyouko's death trigger in the real combat forecast")
 # Boundary can restore two tapped blockers, using its real shared payment.
 remilia();rem=leader_on_field();var blocker=plain(1,4,5,1);blocker.tapped=true
 known_spell("114")
 for id in ["167","167","168"]:put(id,"palette",1)
 expect(AI.projected_blockers(e,0)==1 and not AI.attack_allowed(e,rem),"known Boundary restores a tapped blocker before simulated combat")
 var second=plain(1,4,5,1);second.tapped=true
 expect(AI.projected_blockers(e,0)==2,"Boundary projection includes its legal two-unit target")
 known_spell("character-fdf-069");put("166","palette",1)
 expect(AI.projected_blockers(e,0)==2,"Boundary and flash Kyouko cannot spend the same two blue colors twice")
 for i in range(2):put("167","palette",1)
 expect(AI.projected_blockers(e,0)==3,"jointly payable Boundary and Kyouko create three real projected blockers")
 e.players[1].night_lock=e.turn
 expect(AI.projected_blockers(e,0)==0,"Night lock disables Boundary and flash entries together")
 # Lethal search must account for the same surprise blockers as protection.
 for id in AI.BLOCK_RESPONSES:
  remilia();var bat=e.Roster.create_token(e,0,"bat",1,["红","黑"]);bat.entered_turns=0
  put(AI.CASTLE);put(AI.CASTLE);e.players[1].life=3;known_spell(id)
  var colors=["167","167","168"]
  if id=="114":plain(1,3,5,1).tapped=true
  elif id=="character-rei-022":colors=["165","165","164"]
  else:colors=["167","167","166"]
  for color in colors:put(color,"palette",1)
  expect(AI.lethal_action(e,0).is_empty(),"known affordable response prevents fake unblocked lethal: "+id)
  for color in e.players[1].palette:color.tapped=true
  expect(not AI.lethal_action(e,0).is_empty(),"unpayable response permits the actual unblocked lethal: "+id)

func lethal_regressions():
 # Sep 27 Reimu replay: the static removal bonus previously swapped away
 # Aurora and lost the Castle + three-life-loss win on global turn nine.
 for blocked in [-1,0,1]:
  var board=replay_lethal_board()
  var aurora=e.players[0].hand.filter(func(c):return c.card_id==AI.AURORA)[0]
  var mist=e.players[0].palette.back()
  e.ai_step(0)
  expect(aurora.zone=="hand" and mist.zone=="palette","turn-nine possession preserves Aurora lethal, block branch "+str(blocked))
  expect(e.phase=="possession" and e.stack.is_empty() and e.players[1].life==9,"possession planning does not execute spells or damage on the live board")
  one();e.priority=0
  var block_at=-1 if blocked<0 else board.bats[blocked].uid
  for i in range(12):
   if e.winner!=-2:break
   e.ai_step(0);resolve_ai(board.enemy.uid,block_at)
  expect(e.winner==0 and e.turn==9 and e.players[0].leader.zone=="field","turn-nine route wins safely against block branch "+str(blocked))
 # A real exchange can also create a lethal route by retrieving Aurora.
 remilia();resources(1,2);var retrieved=put(AI.AURORA,"palette");put(AI.MIST,"hand");e.players[1].life=3
 e.phase="possession";e.pending={"kind":"possession","owner":0};e.ai_step(0)
 expect(retrieved.zone=="hand","possession retrieves palette Aurora for immediate three-life lethal")
 one();e.priority=0;e.ai_step(0);resolve_ai()
 expect(e.winner==0,"retrieved Aurora pays real remaining colors and wins")
 # Practical sacrifice value should survive possession even above lethal range.
 remilia();resources(0,2);retrieved=put(AI.AURORA,"palette");put(AI.MIST,"hand");plain(1,7,7,2)
 e.phase="possession";e.pending={"kind":"possession","owner":0};e.ai_step(0)
 expect(retrieved.zone=="hand","possession retrieves Aurora to sacrifice an isolated large body")
 one();e.priority=0;e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.mode=="牺牲单位","retrieved Aurora is used for its planned sacrifice")
 # Direct life loss is useful outside an immediate kill, and repeats legally.
 remilia();resources(0,6);put(AI.AURORA,"hand");put(AI.AURORA,"hand");e.players[1].life=6
 e.ai_step(0);resolve_ai();e.ai_step(0);resolve_ai()
 expect(e.winner==0,"lethal search combines two Auroras for six life loss")
 remilia();resources(0,3);put(AI.AURORA,"hand");e.players[1].life=10
 e.ai_step(0)
 expect(played()==AI.AURORA and e.stack[0].target.mode=="失去生命","spare mana uses Aurora to reduce life while closing the game")
 resolve_ai();expect(e.players[1].life==7,"Aurora pressure really loses three life")
 remilia();resources(0,3);leader_on_field();put(AI.CASTLE);put(AI.CASTLE)
 var bat=e.Roster.create_token(e,0,"bat",1,["红","黑"]);bat.entered_turns=0
 var enemy=plain(1,7,7,2);put(AI.AURORA,"hand");e.players[1].life=8
 var sacrifice=AI.lethal_action(e,0)
 expect(sacrifice.get("target",{}).get("mode","")=="牺牲单位","lethal calculation uses Aurora sacrifice to clear the sole large blocker")
 if not sacrifice.is_empty():AI.execute(e,0,sacrifice);resolve_ai()
 for i in range(6):
  if e.winner!=-2:break
  e.ai_step(0);resolve_ai()
 expect(e.winner==0 and enemy.zone=="grave","sacrifice route enables enough safe attack damage to win")
 remilia();resources(2,3);leader_on_field();put(AI.NIGHT,"hand");var direct=put(AI.AURORA,"hand");e.players[1].life=3
 var immediate=AI.lethal_action(e,0)
 expect(immediate.get("uid",-1)==direct.uid and e.ai_memory[0].get("lethal_plan",[]).is_empty(),"immediate Aurora lethal takes priority over an available Night King route")
 remilia();resources(2,3);e.first=1;e.players[0].potato=true;var role=put(AI.LILY);role.color_counters=["红"]
 put(AI.AURORA,"hand");e.players[1].life=3;e.ai_step(0)
 expect(played()==AI.AURORA and e.players[0].potato and e.players[0].leader.zone=="leader","immediate lethal precedes potato leader expansion")
 remilia();resources(0,3);put(AI.AURORA,"hand");e.players[1].life=3;e.players[1].wards=[{"amount":10,"turn":e.turn}]
 e.ai_step(0);resolve_ai();expect(e.winner==0,"Aurora loses life and bypasses player damage prevention")
 # Turn eleven only requires Gungnir, Castle and an existing bat.
 var board=replay_lethal_board();e.phase="main";e.pending={};e.turn=11;e.players[1].life=3
 e.players[0].hand=[];e.players[0].palette=[];resources(3,3)
 put(AI.GUNGNIR,"hand");put(AI.CASTLE,"hand");var wings=put(AI.WINGS,"hand")
 var first=AI.lethal_action(e,0)
 var route=[first]+e.ai_memory[0].get("lethal_plan",[])
 expect(not route.is_empty() and route.all(func(a):return a.get("card_id","")!=AI.WINGS),"turn-eleven lethal route removes redundant Wings")
 expect(route.any(func(a):return a.get("card_id","")==AI.GUNGNIR) or route.filter(func(a):return a.kind=="attack").size()>=2,"opponent blocks a lethal bat instead of reserving for another attacker")
 for i in range(8):
  if e.winner!=-2:break
  if i==0:AI.execute(e,0,first)
  else:e.ai_step(0)
  resolve_ai()
 expect(e.winner==0 and wings.zone=="hand","trimmed turn-eleven route wins without spending Wings")

func hina_regressions():
 var deck=JSON.parse_string(FileAccess.get_file_as_string("res://deck/未命名卡组_7c906ca3ca80.mdeck")).deck
 expect(Store.validate(deck,true,deck.rule_set).is_empty(),"updated image-based main deck is legal under its existing rule set")
 expect(deck.main.count(AI.HINA)==3 and deck.main.count("23")==2 and deck.main.count(AI.QUEEN)==4 and deck.main.count(AI.AURORA)==4 and not deck.main.any(func(id):return Store.CARDS[id].character=="藤原妹红"),"image deck retains three Hinas and two Parsee, replacing both Mokous with Queen and Aurora")
 remilia();resources(1,1)
 for id in [AI.PARSEE,AI.FAIRY,AI.HINA,AI.WINGS]:put(id,"hand")
 e.ai_step(0)
 expect(played()==AI.WINGS,"two-resource turn retains Wings as the first early play")
 remilia();resources(1,1)
 for id in [AI.PARSEE,AI.FAIRY,AI.HINA]:put(id,"hand")
 e.ai_step(0)
 expect(played()==AI.HINA,"two-resource turn prefers Hina over Vampire Fairy")
 remilia();resources(1,1)
 for id in [AI.PARSEE,AI.LILY,AI.FAIRY]:put(id,"hand")
 e.ai_step(0)
 expect(played()==AI.FAIRY,"without Hina the early Fairy priority remains above Lily and Parsee")
 remilia();resources(0,2)
 for id in [AI.PARSEE,AI.LILY]:put(id,"hand")
 e.ai_step(0)
 expect(played()==AI.LILY,"black Parsee has the lowest early unit priority")
 remilia();resources(0,2);put(AI.PARSEE,"hand");e.ai_step(0)
 expect(played()==AI.PARSEE,"lowest priority does not prevent a legal Parsee-only opening")
 remilia();resources(2,2);leader_on_field()
 put(AI.HINA,"hand");put(AI.NUE,"hand");put(AI.CASTLE,"hand");put(AI.QUEEN,"hand")
 e.ai_step(0)
 expect(played()==AI.HINA,"four-resource turn establishes Hina before ordinary expansion and nonlethal bats")
 resolve_ai()
 expect(e.units(0).any(func(c):return c.card_id==AI.HINA) and e.players[0].leader.zone=="field","Hina deploys legally alongside small Remilia")
 remilia();resources(2,1);put(AI.LILY).color_counters=["红"]
 put(AI.HINA,"hand");e.ai_step(0)
 expect(played()==AI.REMILIA,"three-resource leader curve stays ahead of Hina")
 remilia();resources(1,3);leader_on_field();put(AI.HINA,"hand");put(AI.AURORA,"hand");e.players[1].life=3
 e.ai_step(0)
 expect(played()==AI.AURORA,"certified lethal retains priority over four-resource Hina")
 remilia();resources(2,2);leader_on_field();put(AI.HINA,"hand");put(AI.GUNGNIR,"hand")
 var enemy=put("50","field",1);enemy.leader=true;enemy.leader_counters=1;e.players[1].leader=enemy
 e.ai_step(0)
 expect(played()==AI.GUNGNIR,"core removal retains priority over four-resource Hina")
 remilia();leader_on_field();var hina=put(AI.HINA);put(AI.HINA);resources(2,2,1)
 var spell=put(AI.MIST,"hand",1);e.active=1;e.priority=1
 var target=e.ref_target(e.players[0].leader)
 expect(e.commit_cast(1,spell.uid,target,e.payment(1,e.cast_cost(1,spell,target)).plan).is_empty(),"opponent legally declares removal at small Remilia")
 e.ai_step(0)
 expect(e.stack.back().get("effect","")=="hina_redirect" and e.players[0].life==18,"Hina AI pays two life to redirect hostile removal")
 e.pass_priority(1);e.ai_step(0)
 expect(e.players[0].life==18 and e.stack.size()==1 and e.stack[0].target.uid==hina.uid,"pending redirect is not paid again by either Hina")
 resolve_ai()
 expect(hina.zone=="grave" and e.players[0].leader.zone=="field","real removal kills Hina while small Remilia survives")
 remilia();leader_on_field();put(AI.HINA);resources(2,2,1);e.players[0].life=2
 spell=put(AI.MIST,"hand",1);e.active=1;e.priority=1;target=e.ref_target(e.players[0].leader)
 e.commit_cast(1,spell.uid,target,e.payment(1,e.cast_cost(1,spell,target)).plan)
 expect(not AI.protect_remilia(e,0) and e.players[0].life==2,"protection never loses the game by paying the last two life")
 remilia();leader_on_field();put(AI.HINA);resources(2,2,1)
 var ally=put(AI.LILY);spell=put(AI.MIST,"hand",1);e.active=1;e.priority=1;target=e.ref_target(ally)
 e.commit_cast(1,spell.uid,target,e.payment(1,e.cast_cost(1,spell,target)).plan)
 expect(not AI.protect_remilia(e,0),"new protection rule does not redirect threats aimed at ordinary allies")
 remilia();leader_on_field();put(AI.HINA);resources(2,2)
 spell=put(AI.MIST,"hand");target=e.ref_target(e.players[0].leader)
 e.commit_cast(0,spell.uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan);e.pass_priority(1)
 expect(not AI.protect_remilia(e,0),"Hina does not redirect the friendly player's own spell")
 remilia();leader_on_field();hina=put(AI.HINA)
 var kanako=put("82","field",1);kanako.leader_counters=1
 var pillar=e.Roster.create_token(e,1,"pillar",2,["绿"]);e.priority=1
 target={"selection_id":"kanako_blast","picks":[[e.Pack.ref(e,pillar)],[e.ref_target(e.players[0].leader)]]}
 expect(e.commit_extension(1,kanako.uid,target,[],"kanako_blast").is_empty(),"opposing unit ability legally targets small Remilia")
 e.ai_step(0)
 expect(e.stack.back().get("effect","")=="hina_redirect","Hina AI also responds to an opposing unit's activated ability")
 resolve_ai()
 expect(e.players[0].leader.zone=="field" and e.players[0].leader.damage==0 and (hina.zone=="grave" or hina.damage>0),"real unit ability resolves onto Hina rather than small Remilia")
