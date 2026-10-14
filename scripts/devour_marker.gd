extends RefCounted
## Counter ownership is independent of the exiled card's owner.
const ICON=preload("res://assets/devour_scroll.svg")
const OWN_COLOR=Color("#ef4c55")
const ENEMY_COLOR=Color("#398bff")

static func active(card: Dictionary) -> bool:
 return card.get("zone","")=="exile" and card.get("devour_owner",-1) in [0,1] and card.get("card_id","")!="back" and not card.get("network_hidden",false)

static func color(card: Dictionary,local_seat: int) -> Color:
 return OWN_COLOR if card.get("devour_owner",-1)==local_seat else ENEMY_COLOR

static func apply(tile: Control,card: Dictionary,local_seat: int):
 var marker=tile.get_node_or_null("DevourMarker")
 if not active(card):
  if marker!=null:tile.remove_child(marker);marker.queue_free()
  return
 if marker==null:
  marker=TextureRect.new();marker.name="DevourMarker";tile.add_child(marker)
  marker.texture=ICON;marker.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  marker.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var width=clampf(tile.size.x*0.3,24,44)
 marker.size=Vector2.ONE*width
 marker.position=tile.size-marker.size-Vector2(7,7)
 marker.modulate=color(card,local_seat)

static func apply_pile(top: MeshInstance3D,card: Dictionary,local_seat: int):
 var marker=top.get_node_or_null("DevourMarker")
 if not active(card):
  if marker!=null:top.remove_child(marker);marker.queue_free()
  return
 if marker==null:
  marker=MeshInstance3D.new();marker.name="DevourMarker";top.add_child(marker)
  var shape=PlaneMesh.new();shape.size=Vector2.ONE*top.mesh.size.x*0.3;marker.mesh=shape
  var ink=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.cull_mode=BaseMaterial3D.CULL_DISABLED
  ink.albedo_texture=ICON;marker.material_override=ink
  var inset=Vector2.ONE*(shape.size.x/2+0.06)
  var corner=top.mesh.size/2-inset
  marker.position=Vector3(corner.x,0.006,corner.y)
 marker.material_override.albedo_color=color(card,local_seat)
