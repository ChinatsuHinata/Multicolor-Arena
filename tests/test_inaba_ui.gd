extends "res://tests/support/ui_base.gd"

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
 expect(carrot.zone=="stack" and rabbit.tapped and e.players[0].get("mana",[]).is_empty(),"确认发动时兔子直接支付整组黄绿，不留预存费用")
 clean(true)
 rabbit=put("character-fdf-098","field");rabbit.entered_turns=0
 var actions=e.available_actions(0,rabbit.uid)
 expect(not actions.any(func(action):return action.type=="extension" and action.key=="character-fdf-098"),"未选择待付牌时没有兔子的提前启动选项")
 view.object_clicked(rabbit.uid);await process_frame
 expect(view.local.is_empty() and not rabbit.tapped and e.players[0].get("mana",[]).is_empty(),"直接点击兔子不会提前横置产费")
 view.begin_action({"type":"extension","uid":rabbit.uid,"key":"character-fdf-098","enabled":true});await process_frame
 expect(view.local.is_empty() and not rabbit.tapped and e.players[0].get("mana",[]).is_empty(),"旧的启动入口也不能建立提前付款流程")
 for color in ["黄","绿"]:
  view.local={"uid":rabbit.uid,"action":"choice_payment","choice_cost":{color:1},"mode":"payment","target":{},"plan":[]}
  view.refresh_payment_plan()
  expect(not view.payment_sources().any(func(source):return source.uid==rabbit.uid) and not view.payment_ready(),"兔子不能单独支付1"+color)
 view.local={}
 carrot=put("item-fdn-044","hand");view.request_cast(carrot.uid);await process_frame
 expect(view.local.plan.size()==1 and view.local.plan[0].uid==rabbit.uid and view.local.plan[0].color=="黄/绿","先选择黄绿牌后仍能选兔子一次支付两色")
 view.start_payment();view.commit_local();await process_frame
 expect(carrot.zone=="stack" and rabbit.tapped and e.players[0].get("mana",[]).is_empty(),"付款时才横置兔子，且不产生可留待后续的费用")
 print("INABA UI ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
