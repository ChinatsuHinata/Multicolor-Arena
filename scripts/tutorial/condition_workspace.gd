extends Control
## A private battlefield and a selectable predicate graph share one draft.
const Graph=preload("res://scripts/tutorial/condition_graph.gd")
const Capture=preload("res://scripts/tutorial/condition_capture.gd")
const Config=preload("res://scripts/tutorial/config.gd")
var editor
var recorder
var battle
var flow
var graph_editor
var dock: PanelContainer
var controls: PanelContainer
var summary: Label
var feedback: Label
var capture_status: Label
var phase_label: Label
var players: HBoxContainer
var player_buttons: Array=[]
var cards_scroll: ScrollContainer
var card_buttons: Dictionary={}
var results: VBoxContainer
var candidates: Array=[]
var candidate_flags: Array=[]
var capturing=false
var baseline: Dictionary={}
var rule: Dictionary={}
var trigger_index=0
var trigger_event: OptionButton
var trigger_caption: Label
var saved_trigger: Dictionary={}
var callback: Callable
var return_to: Callable

func begin(owner,caption: String,value: Dictionary,on_apply: Callable,on_return: Callable=Callable(),trigger: Dictionary={}) -> String:
 editor=owner;callback=on_apply;return_to=on_return;rule=trigger.duplicate(true)
 name="BattleConditionEditor";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 recorder=preload("res://scripts/tutorial/battle_recorder.gd").new()
 var scene=editor.recorder.scene if editor.recorder!=null else editor.model.data.scenarios[editor.scene_id]
 var reason=recorder.configure(scene,editor.host.Store.CARDS)
 if not reason.is_empty():return reason
 if editor.recorder!=null:recorder.adapter.restore(editor.recorder.adapter.capture());recorder.bind()
 baseline=recorder.adapter.capture()
 flow=preload("res://scripts/tutorial/recording_flow.gd").new();flow.adapter=recorder.adapter;add_child(flow);flow.set_process(false)
 battle=preload("res://scripts/tutorial/condition_battle.gd").new();battle.workspace=self;battle.tutorial_runtime=flow;battle.tutorial_external=true
 add_child(battle);battle.begin(editor.host,{},{},0)
 battle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);battle.position=-global_position;battle.size=get_viewport_rect().size
 battle.mouse_filter=Control.MOUSE_FILTER_IGNORE
 battle.debug_mode=true;battle.response_mode=battle.ResponseMode.ON
 build_controls()
 dock=PanelContainer.new();dock.name="BattleConditionDock";dock.z_index=300;add_child(dock);dock.add_theme_stylebox_override("panel",editor.host.ui_metrics.panel_style())
 var body=VBoxContainer.new();dock.add_child(body)
 editor.text(body,caption+" · 图形化条件").add_theme_color_override("font_color",editor.host.GOLD)
 editor.text(body,"点选节点后点击卡牌、玩家或区域改选对象。衍生物等中途生成实例：录制生成过程 → 结束录制 → 点选实例。").max_lines_visible=3
 if not rule.is_empty():build_trigger_settings(body)
 graph_editor=Graph.new();graph_editor.name="BattleConditionGraph";graph_editor.condition=value.duplicate(true);graph_editor.aliases=recorder.adapter.aliases.keys();graph_editor.steps=editor.model.data.steps.keys()
 graph_editor.allowed_types=Graph.TYPES.keys().filter(func(type):return type!="deck_count")
 graph_editor.custom_minimum_size.y=180 if rule.is_empty() else 140;graph_editor.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(graph_editor)
 summary=editor.text(body,"");summary.name="CurrentConditionSummary";summary.max_lines_visible=2
 var result_scroll=ScrollContainer.new();result_scroll.name="RecordedConditionChoices";result_scroll.custom_minimum_size.y=160 if rule.is_empty() else 120;result_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(result_scroll);result_scroll.hide()
 results=VBoxContainer.new();result_scroll.add_child(results);results.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 feedback=editor.text(body,"");feedback.max_lines_visible=2;feedback.add_theme_color_override("font_color",editor.host.GOLD)
 var buttons=HBoxContainer.new();body.add_child(buttons)
 editor.action(buttons,"应用触发器" if not rule.is_empty() else "应用条件",apply).name="ApplyBattleCondition"
 editor.action(buttons,"取消",cancel).name="CancelBattleCondition"
 build_subjects()
 var arrows=preload("res://scripts/tutorial/condition_arrows.gd").new();arrows.workspace=self;arrows.name="CurrentConditionArrows";arrows.z_index=320;arrows.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(arrows)
 recorder.rejected.connect(func(detail):capture_status.text=detail)
 recorder.changed.connect(update_capture_controls)
 resized.connect(layout);layout();call_deferred("layout");battle.render();return ""

func build_controls():
 controls=PanelContainer.new();controls.name="ConditionRecordingControls";controls.z_index=330;add_child(controls);controls.add_theme_stylebox_override("panel",editor.host.ui_metrics.panel_style())
 var column=VBoxContainer.new();controls.add_child(column)
 var scroll=ScrollContainer.new();column.add_child(scroll);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var row=HBoxContainer.new();scroll.add_child(row)
 editor.action(row,"录制修改触发器" if not rule.is_empty() else "录制修改条件",start_capture).name="RecordCondition"
 editor.action(row,"结束录制",stop_capture).name="FinishConditionRecording"
 editor.action(row,"撤回一步",func():if recorder.undo():battle.sync_tutorial_scenario()).name="UndoConditionRecording"
 editor.action(row,"放弃本次录制",discard_capture).name="DiscardConditionRecording"
 capture_status=Label.new();column.add_child(capture_status);capture_status.clip_text=true
 update_capture_controls()

func build_trigger_settings(parent: Node):
 var event_row=HBoxContainer.new();parent.add_child(event_row);var event_label=editor.text(event_row,"触发事件");event_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 var labels={"command_accepted":"操作完成后","state_changed":"状态改变后","phase_changed":"阶段改变后","priority_changed":"执行权改变后","step_entered":"进入教程步骤时","ui_action_accepted":"界面操作完成后"}
 saved_trigger=rule.get("on_action",{}).duplicate(true)
 var events=Config.EVENTS.filter(func(event):return event!="ui_action_accepted")
 trigger_event=editor.option(event_row,events,rule.event,func(event):
  rule.event=event
  if event!="command_accepted":rule.erase("on_action")
  elif not saved_trigger.is_empty():rule.on_action=saved_trigger.duplicate(true)
  update_trigger_caption(),events.map(func(event):return labels.get(event,event)))
 trigger_event.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var row=HBoxContainer.new();parent.add_child(row);var count_label=editor.text(row,"执行次数上限");count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 var count=SpinBox.new();row.add_child(count);count.name="TriggerExecutionLimit";count.min_value=1;count.max_value=100000;count.value=rule.max_times
 count.value_changed.connect(func(value):rule.max_times=int(value))
 trigger_caption=editor.text(parent,"");trigger_caption.max_lines_visible=1;update_trigger_caption()

func update_trigger_caption():
 if not is_instance_valid(trigger_caption):return
 trigger_caption.text="触发动作："+preload("res://scripts/tutorial/battle_commands.gd").caption(recorder.adapter,rule.on_action) if rule.has("on_action") else "按当前条件触发；录制可指定触发动作和响应。"
 trigger_caption.tooltip_text=trigger_caption.text

func build_subjects():
 players=HBoxContainer.new();players.z_index=310;add_child(players)
 for who in range(2):
  var button=editor.action(players,"",func():pick_player(who));button.name="ConditionPlayer_"+str(who);player_buttons.append(button)
 phase_label=Label.new();players.add_child(phase_label);phase_label.add_theme_color_override("font_color",editor.host.GOLD)
 cards_scroll=ScrollContainer.new();cards_scroll.name="ConditionCardSubjects";cards_scroll.z_index=310;cards_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(cards_scroll)
 var row=HBoxContainer.new();cards_scroll.add_child(row)
 refresh_subjects()

func refresh_subjects():
 var row=cards_scroll.get_child(0);editor.host.free_children(row);card_buttons={}
 graph_editor.created_names={};graph_editor.alias_names={}
 for subject in recorder.adapter.card_subjects():
  var card=subject.card;var ref=subject.ref;var id=Graph.subject_name(ref)
  var card_name=recorder.adapter.engine.cards.get(card.card_id,{}).get("name",card.card_id)
  var caption=("我方 · " if int(card.owner)==0 else "对方 · ")+card_name
  if ref.has("created"):
   caption=id+" · "+caption;graph_editor.created_names[int(ref.created)]=caption
  else:graph_editor.alias_names[ref.alias]=card_name+" · "+ref.alias
  var uid=int(card.uid)
  var button=editor.action(row,caption,func():pick_card(uid))
  button.tooltip_text=caption+" · "+id;button.clip_text=true;button.custom_minimum_size.x=220 if ref.has("created") else 150;card_buttons[uid]=button
 graph_editor.rebuild()

func safe_rect() -> Rect2:
 var safe=editor.host.ui_metrics.safe.intersection(get_global_rect())
 return safe if safe.has_area() else get_global_rect()

func battle_area() -> Rect2:
 var safe=safe_rect();var width=clampf(size.x*0.42,380,680)
 var top=controls.get_combined_minimum_size().y+64 if is_instance_valid(controls) else 172
 return Rect2(safe.position+Vector2(8,top),Vector2(maxf(200,safe.size.x-width-24),maxf(220,safe.size.y-top-76)))

func layout():
 if not is_instance_valid(dock):return
 var safe=safe_rect();var width=clampf(size.x*0.42,380,680)
 dock.position=safe.position-global_position+Vector2(safe.size.x-width-8,8);dock.size=Vector2(width,safe.size.y-16)
 controls.position=safe.position-global_position+Vector2(8,8);controls.size.x=safe.size.x-16 if capturing else safe.size.x-width-24
 players.position=safe.position-global_position+Vector2(8,controls.get_combined_minimum_size().y+16)
 cards_scroll.position=safe.position-global_position+Vector2(8,safe.size.y-66);cards_scroll.size=Vector2(maxf(200,safe.size.x-width-24),62)
 dock.visible=not capturing;players.visible=not capturing;cards_scroll.visible=not capturing
 battle.position=-global_position;battle.size=get_viewport_rect().size
 battle.resize_world()

func current_condition() -> Dictionary:
 return graph_editor.condition if graph_editor.selected_condition.is_empty() else graph_editor.selected_condition

func pick_card(uid: int):
 if capturing:return
 var ref=preload("res://scripts/tutorial/battle_commands.gd").card_ref(recorder.adapter,uid)
 if ref.is_empty():feedback.text="此实例当前无法定位，请重新录制生成过程。";return
 var c=current_condition()
 if c.type in Config.ENTITY_CONDITIONS:
  c.erase("alias");c.erase("created");c.merge(ref);graph_editor.changed(c);graph_editor.rebuild()
 else:
  var card=recorder.adapter.engine.find_card(uid)
  var value={"type":"entity_zone","zone":card.zone};value.merge(ref);graph_editor.replace_selected(value)

func pick_player(who: int):
 if capturing:return
 var c=current_condition()
 if c.has("player"):c.player=who
 elif c.type=="priority":c.value=who
 elif c.has("owner"):c.owner=who
 else:graph_editor.replace_selected({"type":"life","player":who,"op":"le","value":int(recorder.adapter.engine.players[who].life)});return
 graph_editor.changed(c);graph_editor.rebuild()

func pick_zone(who: int,zone: String):
 if capturing:return
 var c=current_condition()
 if c.get("type")=="entity_zone":c.zone=zone;graph_editor.changed(c);graph_editor.rebuild();return
 if zone not in Config.ZONES:return
 graph_editor.replace_selected({"type":"zone_count","player":who,"zone":zone,"op":"eq","value":recorder.adapter.engine.players[who][zone].size()})

func start_capture():
 if capturing:return
 recorder.adapter.restore(baseline)
 recorder.actions=[];recorder.random_results=[];recorder.points=[{"adapter":recorder.adapter.capture(),"random_count":0}];recorder.cursor=0
 recorder.recording=true;recorder.replaying=false;recorder.advance_rng=true;recorder.bind();capturing=true
 results.get_parent().hide();feedback.text="";layout();battle.sync_tutorial_scenario();update_capture_controls()

func stop_capture():
 if not capturing or recorder.actions.is_empty():return
 recorder.finish();capturing=false;refresh_subjects();layout();battle.sync_tutorial_scenario();show_recorded_choices();update_capture_controls()

func discard_capture():
 recorder.recording=false;recorder.adapter.restore(baseline);recorder.bind();recorder.actions=[];recorder.points=[];recorder.random_results=[];recorder.cursor=0
 capturing=false;refresh_subjects();results.get_parent().hide();layout();battle.sync_tutorial_scenario();update_capture_controls()

func update_capture_controls():
 if not is_instance_valid(controls):return
 controls.find_child("RecordCondition",true,false).disabled=capturing
 controls.find_child("FinishConditionRecording",true,false).disabled=not capturing or recorder.actions.is_empty()
 controls.find_child("UndoConditionRecording",true,false).disabled=not capturing or recorder.cursor==0
 controls.find_child("DiscardConditionRecording",true,false).disabled=not capturing and recorder.actions.is_empty()
 capture_status.text=("录制中 · %d 个操作" % recorder.actions.size()) if capturing else "编辑草稿 · 录制结果应用前可继续修改"

func show_recorded_choices():
 editor.host.free_children(results);results.get_parent().show();candidate_flags=[]
 if not rule.is_empty():
  editor.text(results,"选择作为触发的操作；后续连续的对方操作将成为响应。")
  var labels=[]
  for i in range(recorder.actions.size()):labels.append(str(i+1)+" · "+preload("res://scripts/tutorial/battle_commands.gd").caption(recorder.adapter,recorder.actions[i]))
  trigger_index=0;editor.option(results,range(recorder.actions.size()),trigger_index,func(index):trigger_index=index,labels)
 else:
  candidates=Capture.candidates(recorder,current_condition())
  for item in candidates:
   var flag=editor.flag(results,Graph.describe(item.condition,editor.host.Store.CARDS),item.get("selected",false),func(_value):pass);candidate_flags.append(flag)
 editor.action(results,"用录制结果替换选中条件" if rule.is_empty() else "用录制更新触发和响应",use_recording).name="UseConditionRecording"

func use_recording():
 if rule.is_empty():
  var chosen=[]
  for i in range(candidates.size()):
   if candidate_flags[i].button_pressed:chosen.append(candidates[i].condition.duplicate(true))
  if chosen.is_empty():feedback.text="请先选择至少一个实际条件。";return
  graph_editor.replace_selected(chosen[0] if chosen.size()==1 else {"type":"all","conditions":chosen})
 else:
  var value=Capture.trigger(recorder,trigger_index,rule)
  if value.is_empty():feedback.text="请先选择一个有效触发动作。";return
  rule=value;saved_trigger=rule.on_action.duplicate(true);trigger_event.select(Config.EVENTS.filter(func(event):return event!="ui_action_accepted").find(rule.event));update_trigger_caption()
  graph_editor.condition=rule.when.duplicate(true);graph_editor.selected_condition={};graph_editor.rebuild()
 feedback.text="已更新草稿，点击应用后保存到当前条件／触发器。"

func reference_rect(ref: Dictionary) -> Rect2:
 var view=recorder.adapter.engine
 match ref.kind:
  "player":return player_buttons[int(ref.player)].get_global_rect()
  "phase":return phase_label.get_global_rect()
  "zone":
   var center=battle.project(battle.table.zone_position(ref.zone,int(ref.player)))
   if ref.zone=="field":center=battle.project(Vector3(0,0,2.8 if int(ref.player)==0 else -2.8))
   return Rect2(center-Vector2(24,18),Vector2(48,36))
  "card":
   var card=view.find_card(int(ref.ref.uid))
   if card.zone not in ["hand","stack"]:
    var rect=battle.target_rect(ref.ref)
    if rect.has_area():return rect
   if card_buttons.has(int(card.get("uid",-1))):
    return battle.clipped_arrow_rect(card_buttons[int(card.uid)].get_global_rect(),cards_scroll.get_global_rect())
 return Rect2()

func condition_arrows() -> Array:
 if capturing or graph_editor==null:return []
 var origin=graph_editor.selected_node.get_global_rect() if is_instance_valid(graph_editor.selected_node) else dock.get_global_rect()
 origin=origin.intersection(graph_editor.get_global_rect())
 if not origin.has_area():origin=summary.get_global_rect()
 var arrows=[];var seen=[]
 for ref in Capture.references(current_condition(),recorder.adapter):
  var rect=reference_rect(ref)
  if not rect.has_area() or rect in seen:continue
  seen.append(rect);arrows.append({"from":battle.rect_edge(origin,rect.get_center())-global_position,"to":battle.rect_edge(rect,origin.get_center())-global_position})
 return arrows

func apply():
 var check=Config.new();check.definitions=editor.host.Store.CARDS
 var value=graph_editor.condition.duplicate(true)
 if rule.is_empty():check.condition(value,"condition",editor.model.data.steps)
 else:rule.when=value;value=rule.duplicate(true);check.opponent({"strategy":"rules","rules":[value]},"opponent",editor.model.data.steps)
 check.check_scene_fields(value,"condition","battlefield",[],false)
 check.check_aliases(value,"condition",recorder.adapter.aliases)
 if not check.errors.is_empty():feedback.text="\n".join(check.errors);return
 var old_scene=editor.model.data.scenarios[editor.scene_id];var old_undo=editor.model.undo_stack.duplicate();var old_redo=editor.model.redo_stack.duplicate()
 if editor.recorder==null and rule.is_empty() and old_scene!=recorder.scene:
  editor.model.checkpoint();editor.model.data.scenarios[editor.scene_id]=recorder.scene.duplicate(true)
 if callback.call(value)==false:
  editor.model.data.scenarios[editor.scene_id]=old_scene;editor.model.undo_stack=old_undo;editor.model.redo_stack=old_redo;return
 editor.close_dialog()
 if return_to.is_valid():return_to.call()
 else:editor.refresh()

func cancel():
 editor.close_dialog()
 if return_to.is_valid():return_to.call()
 else:editor.refresh()

func _process(_delta):
 if graph_editor==null or not is_instance_valid(summary):return
 summary.text="当前条件："+Graph.describe(current_condition(),editor.host.Store.CARDS)+(" · 此预览满足" if recorder.adapter.evaluate(current_condition(),[]) else " · 此预览未满足")
 for who in range(2):player_buttons[who].text=("我方" if who==0 else "对方")+"生命 "+str(recorder.adapter.engine.players[who].life)
 phase_label.text="阶段 · "+Graph.PHASE_NAMES.get(recorder.adapter.engine.phase,recorder.adapter.engine.phase)
