extends "res://tests/support/ui_base.gd"
## Optional spell offers and short action lists must expose every choice at once.
var output="res://work/android-ability-options"

class RailSession extends RefCounted:
 var room={"undo_request":{}}
 var read_only=false
 var connected=true
 var paused=false
 func ended():return false

func frames(count: int=8):
 for i in range(count):await process_frame

func tap(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func check_actions(label: String,count: int):
 var scroll=view.responsive.action_scroll
 var column=view.responsive.action_column
 expect(column.get_child_count()==count,label+" offers all expected actions")
 expect(scroll.visible and not scroll.get_v_scroll_bar().visible,label+" needs no scrolling")
 var bounds=scroll.get_global_rect()
 expect(app.ui_metrics.safe.grow(1).encloses(bounds),label+" actions stay in the safe area")
 expect(not bounds.intersects(view.android_back_button.get_global_rect()),label+" actions leave back clear")
 for button in column.get_children():
  expect(bounds.grow(1).encloses(button.get_global_rect()),label+" fully shows "+button.text)
  expect(button.size.y>=app.ui_metrics.hit,label+" preserves touch height for "+button.text)
 if view.stack_panel.visible:
  expect(not bounds.intersects(view.stack_panel.get_global_rect()),label+" actions leave the stack clear")
  expect(view.stack_panel.scroll.size.y>=view.stack_panel.ANDROID_CARD_SIZE.y,label+" stack shows a complete card")
  if view.stack_panel.position.x<view.SIDEBAR.position.x:
   expect(view.stack_panel.get_global_rect().end.y<=view.HAND.position.y-app.ui_metrics.gap+1,label+" relocated stack leaves the hand clear")
 if view.responsive.notice_scroll.visible:
  var notice=view.responsive.notice_scroll.get_global_rect()
  expect(app.ui_metrics.safe.grow(1).encloses(notice) and not notice.intersects(bounds),label+" prompt stays clear of the actions")
  if view.stack_panel.visible:expect(not notice.intersects(view.stack_panel.get_global_rect()),label+" prompt leaves the stack clear")

func add_stack():
 var card=e.make_card("53",1,"stack")
 e.stack.append({"id":e.next_stack,"kind":"card","card":card,"owner":1,"target":{"none":true},"name":e.cards[card.card_id].name})
 e.next_stack+=1

func prepare_spell(id: String,stacked: bool=false):
 clean(true)
 put("character-mar-021","field")
 for resource_id in ["165","167","166","164","168"]:
  for i in range(3):put(resource_id,"palette")
 put("spell-fdf-075","hand")
 put("53","deck")
 var spell=put(id,"deck")
 e.players[0].deck.erase(spell);e.players[0].deck.push_front(spell)
 if stacked:add_stack()
 e.Cat.reveal(e,[spell]);e.pump_choices()
 view.render();await settle();view.render();await frames()
 return spell

func check_patchouli(prefix: String):
 for id in ["spell-fdf-077","spell-fdf-079"]:
  var spell=await prepare_spell(id,true)
  expect(e.pending.get("trigger",{}).get("effect","")=="cat:element_reveal",prefix+" reveal offers the optional exile trigger")
  check_actions(prefix+" "+id+" reveal",2)
  var confirm=find_button(view.responsive.action_column,"确定")
  if confirm!=null:await tap(confirm.get_global_rect().get_center());await frames()
  resolve();view.render();await settle();view.render();await frames()
  expect(spell.zone=="exile" and e.pending.get("trigger",{}).get("effect","")=="cat:grant",prefix+" spell is exiled and offers casting")
  check_actions(prefix+" "+id+" cast",3 if id=="spell-fdf-079" else 2)
  await shot(prefix+"-"+id)
  var decline=find_button(view.responsive.action_column,"不使用")
  if decline!=null:await tap(decline.get_global_rect().get_center());await frames()
  expect(e.pending.is_empty() and spell.zone=="exile",prefix+" second/last choice declines casting")

func check_short_lists(prefix: String):
 for count in [2,3]:
  clean(true);add_stack();view.render();await frames()
  for child in view.responsive.action_column.get_children():
   view.responsive.action_column.remove_child(child);child.queue_free()
  var selected=[]
  for index in range(count):
   var button=view.responsive.button(view.hud,"选择 %d" % index,func():selected.append(index))
   view.responsive.add_phase_action(button)
  view.responsive.position_persistent();await frames()
  check_actions(prefix+" short list "+str(count),count)
  expect(view.stack_panel.visible,prefix+" short list retains the stack")
  var prompt=view.txt("选择本次能力的处理方式，或放弃发动。",Rect2(),17,app.GOLD)
  view.responsive.add_choice_notice(prompt)
  view.network_session=RailSession.new();view.responsive.position_persistent();await frames()
  check_actions(prefix+" network prompt "+str(count),count)
  expect(view.stack_panel.visible,prefix+" network prompt retains the stack")
  var last=view.responsive.action_column.get_child(count-1)
  await tap(last.get_global_rect().get_center());await frames()
  expect(selected==[count-1],prefix+" last action is immediately clickable")
  view.network_session=null

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.is_android=true;app.load_legacy_test_decks()
 for fixture in [{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(1920,1080),"dpi":360.0},{"size":Vector2i(2340,1080),"dpi":420.0},{"size":Vector2i(2160,1080),"dpi":480.0},{"size":Vector2i(1280,720),"dpi":320.0}]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture.size;app.layout_dpi_override=fixture.dpi;app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24)
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var prefix="%dx%d-dpi%d" % [fixture.size.x,fixture.size.y,int(fixture.dpi)]
  await check_patchouli(prefix);await check_short_lists(prefix)
 print("ANDROID ABILITY OPTIONS: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
