extends "res://tests/support/ui_base.gd"
## Exercise the two Android views through the production scene and input routing.

func frames(count: int=6):
 for i in range(count):await process_frame

func touch(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func tap(at: Vector2):
 await touch(at,true);await touch(at,false);await frames()

func inspect_hold(at: Vector2):
 await touch(at,true);await create_timer(1.12).timeout;await touch(at,false);await frames()

func deck_tiles(node: Node,source: String) -> Array:
 var result=[]
 if node.get_script()==preload("res://scripts/deck_card.gd") and node.source_zone==source:result.append(node)
 for child in node.get_children():result.append_array(deck_tiles(child,source))
 return result

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-deck-"+name+".png")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-editor-tests/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=240
 app.draft=Store.blank("触屏卡组编辑测试");app.draft.rule_set="test";app.draft.leader="70"
 app.draft.main=["100","53","100","164","169"];app.draft.side=["165","167","165"]
 app.selected="100";app.editor();await frames(12)
 var ui=app.editor_ui
 expect(not ui.overview and ui.catalogue.is_visible_in_tree() and not ui.management.is_visible_in_tree(),"collection view opens with gallery and a single deck pane")
 expect(ui.catalogue_back.is_visible_in_tree() and app.ui_metrics.safe.grow(1).encloses(ui.catalogue_back.get_global_rect()),"collection exposes a return to main menu button inside the safe area")
 expect(ui.catalogue.get_global_rect().end.x<=ui.deck_panel.get_global_rect().position.x,"gallery is to the left of the deck")
 expect(app.library.columns==4 and app.library.get_child_count()==8 and app.library_rows.size()==8 and app.library_rows.values().all(func(item):return item.row.find_child("LibraryCardArt",true,false)!=null),"library shows four columns and two rows of card art")
 expect(app.library.get_child(0).global_position.y<app.library.get_child(6).global_position.y and app.library_rows.values().all(func(item):return ui.library_scroll.get_global_rect().grow(2).encloses(item.row.get_global_rect())),"all eight gallery cards fit in the visible two rows")
 var pagination=app.screen.find_child("LibraryPagination",true,false)
 var tutorial=app.screen.find_child("LibraryDeckTutorialButton",true,false) as Button
 expect(tutorial!=null and tutorial.is_visible_in_tree() and app.ui_metrics.safe.grow(1).encloses(tutorial.get_global_rect()),"deck tutorial is available on the library page")
 await tap(tutorial.get_global_rect().get_center())
 var guide=app.get_node_or_null("DeckTutorial") as AcceptDialog
 expect(guide!=null and guide.visible,"library tutorial button opens the guide")
 if guide!=null:expect("打开截图文件夹" not in guide.get_node("DeckTutorialText").text,"Android guide omits the removed folder action")
 if guide!=null:guide.hide();guide.queue_free()
 await frames()
 expect(ui.previous_library_page.get_global_rect().end.x<=ui.library_scroll.global_position.x and ui.next_library_page.global_position.x>=ui.library_scroll.get_global_rect().end.x and ui.previous_library_page.direction==-1 and ui.next_library_page.direction==1 and ui.previous_library_page.text.is_empty() and ui.next_library_page.text.is_empty(),"arrow shaped previous and next buttons flank the card area")
 expect(ui.library_page_label.text=="1 / "+str(ui.library_pages) and ui.previous_library_page.disabled and not ui.next_library_page.disabled,"pagination starts on the first page with the previous arrow disabled")
 var all_library_ids=app.library_ids()
 var library_draft_before=app.draft.duplicate(true);var dirty_before=app.dirty
 await tap(ui.next_library_page.get_global_rect().get_center())
 expect(ui.library_page==1 and app.library_rows.keys()==all_library_ids.slice(8,16) and not ui.previous_library_page.disabled,"next arrow shows the next eight cards in catalogue order")
 expect(app.draft==library_draft_before and app.dirty==dirty_before,"browsing library pages does not modify the deck")
 ui.set_overview(true);await frames();ui.set_overview(false);await frames()
 expect(ui.library_page==1 and app.library_rows.keys()==all_library_ids.slice(8,16),"switching views keeps the selected library page")
 app.refresh_responsive_layout();await frames(12);ui=app.editor_ui
 expect(ui.library_page==1 and app.library_rows.keys()==all_library_ids.slice(8,16),"rebuilding the layout keeps the selected library page")
 await tap(ui.previous_library_page.get_global_rect().get_center())
 expect(ui.library_page==0 and app.library_rows.keys()==all_library_ids.slice(0,8),"previous arrow returns to the first eight cards")
 ui.change_library_page(ui.library_pages-1);await frames()
 expect(ui.next_library_page.disabled and app.library_rows.keys()==all_library_ids.slice((ui.library_pages-1)*8) and app.library.get_child_count()==8,"last page keeps eight slots and disables the next arrow")
 var last_page=ui.library_page;ui.change_library_page(last_page+1)
 expect(ui.library_page==last_page,"paging beyond the last result stays at the final page")
 var paging_search=app.screen.find_child("LibrarySearch",true,false)
 paging_search.text="不存在的图鉴卡牌";paging_search.text_changed.emit(paging_search.text);await frames()
 expect(ui.library_page==0 and ui.library_pages==1 and app.library_rows.is_empty() and app.library.get_child_count()==8 and ui.previous_library_page.disabled and ui.next_library_page.disabled,"empty search resets pagination and leaves eight empty slots")
 paging_search.text="";paging_search.text_changed.emit("");await frames()
 expect(ui.library_page==0 and app.library_rows.keys()==all_library_ids.slice(0,8),"clearing search returns to the first page")
 var filter_pane=app.screen.find_child("LibraryFilters",true,false)
 var kind_filter=app.screen.find_child("LibraryKindFilter",true,false)
 var color_filters=app.screen.find_child("LibraryColorFilters",true,false)
 expect(not filter_pane.is_visible_in_tree() and ui.library_filter_button.is_visible_in_tree(),"type, color and sort controls stay in a hidden filter dialog")
 ui.toggle_library_filters();await frames()
 expect(app.color_buttons.keys()==["全部","红","蓝","绿","黄","黑"] and color_filters.get_children().map(func(choice):return choice.text)==["全部","红","蓝","绿","黄","黑"],"filter dialog shows all, red, blue, green, yellow and black in order")
 expect(kind_filter.get_global_rect().end.y<=color_filters.global_position.y and app.ui_metrics.safe.grow(2).encloses(filter_pane.get_global_rect()),"type filter sits above colors inside the dialog")
 for i in range(color_filters.get_child_count()):
  for j in range(i+1,color_filters.get_child_count()):
   expect(not color_filters.get_child(i).get_global_rect().intersects(color_filters.get_child(j).get_global_rect()),"color buttons "+str(i)+" and "+str(j)+" do not overlap")
 var kind_options=[]
 for i in range(kind_filter.item_count):kind_options.append(kind_filter.get_item_text(i))
 expect("自机符卡" in kind_options,"Android type filter includes character spells")
 ui.change_library_page(1);await frames()
 await tap(app.color_buttons["红"].get_global_rect().get_center())
 expect(ui.library_page==0 and app.selected_colors==["红"] and not ui.library_filtered_ids.is_empty() and ui.library_filtered_ids.all(func(id):return Store.CARDS[id].colors==["红"]),"color selection resets paging and shows exact red cards")
 await tap(app.color_buttons["蓝"].get_global_rect().get_center())
 expect(app.selected_colors==["红","蓝"] and ui.library_filtered_ids.all(func(id):return Store.CARDS[id].colors.size()==2 and "红" in Store.CARDS[id].colors and "蓝" in Store.CARDS[id].colors),"vertical filters retain combined color selection")
 await tap(app.color_buttons["全部"].get_global_rect().get_center())
 kind_filter.select(kind_options.find("自机符卡"));kind_filter.item_selected.emit(kind_filter.selected);await frames()
 expect(app.filter_kind=="自机符卡" and not ui.library_filtered_ids.is_empty() and ui.library_filtered_ids.all(func(id):return Store.CARDS[id].kind=="符卡" and (not Store.CARDS[id].requires_character.is_empty() or "角色" in Store.CARDS[id].spell_type)),"new type shows only character specific spells")
 ui.change_library_page(1);await frames()
 app.refresh_responsive_layout();await frames(12);ui=app.editor_ui
 kind_filter=app.screen.find_child("LibraryKindFilter",true,false)
 expect(app.filter_kind=="自机符卡" and ui.library_page==1 and kind_filter.get_item_text(kind_filter.selected)=="自机符卡","layout rebuild preserves the type filter and filtered page")
 ui.toggle_library_filters();await frames()
 await tap(app.color_buttons["红"].get_global_rect().get_center());await frames()
 expect(ui.library_page==0 and ui.library_filtered_ids.all(func(id):return Store.CARDS[id].kind=="符卡" and Store.CARDS[id].colors==["红"] and (not Store.CARDS[id].requires_character.is_empty() or "角色" in Store.CARDS[id].spell_type)),"type and color controls apply together")
 kind_filter.select(0);kind_filter.item_selected.emit(0)
 await tap(app.color_buttons["全部"].get_global_rect().get_center());await frames()
 expect(ui.library_filtered_ids==all_library_ids and app.filter_kind=="全部" and app.selected_colors.is_empty(),"all controls restore the unfiltered catalogue")
 ui.close_library_filters();await frames()
 expect(app.library_rows.values().all(func(item):return item.row.find_children("*","Label",true,false).size()==1 and item.row.find_child("LibraryRemaining",true,false).text.begins_with("余 ")),"gallery cards show only remaining inventory, including unlimited stock")
 var rows=deck_tiles(app.deck_canvas,"main")
 expect(rows.size()==4 and rows[0].source_index==0 and rows[1].source_index==1 and rows[2].source_index==3 and rows[1].position.y>rows[0].position.y,"deck groups duplicate copies while retaining their original source indices")
 expect(rows.all(func(row):return row.find_children("*","TextureRect",true,false).is_empty() and row.find_children("*","Label",true,false).size()==2) and rows[0].find_child("DeckListQuantity",true,false).text=="×2","right deck rows show only card names and right aligned copy counts")
 expect(rows.all(func(row):return row.find_child("DeckListName",true,false).global_position.x<row.find_child("DeckListQuantity",true,false).global_position.x) and deck_tiles(app.deck_canvas,"leader")[0].find_children("*","Label",true,false).size()==1,"quantity stays to the right and the leader has no cost or copy count")
 expect(app.main_card_rect(0)==app.main_card_rect(2) and app.deck_insert_index("main",Vector2(0,2*(ui.list_height+ui.deck_gap)))==3,"grouped row geometry maps duplicate cards and drop gaps to actual deck indices")
 var unchanged=app.draft.duplicate(true)
 await tap(ui.list_buttons.side.get_global_rect().get_center())
 rows=deck_tiles(app.deck_canvas,"side")
 expect(ui.list_zone=="side" and rows.size()==2 and rows[0].find_child("DeckListQuantity",true,false).text=="×2" and deck_tiles(app.deck_canvas,"main").is_empty(),"bottom button switches to only the grouped side deck list")
 expect(app.draft==unchanged and ui.list_switchers.get_global_rect().position.y>=app.counts.get_global_rect().end.y,"bottom list switching leaves the draft unchanged")
 app.refresh_responsive_layout();await frames(12);ui=app.editor_ui
 expect(ui.list_zone=="side" and ui.list_buttons.side.button_pressed and app.draft==unchanged,"rebuilding the Android layout preserves the selected deck list")
 await shot("side-list")
 await tap(ui.list_buttons.main.get_global_rect().get_center());rows=deck_tiles(app.deck_canvas,"main")
 var before=app.draft.duplicate(true)
 await tap(rows[0].get_global_rect().get_center())
 expect(is_instance_valid(ui.details_overlay) and app.draft==before,"short deck card tap opens details without changing the draft")
 ui.close_details();await frames()
 await inspect_hold(rows[0].get_global_rect().get_center())
 expect(is_instance_valid(ui.details_overlay) and app.draft==before,"deck card hold opens details without changing the draft")
 if not is_instance_valid(ui.details_overlay):quit(1);return
 var picture=app.preview.find_child("CardDetailsArt",true,false)
 var description=app.preview.find_child("CardDescriptionPane",true,false)
 expect(picture!=null and description!=null and picture.get_global_rect().position.x>=description.get_global_rect().end.x,"details put rules on the left and art on the right")
 var inventory=picture.get_node("CardDetailsRemaining")
 expect(inventory.text=="余 ∞" and picture.get_global_rect().encloses(inventory.get_global_rect()) and inventory.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT and inventory.vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM,"detail art shows unlimited inventory in its bottom right corner")
 expect(app.ui_metrics.safe.grow(2).encloses(ui.detail_popup.get_global_rect()),"details fit inside the safe area")
 await shot("details")
 find_button(app.preview,"移出卡组").pressed.emit();await frames()
 expect(app.draft.main==["53","100","164","169"] and app.dirty,"detail removal removes one actual copy from a grouped entry")
 expect(deck_tiles(app.deck_canvas,"main")[1].find_child("DeckListQuantity",true,false).text=="×1","removing one copy refreshes the grouped quantity")
 var search=app.screen.find_child("LibrarySearch",true,false)
 search.text="小妖梦";search.text_changed.emit(search.text);await frames()
 expect(app.library_rows.keys()==["39"],"gallery search retains shared card aliases")
 expect(app.library.get_child_count()==8 and ui.previous_library_page.disabled and ui.next_library_page.disabled,"single search result keeps its slot and seven empty slots")
 before=app.draft.duplicate(true)
 await tap(app.library_rows["39"].row.get_global_rect().get_center())
 expect(is_instance_valid(ui.details_overlay),"short gallery tap opens details")
 ui.close_details();await frames()
 await inspect_hold(app.library_rows["39"].row.get_global_rect().get_center())
 expect(is_instance_valid(ui.details_overlay) and app.selected=="39" and app.draft==before,"gallery card hold opens details without auto adding a card")
 find_button(app.preview,"加入主卡组").pressed.emit();await frames()
 expect(app.draft.main.back()=="39","details can add the inspected card to the main deck")
 find_button(app.preview,"加入副卡组").pressed.emit();await frames()
 expect(app.draft.side.count("39")==1,"details can add the inspected card to the side deck")
 ui.close_details();await frames()
 before=app.draft.duplicate(true)
 var source=app.library_rows["39"].row
 var target=deck_tiles(app.deck_canvas,"main")[0]
 await drag(source.get_global_rect().get_center(),target.get_global_rect().get_center())
 expect(app.draft==before and not source.draggable,"gallery mouse dragging cannot add or reorder cards")
 source=app.library_rows["39"].row;target=deck_tiles(app.deck_canvas,"main")[0]
 await touch(source.get_global_rect().get_center(),true);await create_timer(0.65).timeout
 var move=InputEventScreenDrag.new();move.index=0;move.position=target.get_global_rect().get_center();move.relative=move.position-source.get_global_rect().get_center()
 root.push_input(move,true);await frames();await touch(move.position,false);await frames()
 expect(app.draft==before and not root.gui_is_dragging(),"gallery finger hold and drag cannot modify the deck")
 app.draft.rule_set="official";app.update_deck_rows();ui.show_details("39");await frames()
 expect(app.preview.find_child("CardDetailsRemaining",true,false).text=="余 2","detail stock counts copies across the main and side decks")
 find_button(app.preview,"加入主卡组").pressed.emit();await frames()
 expect(app.preview.find_child("CardDetailsRemaining",true,false).text=="余 1" and not app.library_rows["39"].row.draggable,"adding a card refreshes detail stock without enabling gallery dragging")
 ui.close_details();await frames()
 await tap(ui.list_buttons.side.get_global_rect().get_center());await frames()
 rows=deck_tiles(app.deck_canvas,"side")
 var held_at=rows[0].get_global_rect().get_center();var side_before=app.draft.side.duplicate()
 await touch(held_at,true);await create_timer(0.65).timeout
 expect(app.draft.side==side_before and not root.gui_is_dragging(),"holding a list row for 650ms does not delete a card")
 await create_timer(0.45).timeout
 expect(app.draft.side==side_before and not root.gui_is_dragging() and not is_instance_valid(ui.details_overlay),"holding a side row leaves the deck and view unchanged until release")
 await touch(held_at,false);await frames()
 expect(app.draft.side==side_before and is_instance_valid(ui.details_overlay),"release after a long press opens details and preserves the deck")
 ui.close_details();await frames()
 await tap(ui.list_buttons.main.get_global_rect().get_center());await frames()
 rows=deck_tiles(app.deck_canvas,"main")
 before=app.draft.duplicate(true)
 await drag(rows[1].get_global_rect().get_center(),rows[0].get_global_rect().position+Vector2(20,5))
 expect(app.draft==before and rows.all(func(row):return not row.draggable),"right list mouse dragging cannot reorder cards")
 app.main_scroll.scroll_vertical=0;await frames()
 rows=deck_tiles(app.deck_canvas,"main")
 held_at=rows[0].get_global_rect().get_center()
 await touch(held_at,true);await create_timer(1.1).timeout
 expect(app.draft==before and not root.gui_is_dragging() and not is_instance_valid(ui.details_overlay),"holding a main row leaves cards unchanged until release")
 await touch(held_at,false);await frames()
 expect(is_instance_valid(ui.details_overlay),"releasing a main row opens its details")
 ui.show_details("68");await frames()
 expect(find_button(app.preview,"设为自机")!=null and find_button(app.preview,"加入主卡组")!=null and find_button(app.preview,"加入副卡组")!=null,"leader unit details offer leader selection and both deck additions")
 find_button(app.preview,"加入主卡组").pressed.emit();await frames()
 find_button(app.preview,"加入副卡组").pressed.emit();await frames()
 expect(app.draft.main.count("68")==1 and app.draft.side.count("68")==1 and app.draft.leader=="70" and app.preview.find_child("CardDetailsRemaining",true,false).text=="余 2","leader units can join both decks through the existing inventory rules")
 ui.close_details();ui.show_details("70");await frames()
 expect(app.preview.find_child("CardDetailsRemaining",true,false).text=="余 0","current leader's same-name inventory remains unavailable to main and side decks")
 ui.close_details();app.draft.rule_set="test";app.update_deck_rows();await frames()
 # Switches and rebuilds preserve dirty edits and search.
 before=app.draft.duplicate(true)
 await click(ui.view_switch.get_global_rect().get_center());await frames(12)
 expect(ui.overview and not ui.catalogue.visible and ui.management.is_visible_in_tree(),"switch opens full deck view and its management controls")
 var deck_tutorial=app.screen.find_child("LibraryDeckTutorialButton",true,false) as Button
 expect(deck_tutorial!=null and not deck_tutorial.is_visible_in_tree(),"deck tutorial button stays on the library page")
 expect(not ui.list_switchers.visible,"bottom list buttons are limited to the gallery view")
 expect(app.draft==before and app.dirty and app.query=="小妖梦","switch preserves the draft, dirty state and query")
 expect(ui.management.get_children().map(func(button):return button.text)==["保存","套牌广场",app.deck_upload_caption(),"菜单","返回主菜单"] and not ui.catalogue_back.visible,"deck page removes use and places return to menu on the last row")
 ui.tools_menu.pressed.emit();await frames()
 expect(app.saved_select.is_visible_in_tree() and ui.rules_menu.item_count==app.RuleSet.IDS.size() and app.menu_popup.actions[0].text=="导出代码","deck and rule switching stay visible while other tools are grouped inside the menu")
 app.close_menu_popup()
 expect(ui.switchers.get_global_rect().end.y<=ui.columns.global_position.y,"deck and rule switches sit at the top above the deck")
 expect(ui.grid.columns==10 and ui.side_grid.columns==2 and ui.deck_panel.size.x>app.screen.size.x*0.95,"overview has ten main columns and two side columns across the full width")
 rows=deck_tiles(ui.grid,"main")
 var moving=rows[1].card_id
 await drag(rows[1].get_global_rect().get_center(),rows[0].get_global_rect().position+Vector2(1,5));await frames()
 expect(app.draft.main[0]==moving,"deck page retains card drag reordering")
 before=app.draft.duplicate(true);rows=deck_tiles(ui.grid,"main");held_at=rows[0].get_global_rect().get_center()
 await touch(held_at,true);await create_timer(0.65).timeout
 expect(not root.gui_is_dragging() and not is_instance_valid(ui.details_overlay) and app.draft==before,"overview holds do not drag or inspect before one second")
 await create_timer(0.47).timeout
 expect(not is_instance_valid(ui.details_overlay) and app.draft==before,"overview hold waits for release before inspection")
 await touch(held_at,false);await frames()
 expect(not root.gui_is_dragging() and app.draft==before and is_instance_valid(ui.details_overlay),"releasing an overview card opens details without changing the draft")
 ui.close_details();await frames()
 await shot("overview")
 for dimensions in [Vector2i(1280,720),Vector2i(2400,1080)]:
  root.size=dimensions;app.layout_dpi_override=float(dimensions.y)/3.0
  app.layout_safe_override=Rect2(40,0,dimensions.x-64,dimensions.y-24)
  await frames();app.refresh_responsive_layout();await frames(12)
  ui=app.editor_ui
  expect(ui.overview and app.draft==before,"resizing preserves the chosen view and draft")
  var safe=app.ui_metrics.safe.grow(2)
  expect(safe.encloses(ui.columns.get_global_rect()) and safe.encloses(ui.overview_menu.get_global_rect()) and safe.encloses(ui.toolbar.get_global_rect()),"overview controls fit the safe area at "+str(dimensions))
  ui.set_overview(false);await frames(12)
  expect(safe.encloses(ui.columns.get_global_rect()) and ui.catalogue.size.x>ui.deck_panel.size.x,"collection gives card art more space at "+str(dimensions))
  expect(app.library.columns==4 and app.library.get_child_count()==8 and ui.library_scroll.get_global_rect().grow(2).encloses(app.library.get_global_rect()) and safe.encloses(app.screen.find_child("LibraryPagination",true,false).get_global_rect()),"two gallery rows and arrows fit the safe area at "+str(dimensions))
  ui.toggle_library_filters();await frames()
  expect(safe.encloses(ui.library_filter_popup.get_global_rect()) and app.color_buttons.values().all(func(choice):return choice.size.y>=app.ui_metrics.hit and ui.library_filter_popup.get_global_rect().encloses(choice.get_global_rect())),"filter dialog fits with restored mobile touch targets at "+str(dimensions))
  ui.close_library_filters()
  expect(app.library.get_h_scroll_bar()==null if app.library is ScrollContainer else app.library.get_parent().get_h_scroll_bar().max_value<=app.library.get_parent().get_h_scroll_bar().page+1,"gallery fits without horizontal overflow")
  await shot("collection-"+str(dimensions.x))
  ui.set_overview(true);await frames()
 root.size=Vector2i(1280,720);app.layout_dpi_override=240;app.layout_safe_override=Rect2()
 await frames()
 app.draft=app.decks[0].duplicate(true);app.dirty=false;app.query="";app.android_editor_overview=false;app.editor();await frames(12)
 ui=app.editor_ui
 var gallery_first=app.library_rows.values()[0].row
 var scroll_before=ui.library_scroll.scroll_vertical
 var swipe_at=gallery_first.get_global_rect().get_center()
 before=app.draft.duplicate(true)
 await touch(swipe_at,true)
 var swipe=InputEventScreenDrag.new();swipe.index=0;swipe.position=swipe_at-Vector2(0,160);swipe.relative=Vector2(0,-160)
 root.push_input(swipe,true);await frames();await touch(swipe.position,false);await create_timer(0.65).timeout
 expect(ui.library_scroll.scroll_vertical==scroll_before and ui.library_page==0 and app.draft==before and not root.gui_is_dragging() and not is_instance_valid(ui.details_overlay),"gallery finger swipe leaves the fixed page unchanged without dragging, inspecting or modifying cards")
 ui.library_scroll.scroll_vertical=0;await frames()
 await shot("collection")
 ui.show_details("100");await frames();await shot("details");ui.close_details()
 ui.set_overview(true);await frames(12);await shot("overview")
 for main_count in [50,70]:
  app.dirty=true
  app.draft.rule_set="test";app.draft.main.clear();app.draft.side.clear()
  for i in range(main_count):app.draft.main.append(["100","53","164","169"][i%4])
  for i in range(10):app.draft.side.append(["165","167"][i%2])
  for dimensions in [Vector2i(1280,720),Vector2i(2400,1080)]:
   root.size=dimensions;app.layout_dpi_override=float(dimensions.y)/3.0;await frames()
   if DisplayServer.get_name()=="headless":expect(root.size==dimensions,"headless viewport uses the requested screen size without desktop window clamping")
   app.refresh_responsive_layout();await frames(12);ui=app.editor_ui
   expect(app.draft.main.size()==main_count and app.draft.side.size()==10 and ui.grid.get_child_count()==50 and deck_tiles(ui.grid,"main").size()==mini(50,main_count),"fixed grid retains all %d + 10 cards with fifty main slots per page" % main_count)
   expect(app.ui_metrics.safe.grow(2).encloses(ui.columns.get_global_rect()) and app.ui_metrics.safe.grow(2).encloses(app.counts.get_global_rect()),"full deck and counts remain inside the safe area at "+str(dimensions))
   var main_area=app.main_scroll.get_global_rect().grow(1)
   var side_area=ui.side_scroll.get_global_rect().grow(1)
   expect(ui.grid.get_children().all(func(tile):return main_area.encloses(tile.get_global_rect())),"all fifty main slots fit without scrolling at "+str(dimensions))
   expect(ui.side_grid.get_children().all(func(tile):return side_area.encloses(tile.get_global_rect())),"all 10 side cards fit without scrolling at "+str(dimensions))
   expect(ui.grid.get_global_rect().end.x<=ui.side_grid.get_global_rect().position.x and ui.grid.columns==10 and ui.side_grid.columns==2,"main 10 by 5 grid is to the left of the side 2 by 5 grid")
   var frame=app.main_content.get_node("MainDeckFrame").get_global_rect()
   expect(frame.position.is_equal_approx(ui.grid.global_position) and frame.size.is_equal_approx(ui.grid.size),"main deck frame wraps the card grid without blank margins")
   expect(ui.overview_menu.get_global_rect().position.x>=side_area.end.x-1 and app.ui_metrics.safe.grow(2).encloses(ui.overview_menu.get_global_rect()),"expanded menu fills the right side inside the safe area")
   expect(ui.management.get_children().all(func(button):return ui.overview_menu.get_global_rect().encloses(button.get_global_rect())),"all five sidebar controls fit without menu scrolling")
   expect(deck_tiles(app.deck_canvas,"leader")[0].size.x>ui.tile_size.x*2,"leader art expands to use the available space")
   expect(ui.grid.get_child(40).position.y>ui.grid.get_child(30).position.y and ui.side_grid.get_child(8).position.y>ui.side_grid.get_child(6).position.y and absf(ui.grid.get_child(0).global_position.y-ui.side_grid.get_child(0).global_position.y)<2,"both grids align vertically and have five rows")
   expect(app.main_scroll.get_v_scroll_bar().max_value<=app.main_scroll.get_v_scroll_bar().page+1,"full deck has no vertical overflow at "+str(dimensions))
   await shot("overview-%d-%d" % [main_count,dimensions.x])
   if main_count>50:
    var page_before=app.draft.duplicate(true)
    app.screen.find_child("NextMainPage",true,false).pressed.emit();await frames(12);ui=app.editor_ui
    var page_cards=deck_tiles(ui.grid,"main")
    expect(ui.main_page==1 and page_cards.size()==main_count-50 and page_cards[0].source_index==50 and page_cards.back().source_index==main_count-1 and app.draft==page_before,"next page exposes every extra card without changing the deck or absolute indices")
    expect(app.deck_insert_index("main",app.main_card_rect(51).position+Vector2(0,5))==51,"second page gaps resolve to absolute deck indices")
    await shot("overview-page-2-"+str(dimensions.x))
    app.refresh_responsive_layout();await frames(12);ui=app.editor_ui
    expect(ui.main_page==1,"resizing or rebuilding keeps the selected main deck page")
    app.screen.find_child("PreviousMainPage",true,false).pressed.emit();await frames(12);ui=app.editor_ui
    expect(ui.main_page==0 and deck_tiles(ui.grid,"main")[0].source_index==0,"previous page returns to the first fifty cards")
 ui.set_overview(false);await frames(12)
 app.dirty=true;var draft_before_return=app.draft.duplicate(true)
 ui.catalogue_back.pressed.emit();await frames()
 var confirmation=null
 for child in app.get_children():
  if child is ConfirmationDialog and child.visible:confirmation=child
 expect(confirmation!=null and app.page=="editor" and app.draft==draft_before_return,"collection return protects unsaved edits with the existing confirmation")
 if confirmation!=null:confirmation.canceled.emit();await frames()
 expect(app.page=="editor" and app.dirty and app.draft==draft_before_return,"canceling return keeps the unsaved deck")
 app.dirty=false;ui.catalogue_back.pressed.emit();await frames()
 expect(app.page=="menu","collection return opens the main menu")
 app.android_editor_overview=true;app.editor();await frames(12);ui=app.editor_ui
 ui.management.get_child(ui.management.get_child_count()-1).pressed.emit();await frames()
 expect(app.page=="menu","last deck page row returns to the main menu")
 print("ANDROID DECK EDITOR: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
