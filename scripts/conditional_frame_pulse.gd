extends Node
## Pulse only the frame. Card art, cost icons and input remain steady.
var frame: StyleBoxFlat
static func apply(panel: Control,style: StyleBoxFlat,active: bool):
 var pulse=panel.get_node_or_null("ConditionalFramePulse")
 panel.set_meta("conditional_frame",active)
 if not active:
  if pulse!=null:panel.remove_child(pulse);pulse.queue_free()
  return
 if pulse==null:
  pulse=load("res://scripts/conditional_frame_pulse.gd").new()
  pulse.name="ConditionalFramePulse";panel.add_child(pulse)
 pulse.frame=style;pulse.refresh()
func refresh():
 if frame==null:return
 var level=0.5+0.5*sin(float(Time.get_ticks_msec())*TAU/2400.0)
 frame.border_color=Color("#c74b51").lerp(Color("#f26b70"),level)
 frame.shadow_color=Color(0.92,0.20,0.25,0.48+0.10*level)
func _process(_delta: float):refresh()
