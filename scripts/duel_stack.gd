extends Control
const ConditionalFrame=preload("res://scripts/conditional_frame_pulse.gd")
## Screen-space stack, outside the battlefield's input and rendering rectangle.
const AREA=Rect2(1358,148,236,452)
const CARD_SIZE=Vector2(218,305)
var view
var scroll: ScrollContainer
var column: VBoxContainer
var heading: Label
var tiles={}
var signature=""
func build(owner_view):
 view=owner_view;position=AREA.position;size=AREA.size;mouse_filter=Control.MOUSE_FILTER_IGNORE
 heading=view.txt("",Rect2(3,0,230,29),20,view.host.GOLD,self)
 scroll=ScrollContainer.new();scroll.position=Vector2(0,33);scroll.size=Vector2(236,419)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 add_child(scroll)
 column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",15);scroll.add_child(column)
func sync():
 visible=not view.engine.stack.is_empty()
 heading.text="堆叠  %d" % view.engine.stack.size()
 var next=JSON.stringify(view.engine.stack.map(func(e):return [e.id,e.get("ability_text",""),e.get("awaiting_target",false)]))
 if next!=signature:
  var old_ids=tiles.keys();var old_top=column.get_child(0).get_meta("stack_id",-1) if column.get_child_count()>0 else -1
  var scroll_y=scroll.scroll_vertical
  for child in column.get_children():column.remove_child(child);child.queue_free()
  tiles.clear();signature=next
  var entries=view.engine.stack.duplicate();entries.reverse()
  for entry in entries:
   var card=entry.card if entry.kind=="card" else entry.source
   var row=VBoxContainer.new();row.set_meta("stack_id",entry.id);row.add_theme_constant_override("separation",5)
   column.add_child(row)
   var tile=preload("res://scripts/live_tooltip_panel.gd").new();tile.custom_minimum_size=Vector2(218,156) if view.host.landscape_card(card.card_id) else CARD_SIZE;tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
   tile.set_meta("uid",card.uid);tile.set_meta("card_id",card.card_id);row.add_child(tile)
   var art=TextureRect.new();art.texture=view.card_texture(card,true);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;tile.add_child(art)
   tile.gui_input.connect(func(event):
    if not event is InputEventMouseButton or not event.pressed:return
    if event.button_index==MOUSE_BUTTON_RIGHT:
     view.inspect_card(card.card_id,card.uid);tile.accept_event()
    elif event.button_index==MOUSE_BUTTON_LEFT:
     if not view.observing and not view.modal and not view.history_open and not view.revealing():view.choose_target({"stack_id":entry.id})
     tile.accept_event())
   var caption=Label.new();caption.text=view.AbilityCaption.text(entry) if entry.kind=="ability" or entry.has("ability_text") else ""
   caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size.x=218
   caption.add_theme_font_size_override("font_size",15);caption.add_theme_color_override("font_color",view.host.WHITE)
   caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.visible=not caption.text.is_empty();row.add_child(caption)
   tile.tooltip_text=entry.name+("\n"+caption.text if not caption.text.is_empty() else "")
   tiles[entry.id]={"tile":tile,"caption":caption,"art":art}
   if entry.kind=="ability" and entry.id not in old_ids:call_deferred("animate_ability",entry.id,entry.source.duplicate(true))
  scroll.set_deferred("scroll_vertical",scroll_y if not entries.is_empty() and entries[0].id==old_top else 0)
 for entry in view.engine.stack:
  var id=entry.id
  var tile=tiles[id].tile;var selected=id in view.table.selected_stacks;var legal=id in view.table.targetable_stacks
  var context=view.card_context_caption(entry.card) if entry.kind=="card" else ""
  var caption=tiles[id].caption.text
  tile.tooltip_text=entry.name+("\n"+caption if not caption.is_empty() else "")+("\n"+context if not context.is_empty() else "")
  var style=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT
  var conditional=entry.kind=="card" and view.ConditionHints.active(view.engine,entry.card)
  if selected or legal or conditional:
   style.set_border_width_all(4);style.border_color=Color("#ffd65c") if selected else Color("#359bff")
   style.expand_margin_left=3;style.expand_margin_right=3;style.expand_margin_top=3;style.expand_margin_bottom=3
  tile.add_theme_stylebox_override("panel",style);tile.set_meta("selected",selected);tile.set_meta("legal",legal)
  ConditionalFrame.apply(tile,style,conditional and not selected)
func entry_rect(id:int) -> Rect2:
 if not visible or not tiles.has(id):return Rect2()
 var rect=tiles[id].tile.get_global_rect().intersection(scroll.get_global_rect())
 return rect if rect.has_area() else Rect2()
func card_rect(uid:int) -> Rect2:
 for id in tiles:
  if tiles[id].tile.get_meta("uid")==uid:return entry_rect(id)
 return Rect2()
func arrival_rect() -> Rect2:
 return Rect2(AREA.position+Vector2(0,33),CARD_SIZE)
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
