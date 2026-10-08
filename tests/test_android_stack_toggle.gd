extends "res://tests/support/ui_base.gd"

func frames(count: int=4):
 for i in range(count):await process_frame

func add_stack():
 for i in range(6):
  var card=e.make_card("53",0,"stack")
  e.stack.append({"id":500+i,"kind":"card","card":card,"owner":0,"target":{"none":true},"name":e.cards["53"].name})

func touch_toggle(point: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame;await physics_frame

func run_case(screen_size: Vector2i,dpi: float):
 if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
 root.size=screen_size;app.is_android=true;app.layout_dpi_override=dpi
 app.layout_safe_override=Rect2(60,0,screen_size.x-84,screen_size.y-24)
 await frames();app.refresh_responsive_layout();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;await frames()
 clean();add_stack();view.render();await frames()
 var stack=view.stack_panel
 var before=snapshot()
 expect(stack.visible and stack.toggle_button.is_visible_in_tree(),"%s stack and toggle are visible" % screen_size)
 expect(stack.toggle_button.size.x>=90 and stack.toggle_button.size.y>=90,"%s stack toggle provides a large square touch area" % screen_size)
 expect(app.ui_metrics.safe.encloses(stack.toggle_button.get_global_rect()),"%s expanded toggle stays in the screen safe area" % screen_size)
 expect(not stack.toggle_button.get_global_rect().intersects(view.OPPONENT_HAND_COUNT),"%s enlarged toggle leaves the opponent hand button clear" % screen_size)
 expect(stack.tiles[505].tile.custom_minimum_size.y>=280,"%s Android stack card uses a large portrait image" % screen_size)
 expect(not stack.toggle_button.get_global_rect().intersects(view.responsive.action_scroll.get_global_rect()),"%s stack toggle leaves phase actions clear" % screen_size)
 await touch_toggle(stack.toggle_button.get_global_rect().position+Vector2(8,8));await frames()
 expect(stack.collapsed and stack.visible and stack.toggle_button.is_visible_in_tree(),"%s collapse leaves an expand control" % screen_size)
 expect(app.ui_metrics.safe.encloses(stack.toggle_button.get_global_rect()),"%s collapsed toggle stays in the screen safe area" % screen_size)
 expect(not stack.toggle_button.get_global_rect().intersects(view.responsive.action_scroll.get_global_rect()),"%s collapsed toggle leaves phase actions clear" % screen_size)
 expect(not stack.scroll.visible and not stack.entry_rect(505).has_area(),"%s collapsed stack hides cards from input" % screen_size)
 expect(snapshot()==before,"%s collapse does not change duel state" % screen_size)
 await touch_toggle(stack.toggle_button.get_global_rect().end-Vector2(8,8));await frames()
 expect(not stack.collapsed and stack.scroll.visible and stack.entry_rect(505).has_area(),"%s expand restores the stack card" % screen_size)
 stack.set_collapsed(true);view.table.targetable_stacks=[505];stack.sync();await frames()
 expect(not stack.collapsed,"%s stack target selection reopens the stack" % screen_size)
 view.table.targetable_stacks=[]
 clean();add_stack()
 e.cards["53"]=e.cards["53"].duplicate(true)
 e.cards["53"].abilities.append({"实现":"activated_damage","名称":"启动能力","参数":{"数值":1,"费用":{},"横置":false}})
 var unit=put("53","field")
 view.render();await frames();view.open_actions(unit);await frames()
 var hide=find_button(view.android_choice_panel,"隐藏")
 if hide!=null:await click(hide.get_global_rect().get_center());await frames()
 print("STACK GEOMETRY %s dpi=%d panel=%s scroll=%s actions=%s" % [screen_size,int(dpi),stack.get_global_rect(),stack.scroll.get_global_rect(),view.responsive.action_scroll.get_global_rect()])

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-stack-toggle/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 await run_case(Vector2i(1600,900),240)
 await run_case(Vector2i(2160,1080),480)
 await run_case(Vector2i(1280,720),320)
 print("ANDROID STACK TOGGLE: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
