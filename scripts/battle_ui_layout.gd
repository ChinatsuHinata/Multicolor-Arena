extends RefCounted
## Screen-space HUD regions; gameplay and the 3D board stay in duel_view/table.
var view
var metrics
var safe=Rect2()
var enemy_life=Rect2()
var own_life=Rect2()
var toolbar_rect=Rect2()
var log_rect=Rect2()
var action_rect=Rect2()
var back_rect=Rect2()
var palette_rect=Rect2()
var choice_rect=Rect2()
var action_column: VBoxContainer
var palette_row: HBoxContainer
var toolbar: HBoxContainer

func measure(owner_view):
 view=owner_view;metrics=view.host.ui_metrics;safe=metrics.safe
 if not view.is_android:
  view.STAGE=Rect2(0,0,1600,900)
  view.HAND=Rect2(246,663,1108,232)
  view.PROMPT=Rect2(310,605,1000,37)
  view.NOTICE=Rect2(307,639,995,28)
  view.INSPECTION=Rect2(16,100,218,660)
  view.SIDEBAR=Rect2(1366,100,218,660)
  view.OPPONENT_HAND_COUNT=Rect2(1070,78,170,30)
  enemy_life=Rect2(18,18,218,61)
  own_life=Rect2(18,793,218,70)
  log_rect=Rect2(320,53,990,26)
  action_rect=Rect2(1330,675,237,214)
  view.ANDROID_ACTION_X=1330
  view.ANDROID_ACTION_WIDTH=237
  view.ANDROID_ACTION_CONFIRM_Y=770
  view.ANDROID_ACTION_FOOTER_Y=853
  view.ANDROID_ACTION_FOOTER_HEIGHT=36
  choice_rect=Rect2(250,60,1050,380)
  return
 var life_width=maxf(180,metrics.body*6.5)
 var action_width=maxf(244,metrics.body*9.5)
 var g=metrics.gap
 var hit=metrics.hit
 enemy_life=Rect2(safe.position,Vector2(life_width,hit))
 own_life=Rect2(safe.position.x,safe.end.y-hit,life_width,hit)
 toolbar_rect=Rect2(enemy_life.end.x+g,safe.position.y,safe.size.x-life_width-g,hit)
 log_rect=Rect2(enemy_life.end.x+g,enemy_life.end.y+g,safe.size.x-life_width-action_width-g*2,metrics.body*1.5)
 back_rect=Rect2(safe.end.x-action_width,safe.end.y-hit,action_width,hit)
 action_rect=Rect2(back_rect.position.x,back_rect.position.y-hit*3-g*3,action_width,hit*3+g*2)
 var hand_height=242.0 if view.is_android else 228.0
 view.STAGE=Rect2(Vector2.ZERO,view.host.get_viewport_rect().size)
 view.HAND=Rect2(enemy_life.end.x+g,safe.end.y-hand_height,back_rect.position.x-enemy_life.end.x-g*2,hand_height)
 view.PROMPT=Rect2(view.HAND.position.x,view.HAND.position.y-metrics.body*1.7-g,view.HAND.size.x,metrics.body*1.7)
 view.NOTICE=Rect2(view.HAND.position.x,view.PROMPT.position.y-metrics.body*1.6,view.HAND.size.x,metrics.body*1.6)
 view.INSPECTION=Rect2(safe.position.x,enemy_life.end.y+g,life_width,own_life.position.y-enemy_life.end.y-g*2)
 view.SIDEBAR=Rect2(back_rect.position.x,enemy_life.end.y+g,action_width,action_rect.position.y-enemy_life.end.y-g*2)
 view.OPPONENT_HAND_COUNT=Rect2(back_rect.position.x,enemy_life.end.y+g,action_width,metrics.body*1.5)
 view.TOUCH_CAMERA_AREA=Rect2(view.HAND.position.x,log_rect.end.y+g,view.HAND.size.x,view.NOTICE.position.y-log_rect.end.y-g*2)
 choice_rect=Rect2(view.HAND.position.x,toolbar_rect.end.y+g,back_rect.position.x-view.HAND.position.x-g,maxf(220,safe.get_center().y-toolbar_rect.end.y-g*2))
 var palette_width=minf(1020,safe.size.x-life_width-g)
 var palette_y=choice_rect.end.y+g
 var palette_height=minf(330,maxf(210,safe.end.y-palette_y-hit-g))
 palette_rect=Rect2(safe.get_center().x-palette_width/2,palette_y,palette_width,palette_height)
 view.ANDROID_PALETTE_RECT=palette_rect
 view.ANDROID_ACTION_X=back_rect.position.x
 view.ANDROID_ACTION_WIDTH=back_rect.size.x
 view.ANDROID_ACTION_CONFIRM_Y=back_rect.position.y-hit-g
 view.ANDROID_ACTION_FOOTER_Y=back_rect.position.y
 view.ANDROID_ACTION_FOOTER_HEIGHT=hit
 view.ANDROID_BACK_SWIPE_EDGE_X=safe.end.x-hit

func button(parent: Node,caption: String,action: Callable,accent: bool=false) -> Button:
 var result=view.btn(caption,Rect2(),action,accent,parent)
 metrics.button(result)
 return result

func begin_frame():
 if not view.is_android:
  desktop_frame()
  return
 toolbar=HBoxContainer.new();view.hud.add_child(toolbar);toolbar.name="BattleToolbar"
 toolbar.position=toolbar_rect.position;toolbar.size=toolbar_rect.size
 var phase=Label.new();phase.name="BattlePhase";toolbar.add_child(phase)
 phase.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 phase.text="第 %d 回合 · %s · %s" % [view.engine.turn,view.player_caption(view.engine.active),view.phase_names[view.engine.phase]]
 if view.network_session!=null and view.network_session.ended():phase.text="连接中断，对局结束"
 phase.add_theme_font_size_override("font_size",metrics.body+2);phase.add_theme_color_override("font_color",view.host.GOLD)
 phase.clip_text=true;phase.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 for mode in [view.ResponseMode.ON,view.ResponseMode.OFF]:
  var toggle=button(toolbar,"全响应" if mode==view.ResponseMode.ON else "不响应",func():view.set_response_mode(view.ResponseMode.DEFAULT if view.response_mode==mode else mode),view.response_mode==mode)
  toggle.toggle_mode=true;toggle.set_pressed_no_signal(view.response_mode==mode)
 var observe_slot=Control.new();observe_slot.custom_minimum_size=Vector2(metrics.body*5.6,metrics.hit);toolbar.add_child(observe_slot)
 observe_slot.resized.connect(func():
  if is_instance_valid(view.observe_button):
   view.observe_button.position=observe_slot.global_position
   view.observe_button.size=observe_slot.size)
 observe_slot.item_rect_changed.connect(func():
  if is_instance_valid(view.observe_button):view.observe_button.position=observe_slot.global_position)
 var more=MenuButton.new();more.name="BattleTools";more.text="菜单";toolbar.add_child(more);metrics.button(more)
 var actions=[["设置",view.settings_menu],["对局记录",view.open_history],["视角复原",view.reset_camera_view],["单位自动排序",view.sort_units]]
 if view.is_android:actions.append(["操作说明",view.open_android_help])
 if is_instance_valid(view.chat_panel):actions.append(["聊天",func():view.chat_panel.visible=not view.chat_panel.visible])
 for i in range(actions.size()):more.get_popup().add_item(actions[i][0],i)
 more.get_popup().id_pressed.connect(func(id):actions[id][1].call())
 action_column=VBoxContainer.new();action_column.name="PhaseActions";view.hud.add_child(action_column)
 action_column.position=action_rect.position;action_column.size=action_rect.size;action_column.alignment=BoxContainer.ALIGNMENT_END
 action_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 action_column.set_meta("choice_widget",true)
 palette_row=HBoxContainer.new();view.hud.add_child(palette_row);palette_row.name="PaletteToolbar"
 palette_row.position=Vector2(safe.position.x,enemy_life.end.y+metrics.gap)
 palette_row.size=Vector2(enemy_life.size.x,metrics.hit*2+metrics.gap)
 # The left rail has two vertically stacked, generous palette targets.
 if view.is_android:
  palette_row.queue_free()
  palette_row=null

func add_phase_action(control: Button):
 control.reparent(action_column)
 control.position=Vector2.ZERO;control.size=Vector2.ZERO
 if view.is_android:
  metrics.button(control)
  control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 else:control.custom_minimum_size=Vector2(237,49)

func palette_toggle(who: int,index: int,caption: String) -> Button:
 var rect=Rect2(safe.position.x,enemy_life.end.y+metrics.gap+index*(metrics.hit+metrics.gap),enemy_life.size.x,metrics.hit)
 var result=view.host.button(view.hud,caption,rect,func():view.toggle_android_palette(who),view.android_palette_owner==who)
 metrics.button(result)
 return result

func position_persistent():
 if not view.is_android:return
 if is_instance_valid(view.android_back_button):
  var card_search_open=is_instance_valid(view.modal_root) and view.modal_root.get_meta("card_search_topmost",false)
  view.android_back_button.position=Vector2(back_rect.position.x,safe.position.y) if card_search_open else back_rect.position
  view.android_back_button.size=back_rect.size;metrics.button(view.android_back_button)
 if is_instance_valid(view.observe_button):metrics.button(view.observe_button)
 if is_instance_valid(view.reset_view_button):view.reset_view_button.hide()
 if is_instance_valid(view.stack_panel):
  view.stack_panel.position=view.SIDEBAR.position+Vector2(0,metrics.body*1.5+metrics.gap)
  view.stack_panel.size=Vector2(view.SIDEBAR.size.x,maxf(120,view.SIDEBAR.size.y-metrics.body*1.5-metrics.gap))
  view.stack_panel.scroll.size=Vector2(view.SIDEBAR.size.x,view.stack_panel.size.y-36)
 if is_instance_valid(view.inspection) and not view.is_android:
  view.inspection.position=view.INSPECTION.position;view.inspection.size=view.INSPECTION.size

func desktop_frame():
 action_column=VBoxContainer.new();action_column.name="PhaseActions";view.hud.add_child(action_column)
 action_column.position=action_rect.position;action_column.size=action_rect.size
 action_column.alignment=BoxContainer.ALIGNMENT_END
 action_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 action_column.set_meta("choice_widget",true)
 for mode in [view.ResponseMode.ON,view.ResponseMode.OFF]:
  var toggle=view.btn("全响应" if mode==view.ResponseMode.ON else "不响应",Rect2(1040+(mode-1)*115,12,108,38),func():view.set_response_mode(view.ResponseMode.DEFAULT if view.response_mode==mode else mode),view.response_mode==mode)
  toggle.toggle_mode=true;toggle.set_pressed_no_signal(view.response_mode==mode)
 view.txt("连接中断，对局结束" if view.network_session!=null and view.network_session.ended() else "第 %d 回合  ·  %s  ·  %s" % [view.engine.turn,view.player_caption(view.engine.active),view.phase_names[view.engine.phase]],Rect2(410 if not view.player_buffs(1-view.local_seat).is_empty() else 310,12,630,42),23,view.host.GOLD)
 view.btn("设置",Rect2(1460,12,116,40),view.settings_menu)
 view.btn("对局记录",Rect2(1310,99,266,40),view.open_history)
 view.sort_units_button=view.btn("单位自动排序",Rect2(1270,12,164,40),view.sort_units)
 view.sort_units_button.tooltip_text="拖动战场单位调整位置；点击后按占格、颜色值和同名单位排序。"
 if is_instance_valid(view.chat_panel):view.btn("聊天",Rect2(1310,145,266,38),func():view.chat_panel.visible=not view.chat_panel.visible)
 view.txt("A  攻击",Rect2(18,865,103,17),13,view.host.MUTED)
 view.txt("G  墓地",Rect2(126,865,110,17),13,view.host.MUTED)
 view.txt("Q  不响应/继续",Rect2(18,882,103,17),13,view.host.MUTED)
 view.txt("H  除外区",Rect2(126,882,110,17),13,view.host.MUTED)
