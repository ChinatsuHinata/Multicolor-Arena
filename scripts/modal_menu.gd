extends CanvasLayer
## Menus own a separate canvas and consume background input until closed.
signal closed
const TOP_LAYER=1024
var host
var backdrop: ColorRect
var panel: PanelContainer
var scroll: ScrollContainer
var grid: GridContainer
var body: VBoxContainer
var heading: Label
var menu_columns=1
var actions: Array[Button]=[]
var close_button: Button
var previous_focus: WeakRef
var swipe=preload("res://scripts/android_swipe_scroll.gd").new()

func build(app,title: String,entries: Array,columns: int=1):
 host=app;layer=TOP_LAYER;name="ModalMenu"
 menu_columns=maxi(1,columns)
 var focus=get_viewport().gui_get_focus_owner()
 if is_instance_valid(focus):previous_focus=weakref(focus);focus.release_focus()
 backdrop=ColorRect.new();backdrop.name="MenuBackdrop";backdrop.color=Color(0,0,0,0.72)
 add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter=Control.MOUSE_FILTER_STOP;backdrop.theme=host.theme
 backdrop.gui_input.connect(func(_event):backdrop.accept_event())
 panel=PanelContainer.new();panel.name="MenuPopup";backdrop.add_child(panel)
 panel.add_theme_stylebox_override("panel",host.ui_metrics.panel_style(true))
 body=VBoxContainer.new();panel.add_child(body)
 body.add_theme_constant_override("separation",int(host.ui_metrics.gap))
 var header=HBoxContainer.new();body.add_child(header)
 heading=Label.new();heading.text=title;heading.name="MenuTitle";header.add_child(heading)
 heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 heading.add_theme_font_size_override("font_size",host.ui_metrics.title)
 heading.add_theme_color_override("font_color",host.GOLD)
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 close_button=host.button(header,"关闭",Rect2(),close)
 close_button.name="CloseMenu";host.ui_metrics.button(close_button)
 var action_container: Container
 if menu_columns>1:
  grid=GridContainer.new();grid.name="MenuActionsGrid";grid.columns=menu_columns;body.add_child(grid)
  grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
  grid.add_theme_constant_override("h_separation",int(host.ui_metrics.gap))
  grid.add_theme_constant_override("v_separation",int(host.ui_metrics.gap))
  action_container=grid
 else:
  scroll=ScrollContainer.new();scroll.name="MenuActionsScroll";body.add_child(scroll)
  scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
  var column=VBoxContainer.new();scroll.add_child(column)
  column.add_theme_constant_override("separation",int(host.ui_metrics.gap))
  column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  action_container=column
 for entry in entries:
  var button=host.button(action_container,str(entry[0]),Rect2(),func():
   close();entry[1].call())
  host.ui_metrics.button(button);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.disabled=entry.size()>2 and bool(entry[2])
  actions.append(button)
 var focus_buttons: Array[Button]=[close_button]
 for button in actions:
  if not button.disabled:focus_buttons.append(button)
 for i in range(focus_buttons.size()):
  var button=focus_buttons[i]
  var previous=button.get_path_to(focus_buttons[(i-1+focus_buttons.size())%focus_buttons.size()])
  var next=button.get_path_to(focus_buttons[(i+1)%focus_buttons.size()])
  button.focus_previous=previous;button.focus_next=next
  button.focus_neighbor_top=previous;button.focus_neighbor_bottom=next
  button.focus_neighbor_left=previous;button.focus_neighbor_right=next
 relayout()
 backdrop.resized.connect(relayout)
 focus_buttons[1 if focus_buttons.size()>1 else 0].grab_focus()

func relayout():
 var m=host.ui_metrics
 var safe=m.safe
 var rows=ceili(float(actions.size())/menu_columns)
 var action_height=m.hit
 var panel_width=minf(960 if menu_columns>1 else 720,safe.size.x)
 if menu_columns>1:
  # All deck actions stay on screen, including on dense Android displays.
  action_height=minf(m.hit,floorf((safe.size.y-m.padding*2-m.gap*rows)/(rows+1)))
  var font_scale=action_height/m.hit
  var header_font=maxi(1,floori(m.title*font_scale))
  var close_font=maxi(1,floori(m.button_font*font_scale))
  close_button.custom_minimum_size.x=0
  var header_space=panel_width-panel.get_theme_stylebox("panel").get_minimum_size().x-m.gap-close_button.get_theme_stylebox("normal").get_minimum_size().x
  while header_font>1:
   var title_width=heading.get_theme_font("font").get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,header_font).x
   var close_width=close_button.get_theme_font("font").get_string_size(close_button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,close_font).x
   if title_width+close_width<=header_space:break
   header_font-=1;close_font=maxi(1,floori(float(m.button_font)*header_font/m.title))
  heading.add_theme_font_size_override("font_size",header_font)
  close_button.custom_minimum_size.x=close_button.get_theme_font("font").get_string_size(close_button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,close_font).x+close_button.get_theme_stylebox("normal").get_minimum_size().x
  close_button.custom_minimum_size.y=action_height
  close_button.add_theme_font_size_override("font_size",close_font)
  var cell_width=(panel_width-panel.get_theme_stylebox("panel").get_minimum_size().x-m.gap*(menu_columns-1))/menu_columns
  var action_font=maxi(1,floori(m.button_font*font_scale))
  while action_font>1:
   var captions_fit=true
   for button in actions:
    var text_width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,action_font).x
    if text_width>cell_width-button.get_theme_stylebox("normal").get_minimum_size().x:
     captions_fit=false;break
   if captions_fit:break
   action_font-=1
  for button in actions:
   button.custom_minimum_size=Vector2(0,action_height)
   button.size_flags_vertical=Control.SIZE_EXPAND_FILL
   button.add_theme_font_size_override("font_size",action_font)
 var wanted_height=m.padding*2+action_height*(rows+1)+m.gap*rows
 panel.size=Vector2(panel_width,minf(wanted_height,safe.size.y))
 panel.position=safe.position+(safe.size-panel.size)*0.5

func _input(event: InputEvent):
 if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
  get_viewport().set_input_as_handled();close();return
 if host.is_android:swipe.handle(event,backdrop)

func _unhandled_input(_event: InputEvent):
 get_viewport().set_input_as_handled()

func close():
 if is_queued_for_deletion():return
 get_parent().remove_child(self);queue_free();closed.emit()
 var focus=previous_focus.get_ref() if previous_focus!=null else null
 if is_instance_valid(focus) and not focus.is_queued_for_deletion() and focus.is_visible_in_tree():focus.grab_focus()
