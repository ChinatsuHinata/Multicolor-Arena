extends Control
## Hexagonal portraits sample the illustration area of the original card texture.
const TITLES=["毛玉级","妖精级","天狗级","妖怪级","妖怪贤者"]
const CARDS=["character-ucs-063","5","character-fdf-101","91","character-fdf-ex02"]
const CROPS=[Rect2(0.08,0.14,0.84,0.60),Rect2(0.26,0.15,0.50,0.36),Rect2(0.35,0.12,0.43,0.31),Rect2(0.44,0.13,0.48,0.34),Rect2(0.40,0.16,0.43,0.31)]
const COLORS=[Color("bfcad7"),Color("74dcb7"),Color("84c6ef"),Color("ec9d75"),Color("d4a5ff")]
var rank: Dictionary={}
var portrait: Texture2D
var tier=0
var number: Label

static func caption(value: Dictionary) -> String:
 var index=clampi(int(value.get("tier",0)),0,4)
 if index==4:return "妖怪贤者 · 第 %d 名" % maxi(1,int(value.get("position",1)))
 return "%s %d · %s%s" % [TITLES[index],int(value.get("level",2 if index==0 else 3)),"★".repeat(clampi(int(value.get("stars",0)),0,3)),"☆".repeat(3-clampi(int(value.get("stars",0)),0,3))]

func setup(value: Dictionary,cards: Dictionary):
 rank=value.duplicate(true);tier=clampi(int(rank.get("tier",0)),0,4)
 var path=str(cards.get(CARDS[tier],{}).get("image",""))
 portrait=load(path) if not path.is_empty() else null
 tooltip_text=caption(rank)
 custom_minimum_size=Vector2(92,100);mouse_filter=Control.MOUSE_FILTER_IGNORE
 size_flags_vertical=Control.SIZE_SHRINK_CENTER;size_flags_horizontal=Control.SIZE_SHRINK_CENTER
 if not is_instance_valid(number):
  number=Label.new();number.name="RankNumber";add_child(number)
  number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;number.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
  number.add_theme_color_override("font_color",Color.WHITE)
  number.add_theme_color_override("font_outline_color",Color("14202f"));number.add_theme_constant_override("outline_size",9)
  number.add_theme_font_size_override("font_size",28)
 number.text=str(rank.get("position",1)) if tier==4 else str(rank.get("level",2 if tier==0 else 3))
 queue_redraw()

func _notification(what):
 if what==NOTIFICATION_RESIZED:queue_redraw()

func _draw():
 var radius=minf(size.x,size.y)*0.47
 var center=Vector2(size.x*0.5,size.y*0.47)
 var points=PackedVector2Array();var uv=PackedVector2Array()
 for i in range(6):
  var direction=Vector2.from_angle(-PI*0.5+i*TAU/6.0)
  points.append(center+direction*radius)
  uv.append(CROPS[tier].position+(direction+Vector2.ONE)*0.5*CROPS[tier].size)
 if portrait!=null:draw_polygon(points,PackedColorArray([Color.WHITE]),uv,portrait)
 else:draw_colored_polygon(points,Color("243344"))
 points.append(points[0]);draw_polyline(points,COLORS[tier],4.0,true)
