extends Control
## One persistent course host; scene switches replace only the presentation.
const EditorHost=preload("res://scripts/tutorial/editor_host.gd")
var host
var runtime
var is_android=false
var tutorial_controls_enabled=true
var surface: Control
var content: Control
var tutorial_guide
var editor_host
var engine
var scene_frame: Panel
var presented_scenario_id=""

func begin(app,flow):
 host=app;runtime=flow;is_android=host.is_android
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(runtime)
 runtime.scenario_changed.connect(rebuild)
 runtime.adapter.observed.connect(func(event):
  if event.type=="state_changed" and runtime.adapter.scene_type=="battlefield" and is_instance_valid(surface):surface.call_deferred("render"))
 rebuild()

func rebuild():
 # A task reset restores the same engine and scenario. Keep the 3D surface,
 # textures and guide alive instead of allocating a second full battle view.
 if is_instance_valid(surface) and runtime.adapter.scene_type=="battlefield" and presented_scenario_id==runtime.adapter.scenario_id and engine==runtime.adapter.engine:
  surface.sync_tutorial_scenario()
  return
 if is_instance_valid(content):
  if is_instance_valid(tutorial_guide):tutorial_guide.detach_runtime()
  if is_instance_valid(surface) and surface.has_method("revealing"):surface.reveal_player.reset()
  if host.duel_view==surface:host.duel_view=null
  content.process_mode=Node.PROCESS_MODE_DISABLED
  remove_child(content);content.queue_free()
 scene_frame=Panel.new();scene_frame.name="TutorialScenario";add_child(scene_frame)
 scene_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene_frame.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 content=scene_frame
 editor_host=null;engine=runtime.adapter.engine
 presented_scenario_id=runtime.adapter.scenario_id
 host.screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 host.screen.position=Vector2.ZERO;host.screen.size=host.get_viewport_rect().size
 if runtime.adapter.scene_type=="battlefield":
  surface=preload("res://scripts/duel_view.gd").new();surface.tutorial_runtime=runtime;surface.tutorial_external=true
  host.duel_view=surface
  content.add_child(surface);surface.begin(host,{},{},0)
 else:
  # Draw native controls directly into the window. A fitted SubViewport
  # rasterized card art/text before scaling it a second time on desktop.
  editor_host=EditorHost.new();editor_host.owner_view=self;content.add_child(editor_host)
  editor_host.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  surface=editor_host;editor_host.configure(self,runtime)
 tutorial_guide=preload("res://scripts/tutorial/guide.gd").new()
 (content if runtime.adapter.scene_type=="battlefield" else surface).add_child(tutorial_guide)
 tutorial_guide.build(self,runtime)
 if runtime.adapter.scene_type=="battlefield":surface.tutorial_guide=tutorial_guide

func _exit_tree():
 if is_instance_valid(host) and host.duel_view==surface:host.duel_view=null

func guide_rect() -> Rect2:
 if runtime.adapter.scene_type=="battlefield":return Rect2()
 var safe=get_global_rect().intersection(host.ui_metrics.safe).grow(-host.ui_metrics.gap)
 if not safe.has_area():return Rect2()
 if runtime.adapter.scene_type=="deck":
  return Rect2(safe.position-global_position,Vector2(maxf(100,side_width()-host.ui_metrics.gap-safe.position.x),safe.size.y))
 # The compact guide lives inside the deck/editor, below the example cards.
 # It can be hidden to inspect any controls under it; sorting stays exposed.
 var area=editor_host.main_scroll.get_global_rect().intersection(safe) if not is_android and is_instance_valid(editor_host.main_scroll) else safe
 var extent=Vector2(minf(520 if not is_android else 640,area.size.x),minf(296 if not is_android else 360,area.size.y))
 return Rect2(Vector2(area.get_center().x-extent.x*0.5,area.end.y-extent.y)-global_position,extent)

func side_width() -> float:
 return minf(size.x*0.44,clampf(size.x*0.32,340,520))

func deck_rect() -> Rect2:
 var safe=get_global_rect().intersection(host.ui_metrics.safe)
 var x=global_position.x+side_width()+host.ui_metrics.gap
 return Rect2(Vector2(x,safe.position.y)-global_position,Vector2(maxf(100,safe.end.x-x),safe.size.y))

func project_rect(rect: Rect2) -> Rect2:
 return rect

func component_rect(id: String) -> Rect2:
 var node=tutorial_component(id)
 if not is_instance_valid(node) or not node.is_visible_in_tree():return Rect2()
 return project_rect(node.get_global_rect())

func tutorial_component(id: String):
 if id in ["deck_surface","editor_surface"]:return editor_host.screen
 if runtime.adapter.scene_type!="battlefield":return null
 match id:
  "battlefield":return surface.stage
  "hand":return surface.hand_scroll
  "opponent_hand":return surface.opponent_layer
  "inspection":return surface.inspection
  "hud":return surface.hud
  "stack":return surface.stack_panel
 return null

func target_rect(target: Dictionary) -> Rect2:
 return project_rect(surface.target_rect(target)) if runtime.adapter.scene_type=="battlefield" else Rect2()

func apply_tutorial_presentation(value: Dictionary):
 if runtime.adapter.scene_type=="battlefield":surface.apply_tutorial_presentation(value)

func set_tutorial_card_highlights(targets: Array):
 if runtime.adapter.scene_type=="battlefield":surface.set_tutorial_card_highlights(targets)

func _process(_delta):
 host.screen.position=Vector2.ZERO;host.screen.size=host.get_viewport_rect().size
 if runtime.adapter.scene_type=="battlefield" and is_instance_valid(surface):surface.tutorial_controls_enabled=tutorial_controls_enabled
