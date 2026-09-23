extends Control
## Pure-color, joined cost symbols. A zero is explicit; a one is the bare hex.
const CostDisplay=preload("res://scripts/card_cost_display.gd")
const INK={"红":Color("#e74f59"),"蓝":Color("#4a8df4"),"绿":Color("#2eba57"),"黄":Color("#e5cc3d"),"黑":Color("#393d46"),"灰":Color("#82848b")}
var symbols: Array=[]
var vertical=false
var hex_width=30.0
var hex_height=30.0
var step=30.0

static func tokens(cost: Dictionary,stack_vertical: bool=false,variable_color: String="") -> Array:
 var total=0
 for amount in cost.values():total+=maxi(0,int(amount))
 var expanded=not stack_vertical and total+(1 if not variable_color.is_empty() else 0)<=8
 var result=[]
 for key in CostDisplay.sorted_keys(cost):
  var count=maxi(0,int(cost[key]))
  var colors=Array(str(key).split("/"))
  if count==0:result.append({"colors":colors,"number":"0"})
  elif expanded:
   for i in range(count):result.append({"colors":colors,"number":""})
  else:result.append({"colors":colors,"number":"" if count==1 else str(count)})
 if not variable_color.is_empty():result.append({"colors":Array(variable_color.split("/")),"number":"X"})
 if result.is_empty():result.append({"colors":["灰"],"number":"0"})
 return result

func configure(cost: Dictionary,stack_vertical: bool=false,available_width: float=198.0,preferred_width: float=32.0,variable_color: String=""):
 vertical=stack_vertical;symbols=tokens(cost,vertical,variable_color)
 hex_width=preferred_width
 if not vertical:hex_width=minf(preferred_width,available_width/float(symbols.size()))
 hex_width=maxf(16.0,hex_width)
 # Point-up regular hexagon: side = height / 2 = width / sqrt(3).
 hex_height=hex_width*2.0/sqrt(3.0)
 step=hex_height*0.75 if vertical else hex_width
 var display_width=hex_width*symbols.size()
 var display_height=hex_height
 if vertical:
  display_width=hex_width*(1.5 if symbols.size()>1 else 1.0)
  display_height=hex_height+step*(symbols.size()-1)
 custom_minimum_size=Vector2(display_width,display_height)
 size=custom_minimum_size
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 queue_redraw()

func _draw():
 if symbols.is_empty():return
 var font=get_theme_default_font()
 for i in range(symbols.size()):
  var origin=symbol_origin(i)
  var points=hex_points(origin)
  var colors: Array=symbols[i].colors
  if colors.size()==1:draw_colored_polygon(points,INK.get(colors[0],INK["灰"]))
  else:
   var center=origin+Vector2(hex_width/2,hex_height/2)
   for edge in range(6):
    var middle=(points[edge]+points[(edge+1)%6])*0.5
    var index=0
    if colors.size()==2:index=0 if middle.x<center.x else 1
    else:index=mini(colors.size()-1,int(float(edge)*float(colors.size())/6.0))
    draw_colored_polygon(PackedVector2Array([center,points[edge],points[(edge+1)%6]]),INK.get(colors[index],INK["灰"]))
  var closed=PackedVector2Array(points);closed.append(points[0])
  draw_polyline(closed,Color("#d3d9dd"),1.7,true)
  var number: String=symbols[i].number
  if number.is_empty():continue
  var font_size=roundi(hex_width*0.68)
  var measured=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
  while measured.x>hex_width*0.76 and font_size>10:
   font_size-=1
   measured=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
  var center=origin+Vector2(hex_width/2,hex_height/2)
  var foreground=Color("#172027") if colors.size()==1 and colors[0]=="黄" else Color.WHITE
  var baseline=center.y+(font.get_ascent(font_size)-font.get_descent(font_size))*0.5
  draw_string(font,Vector2(center.x-measured.x/2,baseline),number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,foreground)

func symbol_origin(index: int) -> Vector2:
 if not vertical:return Vector2(step*index,0)
 if symbols.size()==1:return Vector2.ZERO
 return Vector2(hex_width*0.5 if index%2==0 else 0.0,step*index)

func hex_points(origin: Vector2) -> PackedVector2Array:
 return PackedVector2Array([
  origin+Vector2(hex_width*0.5,0),
  origin+Vector2(hex_width,hex_height*0.25),
  origin+Vector2(hex_width,hex_height*0.75),
  origin+Vector2(hex_width*0.5,hex_height),
  origin+Vector2(0,hex_height*0.75),
  origin+Vector2(0,hex_height*0.25)
 ])
