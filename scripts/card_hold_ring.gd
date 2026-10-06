extends Control
## Shared one-second inspection feedback in viewport coordinates.
signal completed
var duration=1.0
var progress=0.0
var started_ms=0
var valid: Callable
var radius=24.0

func _ready():
 name="CardHoldRing"
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=4096
 started_ms=Time.get_ticks_msec()
 queue_redraw()

func _notification(what):
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:queue_free()

func _process(_delta):
 if valid.is_valid() and not valid.call():queue_free();return
 # Show the completed ring for a frame before opening the details.
 if progress>=1.0:
  set_process(false);completed.emit();queue_free();return
 progress=minf(1.0,float(Time.get_ticks_msec()-started_ms)/(duration*1000.0))
 queue_redraw()

func _draw():
 draw_arc(Vector2.ZERO,radius,-PI/2,TAU-PI/2,96,Color(0.02,0.04,0.07,0.85),7,true)
 draw_arc(Vector2.ZERO,radius,-PI/2,TAU-PI/2,96,Color("#e8c77e",0.25),3.5,true)
 if progress>0:
  draw_arc(Vector2.ZERO,radius,-PI/2,-PI/2+TAU*progress,96,Color("#ffe3a1"),4,true)
  draw_circle(Vector2.from_angle(-PI/2+TAU*progress)*radius,2.8,Color("#fff4ce"))
