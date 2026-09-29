extends RefCounted
## Human text remains text; selected actions are separate, validated teacher labels.
var player
var panel: Panel
var shade: ColorRect
var seat_choice: OptionButton
var comment: TextEdit
var recommendation: TextEdit
var preferred: OptionButton
var alternative: OptionButton
var confidence: OptionButton
var hindsight: CheckButton
var info: Label
var status: Label
var ctx={}
var frame_index=0
var editing_seat=0
var loading=false
var dirty=false

func open(owner):
 player=owner;player.playing=false;player.update_controls();frame_index=player.index;editing_seat=player.seat
 var packet=player.archive.frame(frame_index);var active=int(packet.projection.state.active)
 var names=packet.room.get("names",[])
 # New computer-turn notes should evaluate the actor, not the viewer's seat.
 # Preserve an existing note's seat when reopening it.
 if player.training.find(frame_index,editing_seat).is_empty() and active>=0 and active<names.size() and packet.projection.state.phase=="main" and ("人机" in names[active] or "电脑" in names[active]):editing_seat=active
 var app=player.app
 shade=ColorRect.new();shade.z_index=20;shade.color=Color(0,0,0,0.75);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);player.controls.add_child(shade)
 panel=app.box(shade,Rect2(150,70,1300,760))
 app.label(panel,"回放训练标注 · 第 %d 步 / 第 %d 回合"%[frame_index+1,player.archive.frames[frame_index].turn],Rect2(28,16,1210,40),26,app.GOLD)
 app.label(panel,"评价哪一方",Rect2(28,65,150,35),18)
 seat_choice=OptionButton.new();seat_choice.position=Vector2(180,65);seat_choice.size=Vector2(360,35)
 for name in player.archive.frame(frame_index).room.names:seat_choice.add_item(name)
 seat_choice.selected=editing_seat;panel.add_child(seat_choice)
 seat_choice.item_selected.connect(func(value):
  if not flush():seat_choice.selected=editing_seat;return
  editing_seat=value;load_row())
 info=app.label(panel,"",Rect2(28,110,1230,52),16,app.MUTED);info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 app.label(panel,"关键点评：问题、理由和预期后果",Rect2(28,165,1210,28),19,app.GOLD)
 comment=TextEdit.new();comment.position=Vector2(28,200);comment.size=Vector2(1238,125);comment.placeholder_text="例如：这一步先铺场会失去黑色来源，应优先保色，并留下神枪费用。";panel.add_child(comment)
 app.label(panel,"推荐路线：按顺序写出出牌、目标、模式与留费",Rect2(28,337,1210,28),19,app.GOLD)
 recommendation=TextEdit.new();recommendation.position=Vector2(28,373);recommendation.size=Vector2(1238,105);recommendation.placeholder_text="例如：先妖精 → 再蕾米 → 再莉莉黑选红色；保留一红一黑。";panel.add_child(recommendation)
 app.label(panel,"下一步推荐操作",Rect2(28,492,200,28),18)
 preferred=OptionButton.new();preferred.position=Vector2(230,488);preferred.size=Vector2(1036,36);panel.add_child(preferred)
 app.label(panel,"较差的对照操作",Rect2(28,538,200,28),18)
 alternative=OptionButton.new();alternative.position=Vector2(230,534);alternative.size=Vector2(1036,36);panel.add_child(alternative)
 app.label(panel,"判断把握",Rect2(28,583,130,30),18)
 confidence=OptionButton.new();confidence.position=Vector2(160,580);confidence.size=Vector2(220,36)
 for title in ["明确 / 高把握","倾向 / 中把握","待讨论 / 低把握"]:confidence.add_item(title)
 panel.add_child(confidence)
 hindsight=CheckButton.new();hindsight.text="判断参考了对手隐藏手牌（事后分析）";hindsight.position=Vector2(420,578);hindsight.size=Vector2(800,40);panel.add_child(hindsight)
 status=app.label(panel,"",Rect2(28,625,1238,60),16,app.MUTED);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 app.button(panel,"保存标注",Rect2(28,697,220,40),func():flush(true),true)
 app.button(panel,"导出训练文件",Rect2(266,697,250,40),export_file)
 app.button(panel,"删除本步标注",Rect2(534,697,250,40),delete_row)
 app.button(panel,"保存并关闭",Rect2(1030,697,236,40),close)
 comment.text_changed.connect(mark_dirty);recommendation.text_changed.connect(mark_dirty)
 preferred.item_selected.connect(func(_i):mark_dirty());alternative.item_selected.connect(func(_i):mark_dirty())
 confidence.item_selected.connect(func(_i):mark_dirty());hindsight.toggled.connect(func(_v):mark_dirty())
 load_row()

func mark_dirty():
 if loading:return
 dirty=true;status.text="尚未保存；关闭或切换评价方时会自动保存。"

func load_row():
 loading=true;ctx=player.training.context(frame_index,editing_seat)
 var row=player.training.find(frame_index,editing_seat)
 comment.text=row.get("comment","");recommendation.text=row.get("recommended_text","")
 info.text=ctx.info
 preferred.clear();alternative.clear();preferred.add_item("仅记录文字推荐");alternative.add_item("不比较其他操作")
 preferred.set_item_metadata(0,{});alternative.set_item_metadata(0,{})
 var computer=ctx.get("computer_choice",{})
 if not computer.is_empty():
  var name=player.archive.frame(frame_index).room.get("names",["玩家","玩家"])[editing_seat]
  var title="电脑实际操作（录像）" if "人机" in name or "电脑" in name else "实际操作（录像 · "+name+"）"
  alternative.add_item(title+"："+computer.label)
  alternative.set_item_metadata(alternative.item_count-1,computer)
 for choice in ctx.choices:
  preferred.add_item(choice.label);alternative.add_item(choice.label)
  preferred.set_item_metadata(preferred.item_count-1,choice)
  alternative.set_item_metadata(alternative.item_count-1,choice)
 restore_choice(preferred,row.get("teacher_action",{}))
 restore_choice(alternative,row.get("comparison_action",{}))
 if row.is_empty() and not computer.is_empty():alternative.selected=1
 confidence.selected=["high","medium","low"].find(row.get("confidence","high"));hindsight.button_pressed=row.get("hindsight",false)
 status.text="已载入本步标注。" if not row.is_empty() else "文字点评可随时保存；选择推荐与对照操作可生成偏好样本。"
 if not player.training.load_error.is_empty():status.text=player.training.load_error
 loading=false;dirty=false

func restore_choice(menu: OptionButton,saved: Dictionary):
 menu.selected=0
 if saved.is_empty():return
 for i in range(1,menu.item_count):
  var choice=menu.get_item_metadata(i)
  if choice.action==saved.get("action",{}) and choice.get("source","")==saved.get("source",""):
   menu.selected=i;return
 # Keep an explicitly selected action even if candidate generation changes.
 menu.add_item(saved.get("label","已保存操作"));menu.set_item_metadata(menu.item_count-1,saved.duplicate(true));menu.selected=menu.item_count-1

func selected_choice(menu: OptionButton) -> Dictionary:
 var value=menu.get_item_metadata(menu.selected)
 return value if value is Dictionary else {}

func flush(force: bool=false) -> bool:
 if not dirty and not force:return true
 if comment.text.strip_edges().is_empty() and recommendation.text.strip_edges().is_empty() and preferred.selected==0:
  if force:status.text="请填写点评、推荐路线或选择推荐操作。"
  return not dirty
 var teacher=selected_choice(preferred);var comparison=selected_choice(alternative)
 if not teacher.is_empty() and not comparison.is_empty() and teacher.action==comparison.action:
  status.text="请为对照选择一个不同的推荐操作。";return false
 if not comparison.is_empty() and teacher.is_empty() and comment.text.strip_edges().is_empty() and recommendation.text.strip_edges().is_empty():
  status.text="请填写推荐说明或选择一个不同的推荐操作。";return false
 var fields={"comment":comment.text.strip_edges(),"recommended_text":recommendation.text.strip_edges(),"confidence":["high","medium","low"][confidence.selected],"hindsight":hindsight.button_pressed,"teacher_action":{},"comparison_action":{}}
 fields.teacher_action=teacher.duplicate(true);fields.comparison_action=comparison.duplicate(true)
 var result=player.training.put(frame_index,editing_seat,fields,ctx)
 if result.has("error"):status.text=result.error;return false
 dirty=false;status.text="已保存 · 共 %d 个标注"%result.annotations
 if not comparison.is_empty():
  if teacher.is_empty():status.text+=" · 文字推荐与实际对照已保留，尚未生成数值偏好对"
  elif not teacher.get("endpoint_complete",false) or not comparison.get("endpoint_complete",false):status.text+=" · 推演端点不完整，尚未生成数值偏好对"
 status.text+="\n"+result.path;player.update_training_button();return true

func export_file():
 if not flush():return
 var result=player.training.save()
 if result.has("error"):status.text=result.error;return
 status.text="训练文件已导出 · %d 个标注\n%s"%[result.annotations,result.path]

func delete_row():
 var result=player.training.remove(frame_index,editing_seat)
 if result.has("error"):status.text=result.error;return
 load_row();status.text="已删除本步当前评价方的标注。";player.update_training_button()

func close():
 if not flush():return
 shade.get_parent().remove_child(shade);shade.queue_free();player.training_editor=null

func is_open() -> bool:return is_instance_valid(shade) and not shade.is_queued_for_deletion()
