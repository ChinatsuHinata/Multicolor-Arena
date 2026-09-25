extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func run():
 var before=FileAccess.get_file_as_string(Store.SAVE_PATH)
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.draft=Store.blank("布局检查")
 app.draft.leader="70"
 app.draft.rule_set="test"
 for i in range(70): app.draft.main.append("68")
 app.editor()
 await process_frame
 await process_frame
 expect(app.main_card_rect(20).position.x>=154 and app.main_card_rect(20).position.y>=200,"third row stays beside the independent leader slot")
 var overlap=false
 for i in range(70):
  var rect=app.main_card_rect(i)
  if rect.intersects(Rect2(4,4,140,195)): overlap=true
  for j in range(i):
   if rect.intersects(app.main_card_rect(j)): overlap=true
 expect(not overlap,"all 70 main cards have distinct unobscured positions")
 app.main_scroll.scroll_vertical=10000
 await process_frame
 expect(app.main_card_rect(69).end.y-app.main_scroll.scroll_vertical<=app.main_scroll.size.y,"last card scrolls fully into view")
 app.toggle_color("红")
 app.toggle_color("黄")
 expect(app.selected_colors==["红","黄"] and app.color_buttons["红"].button_pressed and app.color_buttons["黄"].button_pressed,"red and yellow stay selected together")
 expect(app.matches_colors(Store.CARDS["70"]) and not app.matches_colors(Store.CARDS["99"]) and not app.matches_colors(Store.CARDS["167"]),"multiple selected colors require an exact color set")
 app.toggle_color("红")
 expect(app.selected_colors==["黄"],"unchecking one color preserves the other")
 app.toggle_color("全部")
 expect(app.selected_colors.is_empty() and app.library.get_child_count()==app.library_ids().size(),"all resets color selection")
 expect(Store.CARDS["70"].colors==["红","黄"] and Store.CARDS["170"].colors==["红","黄"] and Store.CARDS["68"].colors==["蓝","黄"],"three requested multicolor identities")
 var names=true
 for row in app.library.get_children():
  if row.get_child(0).text!=Store.CARDS[row.get_meta("card_id")].name: names=false
 expect(names,"library labels preserve entire titles and names")
 app.query="普通的魔法使"
 app.update_library()
 expect(app.library.get_child_count()==1 and app.library.get_child(0).get_meta("card_id")=="68","full character title is searchable")
 var search=app.screen.get_node("LibrarySearch")
 var examples=[
  ["红蓝黑单位","character-ucs-038","单位",["红","蓝","黑"],false],
  ["红黑结界","169","结界",["红","黑"],false],
  ["黄道具","item-htk-008","道具",["黄"],false],
  ["红蓝自机单位","91","自机",["红","蓝"],false],
  ["单黄符卡","99","符卡",["黄"],true]
 ]
 for example in examples:
  search.text=example[0]
  search.text_changed.emit(search.text)
  var ids=app.library_ids()
  expect(ids.has(example[1]) and ids.all(func(id):
   var info=Store.CARDS[id]
   var allowed_kinds=["单位","自机"] if example[2]=="单位" else [example[2]]
   return info.kind in allowed_kinds and example[3].all(func(color):return color in info.colors) and (not example[4] or info.colors.size()==1)
  ),"advanced search filters %s" % example[0])
  expect(app.library.get_child_count()==ids.size(),"typing %s refreshes library" % example[0])
 search.text="单位"
 search.text_changed.emit(search.text)
 expect(app.library_ids().any(func(id):return Store.CARDS[id].kind=="单位") and app.library_ids().any(func(id):return Store.CARDS[id].kind=="自机") and app.library_ids().all(func(id):return Store.CARDS[id].kind in ["单位","自机"]),"unit search includes ordinary and leader units")
 var units=app.library_ids()
 search.text="普通单位"
 search.text_changed.emit(search.text)
 expect(not app.library_ids().is_empty() and app.library_ids().all(func(id):return Store.CARDS[id].kind=="单位"),"ordinary unit search excludes leader units")
 search.text="自机单位"
 search.text_changed.emit(search.text)
 expect(not app.library_ids().is_empty() and app.library_ids().all(func(id):return Store.CARDS[id].kind=="自机"),"leader unit search excludes ordinary units")
 app.filter_kind="单位"
 search.text=""
 search.text_changed.emit(search.text)
 expect(app.library_ids()==units,"unit category includes both unit types")
 app.filter_kind="普通单位"
 expect(app.library_ids().all(func(id):return Store.CARDS[id].kind=="单位"),"ordinary unit category excludes leaders")
 app.filter_kind="自机单位"
 expect(app.library_ids().all(func(id):return Store.CARDS[id].kind=="自机"),"leader unit category excludes ordinary units")
 app.filter_kind="全部"
 var kind_filter=app.screen.get_node("LibraryKindFilter")
 var ordinary_index=-1
 for index in range(kind_filter.item_count):
  if kind_filter.get_item_text(index)=="普通符卡":ordinary_index=index
 expect(ordinary_index>=0,"ordinary spell category is available")
 if ordinary_index>=0:
  kind_filter.select(ordinary_index)
  kind_filter.item_selected.emit(ordinary_index)
  expect(app.library_ids().has("145") and app.library_ids().all(func(id):return Store.CARDS[id].kind=="符卡" and Store.CARDS[id].get("requires_character","")=="" and "角色" not in Store.CARDS[id].get("spell_type","")),"ordinary spell category excludes all character spells")
  kind_filter.select(0)
  kind_filter.item_selected.emit(0)
 for example in [["普通符卡","145"],["红蓝普通符卡","138"],["单蓝普通符卡","145"]]:
  search.text=example[0]
  search.text_changed.emit(search.text)
  var ordinary_ids=app.library_ids()
  expect(ordinary_ids.has(example[1]) and ordinary_ids.all(func(id):return Store.CARDS[id].kind=="符卡" and Store.CARDS[id].get("requires_character","")=="" and "角色" not in Store.CARDS[id].get("spell_type","")),"ordinary spell search filters %s" % example[0])
 expect(app.library_ids().all(func(id):return Store.CARDS[id].colors==["蓝"]) and not app.library_ids().has("new-loc-002"),"single blue ordinary spells match exactly one color and exclude character restricted spells")
 search.text="黄"
 search.text_changed.emit(search.text)
 expect(app.library_ids().has("item-htk-008"),"color-only search includes multicolor cards")
 search.text="单黄"
 search.text_changed.emit(search.text)
 expect(app.library_ids().all(func(id):return Store.CARDS[id].colors==["黄"]),"single prefix only includes monochrome cards")
 var race_examples=[
  ["人类","21","人类",[],false],
  ["妖精","57","妖精",[],false],
  ["单蓝妖精","57","妖精",["蓝"],true],
  ["红黑人类","21","人类",["红","黑"],false],
  ["红黄吸血鬼","character-fdf-ex01","吸血鬼",["红","黄"],false]
 ]
 for example in race_examples:
  search.text=example[0]
  search.text_changed.emit(search.text)
  var race_ids=app.library_ids()
  expect(race_ids.has(example[1]) and race_ids.all(func(id):
   var info=Store.CARDS[id]
   return example[3].all(func(color):return color in info.colors) and (not example[4] or info.colors.size()==1)
  ),"race search filters %s" % example[0])
 search.text="妖精"
 search.text_changed.emit(search.text)
 expect(app.library_ids().has("spell-fdn-066") and app.library_ids().has("item-lof-009"),"race search combines units, spells and items")
 search.text="神"
 search.text_changed.emit(search.text)
 expect(app.library_ids().has("field-fdf-107"),"race search includes related fields")
 var tenshi_spells=[]
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if info.get("canonical_id",id)==id and info.kind=="符卡" and info.get("requires_character","")=="比那名居天子" and "角色" in info.get("spell_type",""):tenshi_spells.append(id)
 search.text="比那名居天子符卡"
 search.text_changed.emit(search.text)
 expect(not tenshi_spells.is_empty() and tenshi_spells.all(func(id):return id in app.library_ids()),"full leader character name finds every role spell")
 search.text="天子符卡"
 search.text_changed.emit(search.text)
 expect(tenshi_spells.all(func(id):return id in app.library_ids()),"partial leader name finds the same role spells")
 search.text="红符卡"
 search.text_changed.emit(search.text)
 expect(app.library_ids().has("121") and app.library_ids().has("spell-ucs-027") and "红" not in Store.CARDS["121"].colors,"color and matching leader-name role spells are combined")
 search.text="紫符卡"
 search.text_changed.emit(search.text)
 expect(not app.library_ids().has("new-spx-006") and app.library_ids().any(func(id):return Store.CARDS[id].get("requires_character","")=="八云紫"),"leader-name search only adds role spells")
 var alias_examples={
  "西瓜":["90","new-spx-001"],"青蛙":["93","new-spx-003","character-ucs-025"],
  "老师":["character-fdf-ex05"],"小五":["76"],"恋恋":["73"],
  "红师傅":["47"],"狗花":["character-fdf-101","character-ucs-056"],
  "uu":["48","71","character-fdn-043"],"豆康":["spell-fdf-087"],
  "大康":["100"],"小康":["spell-rei-012"],"小跳":["spell-soi-098"],
  "蓝康":["spell-fdn-069"],"绿康":["spell-fdn-066"],
  "大跳":["spell-rei-015"],"开门":["149"],
  "炮":["99","spell-mar-002","spell-mar-004"],"饼":["164","165","166","167","168"]
 }
 for alias in alias_examples:
  app.query=alias
  var matches=app.library_ids()
  expect(alias_examples[alias].all(func(id):return id in matches),"editable alias %s finds mapped cards" % alias)
 app.query="青蛙"
 expect(app.library_ids().has("151"),"ordinary alias keeps printed-name search results")
 app.query="炮"
 expect(app.library_ids().size()==3,"cannon alias only finds cards treated as Master Spark")
 app.query="饼"
 expect(app.library_ids().size()==5,"biscuit alias only finds mono two-cost tap mana items")
 app.query="西瓜符卡"
 var suika_alias_spells=app.library_ids()
 app.query="萃香符卡"
 expect(not suika_alias_spells.is_empty() and suika_alias_spells==app.library_ids(),"alias plus spell finds the same character spells")
 for pair in [["老师符卡","上白泽慧音"],["小五符卡","古明地觉"],["恋恋符卡","古明地恋"]]:
  app.query=pair[0]
  var role_ids=app.library_ids()
  expect(not role_ids.is_empty() and role_ids.all(func(id):return Store.CARDS[id].kind=="符卡" and Store.CARDS[id].get("requires_character","")==pair[1] and "角色" in Store.CARDS[id].get("spell_type","")),"new unit alias finds character spells %s" % pair[0])
 search.text=""
 search.text_changed.emit(search.text)
 app.draft.leader=""
 app.update_deck_rows()
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 app.main_content.get_node("LeaderDropZone").gui_input.emit(click)
 var picker=app.get_node_or_null("LeaderPicker")
 expect(picker!=null,"empty leader slot opens card art picker")
 if picker!=null:
  var picker_search=picker.get_node("LeaderPickerSearch")
  picker_search.text="魔理沙"
  picker_search.text_changed.emit(picker_search.text)
  var choices=picker.find_child("LeaderChoices",true,false)
  expect(choices!=null,"leader picker shows card art choices")
  if choices!=null:
   var marisa=choices.get_children().filter(func(tile):return tile.get_meta("card_id","")=="68")
   expect(not marisa.is_empty() and marisa[0].get_child(0).texture!=null,"leader picker filters and shows constructible card art")
   if not marisa.is_empty():marisa[0].gui_input.emit(click)
 await process_frame
 expect(app.draft.leader=="68" and app.dirty,"choosing card art sets the leader")
 var leader_tiles=app.main_content.get_children().filter(func(node):return node.has_method("_get_drag_data") and node.get("source_zone")=="leader")
 if not leader_tiles.is_empty():leader_tiles[0].clicked.emit("68","leader",0,false)
 expect(app.get_node_or_null("LeaderPicker")!=null,"clicking occupied leader slot reopens picker")
 picker=app.get_node_or_null("LeaderPicker")
 if picker!=null:picker.confirmed.emit()
 await process_frame
 app.draft.leader="70"
 app.dirty=false
 app.update_deck_rows()
 app.selected="68"
 app.update_preview()
 await process_frame
 await process_frame
 var scroll=app.preview.get_node("CardTextScroll")
 var column=scroll.get_child(0)
 expect(column.get_child(2).text==app.card_description("68") and "自机能力" in column.get_child(2).text and "1点伤害" in column.get_child(2).text,"complete workbook ability text in preview")
 scroll.scroll_vertical=10000
 await process_frame
 expect(column.size.y-scroll.scroll_vertical<=scroll.size.y+1,"preview footer remains reachable by scrolling")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==before,"player saved decks unchanged")
 print("V03_TEST: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
