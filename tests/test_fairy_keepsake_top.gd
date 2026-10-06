extends "res://tests/support/rules_base.gd"

func activate_keepsake(leader):
 var item=put("item-lof-009")
 var fairy=put("57")
 var spec=e.activation_options(item,"item-lof-009")[0]
 var target=spec.selection[1].pool.filter(func(r):return r.uid==leader.uid and r.mode=="置于牌库顶")[0]
 var choice={"selection_id":"item-lof-009","picks":[[e.Cat.ref(e,fairy)],[target]]}
 expect(e.commit_extension(0,item.uid,choice,[],"item-lof-009").is_empty(),"妖精信物可选择自机置于牌库顶")
 expect(fairy.zone=="grave" and item.tapped,"妖精信物支付横置与牺牲费用")
 one()

func run():
 fresh()
 var leader=e.players[0].leader
 expect(e.enter_field(leader,0),"自机进入战场")
 var old_top=e.players[0].deck[0].uid
 activate_keepsake(leader)
 expect(e.pending.get("kind","")=="leader_return" and leader.get("return_destination","")=="deck","自机离场时可以决定是否返回自机区")
 e.choose_return(false)
 expect(leader.zone=="deck" and e.players[0].deck[0].uid==leader.uid,"不返回自机区时自机成为牌库顶")
 expect(e.players[0].deck.size()>1 and e.players[0].deck[1].uid==old_top,"原牌库顶顺移到第二张")

 fresh()
 leader=e.players[0].leader
 expect(e.enter_field(leader,0),"再次让自机进入战场")
 old_top=e.players[0].deck[0].uid
 activate_keepsake(leader)
 e.choose_return(true)
 expect(leader.zone=="leader" and e.players[0].deck[0].uid==old_top,"选择返回自机区时牌库顶保持原样")

 print("FAIRY KEEPSAKE TOP ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
