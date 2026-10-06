extends "res://tests/support/ui_base.gd"

func show_board():
 e.presentation_events.clear();view.reveal_player.reset();view.picker.reset();view.render()

func spell_role(spell: Dictionary):
 var role=e.cards[spell.card_id].requires_character
 if role.is_empty():return
 var candidates=e.cards.keys().filter(func(id):return e.cards[id].kind in ["单位","自机"] and e.Roster.character_matches(e.cards[id].character,role))
 put(candidates[0],"field")

func keine_board(backpack: bool=false) -> Dictionary:
 clean()
 var source=put("character-fdf-ex05","field");source.leader=true;source.entered_turns=0
 var victim=put("53","field");victim.entered_turns=0
 var top=put("164","deck",1)
 if backpack:put("item-ucs-012","field",1)
 show_board()
 return {"source":source,"victim":victim,"top":top}

func check_ui(label: String):
 var board=keine_board()
 view.begin_action({"type":"extension","uid":board.source.uid,"key":"keine_devour"})
 expect(view.picker.available_refs().all(func(ref):return ref.has("uid")),label+" Keine asks only for the sacrifice")
 view.choose_target(e.ref_target(board.victim))
 expect(view.picker.ready() and view.picker.available_refs().is_empty(),label+" Keine can launch immediately after selecting a sacrifice")
 expect(view.picker.option().picks[1]==[{"player":1}],label+" automatic opponent remains in the declaration")
 expect(find_button(view.ui,"下一项（1）")==null,label+" no extra next-group step is shown")
 var launch=find_button(view.ui,"发动")
 expect(launch!=null and not launch.disabled,label+" launch button is enabled without clicking the opponent")
 var reset=find_button(view.ui,"重选")
 expect(reset!=null,label+" manual sacrifice can still be reset")
 if reset!=null:reset.pressed.emit()
 expect(not view.picker.ready() and not view.picker.available_refs().any(func(ref):return ref.has("player")),label+" reset returns to the sacrifice")
 view.choose_target(e.ref_target(board.victim));view.confirm_declaration()
 expect(board.victim.zone=="grave" and e.pending.is_empty() and e.stack.size()==1,label+" launch pays the sacrifice and opens ordinary responses")
 resolve();expect(board.top.zone=="exile",label+" launched Keine devours the top card")

 board=keine_board();put("character-ucs-046","field",1);show_board()
 var action=e.available_actions(0,board.source.uid,true).filter(func(option):return option.get("key","")=="keine_devour")[0]
 expect(not action.enabled and action.reason=="没有合法目标",label+" Nitori disables the ability in the action menu")
 view.begin_action(action)
 expect(view.local.is_empty() and board.victim.zone=="field",label+" blocked launch cannot enter sacrifice selection")

 board=keine_board(true);put("167","palette");show_board()
 view.begin_action({"type":"extension","uid":board.source.uid,"key":"keine_devour"})
 view.choose_target(e.ref_target(board.victim));view.confirm_declaration()
 expect(e.stack.size()==2 and e.stack.back().effect=="backpack_tax",label+" auto-targeted Keine triggers backpack")
 resolve();show_board()
 expect(e.pending.trigger.effect=="backpack_pay",label+" backpack keeps its payment decision")
 var payment=view.picker.available().filter(func(atom):return atom.kind=="mode" and atom.value=="支付1点")
 expect(not payment.is_empty(),label+" backpack offers payment")
 if not payment.is_empty():
  view.inline_pick(payment[0])
  var resource=e.players[0].palette[0]
  view.choose_target(e.Pack.ref(e,resource));view.confirm_trigger()
  expect(resource.tapped and e.stack.size()==1,label+" backpack payment commits independently")
  resolve();expect(board.top.zone=="exile",label+" paid backpack preserves Keine")

 clean();var source=put("49","field");e.Extra.on_enter(e,source);e.pump_choices();show_board()
 expect(view.picker.ready() and view.picker.available_refs().is_empty(),label+" optional opponent trigger requires no target clicks")
 expect(find_button(view.ui,"重选")==null and find_button(view.ui,"不使用")!=null,label+" optional trigger offers use/decline without redundant reset")
 view.decline_trigger();expect(e.stack.is_empty(),label+" optional trigger can still be declined")

 clean();var spell=put("spell-fdf-061","hand")
 spell_role(spell)
 for i in range(8):put("167","palette")
 show_board();view.request_cast(spell.uid)
 var choices=view.picker.available()
 expect(choices.size()==2 and choices.all(func(atom):return atom.kind=="mode"),label+" opponent spell still asks for its mode")
 if not choices.is_empty():
  view.inline_pick(choices[0])
  expect(view.picker.ready() and view.picker.available_refs().is_empty(),label+" mode selection skips the automatic opponent")
 view.cancel_cast()

 clean();spell=put("spell-fdf-008","hand");e.debug_enabled=true;e.debug_free_payment=true
 spell_role(spell)
 show_board();view.request_cast(spell.uid)
 expect(view.picker.ready() and view.picker.option()=={"player":1} and view.picker.available_refs().is_empty(),label+" opponent-only spell skips player selection")
 expect(find_button(view.ui,"重选")==null,label+" sole automatic opponent has no reset control")
 view.cancel_cast()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/opponent-targeting-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await process_frame
  app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  await process_frame;app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);view.fast_mode=true;e=view.engine
  await process_frame
  check_ui("Android" if android else "Desktop")
 print("OPPONENT_TARGETING_UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
