extends VBoxContainer
## Lossless graphical editing for all existing schema fields, including nested
## sequences, quizzes and opponent actions not covered by the short inspector.
var value: Variant
var root_path=""
const RECORD_LABELS={"sequence":"动作序列","on_action":"触发动作","payment":"支付来源","resource":"临时资源编号","created":"生成卡牌顺序","student":"学员行动方","advance_rng":"推进随机状态","grant_payment":"支付赠予费用"}
const RECORD_DEFAULTS={"on_action":{"type":"pass_priority","player":0},"payment":[],"resource":-100,"created":0,"student":0,"advance_rng":true,"grant_payment":false}
const LABELS={"type":"类型","text":"说明文字","scenario":"切换场景","scenario_mode":"场景切换方式","camera_view":"战场视角","open_zone":"打开区域","guide":"教学指引","sequence":"固定演示","actions":"动作序列","random_results":"预设随机结果","on_action":"触发动作","payment":"支付来源","resource":"临时资源编号","created":"生成卡牌顺序","student":"学员行动方","advance_rng":"推进随机状态","grant_payment":"支付赠予费用","task":"任务设置","success":"成功条件","failure":"失败条件／跳转","timing":"判定时点","action":"所需操作","allowed_actions":"允许的组卡操作","quiz":"答题设置","answers":"答案选项","correct_answer":"正确答案 ID","required_aliases":"调度牌别名","required_choice":"指定颜色选择","allow_turn_end":"允许结束回合","wait_event":"等待事件","next":"成功后前往","restore_on_failure":"失败时恢复","targets":"高亮目标","popup":"指引显示方式","next_button":"推进按钮","layout":"指引布局","focus":"展示卡牌","alias":"卡牌别名","card_id":"卡牌定义 ID","component":"界面组件","player":"操作方","zone":"区域","index":"序号","owner":"所属玩家","kind":"选择类型","key":"属性／能力键","op":"比较关系","value":"数值／状态","color":"颜色","conditions":"子条件","condition":"被取反条件","steps":"步骤 ID","name":"名称","life":"生命值","leader":"套牌自机","leader_on_field":"自机已在战场","deck_order":"剩余牌库（顶→底）","hand":"手牌","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外","state":"预置状态","position":"战场顺序","token_value":"青蛙攻击／血量","token_spirit":"青蛙灵力","token_name":"衍生物名称","seed":"随机种子","first":"先手","turn":"总回合","phase":"阶段","active":"当前回合方","priority":"执行权","players":"双方局面","deck":"教学卡组","screen":"游戏内功能","components":"界面组件策略","opponent":"对手控制","strategy":"对手策略","rules":"响应规则","event":"响应事件","when":"响应条件","max_times":"执行次数上限","card":"操作卡牌","source":"能力来源","target":"操作目标","cards":"所选卡牌","yes":"是否同意","amount":"伤害量","assignments":"伤害分配","seconds":"等待秒数","main":"主卡组","side":"副卡组","rule_set":"构筑规则","tapped":"横置","attacked":"已攻击","damage":"已受伤害","timer":"时间指示物","entered":"入场总回合","entered_turns":"入场时自己的回合","plus_counters":"＋指示物","minus_counters":"－指示物","poverty":"贫穷指示物","leader_counters":"自机指示物","courage":"英勇","color_counters":"颜色指示物","token_colors":"衍生物颜色","potato":"资源状态 potato","mulligan_done":"已完成调度","turns":"自己的回合数","possession_count":"凭依次数","visible":"显示","highlight":"高亮","enabled":"允许交互"}
const OPTIONS={"scenario_mode":["reset","resume"],"camera_view":["battlefield","own_palette","enemy_palette"],"popup":["show","hidden"],"next_button":["manual","auto","hidden"],"layout":["modal","side"],"timing":["enter","state_changed","event","action","answer","mulligan_selection"],"phase":["prepare","main","end","reset","draw","possession","over","mulligan"],"op":["eq","le","ge"],"strategy":["paused","rules"],"color":["红","蓝","绿","黄","黑"],"event":["state_changed","phase_changed","priority_changed","command_accepted","step_entered","ui_action_accepted"],"wait_event":["state_changed","phase_changed","priority_changed","command_accepted","step_entered","ui_action_accepted"]}
const DEFAULTS={"alias":"new_entity","state":{},"position":0,"tapped":false,"attacked":false,"damage":0,"timer":0,"entered":0,"entered_turns":0,"plus_counters":0,"minus_counters":0,"poverty":0,"leader_counters":0,"courage":0,"color_counters":[],"token_colors":[],"seed":42,"first":0,"turn":1,"phase":"main","active":0,"priority":0,"components":{},"opponent":{"strategy":"paused"},"field":[],"hand":[],"palette":[],"grave":[],"exile":[],"leader_on_field":false,"potato":false,"mulligan_done":true,"turns":1,"possession_count":0,"visible":true,"highlight":false,"enabled":true,"next":"$complete","failure":"$complete","restore_on_failure":true,"camera_view":"battlefield","popup":"show","next_button":"manual","layout":"side","targets":[],"focus":{"alias":"new_entity"},"open_zone":{"player":0,"zone":"grave"},"sequence":{"actions":[{"type":"pass_priority","player":0}]},"random_results":[],"required_choice":{"effect":"lily_color","color":"红"},"allowed_actions":[],"required_aliases":[],"allow_turn_end":true,"wait_event":"state_changed","max_times":1,"when":{"type":"priority","value":1},"event":"state_changed","target":{"player":1},"cards":[],"source":{"alias":"new_entity"},"card":{"alias":"new_entity"},"index":0,"key":"ability_key","player":0,"token_value":2,"token_spirit":2,"token_name":"青蛙衍生物","quiz":{"answers":[{"id":"a","text":"选项 A"},{"id":"b","text":"选项 B"}],"correct_answer":"a"}}

func _ready():
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 rebuild()

func button(parent: Node,caption: String,callback: Callable):
 var control=Button.new();parent.add_child(control);control.text=caption;control.pressed.connect(callback)
 return control

func rebuild():
 for child in get_children():remove_child(child);child.queue_free()
 build(self,value,root_path,0)

func build(parent: Node,data: Variant,path: String,depth: int):
 if depth>24:return
 if data is Dictionary:
  for key in data.keys():
   entry(parent,data,key,path+"."+str(key),depth)
  var tools=HBoxContainer.new();parent.add_child(tools)
  var field=LineEdit.new();tools.add_child(field);field.placeholder_text="添加字段名";field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button(tools,"＋ 字段",func():
   var key=field.text.strip_edges()
   if key.is_empty() or data.has(key):return
   var initial=RECORD_DEFAULTS.get(key,DEFAULTS.get(key,""))
   data[key]=initial.duplicate(true) if initial is Dictionary or initial is Array else initial
   rebuild())
 elif data is Array:
  for i in range(data.size()):entry(parent,data,i,path+"."+str(i),depth)
  button(parent,"＋ 添加项",func():
   var key=path.get_slice(".",path.get_slice_count(".")-1)
   if not data.is_empty():data.append(data.back().duplicate(true) if data.back() is Dictionary or data.back() is Array else data.back())
   elif key=="actions":data.append({"type":"pass_priority","player":0})
   elif key=="rules":data.append({"id":"rule_1","event":"state_changed","when":{"type":"priority","value":1},"action":"pass_priority","max_times":1})
   elif key=="random_results":data.append({"type":"coin","value":0})
   elif key=="payment":data.append({"card":{"alias":"new_entity"},"color":"红"})
   elif key in ["field","hand","palette","grave","exile","deck_order"]:data.append({"card_id":"53"})
   elif key=="targets":data.append({"player":1})
   else:data.append("")
   rebuild())

func entry(parent: Node,data: Variant,key: Variant,path: String,depth: int):
 var current=data[key]
 var caption=RECORD_LABELS.get(str(key),LABELS.get(str(key),str(key))) if data is Dictionary else "第 %d 项" % (int(key)+1)
 if current is Dictionary or current is Array:
  var header=HBoxContainer.new();parent.add_child(header)
  var section=VBoxContainer.new();parent.add_child(section)
  var toggle=button(header,caption+"  ▸",func():section.visible=not section.visible)
  toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button(header,"删除",func():erase(data,key))
  if data is Array:
   button(header,"↑",func():var item=data.pop_at(int(key));data.insert(int(key)-1,item);rebuild()).disabled=int(key)==0
   button(header,"↓",func():var item=data.pop_at(int(key));data.insert(int(key)+1,item);rebuild()).disabled=int(key)==data.size()-1
  var indent=MarginContainer.new();section.add_child(indent);indent.add_theme_constant_override("margin_left",18)
  var fields=VBoxContainer.new();indent.add_child(fields)
  build(fields,current,path,depth+1);section.visible=false
  return
 var row=HBoxContainer.new();parent.add_child(row)
 var label=Label.new();row.add_child(label);label.text=caption;label.custom_minimum_size.x=200
 var control: Control
 if current is bool:
  var checkbox=CheckButton.new();row.add_child(checkbox);checkbox.button_pressed=current
  checkbox.toggled.connect(func(number):data[key]=number);control=checkbox
 elif current is int or current is float:
  var number=SpinBox.new();row.add_child(number);number.min_value=-1000000;number.max_value=1000000000;number.allow_greater=true;number.allow_lesser=true;number.step=0 if float(current)!=floor(float(current)) else 1;number.value=current
  number.value_changed.connect(func(value):data[key]=int(value) if current is int else value);control=number
 elif current is String and OPTIONS.has(str(key)):
  var options=OPTIONS[str(key)].duplicate()
  if not current in options:options.append(current)
  var choice=OptionButton.new();row.add_child(choice)
  for item in options:choice.add_item(item)
  choice.select(options.find(current));choice.item_selected.connect(func(index):data[key]=options[index]);control=choice
 else:
  var input=TextEdit.new();row.add_child(input);input.text=str(current);input.custom_minimum_size.y=100 if str(key)=="text" else 42;input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
  input.text_changed.connect(func():data[key]=input.text);control=input
 control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button(row,"×",func():erase(data,key))

func erase(data: Variant,key: Variant):
 if data is Dictionary:data.erase(key)
 else:data.remove_at(int(key))
 rebuild()
