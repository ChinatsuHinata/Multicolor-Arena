extends Control
## Port of the simulator's cover art and landscape tween; rules stay in the view.
const UnknownArt=preload("res://scripts/unknown_card_art.gd")
var board
var card={}
var key=""
var art: TextureRect
var front: Control
var landscape=false
var geometry_initialized=false
var rotation_tween: Tween
var placement_tween: Tween
var dash_tween: Tween
var home=Rect2()
var legal=false
var selected=false
var held=false
var progress=0.0
var unknown_material: ShaderMaterial

func _ready():
 mouse_filter=MOUSE_FILTER_STOP
 var mask=Panel.new();mask.mouse_filter=MOUSE_FILTER_IGNORE;mask.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 var rounded=StyleBoxFlat.new();rounded.bg_color=Color.WHITE;rounded.set_corner_radius_all(6)
 mask.add_theme_stylebox_override("panel",rounded);mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY;add_child(mask)
 art=TextureRect.new();art.mouse_filter=MOUSE_FILTER_IGNORE
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 art.clip_contents=true;mask.add_child(art)
 front=Control.new();front.mouse_filter=MOUSE_FILTER_IGNORE;add_child(front);front.draw.connect(draw_front)
 resized.connect(update_geometry)
 mouse_entered.connect(func():art.material=null)
 mouse_exited.connect(func():art.material=unknown_material)

func configure(c: Dictionary,available: Array,chosen: Array,targeting: bool,rotate_tapped: bool=true):
 card=c;key="card_"+str(c.uid)
 var texture_key=str(c.card_id)+":"+str(c.get("art_id",""))+":"+str(UnknownArt.active(board.view.engine,c))
 if art.get_meta("texture_key","")!=texture_key:
  art.texture=board.view.card_texture(c);art.material=null
  unknown_material=null
  if UnknownArt.active(board.view.engine,c):
   unknown_material=ShaderMaterial.new();unknown_material.shader=UnknownArt.CanvasNoise;art.material=unknown_material
  art.set_meta("texture_key",texture_key)
 legal=c.uid in available;selected=c.uid in chosen
 var tapped=c.get("tapped",false)
 modulate=Color(0.78,0.78,0.78,0.45 if targeting and not legal else 1.0) if tapped else Color(1,1,1,0.45 if targeting and not legal else 1.0)
 var next_landscape=rotate_tapped and tapped
 var changed=landscape!=next_landscape;landscape=next_landscape
 update_geometry()
 if not geometry_initialized:
  art.rotation=PI/2 if landscape else 0.0;geometry_initialized=true
 elif changed:
  if is_instance_valid(rotation_tween):rotation_tween.kill()
  rotation_tween=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  rotation_tween.tween_property(art,"rotation",PI/2 if landscape else 0.0,0.18)
 queue_redraw();front.queue_redraw()

func place(rect: Rect2):
 if home==rect:return
 var first=not home.has_area();home=rect
 if is_instance_valid(placement_tween):placement_tween.kill()
 if is_instance_valid(dash_tween):dash_tween.kill()
 if first:
  position=rect.position;size=rect.size
 else:
  placement_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  placement_tween.tween_property(self,"position",rect.position,0.18)
  placement_tween.tween_property(self,"size",rect.size,0.18)

func update_geometry():
 if not is_node_ready():return
 art.size=Vector2(size.y,size.x) if landscape else size
 art.pivot_offset=art.size/2;art.position=size/2-art.size/2
 front.size=size;queue_redraw();front.queue_redraw()

func _draw():
 var style=StyleBoxFlat.new();style.bg_color=Color("#1b1420");style.set_corner_radius_all(6)
 draw_style_box(style,Rect2(Vector2.ZERO,size))

func draw_front():
 if selected or legal:
  var style=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT;style.set_corner_radius_all(6)
  style.border_color=Color("#e9c175") if selected else Color("#5aa8ff");style.set_border_width_all(3)
  if legal and not selected:style.shadow_color=Color("#5aa8ff",0.35);style.shadow_size=7
  front.draw_style_box(style,Rect2(Vector2.ZERO,size))
 if held:front.draw_arc(size/2,minf(size.x,size.y)*0.36,-PI/2,-PI/2+TAU*progress,48,Color("#e9c175"),3,true)

func hit_rect() -> Rect2:
 var extent=size.max(Vector2.ONE*board.view.host.ui_metrics.hit)
 return Rect2((size-extent)/2,extent)

func _has_point(point: Vector2) -> bool:
 return hit_rect().has_point(point)

func activate():
 board.view.object_clicked(card.uid)

func inspect():
 board.view.android_inspection_allowed=true
 board.view.inspect_card(card.card_id,card.uid,"",card.get("art_id",""))
 board.view.android_inspection_allowed=false

func dash(direction: float):
 if is_instance_valid(placement_tween):placement_tween.kill()
 if is_instance_valid(dash_tween):dash_tween.kill()
 position=home.position
 dash_tween=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 dash_tween.tween_property(self,"position",home.position+Vector2(0,direction*24),0.12)
 dash_tween.tween_property(self,"position",home.position,0.18)
