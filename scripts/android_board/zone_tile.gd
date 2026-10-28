extends Control
## Only the simulator's permanent, summary, zone and pager drawing is retained.
const INK=preload("res://scripts/cost_hex_display.gd").INK
var board
var kind="zone"
var props={}
var action: Callable
var inspect_action: Callable
var disabled=false

func configure(rect: Rect2,value: Dictionary,callback: Callable):
 position=rect.position-board.position;size=rect.size;props=value;action=callback
 kind=props.get("kind","zone");disabled=props.get("disabled",false)
 mouse_filter=MOUSE_FILTER_IGNORE if disabled else MOUSE_FILTER_STOP
 modulate.a=0.45 if props.get("empty",false) else 1.0
 queue_redraw()

func _has_point(point: Vector2) -> bool:
 return not disabled and hit_rect().has_point(point)

func hit_rect() -> Rect2:
 var extent=size.max(Vector2.ONE*board.view.host.ui_metrics.hit)
 return Rect2((size-extent)/2,extent)

func activate():
 if not disabled and action.is_valid():action.call()

func inspect():
 if inspect_action.is_valid():inspect_action.call()

func text(value: String,at: Vector2,fs: int,color: Color=Color.WHITE,width: float=-1):
 draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,color)

func fit(value: String,width: float,fs: int) -> int:
 while fs>8 and get_theme_default_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width:fs-=1
 return fs

func hex(center: Vector2,width: float,color: Color):
 var points=PackedVector2Array()
 for i in range(6):points.append(center+Vector2(sin(i*TAU/6),-cos(i*TAU/6))*width/sqrt(3.0))
 draw_colored_polygon(points,color)

func _draw():
 var m=board.view.host.ui_metrics
 var style=board.view.host.style(Color("#1b1420",0.96),Color("#5aa8ff") if props.get("legal",false) else Color("#6a5265"))
 style.set_corner_radius_all(6);style.set_border_width_all(2 if props.get("legal",false) else 1)
 draw_style_box(style,Rect2(Vector2.ZERO,size))
 match kind:
  "summary":draw_summary()
  "permanent":
   var texture=props.get("texture")
   if texture is Texture2D:
    var dest=Rect2(2,2,size.x-4,size.y-4)
    var scale_value=maxf(dest.size.x/texture.get_width(),dest.size.y/texture.get_height());var crop=dest.size/scale_value
    draw_texture_rect_region(texture,dest,Rect2((texture.get_size()-crop)/2,crop),Color(1,1,1,0.85))
    draw_rect(Rect2(2,size.y-m.small-9,size.x-4,m.small+7),Color("#1b1420",0.85))
   text(props.label,Vector2(5,size.y-6),m.small,Color.WHITE,size.x-10)
   if props.has("count"):
    var value=str(props.count);var width=get_theme_default_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,m.small).x
    text(value,Vector2(size.x-width-5,size.y-6),m.small)
  "pager":
   var caption=("‹"+str(props.count)) if props.dir<0 else (str(props.count)+"›")
   var fs=m.small;var width=get_theme_default_font().get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
   text(caption,Vector2((size.x-width)/2,(size.y+fs)/2),fs,Color("#e9c175"))
   if props.get("selected_hidden",false):draw_circle(Vector2(size.x-10,10),4,Color("#e9c175"))
   if props.get("legal",false):draw_circle(Vector2(10,10),4,Color("#5aa8ff"))
  _:
   var caption=props.get("label","");var fs=fit(caption,size.x-10,m.small)
   text(caption,Vector2(5,(size.y+fs)/2-2),fs,Color.WHITE,size.x-10)
 if int(props.get("usable",0))>0:
  var caption="▶"+str(props.usable);var width=get_theme_default_font().get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,m.small).x+8
  draw_style_box(board.view.host.style(Color("#5aa8ff"),Color.TRANSPARENT),Rect2(size.x-width,0,width,m.small+6))
  text(caption,Vector2(size.x-width+4,m.small+1),m.small)

func draw_summary():
 var m=board.view.host.ui_metrics;var fs=m.small
 var title_fs=fit(props.title,size.x-10,fs)
 text(props.title,Vector2(5,title_fs+5),title_fs,Color.WHITE,size.x-10)
 var before=props.before;var after=props.after;var paying=props.pay
 var total=(str(before.total)+"→"+str(after.total)) if paying else ("可用 %d/%d" % [before.total,before.count])
 # Wrap the summary's second section inside the fixed tile, keeping all five
 # colors readable even when the life column is only 160 logical pixels wide.
 var total_fs=fit(total,size.x-10,mini(fs,roundi(size.y*0.24)))
 var columns=3 if paying else 5;var chip_width=(size.x-10)/columns
 var chip_fs=fit("0→0" if paying else "0",chip_width-10,mini(fs,roundi(size.y*0.19)) if paying else fs)
 text(total,Vector2(5,maxf(title_fs+total_fs+4,size.y*(0.45 if paying else 0.62))),total_fs,Color("#e9c175"))
 for i in range(5):
  var color=board.view.engine.COLORS[i];var x=5+(i%columns)*chip_width
  var y=size.y-7 if not paying or i>=columns else size.y*0.72
  var ink=INK[color];var number=str(before[color])+"→"+str(after[color]) if paying else str(before[color])
  if before[color]==0:ink.a=0.45
  hex(Vector2(x+3,y-chip_fs*0.35),6,ink)
  text(number,Vector2(x+8,y),chip_fs,ink)
