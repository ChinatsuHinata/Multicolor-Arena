extends "res://scripts/stack_arrows.gd"
## The prescribed action stays visible while its native animation plays.
func _process(_delta):
 if not is_instance_valid(view) or view.engine==null:return
 arrows=view.recorded_action_arrows();queue_redraw()

func _draw():
 super._draw()
 if arrows.is_empty():return
 var point=(arrows[0].from+arrows[0].to)*0.5
 draw_circle(point,14,Color("#101c28"))
 draw_string(ThemeDB.fallback_font,point+Vector2(-6,6),str(view.recorded_arrow_index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#ffe8a2"))
