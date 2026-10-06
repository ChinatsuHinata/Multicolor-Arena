extends "res://tests/support/ui_base.gd"

func frames(count: int=7):
 for i in range(count):await process_frame

func seed_stack(ability: bool=false):
 var source=e.make_card("164",1,"stack" if not ability else "field")
 if ability:e.players[1].field.append(source)
 var entry={"id":100,"kind":"ability" if ability else "card","owner":1,"target":{},"name":e.cards[source.card_id].name}
 if ability:entry.source=source;entry.activation=true;entry.effect="token-fdf-129"
 else:entry.card=source
 e.stack=[entry];e.next_stack=101

func clear_stack_popup(label: String):
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel),label+" popup exists")
 if not is_instance_valid(panel):return
 expect(panel.get_meta("avoid_stack",false),label+" whole choice reserves the stack")
 expect(view.stack_panel.is_visible_in_tree() and not panel.get_global_rect().intersects(view.stack_panel.get_global_rect()),label+" stack remains visible and unobstructed")
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),label+" popup fits safe area")
 expect(not view.responsive.side_choice_open(),label+" popup does not suppress stack or phase actions")
 expect(panel.get_global_rect().grow(1).encloses(find_button(panel,"隐藏").get_global_rect()),label+" hide control fits popup")
 if panel.has_node("BoardTargetPrompt"):
  var prompt=panel.get_node("BoardTargetPrompt") as Label
  expect(prompt.size.y+1>=prompt.get_line_height()*prompt.get_line_count(),label+" prompt contains every wrapped line")
 if view.is_android:
  for shortcut in view.android_zone_shortcuts.buttons.values():
   expect(not shortcut.is_visible_in_tree() or not shortcut.get_global_rect().intersects(panel.get_global_rect()),label+" floating zone shortcut leaves the popup clear")

func stack_click():
 var at=view.stack_panel.tiles[100].tile.get_global_rect().get_center()
 if not view.is_android:await click(at);return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await frames()

func check_choices(label: String):
 for id in ["100","123","131","spell-mar-007"]:
  clean(true);e.debug_free_payment=true
  seed_stack(id=="123")
  var card=put(id,"hand")
  if id=="100":put("70","field")
  if id=="spell-mar-007":
   var leader=e.cards[e.players[0].leader.card_id].character
   var reveals=e.cards.keys().filter(func(key):return e.cards[key].get("requires_character","")==leader and not leader.is_empty())
   expect(not reveals.is_empty(),label+" printed spirit strike has a reveal card")
   if reveals.is_empty():continue
   put(reveals[0],"hand")
  if id=="131":e.cards["164"]=e.cards["164"].duplicate(true);e.cards["164"].spell_type="非符"
  view.render();await frames();view.request_cast(card.uid);await frames()
  expect(not view.local.is_empty(),label+" can select printed card "+id)
  clear_stack_popup(label+" "+id)
  if id=="131":
   var counter=view.picker.available().filter(func(atom):return atom.kind=="mode" and "反制" in str(atom.value))
   expect(not counter.is_empty(),label+" multimode spell can select a counter")
   if not counter.is_empty():view.inline_pick(counter[0]);await frames();clear_stack_popup(label+" selected counter mode")
  elif id=="spell-mar-007":
   var reveal=view.picker.available().filter(func(atom):return atom.kind=="target" and atom.value.has("uid"))
   if not reveal.is_empty():view.inline_pick(reveal[0]);await frames()
   var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
   if not finish.is_empty():view.inline_pick(finish[0]);await frames()
   clear_stack_popup(label+" after reveal")
  if view.picker.available_refs().any(func(ref):return ref.get("stack_id",-1)==100):
   await stack_click();await frames()
   expect(view.picker.selected_refs().any(func(ref):return ref.get("stack_id",-1)==100),label+" click reaches actual stack target "+id)
   clear_stack_popup(label+" selected "+id)
   var selected=view.picker.path.duplicate(true)
   find_button(view.android_choice_panel,"隐藏").pressed.emit();await frames()
   expect(view.stack_panel.is_visible_in_tree(),label+" hidden choice keeps stack usable")
   view.android_choice_restore.pressed.emit();await frames()
   expect(view.picker.path==selected,label+" expanding retains the chosen stack card")
   clear_stack_popup(label+" expanded "+id)
 clean(true);e.debug_free_payment=true;seed_stack(true)
 var barrier=put("field-rei-003","field")
 view.render();await frames()
 view.execute_action({"type":"extension","uid":barrier.uid,"key":"watch_counter","enabled":true});await frames()
 clear_stack_popup(label+" activated counter ability")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/stack-popup/"+label+".png")
 await stack_click();await frames()
 expect(view.picker.ready() and view.local.target.get("stack_id",-1)==100,label+" activated ability can select stack target")
 # A later group requires the rail even when the first group picks a unit.
 clean(true);seed_stack();var unit=put("53","field")
 var spec=e.Pack.selection([e.Pack.group([e.ref_target(unit)],1,1,"先选单位"),e.Pack.group([{"stack_id":100}],1,1,"再选堆叠")],"stack-test")
 e.pending={"kind":"effect_choice","owner":0,"options":spec,"trigger":{"effect":"test","optional":false,"source":unit}}
 view.render();await frames();clear_stack_popup(label+" later stack group")
 if view.is_android:
  clean(true)
  var stones=e.Cat.printed_tokens(e,0,5,"token-fdf-129")
  view.render();await frames()
  view.execute_action({"type":"extension","uid":stones[0].uid,"key":"token-fdf-129","enabled":true});await frames()
  var spinner=view.modal_root.find_child("BatchCount",true,false) as SpinBox
  expect(spinner!=null and spinner.max_value==5,label+" keystone amount input uses generated stack count")
  if spinner!=null:
   expect(app.ui_metrics.safe.grow(1).encloses(spinner.get_global_rect()),label+" keystone input fits safe area")
   spinner.value=3
   find_button(view.modal_root,"确认").pressed.emit();await frames()
   expect(view.local.get("stackable_count",0)==3 and not view.modal,label+" one amount entry advances to target selection")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/stack-popup/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for fixture in [{"size":Vector2i(1600,900),"dpi":0},{"size":Vector2i(1280,720),"dpi":240},{"size":Vector2i(1280,720),"dpi":320}]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  app.is_android=fixture.dpi>0;app.layout_dpi_override=fixture.dpi;root.size=fixture.size
  app.layout_safe_override=Rect2(40,12,fixture.size.x-80,fixture.size.y-36) if app.is_android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);await frames()
  view=app.duel_view;view.set_process(false);e=view.engine
  await check_choices("dpi%d" % fixture.dpi)
 app.queue_free();await frames()
 print("STACK INTERACTION POPUP: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
