extends "res://tests/support/ui_base.gd"
const CardPreviewHold=preload("res://scripts/card_preview_hold_settings.gd")
const BoardCard=preload("res://scripts/android_board/board_card.gd")
# Measured by the unmodified board at 1560x720 / dpi280 / safe (40,0,1504,704).
const BASELINE_PORTRAIT_WIDTH=85.0
var output="res://work/android-experimental-board"
var board

func check_left_rail(label: String) -> int:
 var L: Rect2=board.left_column;var safe=app.ui_metrics.safe
 var hit=app.ui_metrics.hit;var g=app.ui_metrics.gap
 var sh=roundf(hit*1.3);var zh=maxf(hit,roundf(hit*1.2));var ctrl_h=hit*2+g;var step=1
 if sh*2+zh*2+ctrl_h+g*4>L.size.y:zh=hit;step=2
 if sh*2+zh*2+ctrl_h+g*4>L.size.y:sh=hit;step=3
 var compact=sh*2+zh*2+ctrl_h+g*4>L.size.y
 if compact:step=4
 var single_row=compact and sh*2+ctrl_h+g*3>L.size.y
 if single_row:ctrl_h=hit;step=5
 print("LEFT RAIL ",label," step=",step," compact=",compact," single_row=",single_row," L=",L," hit=",hit)
 expect(board.left_layout_step==step and board.left_compact==compact and board.left_single_row==single_row,label+" stops at first fitting degradation step")
 var keep=view.hud.get_node("AutoPayKeepButton");var hand=view.hud.get_node("HandDisplayToggle")
 expect(keep.visible and keep.get_global_rect()==board.keep_colors_rect and view.keep_button_rect()==board.keep_colors_rect,label+" keep node uses board rect")
 expect(hand.visible and hand.get_global_rect()==board.hand_toggle_rect and view.responsive.hand_toggle_rect==board.hand_toggle_rect,label+" hand node uses board rect")
 expect(view.emotes.button.visible and not view.emotes.button.disabled,label+" emote fixture is available")
 expect(view.emotes.entry_rect()==board.emote_rect,label+" emote entry uses board rect")
 if view.emotes.button.visible:expect(view.emotes.button.get_global_rect()==board.emote_rect,label+" emote node uses board rect")
 var rects={"keep":keep.get_global_rect(),"hand":hand.get_global_rect(),"emote":board.emote_rect}
 for who in range(2):
  var summary_node=board.tiles["summary-"+str(who)]
  expect(summary_node.visible and summary_node.size.y==sh,label+" summary height "+str(who))
  expect(summary_node.props.title.ends_with("墓%d 除%d" % [e.players[who].grave.size(),e.players[who].exile.size()])==compact,label+" compact summary counts "+str(who))
  rects[str(summary_node.name)]=summary_node.get_global_rect()
  for zone in ["grave","exile"]:
   var key="zone-%d-%s" % [who,zone];var node=board.tiles.get(key)
   expect(is_instance_valid(node) and node.visible if not compact else not is_instance_valid(node) or not node.visible,label+" zone visibility "+key)
   if not compact:
    expect(node.size.y==zh,label+" zone height "+key)
    rects[key]=node.get_global_rect()
 var top=board.tiles["summary-"+str(1-view.local_seat)].get_global_rect().end.y
 var bottom=board.tiles["summary-"+str(view.local_seat)].get_global_rect().position.y
 if not compact:top+=g+zh;bottom-=g+zh
 var control_top=minf(board.keep_colors_rect.position.y,board.emote_rect.position.y)
 expect(control_top==roundf((top+bottom-ctrl_h)/2),label+" controls centered in middle gap")
 if single_row:
  expect(keep.text=="保留"+("无" if app.auto_pay_keep_colors.is_empty() else "".join(app.auto_pay_keep_colors)),label+" single row abbreviates keep caption")
  expect(hand.text==("手牌" if view.hand_display_enabled else "显示"),label+" single row abbreviates hand caption")
  expect(board.keep_colors_rect.position.x==board.emote_rect.end.x+g and board.hand_toggle_rect.position.x==board.keep_colors_rect.end.x+g,label+" single row follows emote keep hand order")
 else:
  expect(board.keep_colors_rect.size==Vector2(L.size.x,hit),label+" keep occupies first full row")
  expect(board.emote_rect.position.y==board.keep_colors_rect.end.y+g and board.hand_toggle_rect.position.y==board.emote_rect.position.y,label+" emote and hand share second row")
  expect(board.hand_toggle_rect.position.x==board.emote_rect.end.x+g and board.hand_toggle_rect.end.x==L.end.x,label+" second row fills rail width")
 for node in [keep,hand,view.emotes.button]:
  expect(node.has_method("hit_rect") and node.hit_rect().size.x>=hit and node.hit_rect().size.y>=hit,label+" expanded touch target "+str(node.name))
 var opponent=view.emotes.opponent_button
 var slot=view.emotes.toolbar_slot(hit,g)
 expect(opponent.visible==slot.has_area(),label+" opponent toggle visibility follows toolbar room")
 if opponent.visible:
  expect(opponent.get_global_rect()==view.emotes.opponent_entry_rect(),label+" opponent toggle uses toolbar slot")
  expect(not opponent.get_global_rect().intersects(L),label+" opponent toggle leaves rail clear")
  rects["opponent"]=opponent.get_global_rect()
 var keys=rects.keys()
 for i in range(keys.size()):
  var key=keys[i];var rect: Rect2=rects[key]
  expect(rect.has_area() and safe.encloses(rect),label+" safe "+key)
  if key!="opponent":expect(L.encloses(rect),label+" in rail "+key)
  expect(rect.position==rect.position.round() and rect.size==rect.size.round(),label+" integer pixels "+key)
  for j in range(i):expect(not rect.intersects(rects[keys[j]]),label+" separate "+key+" / "+keys[j])
 expect(safe.encloses(view.keep_popup_rect()),label+" keep popup fits safe area")
 return step

func check_left_device_matrix():
 var devices=[
  [1560,720,280,Rect2(40,0,1504,704)],
  [1280,720,240,Rect2(32,0,1232,704)],
  [2340,1080,440,Rect2(80,0,2180,1080)],
  [1600,720,320,Rect2(48,0,1504,720)],
  [1920,1080,320,Rect2(0,0,1920,1080)],
  [1280,800,280,Rect2(0,24,1280,776)],
  [1280,600,280,Rect2(0,0,1280,600)]
 ]
 for device in devices:
  root.size=Vector2i(device[0],device[1]);app.layout_dpi_override=device[2];app.layout_safe_override=device[3]
  app.refresh_responsive_layout();await frames();await fill()
  view.emotes.reset();view.replay_recording.finished=true;e.leader_emote_profiles[view.local_seat].enabled=true
  await redraw()
  var label="%dx%d-%d" % [device[0],device[1],device[2]]
  var step=check_left_rail(label)
  if device[1]==600:expect(step>=4,label+" short device uses compact or single row")
  await shot("left-rail-"+label)
  await tap(view.hud.get_node("AutoPayKeepButton"))
  expect(view.keep_popup_open and is_instance_valid(view.keep_popup) and app.ui_metrics.safe.encloses(view.keep_popup.get_global_rect()),label+" rendered keep popup fits safe area")
  view.keep_popup_open=false;await redraw()
 # Force the remaining fallback and the toolbar-without-room case explicitly.
 root.size=Vector2i(1280,480);app.layout_dpi_override=280;app.layout_safe_override=Rect2(0,0,1280,480)
 app.refresh_responsive_layout();await frames();await fill()
 view.emotes.reset();e.leader_emote_profiles[view.local_seat].enabled=true;await redraw()
 expect(check_left_rail("single-row fallback")==5,"shorter device exercises single row fallback")
 var saved_colors=app.auto_pay_keep_colors.duplicate();app.auto_pay_keep_colors=["红","蓝"];await redraw()
 expect(view.hud.get_node("AutoPayKeepButton").text=="保留红蓝","single row uses abbreviated color names")
 app.auto_pay_keep_colors=saved_colors
 var hand=view.hud.get_node("HandDisplayToggle");var hand_rect=hand.get_global_rect()
 await tap(hand)
 expect(not view.hand_display_enabled and view.hud.get_node("HandDisplayToggle").text=="显示" and view.hud.get_node("HandDisplayToggle").get_global_rect()==hand_rect,"single row hand toggle changes caption without moving")
 view.set_hand_display(true);await redraw()
 var phase=view.responsive.toolbar.get_node("BattlePhase");phase.text="没有空位".repeat(100)
 view.emotes.refresh();await frames()
 expect(not view.emotes.opponent_entry_rect().has_area() and not view.emotes.opponent_button.visible,"opponent toggle hides when toolbar has no room")
 await tap(board.tiles["summary-0"])
 expect(board.palette.visible and view.android_palette_focus_owner()==0,"compact summary opens own palette")
 expect(board.tiles.has("palette-grave") and board.tiles["palette-grave"].visible and board.tiles["palette-exile"].visible,"compact palette header shows grave and exile entries")
 var grave: Rect2=board.tiles["palette-grave"].get_global_rect();var exile: Rect2=board.tiles["palette-exile"].get_global_rect()
 var close: Rect2=board.tiles["palette-close"].get_global_rect();var hit=app.ui_metrics.hit
 expect(board.palette_rect.encloses(grave) and board.palette_rect.encloses(exile),"compact palette header entries fit panel")
 expect(not grave.intersects(exile) and not grave.intersects(close) and not exile.intersects(close),"compact palette header entries stay separate")
 expect(minf(grave.size.x,grave.size.y)>=hit and minf(exile.size.x,exile.size.y)>=hit,"compact palette header entries reach hit")
 await tap(board.tiles["palette-grave"])
 expect(is_instance_valid(view.browser_panel) and view.browser_panel.visible and view.browser_zone=="grave" and view.browser_owner==0,"compact palette grave entry opens grave browser")
 view.close_debug();view.set_android_camera_focus(-1);await redraw()

func check_compact_possession():
 expect(board.left_compact,"compact fixture")
 await fill()
 e.phase="possession";e.pending={"kind":"possession","owner":view.local_seat};await redraw()
 await tap(board.tiles["summary-0"]);await tap(board.tiles["summary-0"])
 expect(board.palette.visible,"compact possession summary reopens palette")
 expect(not is_instance_valid(view.browser_panel) or not view.browser_panel.visible,"compact summary does not open pile browser")
 var node=palette_nodes(0).filter(func(c):return not c.card.tapped)[0]
 var palette_uid=node.card.uid;var hand_uid=e.players[0].hand[0].uid
 await tap(node);await tap(view.hand_nodes[hand_uid])
 expect(view.selected_in_zone("palette")!=0 and view.selected_in_zone("hand")!=0,"compact possession selects palette and hand")
 await tap(find_button(view.ui,"确定凭依"))
 expect(e.players[0].hand.any(func(c):return c.uid==palette_uid and c.zone=="hand") and e.players[0].palette.any(func(c):return c.uid==hand_uid and c.zone=="palette"),"compact possession swap completes")
 e.pending={};e.phase="main";view.selection=[];view.set_android_camera_focus(-1);await redraw()

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
 view.android_palette_view=false;view.android_focus_owner=view.local_seat
 view.android_camera_restore={};view.android_auto_focus_owner=-1;view.android_manual_focus_override=-1;board.opened={}
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
   expect(is_equal_approx(node.art.rotation,-PI/2 if c.tapped else 0),"art rotation "+str(c.uid))

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

func palette_nodes(who: int) -> Array:
 return board.cards.values().filter(func(node):return node.visible and node.card.zone=="palette" and node.card.owner==who)

func android_tap(node: Control,mouse_first: bool=false):
 var at=node.get_global_rect().get_center()
 if mouse_first:await create_timer(0.3).timeout
 for pressed in [true,false]:
  var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=pressed
  var mouse=InputEventMouseButton.new();mouse.position=at;mouse.global_position=at
  mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed;mouse.device=-1
  if mouse_first:root.push_input(mouse,true);await process_frame
  root.push_input(event,true);await process_frame
  if node is BoardCard:print("REAL TAP pressed=",pressed," native mouse first=",mouse_first," captured=",board.pressed_control," finger=",board.finger," moved=",board.moved," selected=",view.selected_in_zone("palette"))
  if not mouse_first:root.push_input(mouse,true)
  await frames(2)
 await frames()

func possession_diagnostics(node: Control):
 var at=node.get_global_rect().get_center();var c=node.card
 var surface=view.android_card_touch.surface_at(view.ui,at)
 print("REAL POSSESSION busy: menu=",app.menu_popup_open()," history=",view.history_open," observing=",view.observing," revealing=",view.revealing()," combat=",view.table.combat_animating," banner=",view.banner.visible," presentations=",e.presentation_events.size())
 print("REAL POSSESSION surface=",surface.get_path() if surface!=null else "null"," board descendant=",surface!=null and board.is_ancestor_of(surface)," hit=",board.hit_control(at)," expanded=",node.get_meta("expanded",false))
 print("REAL POSSESSION input: emote wheel=",is_instance_valid(view.emotes.wheel)," inspection=",view.inspection.visible," dismiss finger=",view.android_inspection_dismiss_finger," suppress=",Time.get_ticks_msec()<view.suppress_touch_mouse_until)
 print("REAL POSSESSION object: uid=",c.uid," can_possess=",e.can_possess(c)," tapped=",c.tapped," acting=",view.acting_player()," pending=",e.pending," turn=",e.turn," own turns=",e.players[view.local_seat].turns)

func check_real_possession_tap():
 root.size=Vector2i(2000,923);app.layout_dpi_override=380;app.layout_safe_override=Rect2(0,0,2000,923)
 app.refresh_responsive_layout();await frames()
 # Seat zero plays second: the screenshot's global turn 2 has one palette card.
 # Keep the actual opening decks, reset/draw steps and presentation queue intact.
 app.begin_battle(false);view=app.duel_view;view.set_process(false);e=view.engine;board=view.android_board
 await frames();e.mulligan(0,[]);e.mulligan(1,[])
 for step in range(30):
  if e.turn==2 and e.pending.get("kind","")=="possession" and e.pending.owner==view.local_seat:break
  if e.pending.get("kind","")=="possession":e.possession()
  else:e.pass_priority(e.priority)
  view.render();await frames(2)
 view.render();await settle();view.render();await frames()
 expect(e.turn==2 and e.phase=="possession" and e.pending.get("owner",-1)==view.local_seat,"real opening naturally reaches own turn-2 possession")
 var nodes=palette_nodes(view.local_seat)
 expect(board.palette.visible and nodes.size()==1,"real possession automatically opens the one-card palette")
 var physical_hit=app.ui_metrics.hit*float(root.size.y)/view.get_viewport_rect().size.y
 print("REAL POSSESSION geometry: root=",root.size," hit=",app.ui_metrics.hit," physical hit=",physical_hit," safe=",app.ui_metrics.safe)
 expect(absf(physical_hit-95)<2,"real possession buttons match 95px phone hit height")
 if nodes.is_empty():return
 var node=nodes[0];var uid=node.card.uid
 possession_diagnostics(node)
 expect(node.legal and not node.selected,"real possession palette starts with blue legal border")
 await shot("real-possession-before")
 await android_tap(node)
 expect(view.selected_in_zone("palette")==uid,"real possession touch plus mouse echo selects palette uid")
 expect(node.selected,"real possession selected palette draws gold border")
 view.right_cancel();await frames()
 # stage_input() also guards the backend's mouse-before-touch dispatch order.
 await android_tap(node,true)
 expect(view.selected_in_zone("palette")==uid and node.selected,"real possession mouse-before-touch also selects gold palette")
 expect(board.pressed_control==null and board.finger==-2,"real possession releases board capture after both input orders")
 var hand=e.players[view.local_seat].hand.filter(func(c):return e.can_possess(c))[0];var hand_uid=hand.uid
 await android_tap(view.hand_nodes[hand_uid])
 expect(view.selected_in_zone("hand")==hand_uid,"real possession touch plus mouse echo selects hand")
 var confirm=find_button(view.ui,"确定凭依")
 expect(is_instance_valid(confirm) and not confirm.disabled,"real possession confirmation enables after both selections")
 await shot("real-possession-after")
 if is_instance_valid(confirm) and not confirm.disabled:await android_tap(confirm)
 expect(e.find_card(uid).zone=="hand" and e.find_card(hand_uid).zone=="palette","real possession touch confirmation completes exchange")

func check_real_board_taps():
 # A seeded opening deck makes ordinary paid casts reproducible. No zone,
 # pending, tapped or turn state is manufactured for these input checks.
 var deck=Store.blank("Real board input");deck.leader="70"
 for i in range(25):deck.main.append_array(["53","item-fdn-044"])
 app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;board=view.android_board
 e.start(deck,deck,0,42);e.mulligan(0,[]);e.mulligan(1,[])
 for step in range(120):
  if e.active==0 and e.phase=="main" and e.pending.is_empty() and e.stack.is_empty():
   if not e.units(0).is_empty() and e.players[0].field.any(func(c):return c.card_id=="item-fdn-044"):break
   var id="53" if e.units(0).is_empty() else "item-fdn-044"
   var castable=e.players[0].hand.filter(func(c):return c.card_id==id and e.cast_error(0,c.uid).is_empty())
   if not castable.is_empty():
    var c=castable[0]
    expect(e.commit_cast(0,c.uid,{},e.payment(0,e.cast_cost(0,c)).plan).is_empty(),"real board pays and casts "+id)
    continue
  if e.pending.get("kind","")=="possession":e.possession()
  else:e.pass_priority(e.priority)
 view.render();await settle();view.render();await frames()
 var units=e.units(0);var items=e.players[0].field.filter(func(c):return c.card_id=="item-fdn-044")
 expect(not units.is_empty() and not items.is_empty() and e.phase=="main","real board has naturally resolved unit and item")
 if units.is_empty() or items.is_empty():return
 var unit=units[0];var item=items[0];var node=board.cards["card_"+str(unit.uid)]
 for mouse_first in [false,true]:
  await android_tap(node,mouse_first)
  expect(view.attack_preview_uid==unit.uid or view.android_action_uid==unit.uid,"real unit row responds to touch, mouse first="+str(mouse_first))
  view.right_cancel();await frames()
  await android_tap(board.tiles["band-0-item"],mouse_first);await settle()
  expect(board.sheet.visible and board.cards["card_"+str(item.uid)].visible,"real band tile opens region, mouse first="+str(mouse_first))
  await android_tap(board.cards["card_"+str(item.uid)],mouse_first)
  expect(view.android_action_uid==item.uid and view.action_menu_open,"real expanded item opens actions, mouse first="+str(mouse_first))
  expect(board.pressed_control==null and board.finger==-2,"real board input sequence releases capture")
  view.inspect_id="";view.update_inspection();view.close_overlay();board.close_region();await frames()

func check_palette_geometry(who: int,label: String):
 var hit=app.ui_metrics.hit;var g=app.ui_metrics.gap
 expect(board.palette.visible and view.android_palette_view and view.android_palette_focus_owner()==who,label+" palette layer is open")
 expect(board.palette_rect==Rect2(board.position+Vector2.ONE*g,board.size-Vector2.ONE*g*2),label+" palette uses expansion panel bounds")
 var nodes=palette_nodes(who)
 for i in range(nodes.size()):
  var node=nodes[i];var key="card_"+str(node.card.uid);var rect=node.get_global_rect()
  var target=Rect2(node.global_position+node.hit_rect().position,node.hit_rect().size)
  expect(board.palette_rect.encloses(rect) and board.palette_rect.encloses(target),label+" palette card and touch area fit panel "+key)
  expect(minf(target.size.x,target.size.y)>=hit,label+" palette touch area reaches hit "+key)
  expect(board.card_visible(key) and board.card_rect(key)==rect,label+" palette anchors follow visible card "+key)
  expect(node.get_index()>board.palette.get_index(),label+" palette card draws above panel "+key)
  for j in range(i):
   var other=nodes[j];var other_target=Rect2(other.global_position+other.hit_rect().position,other.hit_rect().size)
   expect(not rect.intersects(other.get_global_rect()) and not target.intersects(other_target),label+" palette cards and hit areas do not overlap")
 expect(not board.palette_rect.intersects(view.hand_scroll.get_global_rect()),label+" palette leaves hand clear")
 for c in e.players[1-who].palette:
  var key="card_"+str(c.uid)
  expect(not board.card_visible(key) and board.card_rect(key)==board.zone_rect(1-who,"palette"),label+" other palette anchors to summary")
 for c in e.players[0].field:
  expect(not board.card_visible("card_"+str(c.uid)),label+" covered unit badge is hidden")

func check_palette_layer():
 await fill()
 await tap(board.tiles["summary-0"]);await settle()
 check_palette_geometry(0,"own")
 expect(palette_nodes(0).size()==e.players[0].palette.size(),"own layer displays every palette card")
 expect(board.palette.get_node("Title").text=="我方颜色盘 · 可用 5/5","own palette title shows summary counts")
 expect(board.tiles["summary-0"].props.selected and not board.tiles["summary-1"].props.selected,"opened summary has gold state")
 var close=board.tiles["palette-close"]
 expect(close.size==Vector2.ONE*app.ui_metrics.hit,"palette close button is hit by hit")
 await shot("palette-own")
 var inspected=palette_nodes(0)[0]
 await touch(inspected.get_global_rect().get_center(),true);await create_timer(CardPreviewHold.seconds+0.08).timeout;await frames()
 expect(view.inspect_id==str(inspected.card.card_id),"palette long hold opens existing inspection")
 await touch(inspected.get_global_rect().get_center(),false)
 view.inspect_id="";view.update_inspection();await redraw()
 await tap(board.tiles["summary-0"])
 expect(not view.android_palette_view and not board.palette.visible,"second own summary tap closes palette layer")
 for c in e.players[0].palette:
  var key="card_"+str(c.uid)
  expect(not board.card_visible(key) and board.card_rect(key)==board.zone_rect(0,"palette"),"closed palette anchors to summary "+key)
 await tap(board.tiles["summary-1"]);await settle()
 check_palette_geometry(1,"enemy")
 expect(palette_nodes(1).size()==e.players[1].palette.size(),"enemy layer displays every palette card")
 expect(board.palette.get_node("Title").text=="对手颜色盘 · 可用 5/5","enemy palette title shows summary counts")
 await shot("palette-enemy")
 await tap(board.tiles["palette-close"])
 expect(not view.android_palette_view and not board.palette.visible,"palette close button closes layer")
 var item=put("item-fdf-096","field");await redraw()
 board.open_region(0,"item");view.toggle_android_palette(0);await settle()
 expect(board.opened.is_empty() and not board.sheet.visible and board.palette.visible,"palette closes region expansion")
 await tap(board.tiles["band-0-item"]);await settle()
 expect(not view.android_palette_view and not board.palette.visible and board.sheet.visible and board.cards["card_"+str(item.uid)].visible,"band click closes palette before opening region")
 board.close_region()
 # Token colors use the same Pack.colors source as summary, including multicolor.
 await fill();e.players[0].palette=[]
 var multi=put("164","palette");multi.token_colors=["红","蓝"]
 var blue=put("164","palette");blue.token_colors=["蓝"]
 var red=put("164","palette");red.token_colors=["红"]
 var green=put("164","palette");green.token_colors=["绿"]
 var red2=put("164","palette");red2.token_colors=["红"]
 var yellow=put("164","palette");yellow.token_colors=["黄"]
 var black=put("164","palette");black.token_colors=["黑"]
 await redraw();view.toggle_android_palette(0);await settle()
 var ordered=[]
 for page in board.rows["palette-0"].pages:ordered.append_array(page.map(func(c):return c.uid))
 expect(ordered==[red.uid,red2.uid,multi.uid,blue.uid,green.uid,yellow.uid,black.uid],"palette sorts first color, single color, then uid")
 red.tapped=true;await redraw()
 var node=board.cards["card_"+str(red.uid)]
 expect(node.landscape and is_equal_approx(node.art.rotation,-PI/2) and node.size.x>node.size.y,"palette tapped card reuses landscape animation")
 check_palette_geometry(0,"tapped")
 view.set_android_camera_focus(-1)

func check_palette_payment():
 await fill();app.auto_camera_focus=false
 for i in range(6):put("164","palette")
 var source=put("164","hand");await redraw()
 var camera=[view.table.camera_offset,view.table.camera_frame_scale,view.table.camera_distance,view.table.top_down_camera_size,view.table.camera.global_transform]
 view.request_cast(source.uid);view.start_payment();await redraw()
 expect(view.local.get("mode","")=="payment" and board.payment.visible,"payment automatically opens palette with camera focus setting off")
 expect(view.android_camera_restore.keys().size()==2 and view.android_camera_restore.has("palette_view") and view.android_camera_restore.has("owner"),"experimental auto focus stores only palette state")
 # Casting proposes a payment plan; clear it to exercise adding a reservation.
 view.local.plan=[];await redraw()
 var options=board.payment.resources.values().filter(func(node):return not node.disabled)
 expect(not options.is_empty(),"payment exposes payable palette cards")
 if not options.is_empty():
  var node=options[0];var uid=int(str(node.name).trim_prefix("Resource-"))
  await tap(node)
  expect(view.local.plan.any(func(r):return r.uid==uid) and board.payment.resources.has(uid),"palette payment click reserves resource with gold state")
  var before=board.summary(0);var after=board.summary(0,view.local.plan)
  expect(board.payment.get_node("Title").text.begins_with("支付 · "),"palette payment title shows before and after availability")
  await shot("palette-payment")
  await tap(board.payment.resources[uid])
  expect(not view.local.plan.any(func(r):return r.uid==uid),"second palette payment click cancels reservation")
 expect(camera==[view.table.camera_offset,view.table.camera_frame_scale,view.table.camera_distance,view.table.top_down_camera_size,view.table.camera.global_transform],"experimental automatic palette focus leaves camera unchanged")
 view.cancel_cast();await redraw()
 expect(not board.payment.visible and view.android_camera_restore.is_empty(),"payment cancel restores closed palette")

func check_palette_possession():
 await fill();app.auto_camera_focus=false
 e.players[0].palette[1].tapped=true
 e.phase="possession";e.pending={"kind":"possession","owner":view.local_seat};await redraw()
 expect(board.palette.visible,"possession automatically opens palette with camera focus setting off")
 expect(view.hand_scroll.visible and not board.palette_rect.intersects(view.hand_scroll.get_global_rect()),"possession hand stays visible and clear of palette")
 var target=e.players[0].palette[0];var node=board.cards["card_"+str(target.uid)]
 expect(node.legal,"possession palette card is available")
 await tap(node)
 expect(view.selected_in_zone("palette")==target.uid and node.selected,"palette click selects possession card with gold state")
 var hand=e.players[0].hand[0]
 await tap(view.hand_nodes[hand.uid])
 expect(view.selected_in_zone("hand")==hand.uid,"possession hand remains clickable while palette is open")
 await shot("palette-possession")
 e.pending={};e.phase="main";view.selection=[];await redraw()
 expect(not board.palette.visible and view.android_camera_restore.is_empty(),"ending possession restores closed palette")
 e.phase="possession";e.pending={"kind":"possession","owner":view.local_seat};await redraw()
 await tap(board.tiles["palette-close"])
 expect(not view.android_palette_view and view.android_manual_focus_override==view.local_seat,"closing automatic palette records manual override")
 await redraw()
 expect(not board.palette.visible,"same possession pending does not reopen manually closed palette")
 e.pending={};e.phase="main";await redraw()
 expect(view.android_manual_focus_override==-1 and view.android_camera_restore.is_empty(),"ending pending clears manual override and restore")
 e.phase="possession";e.pending={"kind":"possession","owner":view.local_seat};await redraw()
 expect(board.palette.visible,"next possession opens palette again")
 e.pending={};e.phase="main";await redraw()
 view.toggle_android_palette(1)
 e.phase="possession";e.pending={"kind":"possession","owner":view.local_seat};await redraw()
 expect(view.android_palette_focus_owner()==0,"possession temporarily switches manually opened enemy palette")
 e.pending={};e.phase="main";await redraw()
 expect(board.palette.visible and view.android_palette_focus_owner()==1,"ending possession restores prior enemy palette")
 view.set_android_camera_focus(-1)

func check_palette_pages():
 await fill();e.players[1].palette=[]
 for i in range(30):
  var c=put("164","palette",1);c.tapped=i%3==1
 view.toggle_android_palette(1);await redraw()
 var info=board.rows["palette-1"];var count=0
 for page in info.pages:count+=page.size()
 expect(info.pages.size()>1 and count==30,"30 palette cards paginate with correct total")
 var next=board.tiles["palette-page-1-next"]
 expect(next.visible and next.props.count==30-info.pages[0].size(),"palette next pager counts every hidden card")
 check_palette_geometry(1,"paged")
 var hidden=info.pages.back().back();var hidden_key="card_"+str(hidden.uid)
 expect(not board.card_visible(hidden_key) and board.card_rect(hidden_key)==board.zone_rect(1,"palette"),"off-page palette card anchors to summary")
 await tap(next);await settle()
 expect(board.rows["palette-1"].page==1,"native palette next pager advances page")
 expect(board.tiles["palette-page-1-prev"].props.count==info.pages[0].size(),"palette previous pager counts hidden cards")
 var anchor=board.anchors["palette-1"];await redraw()
 expect(board.anchors["palette-1"]==anchor,"palette page anchor survives render")
 await tap(board.tiles["palette-page-1-prev"]);await settle()
 expect(board.rows["palette-1"].page==0,"native palette previous pager returns")
 # Real palette target selection jumps to its only legal card, across 3D pages.
 var source=put("49","grave")
 var first=info.pages[0][0]
 e.pending={"kind":"effect_choice","owner":0,"options":[e.ref_target(first),e.ref_target(hidden)],"trigger":{"source":source,"owner":0,"effect":"enter_palette_replace_choose","optional":true,"continuation":true,"data":{},"name":e.cards[source.card_id].name}}
 await redraw()
 expect(board.rows["palette-1"].page==0 and board.tiles["palette-page-1-next"].props.legal,"palette pager marks legal hidden target when current page is available")
 e.pending={"kind":"effect_choice","owner":0,"options":[e.ref_target(hidden)],"trigger":{"source":source,"owner":0,"effect":"enter_palette_replace_choose","optional":true,"continuation":true,"data":{},"name":e.cards[source.card_id].name}}
 await redraw()
 expect(view.android_palette_focus_owner()==1 and board.rows["palette-1"].page==info.pages.size()-1,"palette automatically jumps from unavailable page to first available card")
 var node=board.cards[hidden_key]
 expect(node.visible and node.legal,"enemy palette target is visible with blue state")
 var illegal=palette_nodes(1).filter(func(c):return not c.legal)
 expect(not illegal.is_empty() and illegal.all(func(c):return is_equal_approx(c.modulate.a,0.45)),"illegal palette targets dim using unit card rules")
 await tap(node)
 expect(view.picker.selected_refs().any(func(ref):return ref.get("uid",0)==hidden.uid) and node.selected,"enemy palette target click selects picker ref with gold state")
 e.pending={};view.picker.reset();view.selection=[hidden.uid]
 board.anchors["palette-1"]="card_"+str(info.pages[0][0].uid);await redraw()
 var pager=board.tiles["palette-page-1-next"]
 expect(board.rows["palette-1"].page==0 and pager.props.selected_hidden,"palette pager marks selected hidden target")
 view.selection=[];await redraw();view.set_android_camera_focus(-1)

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
 if view.android_palette_view:await tap(board.tiles["palette-close"])
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

func check_emote_anchor(who: int,node: Control,label: String):
 var bubble=view.emotes.bubbles.get(who)
 expect(node.visible and view.emotes.bubble_target(who)==node.get_global_rect(),label+" emote targets the displayed 2D card or tile")
 expect(is_instance_valid(bubble),label+" speech bubble survives board updates")
 if not is_instance_valid(bubble):return
 expect(bubble.points_down==(who==view.local_seat),label+" speech tail follows viewing seat")
 expect(app.ui_metrics.safe.grow(1).encloses(bubble.get_global_rect()),label+" speech stays inside safe area")
 var edge=node.get_global_rect().position.y if who==view.local_seat else node.get_global_rect().end.y
 var tip=bubble.get_global_rect().end.y if who==view.local_seat else bubble.get_global_rect().position.y
 expect(absf(tip-edge)<2,label+" speech tail meets the displayed anchor")

func check_emotes(label: String):
 for seat in [0,1]:
  view.local_seat=seat;view.table.local_seat=seat
  await fill(40 if board.board_layout_mode=="band" else 14);view.emotes.reset();view.replay_recording.finished=true
  expect(board.board_layout_mode==label,label+" emote fixture uses expected board mode")
  for who in [0,1]:e.leader_emote_profiles[who].enabled=true
  for who in [0,1]:
   var title=label+" seat "+str(seat)+" speaker "+str(who)
   var leader=e.players[who].leader;var key="card_"+str(leader.uid);var row="units-"+str(who)
   e.LeaderEmotes.emit_event(e,who,"greeting");await redraw();view.emotes.refresh()
   view.emotes.expires[who]=Time.get_ticks_msec()+60000
   check_emote_anchor(who,board.tiles["band-%d-leader" % who],title+" leader zone")
   if who==seat:await shot("emotes-"+label+"-seat-"+str(seat)+"-leader")
   e.detach(leader);e.shift(leader,"field");e.players[who].field.append(leader)
   e.presentation_events.clear();view.reveal_player.reset();await redraw()
   board.anchors[row]=key;board.sync();view.emotes.refresh()
   check_emote_anchor(who,board.cards[key],title+" battlefield")
   leader.tapped=true;board.sync();view.emotes.refresh()
   check_emote_anchor(who,board.cards[key],title+" tapped")
   board.anchors[row]="card_"+str(e.players[who].field[0].uid);board.sync();view.emotes.refresh()
   expect(board.rows[row].pages.size()>1 and not board.cards[key].visible,title+" leader is on another page")
   check_emote_anchor(who,board.tiles["page-"+row+"-next"],title+" paged out")
   board.anchors[row]=key;board.sync();view.emotes.refresh()
   check_emote_anchor(who,board.cards[key],title+" page restored")
   if who==seat:await shot("emotes-"+label+"-seat-"+str(seat)+"-field")
   # A missing 2D anchor must not fall back to the hidden 3D scene.
   board.cards[key].hide();view.emotes.refresh()
   expect(not view.emotes.bubble_target(who).has_area(),title+" missing 2D anchor uses edge fallback")
   e.detach(leader);e.shift(leader,"hand");e.players[who].hand.append(leader)
   e.presentation_events.clear();view.reveal_player.reset();await redraw();view.emotes.refresh()
   var bubble=view.emotes.bubbles.get(who)
   expect(is_instance_valid(bubble) and view.emotes.bubble_layout(who,bubble.size).fallback,title+" departed leader uses edge fallback")
  await shot("emotes-"+label+"-seat-"+str(seat))
  view.emotes.reset()
 view.local_seat=0;view.table.local_seat=0;await fill()

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
 if "--emotes-only" in OS.get_cmdline_user_args():
  await check_emotes("inline")
  root.size=Vector2i(1280,720)
  app.layout_dpi_override=200;app.layout_safe_override=Rect2(32,0,1232,540)
  app.refresh_responsive_layout();await frames()
  await check_emotes("band")
  print("ANDROID EMOTES UI: %d checks; %d failures" % [checks,failures.size()])
  app.queue_free();await frames();quit(0 if failures.is_empty() else 1);return
 await check_real_possession_tap()
 await check_real_board_taps()
 if "--real-possession-only" in OS.get_cmdline_user_args():
  print("ANDROID EXPERIMENTAL BOARD: %d checks; %d failures" % [checks,failures.size()])
  app.queue_free();await frames();quit(0 if failures.is_empty() else 1);return
 root.size=Vector2i(1560,720);app.layout_dpi_override=280;app.layout_safe_override=Rect2(40,0,1504,704)
 app.refresh_responsive_layout();await frames()
 await fill();check_layout("three units");check_shapes();check_badges();await shot("battle")
 expect(board.board_layout_mode=="inline","1560x720 uses inline layout")
 var portrait=board.cards["card_"+str(e.players[0].field[0].uid)]
 expect(portrait.size.x>=BASELINE_PORTRAIT_WIDTH*1.5,"inline portrait width grows at least 1.5 times measured 85px baseline")
 expect(not view.opponent_layer.visible,"normal opponent hand backs are hidden")
 expect(not view.hud.get_node("OpponentHandCount").visible,"opponent hand count moves to left summary")
 expect(board.get_index()==0,"AndroidBoard is the first UI child below badges")
 await check_emotes("inline")
 await check_pages();await check_actions_and_hold();await check_left();await check_permanents()
 await check_palette_layer();await check_palette_payment();await check_palette_possession();await check_palette_pages()
 await check_targets();await check_settings();await check_combat()
 root.size=Vector2i(1280,720);app.layout_dpi_override=240;app.layout_safe_override=Rect2(32,0,1232,704)
 app.refresh_responsive_layout();await frames();await fill();check_layout("resized");await shot("battle-resized")
 # A lower-DPI fixture keeps the existing left controls clear while forcing band mode.
 app.layout_dpi_override=200;app.layout_safe_override=Rect2(32,0,1232,540)
 app.refresh_responsive_layout();await frames();await fill();check_layout("band fallback");check_shapes();check_badges()
 expect(floorf((board.size.y-app.ui_metrics.gap*3)/2)<app.ui_metrics.hit*2+app.ui_metrics.gap,"540px safe height at dpi200 forces band threshold")
 expect(board.board_layout_mode=="band","short safe area retains original band layout")
 await check_emotes("band")
 await shot("band-fallback")
 app.layout_safe_override.size.y=528;app.refresh_responsive_layout();await frames();await fill()
 view.toggle_android_palette(0);await redraw();check_palette_geometry(0,"short area")
 var palette_height=board.palette_rect.size.y-app.ui_metrics.hit-app.ui_metrics.gap*3
 expect(floorf((palette_height-app.ui_metrics.gap)/2)<app.ui_metrics.hit*1.4,"short palette uses one row threshold")
 expect(palette_nodes(0).all(func(node):return node.size.y==palette_height),"short palette uses full card area height in one row")
 await check_left_device_matrix()
 await check_compact_possession()
 view.queue_free();app.duel_view=null;await frames();app.is_android=false;app.refresh_ui_metrics();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);await frames()
 expect(view.android_board==null and view.stage.visible,"desktop ignores enabled Android experiment")
 print("ANDROID EXPERIMENTAL BOARD: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
