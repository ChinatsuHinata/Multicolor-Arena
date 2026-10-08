extends Control
## A private battlefield and a selectable predicate graph share one draft.
const Graph=preload("res://scripts/tutorial/condition_graph.gd")
const Capture=preload("res://scripts/tutorial/condition_capture.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const BlockPriorities=preload("res://scripts/tutorial/block_priorities.gd")
var editor
var recorder
var battle
var flow
var graph_editor
var dock: PanelContainer
var dock_scroll: ScrollContainer
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
var block_settings: VBoxContainer
var block_scroll: ScrollContainer
var picking_blockers=false
var trigger_sections: Array=[]
var trigger_tabs: Array=[]
var trigger_filters: VBoxContainer
var response_settings: VBoxContainer
var trigger_overview: Label
var heading_label: Label

func begin(owner,caption: String,value: Dictionary,on_apply: Callable,on_return: Callable=Callable(),trigger: Dictionary={},draft_scene: Dictionary={}) -> String:
 editor=owner;callback=on_apply;return_to=on_return;rule=trigger.duplicate(true)
 name="BattleConditionEditor";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 recorder=preload("res://scripts/tutorial/battle_recorder.gd").new()
 var scene=editor.recorder.scene if editor.recorder!=null else editor.model.data.scenarios[editor.scene_id]
 if not draft_scene.is_empty():scene=draft_scene
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
 dock=PanelContainer.new();dock.name="BattleConditionDock";dock.z_index=300;dock.clip_contents=true;add_child(dock);dock.add_theme_stylebox_override("panel",editor.host.ui_metrics.panel_style())
 var column=VBoxContainer.new();dock.add_child(column)
 var heading=VBoxContainer.new();column.add_child(heading)
 # Keep apply/cancel outside the scrolling editor so content cannot push them off-screen.
 dock_scroll=ScrollContainer.new();dock_scroll.name="ConditionEditorContent";column.add_child(dock_scroll)
 dock_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;dock_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var body=VBoxContainer.new();dock_scroll.add_child(body);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 heading_label=editor.text(heading,caption);heading_label.add_theme_color_override("font_color",editor.host.GOLD)
 var graph_body=body
 if not rule.is_empty():
  trigger_overview=editor.text(heading,"");trigger_overview.name="TriggerRuleOverview";trigger_overview.max_lines_visible=4
  editor.action(heading,"快捷对策：攻击与阻挡",enable_block_presets).name="QuickAttackBlock"
  var tabs=HBoxContainer.new();heading.add_child(tabs)
  for i in range(3):
   var tab=editor.action(tabs,["1 触发时机","2 条件","3 对方响应"][i],func():show_trigger_section(i))
   tab.name=["TriggerTimingTab","TriggerConditionTab","TriggerResponseTab"][i];tab.toggle_mode=true;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;trigger_tabs.append(tab)
  for i in range(3):
   var section=VBoxContainer.new();body.add_child(section);section.size_flags_vertical=Control.SIZE_EXPAND_FILL;trigger_sections.append(section)
  build_trigger_settings(trigger_sections[0]);graph_body=trigger_sections[1]
 editor.text(graph_body,"点选条件节点，再点击战场卡牌、玩家或区域选择对象。生成实例可先录制再点选。").max_lines_visible=3
 graph_editor=Graph.new();graph_editor.name="BattleConditionGraph";graph_editor.condition=value.duplicate(true);graph_editor.aliases=recorder.adapter.aliases.keys();graph_editor.steps=editor.model.data.steps.keys()
 graph_editor.allowed_types=Graph.TYPES.keys().filter(func(type):return type!="deck_count")
 graph_editor.custom_minimum_size.y=300 if rule.is_empty() else 240;graph_editor.size_flags_vertical=Control.SIZE_EXPAND_FILL;graph_body.add_child(graph_editor)
 graph_editor.resized.connect(focus_block_condition)
 if not rule.is_empty():
  response_settings=VBoxContainer.new();trigger_sections[2].add_child(response_settings)
  build_block_settings(trigger_sections[2]);refresh_response_settings();show_trigger_section(1)
 summary=editor.text(body,"");summary.name="CurrentConditionSummary";summary.max_lines_visible=2
 var result_scroll=ScrollContainer.new();result_scroll.name="RecordedConditionChoices";result_scroll.custom_minimum_size.y=160 if rule.is_empty() else 120;result_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(result_scroll);result_scroll.hide()
 results=VBoxContainer.new();result_scroll.add_child(results);results.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 feedback=editor.text(body,"");feedback.max_lines_visible=2;feedback.add_theme_color_override("font_color",editor.host.GOLD)
 var buttons=HBoxContainer.new();buttons.name="ConditionEditorActions";column.add_child(buttons)
 editor.action(buttons,"应用触发器" if not rule.is_empty() else "应用条件",apply).name="ApplyBattleCondition"
 editor.action(buttons,"取消",cancel).name="CancelBattleCondition"
 build_subjects();refresh_block_settings()
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
 editor.text(parent,"何时检查这条规则？").add_theme_color_override("font_color",editor.host.GOLD)
 editor.text(parent,"规则名称")
 editor.line(parent,rule.id,func(value):rule.id=value.strip_edges();heading_label.text="触发器 · "+rule.id).name="TriggerName"
 var event_row=HBoxContainer.new();parent.add_child(event_row);var event_label=editor.text(event_row,"触发事件");event_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 var labels=preload("res://scripts/tutorial/trigger_list_form.gd").EVENT_NAMES
 saved_trigger=rule.get("on_action",{}).duplicate(true)
 var events=Config.EVENTS.filter(func(event):return event!="ui_action_accepted")
 trigger_event=editor.option(event_row,events,rule.event,func(event):
  rule.event=event
  if event!="command_accepted":rule.erase("on_action")
  elif not saved_trigger.is_empty():rule.on_action=saved_trigger.duplicate(true)
  refresh_trigger_filters();update_trigger_caption(),events.map(func(event):return labels.get(event,event)))
 trigger_event.name="TriggerEvent"
 trigger_event.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var row=HBoxContainer.new();parent.add_child(row);var count_label=editor.text(row,"执行次数上限");count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 var count=SpinBox.new();row.add_child(count);count.name="TriggerExecutionLimit";count.min_value=1;count.max_value=100000;count.value=rule.max_times
 count.value_changed.connect(func(value):rule.max_times=int(value))
 editor.text(parent,"只有对手成功执行响应才计一次；重置任务会恢复次数。")
 trigger_filters=VBoxContainer.new();parent.add_child(trigger_filters);refresh_trigger_filters()
 trigger_caption=editor.text(parent,"");trigger_caption.max_lines_visible=3;update_trigger_caption()

func show_trigger_section(index: int):
 if index==2:refresh_block_settings();update_trigger_caption()
 for i in range(trigger_sections.size()):
  trigger_sections[i].visible=i==index;trigger_tabs[i].set_pressed_no_signal(i==index)
 if is_instance_valid(dock_scroll):dock_scroll.scroll_vertical=0
 call_deferred("layout")

func refresh_trigger_filters():
 editor.host.free_children(trigger_filters)
 if rule.event!="command_accepted":return
 editor.text(trigger_filters,"限定哪种操作？")
 var kinds=["any","pass_priority","attack","cast","ability"]
 var current=rule.get("on_action",{}).get("type","any")
 if current not in kinds:kinds.append(current)
 var labels=preload("res://scripts/tutorial/battle_commands.gd").LABELS
 editor.option(trigger_filters,kinds,current,func(kind):
  if kind=="any":rule.erase("on_action")
  else:
   var action={"type":kind,"player":0}
   if kind in ["attack","cast","ability"]:
    var refs=recorder.adapter.card_subjects().filter(func(item):return int(item.card.owner)==0)
    action["source" if kind=="ability" else "card"]=refs[0].ref.duplicate(true) if not refs.is_empty() else {"alias":"选择卡牌"}
    if kind=="ability":action.index=0
   rule.on_action=action
  saved_trigger=rule.get("on_action",{}).duplicate(true);refresh_trigger_filters();update_trigger_caption(),kinds.map(func(kind):return "任意操作" if kind=="any" else labels.get(kind,kind))).name="TriggerActionFilter"
 if not rule.has("on_action"):return
 if rule.on_action.type=="delay":return
 editor.option(trigger_filters,[0,1],rule.on_action.player,func(who):rule.on_action.player=who;saved_trigger=rule.on_action.duplicate(true);refresh_trigger_filters(),["我方操作","对方操作"]).name="TriggerActionPlayer"
 for key in ["card","source"]:
  if rule.on_action.has(key):subject_option(trigger_filters,rule.on_action,key,int(rule.on_action.player),"TriggerActionCard")

func subject_option(parent: Node,action: Dictionary,key: String,who: int,control_name: String):
 var refs=recorder.adapter.card_subjects().filter(func(item):return int(item.card.owner)==who).map(func(item):return item.ref)
 if action.has(key) and action[key] not in refs:refs.append(action[key])
 if refs.is_empty():editor.text(parent,"此场景还没有可选卡牌，请先布置场面或录制生成过程。");return
 editor.option(parent,refs,action.get(key,refs[0]),func(ref):action[key]=ref.duplicate(true);saved_trigger=rule.get("on_action",{}).duplicate(true),refs.map(subject_caption)).name=control_name

func response_kind() -> String:
 if rule.has("sequence"):return "sequence"
 var action=rule.get("action","pass_priority")
 if action is String:return action
 if action.type=="block":return "priorities" if action.has("priorities") else "block"
 return action.type

func refresh_response_settings():
 if not is_instance_valid(response_settings):return
 editor.host.free_children(response_settings)
 editor.text(response_settings,"条件满足后，对方做什么？").add_theme_color_override("font_color",editor.host.GOLD)
 editor.option(response_settings,["pass_priority","block","priorities","cast","ability","sequence"],response_kind(),set_response,["让过执行权","指定单位阻挡／不阻挡","按优先级自动阻挡","使用指定手牌","启动指定异能","录制固定响应序列"]).name="TriggerResponseType"
 if rule.has("sequence"):
  for action in rule.sequence.get("actions",[]):editor.text(response_settings,preload("res://scripts/tutorial/battle_commands.gd").caption(recorder.adapter,action))
  editor.action(response_settings,"重新录制触发和响应",start_capture)
  return
 if not rule.action is Dictionary:return
 var action=rule.action
 if action.type=="block" and not action.has("priorities"):
  editor.text(response_settings,"勾选对方的阻挡单位；不选任何单位则不阻挡。")
  var refs=block_subjects(1).map(func(item):return item.ref)
  for ref in action.cards:
   if ref not in refs:refs.append(ref)
  for ref in refs:
   editor.flag(response_settings,subject_caption(ref),ref in action.cards,func(enabled):
    if enabled and ref not in action.cards:action.cards.append(ref)
    elif not enabled:action.cards.erase(ref)).name="TriggerBlockTarget_"+Graph.subject_name(ref)
 elif action.type in ["cast","ability"]:
  editor.text(response_settings,"对方手牌" if action.type=="cast" else "异能来源")
  subject_option(response_settings,action,"card" if action.type=="cast" else "source",1,"TriggerResponseCard")
  if action.type=="ability":
   editor.option(response_settings,["index","key"],"key" if action.has("key") else "index",func(mode):
    action.erase("index");action.erase("key");action[mode]="输入异能键" if mode=="key" else 0;refresh_response_settings(),["按序号指定异能","按异能键指定"]).name="TriggerAbilitySelector"
   editor.text(response_settings,"异能键" if action.has("key") else "异能序号（从 0 开始）")
   if action.has("key"):editor.line(response_settings,action.key,func(value):action.key=value)
   else:
    var index=SpinBox.new();response_settings.add_child(index);index.min_value=0;index.max_value=100;index.value=action.index;index.value_changed.connect(func(value):action.index=int(value))
  editor.text(response_settings,"目标")
  var targets=[{}, {"player":0}, {"player":1}]
  var labels=["不指定目标","我方玩家","对方玩家"]
  for subject in recorder.adapter.card_subjects():targets.append(subject.ref);labels.append(subject_caption(subject.ref))
  var target=action.get("target",{})
  if target not in targets:targets.append(target);labels.append("已有复合目标")
  editor.option(response_settings,targets,target,func(value):
   if value.is_empty():action.erase("target")
   else:action.target=value.duplicate(true),labels).name="TriggerResponseTarget"
  editor.text(response_settings,"使用真实费用；卡牌不可用或费用不足时，会尝试后面的规则。")

func set_response(kind: String):
 if kind=="sequence":refresh_response_settings();start_capture();return
 if kind=="priorities":enable_block_presets();refresh_response_settings();return
 rule.erase("otherwise")
 rule.erase("sequence")
 match kind:
  "pass_priority":rule.action="pass_priority"
  "block":rule.action={"type":"block","cards":[]}
  "cast","ability":
   var refs=recorder.adapter.card_subjects().filter(func(item):return int(item.card.owner)==1)
   refs=refs.filter(func(item):return item.card.zone==("hand" if kind=="cast" else "field"))+refs.filter(func(item):return item.card.zone!=("hand" if kind=="cast" else "field"))
   rule.action={"type":kind};rule.action["card" if kind=="cast" else "source"]=refs[0].ref.duplicate(true) if not refs.is_empty() else {"alias":"选择卡牌"}
   if kind=="ability":rule.action.index=0
 refresh_response_settings();refresh_block_settings();update_trigger_caption()

func build_block_settings(parent: Node):
 block_scroll=ScrollContainer.new();block_scroll.name="BlockPrioritySettings";parent.add_child(block_scroll)
 block_scroll.custom_minimum_size.y=160;block_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;block_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 block_settings=VBoxContainer.new();block_scroll.add_child(block_settings);block_settings.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 block_scroll.visible=has_block_presets()

func has_block_presets() -> bool:
 return rule.get("action") is Dictionary and rule.action.get("type")=="block" and rule.action.has("priorities")

func attacker_condition(c: Dictionary) -> Dictionary:
 if c.get("type") in ["combat_attacker","combat_attacker_rank"]:return c
 for child in c.get("conditions",[]):
  var found=attacker_condition(child)
  if not found.is_empty():return found
 return {}

func attack_mode() -> String:
 var c=attacker_condition(graph_editor.condition)
 if c.get("type")!="combat_attacker_rank":return "selected"
 if c.get("player")==0 and c.get("key")=="spirit":
  if c.get("count_player")==1 and c.get("ties","field_order")=="field_order":return "opponent_count"
  if c.get("count")==1 and c.get("ties")=="all":return "highest"
 return "custom_rank"

func set_attack_mode(mode: String):
 var previous=attacker_condition(graph_editor.condition)
 var predicate={}
 if mode=="selected":
  var refs=block_subjects(0).map(func(subject):return subject.ref)
  if refs.is_empty():feedback.text="请先设置我方单位，或录制生成单位。";return
  predicate={"type":"combat_attacker"};predicate.merge(refs[0]);rule.erase("otherwise")
 else:
  predicate={"type":"combat_attacker_rank","player":0,"key":"spirit","ties":"all","count":1}
  if mode=="opponent_count":predicate.erase("count");predicate.count_player=1;predicate.ties="field_order"
  elif mode=="custom_rank" and previous.get("type")=="combat_attacker_rank":predicate=previous.duplicate(true)
  enable_rank_response()
 if previous.is_empty():graph_editor.condition=predicate
 else:previous.clear();previous.merge(predicate)
 graph_editor.selected_condition={};graph_editor.changed();graph_editor.rebuild()
 refresh_block_settings();update_trigger_caption()
 block_scroll.scroll_vertical=0

func enable_rank_response():
 rule.otherwise="no_block"
 # A rank shortcut applies to multiple attackers, rather than one recorded move.
 if int(rule.max_times)==1:
  rule.max_times=100000
  var limit=find_child("TriggerExecutionLimit",true,false)
  if limit!=null:limit.set_value_no_signal(rule.max_times)

func block_subjects(who: int) -> Array:
 var subjects=recorder.adapter.card_subjects().filter(func(subject):return int(subject.card.owner)==who and recorder.adapter.engine.is_unit(subject.card))
 return subjects.filter(func(subject):return subject.card.zone=="field")+subjects.filter(func(subject):return subject.card.zone!="field")

func subject_caption(ref: Dictionary) -> String:
 var card=recorder.adapter.resolve_card(ref)
 var caption=Graph.subject_name(ref)
 if not card.is_empty():caption=recorder.adapter.engine.cards[card.card_id].name+" · "+caption
 return caption

func enable_block_presets():
 if has_block_presets():show_trigger_section(2);block_scroll.show();return
 var subjects=block_subjects(0)
 var c=attacker_condition(graph_editor.condition)
 if not subjects.any(func(subject):return subject.card.zone=="field") and c.get("type")!="combat_attacker_rank":c={"type":"combat_attacker_rank","player":0,"key":"spirit","count":1,"ties":"all"}
 var ref=subjects[0].ref if not subjects.is_empty() else {}
 if c.get("type")=="combat_attacker" and recorder.adapter.resolve_card(c).get("owner",-1)==0:
  ref={"created":c.created} if c.has("created") else {"alias":c.alias}
 rule.event="state_changed";rule.erase("on_action");rule.erase("sequence");saved_trigger={}
 rule.action={"type":"block","priorities":BlockPriorities.defaults()}
 if c.get("type")=="combat_attacker_rank":graph_editor.condition=c.duplicate(true);enable_rank_response()
 else:graph_editor.condition={"type":"combat_attacker"};graph_editor.condition.merge(ref);rule.erase("otherwise")
 graph_editor.selected_condition={};graph_editor.rebuild()
 trigger_event.select(Config.EVENTS.filter(func(event):return event!="ui_action_accepted").find(rule.event));update_trigger_caption()
 block_scroll.show();refresh_block_settings()
 refresh_trigger_filters();refresh_response_settings();show_trigger_section(2)

func refresh_block_settings():
 if not is_instance_valid(block_settings):return
 editor.host.free_children(block_settings)
 if not has_block_presets():block_scroll.hide();picking_blockers=false;return
 editor.text(block_settings,"哪些我方攻击需要阻挡？")
 editor.option(block_settings,["selected","highest","opponent_count","custom_rank"],attack_mode(),set_attack_mode,["指定我方单位","我方灵力最高的单位","我方灵力前 x 名（x = 对方单位数）","自定义攻击单位排名"]).name="BlockAttackMode"
 var refs=block_subjects(0).map(func(subject):return subject.ref)
 var c=attacker_condition(graph_editor.condition)
 var selected={"created":c.created} if c.has("created") else {"alias":c.alias} if c.has("alias") else {}
 if not selected.is_empty() and selected not in refs:refs.append(selected)
 if c.get("type")!="combat_attacker_rank" and not refs.is_empty():
  editor.option(block_settings,refs,selected,func(ref):
   var predicate=attacker_condition(graph_editor.condition)
   if predicate.is_empty():predicate={"type":"combat_attacker"};graph_editor.condition=predicate
   predicate.erase("alias");predicate.erase("created");predicate.merge(ref)
   graph_editor.selected_condition={};graph_editor.changed(predicate);graph_editor.rebuild(),refs.map(subject_caption)).name="BlockAttackSubject"
 if c.get("type")=="combat_attacker_rank":
  editor.text(block_settings,Graph.describe(c)+"。按当前场上全部单位计算，包含横置单位和已在场的自机。")
  editor.text(block_settings,"灵力最高包含所有并列最高；前 x 名默认按战场顺序取同值单位。可在条件页修改排名数值、数量来源及同值处理。")
 editor.flag(block_settings,"条件不满足或次数用尽时自动不阻挡",rule.get("otherwise","")=="no_block",func(value):
  if value:rule.otherwise="no_block"
  else:rule.erase("otherwise")
  update_trigger_caption()).name="BlockUnmatchedPass"
 editor.text(block_settings,"勾选启用，↑↓排序；全部不满足则不阻挡。大小按攻击→剩余血量比较。联合击杀按当前战斗预估。")
 var options=rule.action.priorities
 for i in range(options.size()):
  var option=options[i];var row=HBoxContainer.new();block_settings.add_child(row)
  var check=editor.flag(row,str(i+1)+". "+BlockPriorities.LABELS[option.strategy],option.get("enabled",true),func(value):option.enabled=value)
  check.name="BlockPriority_"+option.strategy;check.size_flags_horizontal=Control.SIZE_EXPAND_FILL;check.clip_text=true;check.tooltip_text=check.text
  editor.action(row,"↑",func():move_block_priority(i,-1)).name="BlockMoveUp_"+option.strategy
  row.get_child(row.get_child_count()-1).disabled=i==0
  editor.action(row,"↓",func():move_block_priority(i,1)).name="BlockMoveDown_"+option.strategy
  row.get_child(row.get_child_count()-1).disabled=i==options.size()-1
 var selections=options.filter(func(option):return option.strategy=="selected")
 if not selections.is_empty():
  var option=selections[0]
  var picker=editor.action(block_settings,"结束点选阻挡单位" if picking_blockers else "点选战场阻挡单位（可多选）",func():picking_blockers=not picking_blockers;refresh_block_settings())
  picker.name="PickPresetBlockers"
  var targets=block_subjects(1).map(func(subject):return subject.ref)
  for ref in option.cards:
   if ref not in targets:targets.append(ref)
  for ref in targets:
   editor.flag(block_settings,subject_caption(ref),ref in option.cards,func(value):
    if value and ref not in option.cards:option.cards.append(ref)
    elif not value:option.cards.erase(ref)).name="PresetBlockTarget_"+Graph.subject_name(ref)
 call_deferred("focus_block_condition")

func focus_block_condition():
 if not has_block_presets() or not block_scroll.visible or not is_instance_valid(graph_editor.selected_node):return
 graph_editor.graph.zoom=0.65
 graph_editor.graph.scroll_offset=graph_editor.selected_node.position_offset*0.65-Vector2(24,48)

func move_block_priority(index: int,direction: int):
 var options=rule.action.priorities;var target=index+direction
 if target<0 or target>=options.size():return
 var option=options.pop_at(index);options.insert(target,option);refresh_block_settings()

func update_trigger_caption():
 if not is_instance_valid(trigger_caption):return
 trigger_caption.text="触发动作："+preload("res://scripts/tutorial/battle_commands.gd").caption(recorder.adapter,rule.on_action) if rule.has("on_action") else "按当前条件触发；录制可指定触发动作和响应。"
 trigger_caption.tooltip_text=trigger_caption.text
 trigger_event.disabled=false
 if has_block_presets():
  var condition=graph_editor.condition if graph_editor!=null else rule.get("when",{"type":"always"})
  trigger_caption.text=Graph.describe(condition)+"，按优先级阻挡；对方自动让过战斗响应。"+("范围外自动不阻挡。" if rule.get("otherwise","")=="no_block" else "")
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
 refresh_block_settings()

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
 if picking_blockers and has_block_presets():
  var card=recorder.adapter.engine.find_card(uid)
  if card.owner!=1 or not recorder.adapter.engine.is_unit(card):feedback.text="请选择对方的阻挡单位。";return
  for option in rule.action.priorities:
   if option.strategy=="selected":
    if ref in option.cards:option.cards.erase(ref)
    else:option.cards.append(ref)
  refresh_block_settings();return
 var c=current_condition()
 if c.type=="combat_attacker_rank":
  var who=int(recorder.adapter.engine.find_card(uid).owner)
  if has_block_presets() and who!=0:feedback.text="请选择我方单位；排名条件会自动比较全部单位。";return
  c.player=who;graph_editor.changed(c);graph_editor.rebuild();refresh_block_settings();return
 if c.type in Config.ENTITY_CONDITIONS:
  if has_block_presets() and c.type=="combat_attacker" and recorder.adapter.engine.find_card(uid).owner!=0:feedback.text="请选择我方的攻击单位。";return
  c.erase("alias");c.erase("created");c.merge(ref);graph_editor.changed(c);graph_editor.rebuild()
  refresh_block_settings()
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
 picking_blockers=false
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
  rule=value;saved_trigger=rule.get("on_action",{}).duplicate(true);trigger_event.select(Config.EVENTS.filter(func(event):return event!="ui_action_accepted").find(rule.event));update_trigger_caption()
  graph_editor.condition=rule.when.duplicate(true);graph_editor.selected_condition={};graph_editor.rebuild()
  refresh_trigger_filters();refresh_response_settings();refresh_block_settings()
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
 var origin=graph_editor.selected_node.get_global_rect() if is_instance_valid(graph_editor.selected_node) and graph_editor.selected_node.is_visible_in_tree() else Rect2()
 origin=origin.intersection(graph_editor.get_global_rect()).intersection(dock_scroll.get_global_rect())
 if not origin.has_area():origin=summary.get_global_rect().intersection(dock_scroll.get_global_rect())
 if not origin.has_area():return []
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
 if is_instance_valid(trigger_overview):
  trigger_overview.text="当「%s」，且「%s」\n对方 → %s · 最多 %d 次" % [preload("res://scripts/tutorial/trigger_list_form.gd").EVENT_NAMES.get(rule.event,rule.event),Graph.describe(graph_editor.condition,editor.host.Store.CARDS),preload("res://scripts/tutorial/trigger_list_form.gd").response_caption(rule),rule.max_times]
  trigger_overview.tooltip_text=trigger_overview.text
 for who in range(2):player_buttons[who].text=("我方" if who==0 else "对方")+"生命 "+str(recorder.adapter.engine.players[who].life)
 phase_label.text="阶段 · "+Graph.PHASE_NAMES.get(recorder.adapter.engine.phase,recorder.adapter.engine.phase)
