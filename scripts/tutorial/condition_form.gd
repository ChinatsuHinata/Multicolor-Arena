extends VBoxContainer
## Compact task predicates. No graph layout or arbitrary configuration fields.
const Graph=preload("res://scripts/tutorial/condition_graph.gd")
const Actions=preload("res://scripts/tutorial/ui_actions.gd")
var condition: Dictionary={"type":"always"}
var aliases: Array=[]
var steps: Array=[]
var cards: Dictionary={}
var scene_type="battlefield"
var allowed_types: Array=[]

func _ready():
 rebuild()

func choice(parent: Node,values: Array,current: Variant,callback: Callable,labels: Array=[]) -> OptionButton:
 var input=OptionButton.new();parent.add_child(input)
 for i in range(values.size()):input.add_item(str(values[i]) if labels.is_empty() else str(labels[i]))
 input.select(maxi(0,values.find(current)));input.item_selected.connect(func(i):callback.call(values[i]))
 return input

func label(parent: Node,value: String):
 var output=Label.new();parent.add_child(output);output.text=value;output.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func card_picker(parent: Node,c: Dictionary):
 var search=LineEdit.new();parent.add_child(search);search.placeholder_text="搜索卡名或 ID（留空统计全部卡牌）"
 var select=OptionButton.new();parent.add_child(select)
 var rebuild_cards=func(query):
  select.clear();select.add_item("全部卡牌");select.set_item_metadata(0,"")
  for id in cards:
   if query.is_empty() or query.to_lower() in (str(id)+" "+str(cards[id].name)).to_lower() or id==c.get("card_id"):
    select.add_item(cards[id].name+" · "+id);select.set_item_metadata(select.item_count-1,id)
    if id==c.get("card_id"):select.select(select.item_count-1)
 search.text_changed.connect(rebuild_cards);rebuild_cards.call("")
 select.item_selected.connect(func(i):
  var id=select.get_item_metadata(i)
  if id=="":c.erase("card_id")
  else:c.card_id=id)

func rebuild():
 for child in get_children():remove_child(child);child.queue_free()
 build(self,condition)

func build(parent: Node,c: Dictionary,depth: int=0):
 var kinds=["always","all","any","not","life","entity_zone","entity_state","entity_color_counter","entity_count","zone_count","combat_attacker","combat_attacker_rank","combat_step","phase","priority","pending","player_count","steps_completed"] if scene_type=="battlefield" else ["always","all","any","not","deck_count","ui_action","steps_completed"]
 if not allowed_types.is_empty():kinds=allowed_types.duplicate()
 if c.type not in kinds:kinds.append(c.type)
 var names=kinds.map(func(kind):return {"ui_action":"完成指定操作"}.get(kind,Graph.TYPES.get(kind,kind)))
 choice(parent,kinds,c.type,func(kind):
  var factory=Graph.new();factory.aliases=aliases;factory.steps=steps
  var value=factory.default_condition(kind);factory.free()
  if c.type in preload("res://scripts/tutorial/config.gd").ENTITY_CONDITIONS and kind in preload("res://scripts/tutorial/config.gd").ENTITY_CONDITIONS:
   value.erase("alias")
   if c.has("created"):value.created=c.created
   else:value.alias=c.get("alias","")
  if kind=="ui_action":value={"type":kind,"action":{"id":"editor.inspect"}}
  c.clear();c.merge(value);rebuild(),names)
 if c.has("created"):
  label(parent,"生成实例编号（从 0 开始；相对于场景起点）")
  var number=SpinBox.new();parent.add_child(number);number.min_value=0;number.max_value=100000;number.value=int(c.created)
  number.value_changed.connect(func(value):c.created=int(value))
 for key in ["alias","player","zone","key","op","color","kind","owner"]:
  if not c.has(key):continue
  label(parent,{"alias":"场景卡牌","player":"玩家","zone":"区域","key":"属性","op":"比较方式","color":"颜色","kind":"卡牌类别／选择","owner":"选择方"}.get(key,key))
  var values=[];var labels=[]
  match key:
   "alias":values=aliases.duplicate()
   "player","owner":values=[0,1];labels=["我方","对方"]
   "zone":
    values=["main","side","leader"] if c.type=="deck_count" else ["deck","hand","field","palette","grave","exile","leader","stack"]
    labels=values.map(func(zone):return {"main":"主卡组","side":"副卡组","leader":"自机","deck":"牌库","hand":"手牌","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外","stack":"堆叠"}.get(zone,zone))
   "key":
    values=["tapped","attacked"] if c.type=="entity_state" else ["turns","possession_count"] if c.type=="player_count" else Graph.RANK_STATS.keys() if c.type=="combat_attacker_rank" else preload("res://scripts/tutorial/config.gd").CARD_COUNTS
    if c.type=="combat_attacker_rank":labels=Graph.RANK_STATS.values()
   "op":values=["eq","le","ge"];labels=["等于","小于等于","大于等于"]
   "color":values=["红","蓝","绿","黄","黑"]
   "kind":values=["possession","discard","block","damage_assignment","trigger_order","ward_order","trigger","leader_return","grave_replacement","effect_choice","timer"] if c.type=="pending" else ["单位","自机","道具","结界","符卡"]
  if c[key] not in values:values.append(c[key]);labels=[]
  choice(parent,values,c[key],func(value):c[key]=value,labels)
 if c.type=="combat_attacker_rank":
  label(parent,"排名范围")
  choice(parent,["fixed",0,1],int(c.count_player) if c.has("count_player") else "fixed",func(value):
   c.erase("count");c.erase("count_player")
   if value is String:c.count=1
   else:c.count_player=value
   rebuild(),["固定前 N 名","前 x 名：x = 我方场上单位数","前 x 名：x = 对方场上单位数"]).name="AttackRankCountSource"
  if c.has("count"):
   var count=SpinBox.new();count.name="AttackRankCount";parent.add_child(count);count.min_value=1;count.max_value=100000;count.value=c.count
   count.value_changed.connect(func(value):c.count=int(value))
  choice(parent,["all","field_order"],c.get("ties","field_order"),func(value):c.ties=value,["同值全部符合","同值按战场顺序取前 N 个"]).name="AttackRankTies"
 if c.type in ["deck_count","zone_count"]:card_picker(parent,c)
 if c.has("value"):
  label(parent,"目标值")
  if c.type=="entity_state":choice(parent,[true,false],c.value,func(value):c.value=value,["是","否"])
  elif c.type in ["phase","priority","combat_step"]:
   var values=[0,1] if c.type=="priority" else ["none","attack_window","block_window","first_damage_window","damage_window"] if c.type=="combat_step" else ["prepare","main","end","reset","draw","possession","over","mulligan"]
   choice(parent,values,c.value,func(value):c.value=value)
  else:
   var number=SpinBox.new();parent.add_child(number);number.min_value=-100000 if c.type=="life" else 0;number.max_value=100000;number.value=c.value
   number.value_changed.connect(func(value):c.value=int(value))
 if c.type=="ui_action":
  choice(parent,Actions.ALLOWED,c.action.id,func(value):c.action.id=value,Actions.ALLOWED.map(func(id):return Actions.LABELS[id]))
  if not c.action.has("args"):c.action.args={}
  card_picker(parent,c.action.args)
  choice(parent,["","main","side","leader"],c.action.args.get("zone",""),func(value):
   if value=="":c.action.args.erase("zone")
   else:c.action.args.zone=value,["任意区域","主卡组","副卡组","自机"])
  var value=LineEdit.new();parent.add_child(value);value.placeholder_text="可选：搜索内容／操作参数";value.text=str(c.action.args.get("value",""))
  value.text_changed.connect(func(input):
   if input.is_empty():c.action.args.erase("value")
   else:c.action.args.value=input)
 if c.type=="steps_completed":
  for id in steps:
   var check=CheckButton.new();parent.add_child(check);check.text=id;check.button_pressed=id in c.steps
   check.toggled.connect(func(enabled):
    if enabled and id not in c.steps:c.steps.append(id)
    elif not enabled:c.steps.erase(id))
 if c.type in ["all","any","not"] and depth<12:
  var children=[c.condition] if c.type=="not" else c.conditions
  for i in range(children.size()):
   var group=VBoxContainer.new();parent.add_child(group);label(group,"条件 "+str(i+1));build(group,children[i],depth+1)
   if c.type!="not" and children.size()>1:
    var remove=Button.new();group.add_child(remove);remove.text="删除条件";remove.pressed.connect(func():children.remove_at(i);rebuild())
  if c.type!="not":
   var add=Button.new();parent.add_child(add);add.text="添加条件";add.pressed.connect(func():children.append({"type":"always"});rebuild())
