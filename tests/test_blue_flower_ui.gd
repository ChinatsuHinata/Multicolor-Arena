extends "res://tests/support/ui_base.gd"

const BLUE_FLOWER="spell-fdn-069"
const OTHER_SPELL="spell-fdf-036"

func frames(count: int=8):
 for i in range(count):await process_frame

func tap(at: Vector2):
 if not view.is_android:await click(at);return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func prepare():
 clean(true);e.debug_free_payment=true
 for who in [0,1]:
  for i in range(4):put("164","deck",who)

func stack_spell(who: int) -> Dictionary:
 var card=e.make_card(OTHER_SPELL,who,"stack")
 var entry={"id":e.next_stack,"kind":"card","card":card,"owner":who,"name":e.cards[card.card_id].name,"target":{"none":true}}
 e.stack.append(entry);e.next_stack+=1
 return entry

func cast_flower() -> Dictionary:
 var card=put(BLUE_FLOWER,"hand")
 var error=e.commit_cast(0,card.uid,{"none":true},[])
 expect(error.is_empty(),"Blue Flower cast succeeds: "+error)
 resolve();view.render();await settle();await frames()
 expect(e.pending.get("trigger",{}).get("effect","")=="blue_flower_resolution","Blue Flower opens its resolution choice")
 return card

func check_self(label: String,scenario: String):
 prepare()
 if scenario=="ability":
  var source=put("2","field",1)
  e.stack.append({"id":e.next_stack,"kind":"ability","source":source,"owner":1,"name":"测试能力","ability_text":"测试能力","target":{"none":true}})
  e.next_stack+=1
 elif scenario=="departed":
  e.move_to(stack_spell(1).card,"grave")
 var card=await cast_flower()
 var button=find_button(view.ui,"反制自身")
 expect(button!=null and button.is_visible_in_tree() and not button.disabled,label+" shows the self-counter button when no other spell remains: "+scenario)
 expect(view.picker.ready() and view.picker.option().get("self",false) and view.picker.available_refs().is_empty(),label+" self-counter is ready without selecting a stack entry")
 if button!=null:await tap(button.get_global_rect().get_center());await frames()
 expect(card.zone=="deck" and e.players[0].deck[2].uid==card.uid and e.pending.is_empty(),label+" self-counter button puts Blue Flower third from the deck top")

func check_stack(label: String,who: int):
 prepare()
 var other=stack_spell(who)
 var card=await cast_flower()
 expect(find_button(view.ui,"反制自身")==null and find_button(view.ui,"青ノ花自身")==null,label+" hides self-counter while a spell is selectable")
 expect(not view.picker.ready() and view.picker.available().all(func(atom):return atom.kind=="target" and atom.value.has("stack_id")),label+" requires selecting a spell in the stack")
 expect(view.table.targetable_stacks==[other.id] and view.stack_panel.tiles[other.id].tile.get_meta("legal",false),label+" highlights the selectable stack spell")
 expect(e.pending.options.any(func(option):return option.get("self",false)),label+" presentation preserves the engine's legal options")
 var rect=view.stack_panel.entry_rect(other.id)
 expect(rect.has_area(),label+" selectable spell is exposed in the stack")
 if rect.has_area():await tap(rect.get_center());await frames()
 expect(view.picker.ready() and view.picker.option()=={"stack_id":other.id},label+" clicking the stack selects the spell")
 expect(find_button(view.ui,"反制自身")==null,label+" selection does not reveal self-counter")
 var reset=find_button(view.ui,"重选")
 if reset!=null:await tap(reset.get_global_rect().get_center());await frames()
 expect(not view.picker.ready() and find_button(view.ui,"反制自身")==null,label+" reselecting keeps selection in the stack")
 rect=view.stack_panel.entry_rect(other.id)
 if rect.has_area():await tap(rect.get_center());await frames()
 var confirm=find_button(view.ui,"确定")
 expect(confirm!=null and not confirm.disabled,label+" selected spell can be confirmed")
 if confirm!=null:await tap(confirm.get_global_rect().get_center());await frames()
 expect(other.card.zone=="deck" and e.players[who].deck[2].uid==other.card.uid and card.zone=="grave" and e.pending.is_empty(),label+" confirmation moves the chosen spell and completes Blue Flower")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/blue-flower-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root_override.path_join("settings.json");root.add_child(app);await frames();app.load_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
  app.layout_safe_override=Rect2(60,0,1196,696) if android else Rect2()
  app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  var label="Android" if android else "Desktop"
  for scenario in ["empty","ability","departed"]:await check_self(label,scenario)
  for who in [0,1]:await check_stack(label,who)
 print("BLUE_FLOWER_UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
