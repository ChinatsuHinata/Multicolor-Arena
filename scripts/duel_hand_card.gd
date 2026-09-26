extends "res://scripts/live_tooltip_panel.gd"
const CostDisplay=preload("res://scripts/card_cost_display.gd")
const HexCost=preload("res://scripts/cost_hex_display.gd")
const ConditionalFrame=preload("res://scripts/conditional_frame_pulse.gd")
## Clicking begins a private declaration; payment still requires confirmation.
var view
var uid=0
var card_id=""
var art_id=""
var hidden_card=false
var art: TextureRect
var cost_icons: Control
func build(owner_view,instance: Dictionary,hidden: bool=false):
 view=owner_view; uid=instance.uid; card_id=instance.card_id; hidden_card=hidden
 art_id=instance.get("art_id","")
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 art=TextureRect.new(); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.texture=view.host.texture("back") if hidden else view.card_texture(instance)
 add_child(art)
 if not hidden:
  cost_icons=HexCost.new();cost_icons.position=Vector2(3,5);cost_icons.z_index=2;add_child(cost_icons)
  update_cost(view.engine.cards[card_id].cost,view.engine.cards[card_id].get("variable_cost",""))
 if hidden: tooltip_text="对手手牌 · 未公开"
 else: tooltip_text=view.hand_card_tooltip(instance)
 gui_input.connect(input_card)
func update_cost(cost: Dictionary,variable_color: String=""):
 if is_instance_valid(cost_icons):cost_icons.configure(cost,true,size.x,minf(38.0,size.x*0.24),variable_color)
func update_style(ready: bool,selected: bool,conditional: bool=false):
 # Only gameplay highlights surround hand cards; idle cards have no frame.
 var style=StyleBoxFlat.new()
 style.bg_color=Color.TRANSPARENT
 if ready or selected or conditional:
  style.set_border_width_all(4)
  style.expand_margin_left=4; style.expand_margin_right=4
  style.expand_margin_top=4; style.expand_margin_bottom=4
  style.border_color=Color("#ffd65c") if selected else Color("#359bff")
  style.shadow_color=Color(1.0,0.67,0.13,0.72) if selected else Color(0.12,0.48,1.0,0.65)
  style.shadow_size=10 if selected else 7
 add_theme_stylebox_override("panel",style)
 ConditionalFrame.apply(self,style,conditional and not selected and not hidden_card)
 if not is_instance_valid(art): return
 art.position=Vector2.ZERO; art.size=size
func input_card(event: InputEvent):
 if not event is InputEventMouseButton or not event.pressed: return
 if event.button_index==MOUSE_BUTTON_RIGHT:
  view.inspect_card("back" if hidden_card else card_id,0 if hidden_card else uid,"对手手牌 · 未公开" if hidden_card else "")
  accept_event()
 elif event.button_index==MOUSE_BUTTON_LEFT and not hidden_card:
  if view.picker_active():
   var c=view.engine.find_card(uid)
   if not c.is_empty(): view.choose_target(view.engine.ref_target(c))
  elif view.debug_mode and view.can_begin_debug_drag(): view.begin_debug_drag(uid,get_global_transform()*event.position)
  else: view.hand_clicked(uid)
  accept_event()
