extends "res://tests/support/ui_base.gd"
const Fixture=preload("res://tests/support/reveal_review_fixtures.gd")
var output="res://work/reveal-review-ui"

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var result=root.get_texture().get_image().save_png(output.path_join(name+".png"))
 expect(result==OK,"saved screenshot "+name)

func panel():return view.ui.find_child("RevealReviewPanel",true,false)

func tap(button: Button):
 if not view.is_android:await click(button.get_global_rect().get_center());return
 var event=InputEventScreenTouch.new();event.index=0;event.position=button.get_global_rect().get_center();event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func check_flow(prefix: String):
 clean()
 var fixture=Fixture.ability(e,1)
 Fixture.resolve(e);Fixture.finish(e)
 view.render();await settle();await frames()
 var review=panel()
 expect(is_instance_valid(review),prefix+" opponent sees the reveal review panel")
 if not is_instance_valid(review):return
 var cells=review.find_child("RevealReviewGrid",true,false).get_children()
 expect(cells.size()==3 and cells.map(func(cell):return cell.get_meta("revealed_card").uid)==fixture.shown.map(func(c):return c.uid),prefix+" every revealed card appears, including cards not selected")
 expect(cells.all(func(cell):return cell.get_node("RevealedCardArt").get_child(0).texture!=app.texture("back")),prefix+" every review tile shows its public card artwork")
 var notice=review.get_node("RevealReviewNotice")
 expect(notice.size.y>=notice.get_line_height()*notice.get_line_count(),prefix+" both the confirmation instructions and action-lock notice fit")
 expect(cells.all(func(cell):return cell.get_child(1).size.y>=cell.get_child(1).get_line_height()*mini(2,cell.get_child(1).get_line_count())),prefix+" card names remain readable below the artwork")
 var confirm=review.get_node("RevealReviewConfirm")
 expect(app.ui_metrics.safe.grow(1).encloses(review.get_global_rect()) and review.get_global_rect().encloses(confirm.get_global_rect()),prefix+" panel and confirmation fit the safe area")
 expect(view.response_disabled() and not view.free_main(),prefix+" play and field abilities are locked during review")
 var before=snapshot()
 view.request_cast(fixture.shown[0].uid)
 view.begin_action({"type":"extension","uid":fixture.source.uid,"key":"character-fdf-041:self"})
 e.pass_priority(e.priority)
 expect(snapshot()==before and view.local.is_empty(),prefix+" attempted card, ability and priority actions cannot change state")
 view.toggle_observation()
 view.begin_action({"type":"extension","uid":fixture.source.uid,"key":"character-fdf-041:self"})
 expect(view.observing and snapshot()==before and view.local.is_empty(),prefix+" observing the battlefield cannot bypass the review lock")
 view.toggle_observation()
 await shot(prefix+"-opponent-confirm")
 review=panel();confirm=review.get_node("RevealReviewConfirm")
 await tap(confirm);await settle();await frames()
 expect(e.pending.is_empty() and panel()==null,prefix+" mouse or touch confirmation closes the review and releases resolution")
 await shot(prefix+"-confirmed")

 clean();Fixture.ability(e,0);Fixture.resolve(e);Fixture.finish(e)
 view.render();await settle();await frames()
 review=panel()
 expect(is_instance_valid(review) and review.has_node("RevealReviewWaiting") and not review.has_node("RevealReviewConfirm"),prefix+" the revealing player waits and cannot confirm for the opponent")
 expect(view.response_disabled(),prefix+" the revealing player's actions remain locked")
 await shot(prefix+"-sender-waiting")

 clean()
 var source=put("character-fdf-041","field",1)
 e.begin_reveal_resolution({"id":999,"kind":"ability","owner":1,"source":source,"name":"展示牌"})
 for i in range(14):e.reveal_card(put(["spell-fdf-055","character-soi-006","121"][i%3],"hand",1))
 e.finish_reveal_resolution();e.presentation_events.clear()
 view.render();await frames()
 review=panel()
 var scroll=review.get_node("RevealReviewScroll")
 expect(review.get_node("RevealReviewScroll/RevealReviewGrid").get_child_count()==14,prefix+" large reveals retain all copies in a scrollable grid")
 scroll.scroll_vertical=10000;await frames()
 expect(scroll.scroll_vertical>0 and review.get_global_rect().encloses(review.get_node("RevealReviewConfirm").get_global_rect()),prefix+" scrolling keeps the confirmation button visible")
 await shot(prefix+"-many-cards-scrolled")
 await tap(review.get_node("RevealReviewConfirm"));await frames()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
  app.layout_safe_override=Rect2(60,0,1196,696) if android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  await check_flow("android" if android else "desktop")
 print("REVEAL REVIEW UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
