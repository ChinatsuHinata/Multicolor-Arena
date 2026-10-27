extends Node
const PlayerNameDisplay=preload("res://scripts/player_name_display.gd")
signal changed
signal error_raised(message: String)
var app
var archive
var seat=0
var read_only=true
var replay_mode=true
var connected=true
var paused=false
var snapshots=[]
var latest_snapshot={}
var room={}
var local_game_id=""
var index=0
var playing=false
var speed=1.0
var elapsed=0.0
var controls: Control
var dock: PanelContainer
var progress: Label
var play_button: Button
var slider: HSlider
var updating=false
var collapsed=false
var restore_button: Button
var speed_button: Button
var control_finger=-1
var control_touch_button: Button
var control_touch_origin=Vector2.ZERO
var control_touch_cancelled=false
var control_scrubbing=false
var control_mouse_down=false
var control_mouse_suppressed_until=0
var training
var training_button: Button
var training_editor
func build(parent,data,path: String=""):
 app=parent;archive=data;seat=maxi(0,int(archive.metadata.get("seat",0)))
 if not app.is_android:
  training=preload("res://scripts/ai/replay_training.gd").new();training.setup(archive,path)
 seek(0)
 controls=Control.new();controls.mouse_filter=Control.MOUSE_FILTER_IGNORE;app.screen.add_child(controls)
 if app.is_android:
  controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  build_android_controls()
  update_training_button()
  update_controls()
  return
 controls.size=Vector2(1600,900)
 app.box(controls,Rect2(1360,646,218,249))
 progress=app.label(controls,"",Rect2(1372,650,196,46),15,app.GOLD)
 progress.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 play_button=app.button(controls,"播放",Rect2(1372,702,196,32),func():playing=not playing;update_controls(),true)
 app.button(controls,"上一步",Rect2(1372,744,92,32),func():seek(maxi(0,index-1)))
 app.button(controls,"下一步",Rect2(1474,744,94,32),func():seek(mini(archive.frames.size()-1,index+1)))
 slider=HSlider.new();slider.position=Vector2(1374,783);slider.size=Vector2(190,22);slider.min_value=0;slider.max_value=archive.frames.size()-1;slider.step=1;controls.add_child(slider)
 slider.value_changed.connect(func(value):if not updating:seek(int(value)))
 var rates=OptionButton.new();rates.position=Vector2(1372,817);rates.size=Vector2(196,32)
 for text in ["0.5 倍速","1 倍速","2 倍速","4 倍速"]:rates.add_item(text)
 rates.selected=1;rates.item_selected.connect(func(i):speed=[0.5,1.0,2.0,4.0][i]);controls.add_child(rates)
 app.button(controls,"返回回放列表",Rect2(1372,859,196,32),func():app.replays())
 training_button=app.button(controls,"标注当前步骤",Rect2(1372,602,196,36),open_training,true)
 update_training_button()
 update_controls()

func build_android_controls():
 var m=app.ui_metrics
 dock=PanelContainer.new();dock.name="ReplayDock";controls.add_child(dock)
 var row=HBoxContainer.new();row.name="ReplayActions";dock.add_child(row)
 progress=Label.new();progress.name="ReplayProgress";row.add_child(progress)
 progress.add_theme_color_override("font_color",app.GOLD)
 progress.clip_text=true;progress.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 slider=HSlider.new();slider.name="ReplaySlider";row.add_child(slider)
 slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 slider.min_value=0;slider.max_value=archive.frames.size()-1;slider.step=1
 slider.value_changed.connect(func(value):if not updating and not control_scrubbing:seek(int(value)))
 var add_action=func(caption: String,node_name: String,action: Callable,accent: bool=false) -> Button:
  var result=app.button(row,caption,Rect2(),action,accent)
  result.name=node_name
  m.button(result)
  return result
 var previous=add_action.call("上步","ReplayPrevious",func():seek(maxi(0,index-1)))
 previous.tooltip_text="上一条回放记录"
 play_button=add_action.call("播放","ReplayPlay",func():playing=not playing;update_controls(),true)
 var next=add_action.call("下步","ReplayNext",func():seek(mini(archive.frames.size()-1,index+1)))
 next.tooltip_text="下一条回放记录"
 speed_button=add_action.call("1×","ReplaySpeed",cycle_speed)
 speed_button.tooltip_text="切换速度：0.5 / 1 / 2 / 4 倍"
 var leave=add_action.call("回放列表","ReplayReturn",func():app.replays())
 leave.tooltip_text="返回回放列表"
 add_action.call("收起","ReplayCollapse",toggle_controls)
 restore_button=app.button(controls,"展开回放",Rect2(),toggle_controls,true)
 restore_button.name="ReplayRestore"
 layout_controls()

func cycle_speed():
 var rates=[0.5,1.0,2.0,4.0]
 speed=rates[(rates.find(speed)+1)%rates.size()]
 speed_button.text=str(speed).trim_suffix(".0")+"×"

func android_bottom_inset() -> float:
 if not app.is_android or collapsed:return 0.0
 return app.ui_metrics.hit+app.ui_metrics.gap*3

func toggle_controls():
 collapsed=not collapsed
 if is_instance_valid(app.duel_view):app.duel_view.resize_world()
 layout_controls()

func layout_controls():
 if not app.is_android or not is_instance_valid(dock) or not is_instance_valid(app.duel_view):return
 var m=app.ui_metrics
 var compact=m.panel_style(true)
 compact.set_content_margin_all(m.gap)
 dock.add_theme_stylebox_override("panel",compact)
 var row=dock.get_child(0) as HBoxContainer
 row.add_theme_constant_override("separation",int(m.gap))
 progress.add_theme_font_size_override("font_size",m.small)
 progress.custom_minimum_size.x=m.small*7.0
 slider.custom_minimum_size=Vector2(m.hit*2,m.hit)
 for control in row.get_children():
  if not control is Button:continue
  m.button(control)
  control.custom_minimum_size.x=maxf(m.hit,control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,m.small).x+m.gap*2)
  control.add_theme_font_size_override("font_size",m.small)
  control.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
 var height=m.hit+m.gap*2
 dock.position=Vector2(m.safe.position.x,m.safe.end.y-height)
 dock.size=Vector2(m.safe.size.x,height)
 dock.visible=not collapsed
 m.button(restore_button)
 restore_button.size=Vector2(maxf(m.hit*2.5,restore_button.get_combined_minimum_size().x),m.hit)
 restore_button.position=m.safe.end-restore_button.size
 restore_button.visible=collapsed

func controls_at(point: Vector2) -> bool:
 if not is_instance_valid(controls) or not controls.is_visible_in_tree():return false
 for control in [dock,restore_button]:
  if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(point):return true
 return false

func scrub_to(point: Vector2):
 var rect=slider.get_global_rect()
 var inset=slider.get_theme_icon("grabber").get_width()*0.5
 var fraction=clampf((point.x-rect.position.x-inset)/maxf(1,rect.size.x-inset*2),0.0,1.0)
 updating=true;slider.value=roundi(lerpf(slider.min_value,slider.max_value,fraction));updating=false
 progress.text="%d/%d" % [int(slider.value)+1,archive.frames.size()]

func android_controls_blocked() -> bool:
 if not is_instance_valid(app.duel_view):return true
 var view=app.duel_view
 if view.modal or view.history_open or view.debug_open or app.menu_popup_open():return true
 if is_instance_valid(view.android_battle_menu_root) and view.android_battle_menu_root.is_visible_in_tree():return true
 for child in app.get_children():
  if child is AcceptDialog and child.visible:return true
 return false

func cancel_controls_touch():
 control_finger=-1;control_touch_button=null;control_mouse_down=false
 if control_scrubbing:
  control_scrubbing=false;update_controls()

func handle_controls_input(event: InputEvent) -> bool:
 if not app.is_android or not is_instance_valid(controls):return false
 # Check live overlay state as well as visibility: a menu can open before the
 # next process frame, and its touch must never reach controls beneath it.
 if android_controls_blocked():
  controls.hide();cancel_controls_touch();return false
 if not controls.is_visible_in_tree():return false
 if event is InputEventMouse:
  if event.device==-1 and Time.get_ticks_msec()<control_mouse_suppressed_until:
   get_viewport().set_input_as_handled();return true
  var owned=control_mouse_down or controls_at(event.position)
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed and owned:control_mouse_down=true
   elif not event.pressed:control_mouse_down=false
  # Real mouse events continue into native GUI; only the battlefield skips them.
  return owned
 if event is InputEventScreenTouch and event.pressed:
  if control_finger>=0:
   if controls_at(event.position):get_viewport().set_input_as_handled();return true
   return false
  if not controls_at(event.position):return false
  control_finger=event.index;control_touch_origin=event.position;control_touch_cancelled=false
  control_touch_button=null;control_scrubbing=not collapsed and slider.get_global_rect().has_point(event.position)
  if control_scrubbing:
   playing=false;scrub_to(event.position);play_button.text="播放"
  else:
   for control in [restore_button]+dock.find_children("*","Button",true,false):
    if control.is_visible_in_tree() and not control.disabled and control.get_global_rect().has_point(event.position):control_touch_button=control;break
  control_mouse_suppressed_until=Time.get_ticks_msec()+300
  get_viewport().set_input_as_handled();return true
 if event is InputEventScreenDrag and event.index==control_finger:
  if control_scrubbing:scrub_to(event.position)
  elif event.position.distance_to(control_touch_origin)>app.ui_metrics.hit*0.3:control_touch_cancelled=true
  control_mouse_suppressed_until=Time.get_ticks_msec()+300
  get_viewport().set_input_as_handled();return true
 if event is InputEventScreenTouch and not event.pressed and event.index==control_finger:
  control_finger=-1;control_mouse_suppressed_until=Time.get_ticks_msec()+300
  var action=control_touch_button;control_touch_button=null
  var scrubbing=control_scrubbing;control_scrubbing=false
  get_viewport().set_input_as_handled()
  if scrubbing:
   if event.canceled:update_controls()
   else:seek(int(slider.value))
  elif not event.canceled and not control_touch_cancelled and is_instance_valid(action) and action.is_visible_in_tree() and not action.disabled and action.get_global_rect().has_point(event.position):action.pressed.emit()
  return true
 return false
func can_act(_in_match: bool=false) -> bool:return false
func ended() -> bool:return false
func submit(_command: Dictionary) -> String:return "回放只供查看"
func latency_text() -> String:return ""
func connection_status() -> String:return "回放 · "+("双方手牌可见" if archive.metadata.get("hands","")=="both" else "公开视角" if int(archive.metadata.get("seat",0))<0 else PlayerNameDisplay.caption(room.get("names",["玩家","玩家"])[seat])+"视角")
func pop_snapshot() -> Dictionary:
 var packet=snapshots.pop_front();local_game_id=packet.game_id;return packet
func seek(value: int):
 if training_editor!=null and training_editor.is_open():
  training_editor.close()
  if training_editor!=null:return
 playing=false;elapsed=0;index=value
 var packet=archive.frame(index)
 if packet.is_empty():error_raised.emit("回放片段损坏");return
 packet.recovery=true;packet.projection.state.presentation_events=[]
 room=packet.room;latest_snapshot=packet;snapshots=[packet]
 if is_instance_valid(app.duel_view) and not app.duel_view.is_queued_for_deletion():app.duel_view.get_parent().remove_child(app.duel_view);app.duel_view.queue_free()
 app.duel_view=preload("res://scripts/duel_view.gd").new();app.screen.add_child(app.duel_view)
 app.duel_view.begin(app,{},{},0,0,self)
 if is_instance_valid(controls):app.screen.move_child(controls,-1)
 update_controls()
 layout_controls()
func update_controls():
 if not is_instance_valid(progress):return
 var detail="回放 · 第 %d 局 · 第 %d 回合 · %d / %d" % [archive.frames[index].round,archive.frames[index].turn,index+1,archive.frames.size()]
 progress.text=("%d/%d" % [index+1,archive.frames.size()]) if app.is_android else "回放 · 第 %d 局\n第 %d 回合 · %d / %d" % [archive.frames[index].round,archive.frames[index].turn,index+1,archive.frames.size()]
 if room.get("status","")=="complete":
  var outcome="整场结束 · %d : %d\n%s获胜" % [room.scores[0],room.scores[1],PlayerNameDisplay.caption(room.names[room.winner])] if room.get("winner",-1)>=0 else "对局结束"
  if not app.is_android:progress.text=outcome
  detail=outcome+"\n"+PlayerNameDisplay.in_text(room.get("end_reason",""),room.get("names",[]))
 progress.tooltip_text=detail if app.is_android else PlayerNameDisplay.in_text(room.get("end_reason",""),room.get("names",[])) if room.get("status","")=="complete" else ""
 play_button.text="暂停" if playing else "播放"
 updating=true;slider.value=index;updating=false
func _process(delta):
 if is_instance_valid(controls) and is_instance_valid(app.duel_view):
  controls.visible=not android_controls_blocked() if app.is_android else not app.duel_view.history_open and not app.duel_view.modal
  if app.is_android and not controls.visible:cancel_controls_touch()
 if training_editor!=null and training_editor.is_open():playing=false;return
 if not playing or not snapshots.is_empty() or not is_instance_valid(app.duel_view):return
 if app.duel_view.revealing() or app.duel_view.table.is_animating() or app.duel_view.history_open:return
 if index+1>=archive.frames.size():playing=false;update_controls();return
 elapsed+=delta*speed
 var delay=clampf(float(archive.frames[index+1].time-archive.frames[index].time)/1000.0,0.25,3.0)
 if elapsed<delay:return
 elapsed=0;index+=1
 var packet=archive.frame(index)
 if packet.is_empty():playing=false;error_raised.emit("回放片段损坏");return
 if packet.game_id!=latest_snapshot.game_id:
  seek(index);playing=true
 else:
  room=packet.room;latest_snapshot=packet;snapshots.append(packet)
 update_controls()

func update_training_button():
 if not is_instance_valid(training_button):return
 training_button.visible=app.replay_training_mode
 training_button.text="标注当前步骤 · %d"%training.annotations.size() if not training.annotations.is_empty() else "标注当前步骤"
 layout_controls()

func open_training():
 if app.is_android or not app.replay_training_mode or training_editor!=null:return
 training_editor=preload("res://scripts/replay_training_editor.gd").new();training_editor.open(self)
