extends "res://tests/support/ui_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func pick_allocation(recipients: Array):
 var branches=view.picker.available().filter(func(atom):return atom.kind=="spec" and view.picker.specs[atom.index].get("selection_id","")=="spell-fdn-003")
 expect(branches.size()==1,"界面提供使用时分配5点伤害的选项")
 if branches.is_empty():return
 view.inline_pick(branches[0])
 for unit in recipients:
  view.object_clicked(unit.uid)
  if not view.picker.ready():
   var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
   if not finish.is_empty():view.inline_pick(finish[0])
 expect(view.picker.ready(),"界面可以逐点分配伤害，重复选择同一单位")

func phoenix_selection():
 clean()
 put("21","field");put("33","field")
 for id in ["165","165","168","164"]:put(id,"palette")
 var a=put("53","field");var b=put("50","field",1)
 a.plus_counters=20;b.plus_counters=20
 var spell=put("spell-fdn-003","hand");view.render();await settle()
 view.request_cast(spell.uid);pick_allocation([a,a,b,b,b])
 expect(e.stack.is_empty() and spell.zone=="hand" and view.local.target.picks.size()==5,"点击目标时尚未使用符卡，使用草稿已分配完整伤害")
 var cast_button=find_button(view.ui,"发动")
 expect(cast_button!=null and not cast_button.disabled,"选定目标后可支付并使用凤翼天翔")
 if cast_button==null:return
 cast_button.pressed.emit()
 expect(spell.zone=="stack" and e.stack[0].target.picks.size()==5 and e.pending.is_empty(),"使用凤翼天翔后直接进入响应窗口")
 e.pass_priority(1)
 var hypnosis=put("spell-fdf-052","hand");view.render();await settle()
 view.request_cast(hypnosis.uid);view.choose_target({"stack_id":e.stack[0].id})
 cast_button=find_button(view.ui,"发动")
 expect(cast_button!=null and not cast_button.disabled,"界面可以选择凤翼天翔作为赤眼催眠目标并支付使用")
 if cast_button==null:return
 cast_button.pressed.emit();resolve();e.presentation_events.clear();view.render();await settle()
 pick_allocation([b,b,b,b,b])
 var confirm=find_button(view.ui,"确定")
 expect(confirm!=null and not confirm.disabled,"赤眼催眠可确认重新选择的单个伤害目标")
 if confirm==null:return
 confirm.pressed.emit();resolve()
 expect(a.damage==0 and b.damage==5 and e.players[0].life==10 and e.pending.is_empty(),"界面的重新选择实际改变凤翼天翔结算结果")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/reisen-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var unit=put("53","field");var enemy=put("50","field",1)
 var hand=put("53","hand");var melody=put("spell-fdn-032","field")
 var caption="名称也视为：铃仙·优昙华院·因幡（铃仙乐章）"
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  view.stage_hover_uid=unit.uid;view.refresh_stage_tooltip()
  expect(view.stage.tooltip_text.contains(caption),"悬浮标签显示乐章赋予的铃仙名称："+str(top_down))
  view.object_clicked(unit.uid)
  expect(view.inspection.visible and view.inspect_uid==unit.uid and view.inspection_text.get_parsed_text().contains(caption),"点击单位，详情标注铃仙视同名称："+str(top_down))
  expect(view.inspection_text.get_parsed_text().contains("无能力。"),"详情仍包含原单位能力")
  view.stage_hover_uid=enemy.uid;view.refresh_stage_tooltip()
  expect(not view.stage.tooltip_text.contains(caption),"对手单位不显示自己的铃仙乐章名称")
  view.right_cancel()
 expect(not view.hand_card_tooltip(hand).contains(caption),"手牌中的单位不获得铃仙名称")
 var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0));view.engine=remote
 expect(view.card_context_caption(remote.find_card(unit.uid)).contains(caption),"联机详情同样显示铃仙视同名称")
 view.engine=e;view.inspect_card(unit.card_id,unit.uid)
 e.move_to(melody,"grave");e.presentation_events.clear();view.render();await settle()
 expect(not view.inspection_text.get_parsed_text().contains(caption),"乐章离场后，已打开的详情自动清除铃仙名称")
 view.stage_hover_uid=unit.uid;view.refresh_stage_tooltip()
 expect(not view.stage.tooltip_text.contains(caption),"乐章离场后，悬浮标签清除铃仙名称")
 melody=put("spell-fdn-032","field");view.render();view.inspect_card(unit.card_id,unit.uid)
 e.move_to(unit,"hand");e.presentation_events.clear();view.render()
 expect(not view.inspection_text.get_parsed_text().contains(caption),"单位离开战场后，详情清除铃仙名称")
 await phoenix_selection()
 print("REISEN_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
