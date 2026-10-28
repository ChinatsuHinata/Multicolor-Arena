extends "res://tests/support/ui_base.gd"
const KeywordGlossary=preload("res://scripts/keyword_glossary.gd")
const CardInspection=preload("res://scripts/card_inspection.gd")

func frames(count: int=8):
 for i in range(count):await process_frame

func key(code: int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 root.push_input(event,true);await frames()

func click_keyword(label: RichTextLabel,word: String):
 var text=label.get_parsed_text();var index=text.find(word);var line=label.get_character_line(index);var start=index
 while start>0 and label.get_character_line(start-1)==line:start-=1
 var font=label.get_theme_font("normal_font");var font_size=label.get_theme_font_size("normal_font_size")
 var x=font.get_string_size(text.substr(start,index-start),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
 x+=font.get_string_size(text.substr(index,1),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
 await click(label.global_position+Vector2(x,label.get_line_offset(line)+label.get_line_height(line)*0.5));await frames()

func check_entries():
 expect(KeywordGlossary.ENTRIES.size()==28,"glossary contains 28 entries")
 var ids={}
 for item in KeywordGlossary.ENTRIES:
  expect(not ids.has(item.id),"unique glossary id: "+item.id);ids[item.id]=true
  expect(not item.definition.strip_edges().is_empty(),"nonempty definition: "+item.id)
  expect(KeywordGlossary.entry(item.id)==item,"entry lookup: "+item.id)
 for category in KeywordGlossary.GROUPS:expect(not KeywordGlossary.entries_in(category).is_empty(),"group has entries: "+category)
 expect(KeywordGlossary.entry("unknown").is_empty() and KeywordGlossary.entries_in("unknown").is_empty(),"unknown entries and groups are empty")

func check_matches():
 expect(KeywordGlossary.matches("吸血2。该单位获得吸血3")==[{"start":0,"length":3,"id":"lifelink"}],"numbered keywords link only their first occurrence")
 expect(KeywordGlossary.matches("限制级符卡，计时3，支援")==[{"start":0,"length":5,"id":"restricted"},{"start":6,"length":3,"id":"timer"},{"start":10,"length":2,"id":"support"}],"longest restricted pattern wins and timer includes its number")
 expect(KeywordGlossary.matches("将「先制的少女」放入，先制")==[{"start":11,"length":2,"id":"first"}],"card names do not consume the first keyword link")
 expect(KeywordGlossary.matches("获得防避1，防避1")==[{"start":2,"length":3,"id":"ward"}],"ward links once")
 expect(KeywordGlossary.matches("「先制「吸血2」追击」防避１２X3")==[{"start":11,"length":6,"id":"ward"}],"nested card names are skipped and full-width numbers and X are included")
 expect(KeywordGlossary.matches("规则类能力和能力，限制级，限制级符卡")==[{"start":0,"length":5,"id":"rule_ability"},{"start":9,"length":3,"id":"restricted"}],"ability types match whole and repeated aliases remain plain")
 expect(KeywordGlossary.matches("能力和时符").is_empty() and KeywordGlossary.matches("").is_empty(),"display-only and unknown words stay plain")

func check_popup(id: String):
 var popup=KeywordGlossary.current
 expect(is_instance_valid(popup) and popup.name=="KeywordDefinitionPopup" and popup.layer==1024,"definition opens one popup above modal menus")
 if not is_instance_valid(popup):return
 expect(popup.term.text==KeywordGlossary.entry(id).term and popup.group.text==KeywordGlossary.entry(id).group,"popup displays selected term and group")
 expect(popup.definition.get_parsed_text()==KeywordGlossary.entry(id).definition,"popup preserves exact definition text")
 expect(popup.definition.get_meta("keyword_exclude_id","")==id,"popup excludes its own keyword link")
 expect(app.ui_metrics.safe.grow(1).encloses(popup.panel.get_global_rect()),"definition panel fits safe area")
 expect(popup.panel.size.y<=app.ui_metrics.safe.size.y*0.7+1,"definition panel height respects safe-area limit")
 expect(popup.panel.get_global_rect().get_center().distance_to(app.ui_metrics.safe.get_center())<1,"definition panel is centered in safe area")
 expect(is_equal_approx(popup.panel.size.x,minf(1100 if app.is_android else 720,app.ui_metrics.safe.size.x-app.ui_metrics.padding*2)),"definition panel uses requested responsive width")

func run():
 check_entries();check_matches()
 var fixtures="res://work/keyword-glossary/fixtures-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixtures));Store.Paths.root_override=ProjectSettings.globalize_path(fixtures)
 var settings=fixtures.path_join("settings.json")
 var file=FileAccess.open(settings,FileAccess.WRITE);file.store_string('{"fullscreen":false}');file.close()
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=settings;app.account_session_path=fixtures.path_join("account.json")
 root.add_child(app);await frames()
 await click(find_button(app.screen,"游戏教程").get_global_rect().get_center());await frames()
 var open=app.screen.find_child("OpenKeywordGlossary",true,false)
 expect(app.page=="tutorials" and open is Button and open.visible,"tutorial header always offers glossary entry")
 expect(open.get_index()<app.tutorial_ui.editor_button.get_index(),"glossary entry precedes tutorial editor")
 await click(open.get_global_rect().get_center());await frames()
 expect(app.page=="keyword_glossary","tutorial glossary button opens glossary page")
 for id in ["pursuit","ward","restricted"]:expect(app.screen.find_child("KeywordEntry_"+id,true,false)!=null,"glossary page contains "+id)
 var ui=app.keyword_glossary_ui
 expect(ui.name=="KeywordGlossaryPage" and ui.find_child("KeywordGlossaryScroll",true,false).get_meta("android_swipe_prefer_vertical",false),"glossary uses named vertically scrollable page")
 var groups=[]
 for row in ui.rows.get_children():
  if row is Label:groups.append(row.text)
 expect(groups==KeywordGlossary.GROUPS,"glossary groups retain requested order")
 expect(ui.rows.get_node("KeywordEntry_pursuit").get_child(0) is HBoxContainer,"wide glossary entries use horizontal layout")
 ui.rows.get_node("KeywordEntry_token").get_child(0).get_child(1).meta_clicked.emit("kw:permanent");await frames()
 check_popup("permanent")
 KeywordGlossary.close_definition();await frames()
 await click(ui.find_child("KeywordGlossaryBack",true,false).get_global_rect().get_center());await frames()
 expect(app.page=="tutorials","glossary back returns to tutorials")
 var card_id=""
 for id in Store.CARDS:
  if str(Store.CARDS[id].get("rules_text","")).contains("追击"):card_id=id;break
 expect(not card_id.is_empty(),"real card rules include pursuit")
 var holder=VBoxContainer.new();app.screen.add_child(holder);holder.size=Vector2(500,600)
 var card_rules=CardInspection.rules(app,holder,card_id,500).find_child("CardInspectionRules",true,false)
 expect(card_rules is RichTextLabel and card_rules.get_parsed_text()==app.card_description(card_id),"shared card inspection preserves full rules as rich text")
 var connections=card_rules.meta_clicked.get_connections().size()
 KeywordGlossary.connect_links(app,card_rules);KeywordGlossary.connect_links(app,card_rules)
 expect(card_rules.meta_clicked.get_connections().size()==connections,"repeated link setup never duplicates connections")
 card_rules.meta_hover_started.emit("kw:pursuit");expect(card_rules.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"keyword hover shows pointing hand")
 card_rules.meta_hover_ended.emit("kw:pursuit");expect(card_rules.mouse_default_cursor_shape==Control.CURSOR_ARROW,"keyword hover exit restores arrow")
 card_rules.meta_clicked.emit("other:pursuit");expect(not is_instance_valid(KeywordGlossary.current),"non-keyword metadata does not open definition")
 card_rules.meta_clicked.emit("kw:pursuit");await frames();check_popup("pursuit")
 await key(KEY_ESCAPE)
 expect(app.find_child("KeywordDefinitionPopup",true,false)==null and KeywordGlossary.current==null,"Escape closes definition popup")
 card_rules.meta_clicked.emit("kw:token");await frames()
 var popup=KeywordGlossary.current
 popup.definition.meta_clicked.emit("kw:permanent");await frames()
 expect(KeywordGlossary.current==popup and app.find_children("KeywordDefinitionPopup","",true,false).size()==1,"definition cross-link reuses existing popup")
 check_popup("permanent")
 await click(popup.close_button.get_global_rect().get_center());await frames()
 expect(KeywordGlossary.current==null,"close button closes definition")
 var literal=KeywordGlossary.rich_text(app,holder,"[color=red]吸血2[/color] 追击",app.ui_metrics.body,app.WHITE)
 expect(literal.get_parsed_text()=="[color=red]吸血2[/color] 追击","rich text keeps bracket content literal")
 var preserved=true
 for id in Store.CARDS:
  literal.clear();KeywordGlossary.append(literal,app.card_description(id),app.GOLD)
  if literal.get_parsed_text()!=app.card_description(id):preserved=false;break
 expect(preserved,"every card description retains exactly the same parsed text")
 await click_keyword(card_rules,"追击")
 expect(is_instance_valid(KeywordGlossary.current) and KeywordGlossary.current.term.text=="追击","actual card rule hyperlink opens matching definition")
 popup=KeywordGlossary.current
 var self_links=[];popup.definition.meta_clicked.connect(func(meta):self_links.append(meta))
 await click_keyword(popup.definition,"追击")
 expect(self_links.is_empty(),"current term renders without a clickable self-link")
 KeywordGlossary.show_definition(app,"token");await frames()
 await click_keyword(popup.definition,"永久物")
 expect(KeywordGlossary.current==popup and popup.term.text=="永久物","actual definition hyperlink switches the existing popup")
 KeywordGlossary.close_definition();await frames()
 app.open_tasks();await frames()
 var tasks=app.menu_popup;var original_layer=tasks.layer
 tasks.show_card_details(card_id);await frames()
 var task_rules=tasks.card_overlay.find_child("CardInspectionRules",true,false)
 await click_keyword(task_rules,"追击")
 popup=KeywordGlossary.current
 expect(is_instance_valid(popup) and tasks.layer<popup.layer,"task detail hyperlink opens definition above its existing menu")
 await click(popup.close_button.get_global_rect().get_center());await frames()
 expect(KeywordGlossary.current==null and tasks.layer==original_layer and is_instance_valid(tasks.card_overlay),"closing definition restores task layer and keeps card details")
 app.close_menu_popup();await frames()
 app.editor();await frames()
 app.selected=card_id;app.update_preview();await frames()
 var editor_rules=app.preview.find_child("CardDescription",true,false)
 expect(editor_rules is RichTextLabel and editor_rules.get_parsed_text()==app.card_description(card_id),"desktop deck editor preview shows linked full rules")
 if editor_rules is RichTextLabel:
  await click_keyword(editor_rules,"追击")
  expect(is_instance_valid(KeywordGlossary.current) and KeywordGlossary.current.term.text=="追击","desktop deck editor keyword opens definition")
 KeywordGlossary.close_definition();await frames()
 app.is_android=true;app.layout_dpi_override=160;app.layout_safe_override=Rect2()
 root.size=Vector2i(680,900);root.content_scale_size=Vector2i(680,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.keyword_glossary();await frames(16)
 ui=app.keyword_glossary_ui
 expect(ui.size.x<720 and app.uses_responsive_layout(),"Android glossary uses responsive narrow safe area")
 expect(ui.rows.get_node("KeywordEntry_pursuit").get_child(0) is VBoxContainer,"narrow Android glossary entries stack term and definition")
 KeywordGlossary.show_definition(app,"copy");await frames();check_popup("copy")
 var safe=app.ui_metrics.safe
 app.ui_metrics.safe=Rect2(safe.position,Vector2(safe.size.x,300));KeywordGlossary.current.relayout();await frames()
 popup=KeywordGlossary.current
 expect(popup.scroll.get_v_scroll_bar().max_value>popup.scroll.get_v_scroll_bar().page,"long definition scrolls inside capped popup")
 var drag_start=popup.definition.global_position+Vector2(app.ui_metrics.padding,app.ui_metrics.body)
 var scroll_touch=InputEventScreenTouch.new();scroll_touch.index=0;scroll_touch.position=drag_start;scroll_touch.pressed=true
 root.push_input(scroll_touch,true);await process_frame
 var drag_event=InputEventScreenDrag.new();drag_event.index=0;drag_event.position=drag_start-Vector2(0,app.ui_metrics.hit);drag_event.relative=Vector2(0,-app.ui_metrics.hit)
 root.push_input(drag_event,true);await process_frame
 scroll_touch=scroll_touch.duplicate();scroll_touch.position=drag_event.position;scroll_touch.pressed=false;root.push_input(scroll_touch,true);await frames()
 expect(popup.scroll.scroll_vertical>0,"Android swipe scrolls long definition")
 app.ui_metrics.safe=safe;popup.queue_layout();await frames()
 root.size=Vector2i(1280,900);root.content_scale_size=Vector2i(1280,900);app.queue_layout_refresh();await frames(16)
 expect(app.keyword_glossary_ui==ui and ui.rows.get_node("KeywordEntry_pursuit").get_child(0) is HBoxContainer,"resizing across threshold rebuilds entries horizontally")
 check_popup("copy")
 await key(KEY_BACK);expect(KeywordGlossary.current==null and app.page=="keyword_glossary","Android Back closes definition and keeps glossary")
 KeywordGlossary.show_definition(app,"ward");await frames()
 await click(app.ui_metrics.safe.position+Vector2.ONE);await frames()
 expect(KeywordGlossary.current==null,"clicking popup shade closes definition")
 KeywordGlossary.show_definition(app,"ward");await frames()
 var touch=InputEventScreenTouch.new();touch.position=app.ui_metrics.safe.position+Vector2.ONE;touch.index=0;touch.pressed=true
 root.push_input(touch,true);await process_frame
 touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
 expect(KeywordGlossary.current==null,"releasing touch on popup shade closes definition")
 await key(KEY_BACK);expect(app.page=="tutorials","Android Back returns from glossary to tutorials")
 app.queue_free();await frames()
 print("KEYWORD GLOSSARY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
