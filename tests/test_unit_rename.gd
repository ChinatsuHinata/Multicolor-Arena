extends "res://tests/support/rules_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const UnknownArt=preload("res://scripts/unknown_card_art.gd")

func run():
 nightmare()
 transformation()
 rename_lifecycle()
 print("UNIT_RENAME: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func nightmare():
 fresh();mana()
 e.players[0].leader=e.make_card("character-fdf-117",0,"leader",true)
 var aya=put("18");var incoming=put("18","hand");var spell=put("122","hand")
 expect(e.cast_error(0,incoming.uid)=="同称号单位已经在场","unchanged same-title unit cannot be cast")
 expect(e.field_error(incoming,0)=="同称号单位已经在场","unchanged same-title unit cannot be put into play")
 expect(e.cast_error(0,spell.uid).is_empty(),"Aya allows her role spell before renaming")
 var target=e.ref_target(aya);target.mode="名称改为不明物体并抓牌"
 cast("spell-fdf-072",target)
 expect(e.cards[aya.card_id].name=="不明物体" and e.Cat.is_unknown(e,aya),"Nightmare really renames the selected unit")
 expect(UnknownArt.active(e,aya),"Nightmare obscures a renamed non-UFO unit")
 expect(e.cards[aya.card_id].abilities==e.cards["18"].abilities,"name-only change preserves the unit's printed ability")
 expect(e.cast_error(0,spell.uid)=="需要操控射命丸文","renamed unknown cannot satisfy the original role spell")
 expect(not e.available_actions(0,spell.uid).any(func(a):return a.type=="cast" and a.enabled),"original role spell is disabled in available actions")
 expect(e.cast_error(0,incoming.uid).is_empty(),"original unit can be cast after Nightmare renames its predecessor")
 expect(e.field_error(incoming,0).is_empty(),"original unit can enter through effects after Nightmare")
 var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0))
 expect(UnknownArt.active(remote,remote.find_card(aya.uid)),"network snapshot preserves Nightmare's art effect")
 expect(remote.cast_error(0,incoming.uid).is_empty(),"network client receives permission to cast the original unit")
 expect(remote.cast_error(0,spell.uid)=="需要操控射命丸文","network client also rejects the lost role constraint")
 expect(e.commit_cast(0,incoming.uid,{},e.payment(0,e.cast_cost(0,incoming)).plan).is_empty(),"original unit cast commits after renaming")
 settle();e.priority=0
 expect(incoming.zone=="field" and aya.zone=="field","original unit resolves beside the renamed unit")
 expect(e.cast_error(0,spell.uid).is_empty(),"another real Aya restores role spell permission")

func transformation():
 fresh();mana()
 var nue=put("character-fdf-117");var aya=put("18");var spell=put("122","hand")
 expect(e.cast_error(0,spell.uid).is_empty(),"original role spell is usable before transforming")
 e.Cat.Units.resolve(e,{"owner":0,"source":nue,"effect":"character-fdf-117","target":{"picks":[[e.Pack.ref(e,aya)]]}})
 e.judge()
 expect(e.cards[aya.card_id].name=="不明物体" and e.cards[aya.card_id].kind=="单位","Nue really transforms the target into an unknown unit")
 expect(not UnknownArt.active(e,aya),"Nue's UFO transformation does not apply Nightmare noise")
 expect(e.cards[aya.card_id].abilities==e.cards["token-fdf-131"].abilities and e.stat(aya,"power")==3,"transformation removes original abilities and sets printed stats")
 expect(e.cast_error(0,spell.uid)=="需要操控射命丸文","transformed unknown cannot satisfy its former role spell")
 var incoming=put("18","hand")
 expect(e.field_error(incoming,0).is_empty(),"original unit can enter beside the transformed unknown")
 e.detach(incoming)
 expect(e.enter_field(incoming,0),"effect-driven entry really places the original unit beside the unknown")
 settle();e.priority=0
 expect(e.cast_error(0,spell.uid).is_empty(),"real role unit restores spell permission beside the transformed unknown")

func rename_lifecycle():
 fresh();mana()
 var aya=put("18");var incoming=put("18","hand")
 e.Cat.rename(e,aya,"另一个名称")
 expect(e.field_error(incoming,0).is_empty(),"generic rename also releases the original title restriction")
 e.Cat.rename(e,aya,"不明物体")
 expect(e.cast_error(0,incoming.uid).is_empty(),"repeated renaming keeps the original unit usable")
 e.move_to(aya,"hand")
 expect(aya.card_id=="18" and e.cards[aya.card_id].character=="射命丸文","leaving the battlefield restores the printed name and role")
 e.detach(aya);e.enter_field(aya,0);settle();e.priority=0
 expect(e.cast_error(0,incoming.uid)=="同称号单位已经在场","restored printed title blocks a duplicate again")
