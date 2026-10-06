extends "res://tests/support/ui_base.gd"
const Aliases=preload("res://scripts/card_search_aliases.gd")

func search_panel(node: Node):
 if node==null:return null
 return node.find_child("CardNameSearchPanel",true,false)

func selected_text(node: Node) -> String:
 if node==null:return ""
 var result=""
 if node is Label:result=node.text
 elif node is RichTextLabel:result=node.get_parsed_text()
 for child in node.get_children():result+="\n"+selected_text(child)
 return result

func search_rows(term: String) -> Array:
 var panel=search_panel(view.modal_root)
 expect(panel!=null,"card selection uses the shared search panel")
 if panel==null:return []
 var search=panel.find_child("SearchInput",true,false)
 var results=panel.find_child("SearchResults",true,false)
 expect(search is LineEdit and results!=null,"card selection exposes search input and results")
 if not search is LineEdit or results==null:return []
 search.text=term;search.text_changed.emit(term)
 return results.get_children().filter(func(child):return child is Button and child.visible)

func naming_checks():
 var before=JSON.stringify(e.pending)
 for pair in [["小妖梦","39"],["小猫车","character-ucs-038"],["红饼","165"],["蓝饼","167"],["绿饼","166"],["黄饼","164"],["黑饼","168"],["530","spell-fdf-085"],["165","165"],["旧地狱的宠物妖怪","character-ucs-038"]]:
  var rows=search_rows(pair[0])
  expect(rows.size()==1 and rows[0].get_meta("card_name","")==e.cards[pair[1]].name,"name picker finds the precise card for "+pair[0])
 for term in ["炸弹人","夜雀","UU","小五符卡","饼","炮","密封"]:
  var query=Aliases.prepare_query(e.cards,term,Aliases.load_rules())
  var names=Aliases.matching_names(e.cards,query)
  var rows=search_rows(term)
  expect(not rows.is_empty() and rows.size()==names.size() and rows.all(func(row):return names.has(row.get_meta("card_name",""))),"name picker applies the shared alias rule for "+term)
 for term in ["神风","神之风"]:
  expect(search_rows(term).any(func(row):return row.get_meta("card_name","")==e.cards["134"].name),"name picker finds 神ノ风 through "+term)
 expect(search_rows("不存在的卡牌别名").is_empty(),"unknown query hides all unrelated names")
 expect(search_rows("   ").size()==e.pending.options.size(),"blank query restores all legal names")
 expect(JSON.stringify(e.pending)==before,"searching never changes legal options or the pending effect")

func choose_name(term: String,id: String):
 var rows=search_rows(term)
 expect(rows.size()==1,"one name is selected through "+term)
 if rows.size()!=1:return
 rows[0].pressed.emit()
 var selected=search_panel(view.modal_root).find_child("SelectedCard",true,false)
 expect(selected!=null and e.cards[id].name in selected_text(selected),"selected name appears in the center before confirmation")
 expect(view.picker.ready() and view.picker.option().get("card_name","")==e.cards[id].name,"selection retains the official card name")
 view.confirm_trigger()
 if not e.stack.is_empty():resolve()

func enter_for_name(id: String):
 var source=e.make_card(id,0,"hand")
 e.enter_field(source,0);e.pump_choices();show_choices()
 return source

func show_choices():
 e.presentation_events.clear();view.reveal_player.reset();view.render()

func cast_for_name(id: String,target: Dictionary={}):
 e.debug_enabled=true;e.debug_free_payment=true
 var spell=put(id,"hand")
 var options=e.targets_for(id,0,spell.uid)
 if target.is_empty() and not options.is_empty():target=options[0]
 var error=e.commit_cast(0,spell.uid,target,[])
 expect(error.is_empty(),"cast reaches naming effect: "+id+" "+error)
 resolve();show_choices()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/card-search-aliases-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.draft=Store.blank("别名搜索测试");app.draft.leader="70";app.editor()
 for pair in [["小妖梦",["39"]],["小猫车",["character-ucs-038"]],["炸弹人",["78","character-fdn-042"]],["转转",["32"]],["夜雀",["22","character-fdf-094","token-fdf-127"]],["夜雀道具",["token-fdf-127"]],["红饼",["165"]],["蓝饼",["167"]],["绿饼",["166"]],["黄饼",["164"]],["黑饼",["168"]],["红饼道具",["165"]]]:
  app.query=pair[0]
  var ids=app.library_ids();ids.sort();pair[1].sort()
  expect(ids==pair[1],"editor finds "+pair[0])
 for term in ["神ノ风","神风","神之风"]:
  app.query=term
  expect(app.library_ids().has("134"),"editor finds 神ノ风 through "+term)
 app.query="红蓝单位"
 expect(not app.library_ids().is_empty() and app.library_ids().all(func(id):return Store.CARDS[id].kind in ["单位","自机"] and "红" in Store.CARDS[id].colors and "蓝" in Store.CARDS[id].colors),"editor retains combined category and color filters")
 var expected_character_spells=Store.CARDS.keys().filter(func(id):return Store.CARDS[id].get("canonical_id",id)==id and Store.CARDS[id].kind=="符卡" and (not Store.CARDS[id].requires_character.is_empty() or "角色" in Store.CARDS[id].spell_type))
 app.query="自机符卡"
 expect(app.library_query_filters(app.query).is_empty(),"PC deck search keeps its original category parser")
 var pc_kind=app.screen.find_child("LibraryKindFilter",true,false)
 var pc_kinds=[]
 for i in range(pc_kind.item_count):pc_kinds.append(pc_kind.get_item_text(i))
 expect(pc_kinds==["全部","单位","普通单位","自机单位","符卡","普通符卡","道具","结界"],"PC deck editor keeps its original type options")
 app.is_android=true
 var editor_character_spells=app.library_ids();editor_character_spells.sort();expected_character_spells.sort()
 expect(not editor_character_spells.is_empty() and editor_character_spells==expected_character_spells,"Android editor text search recognizes all character specific spells")
 app.query="红自机符卡"
 expect(not app.library_ids().is_empty() and app.library_ids().all(func(id):return id in expected_character_spells and "红" in Store.CARDS[id].colors),"Android editor search combines colors with the new spell category")
 app.is_android=false
 app.query="小妖梦";app.update_library()
 var editor_row=app.library_rows.get("39",{}).get("row")
 expect(editor_row!=null and editor_row.find_children("*","Label",true,false).any(func(child):return child.text==Store.CARDS["39"].name),"deck builder warehouse shows only the card name")
 app.open_leader_picker()
 var dialog=app.get_node("LeaderPicker")
 var leader_panel=search_panel(dialog)
 expect(leader_panel!=null,"leader picker uses the shared search panel")
 var leader_search=leader_panel.find_child("SearchInput",true,false)
 leader_search.text="炸弹人";leader_search.text_changed.emit(leader_search.text)
 var leader_results=leader_panel.find_child("SearchResults",true,false)
 var leader_rows=leader_results.get_children().filter(func(child):return child is Button and child.visible)
 expect(leader_rows.size()==1 and leader_rows[0].get_meta("card_id","")=="78","leader picker resolves aliases within legal leaders")
 if leader_rows.size()==1:
  leader_rows[0].pressed.emit()
  var leader_selected=leader_panel.find_child("SelectedCard",true,false)
  expect(leader_selected!=null and Store.CARDS["78"].name in selected_text(leader_selected),"selected leader appears in the center")
  expect(app.draft.leader=="70","selecting a leader does not change the deck before confirmation")
  var leader_confirm=dialog.find_child("ConfirmSelection",true,false)
  expect(leader_confirm is Button and leader_confirm.text=="设为自机","leader picker offers the dedicated confirmation")
  if leader_confirm is Button:leader_confirm.pressed.emit()
  expect(app.draft.leader=="78","leader selection applies only after confirmation")
 if is_instance_valid(dialog) and not dialog.is_queued_for_deletion():dialog.queue_free()
 await process_frame
 app.load_test_decks();app.debug_mode=true;app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 clean(true);view.render();app.show_card_inspection=true;view.inspect_card("53")
 view.open_debug_card_picker(0,"hand")
 await process_frame
 var warehouse=search_panel(view.modal_root)
 var search_bounds=warehouse.get_global_rect()
 var search_field=warehouse.find_child("SearchInput",true,false)
 var search_scroll=warehouse.find_child("SearchScroll",true,false)
 var add_confirm=view.modal_root.find_child("ConfirmSelection",true,false)
 expect(search_bounds.has_area() and warehouse.get_parent().get_global_rect().encloses(search_bounds),"battle card search occupies the picker panel")
 expect(search_field.get_global_rect().has_area() and search_scroll.get_global_rect().has_area() and search_bounds.encloses(search_field.get_global_rect()) and search_bounds.encloses(search_scroll.get_global_rect()) and not search_bounds.intersects(add_confirm.get_global_rect()),"battle search controls fit above the add-card action")
 var warehouse_ids=warehouse.visible_entries().map(func(entry):return str(entry.id))
 expect(warehouse_ids.has("21") and not warehouse_ids.has("rec_unit_097") and warehouse_ids.all(func(id):return e.cards[id].get("canonical_id",id)==id),"battle warehouse shows only canonical card versions")
 for term in ["神风","神之风"]:
  warehouse.query=term
  expect(warehouse.visible_entries().any(func(entry):return str(entry.id)=="134"),"battle warehouse finds 神ノ风 through "+term)
 warehouse.query=""
 var warehouse_kind=warehouse.find_child("KindFilter",true,false)
 var pc_search_kinds=[]
 for i in range(warehouse_kind.item_count):pc_search_kinds.append(warehouse_kind.get_item_text(i))
 expect(pc_search_kinds==pc_kinds and warehouse._query_filters("自机符卡").is_empty(),"PC shared card search keeps its original options and category parser")
 var mobile_search=app.CardNameSearchPanel.new();mobile_search.layout_metrics=app.UILayout.new();mobile_search.layout_metrics.touch=true
 mobile_search.size=Vector2(1400,760);app.screen.add_child(mobile_search);mobile_search.configure(e.cards,warehouse.visible_entries())
 var mobile_kind=mobile_search.find_child("KindFilter",true,false)
 var character_spell_index=-1
 for i in range(mobile_kind.item_count):
  if mobile_kind.get_item_text(i)=="自机符卡":character_spell_index=i
 expect(character_spell_index>=0,"Android shared card search type filter includes character spells")
 mobile_kind.select(character_spell_index);mobile_kind.item_selected.emit(character_spell_index)
 var shared_spells=mobile_search.visible_entries().map(func(entry):return str(entry.id));shared_spells.sort()
 expect(shared_spells==expected_character_spells,"Android shared search type filter uses the same character spell classification")
 mobile_kind.select(0);mobile_kind.item_selected.emit(0)
 mobile_search.search_input.text="红自机符卡";mobile_search.search_input.text_changed.emit(mobile_search.search_input.text)
 expect(not mobile_search.visible_entries().is_empty() and mobile_search.visible_entries().all(func(entry):return str(entry.id) in expected_character_spells and "红" in e.cards[str(entry.id)].colors),"Android shared search text combines colors and character spell category")
 mobile_search.queue_free();await process_frame
 var warehouse_search=warehouse.find_child("SearchInput",true,false)
 warehouse_search.text=e.cards["21"].name;warehouse_search.text_changed.emit(warehouse_search.text)
 var variant_rows=warehouse.find_child("SearchResults",true,false).get_children().filter(func(child):return child is Button and child.visible)
 expect(variant_rows.size()==1 and variant_rows[0].get_meta("card_id","")=="21","battle warehouse search lists a shared card once")
 view.close_overlay()
 for spec in [
  {"destination":"hand","group":"","canonical":"spell-rec-054","variant":"spell-smm-002"},
  {"destination":"palette","group":"","canonical":"spell-rec-054","variant":"spell-smm-002"},
  {"destination":"grave","group":"","canonical":"spell-rec-054","variant":"spell-smm-002"},
  {"destination":"field","group":"unit","canonical":"character-fdn-048","variant":"character-ucs-067"},
  {"destination":"field","group":"item","canonical":"165","variant":""},
  {"destination":"field","group":"support","canonical":"field-smm-004","variant":"field-rei-013"}
 ]:
  view.open_debug_card_picker(0,spec.destination,spec.group)
  var add_panel=search_panel(view.modal_root)
  var add_ids=add_panel.visible_entries().map(func(entry):return str(entry.id))
  expect(add_ids.has(spec.canonical) and (spec.variant.is_empty() or not add_ids.has(spec.variant)) and add_ids.all(func(id):return e.cards[id].get("canonical_id",id)==id),"debug "+spec.destination+"/"+spec.group+" lists standard versions")
  expect(add_panel.select_id(spec.canonical),"debug picker selects standard card for "+spec.destination+"/"+spec.group)
  view.modal_root.find_child("ConfirmSelection",true,false).pressed.emit()
  expect(e.players[0][spec.destination].any(func(c):return c.card_id==spec.canonical),"debug picker adds the standard card to "+spec.destination+"/"+spec.group)
 clean(true);view.render()
 for who in [0,1]:
  for pair in [["小妖梦","39"],["小猫车","character-ucs-038"],["红饼","165"],["黑饼","168"]]:
   view.open_debug_card_picker(who,"hand")
   if who==0 and pair[0]=="小妖梦":
    view.refresh_observation()
    expect(view.ui.get_child(view.ui.get_child_count()-1)==view.observe_button and view.ui.get_child(view.ui.get_child_count()-2)==view.modal_root and view.observe_button.z_index>view.modal_root.z_index and view.modal_root.z_index>view.debug_controls.z_index and view.inspection.visible,"only observe battlefield stays above card search")
    view.observe_button.pressed.emit()
    expect(not view.modal_root.visible and view.observe_button.text=="返回选择","observe battlefield can reveal the duel while searching")
    view.observe_button.pressed.emit()
    expect(view.modal_root.visible and view.observe_button.text=="观察战场","observe battlefield can return to card search")
   var debug_panel=search_panel(view.modal_root)
   expect(debug_panel!=null,"debug picker uses the shared search panel")
   var search=debug_panel.find_child("SearchInput",true,false)
   search.text=pair[0];search.text_changed.emit(search.text)
   var results=debug_panel.find_child("SearchResults",true,false)
   var rows=results.get_children().filter(func(child):return child is Button and child.visible)
   expect(rows.size()==1 and rows[0].get_meta("card_id","")==pair[1],"debug picker finds "+pair[0]+" for player "+str(who))
   if rows.size()==1:expect("["+pair[1]+"]" not in rows[0].text,"search warehouse hides the internal card ID for "+pair[0])
   if rows.size()==1:
    rows[0].pressed.emit()
    var selected=debug_panel.find_child("SelectedCard",true,false)
    expect(selected!=null and e.cards[pair[1]].name in selected_text(selected),"debug selection appears in the center")
    expect(not e.players[who].hand.any(func(c):return c.card_id==pair[1]),"debug selection waits for confirmation")
    var confirm=view.modal_root.find_child("ConfirmSelection",true,false)
    expect(confirm is Button and confirm.text=="加入卡牌","debug picker offers add confirmation")
    if confirm is Button:confirm.pressed.emit()
   expect(e.players[who].hand.any(func(c):return c.card_id==pair[1]),"debug alias adds the selected card to the selected player")
   e.presentation_events.clear();view.reveal_player.reset()
 clean();var momiji=enter_for_name("character-fdf-101")
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:momiji_name","Momiji opens the real declaration")
 var old_name=e.cards["field-rei-013"].name
 var standard_name=e.cards["field-smm-004"].name
 expect(not e.pending.options.any(func(option):return option.get("card_name","")==old_name) and e.pending.options.any(func(option):return option.get("card_name","")==standard_name),"Momiji offers only the standard name for alternate versions")
 expect(search_panel(view.modal_root).visible_entries().all(func(entry):return e.cards[str(entry.id)].get("canonical_id",entry.id)==entry.id),"Momiji previews standard card versions")
 naming_checks();choose_name("红饼","165")
 expect(momiji.get("locked_name","")==e.cards["165"].name,"Momiji declares the resolved mana-item name")
 clean();var red=put("165","field");var enemy_red=put("165","field",1);var blue=put("167","field")
 cast_for_name("new-loc-004")
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:deer_name","deer shot opens its real name choice")
 choose_name("红饼","165")
 expect(red.zone=="grave" and enemy_red.zone=="grave" and blue.zone=="field","deer shot destroys only the named item on both sides")
 clean();var old_field=put("field-rei-013","field");var standard_field=put("field-smm-004","field",1)
 cast_for_name("new-loc-004")
 expect(not e.pending.options.any(func(option):return option.get("card_name","")==old_name),"deer shot does not offer the alternate printed name")
 choose_name(standard_name,"field-smm-004")
 expect(old_field.zone=="grave" and standard_field.zone=="grave","deer shot applies the standard name to both versions")
 clean();red=put("165","grave");blue=put("167","grave");enter_for_name("new-spx-005")
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:SPX-005","Yukari opens her real name choice")
 choose_name("红饼","165")
 expect(red.zone=="field" and blue.zone=="grave","Yukari returns the officially named item")
 clean();old_field=put("field-rei-013","grave");standard_field=put("field-smm-004","grave");enter_for_name("new-spx-005")
 choose_name(standard_name,"field-smm-004")
 expect(old_field.zone=="field" and standard_field.zone=="field","Yukari returns both versions under the standard name")
 clean();put("character-ucs-036","field");var target=put("53","field",1);put("39","hand",1);put("164","deck",1)
 cast_for_name("spell-fdf-032",e.ref_target(target))
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:brain_name","Brain Fingerprint also opens the shared name picker")
 choose_name("小妖梦","39")
 expect(target.zone=="grave","another naming effect resolves the three-cost Youmu alias")
 clean();put("character-ucs-036","field");target=put("53","field",1);put("character-ucs-067","hand",1)
 cast_for_name("spell-fdf-032",e.ref_target(target))
 choose_name(e.cards["character-fdn-048"].name,"character-fdn-048")
 expect(target.zone=="grave","name comparison recognizes an alternate unit under its standard name")
 clean();var small=put("39","grave");var large=put("87","grave")
 var query=Aliases.prepare_query(e.cards,"小妖梦",Aliases.load_rules())
 expect(view.choice_matches_query({"kind":"target","value":e.Pack.ref(e,small)},"",query,{}),"card-reference choices resolve aliases")
 expect(not view.choice_matches_query({"kind":"target","value":e.Pack.ref(e,large)},"小妖梦",query,{}),"exclusive aliases reject a different referenced card")
 query=Aliases.prepare_query(e.cards,"红饼",Aliases.load_rules())
 expect(view.choice_matches_query({"kind":"target","value":{"outside_id":"165"}},"",query,{}),"outside-card choices also resolve aliases")
 expect(not view.choice_matches_query({"kind":"target","value":{"outside_id":"167"}},"红饼",query,{}),"exclusive aliases do not include unrelated outside cards")
 query=Aliases.prepare_query(e.cards,"支付",Aliases.load_rules())
 expect(view.choice_matches_query({"kind":"mode","value":"支付费用"},"支付费用",query,{}),"non-card effect choices retain ordinary text search")
 print("CARD_SEARCH_ALIASES_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
