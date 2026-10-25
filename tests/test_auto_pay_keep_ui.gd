extends "res://tests/support/ui_base.gd"

const Draft=preload("res://scripts/payment_draft.gd")
const HexCost=preload("res://scripts/cost_hex_display.gd")

func frames(count: int=3):
 for i in range(count):await process_frame

func activate(at: Vector2):
 if not view.is_android:
  await click(at)
  return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await frames();await physics_frame

func activate_keep():
 var button=view.hud.get_node_or_null("AutoPayKeepButton")
 expect(button!=null,"keep button exists")
 if button:await activate(button.get_global_rect().get_center())

func activate_color(color: String):
 var cell=view.keep_popup.get_node_or_null("AutoPayKeep"+color) if is_instance_valid(view.keep_popup) else null
 expect(cell!=null,"keep swatch exists: "+color)
 if cell:await activate(cell.get_global_rect().get_center())

func check_engine():
 clean();e.debug_free_payment=false
 # The existing skip-first search breaks ties toward the later palette source.
 var blue=put("167","palette");var red=put("165","palette")
 var cost={"红/蓝":1}
 var original=e.payment(0,cost)
 expect(original.plan==[{"uid":red.uid,"color":"红"}],"empty preference preserves the existing equal-weight red plan")
 var kept=e.payment(0,cost,[],["红"])
 expect(kept.plan==[{"uid":blue.uid,"color":"蓝"}],"keeping red pays blue")
 expect(kept.ways==original.ways and e.payment_valid(0,cost,kept.plan),"preference preserves feasibility and plan validity")
 for sample in [cost,{"红":1},{"红/蓝":2},{"红":2},{}]:
  expect(e.payment(0,sample)==e.payment(0,sample,[],[]),"default and explicit empty preference match: "+str(sample))
 expect(Draft.solve_costs(e,0,[cost],[],[],["红"]).plan==kept.plan,"payment draft forwards the keep preference")
 expect(Draft.solve(e,0,cost,[],[],["红"]).plan==kept.plan,"single-cost draft forwards the keep preference")
 expect(Draft.options(e,0,cost,[],[],["红"])==Draft.options_for_costs(e,0,[cost],[],[],["红"]),"single-cost options forwards the keep preference")
 var yellow=put("164","palette")
 var fixed=[{"uid":yellow.uid,"color":"黄"}]
 var fixed_plan=Draft.solve_costs(e,0,[{"红/蓝":1,"黄":1}],fixed,[],["红"]).plan
 expect(fixed_plan==fixed+kept.plan,"fixed reservation recursion forwards the preference and preserves the reservation")
 expect(e.keep_penalty({"colors":["红","黄/绿","蓝"]},["红","绿"])==24,"penalty counts all preserved source colors including pairs")
 expect(e.keep_penalty({"colors":["红","黄/绿"]},[])==0,"empty keep preference has exactly zero penalty")
 clean();put("165","palette");put("165","palette")
 var forced=e.payment(0,{"红":2},[],["红"])
 expect(forced.ways>0 and e.payment_valid(0,{"红":2},forced.plan),"required red resources remain spendable while keeping red")
 clean();put("165","palette");put("167","palette")
 expect(e.payment(0,cost).plan[0].color=="蓝","original red-then-blue palette tie order is unchanged")

func check_layout(prefix: String):
 var button=find_button(view.ui,"保留色：无" if view.is_android else "自动支付保留：无")
 expect(button!=null,prefix+" caption is present")
 if button==null:return
 var rect=button.get_global_rect();var popup=view.keep_popup_rect()
 if not view.is_android:
  expect(rect==Rect2(16,100,218,44),prefix+" desktop keep button uses the specified rectangle")
  expect(view.inspection.get_global_rect()==Rect2(16,156,218,604),prefix+" inspection leaves the button row clear")
  expect(not rect.intersects(view.inspection.get_global_rect()),prefix+" button clears inspection")
  expect(not popup.intersects(view.inspection.get_global_rect()),prefix+" popup opens to the right of inspection")
 else:
  expect(app.ui_metrics.safe.encloses(rect),prefix+" keep button stays inside safe area")
  expect(app.ui_metrics.safe.encloses(popup),prefix+" popup stays inside safe area")
  for name in ["AndroidCameraFocusToggle","AndroidHandZoneSelector","HandDisplayToggle"]:
   var control=view.hud.find_child(name,true,false)
   if control==null:control=view.ui.find_child(name,true,false)
   expect(control!=null,prefix+" neighboring control exists: "+name)
   if control:
    expect(not rect.intersects(control.get_global_rect()),prefix+" button clears "+name)
    expect(not popup.intersects(control.get_global_rect()),prefix+" popup clears "+name)

func check_interactions(prefix: String):
 clean();view.keep_popup_open=false;view.inspect_id="";app.set_auto_pay_keep_colors([])
 # Palette access makes the existing hand-zone selector appear for overlap checks.
 for i in range(2):put("167","palette");put("165","palette")
 e.players[0].palette_access=e.turn
 view.render()
 await frames();check_layout(prefix)
 await activate_keep()
 expect(view.keep_popup_open and is_instance_valid(view.keep_popup),prefix+" button opens popup")
 if not is_instance_valid(view.keep_popup):return
 expect(view.keep_popup.name=="AutoPayKeepPopup",prefix+" popup is named for UI discovery")
 expect(view.hud.get_children().filter(func(child):return child.name=="AutoPayKeepDismiss").size()==1,prefix+" exactly one dismiss layer stays behind the button")
 var sw=view.keep_swatch_size()
 for color in e.COLORS:
  var cell=view.keep_popup.get_node_or_null("AutoPayKeep"+color)
  expect(cell!=null,prefix+" popup offers "+color)
  if cell:
   var paper=cell.get_theme_stylebox("normal")
   expect(paper.bg_color==HexCost.INK[color] and paper.border_width_left==1,prefix+" swatch uses card cost ink and unselected border: "+color)
   expect(cell.size==Vector2(sw,sw),prefix+" swatch uses the responsive square size: "+color)
 await activate_keep()
 expect(not view.keep_popup_open and view.keep_popup==null,prefix+" clicking the button again closes popup")
 await activate_keep()
 var outside=app.ui_metrics.safe.end-Vector2(4,4)
 await activate(outside)
 expect(not view.keep_popup_open and view.keep_popup==null,prefix+" clicking outside closes popup")
 await activate_keep();await activate_color("红")
 expect(app.auto_pay_keep_colors==["红"] and view.keep_popup_open,prefix+" selecting red persists and keeps popup open")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(app.settings_path))
 expect(saved.auto_pay_keep_colors==["红"],prefix+" settings JSON contains selected colors")
 if is_instance_valid(view.keep_popup):
  var paper=view.keep_popup.get_node("AutoPayKeep红").get_theme_stylebox("normal")
  expect(paper.border_color==app.GOLD and paper.border_width_left==3,prefix+" selected swatch has a three-pixel gold border")
 await activate_color("红")
 expect(app.auto_pay_keep_colors.is_empty() and view.keep_popup_open,prefix+" clicking the swatch again removes red")
 for color in ["黑","黄","绿","蓝","红"]:
  await activate_color(color)
  expect(color in app.auto_pay_keep_colors,prefix+" swatch tap selects "+color+": "+str(app.auto_pay_keep_colors))
 expect(app.auto_pay_keep_colors==e.COLORS,prefix+" selections use canonical color order: "+str(app.auto_pay_keep_colors))
 var full_button=view.hud.get_node("AutoPayKeepButton")
 expect(full_button.get_global_rect()==view.keep_button_rect(),prefix+" all five selected colors do not enlarge the button")
 expect(full_button.get_theme_font_size("font_size")>=(14 if view.is_android else 12),prefix+" caption respects minimum font size")
 await activate_keep()
 app.set_auto_pay_keep_colors([]);clean()
 var blue=put("167","palette");var red=put("165","palette")
 # Keep the fixture definition private to this test; card data files stay intact.
 e.cards=e.cards.duplicate(true)
 e.cards["164"].cost={"红/蓝":1}
 var spell=put("164","hand")
 view.render();await frames();view.request_cast(spell.uid);await frames()
 expect(not view.local.is_empty() and view.local.get("plan",[])==[{"uid":red.uid,"color":"红"}],prefix+" cast starts with the original red draft")
 var before=snapshot();var signature=view.local.get("payment_signature","")
 await activate_keep();await activate_color("红")
 expect(view.local.get("plan",[])==[{"uid":blue.uid,"color":"蓝"}],prefix+" choosing red immediately recomputes the draft to blue")
 expect(view.local.get("payment_signature","")!=signature and view.payment_ready(),prefix+" keep preference invalidates the draft signature and leaves valid payment")
 expect(snapshot()==before and view.keep_popup_open,prefix+" editing preference does not spend resources or close popup")
 view.android_inspection_allowed=true
 view.inspect_card(red.card_id,red.uid);await frames()
 expect(not view.keep_popup_open,prefix+" inspecting a card closes keep popup state")
 expect(not is_instance_valid(view.keep_popup) or not view.keep_popup.visible,prefix+" inspecting a card immediately hides keep popup")
 expect(not is_instance_valid(view.keep_dismiss) or not view.keep_dismiss.visible,prefix+" inspection removes the keep dismiss hit layer")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/auto-pay-keep-ui/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 app.account_session_path=Store.Paths.root_override.path_join("session.json")
 DirAccess.make_dir_recursive_absolute(app.tutorial_local_directory)
 var settings=FileAccess.open(app.settings_path,FileAccess.WRITE)
 settings.store_string(JSON.stringify({"auto_pay_keep_colors":["红","bad","蓝","红",1]}));settings.close()
 root.add_child(app);await frames()
 expect(app.auto_pay_keep_colors==["红","蓝"],"loading settings filters invalid and duplicate keep colors")
 app.load_legacy_test_decks()
 var fixtures=[{"android":false,"size":Vector2i(1600,900),"dpi":0.0,"safe":Rect2(),"name":"Desktop"},{"android":true,"size":Vector2i(1280,720),"dpi":240.0,"safe":Rect2(),"name":"Android 720p dpi240"},{"android":true,"size":Vector2i(1280,720),"dpi":320.0,"safe":Rect2(36,0,1220,696),"name":"Android inset dpi320"},{"android":true,"size":Vector2i(1920,1080),"dpi":320.0,"safe":Rect2(),"name":"Android 1080p dpi320"}]
 for fixture in fixtures:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture.size;app.is_android=fixture.android;app.layout_dpi_override=fixture.dpi;app.layout_safe_override=fixture.safe
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  if not fixture.android:check_engine()
  await check_interactions(fixture.name)
 print("AUTO_PAY_KEEP_UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
