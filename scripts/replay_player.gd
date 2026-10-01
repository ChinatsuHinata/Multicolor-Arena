extends Node
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
 dock.add_theme_stylebox_override("panel",m.panel_style(true))
 var column=VBoxContainer.new();dock.add_child(column)
 column.add_theme_constant_override("separation",int(m.gap))
 var progress_row=HBoxContainer.new();column.add_child(progress_row)
 progress_row.add_theme_constant_override("separation",int(m.gap))
 progress=Label.new();progress.name="ReplayProgress";progress_row.add_child(progress)
 progress.add_theme_color_override("font_color",app.GOLD)
 progress.add_theme_font_size_override("font_size",m.body)
 progress.clip_text=true
 progress.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 slider=HSlider.new();slider.name="ReplaySlider";progress_row.add_child(slider)
 slider.custom_minimum_size.y=m.hit
 slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 slider.min_value=0;slider.max_value=archive.frames.size()-1;slider.step=1
 slider.value_changed.connect(func(value):if not updating:seek(int(value)))
 var actions=HBoxContainer.new();actions.name="ReplayActions";column.add_child(actions)
 actions.add_theme_constant_override("separation",int(m.gap))
 var add_action=func(caption: String,action: Callable,accent: bool=false) -> Button:
  var result=app.button(actions,caption,Rect2(),action,accent)
  m.button(result)
  result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  return result
 add_action.call("上一步",func():seek(maxi(0,index-1)))
 play_button=add_action.call("播放",func():playing=not playing;update_controls(),true)
 add_action.call("下一步",func():seek(mini(archive.frames.size()-1,index+1)))
 var rates=OptionButton.new();rates.name="ReplaySpeed";actions.add_child(rates)
 for title in ["0.5 倍速","1 倍速","2 倍速","4 倍速"]:rates.add_item(title)
 rates.selected=1;rates.item_selected.connect(func(i):speed=[0.5,1.0,2.0,4.0][i])
 m.button(rates);rates.custom_minimum_size.x=maxf(m.hit,m.body*5)
 rates.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_action.call("返回回放列表",func():app.replays())
 layout_controls()

func layout_controls():
 if not app.is_android or not is_instance_valid(dock) or not is_instance_valid(app.duel_view):return
 var m=app.ui_metrics
 var battle=app.duel_view.responsive
 var left=battle.toolbar_rect.position.x
 var width=battle.back_rect.position.x-m.gap-left
 dock.add_theme_stylebox_override("panel",m.panel_style(true))
 var column=dock.get_child(0) as VBoxContainer
 column.add_theme_constant_override("separation",int(m.gap))
 (column.get_child(0) as HBoxContainer).add_theme_constant_override("separation",int(m.gap))
 (column.get_child(1) as HBoxContainer).add_theme_constant_override("separation",int(m.gap))
 progress.add_theme_font_size_override("font_size",m.body)
 progress.custom_minimum_size.x=minf(width*0.42,m.body*17.0)
 slider.custom_minimum_size.y=m.hit
 for control in dock.find_children("*","BaseButton",true,false):
  m.button(control)
  if control is OptionButton:control.custom_minimum_size.x=maxf(m.hit,m.body*5)
 dock.position=Vector2(left,battle.log_rect.end.y+m.gap)
 dock.size=Vector2(maxf(1,width),m.padding*2+m.hit*2+m.gap)
func can_act(_in_match: bool=false) -> bool:return false
func ended() -> bool:return false
func submit(_command: Dictionary) -> String:return "回放只供查看"
func latency_text() -> String:return ""
func connection_status() -> String:return "回放 · "+("双方手牌可见" if archive.metadata.get("hands","")=="both" else "公开视角" if int(archive.metadata.get("seat",0))<0 else room.get("names",["玩家","玩家"])[seat]+"视角")
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
 progress.text=("回放 · 第 %d 局 · 第 %d 回合 · %d / %d" if app.is_android else "回放 · 第 %d 局\n第 %d 回合 · %d / %d") % [archive.frames[index].round,archive.frames[index].turn,index+1,archive.frames.size()]
 if room.get("status","")=="complete":
  progress.text="整场结束 · %d : %d\n%s获胜" % [room.scores[0],room.scores[1],room.names[room.winner]] if room.get("winner",-1)>=0 else "对局结束"
  progress.tooltip_text=room.get("end_reason",progress.text)
 else:progress.tooltip_text=""
 play_button.text="暂停" if playing else "播放"
 updating=true;slider.value=index;updating=false
func _process(delta):
 if is_instance_valid(controls) and is_instance_valid(app.duel_view):controls.visible=not app.duel_view.history_open and not app.duel_view.modal
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
