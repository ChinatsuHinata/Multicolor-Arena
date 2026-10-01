extends "res://tests/support/ui_base.gd"
## Geometry, input and rendered captures use the actual production scene.
var output="res://work/android-responsive"
var sizes=[Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2340,1080),Vector2i(1280,720)]

func frames(count: int=5):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 image.save_png(output.path_join(name+".png"))
 print("CAPTURE ",name," ",image.get_size())

func inside(rect: Rect2,outer: Rect2) -> bool:
 return outer.grow(2).encloses(rect)

func buttons(node: Node) -> Array:
 var result=[]
 if node is BaseButton and node.is_visible_in_tree():result.append(node)
 for child in node.get_children():result.append_array(buttons(child))
 return result

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures"))
 root.mode=Window.MODE_WINDOWED
 root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app)
 await frames()
 app.load_legacy_test_decks()
 var fixture=app.decks[app.player_choice].duplicate(true)
 var platforms=[true]
 if "--quick" in OS.get_cmdline_user_args():sizes=[Vector2i(2340,1080)]
 for mobile in platforms:
  for dimensions in sizes:
   root.size=dimensions
   app.is_android=mobile
   root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
   app.layout_dpi_override=float(dimensions.y)/3.0 if mobile else 0.0
   app.layout_safe_override=Rect2(60,0,dimensions.x-84,dimensions.y-24) if mobile else Rect2()
   await frames()
   app.refresh_responsive_layout()
   app.draft=fixture.duplicate(true);app.selected=fixture.leader
   app.editor()
   app.draft.side=fixture.main.slice(0,10)
   app.update_deck_rows()
   await frames(12)
   var prefix=("android" if mobile else "pc")+"-%dx%d" % [dimensions.x,dimensions.y]
   var safe=app.ui_metrics.safe
   expect(inside(app.editor_ui.columns.get_global_rect(),safe),prefix+" editor stays in safe area")
   expect(app.editor_ui.center.size.x>app.editor_ui.catalogue.size.x-32,prefix+" deck has the most space")
   expect(app.library.get_parent().size.y>app.ui_metrics.hit*2,prefix+" library shows at least two touch rows")
   expect(app.editor_ui.grid.columns==10,prefix+" main deck has ten columns")
   expect(app.draft.main.size()==50 and app.draft.side.size()==10,prefix+" full deck fixture %d/%d" % [app.draft.main.size(),app.draft.side.size()])
   var main_bar=app.main_scroll.get_v_scroll_bar()
   var side_scroll=app.deck_canvas.get_node("SideDeckScroll")
   var side_bar=side_scroll.get_h_scroll_bar()
   expect(main_bar.max_value-main_bar.page>1,prefix+" width-filling main cards can scroll vertically")
   expect(side_bar.max_value-side_bar.page<=1,prefix+" 10 side cards fit without horizontal scrolling")
   expect(app.main_scroll.get_global_rect().grow(2).encloses(app.editor_ui.grid.get_child(9).get_global_rect()),prefix+" tenth card fits in the left pane")
   expect(is_equal_approx(app.editor_ui.grid.get_child(0).position.y,app.editor_ui.grid.get_child(9).position.y) and app.editor_ui.grid.get_child(10).position.y>app.editor_ui.grid.get_child(9).position.y,prefix+" cards wrap after ten")
   var grid_right=app.editor_ui.grid.get_child(9).get_global_rect().end.x
   var viewport_right=app.main_scroll.get_global_rect().end.x
   expect(viewport_right-grid_right<=app.ui_metrics.gap+24,prefix+" tenth card reaches the right edge")
   app.main_scroll.scroll_vertical=int(main_bar.max_value-main_bar.page)
   await frames()
   expect(app.main_scroll.get_global_rect().grow(2).encloses(app.editor_ui.grid.get_child(49).get_global_rect()),prefix+" last main card is reachable by scrolling")
   app.main_scroll.scroll_vertical=0
   await frames()
   expect(side_scroll.get_global_rect().grow(2).encloses(app.editor_ui.side_grid.get_child(9).get_global_rect()),prefix+" last side card is visible")
   for child in app.editor_ui.grid.get_children():
    expect(child.position.x+child.size.x<=app.editor_ui.grid.size.x+2,prefix+" deck card inside grid")
   for button in buttons(app.screen):
    expect(button.size.y+1>=app.ui_metrics.hit,prefix+" touch height: "+button.text)
    expect(inside(button.get_global_rect(),safe),prefix+" button in safe area: "+button.text)
   for item in app.library_rows.values():
    var margin=item.row.get_children().filter(func(child):return child is MarginContainer)[0]
    expect(margin.get_child(0).get_child(0).size.x>=app.ui_metrics.body*7,prefix+" card name has readable width")
    expect(item.row.size.y<app.library.get_parent().size.y,prefix+" library row remains visible")
    print("LIBRARY ",item.row.get_global_rect()," margin ",margin.get_global_rect()," label ",margin.get_child(0).get_child(0).get_global_rect()," text ",margin.get_child(0).get_child(0).text," scroll ",app.library.get_parent().scroll_vertical)
    break
   await shot(prefix+"-editor")
   if mobile and not app.editor_ui.details.visible:
    app.editor_ui.toggle_details();await frames()
    expect(app.preview.is_visible_in_tree(),prefix+" collapsed details open")
    app.editor_ui.close_details();await frames()
   app.begin_battle(true);view=app.duel_view;e=view.engine
   await settle();await frames()
   expect(view.STAGE.size==app.get_viewport_rect().size,prefix+" battlefield fills viewport")
   expect(inside(view.hand_scroll.get_global_rect(),safe),prefix+" hand viewport within safe area")
   var confirm=find_button(view.ui,"保留")
   expect(confirm!=null,prefix+" mulligan action available")
   if confirm:
    expect(inside(confirm.get_global_rect(),safe),prefix+" phase action within safe area")
    expect(confirm.size.y>=app.ui_metrics.hit,prefix+" phase action meets touch height")
   if mobile:
    expect(not view.android_back_button.get_global_rect().intersects(confirm.get_global_rect()),prefix+" back and confirm separated")
   for button in buttons(view.hud):
    expect(inside(button.get_global_rect(),safe),prefix+" HUD in safe area: "+button.text)
   await shot(prefix+"-battle")
   for i in range(24-e.players[0].hand.size()):e.players[0].hand.append(e.make_card(fixture.main[i],0,"hand"))
   view.render();await settle();await frames()
   expect(view.hand_scroll.get_h_scroll_bar().max_value>view.hand_scroll.get_h_scroll_bar().page,prefix+" 24 cards scroll instead of overflowing")
   var first=view.hand_nodes[e.players[0].hand[0].uid]
   expect(first.size.x>=minf(80,app.ui_metrics.hit),prefix+" crowded hand keeps usable card width")
   if mobile:
    var selected=view.selection.duplicate()
    var start=view.hand_scroll.get_global_rect().get_center()
    var event=InputEventScreenTouch.new();event.index=0;event.position=start;event.pressed=true;root.push_input(event,true)
    for i in range(5):
     var motion=InputEventScreenDrag.new();motion.index=0;motion.position=start-Vector2((i+1)*35,0);root.push_input(motion,true);await process_frame
    event=event.duplicate();event.position=start-Vector2(175,0);event.pressed=false;root.push_input(event,true);await frames()
    expect(view.hand_scroll.scroll_horizontal>0,prefix+" hand touch swipe scrolls")
    expect(view.selection==selected,prefix+" hand swipe does not select cards")
   view.hand_scroll.scroll_horizontal=int(view.hand_scroll.get_h_scroll_bar().max_value)
   await frames();await shot(prefix+"-hand24")
   app.menu();await frames()
 print("RESPONSIVE UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
