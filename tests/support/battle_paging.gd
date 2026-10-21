extends RefCounted

static func visible_hand_regions(view) -> Array:
 var regions=[]
 if not view.hand_scroll.is_visible_in_tree():return regions
 var viewport=view.hand_scroll.get_global_rect()
 for card in view.hand_nodes.values():
  if not is_instance_valid(card) or not card.is_visible_in_tree():continue
  var visible_card=card.get_global_rect().intersection(viewport)
  if visible_card.has_area():regions.append(visible_card)
 for bar in [view.hand_scroll.get_h_scroll_bar(),view.hand_scroll.get_v_scroll_bar()]:
  if bar.is_visible_in_tree():regions.append(bar.get_global_rect())
 return regions

static func palette_row(view,who: int) -> Rect2:
 var row=Rect2()
 for descriptor in view.table.descriptors.values():
  if descriptor.zone!="palette" or descriptor.owner!=who or descriptor.uid<=0:continue
  var rect=view.projected_card_rect(view.table.visuals[descriptor.key])
  row=row.merge(rect) if row.has_area() else rect
 return row