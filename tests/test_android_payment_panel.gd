extends "res://tests/support/ui_base.gd"
var output="res://work/android-payment-panel"
var board

func frames(count: int=5):
 for i in range(count):await process_frame

func redraw():
 view.render();await settle();view.banner.hide();await frames()

func tap(node: Control):
 expect(is_instance_valid(node) and node.is_visible_in_tree(),"payment control is visible")
 if not is_instance_valid(node):return
 var event=InputEventScreenTouch.new();event.index=0;event.position=node.get_global_rect().get_center();event.pressed=true
 root.push_input(event,true);await frames(2)
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func toggle() -> Button:
 return view.hud.find_child("PaymentPanelToggle",true,false) as Button

func check_toggle(caption: String):
 var button=toggle()
 expect(button!=null,"payment toggle exists")
 if button==null:return
 expect(button.text==caption and button.is_visible_in_tree(),"payment toggle caption "+caption)
 expect(app.ui_metrics.safe.encloses(button.get_global_rect()),"payment toggle fits safe area")
 expect(button.size.y>=app.ui_metrics.hit,"payment toggle keeps touch height")
 var text_width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
 expect(text_width<=button.size.x-button.get_theme_stylebox("normal").get_minimum_size().x,"payment toggle caption fits without clipping")
 if is_instance_valid(view.android_choice_panel):
  var title=view.android_choice_panel.get_node("ChoiceTitle")
  expect(title.text.replace("\n","")==title.tooltip_text and title.get_visible_line_count()==title.get_line_count(),"target title fits without clipping")
  expect(not button.get_global_rect().intersects(title.get_global_rect()),"payment toggle leaves target title clear")
  expect(view.android_choice_panel.get_global_rect().encloses(button.get_global_rect()),"payment toggle stays inside target panel")
 elif is_instance_valid(view.android_choice_restore):
  expect(not button.get_global_rect().intersects(view.android_choice_restore.get_global_rect()),"payment toggle leaves target restore clear")

func shot(label: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))

func check_payment_geometry():
 var popup=board.payment;var rect=popup.get_global_rect();var hit=app.ui_metrics.hit
 expect(app.ui_metrics.safe.encloses(rect) and board.get_global_rect().encloses(rect),"dedicated payment popup fits the safe board area")
 var buttons=[]
 for child in popup.get_children():
  if child is Button:
   expect(rect.encloses(child.get_global_rect()) and child.size.y>=hit,"payment control fits popup and touch height: "+str(child.name))
   for other in buttons:expect(not child.get_global_rect().intersects(other.get_global_rect()),"payment controls do not overlap: "+str(child.name)+" / "+str(other.name))
   buttons.append(child)
 if view.observe_button.visible:expect(not rect.intersects(view.observe_button.get_global_rect()),"payment popup stays clear of observation controls")

func fixture():
 clean();e.debug_free_payment=false
 view.android_palette_view=false;view.android_camera_restore={};view.android_auto_focus_owner=-1;view.android_manual_focus_override=-1
 board.opened={};board.anchors={}
 for who in range(2):
  var unit=put("53","field",who);unit.entered_turns=0;unit.plus_counters=3;unit.tapped=true
 for i in range(10):put("166","palette");put("168","palette")
 var source=put("130","hand")
 await redraw()
 return source

func check_target_payment(label: String):
 var source=await fixture()
 var enemy=e.players[1].field[0]
 view.request_cast(source.uid);await redraw()
 expect(view.local.get("mode","")=="target" and board.payment.visible and view.payment_ready(),"target declaration opens suggested payment")
 check_payment_geometry()
 check_toggle("隐藏支付")
 var before=snapshot();var plan=view.local.plan.duplicate(true)
 await tap(toggle())
 expect(not board.payment.visible and view.local.get("uid",0)==source.uid and view.local.plan==plan,"hide preserves active card and suggested payment")
 expect(is_instance_valid(view.android_choice_panel),"hide payment keeps target controls open")
 check_toggle("继续支付")
 await redraw()
 expect(not board.payment.visible,"redraw keeps payment hidden")
 var target_node=board.cards["card_"+str(enemy.uid)]
 await tap(target_node)
 expect(view.picker.ready() and view.local.target.get("uid",0)==enemy.uid,"target can be selected with payment hidden")
 expect(not board.payment.visible and view.local.plan==plan,"selecting target keeps hidden payment and reservation")
 await shot(label+"-target")
 await tap(toggle())
 expect(board.payment.visible and view.local.target.get("uid",0)==enemy.uid and view.local.plan==plan,"quick restore preserves selected target and payment")
 expect(board.tiles["summary-0"].props.pay,"target selection summary shows payment totals")
 var totals=board.summary(0);var remaining=board.summary(0,plan)
 expect(board.payment.get_node("Title").text.begins_with("支付 · "),"target payment title shows before and after totals")
 var visible_reserved=plan.filter(func(p):return board.payment.resources.has(p.uid))
 expect(not visible_reserved.is_empty(),"a selected payment source is visible")
 if visible_reserved.is_empty():return
 var removed=e.find_card(visible_reserved[0].uid)
 await tap(board.payment.resources[removed.uid])
 expect(not view.payment_ready() and not view.local.plan.any(func(p):return p.uid==removed.uid),"manual payment removal leaves payment incomplete")
 plan=view.local.plan.duplicate(true);var path=view.picker.path.duplicate(true)
 await tap(toggle());await tap(toggle())
 expect(board.payment.visible and view.local.plan==plan and view.picker.path==path,"hide and restore preserve incomplete payment and target path")
 expect(view.android_choice_panel.get_node("ChoiceConfirm").disabled,"incomplete restored payment cannot be confirmed")
 var replacement=e.players[0].palette.filter(func(c):return c.card_id==removed.card_id and c.uid!=removed.uid and board.payment.resources.has(c.uid))[0]
 await tap(board.payment.resources[replacement.uid])
 expect(view.payment_ready() and view.local.plan.any(func(p):return p.uid==replacement.uid),"replacement resource completes restored payment")
 plan=view.local.plan.duplicate(true)
 var next=board.payment.get_node_or_null("PageNext")
 if is_instance_valid(next) and next.visible and not next.disabled:
  await tap(next);await settle()
  var anchor=board.payment.page
  await tap(toggle());await tap(toggle())
  expect(board.payment.page==anchor,"payment restore preserves the palette page")
 await tap(board.payment.get_node("Hide"))
 expect(not board.payment.visible and view.local.plan==plan,"palette hide button preserves manual payment")
 await tap(toggle())
 expect(board.payment.visible,"target toggle restores payment hidden from palette header")
 await tap(view.android_choice_panel.get_node("AndroidChoiceHide"))
 expect(not is_instance_valid(view.android_choice_panel) and is_instance_valid(view.android_choice_restore),"target panel can be hidden independently")
 check_toggle("隐藏支付")
 await tap(toggle());check_toggle("继续支付");await tap(toggle())
 expect(board.payment.visible and view.local.plan==plan and view.picker.path==path,"phase toggle works while target controls are hidden")
 await tap(view.android_choice_restore)
 check_toggle("隐藏支付")
 expect(snapshot()==before,"payment panel operations do not mutate duel state")
 await shot(label+"-payment")
 await tap(toggle())
 var chosen=view.local.plan.map(func(p):return p.uid)
 var confirm=view.android_choice_panel.get_node("ChoiceConfirm")
 expect(not confirm.disabled,"hidden complete payment can be confirmed")
 await tap(confirm)
 expect(source.zone=="stack" and view.local.is_empty(),"confirmation casts the selected spell")
 expect(e.stack.back().target.get("uid",0)==enemy.uid,"confirmation retains selected enemy target")
 expect(e.players[0].palette.filter(func(c):return c.tapped).map(func(c):return c.uid).all(func(uid):return uid in chosen) and e.players[0].palette.filter(func(c):return c.tapped).size()==chosen.size(),"confirmation pays exactly the manually selected sources")
 expect(not removed.tapped and replacement.tapped,"replacement is spent while removed source stays available")
 await redraw()
 expect(toggle()==null,"payment toggle disappears after completion")

func check_payment_phase():
 await fixture()
 var source=put("164","hand")
 for i in range(4):put("164","palette")
 await redraw();view.request_cast(source.uid);view.start_payment();await redraw()
 expect(view.local.get("mode","")=="payment" and board.payment.visible,"payment confirmation opens palette")
 var plan=view.local.plan.duplicate(true);var before=snapshot()
 check_toggle("隐藏支付");await tap(toggle());check_toggle("继续支付");await tap(toggle())
 expect(board.payment.visible and view.local.plan==plan and snapshot()==before,"payment phase toggle preserves draft and duel")
 view.cancel_cast();await redraw()
 expect(toggle()==null and not board.payment.visible,"cancel removes payment shortcut and restores battlefield")

func check_inaba_payment(who: int):
 clean();e.debug_free_payment=false;view.debug_mode=who==1;view.local_seat=who;e.active=who;e.priority=who
 view.android_palette_view=false;view.android_camera_restore={};view.android_auto_focus_owner=-1;view.android_manual_focus_override=-1
 board.opened={};board.payment.category="all";board.payment.page=0
 var rabbit=put("character-fdf-098","field",who);rabbit.entered_turns=0
 var sick=put("character-fdf-098","field",who);sick.entered_turns=e.players[who].turns
 var yellow=put("164","palette",who);var green=put("166","palette",who)
 var items={}
 for id in e.cards:
  if e.DB.has_ability(e.cards[id],"mana"):
   var color=e.DB.ability(e.cards[id],"mana")["颜色"]
   if color in ["黄","绿"] and not items.has(color):items[color]=put(id,"field",who)
 expect(items.size()==2,"fixture contains yellow and green mana items")
 if items.size()!=2:return
 var tapped=put(items["黄"].card_id,"field",who);tapped.tapped=true
 var spell=put("item-fdn-044","hand",who)
 await redraw();view.request_cast(spell.uid);view.start_payment();await redraw()
 var before=snapshot()
 expect(board.payment.visible and not board.palette.visible,"payment opens a dedicated popup for seat "+str(who))
 expect(board.payment.get_node("Category-unit").text.begins_with("单位"),"Inaba is grouped under the unit payment type")
 check_payment_geometry()
 expect(not board.payment.eligible.has(sick.uid) and not board.payment.eligible.has(tapped.uid),"sick Inaba and tapped items cannot pay")
 await tap(board.payment.get_node("Category-unit"))
 await tap(board.payment.resources[rabbit.uid])
 expect(view.local.plan==[{"uid":rabbit.uid,"color":"黄/绿"}] and view.payment_ready(),"Inaba occupies exactly yellow and green together in one reservation")
 expect(board.payment.get_node("Title").text.ends_with("已付 2"),"Inaba fills two payment slots")
 await tap(board.payment.resources[rabbit.uid])
 expect(view.local.plan.is_empty() and not view.payment_ready(),"deselecting Inaba releases both payment slots")
 await tap(board.payment.resources[rabbit.uid])
 await tap(board.payment.get_node("Category-palette"))
 await tap(board.payment.resources[yellow.uid])
 expect(view.local.plan==[{"uid":yellow.uid,"color":"黄"}] and not view.payment_ready(),"replacing Inaba releases both slots and reserves only the newly chosen yellow")
 expect(board.payment.get_node("Title").text.ends_with("已付 1"),"replacing Inaba leaves the second slot empty")
 await tap(board.payment.resources[green.uid])
 expect(view.payment_ready() and view.local.plan.size()==2,"two palette cards can replace Inaba's full paired payment")
 await tap(board.payment.get_node("Category-unit"));await tap(board.payment.resources[rabbit.uid])
 expect(view.local.plan==[{"uid":rabbit.uid,"color":"黄/绿"}],"switching back to Inaba replaces both individual reservations")
 await tap(board.payment.get_node("Category-item"));await tap(board.payment.resources[items["绿"].uid])
 expect(view.local.plan==[{"uid":items["绿"].uid,"color":"绿"}] and not view.payment_ready(),"switching Inaba to an item also releases both slots")
 await tap(board.payment.resources[items["黄"].uid])
 expect(view.payment_ready() and view.local.plan.size()==2,"two items complete the replacement payment")
 var plan=view.local.plan.duplicate(true)
 view.android_back();await frames()
 expect(not board.payment.visible and view.local.plan==plan,"Android back hides payment without discarding it")
 await tap(toggle())
 expect(board.payment.visible and view.local.plan==plan and snapshot()==before,"restoring payment preserves the private draft without tapping sources")
 var hold=InputEventScreenTouch.new();hold.index=0;hold.position=board.payment.resources[items["绿"].uid].get_global_rect().get_center();hold.pressed=true
 root.push_input(hold,true);await create_timer(0.7).timeout
 hold=hold.duplicate();hold.pressed=false;root.push_input(hold,true);await frames()
 expect(view.inspection.visible and view.local.plan==plan,"payment resource long press opens details without changing the draft")
 view.android_back();await frames()
 expect(not view.inspection.visible and board.payment.visible and view.local.plan==plan,"closing resource details restores the payment popup")
 await shot("inaba-payment-seat-"+str(who))
 await tap(find_button(view.hud,"发动"));await redraw()
 expect(spell.zone=="stack" and items["绿"].tapped and items["黄"].tapped,"confirmation spends exactly the two chosen items")
 expect(not rabbit.tapped and not yellow.tapped and not green.tapped,"replaced Inaba and palette cards stay untapped")
 # A single-color cost must never accept half of Inaba's paired output.
 e.priority=who
 view.local={"uid":rabbit.uid,"action":"choice_payment","choice_cost":{"黄":1},"mode":"payment","target":{},"plan":[]}
 await redraw();await tap(board.payment.get_node("Category-unit"))
 expect(board.payment.resources[rabbit.uid].disabled,"Inaba is disabled for a single yellow payment")
 board.payment.choose(rabbit.uid)
 expect(view.local.plan.all(func(entry):return entry.uid!=rabbit.uid),"Inaba cannot be reserved for only one fee")
 view.cancel_cast();await redraw();view.local_seat=0

func check_required_inaba(who: int):
 clean();e.debug_free_payment=false;view.debug_mode=who==1;view.local_seat=who;e.active=who;e.priority=who
 view.android_palette_view=false;view.android_camera_restore={};view.android_auto_focus_owner=-1;view.android_manual_focus_override=-1
 var rabbit=put("character-fdf-098","field",who);rabbit.entered_turns=0
 var yellow=put("164","palette",who);var spell=put("item-fdn-044","hand",who)
 await redraw();view.request_cast(spell.uid);view.start_payment();await redraw()
 var plan=view.local.plan.duplicate(true);var before=snapshot()
 await tap(board.payment.get_node("Category-unit"));await tap(board.payment.resources[rabbit.uid])
 expect(view.local.plan==plan and view.payment_ready(),"required Inaba cannot be deselected without a complete alternative")
 expect(view.message.contains("没有不使用该单位"),"blocked release explains the missing alternative")
 await tap(board.payment.get_node("Category-palette"))
 expect(board.payment.resources[yellow.uid].disabled,"a partial alternative cannot replace required Inaba")
 board.payment.choose(yellow.uid)
 expect(view.local.plan==plan,"replacement cannot release required Inaba through a partial payment")
 await tap(toggle());await tap(board.cards["card_"+str(rabbit.uid)])
 expect(view.local.plan==plan,"battlefield input also preserves required Inaba")
 await tap(toggle())
 expect(snapshot()==before and not rabbit.tapped,"blocked release neither spends nor mutates resources")
 put("166","palette",who);await redraw()
 await tap(board.payment.get_node("Category-unit"));await tap(board.payment.resources[rabbit.uid])
 expect(view.local.plan.is_empty() and not view.payment_ready(),"a newly available complete alternative allows releasing both Inaba slots")
 view.cancel_cast();await redraw();view.local_seat=0

func check_item_orientation():
 clean();e.debug_free_payment=false
 var upright=put("item-fdf-096","field");put("item-fdf-096","field")
 var tapped=put("item-fdf-096","field");tapped.tapped=true
 await redraw()
 var tile=board.tiles["band-0-item"]
 expect(tile.props.previews.size()==2 and not tile.props.previews[0].tapped and tile.props.previews[1].tapped,"item preview includes both orientations even when first two items are upright")
 await shot("item-orientation-preview")
 await tap(tile);await settle()
 var a=board.cards["card_"+str(upright.uid)];var b=board.cards["card_"+str(tapped.uid)]
 expect(a.size.y>a.size.x and not a.landscape and is_zero_approx(a.art.rotation),"upright item stays portrait in expanded region")
 expect(b.size.x>b.size.y and b.landscape and is_equal_approx(b.art.rotation,-PI/2),"tapped item is landscape in expanded region")
 expect(board.sheet_rect.encloses(a.get_global_rect()) and board.sheet_rect.encloses(b.get_global_rect()) and not a.get_global_rect().intersects(b.get_global_rect()),"mixed item orientations fit without overlap")
 await shot("item-orientation-expanded");board.close_region()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.size=Vector2i(1560,720)
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root_override.path_join("settings.json")
 app.is_android=true;app.layout_dpi_override=280;app.layout_safe_override=Rect2(40,0,1504,704)
 root.add_child(app);await frames();app.load_legacy_test_decks();app.android_experimental_battle_ui=true;app.auto_camera_focus=false
 app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;board=view.android_board;await frames()
 for device in [[1560,720,Rect2(40,0,1504,704)],[1280,600,Rect2(0,0,1280,600)]]:
  root.size=Vector2i(device[0],device[1]);app.layout_safe_override=device[2];app.refresh_responsive_layout();await frames()
  await check_target_payment("%dx%d" % [device[0],device[1]])
  await check_payment_phase()
  for who in [0,1]:
   await check_inaba_payment(who)
   await check_required_inaba(who)
  await check_item_orientation()
 print("ANDROID_PAYMENT_PANEL: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
