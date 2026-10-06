extends HBoxContainer
## Private scene draft. Existing card instances keep their aliases and state.
const Selector=preload("res://scripts/card_name_search_panel.gd")
const RuleSet=preload("res://scripts/deck_rule_set.gd")
var editor
var scene: Dictionary={}
var saved_decks: Array=[]
var battlefield=false
var player=0
var zone="deck_order"
var selected_index=-1
var summary: Label
var deck_title: Label
var card_list: ItemList
var zone_choice: OptionButton
var rule_choice: OptionButton
var source_choice: OptionButton
var import_leader: CheckButton
var selector
var quantity: SpinBox
var choose: Button
var move_up: Button
var move_down: Button
var remove: Button
var clear_cards: Button
var error_label: Label
var error_scroll: ScrollContainer

func configure(owner_editor,id: String):
 editor=owner_editor;scene=editor.model.data.scenarios[id].duplicate(true)
 battlefield=scene.get("type","battlefield")=="battlefield"
 zone="deck_order" if battlefield else "main"
 saved_decks=editor.host.decks.duplicate(true)

func _ready():
 name="TutorialInitialSceneForm";add_theme_constant_override("separation",16)
 var left=VBoxContainer.new();add_child(left);left.custom_minimum_size.x=360
 left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=0.7
 if battlefield:
  editor.option(left,[0,1],player,func(value):player=value;selected_index=-1;refresh_cards();refresh_selector(),["我方 · "+scene.players[0].get("name","学员"),"对方 · "+scene.players[1].get("name","教程对手")]).name="InitialScenePlayer"
 else:
  editor.text(left,scene.deck.name)
  rule_choice=editor.option(left,RuleSet.IDS,scene.deck.get("rule_set",RuleSet.OFFICIAL),func(value):scene.deck.rule_set=value;refresh_cards();refresh_selector(),RuleSet.IDS.map(func(id):return RuleSet.label_for(id)));rule_choice.name="InitialSceneRuleSet"
 summary=editor.text(left,"");summary.add_theme_color_override("font_color",editor.host.GOLD)
 var zones=["leader","deck_order"] if battlefield else ["leader","main","side"]
 zone_choice=editor.option(left,zones,zone,change_zone,["初始自机","初始牌库"] if battlefield else ["初始自机","初始主卡组","初始副卡组"]);zone_choice.name="InitialSceneZone"
 editor.text(left,"从已有卡组导入")
 var import_row=HBoxContainer.new();left.add_child(import_row)
 source_choice=OptionButton.new();source_choice.name="InitialSceneSavedDeck";import_row.add_child(source_choice);source_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 source_choice.clip_text=true;source_choice.custom_minimum_size.y=34
 for deck in saved_decks:source_choice.add_item("%s · %s · %d 张" % [deck.name,card_name(deck.leader),deck.main.size()])
 if saved_decks.is_empty():source_choice.add_item("没有已保存卡组");source_choice.disabled=true
 var import_button=editor.action(import_row,"导入卡组",func():import_deck(saved_decks[source_choice.selected],import_leader.button_pressed))
 import_button.name="ImportInitialSceneDeck";import_button.disabled=saved_decks.is_empty()
 import_button.tooltip_text="替换当前一方的牌库，保留起始手牌、战场及其他区域。" if battlefield else "替换主副卡组，并使用来源卡组的规则集。"
 import_leader=editor.flag(left,"同时导入自机",true,func(_value):pass);import_leader.name="ImportInitialSceneLeader"
 deck_title=editor.text(left,"")
 card_list=ItemList.new();card_list.name="InitialSceneCards";left.add_child(card_list)
 card_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;card_list.custom_minimum_size.y=100
 card_list.item_selected.connect(func(index):selected_index=index;selector.select_id(entry_id(entries()[index]));refresh_buttons())
 var order=HBoxContainer.new();left.add_child(order)
 move_up=editor.action(order,"上移",func():move_card(-1));move_up.name="InitialSceneMoveUp"
 move_down=editor.action(order,"下移",func():move_card(1));move_down.name="InitialSceneMoveDown"
 remove=editor.action(order,"移除",remove_card);remove.name="InitialSceneRemoveCard";remove.tooltip_text="移除列表中选中的这一张牌。"
 clear_cards=editor.action(order,"清空",func():entries().clear();selected_index=-1;refresh_cards());clear_cards.name="InitialSceneClearDeck"
 clear_cards.tooltip_text="清空当前牌库或卡组区域；应用初始配置后才写入课程。"
 var hint=editor.text(left,"牌库从上到下依次抽牌。起始手牌、战场、颜色盘等可在录制场景中布置。" if battlefield else "主副卡组可逐张增删、调整顺序；应用时按所选规则集校验。")
 hint.add_theme_font_size_override("font_size",16)
 var right=VBoxContainer.new();add_child(right);right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.size_flags_stretch_ratio=1.5
 selector=Selector.new();selector.name="InitialSceneCardSearch";selector.layout_metrics=editor.host.ui_metrics
 right.add_child(selector);selector.size_flags_vertical=Control.SIZE_EXPAND_FILL;selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 selector.selected.connect(func(_entry):refresh_buttons())
 var add_row=HBoxContainer.new();right.add_child(add_row)
 quantity=SpinBox.new();quantity.name="InitialSceneQuantity";quantity.min_value=1;quantity.max_value=100;quantity.value=1;quantity.step=1
 quantity.custom_minimum_size=Vector2(120,36);add_row.add_child(quantity)
 choose=editor.action(add_row,"加入初始牌库",add_selected);choose.name="InitialSceneAddCard";choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 error_scroll=ScrollContainer.new();right.add_child(error_scroll);error_scroll.custom_minimum_size.y=100
 error_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;error_scroll.hide()
 error_label=editor.text(error_scroll,"");error_label.name="InitialSceneError";error_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 error_label.add_theme_color_override("font_color",Color("ff8d8d"));error_label.hide()
 refresh_cards();refresh_selector()

func card_name(id: String) -> String:
 return str(editor.host.Store.CARDS.get(id,{}).get("name",id))

func entry_id(value: Variant) -> String:
 return str(value.card_id) if value is Dictionary else str(value)

func list_zone() -> String:
 return ("deck_order" if battlefield else "main") if zone=="leader" else zone

func entries() -> Array:
 return scene.players[player].get(list_zone(),[]) if battlefield else scene.deck.get(list_zone(),[])

func leader_id() -> String:
 return scene.players[player].leader.card_id if battlefield else scene.deck.leader

func change_zone(value: String):
 zone=value;selected_index=-1
 zone_choice.select((["leader","deck_order"] if battlefield else ["leader","main","side"]).find(value))
 selector.query="";selector.search_input.clear();selector.filter_kind="全部"
 selector.find_child("KindFilter",true,false).select(0);selector.toggle_color("全部")
 refresh_cards();refresh_selector()

func refresh_cards(reveal: bool=false):
 error_label.hide();error_scroll.hide()
 summary.text="初始自机："+card_name(leader_id())
 summary.text+="\n牌库 %d 张" % scene.players[player].get("deck_order",[]).size() if battlefield else "\n主卡组 %d 张 / 副卡组 %d 张" % [scene.deck.get("main",[]).size(),scene.deck.get("side",[]).size()]
 if not battlefield:rule_choice.select(RuleSet.IDS.find(scene.deck.get("rule_set",RuleSet.OFFICIAL)))
 var cards=entries()
 deck_title.text=("初始牌库" if battlefield else "初始副卡组" if list_zone()=="side" else "初始主卡组")+" · %d 张" % cards.size()
 var scroll=card_list.get_v_scroll_bar().value
 card_list.clear()
 for i in range(cards.size()):
  var entry=cards[i];var caption="%d. %s" % [i+1,card_name(entry_id(entry))]
  if entry is Dictionary and entry.has("alias"):caption+=" · "+entry.alias
  card_list.add_item(caption);card_list.set_item_tooltip(i,caption)
 selected_index=mini(selected_index,cards.size()-1)
 if selected_index>=0:card_list.select(selected_index)
 card_list.get_v_scroll_bar().set_deferred("value",scroll)
 if reveal:card_list.call_deferred("ensure_current_is_visible")
 refresh_buttons()

func refresh_selector():
 var choices=[]
 for id in editor.host.Store.CARDS:
  var info=editor.host.Store.CARDS[id]
  if zone=="leader" and info.kind!="自机":continue
  if not battlefield and not RuleSet.allowed(id,info,scene.deck.get("rule_set",RuleSet.OFFICIAL)):continue
  choices.append({"id":id})
 var previous=str(selector.selected_entry.get("id",""))
 selector.configure(editor.host.Store.CARDS,choices,func(id):return editor.host.preview_texture(id))
 if zone=="leader":selector.select_id(leader_id())
 elif not previous.is_empty():selector.select_id(previous)
 refresh_buttons()

func refresh_buttons():
 if not is_instance_valid(choose):return
 var leader=zone=="leader"
 choose.text="设为初始自机" if leader else "加入初始牌库" if battlefield else "加入初始副卡组" if zone=="side" else "加入初始主卡组"
 choose.disabled=selector.selected_entry.is_empty();quantity.visible=not leader
 move_up.disabled=leader or selected_index<=0
 move_down.disabled=leader or selected_index<0 or selected_index>=entries().size()-1
 remove.disabled=leader or selected_index<0
 clear_cards.disabled=leader or entries().is_empty()

func set_leader(id: String):
 if battlefield:scene.players[player].leader.card_id=id
 else:scene.deck.leader=id

func add_selected():
 if selector.selected_entry.is_empty():return
 var id=str(selector.selected_entry.id)
 if zone=="leader":set_leader(id);refresh_cards();return
 var cards=entries()
 for i in range(int(quantity.value)):cards.append({"card_id":id} if battlefield else id)
 if battlefield:scene.players[player][zone]=cards
 else:scene.deck[zone]=cards
 selected_index=cards.size()-1;refresh_cards(true)

func move_card(offset: int):
 var cards=entries();var target=selected_index+offset
 if zone=="leader" or selected_index<0 or target<0 or target>=cards.size():return
 var entry=cards.pop_at(selected_index);cards.insert(target,entry);selected_index=target
 refresh_cards(true)

func remove_card():
 if zone=="leader" or selected_index<0:return
 entries().remove_at(selected_index);refresh_cards()

func import_deck(deck: Dictionary,with_leader: bool=true):
 if with_leader:set_leader(deck.leader)
 if battlefield:
  # Match copies in order so surviving references and configured state remain.
  var existing={}
  for entry in scene.players[player].get("deck_order",[]):
   if not existing.has(entry.card_id):existing[entry.card_id]=[]
   existing[entry.card_id].append(entry)
  var cards=[]
  for id in deck.main:
   cards.append(existing[id].pop_front() if existing.has(id) and not existing[id].is_empty() else {"card_id":id})
  scene.players[player].deck_order=cards
 else:
  scene.deck.main=deck.main.duplicate();scene.deck.side=deck.get("side",[]).duplicate();scene.deck.rule_set=deck.get("rule_set",RuleSet.OFFICIAL)
 selected_index=-1;refresh_cards();refresh_selector()

func show_error(message: String):
 error_label.text="配置未应用：\n"+message;error_label.show();error_scroll.show();error_scroll.scroll_vertical=0
