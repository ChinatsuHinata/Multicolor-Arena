extends "res://tests/support/ui_base.gd"
const CardPreviewHold=preload("res://scripts/card_preview_hold_settings.gd")
const BoardCard=preload("res://scripts/android_board/board_card.gd")
# Measured by the unmodified board at 1560x720 / dpi280 / safe (40,0,1504,704).
const BASELINE_PORTRAIT_WIDTH=85.0
var output="res://work/android-experimental-board"
var board

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(output.path_join(title+".png"))==OK,"screenshot saved "+title)

func touch(at: Vector2,pressed: bool):
 var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=pressed
 root.push_input(event,true);await frames(2)

func tap(node: Control):
 var at=node.get_global_rect().get_center()
 await touch(at,true);await touch(at,false);await frames()

func redraw():
 view.render();await settle();view.render();await frames();view.banner.hide()

func fill(count: int=3):
 clean();board.anchors={};board.initialized=false
 for who in range(2):
  for i in range(count):
   var c=put("53","field",who);c.entered_turns=0;c.tapped=(i%2==1 if count>=14 else i==1)
  for i in range(5):put(["164","165","166","167","168"][i],"palette",who)
  for i in range(3):put("53","hand",who)
  for i in range(2+who):put("53","grave",who)
  put("100","exile",who)
 await redraw()

func check_layout(label: String):
 print("GEOMETRY ",label," mode=",board.board_layout_mode," B=",board.get_global_rect()," L=",board.left_column," hit=",app.ui_metrics.hit," row=",board.row_h)
 for node in board.cards.values():
  if node.visible and not node.card.tapped:
   print("PORTRAIT SIZE ",label," ",node.size);break
 var safe=app.ui_metrics.safe;var hit=app.ui_metrics.hit;var B=board.get_global_rect()
 check_mode_geometry(label)
 var obstacles=[view.hand_scroll.get_global_rect(),view.responsive.toolbar_rect,view.responsive.log_rect]
 obstacles.append(view.hud.get_node("AutoPayKeepButton").get_global_rect())
 obstacles.append(view.hud.get_node("HandDisplayToggle").get_global_rect())
 if view.stack_panel.visible:obstacles.append(view.stack_panel.get_global_rect())
 for widget in view.life_widgets.values():obstacles.append(widget.button.get_global_rect())
 var nodes=[]
 for node in board.cards.values():
  if node.visible:nodes.append(node)
 for node in board.tiles.values():
  if node.visible:nodes.append(node)
 for node in nodes:
  var rect: Rect2=node.get_global_rect()
  expect(safe.grow(1).encloses(rect),label+" safe "+str(node.name))
  if node is BoardCard or str(node.name).begins_with("band-") or str(node.name).begins_with("page-units-"):
   expect(B.encloses(rect),label+" inside board "+str(node.name))
  if str(node.name).begins_with("band-"):
   expect(rect.size.x>=hit and rect.size.y>=hit,label+" permanent tile size "+str(node.name))
   expect(is_equal_approx(node.modulate.a,0.45 if node.props.empty else 1.0),label+" permanent alpha "+str(node.name))
  for obstacle in obstacles:expect(not rect.intersects(obstacle),label+" clears HUD "+str(node.name))
  var target: Rect2=Rect2(node.global_position+node.hit_rect().position,node.hit_rect().size)
  expect(minf(target.size.x,target.size.y)>=hit-0.1,label+" touch target "+str(node.name))
 for i in range(nodes.size()):
  for j in range(i):expect(not nodes[i].get_global_rect().intersects(nodes[j].get_global_rect()),label+" separate "+str(nodes[i].name)+" / "+str(nodes[j].name))
 for key in ["summary-0","summary-1","zone-0-grave","zone-0-exile","zone-1-grave","zone-1-exile"]:
  expect(board.left_column.grow(1).encloses(board.tiles[key].get_global_rect()),label+" left column "+key)
 expect(board.get_global_rect()==view.TOUCH_CAMERA_AREA,label+" board follows responsive camera area")
 expect(board.tiles["band-0-time"].get_global_rect().end.y<=board.get_global_rect().end.y,label+" own band fits")

func check_mode_geometry(label: String):
 var B=board.get_global_rect();var hit=app.ui_metrics.hit;var g=app.ui_metrics.gap
 var inline_row_h=floorf((B.size.y-g*3)/2)
 var inline_mode=inline_row_h>=hit*2+g
 expect(board.board_layout_mode==("inline" if inline_mode else "band"),label+" mode follows height threshold")
 if inline_mode:
  expect(board.row_h==inline_row_h,label+" inline row height")
  expect(B.position.y+board.row_h*2+g*3<=B.end.y,label+" inline rows fit board bottom")
 else:
  var band_h=maxf(hit,roundf(B.size.y*0.15))
  expect(board.band_h==band_h,label+" original band height")
  expect(board.row_h==floorf((B.size.y-band_h*2-g*4)/2),label+" original band row height")
 var permanent_tiles=board.tiles.values().filter(func(node):return node.visible and str(node.name).begins_with("band-"))
 expect(permanent_tiles.size()==10,label+" five permanent tiles per side without empty-slot nodes")
 for who in range(2):
  var enemy=who!=view.local_seat
  var area: Rect2
  if inline_mode:
   var y=B.position.y+(0 if enemy else board.row_h+g*3)
   var th=floorf((board.row_h-g)/2)
   var left=["leader","melody"] if enemy else ["melody","leader"]
   var right=[["item","barrier"],["time",""]] if enemy else [["time",""],["item","barrier"]]
   for row in range(2):
    expect(board.tiles["band-%d-%s" % [who,left[row]]].get_global_rect()==Rect2(B.position.x,y+row*(th+g),hit,th),label+" mirrored left slot "+str(who)+left[row])
    for col in range(2):
     var group=right[row][col]
     if group.is_empty():continue
     var expected=Rect2(B.end.x-(hit*2+g)+col*(hit+g),y+row*(th+g),hit,th)
     expect(board.tiles["band-%d-%s" % [who,group]].get_global_rect()==expected,label+" mirrored right slot "+str(who)+group)
   area=Rect2(B.position.x+hit+g*2,y,B.size.x-hit*3-g*5,board.row_h)
  else:
   var band_y=B.position.y if enemy else B.position.y+board.band_h+g+board.row_h+g*2+board.row_h+g
   var order=["leader","melody","item","barrier","time"]
   for i in range(order.size()):
    var x=B.position.x+i*(board.band_h+g) if i<2 else B.end.x-(5-i)*(board.band_h+g)+g
    expect(board.tiles["band-%d-%s" % [who,order[i]]].get_global_rect()==Rect2(x,band_y,board.band_h,board.band_h),label+" original band slot "+str(who)+order[i])
   area=Rect2(B.position.x,B.position.y+board.band_h+g+(0 if enemy else board.row_h+g*2),B.size.x,board.row_h)
  var key="units-"+str(who);var info=board.rows[key];var paged=info.pages.size()>1
  if paged:
   for direction in ["prev","next"]:
    var x=area.position.x if direction=="prev" else area.end.x-hit
    expect(board.tiles["page-"+key+"-"+direction].get_global_rect()==Rect2(x,area.position.y,hit,board.row_h),label+" pager at unit area edge "+key+direction)
  var page=info.pages[info.page];var gap=12.0 if paged else 10.0
  var total=maxi(0,page.size()-1)*gap
  for c in page:total+=board.row_h if c.tapped else floorf(board.row_h/1.4)
  var x=area.get_center().x-total/2
  for c in page:
   var width=board.row_h if c.tapped else floorf(board.row_h/1.4)
   var height=floorf(board.row_h/1.4) if c.tapped else board.row_h
   var rect=board.cards["card_"+str(c.uid)].get_global_rect()
   expect(area.encloses(rect),label+" card inside unit area "+str(c.uid))
   expect(rect==Rect2(x,area.position.y+(board.row_h-height)/2,width,height),label+" centered card geometry "+str(c.uid))
   x+=width+gap

func check_shapes():
 for who in range(2):
  for c in e.players[who].field:
   var node=board.cards["card_"+str(c.uid)]
   var ratio=node.size.x/node.size.y
   expect(absf(ratio-(1.4 if c.tapped else 1.0/1.4))<0.025,"portrait/landscape ratio "+str(c.uid))
   expect(is_equal_approx(node.art.rotation,PI/2 if c.tapped else 0),"art rotation "+str(c.uid))

func check_badges():
 for key in board.cards:
  if not board.cards[key].visible:continue
  expect(view.card_badges.has(key),"existing badge for "+key)
  if view.card_badges.has(key):
   var badge=view.card_badges[key].root
   expect(badge.visible and board.card_rect(key).grow(2).has_point(badge.global_position),"badge follows 2D rect "+key)

func check_pages():
 await fill(14);check_layout("paged");check_badges()
 for who in range(2):
  var key="units-"+str(who);var info=board.rows[key]
  expect(info.pages.size()>1,"14 units produce pages "+key)
  var counts=info.pages.map(func(page):return page.size())
  print("PAGE SIZES ",key," ",counts)
  expect(counts==[5,4,4,1],"inline ordered units fill four pages "+key)
  if info.pages.size()<2:continue
  var next=board.tiles["page-"+key+"-next"]
  expect(next.visible and next.props.count==14-info.pages[0].size(),"pager counts hidden units "+key)
  var hidden=info.pages.back().back()
  expect(board.card_rect("card_"+str(hidden.uid))==next.get_global_rect(),"hidden arrow targets next pager "+key)
  await tap(next);await settle()
  expect(board.rows[key].page==1,"native pager changes page "+key)
  check_badges()
  var anchor=board.anchors[key];view.render();await frames()
  expect(board.anchors[key]==anchor,"render preserves page anchor "+key)
  for page_index in range(2,info.pages.size()):
   await tap(board.tiles["page-"+key+"-next"]);await settle()
   expect(board.rows[key].page==page_index,"native pager reaches inline page "+str(page_index)+" "+key)
  expect(board.tiles["page-"+key+"-next"].disabled and board.tiles["page-"+key+"-next"].props.count==0,"last inline page has no hidden units after it "+key)
  await tap(board.tiles["page-"+key+"-prev"]);await settle()
  expect(board.rows[key].page==info.pages.size()-2,"native previous pager returns from last page "+key)
 # An actual new own unit gets its page without touching engine ordering.
 var newcomer=put("53","field");newcomer.entered_turns=0;await redraw()
 expect(board.cards["card_"+str(newcomer.uid)].visible,"new own unit automatically gets its page")
 await shot("paged-units")

func check_actions_and_hold():
 await fill()
 var unit=e.players[0].field[0];var node=board.cards["card_"+str(unit.uid)]
 view.object_clicked(unit.uid)
 var expected=[view.attack_preview_uid,view.android_action_uid]
 view.close_overlay();view.clear_attack_preview();view.android_action_uid=0;await redraw()
 await tap(node)
 expect([view.attack_preview_uid,view.android_action_uid]==expected and expected!=[0,0],"native 2D click uses object_clicked")
 view.close_overlay();view.clear_attack_preview();view.android_action_uid=0;view.inspect_id="";await redraw()
 await create_timer(0.3).timeout
 await click(node.get_global_rect().get_center());await frames()
 expect(view.attack_preview_uid==unit.uid or view.android_action_uid==unit.uid,"mouse testing uses the same 2D card action")
 view.close_overlay();view.clear_attack_preview();view.android_action_uid=0;view.inspect_id="";await redraw()
 var at=node.get_global_rect().get_center()
 await touch(at,true);await create_timer(CardPreviewHold.seconds+0.08).timeout;await frames()
 expect(not view.inspect_id.is_empty(),"long hold inspects the 2D card")
 await shot("long-hold")
 await touch(at,false)
 expect(view.attack_preview_uid==0 and view.android_action_uid==0,"hold release never clicks")
 view.inspect_id="";view.update_inspection();await redraw()
 at=node.get_global_rect().get_center();await touch(at,true)
 var motion=InputEventScreenDrag.new();motion.index=0;motion.position=at+Vector2(20,0);root.push_input(motion,true);await frames()
 await touch(at+Vector2(20,0),false)
 expect(view.attack_preview_uid==0 and view.android_action_uid==0,"12px movement cancels a card press")

func check_left():
 await fill()
 for who in range(2):
  for zone in ["grave","exile"]:expect(board.tiles["zone-%d-%s" % [who,zone]].props.count==e.players[who][zone].size(),"left count "+str(who)+zone)
 await tap(board.tiles["zone-0-grave"])
 expect(is_instance_valid(view.browser_panel) and view.browser_panel.visible and view.browser_zone=="grave" and view.browser_owner==0,"2D grave opens existing browser")
 view.close_debug();await redraw()
 await tap(board.tiles["summary-0"])
 expect(view.android_palette_view and view.android_palette_focus_owner()==0,"summary forwards existing palette toggle")
 await tap(board.tiles["summary-0"])
 expect(not view.android_palette_view,"summary toggle returns to battlefield")
 var flexible=e.players[0].palette[0];flexible.token_colors=["红","蓝"]
 e.players[0].palette[1].tapped=true
 var before=board.summary(0);var after=board.summary(0,[{"uid":flexible.uid,"color":"红"}])
 expect(before.total==4 and before.count==5 and after.total==3,"summary counts cards once and removes reservations")
 expect(before["红"]==after["红"]+1 and before["蓝"]==after["蓝"]+1,"multicolor reservation removes each available color")
 for i in range(6):put("164","palette")
 var source=put("164","hand");await redraw();view.request_cast(source.uid);view.start_payment();await redraw()
 expect(board.tiles["summary-0"].props.pay,"payment summary displays before and after")
 await shot("payment-summary")
 view.cancel_cast();await redraw();await shot("left-summaries")

func check_permanents():
 await fill()
 var first=put("item-fdf-096","field");var second=put("item-fdf-096","field")
 await redraw()
 var entry=board.tiles["band-0-item"]
 expect(entry.props.count==2,"item band counts two items")
 await tap(entry);await settle();await frames()
 expect(board.sheet.visible and board.rows.perm.pages[0].size()==2,"item band opens two portrait cards")
 expect(board.cards["card_"+str(first.uid)].visible and board.cards["card_"+str(second.uid)].visible,"both expanded items are visible")
 var g=app.ui_metrics.gap;var hit=app.ui_metrics.hit
 expect(board.sheet_rect==Rect2(board.position+Vector2.ONE*g,board.size-Vector2.ONE*g*2),"expansion retains full board panel bounds")
 var height=minf(board.row_h,board.sheet_rect.size.y-hit-g*3)
 expect(board.cards["card_"+str(first.uid)].size==Vector2(floorf(height/1.4),height),"expanded card height follows current unit row")
 var first_rect=board.cards["card_"+str(first.uid)].get_global_rect();var second_rect=board.cards["card_"+str(second.uid)].get_global_rect()
 expect(board.sheet_rect.encloses(first_rect) and board.sheet_rect.encloses(second_rect),"expanded items fit inside full board panel")
 expect(not first_rect.intersects(second_rect),"expanded items do not overlap after placement animation")
 expect(e.players[0].field.filter(func(c):return e.is_unit(c)).all(func(c):return not view.card_badges["card_"+str(c.uid)].root.visible),"expansion hides badges of covered units")
 await shot("item-expansion")
 view.object_clicked(first.uid);var expected=view.android_action_uid
 view.close_overlay();view.android_action_uid=0;view.render();await frames()
 if board.opened.is_empty():board.open_region(0,"item")
 await settle();await tap(board.cards["card_"+str(first.uid)])
 expect(view.android_action_uid==expected and expected==first.uid,"expanded card uses object_clicked")
 view.close_overlay();view.android_action_uid=0;view.render();await frames()
 if board.opened.is_empty():board.open_region(0,"item")
 await tap(board.tiles["perm-close"])
 expect(not board.sheet.visible,"expansion close button works")
 board.open_region(0,"item");e.revision+=1;await redraw()
 expect(not board.sheet.visible,"engine revision closes expansion")
 board.open_region(0,"item")
 await touch(board.get_global_rect().position+Vector2(1,1),true);await touch(board.get_global_rect().position+Vector2(1,1),false)
 expect(not board.sheet.visible,"press outside expansion closes it")

func check_targets():
 await fill(14)
 var target=e.players[1].field.back();target.plus_counters=3
 var key="card_"+str(target.uid);var row="units-1"
 board.anchors[row]="card_"+str(e.players[1].field[0].uid)
 var spell=put("130","hand")
 for i in range(6):put("166","palette");put("168","palette")
 await redraw()
 expect(not board.cards.has(key) or not board.cards[key].visible,"legal target begins on another page")
 view.request_cast(spell.uid);await redraw()
 expect(view.local.get("mode","")=="target","real spell enters target selection")
 expect(view.picker.available_refs().any(func(ref):return ref.get("uid",0)==target.uid),"real spell offers high-spirit target")
 var node=board.cards[key]
 expect(node.visible and board.rows[row].page>0,"entering targets automatically jumps to the legal page")
 expect(node.legal and not node.selected,"legal unit has blue state")
 var illegal=board.cards.values().filter(func(c):return c.visible and not c.legal)
 expect(not illegal.is_empty() and illegal.all(func(c):return is_equal_approx(c.modulate.a,0.45)),"illegal unit cards dim to 0.45")
 await tap(node)
 expect(view.picker.selected_refs().any(func(ref):return ref.get("uid",0)==target.uid),"native 2D target click selects picker ref")
 expect(node.selected,"selected target uses gold state")
 await shot("unit-targeting")
 view.cancel_cast();await redraw()

func check_settings():
 view.settings_menu();await frames()
 var column=view.android_battle_menu_root
 expect(column.find_child("AndroidExperimentalBattleUI",true,false) is CheckButton,"battle settings contains experimental toggle")
 for key in ["AutoCameraFocus","AndroidManualCamera","AndroidZoneShortcutsSetting"]:
  expect(column.find_child(key,true,false).disabled,"2D mode disables "+key)
 for caption in ["3D 斜视","2D 上方俯视"]:expect(find_button(column,caption).disabled,"2D mode disables "+caption)
 await shot("battle-settings")
 view.close_android_battle_menu();app.set_android_experimental_battle_ui(false);await frames()
 expect(view.android_board==board and not view.stage.visible,"setting changes wait until next battle")
 expect(view.message=="试验对战界面将在下一局生效","setting explains next-battle activation")
 app.set_android_experimental_battle_ui(true)

func check_combat():
 await fill()
 var attacker=e.players[0].field[0];var node=board.cards["card_"+str(attacker.uid)]
 var home=node.position
 e.combat={"attacker":e.ref_target(attacker),"blockers":[],"owner":0}
 view.table.combat_animating=true
 await create_timer(0.08).timeout
 expect(node.position.y<home.y-1,"combat animation start dashes the 2D attacker toward enemy row")
 var count=view.effects.get_child_count()
 view.show_combat_impact(attacker.uid,0)
 expect(view.effects.get_child_count()==count+1,"combat impact reuses existing effect")
 var flash=view.effects.get_child(view.effects.get_child_count()-1)
 expect((flash.position+flash.size/2).distance_to(board.card_rect("card_"+str(attacker.uid)).get_center())<2,"combat impact is centered on 2D card")
 await create_timer(0.35).timeout
 expect(node.position.is_equal_approx(home),"attacker returns home after 120ms out and 180ms back")
 view.table.combat_animating=false;e.combat={};await redraw()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1560,720)
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root_override.path_join("settings.json")
 app.is_android=true;app.layout_dpi_override=280;app.layout_safe_override=Rect2(40,0,1504,704)
 root.add_child(app);await frames();app.load_legacy_test_decks()
 expect(not app.android_experimental_battle_ui,"experimental UI defaults off")
 app.settings();await frames()
 var toggle=app.screen.find_child("AndroidExperimentalBattleUI",true,false)
 expect(toggle is CheckButton and not toggle.button_pressed,"Android menu contains experimental setting")
 app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
 expect(view.android_board==null and view.stage.visible,"disabled Android path retains visible 3D stage")
 app.set_android_experimental_battle_ui(true)
 var saved=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
 expect(saved.get("android_experimental_battle_ui")==true,"settings JSON writes experimental flag")
 var settings_path=app.settings_path
 app.queue_free();await frames()
 app=load("res://main.tscn").instantiate();app.settings_path=settings_path
 app.is_android=true;app.layout_dpi_override=280;app.layout_safe_override=Rect2(40,0,1504,704)
 root.add_child(app);await frames();app.load_legacy_test_decks()
 expect(app.android_experimental_battle_ui,"restart reads experimental flag")
 app.android_experimental_battle_ui=true;app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;board=view.android_board;await frames()
 expect(board!=null and not view.stage.visible,"enabled battle builds 2D board and hides stage")
 expect(view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"2D mode stops 3D rendering")
 expect(not is_instance_valid(view.android_zone_shortcuts),"2D mode omits floating zone shortcuts")
 await fill();check_layout("three units");check_shapes();check_badges();await shot("battle")
 expect(board.board_layout_mode=="inline","1560x720 uses inline layout")
 var portrait=board.cards["card_"+str(e.players[0].field[0].uid)]
 expect(portrait.size.x>=BASELINE_PORTRAIT_WIDTH*1.5,"inline portrait width grows at least 1.5 times measured 85px baseline")
 expect(not view.opponent_layer.visible,"normal opponent hand backs are hidden")
 expect(not view.hud.get_node("OpponentHandCount").visible,"opponent hand count moves to left summary")
 expect(board.get_index()==0,"AndroidBoard is the first UI child below badges")
 await check_pages();await check_actions_and_hold();await check_left();await check_permanents();await check_targets();await check_settings();await check_combat()
 root.size=Vector2i(1280,720);app.layout_dpi_override=240;app.layout_safe_override=Rect2(32,0,1232,704)
 app.refresh_responsive_layout();await frames();await fill();check_layout("resized");await shot("battle-resized")
 # A lower-DPI fixture keeps the existing left controls clear while forcing band mode.
 app.layout_dpi_override=200;app.layout_safe_override=Rect2(32,0,1232,540)
 app.refresh_responsive_layout();await frames();await fill();check_layout("band fallback");check_shapes();check_badges()
 expect(floorf((board.size.y-app.ui_metrics.gap*3)/2)<app.ui_metrics.hit*2+app.ui_metrics.gap,"540px safe height at dpi200 forces band threshold")
 expect(board.board_layout_mode=="band","short safe area retains original band layout")
 await shot("band-fallback")
 view.queue_free();app.duel_view=null;await frames();app.is_android=false;app.refresh_ui_metrics();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);await frames()
 expect(view.android_board==null and view.stage.visible,"desktop ignores enabled Android experiment")
 print("ANDROID EXPERIMENTAL BOARD: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
