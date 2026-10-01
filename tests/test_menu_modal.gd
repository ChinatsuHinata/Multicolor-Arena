extends "res://tests/support/ui_base.gd"
var background_clicks=0

func frames(count: int=6):
 for i in range(count):await process_frame

func key(code: int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func touch(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
 root.push_input(event,true);await process_frame

func tap(at: Vector2):
 await touch(at,true);await touch(at,false);await frames()

func swipe(from: Vector2,to: Vector2):
 await touch(from,true)
 for i in range(1,7):
  var event=InputEventScreenDrag.new();event.index=0;event.position=from.lerp(to,float(i)/6)
  root.push_input(event,true);await process_frame
 await touch(to,false);await frames()

func check_shell(title: String):
 var popup=app.menu_popup
 expect(popup is CanvasLayer and popup.layer==popup.TOP_LAYER and popup.layer>0,title+" uses a separate top canvas")
 expect(popup.backdrop.get_global_rect().encloses(root.get_visible_rect()) and popup.backdrop.mouse_filter==Control.MOUSE_FILTER_STOP,title+" blocks the full viewport")
 expect(app.ui_metrics.safe.grow(1).encloses(popup.panel.get_global_rect()) and popup.panel.get_global_rect().get_center().distance_to(app.ui_metrics.safe.get_center())<1,title+" is centered within the safe area")
 expect(popup.actions.all(func(button):return button.size.y>=64 if app.is_android else button.size.y>=app.ui_metrics.hit),title+" keeps all actions touch sized")
 var close=popup.close_button
 expect(close.get_theme_font("font").get_string_size(close.text,HORIZONTAL_ALIGNMENT_LEFT,-1,close.get_theme_font_size("font_size")).x<=close.size.x-close.get_theme_stylebox("normal").get_minimum_size().x,title+" keeps the close label visible")

func check_deck_grid():
 var popup=app.menu_popup
 expect(popup.scroll==null and popup.grid is GridContainer and popup.grid.columns==2,"deck menu uses two columns without a scroll container")
 expect(popup.actions.size()==8 and popup.actions.all(func(button):return button.is_visible_in_tree() and popup.panel.get_global_rect().encloses(button.get_global_rect())),"all eight deck actions are visible inside the popup")
 var paired=true
 for i in range(0,popup.actions.size(),2):
  var left=popup.actions[i].get_global_rect();var right=popup.actions[i+1].get_global_rect()
  paired=paired and is_equal_approx(left.position.y,right.position.y) and left.end.x<right.position.x
 expect(paired,"deck actions fill four rows of two buttons")
 expect(popup.actions.all(func(button):return button.text not in ["打开截图文件夹","组卡教程"]),"Android deck menu omits the folder and tutorial actions")
 expect(popup.actions.all(func(button):return button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x<=button.size.x-button.get_theme_stylebox("normal").get_minimum_size().x),"deck action captions fit without truncation")

func probe(parent: Node) -> Button:
 var button=app.button(parent,"背景按钮",Rect2(24,340,160,70),func():background_clicks+=1)
 button.z_index=RenderingServer.CANVAS_ITEM_Z_MAX
 return button

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/menu-modal-tests/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.layout_dpi_override=320
 app.layout_safe_override=Rect2(30,12,1220,690)
 app.draft=Store.blank("菜单遮挡测试");app.draft.rule_set="test";app.draft.leader="70"
 app.draft.main=["100","53","164","169"];app.draft.side=["165","167"]
 app.selected="100";app.android_editor_overview=true;app.editor();await frames(12)
 var ui=app.editor_ui
 await tap(ui.tools_menu.get_global_rect().get_center())
 expect(app.menu_popup_open(),"deck menu opens from its production button")
 check_shell("deck menu")
 var deck_before=app.draft.duplicate(true)
 var background=probe(app.screen)
 await click(background.get_global_rect().get_center());await tap(background.get_global_rect().get_center())
 await tap(ui.view_switch.get_global_rect().get_center())
 await tap(find_button(ui.management,"返回主菜单").get_global_rect().get_center())
 expect(background_clicks==0 and app.page=="editor" and ui.overview and app.draft==deck_before and app.menu_popup_open(),"deck menu blocks late high-z buttons, view switching and navigation by mouse and touch")
 var popup=app.menu_popup
 check_deck_grid()
 await capture("deck-modal-menu")
 await tap(popup.close_button.get_global_rect().get_center())
 expect(not app.menu_popup_open(),"deck menu closes through its own close button")
 await tap(background.get_global_rect().get_center())
 expect(background_clicks==1,"background controls work again after closing the deck menu")
 await tap(ui.tools_menu.get_global_rect().get_center())
 popup=app.menu_popup
 await tap(popup.actions[3].get_global_rect().get_center())
 expect(not app.menu_popup_open() and app.get_children().any(func(child):return child is ConfirmationDialog and child.visible),"menu action closes the menu before opening the rename dialog")
 for child in app.get_children():
  if child is ConfirmationDialog:child.hide();child.queue_free()
 await frames()
 ui.tools_menu.pressed.emit();await frames()
 await key(KEY_ESCAPE)
 expect(not app.menu_popup_open(),"Escape closes the deck menu")
 app.layout_dpi_override=480;app.refresh_ui_metrics()
 ui.tools_menu.pressed.emit();await frames()
 check_shell("dense Android deck menu");check_deck_grid()
 var deck_entries=[]
 for action in app.menu_popup.actions:deck_entries.append([action.text,func():pass])
 app.close_menu_popup()
 for dimensions in [Vector2i(700,900),Vector2i(540,900),Vector2i(380,900),Vector2i(320,900),Vector2i(540,480),Vector2i(380,480)]:
  root.content_scale_size=dimensions;root.size=dimensions
  app.layout_dpi_override=320;app.layout_safe_override=Rect2(Vector2.ZERO,Vector2(dimensions))
  app.refresh_ui_metrics();await frames()
  app.open_menu_popup("组卡菜单",deck_entries,2);await frames()
  check_shell("narrow "+str(dimensions)+" deck menu");check_deck_grid()
  if dimensions==Vector2i(320,900):await capture("deck-modal-narrow-320")
  app.close_menu_popup()
 root.content_scale_size=Vector2i(1600,900);root.size=Vector2i(1280,720)
 app.layout_safe_override=Rect2(30,12,1220,690)
 app.layout_dpi_override=320;app.refresh_ui_metrics();await frames()
 app.open_menu_popup("组卡菜单",deck_entries,2);await frames()
 app.menu();await frames()
 expect(not app.menu_popup_open() and app.screen.find_child("ModalMenu",true,false)==null,"page changes remove the modal and its input blocker")

 for mobile in [true,false]:
  background_clicks=0
  app.is_android=mobile;app.debug_mode=not mobile
  app.layout_safe_override=Rect2();app.layout_dpi_override=240 if mobile else 0
  app.begin_battle(true);view=app.duel_view;e=view.engine;await settle()
  clean(not mobile);put("53","field");put("100","hand");view.render();await settle()
  var menu_button=view.hud.find_child("BattleTools",true,false)
  await click(menu_button.get_global_rect().get_center());await frames()
  expect(app.menu_popup_open(),"battle menu opens from the "+("Android" if mobile else "PC")+" toolbar")
  check_shell("battle menu")
  var state_before=snapshot();var response_before=view.response_mode
  var camera_before=view.table.camera.global_transform
  var observation_before=view.observing;var selected_before=view.selection.duplicate()
  background=probe(view.ui)
  await click(background.get_global_rect().get_center());await tap(background.get_global_rect().get_center())
  await click(view.observe_button.get_global_rect().get_center())
  await click(find_button(view.hud,"全响应").get_global_rect().get_center())
  if mobile:await tap(view.android_back_button.get_global_rect().get_center())
  await swipe(view.STAGE.get_center(),view.STAGE.get_center()+Vector2(120,30))
  for code in [KEY_Q,KEY_A,KEY_G,KEY_H]:await key(code)
  expect(background_clicks==0 and view.observing==observation_before and view.response_mode==response_before and view.selection==selected_before and not view.debug_open,"battle menu blocks background buttons, observation, back, responses and shortcuts")
  expect(snapshot()==state_before and view.table.camera.global_transform==camera_before and app.menu_popup_open(),"battle menu blocks gameplay and camera gestures while keeping the menu open")
  view.refresh_observation();view.render();await frames()
  expect(app.menu_popup_open(),"HUD rebuilding and persistent controls stay beneath the battle menu")
  await click(background.get_global_rect().get_center())
  expect(background_clicks==0,"background remains blocked after HUD rebuilding")
  await capture("battle-modal-menu-"+("android" if mobile else "pc"))
  popup=app.menu_popup
  await click(popup.actions[1].get_global_rect().get_center());await frames()
  expect(not app.menu_popup_open() and view.history_open,"battle menu action opens the match history")
  view.close_history();await frames()
  view.open_tools_menu();await frames();view.android_back();await frames()
  expect(not app.menu_popup_open(),"battle back closes the top menu")
  await click(background.get_global_rect().get_center())
  expect(background_clicks==1,"battle background controls resume after closing")
  app.menu();await frames()
 print("MENU MODAL: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
