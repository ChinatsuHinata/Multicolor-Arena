extends Panel
## Clicking begins a private declaration; payment still requires confirmation.
var view
var uid=0
var card_id=""
var hidden_card=false
var art: TextureRect
func build(owner_view,instance: Dictionary,hidden: bool=false):
 view=owner_view; uid=instance.uid; card_id=instance.card_id; hidden_card=hidden
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 art=TextureRect.new(); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.texture=load("res://assets/card_back.svg") if hidden else view.host.texture(card_id)
 add_child(art)
 if hidden: tooltip_text="对手手牌 · 未公开"
 else: tooltip_text=view.engine.cards[card_id].name
 gui_input.connect(input_card)
func update_style(ready: bool,selected: bool):
 var style=view.host.style(Color("#27313d"),view.host.GOLD if ready or selected else Color("#405167"))
 style.set_border_width_all(5 if ready or selected else 1)
 if ready or selected:
  style.border_color=Color("#ffd65c") if selected else Color("#359bff")
  style.shadow_color=Color(1.0,0.67,0.13,0.72) if selected else Color(0.12,0.48,1.0,0.65)
  style.shadow_size=10 if selected else 7
 add_theme_stylebox_override("panel",style)
 if not is_instance_valid(art): return
 art.position=Vector2(7,7); art.size=size-Vector2(14,14)
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
