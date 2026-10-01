extends "res://tests/support/ui_base.gd"
## Exercise the real deck editor's long saved-deck popup with touch events.

func frames(count: int=4):
 for i in range(count):await process_frame
func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/android-deck-dropdown-test/"+name+".png")

func selected_deck_index() -> int:
 for i in range(app.decks.size()):
  if app.decks[i].id==app.draft.id:return i
 return -1

func open_deck_menu() -> PopupMenu:
 app.saved_select.show_popup()
 await frames()
 return app.editor_ui.saved_deck_menu

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-deck-dropdown-test/fixtures-"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app)
 await frames()
 expect(not app.decks.is_empty(),"fixture includes a valid base deck")
 if app.decks.is_empty():quit(1);return
 var base=app.decks[0].duplicate(true)
 var fixture_error=""
 for i in range(48):
  var deck=base.duplicate(true)
  deck.id="android_dropdown_%03d" % i
  deck.name="安卓下拉测试 %03d" % i
  var error=Store.save_file(deck)
  if not error.is_empty():fixture_error=error;break
 expect(fixture_error.is_empty(),"48 extra deck fixtures are saved")
 app.is_android=true
 app.layout_dpi_override=240.0
 app.layout_safe_override=Rect2(40,0,1200,690)
 app.editor()
 app.editor_ui.set_overview(true)
 await frames()
 var popup=app.editor_ui.saved_deck_menu
 expect(popup!=null and popup.item_count>=49,"deck menu lists all decks")
 var chosen={"index":-1}
 popup.id_pressed.connect(func(index):chosen.index=index)
 popup=await open_deck_menu()
 await frames()
 print("POPUP ",popup.visible," POSITION ",popup.position," SIZE ",popup.size," ROOT ",root.size)
 expect(popup.visible,"top deck switch opens the saved-deck popup")
 expect(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(Rect2(Vector2(popup.position),Vector2(popup.size))),"saved-deck popup fits the visible screen")
 var probe=Vector2(popup.position)+Vector2(popup.size.x*0.5,popup.size.y*0.65)
 await click(probe)
 await frames()
 var first_index=chosen.index
 print("BASELINE INDEX ",first_index)
 expect(first_index>=0,"baseline tap selects a visible deck")
 popup=app.editor_ui.saved_deck_menu
 chosen.index=-1
 popup.id_pressed.connect(func(index):chosen.index=index)
 popup=await open_deck_menu()
 await frames()
 var popup_events={"touch":0,"drag":0}
 popup.window_input.connect(func(event):
  if event is InputEventScreenTouch:popup_events.touch+=1
  elif event is InputEventScreenDrag:popup_events.drag+=1)
 var start=probe
 var touch=InputEventScreenTouch.new();touch.index=0;touch.position=start;touch.pressed=true
 root.push_input(touch,true)
 for step in range(1,9):
  var drag=InputEventScreenDrag.new();drag.index=0;drag.position=start-Vector2(0,step*65)
  drag.relative=Vector2(0,-65);drag.screen_relative=drag.relative
  root.push_input(drag,true)
  await process_frame
 touch=touch.duplicate();touch.position=start-Vector2(0,8*65);touch.pressed=false;root.push_input(touch,true)
 await frames()
 print("AFTER DRAG POPUP ",popup.visible," EVENTS ",popup_events)
 expect(popup.visible,"drag keeps deck popup open")
 await shot("saved-deck-dropdown-after-swipe")
 if popup.visible:
  await click(probe)
  await frames()
 print("SWIPED INDEX ",chosen.index," CURRENT SELECTED ",selected_deck_index())
 var swiped_index=chosen.index if chosen.index>=0 else selected_deck_index()
 expect(swiped_index>first_index,"finger drag reaches later decks")
 popup=await open_deck_menu()
 await frames()
 popup.scroll_to_item(popup.item_count-1)
 await frames()
 var upper_probe=Vector2(popup.position)+Vector2(popup.size.x*0.5,popup.size.y*0.25)
 await click(upper_probe)
 await frames()
 var bottom_index=selected_deck_index()
 popup=await open_deck_menu()
 await frames()
 popup.scroll_to_item(popup.item_count-1)
 await frames()
 var down=InputEventScreenTouch.new();down.index=0;down.position=upper_probe;down.pressed=true
 root.push_input(down,true)
 for step in range(1,8):
  var move=InputEventScreenDrag.new();move.index=0;move.position=upper_probe+Vector2(0,step*65)
  move.relative=Vector2(0,65);move.screen_relative=move.relative
  root.push_input(move,true);await process_frame
 down=down.duplicate();down.position=upper_probe+Vector2(0,7*65);down.pressed=false;root.push_input(down,true)
 await frames()
 if popup.visible:await click(upper_probe)
 await frames()
 print("DOWN BASELINE ",bottom_index," AFTER SWIPE ",selected_deck_index())
 expect(selected_deck_index()<bottom_index,"finger drag downward reaches earlier decks")
 print("ANDROID DECK DROPDOWN: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
