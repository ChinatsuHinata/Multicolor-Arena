extends Control
## Responsive side-column board. All actions are forwarded to duel_view.
const Card=preload("res://scripts/android_board/board_card.gd")
const Tile=preload("res://scripts/android_board/zone_tile.gd")
const CardPreviewHold=preload("res://scripts/card_preview_hold_settings.gd")
const LABELS={"leader":"自机","melody":"乐章","item":"道具","barrier":"结界","time":"时符"}
var view
var anchors={}
var cards={}
var tiles={}
var rows={}
var aliases={}
var destinations={}
var descriptors={}
var groups={}
var previous_units={}
var initialized=false
var targeting_stamp=""
var targeting_entered=false
var available=[]
var chosen=[]
var targeting=false
# Control.layout_mode is a native integer property; keep this string distinct.
var board_layout_mode=""
var band_h=0.0
var row_h=0.0
var left_column=Rect2()
var keep_colors_rect=Rect2()
var sheet: Panel
var sheet_rect=Rect2()
var opened={}
var opened_revision=-1
var opened_local=false
var pressed_control: Control
var finger=-2
var origin=Vector2.ZERO
var elapsed=0.0
var moved=false
var inspected=false
var combat_was_animating=false

func _ready():
 name="AndroidBoard";mouse_filter=MOUSE_FILTER_IGNORE
 sheet=Panel.new();sheet.name="RegionExpansion";sheet.mouse_filter=MOUSE_FILTER_STOP
 add_child(sheet);sheet.hide()

func sync():
 var B: Rect2=view.responsive.board_rect
 position=B.position;size=B.size;left_column=view.responsive.left_column_rect
 var hit=view.host.ui_metrics.hit;var g=view.host.ui_metrics.gap
 var inline_row_h=floorf((B.size.y-g*3)/2)
 board_layout_mode="inline" if inline_row_h>=hit*2+g else "band"
 if board_layout_mode=="inline":
  row_h=inline_row_h
 else:
  band_h=maxf(hit,roundf(B.size.y*0.15));row_h=floorf((B.size.y-band_h*2-g*4)/2)
 available=view.highlights();chosen=view.selected_uids()
 for resource in view.local.get("plan",[]):
  if resource.uid not in chosen:chosen.append(resource.uid)
 targeting=view.picker_active() or view.local.get("mode","")=="target"
 var stamp=view.picker.key if targeting else ""
 targeting_entered=targeting and (targeting_stamp!=stamp or not initialized)
 targeting_stamp=stamp
 if not opened.is_empty() and (view.engine.revision!=opened_revision or not opened_local and not view.local.is_empty()):opened={}
 for node in cards.values():node.hide()
 for node in tiles.values():node.hide()
 rows={};aliases={};destinations={};descriptors=view.table.descriptors.duplicate();groups={}
 for descriptor in view.table.descriptors.values():
  for uid in descriptor.get("members",[]):aliases["card_"+str(uid)]=descriptor.key
 var current_units={}
 for who in [1-view.local_seat,view.local_seat]:
  groups[who]={"unit":[],"item":[],"barrier":[],"time":[],"melody":[]}
  for c in view.engine.players[who].field:
   var group=view.table.field_group(c)
   if group=="support":group="barrier" if view.engine.cards[c.card_id].kind=="结界" else "time"
   groups[who][group].append(c)
   if group=="unit":current_units[c.uid]=true
  var enemy=who!=view.local_seat
  var area: Rect2
  if board_layout_mode=="inline":
   var y=B.position.y+(0 if enemy else row_h+g*3)
   layout_inline(who,Rect2(B.position.x,y,B.size.x,row_h))
   area=Rect2(B.position.x+hit+g*2,y,B.size.x-hit-(hit*2+g)-g*4,row_h)
  else:
   var band_y=B.position.y if enemy else B.position.y+band_h+g+row_h+g*2+row_h+g
   layout_band(who,Rect2(B.position.x,band_y,B.size.x,band_h))
   var y=B.position.y+band_h+g+(0 if enemy else row_h+g*2)
   area=Rect2(B.position.x,y,B.size.x,row_h)
  var units=view.table.ordered_units(who,groups[who].unit)
  units=units.filter(func(c):return aliases.get("card_"+str(c.uid),"card_"+str(c.uid))=="card_"+str(c.uid))
  layout_row("units-"+str(who),units,area,true,who==view.local_seat)
 previous_units=current_units;initialized=true
 layout_left()
 layout_sheet()
 queue_redraw()

func _draw():
 var g=view.host.ui_metrics.gap
 var y=row_h+g*1.5 if board_layout_mode=="inline" else band_h+g+row_h+g
 draw_line(Vector2(g,y),Vector2(size.x-g,y),Color(1,1,1,0.12),1)

func tile(key: String,rect: Rect2,props: Dictionary,action: Callable):
 if not tiles.has(key):
  var node=Tile.new();node.board=self;node.name=key;add_child(node);tiles[key]=node
 var node=tiles[key]
 node.configure(rect,props,action);node.set_meta("expanded",key.begins_with("perm-"));node.show()
 return node

func card(c: Dictionary,rect: Rect2,expanded: bool=false):
 var key="card_"+str(c.uid)
 if not cards.has(key):
  var node=Card.new();node.board=self;node.name=key;add_child(node);cards[key]=node
 var node=cards[key]
 node.configure(c,available,chosen,targeting,not expanded);node.place(Rect2(rect.position-position,rect.size))
 node.set_meta("expanded",expanded);node.show()
 if expanded:move_child(node,-1)
 if not descriptors.has(key):
  var d=view.table.description(c,Vector3.ZERO);d.members=[c.uid];descriptors[key]=d
 return node

func layout_band(who: int,rect: Rect2):
 var g=view.host.ui_metrics.gap;var w=roundf(band_h)
 var player=view.engine.players[who]
 var leaders=([player.leader]+player.get("extra_leaders",[])).filter(func(c):return c.zone=="leader")
 for group in ["leader","melody","item","barrier","time"]:
  var index=["leader","melody","item","barrier","time"].find(group)
  var x=rect.position.x+index*(w+g) if index<2 else rect.end.x-(5-index)*(w+g)+g
  var list=leaders if group=="leader" else groups[who][group]
  var first={} if list.is_empty() else list[0]
  var props={"kind":"permanent","label":LABELS[group],"count":list.size(),"empty":list.is_empty(),"disabled":list.is_empty() and group!="leader","legal":list.any(func(c):return c.uid in available) and targeting}
  if not first.is_empty():props.texture=view.card_texture(first)
  if group=="leader":props.erase("count")
  var action=func():view.leader_zone_clicked(who) if group=="leader" else open_region(who,group)
  var node=tile("band-%d-%s" % [who,group],Rect2(x,rect.position.y,w,band_h),props,action)
  node.inspect_action=Callable()
  if group=="leader" and not first.is_empty():node.inspect_action=func():inspect(first)
  for c in list:destinations["card_"+str(c.uid)]=node

func layout_inline(who: int,rect: Rect2):
 var g=view.host.ui_metrics.gap;var tw=view.host.ui_metrics.hit;var th=floorf((row_h-g)/2)
 var player=view.engine.players[who]
 var leaders=([player.leader]+player.get("extra_leaders",[])).filter(func(c):return c.zone=="leader")
 var enemy=who!=view.local_seat
 for group in ["leader","melody","item","barrier","time"]:
  var bottom=group in ["melody","time"] if enemy else group in ["leader","item","barrier"]
  var x=rect.position.x if group in ["leader","melody"] else rect.end.x-(tw*2+g)+(tw+g if group=="barrier" else 0)
  var y=rect.position.y+(th+g if bottom else 0)
  var list=leaders if group=="leader" else groups[who][group]
  var first={} if list.is_empty() else list[0]
  var props={"kind":"permanent","label":LABELS[group],"count":list.size(),"empty":list.is_empty(),"disabled":list.is_empty() and group!="leader","legal":list.any(func(c):return c.uid in available) and targeting}
  if not first.is_empty():props.texture=view.card_texture(first)
  if group=="leader":props.erase("count")
  var action=func():view.leader_zone_clicked(who) if group=="leader" else open_region(who,group)
  var node=tile("band-%d-%s" % [who,group],Rect2(x,y,tw,th),props,action)
  node.inspect_action=Callable()
  if group=="leader" and not first.is_empty():node.inspect_action=func():inspect(first)
  for c in list:destinations["card_"+str(c.uid)]=node

func row_pages(list: Array,area_width: float,height: float,rotate_tapped: bool) -> Array:
 # Simulator layout_shared.row_pages: greedily fill by actual portrait/landscape width.
 var pages=[[]];var total=maxi(0,list.size()-1)*10.0
 for c in list:total+=card_width(c,height,rotate_tapped)
 if total<=area_width:
  pages[0]=list;return pages
 var inner=area_width-view.host.ui_metrics.hit*2-view.host.ui_metrics.gap*2;var used=0.0
 for c in list:
  var width=card_width(c,height,rotate_tapped)
  if not pages.back().is_empty() and used+12+width>inner:pages.append([]);used=0
  used+=width+(12 if not pages.back().is_empty() else 0);pages.back().append(c)
 return pages

func card_width(c: Dictionary,height: float,rotate_tapped: bool) -> float:
 return height if rotate_tapped and c.get("tapped",false) else floorf(height/1.4)

func page_of(pages: Array,key: String) -> int:
 for i in range(pages.size()):
  if pages[i].any(func(c):return "card_"+str(c.uid)==key):return i
 return 0

func layout_row(key: String,list: Array,area: Rect2,rotate_tapped: bool,own_units: bool=false):
 var pages=row_pages(list,area.size.x,area.size.y,rotate_tapped)
 var page=page_of(pages,anchors.get(key,""))
 if targeting_entered and not pages[page].any(func(c):return c.uid in available):
  for i in range(pages.size()):
   if pages[i].any(func(c):return c.uid in available):page=i;break
 if own_units and initialized:
  for c in list:
   if not previous_units.has(c.uid):page=page_of(pages,"card_"+str(c.uid))
 if not pages[page].is_empty():anchors[key]="card_"+str(pages[page][0].uid)
 var info={"pages":pages,"page":page,"hidden_before":0,"hidden_after":0}
 rows[key]=info
 var paged=pages.size()>1;var gap=12.0 if paged else 10.0
 if paged:
  var hit=view.host.ui_metrics.hit
  for direction in [-1,1]:
   var hidden=[]
   for i in range(pages.size()):
    if i<page if direction<0 else i>page:hidden.append_array(pages[i])
   info["hidden_before" if direction<0 else "hidden_after"]=hidden.size()
   var x=area.position.x if direction<0 else area.end.x-hit
   var pager=tile(("perm-" if key=="perm" else "")+"page-"+key+("-prev" if direction<0 else "-next"),Rect2(x,area.position.y,hit,area.size.y),{"kind":"pager","dir":direction,"count":hidden.size(),"disabled":hidden.is_empty(),"legal":targeting and hidden.any(func(c):return c.uid in available),"selected_hidden":hidden.any(func(c):return c.uid in chosen)},func():turn_page(key,direction))
   for c in hidden:destinations["card_"+str(c.uid)]=pager
 var total=maxi(0,pages[page].size()-1)*gap
 for c in pages[page]:total+=card_width(c,area.size.y,rotate_tapped)
 var x=area.get_center().x-total/2
 for c in pages[page]:
  var w=card_width(c,area.size.y,rotate_tapped);var tapped=rotate_tapped and c.get("tapped",false)
  var h=floorf(area.size.y/1.4) if tapped else area.size.y
  card(c,Rect2(x,area.position.y+(area.size.y-h)/2,w,h),key=="perm")
  x+=w+gap

func turn_page(key: String,direction: int):
 if not rows.has(key):return
 var info=rows[key];var next=clampi(info.page+direction,0,info.pages.size()-1)
 if info.pages[next].is_empty():return
 anchors[key]="card_"+str(info.pages[next][0].uid)
 sync();view.rebuild_badges();view.arrow_layer.queue_redraw()

func summary(who: int,reservations: Array=[]) -> Dictionary:
 var result={"total":0,"count":view.engine.players[who].palette.size()}
 for color in view.engine.COLORS:result[color]=0
 var reserved=reservations.map(func(r):return r.uid)
 for c in view.engine.players[who].palette:
  if c.tapped or c.uid in reserved:continue
  result.total+=1
  for color in view.engine.Pack.colors(view.engine,c):
   if result.has(color):result[color]+=1
 return result

func layout_left():
 var L=left_column;var hit=view.host.ui_metrics.hit;var g=view.host.ui_metrics.gap
 var sh=roundf(hit*1.3);var zh=maxf(hit,roundf(hit*1.2))
 if sh*2+zh*2+g*3>L.size.y:zh=hit
 if sh*2+zh*2+g*3>L.size.y:sh=hit
 var compact=sh*2+zh*2+g*3>L.size.y
 # Keep the existing hand visibility control reachable between the two pairs.
 var free_top=L.position.y+sh+g+(0 if compact else zh+g)
 var free_bottom=L.end.y-sh-g-(0 if compact else zh+g)
 keep_colors_rect=Rect2()
 if free_bottom-free_top>=hit:
  view.responsive.hand_toggle_rect=Rect2(L.position.x,(free_top+free_bottom-hit)/2,L.size.x,hit)
 if free_bottom-free_top>=hit*2:
  keep_colors_rect=Rect2(L.position.x,free_top,L.size.x,hit)
  view.responsive.hand_toggle_rect.position.y=free_bottom-hit
 for who in [1-view.local_seat,view.local_seat]:
  var own=who==view.local_seat;var p=view.engine.players[who]
  var y=L.end.y-sh if own else L.position.y
  var title=("我方 牌库%d" % p.deck.size()) if own else ("对手 手牌%d·牌库%d" % [p.hand.size(),p.deck.size()])
  if compact:title+=" 墓%d 除%d" % [p.grave.size(),p.exile.size()]
  var pay=own and view.local.get("mode","")=="payment"
  var before=summary(who);var after=summary(who,view.local.get("plan",[])) if pay else before
  tile("summary-"+str(who),Rect2(L.position.x,y,L.size.x,sh),{"kind":"summary","title":title,"before":before,"after":after,"pay":pay},func():view.browse_zone(who,"grave") if compact else view.toggle_android_palette(who))
  if compact:continue
  var zy=y-g-zh if own else y+sh+g
  for i in range(2):
   var zone="grave" if i==0 else "exile";var list=p[zone]
   var usable=list.filter(func(c):return own and view.can_use_region_card(c)).size()
   var legal=view.picker_active() and view.picker.available_refs().any(func(ref):return ref.has("uid") and list.any(func(c):return c.uid==ref.uid))
   tile("zone-%d-%s" % [who,zone],Rect2(L.position.x+i*(L.size.x+g)/2,zy,(L.size.x-g)/2,zh),{"label":("墓地 %d" if i==0 else "除外 %d") % list.size(),"count":list.size(),"usable":usable,"legal":legal},func():view.browse_zone(who,zone))

func open_region(who: int,group: String):
 opened={"who":who,"group":group};opened_revision=view.engine.revision;opened_local=not view.local.is_empty()
 anchors.erase("perm");sync();view.rebuild_badges()

func close_region():
 opened={};sync();view.rebuild_badges();view.arrow_layer.queue_redraw()

func layout_sheet():
 sheet.visible=not opened.is_empty();sheet_rect=Rect2()
 if opened.is_empty():return
 var g=view.host.ui_metrics.gap;var hit=view.host.ui_metrics.hit
 sheet_rect=Rect2(position+Vector2.ONE*g,size-Vector2.ONE*g*2)
 sheet.position=sheet_rect.position-position;sheet.size=sheet_rect.size
 sheet.add_theme_stylebox_override("panel",view.host.style(Color("#1b1420",0.96),Color("#6a5265")))
 move_child(sheet,-1)
 var list=groups[opened.who][opened.group]
 var title=("我方" if opened.who==view.local_seat else "对手")+" · "+LABELS[opened.group]+"（%d）" % list.size()
 var title_node=sheet.get_node_or_null("Title")
 if title_node==null:
  title_node=Label.new();title_node.name="Title";title_node.mouse_filter=MOUSE_FILTER_IGNORE;sheet.add_child(title_node)
 title_node.text=title;title_node.position=Vector2(g,0);title_node.size=Vector2(sheet.size.x-hit-g*3,hit)
 title_node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;title_node.add_theme_font_size_override("font_size",view.host.ui_metrics.small)
 tile("perm-close",Rect2(sheet_rect.end.x-hit-g,sheet_rect.position.y,hit,hit),{"label":"关闭"},close_region)
 move_child(tiles["perm-close"],-1)
 var height=minf(row_h,sheet_rect.size.y-hit-g*3)
 var y=sheet_rect.position.y+hit+g
 # Sheet cards are portrait even when the underlying permanent is tapped.
 layout_row("perm",list,Rect2(sheet_rect.position.x+g,y,sheet_rect.size.x-g*2,height),false)

func card_visible(key: String) -> bool:
 var actual=aliases.get(key,key)
 if not opened.is_empty():return cards.has(actual) and cards[actual].visible and cards[actual].get_meta("expanded",false)
 return cards.has(actual) and cards[actual].visible or destinations.has(actual) and destinations[actual].visible and actual==key and destinations[actual].name.ends_with("leader")

func card_rect(key: String) -> Rect2:
 var actual=aliases.get(key,key)
 if cards.has(actual) and cards[actual].visible:return cards[actual].get_global_rect()
 if destinations.has(actual) and destinations[actual].visible:return destinations[actual].get_global_rect()
 return Rect2()

func zone_rect(who: int,zone: String) -> Rect2:
 var key="summary-"+str(who) if zone=="deck" else "zone-%d-%s" % [who,zone]
 if not tiles.has(key) or not tiles[key].visible:key="summary-"+str(who)
 return tiles[key].get_global_rect() if tiles.has(key) else Rect2()

func inspect(c: Dictionary):
 view.android_inspection_allowed=true;view.inspect_card(c.card_id,c.uid,"",c.get("art_id",""));view.android_inspection_allowed=false

func hit_control(point: Vector2) -> Control:
 var candidates=[]
 for node in cards.values():
  if node.visible and node.hit_rect().has_point(point-node.global_position):candidates.append(node)
 for node in tiles.values():
  if node.visible and not node.disabled and node.hit_rect().has_point(point-node.global_position):candidates.append(node)
 candidates.sort_custom(func(a,b):return a.get_index()>b.get_index())
 for node in candidates:
  if opened.is_empty() or node.get_meta("expanded",false):return node
 return null

func handle(event: InputEvent) -> bool:
 var touch=event is InputEventScreenTouch or event is InputEventScreenDrag
 var mouse=event is InputEventMouseButton or event is InputEventMouseMotion
 if not touch and not mouse:return false
 if event is InputEventMouseButton and event.button_index!=MOUSE_BUTTON_LEFT:return false
 var press=event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed
 var release=event is InputEventScreenTouch and not event.pressed or event is InputEventMouseButton and not event.pressed
 if mouse and Time.get_ticks_msec()<view.suppress_touch_mouse_until and event.position.distance_to(view.suppress_touch_mouse_point)<28:return false
 if press:
  if view.host.menu_popup_open() or view.history_open or view.observing or view.revealing() or view.table.combat_animating:return false
  var surface=view.android_card_touch.surface_at(view.ui,event.position)
  if not opened.is_empty() and not sheet_rect.has_point(event.position):
   close_region()
   if surface!=null and not is_ancestor_of(surface):return false
   consume(event,touch);return true
  if surface!=null and not is_ancestor_of(surface):return false
  if is_instance_valid(pressed_control):
   moved=true;consume(event,touch);return true
  pressed_control=hit_control(event.position)
  if pressed_control==null:return false
  finger=event.index if touch else -1;origin=event.position;elapsed=0;moved=false;inspected=false
 elif not is_instance_valid(pressed_control):return false
 elif (event.index if touch else -1)!=finger:return false
 if event is InputEventScreenDrag or event is InputEventMouseMotion:
  if event.position.distance_to(origin)>12:moved=true
 elif release:
  var node=pressed_control;pressed_control=null;finger=-2
  var canceled=event.canceled if touch else false
  if node is Card:node.held=false;node.front.queue_redraw()
  if not canceled and not moved and not inspected:node.activate()
 consume(event,touch)
 return true

func consume(event: InputEvent,touch: bool):
 if touch:view.suppress_touch_mouse_until=Time.get_ticks_msec()+250;view.suppress_touch_mouse_point=event.position
 get_viewport().set_input_as_handled()

func _process(delta: float):
 if is_instance_valid(pressed_control):
  if not pressed_control.is_visible_in_tree() or view.host.menu_popup_open() or view.history_open or view.table.combat_animating:moved=true
  elapsed+=delta
  if pressed_control is Card:
   pressed_control.held=not moved and not inspected;pressed_control.progress=minf(1,elapsed/CardPreviewHold.seconds);pressed_control.front.queue_redraw()
  if not moved and not inspected and elapsed>=CardPreviewHold.seconds:
   inspected=true;pressed_control.inspect()
 var animating=view.table.combat_animating
 if animating and not combat_was_animating:
  var uid=view.engine.combat.get("attacker",{}).get("uid",0);var key="card_"+str(uid)
  if cards.has(key) and cards[key].visible:cards[key].dash(-1 if cards[key].card.owner==view.local_seat else 1)
 combat_was_animating=animating
 if animating:view.update_badge_positions();view.arrow_layer.queue_redraw()

func _notification(what: int):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  moved=true
  if is_instance_valid(pressed_control) and pressed_control is Card:pressed_control.held=false;pressed_control.front.queue_redraw()
  pressed_control=null;finger=-2
