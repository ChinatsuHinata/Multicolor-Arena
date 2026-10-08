extends Control
const ConditionalFrame=preload("res://scripts/conditional_frame_pulse.gd")
## Screen-space stack, outside the battlefield's input and rendering rectangle.
const AREA=Rect2(1358,148,236,452)
const CARD_SIZE=Vector2(218,305)
const ANDROID_CARD_SIZE=Vector2(200,280)
const ANDROID_PANEL_INSET=8.0
const TOGGLE_SIZE=Vector2(90,90)
var view
var scroll: ScrollContainer
var column: VBoxContainer
var heading: Label
var toggle_button: Button
var collapsed=false
var tiles={}
var signature=""
func chosen_mode(entry: Dictionary) -> String:
 if entry.get("kind","")!="card":return ""
 var target=entry.get("target",{})
 var modes=selected_modes(target)
 var card_id=entry.get("card",{}).get("card_id","")
 if card_id=="spell-htk-003":
  return "（造成%d点伤害，对手需要多支付%d费，将%d张目标道具或单位移回手上）" % [modes.count("造成1点伤害"),modes.count("反制，除非支付1点"),modes.count("移回手牌")]
 if card_id not in ["176","161"] and not str(target.get("mode","")).is_empty():modes=[str(target.mode)]
 if modes.is_empty() and target.has("ignore_color"):
  modes.append("不忽略颜色" if target.ignore_color=="无" else "忽略%s色" % target.ignore_color)
 var captions=[]
 for mode in modes:
  var shown=mode_caption(card_id,mode)
  if not captions.is_empty() and captions.back().begins_with(shown+" ×"):
   var previous=captions.pop_back()
   captions.append(shown+" ×%d" % (int(previous.get_slice("×",1))+1))
  elif not captions.is_empty() and captions.back()==shown:captions[-1]=shown+" ×2"
  else:captions.append(shown)
 return "已选择："+"、".join(captions) if not captions.is_empty() else ""
func selected_modes(target: Dictionary) -> Array:
 var modes=[]
 if target.has("picks"):
  for group in target.picks:
   for choice in group:
    if choice is Dictionary:modes.append_array(selected_modes(choice))
 elif target.has("parts"):
  for part in target.parts:
   if part is Dictionary:modes.append_array(selected_modes(part))
 if modes.is_empty() and not str(target.get("mode","")).is_empty():modes.append(str(target.mode))
 return modes
func mode_caption(card_id: String,mode: String) -> String:
 match card_id:
  "176":return {"横置":"横置目标单位"}.get(mode,mode)
  "161":return {"全体强化":"己方单位获得+1/+0与+1","回收单位":"将目标墓地单位移回手上"}.get(mode,mode)
 return mode
func entry_caption(entry: Dictionary) -> String:
 var caption=view.AbilityCaption.text(entry) if entry.kind=="ability" or entry.has("ability_text") else ""
 var mode=chosen_mode(entry)
 if caption.is_empty():return mode
 return caption+"\n"+mode if not mode.is_empty() else caption
func build(owner_view):
 view=owner_view;position=AREA.position;size=AREA.size;mouse_filter=Control.MOUSE_FILTER_IGNORE
 clip_contents=false
 heading=view.txt("",Rect2(3,0,230,29),20,view.host.GOLD,self)
 scroll=ScrollContainer.new();scroll.position=Vector2(0,33);scroll.size=Vector2(236,419)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 add_child(scroll)
 column=VBoxContainer.new()
 column.add_theme_constant_override("separation",6 if view.is_android else 15)
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
 if view.is_android:
  toggle_button=view.host.button(self,"›",Rect2(Vector2.ZERO,TOGGLE_SIZE),func():set_collapsed(not collapsed))
  toggle_button.name="StackToggle"
  toggle_button.add_theme_font_size_override("font_size",40)
  toggle_button.z_index=2
  resized.connect(update_toggle_position)
  update_toggle_position()

func set_collapsed(value: bool):
 if not view.is_android:return
 collapsed=value
 apply_collapsed_state()
 if is_instance_valid(view.responsive):view.responsive.position_persistent()

func apply_collapsed_state():
 if not view.is_android:return
 heading.visible=not collapsed
 scroll.visible=not collapsed
 if is_instance_valid(toggle_button):
  toggle_button.text="‹" if collapsed else "›"
  toggle_button.tooltip_text="展开堆叠" if collapsed else "收起堆叠"
  update_toggle_position()

func update_toggle_position():
 if not is_instance_valid(toggle_button):return
 toggle_button.size=TOGGLE_SIZE
 toggle_button.position=Vector2(maxf(0,size.x-TOGGLE_SIZE.x) if collapsed else -TOGGLE_SIZE.x,
  maxf(0,minf(size.y-TOGGLE_SIZE.y,32)))
func sync():
 var unresolved=view.engine.unresolved_stack_entries()
 visible=not unresolved.is_empty()
 if view.is_android and not view.table.targetable_stacks.is_empty():collapsed=false
 apply_collapsed_state()
 heading.text="堆叠  %d" % unresolved.size()
 var resolving_id=view.engine.pending.get("resolving_entry",view.engine.pending.get("trigger",{}).get("entry",{})).get("id",-1)
 var next=JSON.stringify(unresolved.map(func(e):return [e.id,e.get("ability_text",""),e.get("awaiting_target",false),chosen_mode(e),e.id==resolving_id]))
 if next!=signature:
  var old_ids=tiles.keys();var old_top=column.get_child(0).get_meta("stack_id",-1) if column.get_child_count()>0 else -1
  var scroll_y=scroll.scroll_vertical
  for child in column.get_children():column.remove_child(child);child.queue_free()
  tiles.clear();signature=next
  var entries=unresolved.duplicate();entries.reverse()
  for index in range(entries.size()):
   var entry=entries[index]
   var card=entry.card if entry.kind=="card" else entry.source
   var row=VBoxContainer.new()
   row.set_meta("stack_id",entry.id);row.add_theme_constant_override("separation",5)
   column.add_child(row)
   var tile=preload("res://scripts/live_tooltip_panel.gd").new()
   var card_size=ANDROID_CARD_SIZE if view.is_android else CARD_SIZE
   tile.custom_minimum_size=Vector2(card_size.x,card_size.x*156.0/218.0) if view.host.landscape_card(card.card_id) else card_size
   tile.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
   tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
   tile.set_meta("uid",card.uid);tile.set_meta("card_id",card.card_id);row.add_child(tile)
   if view.is_android:
    view.android_card_touch.bind_card(tile,func():view.inspect_card(card.card_id,card.uid,caption_for(entry),card.get("art_id","")),func():
     if entry.id!=resolving_id and not view.observing and not view.modal and not view.history_open and not view.revealing():view.choose_target({"stack_id":entry.id}))
   var art=TextureRect.new();art.texture=view.card_texture(card,true);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;tile.add_child(art)
   tile.gui_input.connect(func(event):
    if not event is InputEventMouseButton:return
    if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
     view.inspect_card(card.card_id,card.uid);tile.accept_event()
    elif event.button_index==MOUSE_BUTTON_LEFT and event.pressed!=view.is_android:
     if entry.id!=resolving_id and not view.observing and not view.modal and not view.history_open and not view.revealing():view.choose_target({"stack_id":entry.id})
     tile.accept_event())
   var details: VBoxContainer
   if view.is_android:
    details=VBoxContainer.new()
    details.add_theme_constant_override("separation",4)
    row.add_child(details)
    var order=Label.new();order.name="StackOrder"
    order.text="正在结算" if entry.id==resolving_id else "%d · %s" % [index+1,"先结算" if index==0 else "随后结算"]
    order.add_theme_font_size_override("font_size",view.host.ui_metrics.small)
    order.add_theme_color_override("font_color",view.host.GOLD)
    order.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(order)
   var caption_text=entry_caption(entry)
   if entry.id==resolving_id and not view.is_android:caption_text="正在结算\n"+caption_text
   var caption=Label.new();caption.text=caption_text
   caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size.x=card_size.x
   caption.max_lines_visible=-1
   caption.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
   caption.add_theme_font_size_override("font_size",view.host.ui_metrics.small if view.is_android else 15);caption.add_theme_color_override("font_color",view.host.WHITE)
   caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.visible=not caption.text.is_empty()
   if view.is_android:details.add_child(caption)
   else:row.add_child(caption)
   tile.tooltip_text=entry.name+("\n"+caption.text if not caption.text.is_empty() else "")
   tiles[entry.id]={"tile":tile,"caption":caption,"art":art}
   if entry.kind=="ability" and entry.id not in old_ids:call_deferred("animate_ability",entry.id,entry.source.duplicate(true))
  scroll.set_deferred("scroll_vertical",scroll_y if not entries.is_empty() and entries[0].id==old_top else 0)
 for entry in unresolved:
  var id=entry.id
  var tile=tiles[id].tile;var selected=id in view.table.selected_stacks;var legal=id in view.table.targetable_stacks
  var context=view.card_context_caption(entry.card) if entry.kind=="card" else ""
  var caption=tiles[id].caption.text
  tile.tooltip_text=entry.name+("\n"+caption if not caption.is_empty() else "")+("\n"+context if not context.is_empty() else "")
  var style=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT
  var conditional=entry.kind=="card" and view.ConditionHints.active(view.engine,entry.card)
  view.sync_stack_target_marker(tile,{"stack_id":id})
  if selected or legal or conditional:
   style.set_border_width_all(4);style.border_color=Color("#ffd65c") if selected else Color("#359bff")
   style.expand_margin_left=3;style.expand_margin_right=3;style.expand_margin_top=3;style.expand_margin_bottom=3
  tile.add_theme_stylebox_override("panel",style);tile.set_meta("selected",selected);tile.set_meta("legal",legal)
  ConditionalFrame.apply(tile,style,conditional and not selected)
func entry_rect(id:int) -> Rect2:
 if not visible or collapsed or not tiles.has(id):return Rect2()
 var rect=tiles[id].tile.get_global_rect().intersection(scroll.get_global_rect())
 return rect if rect.has_area() else Rect2()
func arrow_rect(id:int) -> Rect2:
 if not visible or collapsed or not tiles.has(id):return Rect2()
 return view.clipped_arrow_rect(tiles[id].tile.get_global_rect(),scroll.get_global_rect())
func caption_for(entry: Dictionary) -> String:
 return entry_caption(entry)
func card_rect(uid:int) -> Rect2:
 for id in tiles:
  if tiles[id].tile.get_meta("uid")==uid:return arrow_rect(id)
 return Rect2()
func arrival_rect() -> Rect2:
 if collapsed and is_instance_valid(toggle_button):return toggle_button.get_global_rect()
 return Rect2(scroll.get_global_rect().position,ANDROID_CARD_SIZE if view.is_android else CARD_SIZE)
func inspect_at(point:Vector2) -> bool:
 for id in tiles:
  if entry_rect(id).has_point(point):
   var tile=tiles[id].tile;view.inspect_card(tile.get_meta("card_id"),tile.get_meta("uid"));return true
 return false
func animate_ability(id:int,source:Dictionary):
 await get_tree().process_frame
 if not is_instance_valid(view) or not tiles.has(id):return
 var dest=entry_rect(id)
 if not dest.has_area():return
 var origin=view.target_rect(view.engine.ref_target(source))
 if not origin.has_area():return
 var art=TextureRect.new();art.texture=view.card_texture(source,true);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.position=origin.position;art.size=origin.size;view.effects.add_child(art)
 var face=tiles[id].art;face.modulate.a=0;view.table.mark_busy();var face_ref=weakref(face)
 var tween=create_tween().bind_node(art).set_parallel(true)
 tween.tween_property(art,"position",dest.position,0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 tween.tween_property(art,"size",dest.size,0.3)
 tween.chain().tween_callback(func():
  art.queue_free()
  var remaining_face=face_ref.get_ref()
  if is_instance_valid(remaining_face):remaining_face.modulate.a=1)
