extends RefCounted
const GROUPS=["能力词条","基础概念","能力种类"]
const ENTRIES=[
 {"id":"lifelink","term":"吸血X","group":"能力词条","definition":"当具有吸血的单位造成战斗伤害的伤害判定结束时，你获得X点生命。","patterns":["吸血"],"numbered":true,"link":true},
 {"id":"timer","term":"计时X","group":"能力词条","definition":"带有计时X的牌在进战场时带有X个计时指示物。（计时指示物：一种用于指示时间的指示物，会在每个自己的结束阶段结束时移除一个）","patterns":["计时"],"numbered":true,"link":true},
 {"id":"exorcise","term":"退治","group":"能力词条","definition":"非人类的单位不能阻挡具有退治的单位。","patterns":["退治"],"numbered":false,"link":true},
 {"id":"annihilate","term":"歼灭","group":"能力词条","definition":"在自己的主要阶段战斗中，具有歼灭的单位在伤害判定中消灭对方单位后，同时会对对方玩家造成等同于其灵力值的战斗伤害。","patterns":["歼灭"],"numbered":false,"link":true},
 {"id":"miracle","term":"奇迹","group":"能力词条","definition":"当玩家在抽牌阶段抽的第一张牌为具有奇迹能力的牌时，那个玩家可以展示它，若如此做，你可以立即使用它，且不需要支付卡牌颜色值。","patterns":["奇迹"],"numbered":false,"link":true},
 {"id":"haste","term":"疾行","group":"能力词条","definition":"具有疾行的单位可以在进入战场的自己回合进行攻击。","patterns":["疾行"],"numbered":false,"link":true},
 {"id":"valor","term":"英勇","group":"能力词条","definition":"具有英勇的单位在攻击后的结束阶段开始时重置。","patterns":["英勇"],"numbered":false,"link":true},
 {"id":"first","term":"先制","group":"能力词条","definition":"具有先制的单位，在战斗伤害结算时，会优先对单位造成战斗伤害，如果该伤害造成那个单位死去，则前者不会受到来自后者的战斗伤害。","patterns":["先制"],"numbered":false,"link":true},
 {"id":"last_word","term":"终言","group":"能力词条","definition":"具有终言的符卡在构筑卡组时，它及其同名卡只能放入一张。","patterns":["终言"],"numbered":false,"link":true},
 {"id":"prismatic","term":"极彩","group":"能力词条","definition":"具有极彩的牌在使用时，可以使用任意颜色值支付。","patterns":["极彩"],"numbered":false,"link":true},
 {"id":"menace","term":"威吓","group":"能力词条","definition":"具有威吓的单位攻击时，对方需要至少两个单位才能阻挡之。","patterns":["威吓"],"numbered":false,"link":true},
 {"id":"crystal","term":"结晶","group":"能力词条","definition":"具有结晶的单位从战场送去墓地时，可以发动的能力，将那个单位竖置替换一张自己颜色盘中的已横置的牌，且将那张已横置的牌送去墓地。","patterns":["结晶"],"numbered":false,"link":true},
 {"id":"counter","term":"反制","group":"能力词条","definition":"使对抗中的牌的使用或能力无效。若牌的使用被反制，则那张牌进入墓地。","patterns":["反制"],"numbered":false,"link":true},
 {"id":"pursuit","term":"追击","group":"能力词条","definition":"当具有追击的单位在你的回合第一次造成战斗伤害时，重置该单位。","patterns":["追击"],"numbered":false,"link":true},
 {"id":"ward","term":"防避X","group":"能力词条","definition":"具有防避X的单位在受到伤害时会防止其中的X点，并失去该能力。","patterns":["防避"],"numbered":true,"link":true},
 {"id":"restricted","term":"限制级符卡","group":"能力词条","definition":"限制级符卡和其同名牌在构筑时只能加入至多1张。","patterns":["限制级符卡","限制级"],"numbered":false,"link":true},
 {"id":"support","term":"支援","group":"能力词条","definition":"具有支援的角色符卡，在其对应的角色位于你的自机区中时也能使用。","patterns":["支援"],"numbered":false,"link":true},
 {"id":"permanent","term":"永久物","group":"基础概念","definition":"能持续存在于战场上的牌称之为“永久物”，包括但不限于（结界、道具、单位等）。","patterns":["永久物"],"numbered":false,"link":true},
 {"id":"ability","term":"能力","group":"基础概念","definition":"写在卡牌能力框内的文本为该牌的“能力”，分为规则类、基本类、启动类、触发类、静止类、代替类六种。","patterns":["能力"],"numbered":false,"link":false},
 {"id":"token","term":"衍生物","group":"基础概念","definition":"是指通过某种效应产生的特殊永久物，通常是从游戏外放进战场的，衍生物不管以何种方式离开战场后都会被改为移除游戏。（但它们离开战场的方式是不变的，依然会触发相应的效应。如死去时，离场时等）","patterns":["衍生物"],"numbered":false,"link":true},
 {"id":"copy","term":"复制","group":"基础概念","definition":"指的是创造某个或者一些永久物，能力，符卡，为某个或者某些目标的复制品。这些复制品的类型、颜色、原本能力、属性和其上的指示物均会被复制，表示形式无特殊说明均为竖置。永久物的复制通常会以衍生物的形式出现。","patterns":["复制"],"numbered":false,"link":true},
 {"id":"sacrifice","term":"牺牲","group":"基础概念","definition":"使你的某个/些永久物死去。通常作为使用能力的代价，处理时不可被响应，不进入对抗。（注：牺牲不是消灭）","patterns":["牺牲"],"numbered":false,"link":true},
 {"id":"rule_ability","term":"规则类能力","group":"能力种类","definition":"用于阐述卡牌使用条件或解除增加规则限制的能力。","patterns":["规则类能力"],"numbered":false,"link":true},
 {"id":"basic_ability","term":"基本类能力","group":"能力种类","definition":"一般是符卡结算时，直接产生的效果。","patterns":["基本类能力"],"numbered":false,"link":true},
 {"id":"activated_ability","term":"启动类能力","group":"能力种类","definition":"需要支付使用条件才能使用的能力。","patterns":["启动类能力"],"numbered":false,"link":true},
 {"id":"triggered_ability","term":"触发类能力","group":"能力种类","definition":"满足使用条件便可立即使用的能力。","patterns":["触发类能力"],"numbered":false,"link":true},
 {"id":"static_ability","term":"静止类能力","group":"能力种类","definition":"持续生效或不进入对抗的能力，包括部分能力词条。","patterns":["静止类能力"],"numbered":false,"link":true},
 {"id":"replacement_ability","term":"代替类能力","group":"能力种类","definition":"通常带有“改为”等字样的能力，会代替某种动作执行。","patterns":["代替类能力"],"numbered":false,"link":true},
]
const LINK_PREFIX="kw:"
const DefinitionPopup=preload("res://scripts/keyword_glossary_popup.gd")
static var current

static func entry(id: String) -> Dictionary:
 for item in ENTRIES:
  if item.id==id:return item
 return {}

static func entries_in(group: String) -> Array:
 return ENTRIES.filter(func(item):return item.group==group)

static func matches(text: String) -> Array:
 var result=[];var seen={};var offset=0;var depth=0
 while offset<text.length():
  if text[offset]=="「":depth+=1;offset+=1;continue
  if text[offset]=="」":depth=maxi(0,depth-1);offset+=1;continue
  if depth>0:offset+=1;continue
  var chosen={};var length=0
  for item in ENTRIES:
   if not item.get("link",true):continue
   for pattern in item.get("patterns",[item.term]):
    if pattern.length()>length and text.substr(offset,pattern.length())==pattern:chosen=item;length=pattern.length()
  if length==0:offset+=1;continue
  if chosen.get("numbered",false):
   while offset+length<text.length() and "0123456789０１２３４５６７８９X".contains(text[offset+length]):length+=1
  if not seen.has(chosen.id):result.append({"start":offset,"length":length,"id":chosen.id});seen[chosen.id]=true
  offset+=length
 return result

static func append(label: RichTextLabel,text: String,link_color: Color):
 var offset=0
 for found in matches(text):
  if found.id==label.get_meta("keyword_exclude_id",""):continue
  label.add_text(text.substr(offset,found.start-offset));label.push_meta(LINK_PREFIX+found.id);label.push_color(link_color)
  label.add_text(text.substr(found.start,found.length));label.pop();label.pop()
  offset=found.start+found.length
 label.add_text(text.substr(offset))

static func connect_links(app,label: RichTextLabel):
 if label.has_meta("keyword_links_connected"):return
 label.set_meta("keyword_links_connected",true)
 label.meta_clicked.connect(func(meta):
  var value=str(meta)
  if value.begins_with(LINK_PREFIX):show_definition(app,value.trim_prefix(LINK_PREFIX)))
 label.meta_hover_started.connect(func(_id):label.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND)
 label.meta_hover_ended.connect(func(_id):label.mouse_default_cursor_shape=Control.CURSOR_ARROW)

static func rich_text(app,parent: Node,text: String,font: int,color: Color,exclude_id: String="") -> RichTextLabel:
 var label=RichTextLabel.new();parent.add_child(label)
 if not exclude_id.is_empty():label.set_meta("keyword_exclude_id",exclude_id)
 label.fit_content=true;label.scroll_active=false;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.selection_enabled=false;label.focus_mode=Control.FOCUS_NONE;label.mouse_filter=Control.MOUSE_FILTER_STOP
 label.add_theme_font_size_override("normal_font_size",font);label.add_theme_color_override("default_color",color)
 append(label,text,app.GOLD);connect_links(app,label)
 return label

static func show_definition(app,id: String):
 if entry(id).is_empty():return
 if not is_instance_valid(current):
  current=DefinitionPopup.new();current.app=app;current.glossary=load("res://scripts/keyword_glossary.gd");app.add_child(current)
 current.show_entry(id)

static func close_definition():
 if is_instance_valid(current):current.queue_free()
 current=null
