extends "res://scripts/stack_arrows.gd"
var workspace

func _process(_delta):
 if not is_instance_valid(workspace):return
 arrows=workspace.condition_arrows();queue_redraw()

func _draw():
 super._draw()
 for arrow in arrows:
  draw_arc(arrow.to,11,0,TAU,32,Color("#ffe8a2"),2,true)
