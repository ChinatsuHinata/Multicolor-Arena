extends "res://tests/support/ui_base.gd"
## Current Android collection layout and filter dialog at common landscape sizes.

func frames(count: int=8):
 for i in range(count):await process_frame

func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-gallery-"+name+".png")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-gallery-tests/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=240
 app.draft=Store.blank("安卓组卡布局测试");app.draft.rule_set="test"
 app.editor();await frames(16)
 for dimensions in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(2670,1200),Vector2i(2670,1200)]:
  root.size=dimensions
  app.layout_dpi_override=(560.0 if app.layout_dpi_override==440.0 else 440.0) if dimensions.x==2670 else float(dimensions.y)/3.0
  app.layout_safe_override=Rect2(24,0,dimensions.x-48,dimensions.y-18)
  app.refresh_responsive_layout();await frames(16)
  var ui=app.editor_ui
  var safe=app.ui_metrics.safe.grow(2)
  expect(app.library.columns==4 and app.library.get_child_count()==8 and app.library_rows.size()==8,"gallery has 4 columns and 2 rows at "+str(dimensions))
  var slots=app.library.get_children()
  expect(slots[0].global_position.x<slots[1].global_position.x and slots[2].global_position.x<slots[3].global_position.x and absf(slots[0].global_position.y-slots[3].global_position.y)<2 and slots[0].global_position.y<slots[4].global_position.y and absf(slots[4].global_position.y-slots[7].global_position.y)<2,"gallery cards occupy two rows of four at "+str(dimensions))
  expect(slots.all(func(card):return ui.library_scroll.get_global_rect().grow(2).encloses(card.get_global_rect())),"all eight cards fit the gallery viewport at "+str(dimensions))
  expect(slots.all(func(card):var art=card.find_child("LibraryCardArt",true,false);return art.size.y>=100 and art.size.x>=80 and art.texture!=null),"actual card art has useful dimensions and loaded textures at "+str(dimensions))
  expect(slots.all(func(card):var art=card.find_child("LibraryCardArt",true,false);return card.get_global_rect().grow(2).encloses(art.get_global_rect()) and absf(art.size.y/art.size.x-1.397)<0.01),"gallery keeps every portrait face complete without stretching or cropping")
  expect(slots.all(func(card):var art=card.find_child("LibraryCardArt",true,false);var stock=card.find_child("LibraryRemaining",true,false);return card.get_global_rect().grow(2).encloses(stock.get_global_rect()) and stock.global_position.y>=art.get_global_rect().end.y and absf(stock.get_global_rect().get_center().x-art.get_global_rect().get_center().x)<2),"inventory is centered below each full card face without covering art")
  var search=app.screen.find_child("LibrarySearch",true,false)
  expect(ui.library_search_bar.get_parent()==ui.toolbar and absf(search.global_position.y-ui.catalogue_back.global_position.y)<4,"search and filters share the top toolbar")
  expect(ui.previous_library_page.get_global_rect().end.x<=ui.library_scroll.global_position.x and ui.next_library_page.global_position.x>=ui.library_scroll.get_global_rect().end.x,"page arrows sit on either side of the card area")
  expect(safe.encloses(ui.library_filter_button.get_global_rect()) and safe.encloses(ui.next_library_page.get_global_rect()),"filter and page buttons remain in the safe area at "+str(dimensions))
  expect(ui.catalogue_back.size.y>=app.ui_metrics.hit and ui.catalogue_back.get_theme_font_size("font_size")==app.ui_metrics.button_font and ui.library_filter_button.size.y>=app.ui_metrics.hit and ui.next_library_page.custom_minimum_size.is_equal_approx(Vector2(app.ui_metrics.hit*1.45,app.ui_metrics.hit)),"toolbar buttons and page arrows use the restored mobile dimensions")
  expect(safe.encloses(ui.toolbar.get_global_rect()) and ui.library_search_bar.get_global_rect().end.x<=ui.catalogue_back.global_position.x and ui.catalogue_back.get_global_rect().end.x<=ui.view_switch.global_position.x,"restored top controls fit without overlap")
  var choose=app.screen.find_child("ChooseDeckLeader",true,false) as Button
  expect(choose!=null and safe.encloses(choose.get_global_rect()) and choose.size.x<ui.deck_panel.size.x*0.7 and choose.size.y<=app.ui_metrics.hit,"compact choose-leader button remains clickable at "+str(dimensions))
  expect(not ui.library_filter_overlay.visible and app.screen.find_child("LibraryKindFilter",true,false)!=null and app.screen.find_child("LibrarySortChoice",true,false)!=null,"type, color and sort filters live in a hidden dialog")
  expect(app.counts.text=="0/%d·0/10" % app.RuleSet.main_limit(app.draft.rule_set) and app.main_content.find_children("*","Label",true,false).all(func(label):return label.text not in ["自机","主卡组  0"]),"deck list removes redundant headings and uses numeric counts")
  await capture(str(dimensions.x)+"-collection")
  ui.toggle_library_filters();await frames()
  expect(ui.library_filter_overlay.visible and safe.encloses(ui.library_filter_popup.get_global_rect()),"filter dialog opens inside the safe area at "+str(dimensions))
  var kind=app.screen.find_child("LibraryKindFilter",true,false)
  var sort=app.screen.find_child("LibrarySortChoice",true,false)
  var colors=app.screen.find_child("LibraryColorFilters",true,false)
  expect(kind.is_visible_in_tree() and colors.is_visible_in_tree() and colors.columns==3 and sort.is_visible_in_tree(),"type, six colors and sorting share the filter dialog")
  var color_view=app.screen.find_child("LibraryColorScroll",true,false)
  expect(app.color_buttons.values().all(func(button):return button.size.y>=app.ui_metrics.hit and color_view.get_global_rect().grow(2).encloses(button.get_global_rect())),"all color choices have restored touch sizes inside the filter viewport")
  await capture(str(dimensions.x)+"-filters")
  var before=app.draft.duplicate(true)
  app.color_buttons["红"].pressed.emit();await frames()
  expect(app.selected_colors==["红"] and ui.library_page==0 and app.draft==before,"filtering changes the catalogue without editing the deck")
  app.color_buttons["蓝"].pressed.emit();await frames()
  expect(app.selected_colors==["红","蓝"] and app.color_buttons["红"].button_pressed and app.color_buttons["蓝"].button_pressed,"color choices support simultaneous selection")
  ui.close_library_filters();await frames()
  expect(not ui.library_filter_overlay.visible,"filter dialog closes while retaining selected filters")
  ui.set_overview(true);await frames()
  expect(app.name_label.get_parent()==ui.toolbar and app.name_label.text.begins_with("安卓组卡布局测试"),"deck name moves into the overview toolbar")
  var hero=app.screen.find_child("OverviewLeaderPane",true,false)
  expect(app.counts.get_parent()==hero and safe.encloses(app.counts.get_global_rect()) and app.counts.position.y>hero.get_child(1).position.y,"overview counts appear below the leader image inside the screen")
  expect(safe.encloses(ui.toolbar.get_global_rect()) and safe.encloses(ui.columns.get_global_rect()) and safe.encloses(ui.overview_menu.get_global_rect()),"overview contains the restored controls within the safe area")
  var last_button=ui.management.get_child(ui.management.get_child_count()-1)
  ui.management_scroll.scroll_vertical=99999;await frames()
  expect(ui.management_scroll.get_global_rect().grow(2).encloses(last_button.get_global_rect()),"overview management can reveal its last button without shrinking touch targets")
  await capture(str(dimensions.x)+"-overview")
  ui.set_overview(false);await frames()
  expect(app.name_label.get_parent()==ui.center,"collection keeps the deck name in the compact deck pane")
  expect(ui.list_height<app.ui_metrics.hit and ui.list_height<app.ui_metrics.body*2.4,"deck list rows are compact")
  app.selected_colors.clear();app.refresh_color_buttons();app.update_library();await frames()
 app.queue_free();await process_frame
 print("ANDROID DECK GALLERY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
