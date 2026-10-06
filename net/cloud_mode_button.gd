extends Button

var outline=PackedVector2Array()

func _init():
 text="云端";tooltip_text="进入云端联机"
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","disabled","focus"]:
  add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for color in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
  add_theme_color_override(color,Color.TRANSPARENT)
 for changed in [mouse_entered,mouse_exited,focus_entered,focus_exited,button_down,button_up,resized]:
  changed.connect(queue_redraw)
 var curve=Curve2D.new();curve.bake_interval=2.0
 curve.add_point(Vector2(68,167),Vector2.ZERO,Vector2(-33,0))
 curve.add_point(Vector2(10,114),Vector2(0,28),Vector2(0,-26))
 curve.add_point(Vector2(53,64),Vector2(-24,4),Vector2(3,-32))
 curve.add_point(Vector2(113,9),Vector2(-32,0),Vector2(26,0))
 curve.add_point(Vector2(172,48),Vector2(-10,-23),Vector2(10,-11))
 curve.add_point(Vector2(212,30),Vector2(-15,0),Vector2(27,0))
 curve.add_point(Vector2(266,76),Vector2(-4,-26),Vector2(7,-3))
 curve.add_point(Vector2(289,72),Vector2(-8,0),Vector2(33,0))
 curve.add_point(Vector2(348,131),Vector2(0,-33),Vector2(0,20))
 curve.add_point(Vector2(310,167),Vector2(22,0))
 curve.add_point(Vector2(68,167))
 outline=curve.get_baked_points()
 outline.resize(outline.size()-1)

func _draw():
 var factor=minf(size.x/360.0,size.y/180.0)
 var origin=(size-Vector2(360,180)*factor)*0.5
 var points=PackedVector2Array()
 for point in outline:points.append(origin+point*factor)
 var fill=Color("#dce8ee")
 var border=Color("#9db9c9")
 if disabled:fill=Color("#8c9ba3")
 elif is_pressed():fill=Color("#abc7d8");border=Color("#e8c77e")
 elif is_hovered():fill=Color("#f0f6fa");border=Color("#e8c77e")
 if has_focus() and not disabled:border=Color("#e8c77e")
 draw_colored_polygon(points,fill)
 points.append(points[0])
 draw_polyline(points,border,3.0 if has_focus() else 2.0,true)
 var font=get_theme_font("font")
 var font_size=get_theme_font_size("font_size")
 var measured=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
 var center=origin+Vector2(180,120)*factor
 var baseline=center.y+(font.get_ascent(font_size)-font.get_descent(font_size))*0.5
 draw_string(font,Vector2(center.x-measured.x*0.5,baseline),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#142835"))
