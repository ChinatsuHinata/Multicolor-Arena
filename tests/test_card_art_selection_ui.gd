extends "res://tests/support/ui_base.gd"
const N=preload("res://scripts/rules/new0921_cards.gd")
var output="res://work/card-art-selection"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap_card(uid):
 var at=view.region_tiles[uid].get_global_rect().get_center()
 if not view.is_android:await click(at);return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func reset_presentations():
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()

func check_gallery(prefix: String):
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel) and panel.get_meta("region_picker",false),prefix+" card selection opens the art gallery")
 if not is_instance_valid(panel):return
 var grid=panel.find_child("RegionChoiceGrid",true,false)
 expect(grid!=null and grid.get_meta("columns",1)>=mini(2,view.region_tiles.size()),prefix+" card art uses multiple columns when there are multiple cards")
 expect(grid.find_children("*","Button",true,false).is_empty() and grid.find_children("*","Label",true,false).all(func(label):return label.name=="RegionOwnerLabel"),prefix+" cards have no name buttons or name labels")
 for tile in view.region_tiles.values():
  var card=view.region_card(tile.get_meta("choice_atom"))
  var owner_label=tile.get_parent().get_node_or_null("RegionOwnerLabel")
  if card.zone=="grave":
   expect(owner_label!=null and owner_label.text==view.player_caption(card.owner)+"的墓地",prefix+" grave card identifies its graveyard owner")
  else:expect(owner_label==null,prefix+" other zones have no graveyard owner label")
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),prefix+" gallery stays in the safe area")
 expect(panel.get_global_rect().encloses(panel.find_child("RegionConfirm",true,false).get_global_rect()),prefix+" confirmation stays inside the gallery")

func grave_owners_flow(prefix: String):
 clean(true)
 var source=put("character-fdn-043","field")
 var own=put("53","grave")
 for who in range(2):
  for i in range(5):put("164","grave",who)
 var other=put("53","grave",1)
 await reset_presentations()
 view.begin_action({"type":"extension","uid":source.uid,"key":"character-fdn-043"});await frames()
 check_gallery(prefix+" Fujimi graveyards")
 expect(view.region_tiles.size()==12,prefix+" Fujimi shows both complete graveyards")
 for uid in view.region_tiles:
  var tile=view.region_tiles[uid]
  var label=tile.get_parent().get_node("RegionOwnerLabel")
  expect(label.get_meta("region_owner")==e.find_card(uid).owner,prefix+" identical card art retains the correct graveyard owner")
  expect(label.get_global_rect().end.y<=tile.get_global_rect().position.y and tile.get_parent().get_global_rect().encloses(label.get_global_rect()),prefix+" owner label stays above the card inside its cell")
 var scroll=view.android_choice_panel.find_child("RegionChoiceScroll",true,false)
 scroll.scroll_vertical=0;await frames()
 await tap_card(own.uid)
 scroll.scroll_vertical=10000;await frames()
 await tap_card(other.uid)
 expect(view.region_batch.size()==2 and view.region_batch.any(func(atom):return atom.value.uid==own.uid) and view.region_batch.any(func(atom):return atom.value.uid==other.uid),prefix+" same-name cards in different graveyards can both be selected")
 await shot(prefix+"-fujimi-graveyard-owners")
 var hide=view.android_choice_panel.get_node("AndroidChoiceHide" if view.is_android else "DesktopChoiceHide")
 await click(hide.get_global_rect().get_center());await frames()
 await click(view.android_choice_restore.get_global_rect().get_center());await frames()
 check_gallery(prefix+" Fujimi restored")
 expect(view.region_batch.size()==2,prefix+" hiding and reopening preserves both graveyard selections")
 var confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 expect(source.zone=="grave" and e.stack.size()==1,prefix+" Fujimi sacrifices itself after target confirmation")
 resolve()
 expect(own.zone=="exile" and other.zone=="exile" and e.players[0].grave.size()==6 and e.players[1].grave.size()==5,prefix+" resolution removes the exact selected cards from each graveyard")
 await reset_presentations()

func fairy_flow(prefix: String):
 clean(true);e.debug_free_payment=true
 var ids=[];var names=[]
 for id in e.DB.IDS:
  var info=e.cards[id]
  if info.kind=="单位" and "妖精" in info.race and info.name not in names:
   ids.append(id);names.append(info.name)
   if ids.size()==3:break
 var first=put(ids[0],"grave");var duplicate=put(ids[0],"grave")
 var second=put(ids[1],"grave");var third=put(ids[2],"grave")
 var spell=put("97","hand")
 view.local={"uid":spell.uid,"mode":"target"};view.render();await frames()
 check_gallery(prefix+" Fairy Frolic")
 var path=view.picker.path.duplicate(true)
 await tap_card(first.uid)
 expect(view.region_batch.size()==1 and view.picker.path==path,prefix+" selection accumulates without advancing the popup")
 expect(not view.region_tiles[duplicate.uid].get_meta("region_legal"),prefix+" same-name duplicate becomes unavailable")
 await tap_card(duplicate.uid)
 expect(view.region_batch.size()==1,prefix+" duplicate fairy cannot be selected")
 await tap_card(first.uid);await tap_card(duplicate.uid)
 expect(view.region_batch.size()==1 and view.region_batch[0].value.uid==duplicate.uid,prefix+" selected art can be toggled and a different copy chosen")
 await tap_card(second.uid);await tap_card(third.uid)
 expect(view.region_batch.size()==3 and view.picker.path==path,prefix+" all three legal fairies are selected in one popup")
 var selected_panel=view.android_choice_panel
 var hide=selected_panel.get_node("AndroidChoiceHide" if view.is_android else "DesktopChoiceHide")
 await click(hide.get_global_rect().get_center());await frames()
 expect(is_instance_valid(view.android_choice_restore),prefix+" gallery can be hidden")
 await click(view.android_choice_restore.get_global_rect().get_center());await frames()
 expect(view.region_batch.size()==3,prefix+" reopening preserves every selected card")
 await shot(prefix+"-fairy-multiselect")
 var confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 expect(e.stack.any(func(entry):return entry.kind=="card" and entry.card.uid==spell.uid and entry.target.picks[0].size()==3),prefix+" one confirmation submits all three targets")
 resolve()
 expect(duplicate.zone=="field" and second.zone=="field" and third.zone=="field" and first.zone=="grave",prefix+" Fairy Frolic resolves the exact chosen copies")
 await reset_presentations()

func books_flow(prefix: String,codes: Array):
 clean(true);e.players[0].deck=[]
 var books=[]
 for code in codes:
  books.append(put(N.id(code),"deck"));put(N.id(code),"deck")
 var source=put(N.id("ETO-003"),"field")
 N.event(e,source,"ETO-003");e.pump_choices();resolve()
 await reset_presentations()
 check_gallery(prefix+" books")
 var confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 expect(confirm.disabled,prefix+" empty mandatory search cannot be confirmed")
 expect(confirm.text!="跳过此项",prefix+" mandatory song collection never offers a skip action")
 for book in books:
  await tap_card(book.uid)
  var copy=e.players[0].deck.filter(func(c):return c.card_id==book.card_id and c.uid!=book.uid)[0]
  expect(not view.region_tiles[copy.uid].get_meta("region_legal"),prefix+" only one copy of each book can be chosen")
 expect(view.region_batch.size()==codes.size() and not confirm.disabled,prefix+" exactly one of each available species satisfies the search")
 await shot(prefix+"-books-search-"+str(codes.size()))
 await click(confirm.get_global_rect().get_center());await reset_presentations()
 expect(e.pending.trigger.effect=="n21:three_books",prefix+" searched books advance to destination selection")
 expect(view.region_tiles.size()==books.size(),prefix+" only searched copies are shown for allocation")
 await tap_card(books[0].uid)
 confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 expect(view.region_tiles.size()==books.size()-1 and not view.region_tiles.has(books[0].uid),prefix+" hand selection removes that book from later choices")
 await shot(prefix+"-books-destination-"+str(codes.size()))
 confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 expect(confirm!=null and not confirm.disabled and confirm.text=="跳过此项",prefix+" grave destination can be skipped")
 await click(confirm.get_global_rect().get_center());await frames()
 await tap_card(books[1].uid)
 confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 expect(e.pending.is_empty() and books[0].zone=="hand" and books[1].zone=="palette" and books[1].tapped,prefix+" final confirmation sends the chosen books to hand and tapped palette")
 expect(e.players[0].grave.is_empty() and e.players[0].deck.size()==codes.size()*2-2,prefix+" skipped destination and unassigned books remain in the library")
 await reset_presentations()

func weighted_flow(prefix: String):
 clean(true);e.debug_free_payment=true
 var shinmy=e.DB.IDS.filter(func(id):return e.cards[id].kind in ["单位","自机"] and "少名针妙丸" in e.cards[id].get("character",""))[0]
 put(shinmy,"field")
 var ids=[]
 for spirit in [2,1,2]:
  var matches=e.DB.IDS.filter(func(id):return e.cards[id].kind=="单位" and "黄" in e.cards[id].colors and int(e.cards[id].get("spirit",0))==spirit)
  ids.append(matches[0])
 var first=put(ids[0],"grave");var second=put(ids[1],"grave");var third=put(ids[2],"grave")
 var spell=put("spell-fdn-023","hand")
 view.local={"uid":spell.uid,"mode":"target"};view.render();await frames()
 check_gallery(prefix+" spirit sum")
 await tap_card(first.uid);await tap_card(second.uid)
 expect(view.region_batch.size()==2 and not view.region_tiles[third.uid].get_meta("region_legal"),prefix+" multiselect respects the spirit sum limit")
 await tap_card(third.uid)
 expect(view.region_batch.size()==2,prefix+" a card exceeding the spirit sum cannot be added")
 var confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 expect(e.stack.any(func(entry):return entry.kind=="card" and entry.card.uid==spell.uid and entry.target.picks[0].size()==2),prefix+" a legal weighted selection submits together: "+view.message)

func partial_row_flow(prefix: String):
 clean(true);e.players[0].deck=[]
 for code in ["ETO-007","ETO-007","ETO-009","ETO-009","ETO-011"]:put(N.id(code),"deck")
 var source=put(N.id("ETO-003"),"field")
 N.event(e,source,"ETO-003");e.pump_choices();resolve();await reset_presentations()
 check_gallery(prefix+" five songs")
 var panel=view.android_choice_panel
 var gallery=panel.find_child("RegionChoiceGrid",true,false)
 var first_row=gallery.get_child(0)
 var first_card=first_row.get_child(0)
 var last_card=first_row.get_child(first_row.get_child_count()-1)
 expect(panel.get_global_rect().end.x-last_card.get_global_rect().end.x<first_card.size.x,prefix+" full rows do not leave an empty card-width on the right")
 for row in gallery.get_children():
  expect(absf(row.get_child(0).get_global_rect().position.x-first_card.get_global_rect().position.x)<1,prefix+" partial rows start at the same left edge as full rows")
 await shot(prefix+"-songs-layout-five")

func outside_flow(prefix: String):
 clean(true);e.debug_free_payment=true
 var spell=put("spell-ucs-022","hand")
 e.commit_cast(0,spell.uid,{"none":true},[]);resolve();await reset_presentations()
 check_gallery(prefix+" outside search")
 expect(view.picker.available().any(func(atom):return atom.kind=="target" and atom.value.has("outside_id")) and not view.picker.available().any(func(atom):return atom.kind=="mode"),prefix+" game-outside cards are chosen by art without a preceding name button")
 var id=view.region_tiles.keys()[0]
 await tap_card(id)
 var confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 check_gallery(prefix+" second outside search")
 id=view.region_tiles.keys()[0];await tap_card(id)
 confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 await click(confirm.get_global_rect().get_center());await frames()
 expect(e.pending.is_empty() and e.players[0].hand.size()==2,prefix+" both outside cards resolve directly into hand")
 await reset_presentations()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 root.add_child(app);await frames();app.load_test_decks()
 for fixture in [{"size":Vector2i(1600,900),"dpi":0.0},{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(2340,1080),"dpi":420.0}]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture.size;app.is_android=fixture.dpi>0;app.layout_dpi_override=fixture.dpi
  app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24) if app.is_android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var prefix="android-%dx%d" % [fixture.size.x,fixture.size.y] if app.is_android else "desktop"
  await grave_owners_flow(prefix)
  await fairy_flow(prefix)
  await books_flow(prefix,["ETO-007","ETO-009","ETO-011"])
  await books_flow(prefix,["ETO-009","ETO-011"])
  await weighted_flow(prefix)
  await outside_flow(prefix)
  await partial_row_flow(prefix)
 print("CARD ART SELECTION UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
