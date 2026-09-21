extends Panel
## Hand tile: clicking selects only for mandatory choices; casting uses a mouse drag.
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
 add_theme_stylebox_override("panel",view.host.style(Color("#27313d"),view.host.GOLD if ready or selected else Color("#405167")))
 if not is_instance_valid(art): return
 art.position=Vector2(4,4); art.size=size-Vector2(8,8)
func input_card(event: InputEvent):
 if not event is InputEventMouseButton or not event.pressed: return
 if event.button_index==MOUSE_BUTTON_RIGHT:
  view.inspect_card("back" if hidden_card else card_id,0 if hidden_card else uid,"对手手牌 · 未公开" if hidden_card else "")
  accept_event()
 elif event.button_index==MOUSE_BUTTON_LEFT and not hidden_card:
  view.begin_hand_drag(uid,get_global_mouse_position())
  accept_event()
