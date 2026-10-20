extends SceneTree
## Camera framing must ignore temporary HUD slivers and recover on the next layout.
const View=preload("res://scripts/duel_view.gd")
const Table=preload("res://scripts/duel_table.gd")

class Metrics:
 extends RefCounted
 var gap=10.0
 var hit=60.0

var view
var checks=0
var failures=[]

func _initialize():call_deferred("run")

func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func check_frame(title: String):
 var area=view.responsive.camera_focus_rect()
 var projected=view.projected_android_focus(view.android_focus_bounds())
 expect(view.table.camera.global_transform.is_finite() and view.table.camera_frame_scale<6.0,title+" keeps a finite, usable camera distance")
 expect(area.grow(2).encloses(projected),title+" frames the selected region")

func check_layout(top_down: bool,wide: bool):
 view.table.top_down_view=top_down;view.table.wide_playmat=wide
 var title=("2D" if top_down else "3D")+(" wide" if wide else " normal")
 for seat in [0,1]:
  view.local_seat=seat;view.table.local_seat=seat
  for who in [-1,seat,1-seat,seat,-1,1-seat]:
   view.android_palette_view=who>=0;view.android_focus_owner=who
   view.focus_palette_camera(false)
   check_frame(title+" seat %d focus %d" % [seat,who])
 view.android_palette_view=true;view.android_focus_owner=1-view.local_seat
 view.focus_palette_camera(false)
 var original=view.table.camera.global_transform
 var original_scale=view.table.camera_frame_scale
 var area=view.responsive.camera_focus_rect()
 # A panel can briefly leave just one pixel during opening/reflow.
 var panel=Panel.new();view.add_child(panel);view.android_choice_panel=panel
 panel.position=area.position-Vector2(20,20);panel.size=area.size+Vector2(40,9)
 view.focus_palette_camera(false)
 expect(view.table.camera.global_transform.is_equal_approx(original) and is_equal_approx(view.table.camera_frame_scale,original_scale),title+" a one-pixel HUD gap preserves the previous camera")
 expect(view.android_camera_area!=view.responsive.camera_focus_rect(),title+" a temporary HUD gap remains pending for reframing")
 panel.size=area.size+Vector2(9,40)
 view.focus_palette_camera(false)
 expect(view.table.camera.global_transform.is_equal_approx(original),title+" a one-pixel vertical gap also preserves the camera")
 panel.free();view.android_choice_panel=null
 view.focus_palette_camera(false);check_frame(title+" after panel closes")
 # Large touch metrics/logs must never push the palette frame into the hand.
 view.responsive.log_rect.position.y=view.HAND.position.y-100
 area=view.responsive.camera_focus_rect()
 expect(area.size.y>=view.responsive.metrics.hit*2 and area.end.y<=view.HAND.position.y,title+" cramped HUD keeps a useful frame above the hand")
 view.focus_palette_camera(false);check_frame(title+" cramped HUD")
 view.responsive.log_rect.position.y=100

func check_interrupted_switches(top_down: bool):
 view.table.top_down_view=top_down
 view.android_palette_view=false;view.focus_palette_camera(false)
 view.android_palette_view=true;view.android_focus_owner=view.local_seat
 view.focus_palette_camera(true)
 await create_timer(0.05).timeout
 view.android_focus_owner=1-view.local_seat;view.focus_palette_camera(true)
 await create_timer(0.05).timeout
 view.reset_camera_view()
 var reset=view.table.camera.global_transform
 await create_timer(0.35).timeout
 check_frame("interrupted switches "+str(top_down))
 expect(view.table.camera.global_transform.is_equal_approx(reset),"reset cancels the old camera animation "+str(top_down))

func run():
 view=View.new();root.add_child(view);view.set_process(false)
 view.is_android=true;view.STAGE=Rect2(0,0,1600,900);view.HAND=Rect2(260,660,1050,232)
 var viewport=SubViewport.new();viewport.size=Vector2i(1600,900);view.add_child(viewport);view.viewport=viewport
 var table=Table.new();viewport.add_child(table);view.table=table
 table.camera=Camera3D.new();table.add_child(table.camera);table.camera.current=true
 view.responsive.view=view;view.responsive.metrics=Metrics.new()
 view.responsive.toolbar_rect=Rect2(260,10,1300,60);view.responsive.log_rect=Rect2(260,100,1000,40)
 for top_down in [true,false]:
  for wide in [false,true]:check_layout(top_down,wide)
  await check_interrupted_switches(top_down)
 print("ANDROID CAMERA STABILITY: %d checks; %d failures" % [checks,failures.size()])
 view.free();quit(0 if failures.is_empty() else 1)
