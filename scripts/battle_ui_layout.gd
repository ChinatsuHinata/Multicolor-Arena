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
var hand_toggle_rect=Rect2()
var hand_cards_rect=Rect2()
var action_column: VBoxContainer
var action_scroll: ScrollContainer
var notice_scroll: ScrollContainer
var notice_column: VBoxContainer
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
  view.OPPONENT_HAND_COUNT=Rect2(1366,76,218,62)
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
  measure_hand_controls()
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
 view.OPPONENT_HAND_COUNT=Rect2(back_rect.position.x,enemy_life.end.y+g,action_width,maxf(hit,metrics.body*2.5))
 view.TOUCH_CAMERA_AREA=Rect2(view.HAND.position.x,log_rect.end.y+g,view.HAND.size.x,view.NOTICE.position.y-log_rect.end.y-g*2)
 choice_rect=Rect2(view.HAND.position.x,toolbar_rect.end.y+g,back_rect.position.x-view.HAND.position.x-g,maxf(220,safe.get_center().y-toolbar_rect.end.y-g*2))
 var palette_left=enemy_life.end.x+g
 var palette_width=minf(1320,back_rect.position.x-g-palette_left)
 var palette_y=choice_rect.end.y+g
 var palette_height=minf(264,maxf(220,safe.end.y-palette_y-hit-g))
 palette_rect=Rect2(palette_left,palette_y,palette_width,palette_height)
 view.ANDROID_PALETTE_RECT=palette_rect
 view.ANDROID_ACTION_X=back_rect.position.x
 view.ANDROID_ACTION_WIDTH=back_rect.size.x
 view.ANDROID_ACTION_CONFIRM_Y=back_rect.position.y-hit-g
 view.ANDROID_ACTION_FOOTER_Y=back_rect.position.y
 view.ANDROID_ACTION_FOOTER_HEIGHT=hit
 view.ANDROID_BACK_SWIPE_EDGE_X=safe.end.x-hit
 measure_hand_controls()

func measure_hand_controls():
 if view.is_android:
  hand_toggle_rect=Rect2(safe.position.x,enemy_life.end.y+metrics.hit*2+metrics.gap*3,enemy_life.size.x,metrics.hit)
  hand_cards_rect=view.HAND
 else:
  var width=132.0
  hand_toggle_rect=Rect2(view.HAND.position+Vector2(0,17),Vector2(width,44))
  var inset=width+metrics.gap
  hand_cards_rect=Rect2(view.HAND.position+Vector2(inset,0),view.HAND.size-Vector2(inset,0))

func render_hand_controls():
 # Hand visibility is local UI state, available even to read-only spectators.
 var toggle=view.host.button(view.hud,"隐藏手牌" if view.hand_display_enabled else "显示手牌",hand_toggle_rect,func():view.set_hand_display(not view.hand_display_enabled),not view.hand_display_enabled)
 toggle.name="HandDisplayToggle"
 if view.is_android:metrics.button(toggle)
 toggle.tooltip_text="隐藏双方手牌区域" if view.hand_display_enabled else "显示双方手牌区域"
 var badge=view.host.box(view.hud,view.OPPONENT_HAND_COUNT,Color("#101e2b"),view.host.GOLD)
 badge.name="OpponentHandCount"
 badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var frame=view.host.style(Color("#101e2b"),view.host.GOLD)
 frame.set_border_width_all(2)
 badge.add_theme_stylebox_override("panel",frame)
 var inset=12.0
 var count_text=str(view.engine.players[1-view.local_seat].hand.size())
 var count_width=maxf(metrics.hit*0.85,(metrics.title+6)*count_text.length()*0.7+metrics.gap) if view.is_android else badge.size.x-94-inset*2
 var label_width=badge.size.x-inset*2-count_width
 var caption=view.txt("对方手牌",Rect2(inset,0,label_width,badge.size.y),metrics.body if view.is_android else 19,view.host.WHITE,badge)
 caption.name="OpponentHandCaption"
 caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var count=view.txt(count_text,Rect2(inset+label_width,0,count_width,badge.size.y),metrics.title+6 if view.is_android else 36,view.host.GOLD,badge)
 count.name="HandCountValue"
 count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 count.add_theme_font_size_override("font_size",metrics.title+6 if view.is_android else 36)

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
 var observe_slot=Control.new();observe_slot.name="ObserveSlot";observe_slot.custom_minimum_size=Vector2(metrics.body*5.6,metrics.hit);toolbar.add_child(observe_slot)
 observe_slot.resized.connect(func():
  if is_instance_valid(view.observe_button):
   view.observe_button.size=observe_slot.size
   view.observe_button.position=Vector2(back_rect.position.x-metrics.gap-view.observe_button.size.x,safe.position.y) if is_instance_valid(view.modal_root) else observe_slot.global_position)
 observe_slot.item_rect_changed.connect(func():
  if is_instance_valid(view.observe_button):view.observe_button.position=Vector2(back_rect.position.x-metrics.gap-view.observe_button.size.x,safe.position.y) if is_instance_valid(view.modal_root) else observe_slot.global_position)
 var more=button(toolbar,"菜单",view.open_tools_menu);more.name="BattleTools"
 action_scroll=ScrollContainer.new();action_scroll.name="PhaseActionScroll";view.hud.add_child(action_scroll)
 action_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 action_scroll.follow_focus=true;action_scroll.set_meta("choice_widget",true)
 action_column=VBoxContainer.new();action_column.name="PhaseActions";action_scroll.add_child(action_column)
 action_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 action_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 action_column.set_meta("choice_widget",true)
 notice_scroll=ScrollContainer.new();notice_scroll.name="RightChoiceNotices";view.hud.add_child(notice_scroll)
 notice_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 notice_scroll.set_meta("choice_widget",true)
 notice_column=VBoxContainer.new();notice_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;notice_scroll.add_child(notice_column)
 palette_row=HBoxContainer.new();view.hud.add_child(palette_row);palette_row.name="PaletteToolbar"
 palette_row.position=Vector2(safe.position.x,enemy_life.end.y+metrics.gap)
 palette_row.size=Vector2(enemy_life.size.x,metrics.hit*2+metrics.gap)
 # The left rail has two vertically stacked, generous palette targets.
 if view.is_android:
  palette_row.queue_free()
  palette_row=null

func tools_actions() -> Array:
 var actions=[["设置",view.settings_menu],["对局记录",view.open_history],["视角复原",view.reset_camera_view],["单位自动排序",view.sort_units]]
 if view.is_android:actions.append(["操作说明",view.open_android_help])
 if view.is_android and view.network_session!=null and not view.network_session.replay_mode and not view.network_session.read_only and view.network_session.room.get("undo_request",{}).is_empty():
  actions.append(["请求悔棋",func():view.network_session.room_action({"name":"undo_request"}),not view.network_session.can_act(true) or not view.network_session.room.get("undo_available",false) or not view.engine.stack.is_empty()])
 return actions

func add_phase_action(control: Button):
 control.reparent(action_column)
 control.position=Vector2.ZERO;control.size=Vector2.ZERO
 if view.is_android:
  metrics.button(control)
  control.custom_minimum_size=Vector2(0,metrics.hit)
  control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  var margins=control.get_theme_stylebox("normal").get_minimum_size()
  var text_height=control.get_theme_font("font").get_multiline_string_size(control.text,HORIZONTAL_ALIGNMENT_CENTER,back_rect.size.x-18-margins.x,metrics.button_font).y
  control.custom_minimum_size.y=maxf(metrics.hit,text_height+margins.y)
 else:control.custom_minimum_size=Vector2(237,49)

func palette_toggle(who: int,index: int,caption: String) -> Button:
 var rect=Rect2(safe.position.x,enemy_life.end.y+metrics.gap+index*(metrics.hit+metrics.gap),enemy_life.size.x,metrics.hit)
 var result=view.host.button(view.hud,caption,rect,func():view.toggle_android_palette(who),view.android_palette_owner==who)
 metrics.button(result)
 return result

func choice_popup_max_height(minimum_height: float=0) -> float:
 var bottom=safe.end.y-metrics.gap
 if view.android_palette_owner>=0:
  if palette_rect.position.y-metrics.gap-choice_rect.position.y<minimum_height:
   palette_rect.position.y=minf(safe.end.y-palette_rect.size.y,choice_rect.position.y+minimum_height+metrics.gap)
   view.ANDROID_PALETTE_RECT=palette_rect
  bottom=minf(bottom,palette_rect.position.y-metrics.gap)
 return maxf(0,bottom-choice_rect.position.y)

func wrapped_height(text: String,width: float,font_size: int) -> float:
 return view.host.get_theme_font("font").get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,maxf(1,width),font_size).y

func add_choice_notice(label: Label):
 label.reparent(notice_column);label.position=Vector2.ZERO;label.size=Vector2.ZERO
 label.custom_minimum_size=Vector2(0,wrapped_height(label.text,back_rect.size.x-18,metrics.small))
 label.add_theme_font_size_override("font_size",metrics.small)
 label.clip_text=false;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func dialog_content(panel: Panel,width: float,content_height: float,has_footer: bool=true) -> Dictionary:
 panel.size.x=minf(width,safe.size.x-24)
 panel.clip_contents=true
 var title=panel.get_node("DialogTitle") as Label
 title.add_theme_font_size_override("font_size",metrics.title)
 title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 title.position=Vector2(20,12)
 title.size=Vector2(panel.size.x-40,maxf(metrics.title*1.4,minf(metrics.title*2.8,wrapped_height(title.text,panel.size.x-40,metrics.title))))
 title.tooltip_text=title.text
 var top=title.position.y+title.size.y+metrics.gap
 var footer_height=metrics.hit+metrics.gap if has_footer else 0.0
 panel.size.y=minf(safe.size.y-24,top+maxf(metrics.hit,content_height)+footer_height+20)
 view.center_panel(panel)
 var scroll=ScrollContainer.new();scroll.name="ChoiceDialogScroll";panel.add_child(scroll)
 scroll.position=Vector2(20,top);scroll.size=Vector2(panel.size.x-40,panel.size.y-top-footer_height-20)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
 var body=VBoxContainer.new();body.name="ChoiceDialogBody";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 body.add_theme_constant_override("separation",int(metrics.gap))
 var footer: HBoxContainer
 if has_footer:
  footer=HBoxContainer.new();footer.name="ChoiceDialogFooter";panel.add_child(footer)
  footer.position=Vector2(20,panel.size.y-metrics.hit-16);footer.size=Vector2(panel.size.x-40,metrics.hit)
  footer.add_theme_constant_override("separation",int(metrics.gap));footer.alignment=BoxContainer.ALIGNMENT_END
 return {"scroll":scroll,"body":body,"footer":footer}

func choice_footer_button(footer: HBoxContainer,caption: String,action: Callable,accent: bool=false) -> Button:
 var result=view.btn(caption,Rect2(),action,accent,footer);metrics.button(result)
 result.custom_minimum_size.x=0;result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 return result

func choice_card_row(parent: Control,card: Dictionary,caption: String,action: Callable,width: float,enabled: bool=true) -> Control:
 var row=HBoxContainer.new();parent.add_child(row);row.add_theme_constant_override("separation",int(metrics.gap))
 var slot=Control.new();slot.custom_minimum_size=Vector2(132,184);row.add_child(slot)
 var tile=view.card_tile(slot,card,Rect2(0,0,132,184),action if enabled else Callable())
 if not enabled:tile.modulate=Color(0.55,0.55,0.55)
 var select=view.btn(caption,Rect2(),action,false,row);metrics.button(select)
 select.custom_minimum_size=Vector2(0,maxf(metrics.hit,wrapped_height(caption,width-132-metrics.gap-metrics.padding*2,metrics.body)+metrics.padding*2))
 select.size_flags_horizontal=Control.SIZE_EXPAND_FILL;select.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 select.disabled=not enabled
 return tile

func floating_scroll(panel: Panel,content_height: float,footer_height: float=0,scroll_name: String="BattleChoiceScroll") -> ScrollContainer:
 var top=metrics.hit+22
 var chrome=top+footer_height+23
 var maximum=choice_popup_max_height(chrome+metrics.hit)
 panel.size.y=minf(maximum,chrome+maxf(metrics.hit,content_height))
 panel.clip_contents=true
 var scroll=ScrollContainer.new();scroll.name=scroll_name;panel.add_child(scroll)
 scroll.position=Vector2(18,top);scroll.size=Vector2(panel.size.x-36,maxf(0,panel.size.y-chrome))
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
 return scroll

func position_persistent():
 if not view.is_android:return
 if is_instance_valid(view.android_back_button):
  view.android_back_button.position=Vector2(back_rect.position.x,safe.position.y) if is_instance_valid(view.modal_root) else back_rect.position
  view.android_back_button.size=back_rect.size;metrics.button(view.android_back_button)
 if is_instance_valid(view.observe_button):
  metrics.button(view.observe_button)
  if is_instance_valid(view.modal_root):
   view.observe_button.position=Vector2(back_rect.position.x-metrics.gap-view.observe_button.size.x,safe.position.y)
  elif is_instance_valid(toolbar):
   var observe_slot=toolbar.get_node_or_null("ObserveSlot") as Control
   if observe_slot!=null:
    view.observe_button.position=observe_slot.global_position;view.observe_button.size=observe_slot.size
 var stack_top=view.OPPONENT_HAND_COUNT.size.y+metrics.gap
 if view.network_session!=null:stack_top+=metrics.small*1.4+metrics.gap
 var rail_top=view.SIDEBAR.position.y+stack_top
 var rail_bottom=back_rect.position.y-metrics.gap
 if is_instance_valid(notice_scroll) and is_instance_valid(notice_column):
  var popup_open=is_instance_valid(view.android_choice_panel) or is_instance_valid(view.android_choice_restore) or is_instance_valid(view.modal_root)
  var notice_height=0.0 if popup_open else minf(metrics.hit,notice_column.get_combined_minimum_size().y)
  notice_scroll.position=Vector2(back_rect.position.x,rail_top)
  notice_scroll.size=Vector2(back_rect.size.x,notice_height)
  notice_scroll.visible=notice_height>0 and not view.observing
  if notice_height>0:
   stack_top+=notice_height+metrics.gap;rail_top+=notice_height+metrics.gap
 var rail_height=maxf(0,rail_bottom-rail_top)
 var heading_height=metrics.body*3.2+metrics.gap
 var stack_visible=is_instance_valid(view.stack_panel) and view.stack_panel.visible
 var actions_top=back_rect.position.y
 if is_instance_valid(action_scroll) and is_instance_valid(action_column):
  var capacity=rail_height
  var minimum_action_height=metrics.hit
  for action in action_column.get_children():minimum_action_height=maxf(minimum_action_height,action.get_combined_minimum_size().y)
  if stack_visible:
   var reserve=ceilf(heading_height+view.stack_panel.ANDROID_PANEL_INSET*2+view.stack_panel.ANDROID_CARD_SIZE.y+metrics.gap)+2
   if capacity-reserve<minimum_action_height:
    heading_height=ceilf(wrapped_height("堆叠 %d" % view.engine.stack.size(),view.SIDEBAR.size.x-view.stack_panel.ANDROID_PANEL_INSET*2,metrics.small))+metrics.gap
    reserve=ceilf(heading_height+view.stack_panel.ANDROID_PANEL_INSET*2+view.stack_panel.ANDROID_CARD_SIZE.y+metrics.gap)+2
   capacity=maxf(metrics.hit,capacity-reserve)
  var actions_height=minf(action_column.get_combined_minimum_size().y,minf(rail_height,capacity))
  action_scroll.size=Vector2(back_rect.size.x,actions_height)
  action_scroll.position=Vector2(back_rect.position.x,rail_bottom-actions_height)
  action_scroll.visible=actions_height>0 and not view.observing
  if actions_height>0:actions_top=action_scroll.position.y
 if is_instance_valid(view.stack_panel):
  var stack_inset=view.stack_panel.ANDROID_PANEL_INSET
  view.stack_panel.heading.add_theme_font_size_override("font_size",metrics.small if heading_height<metrics.body*3.2 else metrics.body+2)
  view.stack_panel.heading.position=Vector2(stack_inset,stack_inset)
  view.stack_panel.heading.size=Vector2(view.SIDEBAR.size.x-stack_inset*2,heading_height-metrics.gap)
  view.stack_panel.heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  view.stack_panel.heading.text="堆叠 %d" % view.engine.stack.size() if heading_height<metrics.body*3.2 else "堆叠 %d\n从上往下结算" % view.engine.stack.size()
  view.stack_panel.heading.tooltip_text="从上往下结算"
  if view.network_session!=null:
   view.stack_panel.visible=view.stack_panel.visible and view.network_session.room.get("undo_request",{}).is_empty()
  view.stack_panel.position=view.SIDEBAR.position+Vector2(0,stack_top)
  # Reserve the actual phase actions, including extra choices and wrapped text.
  var stack_height=maxf(0,actions_top-metrics.gap-view.stack_panel.position.y)
  view.stack_panel.size=Vector2(view.SIDEBAR.size.x,stack_height)
  view.stack_panel.scroll.position=Vector2(stack_inset,heading_height+stack_inset)
  var scroll_height=maxf(0,stack_height-heading_height-stack_inset*2)
  view.stack_panel.scroll.size=Vector2(view.SIDEBAR.size.x-stack_inset*2,scroll_height)
  view.stack_panel.visible=view.stack_panel.visible and scroll_height>=maxf(metrics.hit,view.stack_panel.scroll.get_combined_minimum_size().y)
 if is_instance_valid(view.inspection) and not view.is_android:
  view.inspection.position=view.INSPECTION.position;view.inspection.size=view.INSPECTION.size

func network_latency_rect() -> Rect2:
 return Rect2(view.SIDEBAR.position+Vector2(0,view.OPPONENT_HAND_COUNT.size.y),Vector2(view.SIDEBAR.size.x,metrics.small*1.4))

func undo_request_rect() -> Rect2:
 var top=network_latency_rect().end.y+metrics.gap
 return Rect2(view.SIDEBAR.position.x,top,view.SIDEBAR.size.x,minf(view.SIDEBAR.end.y-top-metrics.gap,metrics.hit*2.5))

func desktop_frame():
 action_column=VBoxContainer.new();action_column.name="PhaseActions";view.hud.add_child(action_column)
 action_column.position=action_rect.position;action_column.size=action_rect.size
 action_column.alignment=BoxContainer.ALIGNMENT_END
 action_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 action_column.set_meta("choice_widget",true)
 var toolbar_y=12.0
 for i in range(2):
  var mode=view.ResponseMode.ON if i==0 else view.ResponseMode.OFF
  var toggle=view.btn("全响应" if i==0 else "不响应",Rect2(1016+i*116,toolbar_y,108,40),func():view.set_response_mode(view.ResponseMode.DEFAULT if view.response_mode==mode else mode),view.response_mode==mode)
  toggle.toggle_mode=true;toggle.set_pressed_no_signal(view.response_mode==mode)
 var phase_x=410 if not view.player_buffs(1-view.local_seat).is_empty() else 310
 view.txt("连接中断，对局结束" if view.network_session!=null and view.network_session.ended() else "第 %d 回合  ·  %s  ·  %s" % [view.engine.turn,view.player_caption(view.engine.active),view.phase_names[view.engine.phase]],Rect2(phase_x,12,1004-phase_x,42),23,view.host.GOLD)
 var more=view.btn("更多操作",Rect2(),view.open_tools_menu);more.name="BattleTools"
 more.position=Vector2(1408,toolbar_y);more.size=Vector2(168,40)
 more.add_theme_stylebox_override("normal",view.host.style(Color("#192a38"),Color("#3d5161")))
 more.add_theme_stylebox_override("hover",view.host.style(Color("#294354"),view.host.GOLD))
 more.add_theme_stylebox_override("pressed",view.host.style(Color("#615135"),view.host.GOLD))
 more.add_theme_color_override("font_color",view.host.WHITE)
 more.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 view.txt("A  攻击",Rect2(18,865,103,17),13,view.host.MUTED)
 view.txt("G  墓地",Rect2(126,865,110,17),13,view.host.MUTED)
 view.txt("Q  不响应/继续",Rect2(18,882,103,17),13,view.host.MUTED)
 view.txt("H  除外区",Rect2(126,882,110,17),13,view.host.MUTED)
