extends "res://tests/test_v092.gd"

func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_legacy_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean(true)
 var rabbit=put("character-fdf-098","field")
 rabbit.entered_turns=0
 var carrot=put("item-fdn-044","hand")
 view.request_cast(carrot.uid);await process_frame
 expect(view.local.get("mode","")=="target" and view.local.plan.size()==1 and view.local.plan[0].uid==rabbit.uid and view.local.plan[0].color=="黄/绿","兔子推荐支付一次提供整组黄绿")
 expect(view.payment_sources().any(func(source):return source.uid==rabbit.uid),"兔子可作为支付候选显示")
 expect(view.table.descriptors.get("card_"+str(rabbit.uid),{}).get("gold",false),"推荐支付时兔子显示金边")
 view.object_clicked(rabbit.uid);await process_frame
 expect(view.local.plan.is_empty() and view.payment_sources().any(func(source):return source.uid==rabbit.uid),"点击金边兔子取消推荐，仍可重新选择")
 expect(not view.table.descriptors.get("card_"+str(rabbit.uid),{}).get("gold",false) and view.table.descriptors.get("card_"+str(rabbit.uid),{}).get("blue",false),"取消后兔子显示可选蓝边")
 view.object_clicked(rabbit.uid);await process_frame
 expect(view.local.plan.size()==1 and view.local.plan[0].color=="黄/绿","再次点击兔子只选一笔成对支付")
 view.start_payment();view.commit_local();await process_frame
 expect(carrot.zone=="stack" and rabbit.tapped,"确认发动后横置兔子并将道具送入堆叠")
 clean(true)
 rabbit=put("character-fdf-098","field");rabbit.entered_turns=0
 var actions=e.available_actions(0,rabbit.uid)
 expect(actions.any(func(action):return action.type=="extension" and action.key=="character-fdf-098"),"兔子可以提前启动而无需先选择手牌")
 view.begin_action(actions.filter(func(action):return action.type=="extension" and action.key=="character-fdf-098")[0])
 view.start_payment();view.commit_local();await process_frame
 expect(rabbit.tapped and e.stack.is_empty() and e.players[0].mana.size()==1 and e.players[0].mana[0].get("pair",[])==["黄","绿"],"提前横置后只产生一笔不可拆分黄绿资源")
 carrot=put("item-fdn-044","hand");view.request_cast(carrot.uid);await process_frame
 expect(view.local.plan.size()==1 and view.local.plan[0].uid==e.players[0].mana[0].uid,"提前产生的费用可为后续使用自动付款")
 view.start_payment();view.commit_local();await process_frame
 expect(carrot.zone=="stack" and e.players[0].mana.is_empty(),"整组黄绿支付后一次性消耗")
 print("INABA UI ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
