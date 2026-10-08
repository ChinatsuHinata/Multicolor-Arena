extends VBoxContainer
## Scene rules are presented as readable, ordered cards in a private draft.
const Graph=preload("res://scripts/tutorial/condition_graph.gd")
const EVENT_NAMES={"command_accepted":"操作完成后","state_changed":"状态改变后","phase_changed":"阶段改变后","priority_changed":"执行权改变后","step_entered":"进入教程步骤时","ui_action_accepted":"界面操作完成后"}
var editor
var value: Dictionary={}
var alias_scene: Dictionary={}

static func response_caption(rule: Dictionary) -> String:
 if rule.has("sequence"):
  return "按录制顺序执行 %d 个动作" % rule.sequence.get("actions",[]).size()
 var action=rule.get("action","pass_priority")
 if action is String:return "让过执行权"
 match action.get("type"):
  "block":return "按优先级选择阻挡单位" if action.has("priorities") else "不阻挡" if action.get("cards",[]).is_empty() else "用指定的 %d 个单位阻挡" % action.cards.size()
  "cast":return "使用指定手牌"
  "ability":return "启动指定异能"
 return "让过执行权"

func _ready():
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",12)
 rebuild()

func rebuild():
 editor.host.free_children(self)
 var automatic=editor.flag(self,"自动响应（无可用触发规则时）",value.get("auto_response",true),func(enabled):value.auto_response=enabled;rebuild())
 automatic.name="TutorialAutomaticResponse"
 editor.text(self,"先执行触发规则；自动让过执行权，未指定阻挡时不阻挡，并完成对方待选操作。")
 if value.rules.is_empty():
  editor.text(self,"尚无触发器，对手会自动响应。" if value.get("auto_response",true) else "尚无触发器，对手会等待。新增一条规则，设置触发时机和响应。")
  editor.action(self,"条件编辑器／录制触发",func():editor.open_rule_graph(-1,value,alias_scene)).name="OpenTriggerConditionGraph"
 else:
  editor.text(self,"从上到下检查规则；同一时机优先执行排在前面的可用响应。")
 for i in range(value.rules.size()):
  var rule=value.rules[i]
  var panel=PanelContainer.new();add_child(panel);panel.add_theme_stylebox_override("panel",editor.host.ui_metrics.panel_style())
  var body=VBoxContainer.new();panel.add_child(body);body.add_theme_constant_override("separation",6)
  editor.text(body,"%d. %s · 最多执行 %d 次" % [i+1,rule.id,rule.max_times]).add_theme_color_override("font_color",editor.host.GOLD)
  editor.text(body,"当「%s」，且「%s」" % [EVENT_NAMES.get(rule.event,rule.event),Graph.describe(rule.when,editor.host.Store.CARDS)])
  if rule.has("on_action"):
   var action=rule.on_action
   editor.text(body,"限定操作："+("我方" if int(action.get("player",0))==0 else "对方")+" · "+preload("res://scripts/tutorial/battle_commands.gd").LABELS.get(action.type,action.type))
  editor.text(body,"对方 → "+response_caption(rule))
  var row=HBoxContainer.new();body.add_child(row)
  editor.action(row,"编辑条件与响应",func():editor.open_rule_graph(i,value,alias_scene)).name="OpenTriggerConditionGraph" if i==0 else "EditTrigger_"+rule.id
  editor.action(row,"复制",func():
   var copy=rule.duplicate(true);var used={}
   for item in value.rules:used[item.id]=true
   copy.id=editor.model.unique_id("trigger_",used);value.rules.insert(i+1,copy);rebuild()).name="CopyTrigger_"+rule.id
  editor.action(row,"↑",func():move_rule(i,-1)).disabled=i==0
  editor.action(row,"↓",func():move_rule(i,1)).disabled=i==value.rules.size()-1
  editor.action(row,"删除",func():value.rules.remove_at(i);value.strategy="paused" if value.rules.is_empty() else "rules";rebuild()).name="DeleteTrigger_"+rule.id
 editor.action(self,"新增触发器",func():editor.open_rule_graph(-1,value,alias_scene)).name="AddTutorialTrigger"

func move_rule(index: int,direction: int):
 var rule=value.rules.pop_at(index);value.rules.insert(index+direction,rule);rebuild()
