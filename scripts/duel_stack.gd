extends Control
const ConditionalFrame=preload("res://scripts/conditional_frame_pulse.gd")
const Palette=preload("res://scripts/ui_palette.gd")
## Screen-space stack, outside the battlefield's input and rendering rectangle.
const AREA=Rect2(1358,148,236,452)
const CARD_SIZE=Vector2(218,305)
const ANDROID_CARD_SIZE=Vector2(200,280)
const ANDROID_PANEL_INSET=8.0
const TOGGLE_SIZE=Vector2(90,90)
## Desktop compact layout: the next entry to resolve keeps a readable card face,
## everything beneath it becomes a row with a thumbnail and the effect text.
const LEAD_SIZE=Vector2(168,235)
const THUMB_SIZE=Vector2(58,81)
const ROW_WIDTH=214.0
const ROW_TEXT_X=74.0
## Android: the next entry glows like a card being cast and the entries beneath
## it fan out behind its face; the rest of the stack becomes compact rows.
const ANDROID_THUMB_SIZE=Vector2(64,90)
const LEAD_GLOW=Color("#ff8a2b")
const RESOLVING_GLOW=Color("#ff3d2e")
const FAN_DEPTH=2
var view
var scroll: ScrollContainer
var column: VBoxContainer
var heading: Label
var hint: Label
var backing: Panel
var toggle_button: Button
var collapsed=false
var tiles={}
var signature=""
var resolving_style: StyleBoxFlat
var glow_styles=[]
var flare=0.0
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
 var cost=view.variable_cost_caption(entry.card) if entry.kind=="card" else ""
 if not cost.is_empty():mode+=("\n" if not mode.is_empty() else "")+cost
 if caption.is_empty():return mode
 return caption+"\n"+mode if not mode.is_empty() else caption
func spell_owner_label(parent: Node,card: Dictionary) -> Label:
 var owner=view.host.Store.Database.spell_owner_caption(view.engine.cards.get(card.get("card_id",""),{}))
 if owner.is_empty():return null
 var label=Label.new();label.name="SpellOwner";label.text=owner
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",view.host.ui_metrics.small if view.is_android else 14)
 label.add_theme_color_override("font_color",view.host.GOLD);parent.add_child(label)
 return label
func build(owner_view):
 view=owner_view;position=AREA.position;size=AREA.size;mouse_filter=Control.MOUSE_FILTER_IGNORE
 clip_contents=false
 if compact_enabled():
  backing=Panel.new();backing.name="StackBacking";backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var frame=view.host.style(Color("#3a2434e6"),Color("#b67d96"));frame.shadow_color=Color(0,0,0,0.35);frame.shadow_size=8
  backing.add_theme_stylebox_override("panel",frame);add_child(backing)
  backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  backing.offset_left=-6;backing.offset_right=4;backing.offset_top=-4;backing.offset_bottom=4
  var rule=ColorRect.new();rule.name="StackRule";rule.color=Palette.VERMILION;rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
  rule.position=Vector2(4,29);rule.size=Vector2(72,3);add_child(rule)
 elif view.is_android:
  backing=Panel.new();backing.name="StackBacking";backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var frame=view.host.style(Color("#0b1520e0"),Color("#c8743a"));frame.set_border_width_all(2)
  frame.shadow_color=Color(1.0,0.45,0.15,0.22);frame.shadow_size=10
  backing.add_theme_stylebox_override("panel",frame);add_child(backing)
  backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 heading=view.txt("",Rect2(3,0,230,29),20,view.host.GOLD,self)
 if compact_enabled():
  hint=view.txt("顶部先结算 ↑",Rect2(110,4,120,24),14,Palette.MIST,self);hint.name="StackHint"
  hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 scroll=ScrollContainer.new();scroll.position=Vector2(0,33);scroll.size=Vector2(236,419)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 add_child(scroll)
 column=VBoxContainer.new()
 column.add_theme_constant_override("separation",6 if view.is_android else 10 if compact_enabled() else 15)
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
 if view.is_android:
  toggle_button=view.host.button(self,"›",Rect2(Vector2.ZERO,TOGGLE_SIZE),func():set_collapsed(not collapsed))
  toggle_button.name="StackToggle"
  toggle_button.add_theme_font_size_override("font_size",40)
  toggle_button.z_index=2
  resized.connect(update_toggle_position)
  update_toggle_position()

func compact_enabled() -> bool:
 return Palette.enabled and not view.is_android

func set_collapsed(value: bool):
 if not view.is_android:return
 collapsed=value
 apply_collapsed_state()
 if is_instance_valid(view.responsive):view.responsive.position_persistent()

func apply_collapsed_state():
 if not view.is_android:return
 heading.visible=not collapsed
 scroll.visible=not collapsed
 if is_instance_valid(backing):backing.visible=not collapsed
 if is_instance_valid(toggle_button):
  toggle_button.text="‹" if collapsed else "›"
  toggle_button.tooltip_text="展开对抗区" if collapsed else "收起对抗区"
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
 heading.text="对抗区  %d" % unresolved.size()
 var resolving_id=view.engine.pending.get("resolving_entry",view.engine.pending.get("trigger",{}).get("entry",{})).get("id",-1)
 var next=JSON.stringify(unresolved.map(func(e):return [e.id,e.get("ability_text",""),e.get("awaiting_target",false),chosen_mode(e),e.id==resolving_id]))
 if next!=signature:
  var old_ids=tiles.keys();var old_top=column.get_child(0).get_meta("stack_id",-1) if column.get_child_count()>0 else -1
  var scroll_y=scroll.scroll_vertical
  var live_ids=unresolved.map(func(e):return e.id)
  for id in old_ids:
   if id not in live_ids:dissolve(id)
  for child in column.get_children():column.remove_child(child);child.queue_free()
  tiles.clear();signature=next;resolving_style=null
  var entries=unresolved.duplicate();entries.reverse()
  var compact=(compact_enabled() or view.is_android) and entries.size()>1
  for index in range(entries.size()):
   var entry=entries[index]
   var card=entry.card if entry.kind=="card" else entry.source
   var row=VBoxContainer.new()
   row.set_meta("stack_id",entry.id);row.add_theme_constant_override("separation",5)
   column.add_child(row)
   if compact_enabled():order_ribbon(row,index,entry.id==resolving_id)
   if compact and index>0:
    compact_row(row,entry,card,index,resolving_id,old_ids)
    continue
   var tile=preload("res://scripts/live_tooltip_panel.gd").new()
   var card_size=ANDROID_CARD_SIZE if view.is_android else LEAD_SIZE if compact else CARD_SIZE
   tile.custom_minimum_size=Vector2(card_size.x,card_size.x*156.0/218.0) if view.host.landscape_card(card.card_id) else card_size
   tile.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
   tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
   tile.set_meta("uid",card.uid);tile.set_meta("card_id",card.card_id);row.add_child(tile)
   if view.is_android:
    bind_touch(tile,entry,card,resolving_id)
    fan(tile,entries)
   var art=TextureRect.new();art.texture=view.card_texture(card,true);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;tile.add_child(art)
   bind_tile_input(tile,entry,card,resolving_id)
   var details: VBoxContainer
   if view.is_android:
    details=VBoxContainer.new()
    details.add_theme_constant_override("separation",4)
    row.add_child(details)
    var order=Label.new();order.name="StackOrder"
    order.text="正在结算" if entry.id==resolving_id else "%d · %s" % [index+1,"先结算" if index==0 else "随后结算"]
    order.add_theme_font_size_override("font_size",view.host.ui_metrics.small)
    order.add_theme_color_override("font_color",RESOLVING_GLOW.lightened(0.3) if entry.id==resolving_id else LEAD_GLOW.lightened(0.25))
    order.mouse_filter=Control.MOUSE_FILTER_IGNORE;details.add_child(order)
   spell_owner_label(details if view.is_android else row,card)
   var caption_text=entry_caption(entry)
   # The desktop ribbon already announces the resolving entry.
   if entry.id==resolving_id and not view.is_android and not compact_enabled():caption_text="正在结算\n"+caption_text
   var caption=Label.new();caption.text=caption_text
   caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size.x=ROW_WIDTH if compact_enabled() else card_size.x
   caption.max_lines_visible=-1
   caption.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
   caption.add_theme_font_size_override("font_size",view.host.ui_metrics.small if view.is_android else 15);caption.add_theme_color_override("font_color",view.host.WHITE)
   caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.visible=not caption.text.is_empty()
   if compact_enabled():
    caption.add_theme_font_size_override("font_size",16)
    var plate=view.host.style(Color("#2e1c2bc8"),Color("#6a4558"))
    plate.content_margin_left=8;plate.content_margin_right=8;plate.content_margin_top=4;plate.content_margin_bottom=5
    caption.add_theme_stylebox_override("normal",plate)
   if view.is_android:details.add_child(caption)
   else:row.add_child(caption)
   tile.tooltip_text=entry.name+("\n"+caption.text if not caption.text.is_empty() else "")
   tiles[entry.id]={"tile":tile,"caption":caption,"art":art,"compact":false,"owner":int(entry.get("owner",-1)),"kind":entry.kind}
   if entry.id not in old_ids:arrive(row)
   if entry.kind=="ability" and entry.id not in old_ids:call_deferred("animate_ability",entry.id,entry.source.duplicate(true))
  scroll.set_deferred("scroll_vertical",scroll_y if not entries.is_empty() and entries[0].id==old_top else 0)
 glow_styles=[]
 for entry in unresolved:
  var id=entry.id
  var tile=tiles[id].tile;var selected=id in view.table.selected_stacks;var legal=id in view.table.targetable_stacks
  var context=view.card_context_caption(entry.card) if entry.kind=="card" else ""
  var caption=tiles[id].caption.text
  var card=entry.card if entry.kind=="card" else entry.source
  var owner=view.host.Store.Database.spell_owner_caption(view.engine.cards.get(card.get("card_id",""),{}))
  tile.tooltip_text=entry.name+("\n"+owner if not owner.is_empty() else "")+("\n"+caption if not caption.is_empty() else "")+("\n"+context if not context.is_empty() else "")
  var style=base_style(tiles[id],id==resolving_id)
  var conditional=entry.kind=="card" and view.conditional_hint(entry.card)
  view.sync_stack_target_marker(tile,{"stack_id":id})
  if selected or legal or conditional:
   style.set_border_width_all(4);style.border_color=Color("#ffd65c") if selected else Color("#359bff")
   style.expand_margin_left=3;style.expand_margin_right=3;style.expand_margin_top=3;style.expand_margin_bottom=3
  elif id==resolving_id and compact_enabled():resolving_style=style
  if view.is_android and not tiles[id].compact:
   glow_styles.append({"style":style,"color":RESOLVING_GLOW if id==resolving_id else LEAD_GLOW,"border":not (selected or legal or conditional)})
  tile.add_theme_stylebox_override("panel",style);tile.set_meta("selected",selected);tile.set_meta("legal",legal)
  ConditionalFrame.apply(tile,style,conditional and not selected)

func bind_touch(tile: Control,entry: Dictionary,card: Dictionary,resolving_id):
 view.android_card_touch.bind_card(tile,func():view.inspect_card(card.card_id,card.uid,caption_for(entry),card.get("art_id","")),func():
  if entry.id!=resolving_id and not view.observing and not view.modal and not view.history_open and not view.revealing():view.choose_target({"stack_id":entry.id}))

## The entries beneath the lead peek out behind its face, tilted like a held fan.
func fan(tile: Control,entries: Array):
 for depth in range(mini(FAN_DEPTH,entries.size()-1),0,-1):
  var under=entries[depth]
  var ghost=TextureRect.new();ghost.name="StackFan%d" % depth;ghost.show_behind_parent=true
  ghost.texture=view.card_texture(under.card if under.kind=="card" else under.source,true)
  ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
  ghost.size=tile.custom_minimum_size;ghost.pivot_offset=ghost.size
  ghost.position=Vector2(-5.0*depth,0);ghost.rotation=deg_to_rad(-3.5*depth)
  ghost.modulate=Color(0.6,0.6,0.66,0.92)
  tile.add_child(ghost)

func bind_tile_input(tile: Control,entry: Dictionary,card: Dictionary,resolving_id):
 tile.gui_input.connect(func(event):
  if not event is InputEventMouseButton:return
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   view.inspect_card(card.card_id,card.uid);tile.accept_event()
  elif event.button_index==MOUSE_BUTTON_LEFT and event.pressed!=view.is_android:
   if entry.id!=resolving_id and not view.observing and not view.modal and not view.history_open and not view.revealing():view.choose_target({"stack_id":entry.id})
   tile.accept_event())

func order_ribbon(row: VBoxContainer,index: int,resolving: bool):
 var ribbon=Label.new();ribbon.name="StackOrder";ribbon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ribbon.text="✿ 正在结算" if resolving else "%d · %s" % [index+1,"下一个结算" if index==0 else "随后结算"]
 ribbon.add_theme_font_size_override("font_size",15 if index==0 else 13)
 ribbon.add_theme_color_override("font_color",Color.WHITE if resolving else Palette.SAKURA if index==0 else Palette.MIST)
 if resolving:
  var band=StyleBoxFlat.new();band.bg_color=Palette.VERMILION;band.set_corner_radius_all(6)
  band.content_margin_left=8;band.content_margin_right=8
  ribbon.add_theme_stylebox_override("normal",band);ribbon.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
 row.add_child(ribbon)

func compact_row(row: VBoxContainer,entry: Dictionary,card: Dictionary,index: int,resolving_id,old_ids: Array):
 var android=view.is_android
 var metrics=view.host.ui_metrics
 var width=view.SIDEBAR.size.x-ANDROID_PANEL_INSET*2-4 if android else ROW_WIDTH
 var thumb=ANDROID_THUMB_SIZE if android else THUMB_SIZE
 var text_x=thumb.x+16 if android else ROW_TEXT_X
 var tile=preload("res://scripts/live_tooltip_panel.gd").new();tile.name="StackRow"
 tile.custom_minimum_size=Vector2(width,thumb.y+12);tile.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
 tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;tile.clip_contents=true
 tile.set_meta("uid",card.uid);tile.set_meta("card_id",card.card_id);row.add_child(tile)
 var art=TextureRect.new();art.name="StackThumb";art.texture=view.card_texture(card,true)
 # Expand mode must precede the size, or the texture's native size wins.
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.position=Vector2(8,6);art.size=thumb
 tile.add_child(art)
 var badge_size=maxf(22.0,metrics.small*0.95) if android else 22.0
 var badge=Label.new();badge.name="StackBadge";badge.text=str(index+1);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
 badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 badge.position=Vector2(2,2);badge.size=Vector2.ONE*badge_size;badge.add_theme_font_size_override("font_size",int(badge_size*0.6))
 var disc=StyleBoxFlat.new();disc.bg_color=Palette.VERMILION;disc.border_color=Palette.SHRINE_GOLD;disc.set_border_width_all(1);disc.set_corner_radius_all(int(badge_size*0.5))
 badge.add_theme_stylebox_override("normal",disc);badge.add_theme_color_override("font_color",Color.WHITE);tile.add_child(badge)
 var title_size=maxi(16,roundi(metrics.small*0.8)) if android else 15
 var title=Label.new();title.name="StackName";title.text=entry.name;title.clip_text=true;title.mouse_filter=Control.MOUSE_FILTER_IGNORE
 title.position=Vector2(text_x,5);title.size=Vector2(width-text_x-8,title_size+7)
 title.add_theme_font_size_override("font_size",title_size);title.add_theme_color_override("font_color",view.host.GOLD if android else Palette.SAKURA);tile.add_child(title)
 var caption_y=title.position.y+title.size.y+1
 var owner=spell_owner_label(tile,card)
 if owner!=null:
  owner.position=Vector2(text_x,caption_y);owner.size=Vector2(width-text_x-8,0)
  owner.size.y=owner.get_line_count()*owner.get_line_height()+2;caption_y+=owner.size.y
 var caption_size=maxi(14,roundi(metrics.small*0.7)) if android else 14
 var caption=Label.new();caption.name="StackCaption";caption.text=entry_caption(entry)
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING if android else TextServer.OVERRUN_TRIM_ELLIPSIS
 # Phone captions carry chosen modes that are not repeated anywhere else.
 caption.max_lines_visible=-1 if android else 4;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption.position=Vector2(text_x,caption_y);caption.size=Vector2(width-text_x-8,maxf(caption_size+4,thumb.y-title.size.y-6) if android else thumb.y-18)
 caption.add_theme_font_size_override("font_size",caption_size);caption.add_theme_color_override("font_color",view.host.WHITE if android else Palette.WASHI)
 caption.visible=not caption.text.is_empty();tile.add_child(caption)
 if not caption.visible:
  # Without effect text, give long names a second line instead of clipping.
  title.clip_text=false;title.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY;title.max_lines_visible=2
  title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.size.y=(title_size+7)*2
  if owner!=null:owner.position.y=title.position.y+title.size.y+1
 if caption.visible:
  # Grow the row for wrapped effects instead of hiding them behind the tooltip.
  var lines=caption.get_line_count() if android else mini(caption.get_line_count(),4)
  caption.size.y=maxf(caption.size.y,lines*caption.get_line_height()+4.0)
  tile.custom_minimum_size.y=maxf(tile.custom_minimum_size.y,caption.position.y+caption.size.y+6.0)
 if owner!=null:tile.custom_minimum_size.y=maxf(tile.custom_minimum_size.y,owner.position.y+owner.size.y+6.0)
 bind_tile_input(tile,entry,card,resolving_id)
 if android:bind_touch(tile,entry,card,resolving_id)
 tile.tooltip_text=entry.name+("\n"+caption.text if not caption.text.is_empty() else "")
 tiles[entry.id]={"tile":tile,"caption":caption,"art":art,"compact":true,"owner":int(entry.get("owner",-1)),"kind":entry.kind}
 if entry.id not in old_ids:arrive(row)
 if entry.kind=="ability" and entry.id not in old_ids:call_deferred("animate_ability",entry.id,entry.source.duplicate(true))

func base_style(parts: Dictionary,resolving: bool) -> StyleBoxFlat:
 var style=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT
 if view.is_android:
  style.set_corner_radius_all(8)
  if parts.compact:
   style.bg_color=Color("#4a2e3ee8") if Palette.enabled else Color("#13202ee8");style.set_border_width_all(1)
   style.border_width_left=5;style.border_color=owner_ink(parts.owner)
  else:
   # _process() pulses this aura; a fresh arrival flares it once.
   style.set_border_width_all(3);style.border_color=RESOLVING_GLOW if resolving else LEAD_GLOW
   style.shadow_size=16;style.shadow_color=Color(RESOLVING_GLOW if resolving else LEAD_GLOW,0.55)
   style.expand_margin_left=3;style.expand_margin_right=3;style.expand_margin_top=3;style.expand_margin_bottom=3
  return style
 if not compact_enabled():return style
 style.set_corner_radius_all(8)
 if parts.compact:
  style.bg_color=Color("#4a2e3ee8");style.set_border_width_all(1)
  # A side stripe tells whose effect it is without reading the name.
  style.border_width_left=4;style.border_color=owner_ink(parts.owner)
 if resolving:
  style.set_border_width_all(3);style.border_color=Palette.SAKURA
  style.shadow_color=Color(0.96,0.55,0.66,0.45);style.shadow_size=10
  style.expand_margin_left=3;style.expand_margin_right=3;style.expand_margin_top=3;style.expand_margin_bottom=3
 return style

func owner_ink(owner: int) -> Color:
 if owner<0:return Color("#6b4458")
 return Color("#7fd1b9") if owner==view.local_seat else Color("#e0655a")

func _process(delta: float):
 flare=maxf(0.0,flare-delta*1.4)
 for glow in glow_styles:
  var pulse=0.5+0.5*sin(float(Time.get_ticks_msec())*TAU/(700.0 if glow.color==RESOLVING_GLOW else 1300.0))
  var style: StyleBoxFlat=glow.style
  style.shadow_size=int(12+10*pulse+18*flare)
  style.shadow_color=Color(glow.color,minf(1.0,0.35+0.35*pulse+0.3*flare))
  if glow.border:style.border_color=glow.color.lerp(Color("#ffe2a8"),minf(1.0,0.45*pulse+0.5*flare))
 if resolving_style==null:return
 var level=0.5+0.5*sin(float(Time.get_ticks_msec())*TAU/1400.0)
 resolving_style.border_color=Palette.SAKURA.lerp(Palette.VERMILION,level)
 resolving_style.shadow_color=Color(0.96,0.45,0.55,0.3+0.25*level)

func arrive(row: Control):
 if not is_inside_tree():return
 if view.is_android:
  if row.get_index()==0:flare=1.0
 elif not compact_enabled():return
 row.modulate.a=0.0
 var tween=create_tween().bind_node(row)
 tween.tween_property(row,"modulate:a",1.0,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Resolved abilities have no card movement, so fade them out in place.
## Cards leaving the stack are animated by the reveal player from card_rect().
func dissolve(id):
 if not compact_enabled() or not tiles.has(id) or tiles[id].kind!="ability":return
 if not is_instance_valid(view.effects) or not entry_rect(id).has_area():return
 var art: TextureRect=tiles[id].art
 if not is_instance_valid(art) or art.texture==null or tiles[id].tile.modulate.a<0.5:return
 var face=art.get_global_rect().intersection(scroll.get_global_rect())
 if not face.has_area():return
 var ghost=TextureRect.new();ghost.texture=art.texture;ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ghost.position=face.position;ghost.size=face.size;ghost.pivot_offset=face.size*0.5
 ghost.modulate=Color(1.0,0.86,0.9,1.0);view.effects.add_child(ghost)
 var tween=ghost.create_tween().set_parallel(true)
 tween.tween_property(ghost,"position:y",face.position.y-26,0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 tween.tween_property(ghost,"scale",Vector2(1.08,1.08),0.42)
 tween.tween_property(ghost,"modulate:a",0.0,0.42)
 tween.chain().tween_callback(ghost.queue_free)

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
  if tiles[id].tile.get_meta("uid")==uid:
   if not tiles[id].compact:return arrow_rect(id)
   if not visible or collapsed:return Rect2()
   return view.clipped_arrow_rect(tiles[id].art.get_global_rect(),scroll.get_global_rect())
 return Rect2()
func arrival_rect() -> Rect2:
 if collapsed and is_instance_valid(toggle_button):return toggle_button.get_global_rect()
 var arrival=ANDROID_CARD_SIZE if view.is_android else LEAD_SIZE if compact_enabled() and not tiles.is_empty() else CARD_SIZE
 var origin=scroll.get_global_rect().position
 if compact_enabled():origin+=Vector2(maxf(0,(scroll.size.x-arrival.x)*0.5),22)
 return Rect2(origin,arrival)
func inspect_at(point:Vector2) -> bool:
 for id in tiles:
  if entry_rect(id).has_point(point):
   var tile=tiles[id].tile;view.inspect_card(tile.get_meta("card_id"),tile.get_meta("uid"));return true
 return false
func animate_ability(id:int,source:Dictionary):
 await get_tree().process_frame
 if not is_instance_valid(view) or not tiles.has(id):return
 var dest=entry_rect(id) if not tiles[id].compact else tiles[id].art.get_global_rect().intersection(scroll.get_global_rect())
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
