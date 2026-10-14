extends Control
## A local top-to-bottom stack draft. Only the confirmation mutates the duel.
var view
var order: Array
var scroll: ScrollContainer
var column: VBoxContainer
var rows: Array=[]
var handles: Array=[]
var source=-1
var finger=-1
var origin=Vector2.ZERO
var pointer=Vector2.ZERO
var dragging=false
var slot=-1
var insertion: ColorRect
var preview: PanelContainer

func build(owner_view,panel: Panel,draft: Array):
 view=owner_view;order=draft
 name="TriggerOrderList";mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var metrics=view.host.ui_metrics
 var row_height=maxf(136,metrics.hit+20)
 var hint_width=minf(900,metrics.safe.size.x-24)-40
 var hint_text=view.responsive.wrap_choice_prompt("拖动 ≡ 调整顺序；顶部先结算，与堆叠顺序一致。",hint_width,metrics.small)
 var hint_height=view.responsive.wrapped_height(hint_text,hint_width,metrics.small)+8
 var layout=view.responsive.dialog_content(panel,900,minf(580,order.size()*(row_height+metrics.gap))+hint_height,true)
 scroll=layout.scroll;column=layout.body
 var hint=view.txt(hint_text,Rect2(scroll.position,Vector2(scroll.size.x,hint_height)),metrics.small,view.host.WHITE,panel)
 hint.name="TriggerOrderHint";hint.add_theme_font_size_override("font_size",metrics.small);hint.clip_text=false
 scroll.position.y+=hint_height+metrics.gap;scroll.size.y-=hint_height+metrics.gap
 scroll.set_meta("android_swipe_prefer_vertical",true)
 var confirm=view.responsive.choice_footer_button(layout.footer,"确认顺序",func():
  if source>=0 or view.observing or view.network_locked() or view.engine.pending.get("kind","")!="trigger_order":return
  view.engine.choose_trigger_order(order.duplicate());view.picker.reset();view.render(),true)
 confirm.name="ConfirmTriggerOrder"
 insertion=ColorRect.new();insertion.color=view.host.GOLD;insertion.mouse_filter=Control.MOUSE_FILTER_IGNORE;insertion.hide();add_child(insertion)
 preview=PanelContainer.new();preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
 preview.add_theme_stylebox_override("panel",view.host.style(Color("#24394a"),view.host.GOLD));preview.hide();add_child(preview)
 var preview_text=Label.new();preview_text.name="Caption";preview_text.add_theme_font_size_override("font_size",metrics.body)
 preview_text.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.add_child(preview_text)
 rebuild()
 panel.move_child(self,-1)

func rebuild():
 for child in column.get_children():column.remove_child(child);child.queue_free()
 rows.clear();handles.clear()
 var metrics=view.host.ui_metrics
 for position in range(order.size()):
  var index=order[position];var trigger=view.engine.pending.options[index];var card=trigger.source
  var row=PanelContainer.new();row.name="TriggerOrderRow"+str(index);row.set_meta("trigger_index",index)
  var frame=view.host.style(Color("#172836"),Color("#314b5a"));frame.set_content_margin_all(10)
  row.add_theme_stylebox_override("panel",frame);row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  row.mouse_default_cursor_shape=Control.CURSOR_DRAG;column.add_child(row);rows.append(row)
  var body=HBoxContainer.new();body.add_theme_constant_override("separation",int(metrics.gap));body.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(body)
  var handle=Label.new();handle.name="DragHandle";handle.text="≡";handle.custom_minimum_size=Vector2(metrics.hit,maxf(116,metrics.hit))
  handle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;handle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  handle.add_theme_font_size_override("font_size",32);handle.add_theme_color_override("font_color",view.host.GOLD)
  handle.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(handle);handles.append(handle)
  var art=TextureRect.new();art.name="TriggerSourceArt";art.texture=view.card_texture(card,true)
  art.custom_minimum_size=Vector2(82,116);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(art)
  var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(details)
  var number=Label.new();number.name="TriggerOrderNumber";number.text="%d · %s" % [position+1,"先结算" if position==0 else "随后结算"]
  number.add_theme_font_size_override("font_size",metrics.body);number.add_theme_color_override("font_color",view.host.GOLD);number.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(number)
  var title=Label.new();title.text=view.engine.cards[card.card_id].name;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  title.add_theme_font_size_override("font_size",metrics.small);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(title)
  var caption=Label.new();caption.name="TriggerCaption";caption.text=view.AbilityCaption.text(trigger)
  caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  caption.add_theme_font_size_override("font_size",metrics.small);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(caption)
  row.tooltip_text=view.engine.cards[card.card_id].name+"\n"+caption.text

func handle(event: InputEvent) -> bool:
 if not is_visible_in_tree() or view.observing or view.network_locked():
  if source>=0:finish(false)
  return false
 if source>=0 and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  finish(false);return consume()
 if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 var touch=event is InputEventScreenTouch or event is InputEventScreenDrag
 if source>=0:
  # Some Android devices send the mouse echo before the native finger press.
  if touch and finger<0 and event is InputEventScreenTouch and event.pressed and event.position.distance_to(origin)<28:
   finger=event.index;return consume()
  if touch and event.index!=finger or not touch and finger>=0:return consume()
  pointer=event.position
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   finish(false);return consume()
  if event is InputEventMouseMotion or event is InputEventScreenDrag:
   if pointer.distance_to(origin)>12:dragging=true
   if dragging:update_drag()
   return consume()
  if event is InputEventScreenTouch and not event.pressed or event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   if dragging:update_drag()
   finish(dragging and not (event is InputEventScreenTouch and event.canceled) and scroll.get_global_rect().has_point(pointer));return consume()
  return consume()
 if not (event is InputEventMouseButton or event is InputEventScreenTouch) or not event.pressed or not scroll.get_global_rect().has_point(event.position):return false
 for i in range(rows.size()):
  if not rows[i].get_global_rect().has_point(event.position):continue
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
   var card=view.engine.pending.options[order[i]].source
   view.inspect_card(card.card_id,card.uid,view.AbilityCaption.text(view.engine.pending.options[order[i]]),card.get("art_id",""));return consume()
  if touch and not handles[i].get_global_rect().has_point(event.position):return false
  if not touch and event.button_index!=MOUSE_BUTTON_LEFT:return false
  source=order[i];finger=event.index if touch else -1;origin=event.position;pointer=origin;slot=i
  return consume()
 return false

func consume() -> bool:
 get_viewport().set_input_as_handled();return true

func update_drag():
 slot=rows.size()
 for i in range(rows.size()):
  if pointer.y<rows[i].get_global_rect().get_center().y:slot=i;break
 var bounds=scroll.get_global_rect()
 var y=rows[slot].get_global_rect().position.y if slot<rows.size() else rows.back().get_global_rect().end.y
 insertion.position=Vector2(bounds.position.x,clampf(y,bounds.position.y,bounds.end.y-3))-global_position
 insertion.size=Vector2(bounds.size.x,3);insertion.visible=bounds.has_point(pointer)
 var card=view.engine.pending.options[source].source
 preview.get_node("Caption").text="≡ "+view.engine.cards[card.card_id].name
 preview.position=Vector2(clampf(pointer.x-global_position.x+16,0,maxf(0,size.x-preview.size.x)),clampf(pointer.y-global_position.y+16,0,maxf(0,size.y-preview.size.y)))
 preview.show()
 for row in rows:row.modulate=Color(1,1,1,0.4) if row.get_meta("trigger_index")==source else Color.WHITE

func finish(apply: bool):
 if apply and slot>=0:
  var previous=order.find(source)
  var destination=slot-1 if slot>previous else slot
  order.remove_at(previous);order.insert(clampi(destination,0,order.size()),source)
 source=-1;finger=-1;dragging=false;slot=-1;insertion.hide();preview.hide()
 for row in rows:row.modulate=Color.WHITE
 if apply:rebuild()

func _process(delta: float):
 if source>=0 and (not is_visible_in_tree() or view.observing or view.network_locked()):finish(false);return
 if not dragging:return
 var bounds=scroll.get_global_rect()
 if pointer.x<bounds.position.x or pointer.x>bounds.end.x:return
 var edge=minf(48,bounds.size.y*0.2)
 var direction=-1 if pointer.y<bounds.position.y+edge else 1 if pointer.y>bounds.end.y-edge else 0
 if direction!=0:scroll.get_v_scroll_bar().value+=direction*420*delta;update_drag()

func _notification(what: int):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and source>=0:finish(false)
