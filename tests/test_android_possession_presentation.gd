extends "res://tests/support/ui_base.gd"
const Remote=preload("res://net/remote_duel.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
var board
var output="res://work/android-possession-presentation/"+str(Time.get_ticks_usec())

func frames(count: int=5):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(output.path_join(title+".png"))==OK,"screenshot "+title)

func reset_board(seat: int=0):
 clean();view.debug_mode=false;view.replay_recording.finished=true
 view.local_seat=seat;view.table.local_seat=seat
 view.android_palette_view=false;view.android_focus_owner=seat
 view.android_camera_restore={};view.android_auto_focus_owner=-1;view.android_manual_focus_override=-1
 board.opened={};board.anchors={}
 for who in range(2):
  for i in range(4):put(["164","165","166","167"][i],"palette",who)
  for i in range(4):put("53","hand",who)
 view.render();await frames()

func check_landscape(label: String):
 await reset_board()
 for who in range(2):
  for kind in ["结界","时符"]:
   var id=""
   for key in e.cards:
    if e.cards[key].kind==kind or kind=="时符" and kind in e.cards[key].get("spell_type",""):id=key;break
   expect(not id.is_empty(),"fixture "+kind)
   if id.is_empty():continue
   var first=put(id,"field",who);var second=put(id,"field",who);second.tapped=true
   var group="barrier" if kind=="结界" else "time"
   view.render();board.open_region(who,group);await create_timer(0.25).timeout
   expect(board.tiles["band-%d-%s" % [who,group]].props.landscape,label+" rotates "+kind+" thumbnail")
   for card in [first,second]:
    var node=board.cards["card_"+str(card.uid)]
    expect(node.landscape and is_equal_approx(node.art.rotation,-PI/2),label+" rotates "+kind+" art "+str(card.tapped))
    expect(absf(node.size.x/node.size.y-1.4)<0.03 and board.sheet_rect.encloses(node.get_global_rect()),label+" landscape card fits "+kind)
   expect(not board.cards["card_"+str(first.uid)].get_global_rect().intersects(board.cards["card_"+str(second.uid)].get_global_rect()),label+" landscape cards stay separate")
   expect(not first.tapped and second.tapped,label+" orientation preserves rule tapping")
   await shot(label+"-"+str(who)+"-"+group)
   board.close_region()
 # The larger landscape width must also drive pagination.
 var cards=[]
 for i in range(12):cards.append({"uid":i,"tapped":i%2==1})
 var pages=board.row_pages(cards,500,150,false,true)
 expect(pages.size()>1 and pages.all(func(page):return page.size()*150+maxi(0,page.size()-1)*12<=500-app.ui_metrics.hit*2-app.ui_metrics.gap*2),label+" landscape pagination uses actual widths")

func check_exchange(seat: int,label: String):
 await reset_board(seat)
 var enemy=1-seat
 put("spell-htk-004","field",enemy)
 e.active=enemy;e.priority=enemy;e.phase="possession";e.pending={"kind":"possession","owner":enemy}
 view.render();await frames()
 expect(board.palette.visible and view.android_palette_focus_owner()==enemy,label+" opens enemy palette with auto camera disabled")
 var player=e.players[enemy];var old=player.palette[0];var incoming=player.hand[0]
 e.possession(old.uid,incoming.uid);view.render();await frames(1)
 var presentation=view.reveal_player
 expect(presentation.busy and board.palette.visible and presentation.palette_owner==enemy,label+" keeps palette open through exchange")
 expect(presentation.palette_cards.any(func(card):return card.uid==old.uid) and not presentation.palette_cards.any(func(card):return card.uid==incoming.uid),label+" shows palette before exchange")
 if presentation.current.get("from","")=="palette":
  expect(board.palette_rect.grow(2).encloses(Rect2(presentation.face.position,presentation.face.size)),label+" flight starts on visible palette")
 await shot(label+"-outgoing")
 await settle()
 expect(board.palette.visible and presentation.palette_owner==-1,label+" remains open for next possession")
 expect(board.cards["card_"+str(incoming.uid)].visible and not board.cards["card_"+str(old.uid)].visible,label+" displays completed exchange")
 for i in range(2):
  old=player.palette[0];incoming=player.hand[0]
  e.possession(old.uid,incoming.uid);view.render();await frames(1)
  expect(board.palette.visible and presentation.busy,label+" stays open during repeat "+str(i))
  await settle()
 expect(not board.palette.visible and not view.android_palette_view and view.android_camera_restore.is_empty(),label+" closes after final animation")
 expect(presentation.movements.size()==6,label+" presents all three exchanges")
 e.pending={"kind":"possession","owner":enemy};view.render();await frames()
 e.possession();view.render();await frames()
 expect(not board.palette.visible,label+" skipping possession closes palette")
 e.players[enemy].field=[];player.possession_count=0
 e.pending={"kind":"possession","owner":enemy};view.render();await frames()
 e.possession(player.palette[0].uid,player.hand[0].uid);view.render();await frames(1)
 expect(board.palette.visible and view.reveal_player.busy,label+" normal possession stays open during animation")
 await settle()
 expect(not board.palette.visible,label+" normal single possession closes after animation")

func check_projection(spectator: bool):
 await reset_board()
 var authority=e;var enemy=1-view.local_seat
 put("spell-htk-004","field",enemy)
 authority.active=enemy;authority.priority=enemy;authority.phase="possession";authority.pending={"kind":"possession","owner":enemy}
 # Multiple authority commands can arrive together without a prior pending UI.
 for i in range(3):authority.possession(authority.players[enemy].palette[0].uid,authority.players[enemy].hand[0].uid)
 var events=authority.presentation_events.duplicate(true)
 var projection=Observer.build(authority,events) if spectator else Seat.build(authority,view.local_seat,events)
 var remote=Remote.new();remote.seat=view.local_seat;remote.apply_snapshot(projection.duplicate(true))
 view.engine=remote;view.table.duel=remote;e=remote
 view.render();await frames(1)
 var label="observer" if spectator else "online"
 expect(board.palette.visible and view.android_palette_focus_owner()==enemy,label+" events open palette without prior pending")
 expect(view.reveal_player.queue.all(func(event):return event.type!="move_batch"),label+" preserves exchange order")
 expect(remote.players[enemy].hand.all(func(card):return card.card_id=="back"),label+" private hand remains hidden")
 await settle()
 expect(not board.palette.visible and view.reveal_player.movements.size()==6,label+" completes queued exchanges then closes")
 expect(remote.players[enemy].hand.all(func(card):return card.card_id=="back"),label+" presentation preserves hand privacy")
 view.engine=authority;view.table.duel=authority;e=authority

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures"))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1560,720)
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root_override.path_join("settings.json")
 app.is_android=true;app.layout_dpi_override=280;app.layout_safe_override=Rect2(40,0,1504,704)
 root.add_child(app);await frames(8);app.load_legacy_test_decks()
 app.android_experimental_battle_ui=true;app.auto_camera_focus=false;app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;board=view.android_board;await frames()
 Engine.max_fps=120
 for device in [[1560,720,Rect2(40,0,1504,704)],[1280,480,Rect2(0,0,1280,480)]]:
  root.size=Vector2i(device[0],device[1]);app.layout_safe_override=device[2];app.refresh_responsive_layout();await frames()
  var label="%dx%d" % [device[0],device[1]]
  await check_landscape(label)
  for seat in range(2):await check_exchange(seat,label+"-seat"+str(seat))
 await check_projection(false);await check_projection(true)
 print("ANDROID POSSESSION PRESENTATION: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
