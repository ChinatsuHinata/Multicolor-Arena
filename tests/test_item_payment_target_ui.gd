extends "res://tests/support/ui_base.gd"

func frames(count: int=3):
 for i in range(count):await process_frame

func activate(at: Vector2):
 if not view.is_android:
  await click(at)
  return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await process_frame;await physics_frame

func select_card(uid: int):
 view.object_clicked(uid);await frames()

func reserved(uid: int) -> bool:
 return view.local.get("plan",[]).any(func(entry):return entry.uid==uid)

func check_spell(id: String,resource_id: String,unused_id: String,prefix: String):
 clean()
 e.debug_free_payment=false
 var spell=put(id,"hand")
 var items={}
 for card_id in ["165","166","167","164"]:items[card_id]=put(card_id,"field")
 var resource=items[resource_id];var unused=items[unused_id]
 var tapped=put(resource_id,"field");tapped.tapped=true
 var enemy=put("164","field",1);var boundary=put("170","field",1)
 for card_id in ["165","165","166","167","167","167","164","164"]:put(card_id,"palette")
 var role=e.cards[id].requires_character
 if not role.is_empty():put(e.cards.keys().filter(func(key):return e.cards[key].kind in ["单位","自机"] and e.Roster.character_matches(e.cards[key].character,role))[0],"field")
 view.render();await settle();view.request_cast(spell.uid);await settle()
 expect(view.local.get("mode","")=="target" and view.payment_ready(),prefix+" starts a paid declaration")
 if view.local.is_empty():return
 if id=="134":
  resource=items.values().filter(func(item):return reserved(item.uid))[0];resource_id=resource.card_id
  unused=items.values().filter(func(item):return not reserved(item.uid))[0]
 expect(reserved(resource.uid),prefix+" suggested payment reserves its field item")
 expect(view.picker.available_refs().any(func(ref):return ref.get("uid",0)==resource.uid),prefix+" the same item is also a legal spell target")
 var before=snapshot();var count=view.local.plan.size()
 await select_card(resource.uid)
 expect(not reserved(resource.uid) and view.local.plan.size()==count-1,prefix+" clicking the reserved item removes its payment reservation")
 expect(view.picker.selected_refs().is_empty(),prefix+" payment click does not choose a self target")
 await select_card(resource.uid)
 expect(reserved(resource.uid) and view.payment_ready(),prefix+" clicking again restores the payment reservation")
 expect(snapshot()==before,prefix+" editing reservations does not mutate the duel")
 expect(not view.payment_sources().any(func(source):return source.uid==unused.uid),prefix+" an unreserved item cannot join a full or incompatible payment")
 await select_card(unused.uid)
 expect(view.picker.selected_refs().is_empty(),prefix+" an unavailable payment item cannot accidentally become a self target")

 await select_card(enemy.uid)
 expect(view.picker.ready() and view.local.target.get("uid",0)==enemy.uid,prefix+" enemy item remains directly targetable")
 await select_card(resource.uid)
 expect(not reserved(resource.uid) and view.local.target.get("uid",0)==enemy.uid,prefix+" changing payment preserves the chosen enemy target")
 var replacement=e.players[0].palette.filter(func(card):return card.card_id==resource_id and not reserved(card.uid))[0]
 view.object_clicked(replacement.uid)
 expect(reserved(replacement.uid) and view.payment_ready(),prefix+" palette resource can replace the item payment")
 await select_card(resource.uid)
 expect(not reserved(resource.uid) and view.local.target.get("uid",0)==enemy.uid,prefix+" clicking an item while payment is full preserves the target")
 view.object_clicked(replacement.uid);await select_card(resource.uid)
 expect(reserved(resource.uid) and not reserved(replacement.uid),prefix+" item payment can be restored")

 var mode=view.android_choice_panel.get_node_or_null("ItemClickMode")
 expect(mode!=null and mode.text=="己方道具：调整支付",prefix+" ambiguous item clicks expose their payment mode")
 if mode==null:return
 var panel=view.android_choice_panel
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),prefix+" mode panel fits the safe area")
 expect(not mode.get_global_rect().intersects(panel.get_node("ChoiceConfirm").get_global_rect()),prefix+" mode button leaves confirmation clear")
 await activate(mode.get_global_rect().get_center());await frames()
 var plan=view.local.plan.duplicate(true)
 await select_card(resource.uid)
 expect(view.local.target.get("uid",0)==resource.uid and view.local.plan==plan,prefix+" explicit target mode can select an own payment item without changing payment")
 mode=view.android_choice_panel.get_node("ItemClickMode")
 await activate(mode.get_global_rect().get_center());await frames()
 await select_card(enemy.uid)
 await select_card(tapped.uid)
 expect(view.local.target.get("uid",0)==tapped.uid,prefix+" tapped own items remain directly targetable")
 await select_card(boundary.uid)
 expect(view.local.target.get("uid",0)==boundary.uid,prefix+" boundaries remain directly targetable")
 await select_card(enemy.uid)
 expect(snapshot()==before,prefix+" selecting targets and switching modes do not pay or resolve early")
 view.confirm_declaration()
 expect(spell.zone=="stack" and e.stack.back().target.get("uid",0)==enemy.uid,prefix+" confirmation submits the selected enemy target")
 expect(resource.tapped and enemy.zone=="field",prefix+" confirmation pays with the own item and waits for resolution")
 resolve()
 expect(enemy.zone==("exile" if id=="135" else "grave") and resource.zone=="field",prefix+" resolution removes the enemy item and preserves the payment item")
 view.render();await settle()

func check_multiple_targets(prefix: String):
 clean();e.debug_free_payment=false
 var spell=put("spell-fdf-074","hand")
 var red=put("165","field");var green=put("166","field");var enemy=put("164","field",1)
 var role=e.cards[spell.card_id].requires_character
 put(e.cards.keys().filter(func(key):return e.cards[key].kind in ["单位","自机"] and e.Roster.character_matches(e.cards[key].character,role))[0],"field")
 for id in ["165","165","166","166"]:put(id,"palette")
 view.render();await settle();view.request_cast(spell.uid);await settle()
 expect(not view.local.is_empty() and view.payment_ready(),prefix+" multi-target spell starts with real payment")
 expect(view.picker.available().any(func(atom):return atom.kind=="finish_group"),prefix+" optional target group offers a finish action alongside board targets")
 var mode=view.android_choice_panel.find_child("ItemClickMode",true,false)
 expect(mode!=null,prefix+" mixed choice panel also exposes the item click mode")
 if mode==null:return
 await select_card(red.uid)
 expect(not reserved(red.uid) and view.picker.selected_refs().is_empty(),prefix+" multi-target item click edits payment")
 await select_card(red.uid)
 mode=view.android_choice_panel.find_child("ItemClickMode",true,false)
 await activate(mode.get_global_rect().get_center());await frames()
 var plan=view.local.plan.duplicate(true)
 await select_card(red.uid);await select_card(enemy.uid)
 expect(view.picker.selected_refs().size()==2 and view.local.plan==plan,prefix+" explicit target mode selects both own and enemy items")
 var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
 if not finish.is_empty():view.inline_pick(finish[0])
 expect(view.picker.ready(),prefix+" multiple item targets can be completed")
 view.confirm_declaration()
 expect(spell.zone=="stack" and red.tapped and green.tapped,prefix+" the same own item can legally pay and be a declared target")
 resolve()
 expect(red.zone=="grave" and enemy.zone=="grave" and green.zone=="field",prefix+" explicit own and enemy item targets both resolve")
 view.render();await settle()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/item-payment-target-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 DirAccess.make_dir_recursive_absolute(app.tutorial_local_directory)
 root.add_child(app);await frames();app.load_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=320.0 if android else 0.0
  app.layout_safe_override=Rect2(36,0,1220,696) if android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  for top_down in [false,true]:
   view.table.set_top_down_view(top_down)
   for fixture in [["134","166","167"],["104","165","166"],["135","167","166"]]:
    var prefix=("Android" if android else "Desktop")+" "+("2D" if top_down else "3D")+" "+fixture[0]
    await check_spell(fixture[0],fixture[1],fixture[2],prefix)
  await check_multiple_targets("Android" if android else "Desktop")
 print("ITEM_PAYMENT_TARGET_UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
