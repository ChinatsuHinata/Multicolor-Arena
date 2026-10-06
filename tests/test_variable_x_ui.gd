extends "res://tests/support/ui_base.gd"
var output="res://work/variable-x-ui"
func frames(count: int=6):
 for i in range(count):await process_frame
func edit(input: LineEdit,value: String):
 input.text=value;input.text_changed.emit(value)
func type_value(input: LineEdit,value: String):
 input.grab_focus();input.select_all()
 for index in range(value.length()):
  var event=InputEventKey.new();event.pressed=true;event.keycode=value.unicode_at(index);event.unicode=value.unicode_at(index)
  root.push_input(event,true);await process_frame
  event=event.duplicate();event.pressed=false;root.push_input(event,true);await process_frame
func submit():
 var button=view.android_choice_panel.get_node("ChoiceFooter/ChoiceConfirm") as Button
 button.pressed.emit();await frames()
func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func x_field() -> LineEdit:
 return view.android_choice_panel.get_node("XValueInput") as LineEdit
func check_flow(prefix: String):
 clean()
 var spell=put("111","hand")
 for id in ["167","167","164","164","164","165"]:put(id,"palette")
 view.render();view.request_cast(spell.uid);await frames()
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel) and panel.has_node("XValueInput"),prefix+" opens the numeric X field")
 if not is_instance_valid(panel) or not panel.has_node("XValueInput"):return
 expect(panel.get_meta("centered",false) and app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),prefix+" numeric popup is centered and fits the safe area")
 expect(panel.get_node("XRange").text.contains("X 最大为 3"),prefix+" displays the precomputed payable maximum")
 expect(panel.find_children("ChoiceTile*","Button",true,false).is_empty(),prefix+" replaces the long X option list")
 var input=x_field();var button=panel.get_node("ChoiceFooter/ChoiceConfirm") as Button
 for invalid in ["-1","1.5","4","a","99999999999999999999"]:
  edit(input,invalid);expect(input.text=="0",prefix+" rejects "+invalid)
 edit(input,"");expect(button.disabled,prefix+" empty X cannot be submitted")
 button.pressed.emit();await frames()
 expect(view.picker.selected_x()==-1 and e.stack.is_empty(),prefix+" empty input cannot advance even through the callback")
 await type_value(input,"3")
 expect(input.text=="3" and not button.disabled,prefix+" real key input accepts legal X")
 var notice=panel.get_node("XRange") as Label
 expect(view.responsive.wrapped_height(notice.text,notice.size.x,notice.get_theme_font_size("font_size"))<=notice.size.y,prefix+" range text fits at the actual font size")
 var hide=find_button(panel,"隐藏");hide.pressed.emit();await frames()
 expect(not is_instance_valid(view.android_choice_panel),prefix+" numeric popup can be hidden")
 view.android_choice_restore.pressed.emit();await frames()
 expect(x_field().text=="3",prefix+" restoring the popup keeps the drafted X")
 await shot(prefix+"-input")
 await submit()
 expect(view.picker.selected_x()==3 and not view.picker.ready(),prefix+" typed X advances to target selection")
 expect(view.android_choice_panel.has_node("BoardTargetPrompt") and not view.android_choice_panel.get_meta("centered",false),prefix+" the next step asks for a battlefield target")
 view.choose_target({"player":1});await frames()
 expect(view.picker.ready() and view.picker.option().x==3,prefix+" target selection retains X")
 var reset=find_button(view.android_choice_panel,"重选");reset.pressed.emit();await frames()
 expect(x_field().text=="3" and not view.picker.ready(),prefix+" reselect returns to X without declaring a target")
 edit(x_field(),"2");await submit();view.choose_target({"player":1});view.confirm_declaration();await frames()
 expect(e.stack.any(func(entry):return entry.get("card",{}).get("uid",0)==spell.uid and entry.target.x==2 and entry.target.player==1),prefix+" typed X commits the actual spell and chosen player")
 expect(e.players[0].palette.filter(func(c):return c.tapped).size()==4,prefix+" commit pays two fixed blue plus two yellow")

 clean();var unit=put("character-fdf-ex03","hand")
 put("166","field").tapped=true;put("164","field").tapped=true
 for id in ["166","166","164","164"]:put(id,"palette")
 view.render();view.request_cast(unit.uid);await frames()
 expect(is_instance_valid(view.android_choice_panel) and view.android_choice_panel.has_node("XValueInput"),prefix+" variable-cost unit opens its numeric popup")
 if not is_instance_valid(view.android_choice_panel) or not view.android_choice_panel.has_node("XValueInput"):return
 expect(x_field().values==[0,1,2],prefix+" variable-cost unit also uses the numeric popup")
 edit(x_field(),"2");await submit()
 expect(view.picker.ready() and not e.players[0].palette.any(func(c):return c.tapped),prefix+" choosing unit X only reserves resources")
 edit(x_field(),"1");await submit()
 expect(view.picker.option().x==1 and view.local.plan.size()==3,prefix+" changing X recalculates payment before submission")
 await shot(prefix+"-unit-confirm")
 await submit()
 expect(unit.zone=="stack" and e.stack.back().target.x==1,prefix+" unit confirmation actually uses the revised X")
 view.cancel_cast()

 clean();var source=put("new-eto-002","field")
 for i in range(4):put("new-eto-s001","field")
 e.Roster.on_enter(e,source);e.pump_choices();e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
 expect(view.picker.ready() and view.picker.option()=={"none":true},prefix+" non-target orb sacrifice is announced before choosing its count")
 view.confirm_trigger();resolve();view.render();await frames()
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:ball_sacrifice",prefix+" orb count is selected during resolution")
 var orbs=view.picker.available_refs()
 if orbs.size()>=2:
  view.choose_target(orbs[0]);view.choose_target(orbs[1])
  view.inline_pick(view.picker.available().filter(func(atom):return atom.kind=="finish_group")[0])
  view.confirm_trigger();await frames()
  expect(e.players[1].life==18 and e.find_card(orbs[0].uid).zone!="field" and e.find_card(orbs[1].uid).zone!="field",prefix+" orb damage uses the actual two sacrifices")
 clean();var alice=put("character-fdf-112","field");alice.entered_turns=0
 for i in range(3):e.Cat.tokens(e,0,1,"人偶",1,1,1,["黄"])
 e.presentation_events.clear();view.reveal_player.reset();view.render()
 view.execute_action({"type":"extension","uid":alice.uid,"key":"character-fdf-112","enabled":true});await frames()
 var branches=view.picker.available().filter(func(atom):return atom.kind=="mode" and atom.value=="牺牲人偶并检索")
 expect(branches.size()==1,prefix+" Alice still offers her sacrifice mode before resolution")
 if branches.is_empty():return
 view.inline_pick(branches[0]);view.confirm_declaration();resolve();view.render();await frames()
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:alice_sacrifice",prefix+" Alice chooses X during resolution")
 expect(x_field().values==[0,1,2,3],prefix+" Alice's sacrifice mode opens the numeric X field")
 edit(x_field(),"2");await shot(prefix+"-alice-input");await submit()
 var targets=view.picker.available().filter(func(atom):return atom.kind=="target")
 var sacrificed=[targets[0].value]
 view.choose_target(targets[0].value);await frames()
 expect(not view.picker.ready(),prefix+" one doll does not fulfill a declared X of two")
 targets=view.picker.available().filter(func(atom):return atom.kind=="target")
 sacrificed.append(targets[0].value)
 view.choose_target(targets[0].value);await frames()
 expect(view.picker.ready() and view.picker.option().picks[0].size()==2,prefix+" exactly two dolls fulfill typed X")
 view.confirm_trigger();await frames()
 expect(alice.tapped and sacrificed.all(func(ref):return e.find_card(ref.uid).is_empty() or e.find_card(ref.uid).zone!="field"),prefix+" Alice sacrifices exactly the two dolls chosen for X")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for fixture in [{"size":Vector2i(1600,900),"dpi":0.0},{"size":Vector2i(1280,720),"dpi":320.0},{"size":Vector2i(2160,1080),"dpi":480.0}]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture.size;app.is_android=fixture.dpi>0;app.layout_dpi_override=fixture.dpi
  app.layout_safe_override=Rect2(60,0,fixture.size.x-84,fixture.size.y-24) if app.is_android else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  await check_flow("%dx%d-dpi%d" % [fixture.size.x,fixture.size.y,int(fixture.dpi)])
 print("VARIABLE_X_UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
