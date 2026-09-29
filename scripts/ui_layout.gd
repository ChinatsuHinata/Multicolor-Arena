extends RefCounted
## Shared logical-pixel metrics. No Control scale is changed here.
## The window stretches with EXPAND; safe insets are converted from screen pixels.
const BASE_HEIGHT=900.0
const GOLD=Color("#e8c77e")
const TEXT=Color("#f0f3f6")
const MUTED=Color("#b2c2ce")
var touch=false
var safe=Rect2()
var gap=12.0
var padding=16.0
var hit=48.0
var body=18
var small=16
var title=28
var button_font=20

func measure(control: Control,mobile: bool,dpi_override: float=0.0,safe_override: Rect2=Rect2()):
 touch=mobile
 var logical=control.get_viewport_rect().size
 var window=control.get_window()
 var pixels=Vector2(window.size)
 var factor=pixels.y/maxf(1.0,logical.y)
 var dpi=dpi_override if dpi_override>0 else float(DisplayServer.screen_get_dpi())
 if dpi<=0:dpi=160.0
 var dp=dpi/160.0/maxf(0.1,factor)
 hit=maxf(64.0,ceilf(48.0*dp)) if touch else 48.0
 body=maxi(24,ceili(16.0*dp)) if touch else 18
 small=maxi(22,ceili(14.0*dp)) if touch else 16
 button_font=body
 title=body+8 if touch else 28
 gap=maxf(12.0,ceilf(6.0*dp)) if touch else 12.0
 padding=maxf(16.0,ceilf(8.0*dp)) if touch else 18.0
 safe=Rect2(Vector2.ZERO,logical)
 var physical_safe=safe_override
 if touch and not physical_safe.has_area() and OS.has_feature("android"):
  physical_safe=Rect2(DisplayServer.get_display_safe_area())
  physical_safe.position-=Vector2(DisplayServer.window_get_position())
 if physical_safe.has_area():
  physical_safe=physical_safe.intersection(Rect2(Vector2.ZERO,pixels))
  safe=Rect2(physical_safe.position/factor,physical_safe.size/factor).intersection(safe)
 # Keep controls away from rounded corners and gesture edges even if an OEM
 # reports the whole display as safe in immersive mode.
 safe=safe.grow(-padding)

func font_size(requested: int) -> int:
 if not touch:return requested
 if requested>=26:return maxi(title,requested)
 if requested>=18:return body
 return small

func panel_style(accent: bool=false) -> StyleBoxFlat:
 var s=StyleBoxFlat.new()
 s.bg_color=Color("#342d21") if accent else Color("#111f2b")
 s.border_color=GOLD if accent else Color("#293c49")
 s.set_border_width_all(1 if accent else 0)
 s.set_corner_radius_all(12)
 s.set_content_margin_all(padding)
 return s

func apply_theme(theme: Theme):
 theme.default_font_size=body
 for kind in ["Button","OptionButton","LineEdit","CheckButton","PopupMenu"]:
  theme.set_font_size("font_size",kind,button_font)
  theme.set_color("font_color",kind,TEXT)
 for kind in ["HBoxContainer","VBoxContainer","GridContainer"]:
  theme.set_constant("separation",kind,int(gap))
  theme.set_constant("h_separation",kind,int(gap))
  theme.set_constant("v_separation",kind,int(gap))
 theme.set_constant("v_separation","PopupMenu",int(hit-body))
 for kind in ["Button","OptionButton","LineEdit"]:
  for state in ["normal","hover","pressed","focus"]:
   var s=panel_style(state in ["pressed","focus"])
   s.bg_color=Color("#223b4b") if state=="hover" else Color("#514328") if state=="pressed" else Color("#192c3a")
   if state=="focus":s.bg_color=Color.TRANSPARENT
   s.content_margin_top=maxf(8,(hit-body*1.3)*0.5)
   s.content_margin_bottom=s.content_margin_top
   theme.set_stylebox(state,kind,s)

func button(control: BaseButton):
 control.custom_minimum_size.y=hit
 control.add_theme_font_size_override("font_size",button_font)
 control.focus_mode=Control.FOCUS_ALL
 if control is Button:
  control.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  control.tooltip_text=control.text
  var text_width=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button_font).x
  control.custom_minimum_size.x=maxf(hit,text_width+padding*2)

func columns(width: float) -> Dictionary:
 var library=maxf(340.0,hit*6.0+gap*5.0+padding*2.0) if touch else clampf(width*0.23,340,430)
 var details=clampf(width*0.18,250,340)
 var inline_details=width>=library+details+maxf(library+80,600)+gap*2
 return {"library":library,"details":details,"inline":inline_details}

func hand_layout(area: Rect2,count: int,compact: bool=false) -> Dictionary:
 var h=minf(area.size.y-24,160 if compact else 224 if touch else 204)
 var preferred=h/1.397
 var minimum=maxf(hit,94) if touch else 80.0
 var width=clampf((area.size.x-gap*maxi(0,count-1))/maxi(1,count),minimum,preferred)
 var stride=width+gap
 var extent=maxf(area.size.x,stride*count-gap)
 return {"card":Vector2(width,width*1.397),"stride":stride,"extent":extent,
  "inset":maxf(0,(area.size.x-(stride*count-gap))*0.5)}
