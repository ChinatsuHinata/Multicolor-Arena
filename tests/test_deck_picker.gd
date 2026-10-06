extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
var output="res://work/deck-picker-tests"

func frames(count: int=5):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(title+".png"))

func key(code: Key):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 root.push_input(event,true);await frames()

func set_search(picker,value: String):
 picker.search.text=value;picker.search.text_changed.emit(value)

func activate(button: Button):
 var ancestor=button.get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
  ancestor=ancestor.get_parent()
 await frames()
 if app.is_android:
  var event=InputEventScreenTouch.new();event.index=0;event.position=button.get_global_rect().get_center();event.pressed=true
  root.push_input(event,true);await process_frame
  event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
 else:await click(button.get_global_rect().get_center());await frames()

func choose_fixture(id: String):
 var picker=app.deck_picker_ui
 if picker==null:expect(false,"selection button opens the gallery");return
 set_search(picker,"检索样本 编号"+id.trim_prefix("picker_"))
 await frames()
 var tiles=picker.grid.get_children().filter(func(node):return node is Button)
 expect(tiles.size()==1 and tiles[0].get_meta("deck_id","")==id,"search resolves exactly the intended deck")
 if not tiles.is_empty():await activate(tiles[0])

func check_layout(picker):
 var safe=app.screen.get_global_rect().grow(1)
 for control in [picker.search,picker.notice,picker.previous_button,picker.next_button,picker.find_child("DeckPickerBack",true,false)]:
  expect(safe.encloses(control.get_global_rect()),"search, navigation and return controls fit the usable screen")
 expect(picker.grid.get_child_count()<=picker.page_size,"gallery paginates the saved collection")
 for tile in picker.grid.get_children():
  expect(picker.gallery.get_global_rect().grow(1).encloses(tile.get_global_rect()),"deck tile fits inside gallery")
  if tile is Button:
   var content=tile.get_child(0)
   for child in content.find_children("*","Label",true,false):
    expect(tile.get_global_rect().grow(1).encloses(child.get_global_rect()),"deck metadata fits inside tile")

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 var base=app.decks[0].duplicate(true)
 for i in range(14):
  var deck=base.duplicate(true);deck.id="picker_%02d" % i;deck.name="检索样本 编号%02d" % i
  deck.rule_set="test";deck.leader="70" if i%2==0 else "68"
  deck.main=["100","53"];deck.side=["39"]
  if i==11:
   deck.leader="character-fdf-117";deck.main=["64","soi_unit_086","100"];deck.side=["64"]
  if i==12:
   deck.main=Store.CARDS.keys().filter(func(id):return Store.CARDS[id].get("constructible",false) and Store.excludes_deck_colors(id)).slice(0,10)
   deck.side=[]
  if i==13:deck.art_overrides={"70":"tts_151600"};deck.leader="70"
  expect(Store.save_file(deck).is_empty(),"saved deck fixture")
 for android in [false,true]:
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if android else Window.CONTENT_SCALE_ASPECT_KEEP
  app.is_android=android;app.layout_dpi_override=360 if android else 0
  app.layout_safe_override=Rect2(40,0,1200,690) if android else Rect2()
  app.setup();await frames()
  var source=app.screen
  var player_id=app.decks[app.player_choice].id
  var ai_id=app.decks[app.ai_choice].id
  var player=app.screen.find_child("PlayerDeckSelect",true,false)
  expect(player is Button and not player is OptionButton,"match setup uses buttons instead of deck dropdowns")
  await activate(player)
  expect(app.deck_picker_open() and app.screen==source,"selection opens the shared gallery over the preserved source screen")
  var picker=app.deck_picker_ui
  check_layout(picker)
  await shot("android" if android else "desktop")
  if android:
   await activate(picker.color_toggle)
   expect(picker.color_row.visible,"Android color filters expand on demand")
   check_layout(picker);await shot("android-colors")
   await activate(picker.color_toggle)
  else:
   for i in range(22):
    await key(KEY_TAB)
    expect(picker.is_ancestor_of(root.gui_get_focus_owner()),"keyboard focus stays inside the deck selection screen")
  await activate(picker.next_button)
  expect(picker.page_index==1,"next page reaches decks outside the first page")
  set_search(picker,"不存在的套牌检索词");await frames()
  expect(picker.matches.is_empty() and picker.previous_button.disabled and picker.next_button.disabled,"empty search gives a message and disables pagination")
  set_search(picker,"检索样本 编号13");await frames()
  expect(picker.matches.size()==1 and picker.page_index==0,"search resets pagination and combines terms")
  if android:
   root.size=Vector2i(2340,1080);app.layout_dpi_override=240;app.layout_safe_override=Rect2(30,0,2280,1040)
   app.queue_layout_refresh();await frames(10)
   expect(app.deck_picker_ui==picker and picker.search.text=="检索样本 编号13" and picker.matches.size()==1,"resizing preserves the active gallery and search")
   check_layout(picker);await shot("android-wide")
  var art=picker.grid.get_child(0).find_child("DeckPickerLeaderArt",true,false)
  expect(art.texture==app.texture("70","tts_151600"),"gallery respects saved alternate leader artwork")
  var excluded=picker.entries.filter(func(entry):return entry.deck.id=="picker_12")[0]
  expect(excluded.colors==Store.CARDS["70"].colors,"deck colors follow plaza rules for rainbow cards, Lily and the stone")
  var nue=picker.entries.filter(func(entry):return entry.deck.id=="picker_11")[0]
  expect(nue.colors==Store.CARDS["100"].colors,"Nue in leader, main and side contributes no deck colors")
  var counts=Store.deck_color_counts(["64","soi_unit_086","character-fdf-117","100","100"])
  expect(counts.values().reduce(func(total,value):return total+value,0)==Store.CARDS["100"].colors.size()*2 and Store.CARDS["100"].colors.all(func(color):return counts[color]==2),"editor color counts exclude every Nue and retain ordinary card copies")
  set_search(picker,"小妖梦");await frames()
  expect(picker.matches.any(func(entry):return entry.deck.id=="picker_13"),"card aliases search saved deck contents")
  set_search(picker,Store.CARDS["70"].name);await frames()
  expect(picker.matches.any(func(entry):return entry.deck.id=="picker_13") and not picker.matches.any(func(entry):return entry.deck.id=="picker_01"),"leader name finds the appropriate decks")
  picker.reset_search()
  var color=picker.entries.filter(func(entry):return entry.deck.id=="picker_13")[0].colors[0]
  picker.toggle_color(color)
  expect(picker.matches.all(func(entry):return color in entry.colors),"color filter searches the whole saved deck")
  set_search(picker,"检索样本");await frames()
  expect(picker.matches.all(func(entry):return color in entry.colors and "检索样本" in entry.deck.name),"text and color filters combine")
  await key(KEY_BACK if android else KEY_ESCAPE)
  expect(not app.deck_picker_open() and app.decks[app.player_choice].id==player_id and app.decks[app.ai_choice].id==ai_id,"cancel preserves both match selections")
  await activate(app.screen.find_child("PlayerDeckSelect",true,false));await choose_fixture("picker_13")
  expect(not app.deck_picker_open() and app.decks[app.player_choice].id=="picker_13" and app.decks[app.ai_choice].id==ai_id,"player selection updates only the player slot")
  await activate(app.screen.find_child("AIDeckSelect",true,false));await choose_fixture("picker_01")
  expect(app.decks[app.ai_choice].id=="picker_01" and app.decks[app.player_choice].id=="picker_13","opponent selection updates only the AI slot")
  app.draft=app.decks[app.player_choice].duplicate(true);app.editor();await frames()
  if android:app.editor_ui.set_overview(true);await frames()
  app.draft.name="未保存草稿";app.dirty=true
  var original=app.draft.duplicate(true)
  expect(app.saved_select is Button and not app.saved_select is OptionButton,"editor uses a shared gallery button")
  await shot("editor-android" if android else "editor-desktop")
  await activate(app.saved_select)
  if not app.deck_picker_open():
   expect(false,"editor button opens the deck gallery");quit(1);return
  await activate(app.deck_picker_ui.find_child("DeckPickerBack",true,false))
  expect(app.dirty and app.draft==original,"return from picker keeps the unsaved editor draft intact")
  await activate(app.saved_select);await choose_fixture("picker_01")
  var confirmation=app.get_children().filter(func(child):return child is ConfirmationDialog and child.visible)
  expect(confirmation.size()==1 and app.draft==original,"choosing another deck keeps the existing unsaved-change confirmation")
  if not confirmation.is_empty():confirmation[0].confirmed.emit();await frames()
  expect(app.draft.id=="picker_01" and not app.dirty,"confirmed editor selection loads the chosen saved deck")
  for cloud in [false,true]:
   var session=Session.new();root.add_child(session)
   session.initialize(output.path_join("session-"+str(android)+"-"+str(cloud)));session.set_process(false)
   session.is_host=true;session.cloud_mode=cloud;session.cloud_slot=1;session.seat=0
   session.cloud_seats=["房主","玩家","","","","","",""]
   session.room_id="picker-test-room";session.connected=true;session.paused=false
   session.series.setup(1,false,"test");session.series.state.names=["房主","玩家"]
   session.room=session.series.public_state(0);app.lan_session=session;app.online();await frames()
   var lobby=app.screen.get_children().filter(func(child):return child.get_script()==preload("res://net/lan_lobby.gd"))[0]
   var pick=app.screen.find_child("NetworkDeckSelect",true,false)
   expect(pick is Button and not pick is OptionButton,"LAN and cloud room selectors use gallery buttons")
   await activate(pick);await choose_fixture("picker_13")
   expect(app.page=="online" and app.decks[lobby.deck_index].id=="picker_13","room gallery returns the selected deck to its lobby")
   expect(session.series.state.decks[0].is_empty(),"gallery selection preserves the explicit room registration action")
   var register=find_button(app.screen,"选择此卡组")
   await activate(register)
   expect(session.series.state.decks[0].get("id","")=="picker_13","room registration submits the deck selected in the gallery")
   if android:
    app.online();await frames()
    lobby=app.screen.get_children().filter(func(child):return child.get_script()==preload("res://net/lan_lobby.gd"))[0]
    expect(app.decks[lobby.deck_index].id=="picker_13","rebuilding an Android lobby preserves the selected deck")
   if cloud:
    session.read_only=true;session.room=session.series.public_state(-1);lobby.refresh(true);await frames()
    expect(app.screen.find_child("NetworkDeckSelect",true,false).disabled,"spectator deck button remains disabled")
   app.menu();app.lan_session=null;session.leave(false);session.queue_free();await frames()
  app.decks=[]
  # Empty collection is tested without touching the actual saved files.
  var empty=preload("res://scripts/deck_picker.gd").new();empty.app=app;app.screen.add_child(empty);await frames()
  expect(empty.entries.is_empty() and empty.matches.is_empty() and empty.grid.get_child_count()==1,"empty collection displays an actionable message")
  empty.queue_free()
 app.queue_free();await frames()
 print("DECK PICKER: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
