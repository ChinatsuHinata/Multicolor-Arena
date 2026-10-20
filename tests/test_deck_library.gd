extends "res://tests/support/ui_base.gd"
const Library=preload("res://scripts/deck_library.gd")
var output="res://work/deck-library-tests"
var fixture_ids=["library_0","library_1","library_2","library_3"]

func frames(count: int=6):
 for i in range(count):await process_frame

func matches(picker) -> Array:return picker.matches.map(func(entry):return str(entry.deck.id))

func search(picker,value: String):
 picker.search.text=value;picker.apply_search()

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(title+".png"))

func check_tiles(picker):
 var safe=app.screen.get_global_rect().grow(1)
 for control in [picker.search,picker.sort_choice,picker.previous_button,picker.next_button,picker.find_child("DeckPickerBack",true,false)]:
  expect(safe.encloses(control.get_global_rect()),"gallery controls stay within the usable screen")
 for tile in picker.grid.get_children():
  if not tile is Button:continue
  var art=tile.find_child("DeckPickerLeaderArt",true,false)
  var title=tile.find_child("DeckPickerTitle",true,false)
  var favorite=tile.find_child("DeckPickerFavorite_*",true,false)
  var labels=tile.find_children("*","Label",true,false)
  expect(labels.size()==1 and labels[0]==title,"deck tile shows only its title")
  expect(art.texture!=null and art.size.y>40 and art.get_global_rect().end.y<=title.global_position.y,"leader art appears above the title even in compact layouts")
  expect(tile.get_global_rect().grow(1).encloses(title.get_global_rect()) and tile.get_global_rect().grow(1).encloses(favorite.get_global_rect()),"title and favorite control fit inside the tile")
  expect(picker.gallery.get_global_rect().grow(1).encloses(tile.get_global_rect()),"tile fits the gallery")
  expect(favorite.size.x>=app.ui_metrics.hit and favorite.size.y>=app.ui_metrics.hit,"favorite button keeps a usable mouse and touch target")

func favorite_click(button: Button):
 if app.is_android:
  var touch=InputEventScreenTouch.new();touch.index=0;touch.position=button.get_global_rect().get_center();touch.pressed=true
  root.push_input(touch,true);await process_frame
  touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true)
 else:await click(button.get_global_rect().get_center())
 await frames()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join(str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=output.path_join("tutorials")
 app.settings_path=output.path_join("settings.json");app.account_session_path=output.path_join("account-session.json")
 app.ai_opponent="custom";root.add_child(app);await frames()
 var names=["排序样本 编号2","排序样本 编号10","排序样本 编号1","排序样本 编号3"]
 for i in range(4):
  var deck=Store.blank(names[i]);deck.id=fixture_ids[i];deck.rule_set="test"
  deck.leader="70" if i in [0,2] else "68";deck.main=["53","100"];deck.side=[]
  expect(Store.save_file(deck).is_empty(),"isolated deck fixture saves")
 var library=Library.new();expect(library.load_data().is_empty(),"missing library starts with defaults")
 for i in range(4):
  for game in range([8,4,2,1][i]):expect(library.record_usage([fixture_ids[i]],"fixture_%d_%d" % [i,game]).is_empty(),"usage fixture saves")
 expect(library.set_favorite(fixture_ids[1],true).is_empty() and library.set_favorite(fixture_ids[2],true).is_empty(),"favorite fixtures save")
 var counts=[8,4,2,1]
 expect(library.record_usage([fixture_ids[0],fixture_ids[0]],"local_game").is_empty(),"same deck in both local seats records one game")
 var reloaded=Library.new();reloaded.load_data()
 expect(reloaded.usage_count(fixture_ids[0])==9 and reloaded.record_usage([fixture_ids[0]],"local_game").is_empty() and reloaded.usage_count(fixture_ids[0])==9,"reloading and reconnecting do not count the same game again")
 counts[0]=9
 for android in [false,true]:
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if android else Window.CONTENT_SCALE_ASPECT_KEEP
  app.is_android=android;app.layout_dpi_override=360 if android else 0
  app.layout_safe_override=Rect2(40,0,1200,690) if android else Rect2()
  app.setup();await frames()
  app.open_match_deck_picker(0);await frames()
  var picker=app.deck_picker_ui;search(picker,"排序样本");await frames()
  expect(picker.library.sort_mode=="usage" and matches(picker)==[fixture_ids[1],fixture_ids[2],fixture_ids[0],fixture_ids[3]],"usage sorts descending within favorites and remaining decks")
  check_tiles(picker)
  await shot("android" if android else "desktop")
  picker.sort_choice.select(1);picker.sort_choice.item_selected.emit(1);await frames()
  expect(matches(picker)==[fixture_ids[2],fixture_ids[1],fixture_ids[0],fixture_ids[3]],"name sort is natural and still puts favorites first")
  picker.sort_choice.select(2);picker.sort_choice.item_selected.emit(2);await frames()
  expect(matches(picker)==[fixture_ids[2],fixture_ids[1],fixture_ids[0],fixture_ids[3]],"leader sort groups both favorites and remaining decks by leader")
  search(picker,"排序样本 编号3");await frames()
  var favorite=picker.find_child("DeckPickerFavorite_"+fixture_ids[3],true,false)
  var player_id=app.decks[app.player_choice].id
  await favorite_click(favorite)
  expect(app.deck_picker_ui==picker and app.decks[app.player_choice].id==player_id,"clicking favorite does not select or close the gallery")
  expect(picker.library.favorite(fixture_ids[3]) and matches(picker)==[fixture_ids[3]],"favoriting retains the active search")
  search(picker,"排序样本");await frames()
  expect(matches(picker)==[fixture_ids[2],fixture_ids[3],fixture_ids[1],fixture_ids[0]],"new favorite joins the sorted favorite group")
  app.close_deck_picker();app.open_match_deck_picker(0);await frames()
  picker=app.deck_picker_ui;search(picker,"排序样本");await frames()
  expect(picker.sort_choice.selected==2 and picker.library.favorite(fixture_ids[3]),"reopening restores the selected sort and favorites")
  picker.sort_choice.select(0);picker.sort_choice.item_selected.emit(0);await frames()
  expect(matches(picker)==[fixture_ids[1],fixture_ids[2],fixture_ids[3],fixture_ids[0]],"all favorites remain ahead of a more frequently used ordinary deck")
  if android:
   expect(picker.color_row.visible,"Android gallery shows color filters immediately");check_tiles(picker);await shot("android-colors")
   root.size=Vector2i(2340,1080);app.layout_dpi_override=240;app.layout_safe_override=Rect2(30,0,2280,1040)
   app.queue_layout_refresh();await frames(12);check_tiles(picker);await shot("android-wide")
  search(picker,"排序样本 编号3");await frames()
  await favorite_click(picker.find_child("DeckPickerFavorite_"+fixture_ids[3],true,false))
  search(picker,"排序样本");await frames()
  expect(matches(picker)==[fixture_ids[1],fixture_ids[2],fixture_ids[0],fixture_ids[3]],"removing a favorite returns it to the ordinary group")
  picker.toggle_color("红");await frames()
  expect(matches(picker)==[fixture_ids[2],fixture_ids[0]],"color filters retain favorite priority and usage sorting")
  picker.reset_search();search(picker,"排序样本");await frames()
  picker.page_size=2;picker.render_tiles();picker.turn_page(1);await frames()
  expect(picker.grid.get_children().filter(func(tile):return tile is Button).map(func(tile):return str(tile.get_meta("deck_id")))==[fixture_ids[0],fixture_ids[3]],"pagination slices the complete sorted collection")
  picker.change_sort(1);await frames()
  expect(picker.page_index==0 and matches(picker)==[fixture_ids[2],fixture_ids[1],fixture_ids[0],fixture_ids[3]],"changing sort returns to the first sorted page")
  picker.change_sort(0);app.close_deck_picker()
  var after=Library.new();after.load_data()
  expect(fixture_ids.map(func(id):return after.usage_count(id))==counts,"browsing, filtering and favoriting do not increment usage")
  expect(not after.favorite(fixture_ids[3]),"removing favorites persists")
 app.is_android=false;app.reload_decks();app.debug_mode=true;app.experimental_ai=false
 app.player_choice=app.remaining_deck_index(fixture_ids[0],0);app.ai_choice=app.remaining_deck_index(fixture_ids[3],0)
 app.begin_battle(true);await frames()
 var after_battle=Library.new();after_battle.load_data()
 expect(after_battle.usage_count(fixture_ids[0])==10 and after_battle.usage_count(fixture_ids[3])==2,"starting a local battle records both saved decks")
 var original=Store.read_file(Store.file_paths[fixture_ids[1]]).deck
 original.name="改名后的排序样本";expect(Store.save_file(original).is_empty(),"saved favorite can be renamed")
 app.reload_decks();after_battle.load_data()
 expect(after_battle.favorite(fixture_ids[1]) and after_battle.usage_count(fixture_ids[1])==4,"rename and ordinary deck saving retain favorite and usage records")
 expect(not Store.clean_deck(original).has("favorite") and not Store.decode(Store.encode(original)).deck.has("usage_count"),"local gallery preferences stay outside shared deck contents")
 app.queue_free();await frames()
 print("DECK LIBRARY: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
