extends Control
## Transient speech stays outside the rebuilt HUD and never blocks rule animation.
const Profiles=preload("res://scripts/rules/leader_emotes.gd")
const Wheel=preload("res://scripts/emote_wheel.gd")
const Bubble=preload("res://scripts/emote_bubble.gd")
const Icon=preload("res://scripts/emote_icon.gd")
const DISPLAY_MS=4000
var view
var button: Button
var opponent_button: Button
var wheel: Control
var shade: Control
var bubbles={}
var expires={}
var speakers={}
var seen={}
var game_key=""
var observed_serial=0
var entry_finger=-1
var entry_control: Button

func build(owner_view):
 view=owner_view;name="LeaderEmotes"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 button=view.host.button(self,"",Rect2(),open_wheel)
 button.name="LeaderEmoteButton";button.icon=Icon.texture("greeting",48)
 button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
 button.z_index=90
 opponent_button=view.host.button(self,"",Rect2(),toggle_opponent_emotes)
 opponent_button.name="OpponentEmoteToggle";opponent_button.toggle_mode=true
 opponent_button.z_index=90
 opponent_button.icon=Icon.texture("greeting",48)
 opponent_button.expand_icon=true
 opponent_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
 opponent_button.draw.connect(draw_opponent_slash)
 # The shared text-button margins leave a square icon toggle almost no room.
 for state in ["normal","hover","pressed","disabled","hover_pressed"]:
  var box=opponent_button.get_theme_stylebox(state)
  if box==null:continue
  box=box.duplicate()
  box.content_margin_left=6;box.content_margin_right=6;box.content_margin_top=6;box.content_margin_bottom=5
  opponent_button.add_theme_stylebox_override(state,box)
 refresh()

func enabled() -> bool:
 return Profiles.profile(view.engine,view.local_seat).get("enabled",false)

func other_popup() -> bool:
 if view.host.menu_popup_open() or view.modal or view.observing or view.history_open or view.debug_open or view.action_menu_open or view.keep_popup_open:return true
 for node in [view.modal_root,view.android_choice_panel,view.android_battle_menu_root,view.table.inspect_root]:
  if is_instance_valid(node) and node.visible:return true
 if view.is_android and view.inspection.visible:return true
 for child in view.host.get_children():
  if child is Window and child.visible and not child.is_queued_for_deletion():return true
 return false

func available() -> bool:
 var e=view.engine
 if not enabled() or e.winner!=-2 or e.phase in ["mulligan","over"] or e.priority!=view.local_seat:return false
 if view.replay_view() or view.spectator_view() or view.network_locked() or view.response_disabled():return false
 if view.network_session!=null and not view.network_session.can_act(true):return false
 if not e.pending.is_empty() or not e.entry_choices.is_empty() or not view.local.is_empty():return false
 if view.tutorial_runtime!=null and (not view.tutorial_controls_enabled or view.tutorial_runtime.playing_sequence()):return false
 if other_popup() or view.revealing() or view.table.combat_animating:return false
 if view.drag_uid!=0 or view.debug_drag_uid!=0 or view.unit_drag_uid!=0 or view.attack_preview_uid!=0:return false
 return e.emote_remaining(view.local_seat)<=0.0

func entry_rect() -> Rect2:
 var safe=view.responsive.safe
 var extent=maxf(52.0,view.host.ui_metrics.hit) if view.is_android else 52.0
 var at=Vector2(safe.position.x,view.responsive.hand_toggle_rect.position.y-extent-view.host.ui_metrics.gap) if view.is_android else Vector2(view.responsive.own_life.end.x+10,view.responsive.own_life.position.y)
 return Rect2(at,Vector2(extent+12 if view.is_android else extent,extent))

func opponent_entry_rect() -> Rect2:
 var entry=entry_rect()
 if view.is_android:
  # Only measured layout rects here: render() rebuilds the toolbar and calls
  # refresh() before its labels are sized, so live widths make the toggle jump.
  # Its size must not read its own minimum size either, which icon_max_width
  # derives from this rect.
  var height=view.host.ui_metrics.hit
  var gap=view.host.ui_metrics.gap
  # Beside the send button when the left rail is wide enough.
  if entry.size.x+gap+height<=view.responsive.enemy_life.size.x:
   return Rect2(entry.end.x+gap,entry.position.y+(entry.size.y-height)*0.5,height,height)
  var bounds=Rect2(entry.position-Vector2(0,height+gap),Vector2(height,height))
  var enemy_status_bottom=view.responsive.enemy_life.end.y+view.host.ui_metrics.hit*2+gap*3+view.host.ui_metrics.body*2.5
  # Dense touch controls can fill the upper rail. Use its separate lower gap
  # without moving the camera, payment, hand or emote-send controls.
  if bounds.position.y<enemy_status_bottom+gap:
   var slot=toolbar_slot(height,gap)
   if slot.has_area():return slot
   bounds.position.y=view.responsive.hand_toggle_rect.end.y+gap
  return bounds
 var life=view.responsive.enemy_life
 return Rect2(life.end.x+10,roundf(life.position.y+(life.size.y-44.0)*0.5),44,44)

## Blank space after the phase caption, from minimum sizes rather than the
## caption's sorted width, which is still zero right after a HUD rebuild.
func toolbar_slot(extent: float,gap: float) -> Rect2:
 var toolbar=view.responsive.toolbar
 if not is_instance_valid(toolbar):return Rect2()
 var phase=toolbar.get_node_or_null("BattlePhase")
 if phase==null:return Rect2()
 var phase_width=view.responsive.toolbar_rect.size.x
 var shown=0
 for child in toolbar.get_children():
  if not child is Control or not child.visible:continue
  shown+=1
  if child!=phase:phase_width-=child.get_combined_minimum_size().x
 phase_width-=toolbar.get_theme_constant("separation")*maxi(0,shown-1)
 var text_width=phase.get_theme_font("font").get_string_size(phase.text,HORIZONTAL_ALIGNMENT_LEFT,-1,phase.get_theme_font_size("font_size")).x
 if phase_width-text_width<extent+gap*2:return Rect2()
 var rect=view.responsive.toolbar_rect
 return Rect2(rect.position.x+phase_width-extent-gap,rect.position.y,extent,extent)

func draw_opponent_slash():
 if view==null or view.host.show_opponent_emotes:return
 var s=opponent_button.size
 var start=Vector2(s.x*0.26,s.y*0.74)
 var end=Vector2(s.x*0.74,s.y*0.26)
 var width=maxf(3.0,s.y*0.07)
 opponent_button.draw_line(start,end,Color("#24110f"),width+2,true)
 opponent_button.draw_line(start,end,Color("#cf4538"),width,true)

func opponent_emotes_hidden() -> bool:
 return not view.host.show_opponent_emotes and not view.replay_view() and not view.spectator_view()

func toggle_opponent_emotes():
 if not opponent_button.visible or opponent_button.disabled or other_popup():return
 view.host.set_show_opponent_emotes(not view.host.show_opponent_emotes)

func remove_bubble(who: int):
 if is_instance_valid(bubbles.get(who)):
  bubbles[who].hide();bubbles[who].queue_free()
 bubbles.erase(who);expires.erase(who);speakers.erase(who)

func refresh():
 if view==null or view.engine==null:return
 var key=str(view.engine.get_instance_id())+":"+(str(view.network_session.local_game_id) if view.network_session!=null else "offline")
 if key!=game_key or int(view.engine.emote_serial)<observed_serial:
  reset();game_key=key
 observed_serial=int(view.engine.emote_serial)
 var bounds=entry_rect();button.position=bounds.position;button.size=bounds.size
 button.visible=enabled() and not view.replay_view() and not view.spectator_view()
 button.disabled=not available()
 var remaining=ceili(view.engine.emote_remaining(view.local_seat))
 button.text=str(remaining) if remaining>0 else ""
 button.tooltip_text="表情冷却：%d 秒" % remaining if remaining>0 else "表情 · 在我方可响应且没有弹框时使用"
 opponent_button.text=""
 # Reapplying even the same override emits theme_changed on every frame.
 # Keep text/layout caches intact until responsive metrics actually change.
 var opponent_font_size=view.host.ui_metrics.small if view.is_android else 14
 if opponent_button.get_theme_font_size("font_size")!=opponent_font_size:
  opponent_button.add_theme_font_size_override("font_size",opponent_font_size)
 var opponent_bounds=opponent_entry_rect()
 opponent_button.position=opponent_bounds.position;opponent_button.size=opponent_bounds.size
 var opponent_icon_width=roundi(opponent_bounds.size.y*0.56) if view.is_android else 28
 if opponent_button.get_theme_constant("icon_max_width")!=opponent_icon_width:
  opponent_button.add_theme_constant_override("icon_max_width",opponent_icon_width)
 var opponent_icon_color=Color(1,1,1,1.0 if view.host.show_opponent_emotes else 0.55)
 var icon_changed=false
 for color_name in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color","icon_hover_pressed_color"]:
  if opponent_button.get_theme_color(color_name)!=opponent_icon_color:
   opponent_button.add_theme_color_override(color_name,opponent_icon_color)
   icon_changed=true
 if icon_changed:opponent_button.queue_redraw()
 opponent_button.visible=not view.replay_view() and not view.spectator_view()
 opponent_button.disabled=other_popup() or view.tutorial_runtime!=null and (not view.tutorial_controls_enabled or view.tutorial_runtime.playing_sequence())
 opponent_button.set_pressed_no_signal(view.host.show_opponent_emotes)
 opponent_button.tooltip_text="点击关闭对方表情" if view.host.show_opponent_emotes else "点击开启对方表情"
 if opponent_emotes_hidden():remove_bubble(1-view.local_seat)
 if is_instance_valid(wheel):
  if not available():close_wheel()
  else:position_wheel()
 var now=Time.get_ticks_msec()
 for who in bubbles.keys():
  var bubble=bubbles[who]
  if now>=int(expires[who]):
   remove_bubble(who);continue
  var placement=bubble_layout(who,bubble.size)
  bubble.position=placement.position;bubble.set_tip_x(placement.tip_x)
  bubble.modulate.a=minf(1.0,float(int(expires[who])-now)/300.0)

func open_wheel():
 if is_instance_valid(wheel):close_wheel();return
 if not available():return
 shade=Control.new();shade.name="LeaderEmoteDismiss"
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.mouse_filter=Control.MOUSE_FILTER_STOP;shade.z_index=210;add_child(shade)
 wheel=Wheel.new();shade.add_child(wheel)
 wheel.selected.connect(send);wheel.dismissed.connect(close_wheel)
 position_wheel();wheel.grab_focus()

func position_wheel():
 var safe=view.responsive.safe
 var extent=minf(360 if view.is_android else 330,minf(safe.size.x,safe.size.y)-16)
 wheel.size=Vector2.ONE*extent
 var origin=Vector2(button.position.x+button.size.x+12,button.position.y+button.size.y*0.5-extent*0.5)
 wheel.position=Vector2(clampf(origin.x,safe.position.x+8,safe.end.x-extent-8),clampf(origin.y,safe.position.y+8,safe.end.y-extent-8))

func close_wheel():
 if is_instance_valid(shade):
  shade.hide();shade.queue_free()
 shade=null;wheel=null;entry_finger=-1;entry_control=null

func send(kind: String):
 if not available():close_wheel();return
 close_wheel()
 var error=view.engine.send_emote(view.local_seat,kind)
 if not error.is_empty():view.message=error
 view.render();refresh()

func handle(event: InputEvent) -> bool:
 if is_instance_valid(wheel) and not available():close_wheel()
 var pointer=event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag
 if is_instance_valid(wheel):
  if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
   close_wheel();get_viewport().set_input_as_handled();return true
  if pointer:
   if event is InputEventMouse and event.device==-1:
    get_viewport().set_input_as_handled();return true
   var at=wheel.make_input_local(event).position
   if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and not wheel._has_point(at):
    close_wheel();get_viewport().set_input_as_handled();return true
   if event is InputEventScreenTouch or event is InputEventScreenDrag:
    wheel._gui_input(wheel.make_input_local(event))
    view.suppress_touch_mouse_until=Time.get_ticks_msec()+250;view.suppress_touch_mouse_point=event.position
    get_viewport().set_input_as_handled()
  # Focused wheel receives keyboard/mouse GUI events; battle input stops here.
  return true
 for entry in [button,opponent_button]:
  if not entry.visible or entry==opponent_button and entry.disabled:continue
  if event is InputEventMouse and entry.get_global_rect().has_point(event.position):
   if event.device==-1:get_viewport().set_input_as_handled()
   # Let real mouse input reach the button, without running battlefield input.
   return true
 if event is InputEventScreenTouch:
  if event.pressed and entry_finger==-1:
   for entry in [button,opponent_button]:
    if entry.visible and not (entry==opponent_button and entry.disabled) and entry.get_global_rect().has_point(event.position):
     entry_finger=event.index;entry_control=entry;break
  if event.index==entry_finger:
   if not event.pressed:
    var target=entry_control
    entry_finger=-1
    entry_control=null
    if not event.canceled and is_instance_valid(target) and target.visible and not target.disabled and target.get_global_rect().has_point(event.position):
     if target==button:open_wheel()
     else:toggle_opponent_emotes()
   view.suppress_touch_mouse_until=Time.get_ticks_msec()+250;view.suppress_touch_mouse_point=event.position
   get_viewport().set_input_as_handled();return true
 if event is InputEventScreenDrag and event.index==entry_finger:
  get_viewport().set_input_as_handled();return true
 return false

func consume(events: Array) -> Array:
 refresh()
 var remaining=[]
 for event in events:
  if event.get("emote",false) or event.get("type","")=="emote":show_event(event)
  else:remaining.append(event)
 return remaining

func show_event(event: Dictionary):
 var who=int(event.get("owner",-1));var kind=str(event.get("kind",""))
 if who not in [0,1] or not Profiles.DEFAULT_LINES.has(kind):return
 var key=str(who)+":"+str(event.get("serial",0))
 if seen.has(key):return
 seen[key]=true
 if seen.size()>256:seen.erase(seen.keys()[0])
 # Consume muted events too, so reconnect snapshots cannot replay them later.
 if who!=view.local_seat and opponent_emotes_hidden():return
 # A spectator's seat sets the camera perspective; both players are public speakers.
 if not view.spectator_view() and who==view.local_seat and not enabled():return
 var line=str(event.get("text",Profiles.DEFAULT_LINES[kind])).strip_edges().substr(0,120)
 if line.is_empty():return
 if is_instance_valid(bubbles.get(who)):bubbles[who].queue_free()
 var bubble=Bubble.new();add_child(bubble);bubble.z_index=95
 bubble.name="LeaderEmoteBubble"+str(who)
 if view.is_android:bubble.size=Vector2(320,88)
 var leader_id=str(event.get("leader_id",Profiles.profile(view.engine,who).get("leader_id","")))
 bubble.configure(line,kind,who==view.local_seat,leader_id=="character-fdn-026")
 bubbles[who]=bubble;expires[who]=Time.get_ticks_msec()+DISPLAY_MS
 speakers[who]=int(event.get("leader_uid",Profiles.profile(view.engine,who).get("leader_uid",0)))
 var placement=bubble_layout(who,bubble.size)
 bubble.position=placement.position;bubble.set_tip_x(placement.tip_x)

func bubble_target(who: int) -> Rect2:
 var uid=int(speakers.get(who,Profiles.profile(view.engine,who).get("leader_uid",0)))
 var leader=view.engine.find_card(uid)
 if leader.is_empty():leader=view.engine.players[who].leader
 if leader.get("zone","") not in ["leader","field"]:return Rect2()
 var visual=view.table.visuals.get("card_"+str(leader.uid))
 if is_instance_valid(visual):return view.projected_card_rect(visual)
 if leader.zone=="leader":return Rect2(view.project(view.table.zone_position("leader",who))-Vector2(24,32),Vector2(48,64))
 # A paged-out unit has no screen card; point at its battlefield page control.
 var group=view.table.field_group(leader)
 var pager=view.zone_pagers.get(group+str(leader.owner),{})
 if is_instance_valid(pager.get("root")):return pager.root.get_rect()
 var bounds=view.table.zone_page_bounds(leader.owner,group)
 var point=view.project(Vector3(bounds.get_center().x,0.035,bounds.get_center().y))
 return Rect2(point-Vector2(24,32),Vector2(48,64))

func bubble_layout(who: int,dimensions: Vector2) -> Dictionary:
 var safe=view.responsive.safe.grow(-8)
 var target=bubble_target(who);var down=who==view.local_seat
 var fallback=target.size==Vector2.ZERO
 var anchor=Vector2(view.HAND.get_center().x,view.HAND.position.y-8 if down else safe.position.y+90)
 if not fallback:anchor=Vector2(target.get_center().x,target.position.y if down else target.end.y)
 var origin=Vector2(anchor.x-dimensions.x*0.5,anchor.y-dimensions.y if down else anchor.y)
 origin.x=clampf(origin.x,safe.position.x,safe.end.x-dimensions.x)
 origin.y=clampf(origin.y,safe.position.y,safe.end.y-dimensions.y)
 return {"position":origin,"tip_x":anchor.x-origin.x,"target":target,"fallback":fallback}

func reset():
 close_wheel()
 for bubble in bubbles.values():
  if is_instance_valid(bubble):bubble.queue_free()
 bubbles.clear();expires.clear();speakers.clear();seen.clear();observed_serial=0

func covers(rect: Rect2) -> bool:
 for bubble in bubbles.values():
  if is_instance_valid(bubble) and bubble.visible and bubble.get_global_rect().intersects(rect):return true
 return false
