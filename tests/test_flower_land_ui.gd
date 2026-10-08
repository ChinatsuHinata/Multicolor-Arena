extends "res://tests/support/ui_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const FLOWER="spell-fdf-031"

func prompt_label(node: Node):
 if node is Label and node.get_meta("optional_trigger_prompt",false):return node
 for child in node.get_children():
  var found=prompt_label(child)
  if found!=null:return found
 return null

func pick_target(ref: Dictionary):
 var choices=view.picker.available().filter(func(atom):return atom.kind=="target" and atom.value==ref)
 expect(choices.size()==1,"requested target is available")
 if not choices.is_empty():view.inline_pick(choices[0])

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/flower-land-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root_override.path_join("settings.json");root.add_child(app);await process_frame
 app.load_test_decks()
 for mobile in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await process_frame
  app.is_android=mobile;app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
  for top_down in [false,true]:
   clean();view.table.set_top_down_view(top_down)
   var yuuka=put("character-soi-018","field");var ally=put("53","field");var enemy=put("53","field",1);var spell=put(FLOWER,"hand")
   for i in range(3):put("165","palette");put("166","palette")
   view.render();await settle();view.request_cast(spell.uid)
   expect(view.local.get("mode","")=="target","paid spell begins with manual target selection")
   pick_target({"player":1})
   var finish=view.picker.available().filter(func(atom):return atom.kind=="finish_group")
   if not finish.is_empty():view.inline_pick(finish[0])
   expect(not view.picker.ready() and not view.picker.available().any(func(atom):return atom.kind=="finish_group"),"reset step cannot be skipped or confirmed empty")
   expect(view.picker.available().any(func(atom):return atom.kind=="target" and atom.value==e.ref_target(enemy)),"opposing unit can be selected for reset")
   var reset_unit=enemy if top_down else ally
   pick_target(e.ref_target(reset_unit))
   expect(view.picker.ready(),"upright own or enemy unit completes the declaration")
   view.confirm_declaration()
   expect(spell.zone=="stack" and view.local.is_empty(),"UI submits a real cast after both selections")
   e.tap_card(reset_unit);resolve()
   expect(not reset_unit.tapped and e.players[1].life==16,"UI-selected unit resets on resolution")

   clean();view.table.set_top_down_view(top_down);put("53","field");spell=put(FLOWER,"hand")
   e.move_to(spell,"palette");e.pump_choices();e.presentation_events.clear();view.reveal_player.reset();view.render();await settle();view.render();await process_frame
   var prompt=prompt_label(view.ui)
   expect(prompt==null and e.pending.is_empty() and e.stack.is_empty(),"missing Yuuka shows no trigger prompt on both layouts")
   expect(spell.zone=="palette" and not view.picker_active(),"skipped palette trigger leaves no choice to confirm or decline")
   var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,0));view.engine=remote;view.table.duel=remote;view.render();await process_frame
   prompt=prompt_label(view.ui)
   expect(prompt==null and not view.picker_active(),"network UI also suppresses the trigger without Yuuka")
   view.engine=e;view.table.duel=e;view.render()
   put("character-soi-018","field");var enabled=put(FLOWER,"hand")
   e.move_to(enabled,"palette");e.pump_choices();e.presentation_events.clear();view.reveal_player.reset();view.render();await settle();view.render();await process_frame
   expect(prompt_label(view.ui)!=null and e.pending.get("trigger",{}).get("effect","")=="cat:flower_cast","own Yuuka preserves the normal palette trigger prompt")
   view.decline_trigger()
   expect(e.pending.is_empty() and e.stack.is_empty() and enabled.zone=="palette","eligible palette trigger still supports declining")
 print("FLOWER_LAND_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
