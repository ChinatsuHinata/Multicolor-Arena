extends VBoxContainer
const Series=preload("res://net/series_controller.gd")
const KINDS={"swiss":"瑞士轮","single_elimination":"单败淘汰","double_elimination":"双败淘汰","round_robin":"循环赛"}
var app
var stages: Array=[]
var fields: Array=[]
var locked_through=-1

func begin(host,data: Array,current_index: int=-1):
 app=host;stages=data.duplicate(true);locked_through=current_index
 if stages.is_empty():stages.append(default_stage())
 rebuild()

func default_stage() -> Dictionary:
 return {"name":"第 %d 阶段" % (stages.size()+1),"kind":"swiss","game_format":3,"rounds":0,"points":{"win":3,"draw":1,"loss":0,"bye":3,"scores":{}},"advance":{"mode":"all","count":2,"points":6,"early":false,"eliminate_losses":0}}

func label_text(parent: Node,caption: String):
 var label=Label.new();parent.add_child(label);label.text=caption;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",app.ui_metrics.small)

func spin(parent: Node,caption: String,value: int,limit: int=10000) -> SpinBox:
 var row=HBoxContainer.new();parent.add_child(row);label_text(row,caption)
 var control=SpinBox.new();row.add_child(control);control.max_value=limit;control.value=value;control.custom_minimum_size.y=app.ui_metrics.hit
 control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 return control

func choice(parent: Node,caption: String,options: Dictionary,selected: String) -> OptionButton:
 label_text(parent,caption)
 var control=OptionButton.new();parent.add_child(control)
 for key in options:
  control.add_item(options[key]);control.set_item_metadata(control.item_count-1,key)
 control.select(maxi(0,options.keys().find(selected)));app.ui_metrics.button(control)
 return control

func rebuild():
 for child in get_children():remove_child(child);child.queue_free()
 fields=[]
 for index in range(stages.size()):
  var stage=stages[index];var locked=index<=locked_through
  var panel=PanelContainer.new();add_child(panel);panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
  var column=VBoxContainer.new();panel.add_child(column)
  var title=LineEdit.new();column.add_child(title);title.text=stage.name;title.max_length=40;title.custom_minimum_size.y=app.ui_metrics.hit
  var kind=choice(column,"阶段赛制",KINDS,stage.kind)
  var games={}
  for format_value in [Series.BO1,Series.BO1_SIDEBOARD,Series.BO2,Series.BO3,Series.BO5,Series.EXPLORATION,Series.EXPLORATION_RANDOM]:games[str(format_value)]=Series.format_label(format_value)
  var game=choice(column,"本阶段局制",games,str(int(stage.game_format)))
  var rounds=spin(column,"瑞士轮轮数（0 自动；循环赛自动全循环）",int(stage.rounds),127)
  var point_fields={}
  for key in ["win","draw","loss","bye"]:point_fields[key]=spin(column,{"win":"胜分","draw":"平分","loss":"负分","bye":"轮空分"}[key],int(stage.points.get(key,0)))
  label_text(column,"按本方大比分给分（可留空）；例如 2:0=3,2:1=2,1:2=1,0:2=0；未设置的比分使用胜平负分")
  var scores=LineEdit.new();column.add_child(scores);scores.custom_minimum_size.y=app.ui_metrics.hit
  var score_entries=[]
  for key in stage.points.get("scores",{}):score_entries.append(str(key)+"="+str(int(stage.points.scores[key])))
  scores.text=",".join(score_entries);scores.placeholder_text="2:0=3,2:1=2,1:2=1,0:2=0"
  var advance=choice(column,"进入下一阶段的条件",{"all":"所有未淘汰选手（淘汰赛仅胜者）","rank":"按本阶段排名","points":"按本阶段积分达标"},stage.advance.mode)
  var count=spin(column,"按排名：晋级人数",int(stage.advance.get("count",2)),128);count.min_value=1
  var threshold=spin(column,"按积分：最低晋级分数",int(stage.advance.get("points",6)),1000000)
  var early=CheckButton.new();column.add_child(early);early.text="提前晋级 / 提前淘汰";early.button_pressed=stage.advance.get("early",false);app.ui_metrics.button(early)
  var losses=spin(column,"提前淘汰：累计负场（0 关闭）",int(stage.advance.get("eliminate_losses",0)),127)
  label_text(column,"启用后，达到晋级分数即停止参赛；剩余轮次全取最高分仍不能达标则提前淘汰。各阶段积分独立计算。末阶段按成绩发奖。")
  for control in [kind,game]:control.disabled=locked;control.set_meta("page_disabled",locked)
  for control in [rounds,point_fields.win,point_fields.draw,point_fields.loss,point_fields.bye]:control.editable=not locked
  scores.editable=not locked
  if index<locked_through:
   advance.disabled=true;count.editable=false;threshold.editable=false;early.disabled=true;losses.editable=false;title.editable=false
   advance.set_meta("page_disabled",true);early.set_meta("page_disabled",true)
  var controls=HFlowContainer.new();column.add_child(controls)
  if index>locked_through:
   var remove=app.button(controls,"删除阶段",Rect2(),func():if capture():stages.remove_at(index);rebuild())
   app.ui_metrics.button(remove);remove.disabled=stages.size()==1
   remove.set_meta("page_disabled",stages.size()==1)
   if index>locked_through+1:
    var up=app.button(controls,"上移阶段",Rect2(),func():
     if capture():var previous=stages[index-1];stages[index-1]=stages[index];stages[index]=previous;rebuild())
    app.ui_metrics.button(up)
  fields.append({"title":title,"kind":kind,"game":game,"rounds":rounds,"points":point_fields,"scores":scores,"advance":advance,"count":count,"threshold":threshold,"early":early,"losses":losses})
 var add=app.button(self,"＋ 添加下一阶段",Rect2(),func():if capture():stages.append(default_stage());rebuild())
 app.ui_metrics.button(add);add.disabled=stages.size()>=12
 add.set_meta("page_disabled",stages.size()>=12)
 relayout()

func relayout():
 add_theme_constant_override("separation",int(app.ui_metrics.gap))
 for box in find_children("*","BoxContainer",true,false):box.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 for panel in find_children("*","PanelContainer",true,false):panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 for label in find_children("*","Label",true,false):label.add_theme_font_size_override("font_size",app.ui_metrics.small)
 for control in find_children("*","SpinBox",true,false):control.custom_minimum_size.y=app.ui_metrics.hit
 for field in fields:
  field.title.custom_minimum_size.y=app.ui_metrics.hit;field.scores.custom_minimum_size.y=app.ui_metrics.hit
 for button in find_children("*","Button",true,false):app.ui_metrics.button(button)

func capture() -> bool:
 var result=[]
 for field in fields:
  var points={"scores":{}}
  for key in field.points:points[key]=int(field.points[key].value)
  for term in field.scores.text.replace("，",",").split(",",false):
   var pair=term.strip_edges().split("=")
   if pair.size()!=2 or not pair[1].strip_edges().is_valid_int():app.alert("比分给分格式为 2:0=3,2:1=2","计分规则");return false
   points.scores[pair[0].strip_edges()]=int(pair[1])
  result.append({"name":field.title.text,"kind":field.kind.get_selected_metadata(),"game_format":int(field.game.get_selected_metadata()),"rounds":int(field.rounds.value),"points":points,"advance":{"mode":field.advance.get_selected_metadata(),"count":int(field.count.value),"points":int(field.threshold.value),"early":field.early.button_pressed,"eliminate_losses":int(field.losses.value)}})
 stages=result;return true
