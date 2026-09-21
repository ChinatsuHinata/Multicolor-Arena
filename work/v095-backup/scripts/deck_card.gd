extends Panel
signal preview_requested(id: String)
signal clicked(id: String, zone: String, index: int, right: bool)
var card_id=""
var source_zone=""
var source_index=-1
var dragged=false
var face_texture: Texture2D
func _ready():
 mouse_entered.connect(func(): preview_requested.emit(card_id))
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _gui_input(event):
 if event is InputEventMouseButton:
  if event.pressed: dragged=false
  elif not dragged and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
   clicked.emit(card_id,source_zone,source_index,event.button_index==MOUSE_BUTTON_RIGHT)
func _get_drag_data(_at):
 dragged=true
 var ghost=TextureRect.new()
 ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 ghost.texture=face_texture
 ghost.custom_minimum_size=Vector2(100,140)
 ghost.size=Vector2(100,140)
 ghost.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 ghost.modulate.a=0.85
 set_drag_preview(ghost)
 return {"card_id":card_id,"source_zone":source_zone,"source_index":source_index}

