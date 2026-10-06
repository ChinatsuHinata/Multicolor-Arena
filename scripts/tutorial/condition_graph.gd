extends Control
## A tree of real engine predicates, drawn as draggable connected nodes.
signal edited(value: Dictionary)
signal focused(value: Dictionary)
const TYPES={"always":"始终成立","all":"全部满足 AND","any":"任一满足 OR","not":"取反 NOT","life":"生命值","entity_zone":"卡牌所在区域","entity_state":"卡牌横置／攻击","entity_color_counter":"卡牌颜色指示物","entity_count":"卡牌伤害／计数","zone_count":"区域卡牌数量","combat_attacker":"指定攻击者","combat_step":"战斗响应时点","phase":"对局阶段","priority":"执行权","pending":"等待玩家选择","player_count":"玩家计数","deck_count":"卡组张数","steps_completed":"已完成步骤"}
const PHASE_NAMES={"prepare":"准备","main":"主要","end":"结束","reset":"重置","draw":"抓牌","possession":"凭依","over":"结束对局","mulligan":"起手调度"}
const COMBAT_NAMES={"none":"没有战斗","attack_window":"攻击响应","block_window":"阻挡响应","first_damage_window":"先制伤害响应","damage_window":"伤害响应"}
var condition: Dictionary={"type":"always"}
var aliases: Array=[]
var steps: Array=[]
var graph: GraphEdit
var positions: Dictionary={}
var row=0
var selected_condition: Dictionary={}
var selected_node: GraphNode
var alias_names: Dictionary={}
var created_names: Dictionary={}
var allowed_types: Array=[]

static func subject_name(c: Dictionary) -> String:
 return "生成实例 #"+str(int(c.created)) if c.has("created") else str(c.get("alias",""))

static func describe(c: Dictionary,cards: Dictionary={}) -> String:
 var op={"eq":" = ","le":" ≤ ","ge":" ≥ "}.get(c.get("op","eq")," = ")
 var side="我方" if int(c.get("player",0))==0 else "敌方"
 var card_name=str(cards.get(c.get("card_id",""),{}).get("name",c.get("card_id","卡牌")))
 var zones={"deck":"牌库","hand":"手牌","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外","leader":"自机区","stack":"堆叠"}
 match c.get("type"):
  "always":return "始终满足"
  "all","any":return (" 且 " if c.type=="all" else " 或 ").join(c.get("conditions",[]).map(func(item):return "（"+describe(item,cards)+"）"))
  "not":return "不满足（"+describe(c.get("condition",{}),cards)+"）"
  "life":return side+"生命"+op+str(int(c.get("value",0)))
  "entity_zone":return subject_name(c)+" 位于"+zones.get(c.get("zone"),str(c.get("zone","")))
  "entity_state":return subject_name(c)+" "+("横置" if c.get("key")=="tapped" else "已攻击")+"："+("是" if c.get("value",false) else "否")
  "entity_color_counter":return subject_name(c)+" 有"+c.get("color","")+"色指示物"
  "entity_count":return subject_name(c)+" 的"+str(c.get("key","计数"))+op+str(int(c.get("value",0)))
  "zone_count":return side+zones.get(c.get("zone"),"区域")+"中"+(card_name if c.has("card_id") else c.get("kind","卡牌"))+"数量"+op+str(int(c.get("value",0)))
  "deck_count":return {"main":"主卡组","side":"副卡组","leader":"自机"}.get(c.get("zone"),"卡组")+"中"+card_name+"数量"+op+str(int(c.get("value",0)))
  "ui_action":return preload("res://scripts/tutorial/ui_actions.gd").caption(c.get("action",{}),cards)
  "priority":return ("我方" if int(c.get("value",0))==0 else "对方")+"拥有执行权"
  "phase":return "当前阶段："+PHASE_NAMES.get(c.get("value"),str(c.get("value","")))
  "combat_step":return "战斗时点："+COMBAT_NAMES.get(c.get("value"),str(c.get("value","none")))
  "pending":return ("我方" if int(c.get("owner",0))==0 else "对方")+"正在选择："+str(c.get("kind",""))
  "combat_attacker":return subject_name(c)+"正在攻击"
  "player_count":return side+"的"+str(c.get("key","计数"))+op+str(c.get("value",0))
  _:return TYPES.get(c.get("type"),"未设置条件")

func _ready():
 if not get_parent() is Container:set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 graph=GraphEdit.new();graph.name="ConditionGraph";add_child(graph);graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 graph.minimap_enabled=false
 rebuild()

func changed(c: Dictionary={}):
 if not c.is_empty():select_condition(c)
 edited.emit(condition.duplicate(true))

func select_condition(c: Dictionary,node: GraphNode=null):
 selected_condition=c
 if node!=null:selected_node=node
 else:
  for child in graph.get_children():
   if child is GraphNode and is_same(child.get_meta("condition",{}),c):selected_node=child;break
 for child in graph.get_children():
  if child is GraphNode:child.selected=is_same(child.get_meta("condition",{}),c)
 focused.emit(c)

func replace_selected(value: Dictionary):
 var target=condition if selected_condition.is_empty() else selected_condition
 target.clear();target.merge(value.duplicate(true));changed(target);rebuild()

func rebuild():
 if graph==null:return
 for child in graph.get_children():
  if child is GraphNode:
   positions[str(child.name)]=child.position_offset;graph.remove_child(child);child.queue_free()
 graph.clear_connections();row=0
 build_node(condition,"root",0,Callable())
 if selected_condition.is_empty():select_condition(condition,graph.get_node("root"))
 else:select_condition(selected_condition)

func default_condition(kind: String) -> Dictionary:
 var alias=aliases[0] if not aliases.is_empty() else "选择卡牌别名"
 match kind:
  "all","any":return {"type":kind,"conditions":[{"type":"always"}]}
  "not":return {"type":kind,"condition":{"type":"always"}}
  "life":return {"type":kind,"player":1,"op":"le","value":0}
  "entity_zone":return {"type":kind,"alias":alias,"zone":"grave"}
  "entity_state":return {"type":kind,"alias":alias,"key":"tapped","value":true}
  "entity_color_counter":return {"type":kind,"alias":alias,"color":"红"}
  "entity_count":return {"type":kind,"alias":alias,"key":"damage","op":"ge","value":1}
  "zone_count":return {"type":kind,"player":1,"zone":"field","kind":"单位","op":"le","value":0}
  "combat_attacker":return {"type":kind,"alias":alias}
  "combat_step":return {"type":kind,"value":"attack_window"}
  "phase":return {"type":kind,"value":"main"}
  "priority":return {"type":kind,"value":0}
  "pending":return {"type":kind,"owner":0,"kind":"block"}
  "player_count":return {"type":kind,"player":0,"key":"turns","op":"ge","value":1}
  "deck_count":return {"type":kind,"zone":"main","op":"ge","value":1}
  "steps_completed":return {"type":kind,"steps":[steps[0]] if not steps.is_empty() else []}
 return {"type":"always"}

func option(parent: Node,c: Dictionary,key: String,values: Array,labels: Array=[]):
 var control=OptionButton.new();parent.add_child(control)
 for i in range(values.size()):control.add_item(str(values[i]) if labels.is_empty() else str(labels[i]))
 control.select(maxi(0,values.find(c.get(key))))
 control.item_selected.connect(func(index):c[key]=values[index];changed(c))
 return control

func card_subject(parent: Node,c: Dictionary):
 var source=OptionButton.new();source.name="ConditionCardSource";parent.add_child(source)
 source.add_item("初始场景卡牌");source.add_item("中途生成实例");source.select(1 if c.has("created") else 0)
 source.item_selected.connect(func(index):
  c.erase("alias");c.erase("created")
  if index==0:c.alias=aliases[0] if not aliases.is_empty() else "选择卡牌别名"
  else:c.created=int(created_names.keys()[0]) if not created_names.is_empty() else 0
  changed(c);rebuild())
 if c.has("alias"):
  var values=aliases.duplicate()
  if c.alias not in values:values.append(c.alias)
  option(parent,c,"alias",values,values.map(func(alias):return alias_names.get(alias,alias)))
 else:
  var values=created_names.keys()
  if int(c.created) not in values:values.append(int(c.created))
  option(parent,c,"created",values,values.map(func(index):return created_names.get(index,"尚未生成 · 生成实例 #"+str(index))))
  var hint=Label.new();parent.add_child(hint);hint.text="录制生成过程后，点选战场或底部实例。";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func build_node(c: Dictionary,id: String,depth: int,remove: Callable) -> GraphNode:
 var node=GraphNode.new();node.name=id;node.title=TYPES.get(c.get("type"),str(c.get("type")));graph.add_child(node)
 node.set_meta("condition",c)
 node.gui_input.connect(func(event):
  if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:select_condition(c,node))
 node.custom_minimum_size=Vector2(260,0)
 node.position_offset=positions.get(id,Vector2(40+depth*320,64+row*290))
 if c.get("type") not in ["all","any","not"]:row+=1
 var panel=StyleBoxFlat.new();panel.bg_color=Color("#132938");panel.border_color=Color("#517287");panel.set_border_width_all(1);panel.set_corner_radius_all(8)
 node.add_theme_stylebox_override("panel",panel)
 var selected_panel=panel.duplicate();selected_panel.border_color=Color("#e8c77e");selected_panel.set_border_width_all(2);node.add_theme_stylebox_override("panel_selected",selected_panel)
 node.dragged.connect(func(_from,to):positions[id]=to)
 var focus=Button.new();node.add_child(focus);focus.text="定位此条件";focus.name="FocusCondition";focus.pressed.connect(func():select_condition(c,node);graph.scroll_offset=node.position_offset-Vector2(24,64))
 var predicate_types=TYPES.keys() if allowed_types.is_empty() else allowed_types
 if c.get("type") not in predicate_types:predicate_types=predicate_types.duplicate();predicate_types.append(c.type)
 var kind=option(node,c,"type",predicate_types,predicate_types.map(func(value):return TYPES.get(value,value)))
 kind.name="ConditionType"
 # Type changes replace only this predicate; surrounding groups stay intact.
 for connection in kind.item_selected.get_connections():kind.item_selected.disconnect(connection.callable)
 kind.item_selected.connect(func(index):
  var value=default_condition(predicate_types[index])
  if c.get("type") in preload("res://scripts/tutorial/config.gd").ENTITY_CONDITIONS and value.type in preload("res://scripts/tutorial/config.gd").ENTITY_CONDITIONS:
   value.erase("alias")
   if c.has("created"):value.created=c.created
   else:value.alias=c.get("alias","")
  c.clear();c.merge(value);changed(c);rebuild())
 var body=VBoxContainer.new();node.add_child(body)
 var type=c.get("type","always")
 if type in preload("res://scripts/tutorial/config.gd").ENTITY_CONDITIONS:card_subject(body,c)
 if c.has("player"):option(body,c,"player",[0,1],["我方","对方"])
 if type=="pending":
  option(body,c,"owner",[0,1],["我方选择","对方选择"])
  option(body,c,"kind",["possession","discard","block","damage_assignment","trigger_order","ward_order","trigger","leader_return","grave_replacement","effect_choice","timer"],["凭依","弃牌","阻挡","伤害分配","触发排序","守护排序","触发目标","自机回手","墓地替换","效果选择","时间指示物"])
 if type=="entity_zone":option(body,c,"zone",["deck","hand","field","palette","grave","exile","leader","stack"],["牌库","手牌","战场","颜色盘","墓地","除外","自机区","堆叠"])
 if type=="entity_state":
  option(body,c,"key",preload("res://scripts/tutorial/config.gd").CARD_FLAGS,["横置","已攻击"])
  option(body,c,"value",[true,false],["是","否"])
 if type=="entity_color_counter":option(body,c,"color",["红","蓝","绿","黄","黑"])
 if type=="entity_count":option(body,c,"key",preload("res://scripts/tutorial/config.gd").CARD_COUNTS)
 if type=="zone_count":
  option(body,c,"zone",["deck","hand","field","palette","grave","exile"],["牌库","手牌","战场","颜色盘","墓地","除外"])
  var types=["全部","单位","自机","道具","结界","符卡"]
  var choice=OptionButton.new();body.add_child(choice)
  for item in types:choice.add_item(item)
  choice.select(maxi(0,types.find(c.get("kind","全部"))))
  choice.item_selected.connect(func(index):
   if index==0:c.erase("kind")
   else:c.kind=types[index]
   changed())
  var card=LineEdit.new();body.add_child(card);card.placeholder_text="可选：仅统计卡牌 ID";card.text=c.get("card_id","")
  card.text_changed.connect(func(value):
   if value.is_empty():c.erase("card_id")
   else:c.card_id=value
   changed())
 if type=="phase":option(body,c,"value",["prepare","main","end","reset","draw","possession","over","mulligan"],["准备","主要","结束","重置","抓牌","凭依","结束对局","起手调度"])
 if type=="combat_step":option(body,c,"value",["none","attack_window","block_window","first_damage_window","damage_window"],["没有战斗","攻击响应","阻挡响应","先制伤害响应","伤害响应"])
 if type=="priority":option(body,c,"value",[0,1],["我方执行权","对方执行权"])
 if type=="player_count":option(body,c,"key",["turns","possession_count"],["自己的回合数","凭依次数"])
 if type=="deck_count":option(body,c,"zone",["main","side"],["主卡组","副卡组"])
 if type in ["life","player_count","deck_count","entity_count","zone_count"]:
  option(body,c,"op",["eq","le","ge"],["等于 =","小于等于 ≤","大于等于 ≥"])
  var value=SpinBox.new();body.add_child(value);value.min_value=-100000 if type=="life" else 0;value.max_value=100000;value.value=c.get("value",0)
  value.value_changed.connect(func(number):c.value=int(number);changed(c))
 if type=="steps_completed":
  for step in steps:
   var check=CheckButton.new();check.text=str(step);body.add_child(check);check.button_pressed=step in c.get("steps",[])
   check.toggled.connect(func(enabled):
    if enabled and not step in c.steps:c.steps.append(step)
    elif not enabled:c.steps.erase(step)
    changed())
 if type in ["all","any"]:
  var add=Button.new();add.text="＋ 添加子条件";body.add_child(add)
  add.pressed.connect(func():c.conditions.append({"type":"always"});changed();rebuild())
 if remove.is_valid():
  var button=Button.new();button.text="删除此条件";body.add_child(button)
  button.pressed.connect(func():remove.call();selected_condition={};changed();rebuild())
 node.set_slot(0,id!="root",0,Color("#75b9dc"),type in ["all","any","not"],0,Color("#e8c77e"))
 if type in ["all","any"]:
  for i in range(c.conditions.size()):
   var child_id=id+"_"+str(i)
   build_node(c.conditions[i],child_id,depth+1,func():
    c.conditions.remove_at(i)
    if c.conditions.is_empty():c.conditions.append({"type":"always"}))
   graph.connect_node(id,0,child_id,0)
 elif type=="not":
  build_node(c.condition,id+"_not",depth+1,Callable());graph.connect_node(id,0,id+"_not",0)
 return node
