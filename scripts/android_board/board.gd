extends Control
## Responsive side-column board. All actions are forwarded to duel_view.
const Card=preload("res://scripts/android_board/board_card.gd")
const Tile=preload("res://scripts/android_board/zone_tile.gd")
const PaymentPopup=preload("res://scripts/android_board/payment_popup.gd")
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
var hand_toggle_rect=Rect2()
var emote_rect=Rect2()
var left_compact=false
var left_single_row=false
var left_layout_step=1
var sheet: Panel
var sheet_rect=Rect2()
var palette: Panel
var palette_rect=Rect2()
var payment: Panel
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

class LeftButton extends Button:
 var hit=0.0
 var peers=[]
 func hit_rect() -> Rect2:
  var extent=size.max(Vector2.ONE*hit)
  return Rect2((size-extent)/2,extent)
 func _has_point(point: Vector2) -> bool:
  if Rect2(Vector2.ZERO,size).has_point(point):return true
  # Expanded touch targets must yield to a neighbour's visible button.
  for rect in peers:
   if rect.has_point(global_position+point):return false
  return hit_rect().has_point(point)

func place_left_button(button: Button,rect: Rect2):
 if button.get_script()!=LeftButton:button.set_script(LeftButton)
 button.hit=view.host.ui_metrics.hit
 button.peers=[keep_colors_rect,hand_toggle_rect,emote_rect]
 button.clip_text=true;button.custom_minimum_size=rect.size
 button.position=rect.position;button.size=rect.size

func _ready():
 name="AndroidBoard";mouse_filter=MOUSE_FILTER_IGNORE
 sheet=Panel.new();sheet.name="RegionExpansion";sheet.mouse_filter=MOUSE_FILTER_STOP
 add_child(sheet);sheet.hide()
 palette=Panel.new();palette.name="PaletteExpansion";palette.mouse_filter=MOUSE_FILTER_STOP
 add_child(palette);palette.hide()
 payment=PaymentPopup.new();payment.board=self;payment.name="PaymentPopup";add_child(payment);payment.hide()

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
 if view.android_palette_view:opened={}
 if not opened.is_empty() and (view.engine.revision!=opened_revision or not opened_local and not view.local.is_empty()):opened={}
 for node in cards.values():node.hide()
 for node in tiles.values():node.hide()
 rows={};aliases={};destinations={};descriptors=view.table.descriptors.duplicate();groups={}
 for descriptor in view.table.descriptors.values():
  for uid in descriptor.get("members",[]):aliases["card_"+str(uid)]=descriptor.key
 var current_units={}
 for who in [1-view.local_seat,view.local_seat]:
  for c in palette_cards(who):
   var key="card_"+str(c.uid)
   if not descriptors.has(key):descriptors[key]=view.table.description(c,Vector3.ZERO)
  groups[who]={"leader":view.engine.leaders(who).filter(func(c):return c.zone=="leader"),"unit":[],"item":[],"barrier":[],"time":[],"melody":[]}
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
 layout_palette()
 queue_redraw()

func _draw():
 var g=view.host.ui_metrics.gap
 var y=row_h+g*1.5 if board_layout_mode=="inline" else band_h+g+row_h+g
 draw_line(Vector2(g,y),Vector2(size.x-g,y),Color(1,1,1,0.12),1)

func tile(key: String,rect: Rect2,props: Dictionary,action: Callable):
 if not tiles.has(key):
  var node=Tile.new();node.board=self;node.name=key;add_child(node);tiles[key]=node
 var node=tiles[key]
 node.configure(rect,props,action);node.set_meta("expanded",key.begins_with("perm-") or key.begins_with("palette-"));node.show()
 return node

func card(c: Dictionary,rect: Rect2,expanded: bool=false,rotate_tapped: bool=true,force_landscape: bool=false):
 var key="card_"+str(c.uid)
 if not cards.has(key):
  var node=Card.new();node.board=self;node.name=key;add_child(node);cards[key]=node
 var node=cards[key]
 node.configure(c,available,chosen,targeting,rotate_tapped,force_landscape);node.place(Rect2(rect.position-position,rect.size))
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
  var props={"kind":"permanent","label":LABELS[group],"count":list.size(),"empty":list.is_empty(),"legal":list.any(func(c):return c.uid in available) and targeting}
  props.landscape=group in ["barrier","time"]
  if group=="item":props.previews=item_previews(list)
  if not first.is_empty():props.texture=view.card_texture(first)
  if group=="leader":props.erase("count")
  var action=func():open_region(who,group)
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
  var props={"kind":"permanent","label":LABELS[group],"count":list.size(),"empty":list.is_empty(),"legal":list.any(func(c):return c.uid in available) and targeting}
  props.landscape=group in ["barrier","time"]
  if group=="item":props.previews=item_previews(list)
  if not first.is_empty():props.texture=view.card_texture(first)
  if group=="leader":props.erase("count")
  var action=func():open_region(who,group)
  var node=tile("band-%d-%s" % [who,group],Rect2(x,y,tw,th),props,action)
  node.inspect_action=Callable()
  if group=="leader" and not first.is_empty():node.inspect_action=func():inspect(first)
  for c in list:destinations["card_"+str(c.uid)]=node

func item_previews(list: Array) -> Array:
 var sample=list.slice(0,2)
 var upright=list.filter(func(c):return not c.get("tapped",false))
 var tapped=list.filter(func(c):return c.get("tapped",false))
 if not upright.is_empty() and not tapped.is_empty():sample=[upright[0],tapped[0]]
 return sample.map(func(c):return {"texture":view.card_texture(c),"tapped":c.get("tapped",false)})

func row_pages(list: Array,area_width: float,height: float,rotate_tapped: bool,force_landscape: bool=false) -> Array:
 # Simulator layout_shared.row_pages: greedily fill by actual portrait/landscape width.
 var pages=[[]];var total=maxi(0,list.size()-1)*10.0
 for c in list:total+=card_width(c,height,rotate_tapped,force_landscape)
 if total<=area_width:
  pages[0]=list;return pages
 var inner=area_width-view.host.ui_metrics.hit*2-view.host.ui_metrics.gap*2;var used=0.0
 for c in list:
  var width=card_width(c,height,rotate_tapped,force_landscape)
  if not pages.back().is_empty() and used+12+width>inner:pages.append([]);used=0
  used+=width+(12 if not pages.back().is_empty() else 0);pages.back().append(c)
 return pages

func card_width(c: Dictionary,height: float,rotate_tapped: bool,force_landscape: bool=false) -> float:
 return height if force_landscape or rotate_tapped and c.get("tapped",false) else floorf(height/1.4)

func page_of(pages: Array,key: String) -> int:
 for i in range(pages.size()):
  if pages[i].any(func(c):return "card_"+str(c.uid)==key):return i
 return 0

func layout_row(key: String,list: Array,area: Rect2,rotate_tapped: bool,own_units: bool=false,force_landscape: bool=false):
 var pages=row_pages(list,area.size.x,area.size.y,rotate_tapped,force_landscape)
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
 for c in pages[page]:total+=card_width(c,area.size.y,rotate_tapped,force_landscape)
 var x=area.get_center().x-total/2
 for c in pages[page]:
  var w=card_width(c,area.size.y,rotate_tapped,force_landscape);var tapped=force_landscape or rotate_tapped and c.get("tapped",false)
  var h=floorf(area.size.y/1.4) if tapped else area.size.y
  card(c,Rect2(x,area.position.y+(area.size.y-h)/2,w,h),key=="perm",rotate_tapped,force_landscape)
  x+=w+gap

func turn_page(key: String,direction: int):
 if not rows.has(key):return
 var info=rows[key];var next=clampi(info.page+direction,0,info.pages.size()-1)
 if info.pages[next].is_empty():return
 anchors[key]="card_"+str(info.pages[next][0].uid)
 sync();view.rebuild_badges();view.arrow_layer.queue_redraw()

func palette_cards(who: int) -> Array:
 if is_instance_valid(view.reveal_player) and view.reveal_player.palette_owner==who:return view.reveal_player.palette_cards
 return view.engine.players[who].palette

func summary(who: int,reservations: Array=[]) -> Dictionary:
 var result={"total":0,"count":palette_cards(who).size()}
 for color in view.engine.COLORS:result[color]=0
 var reserved=reservations.map(func(r):return r.uid)
 for c in palette_cards(who):
  if c.tapped or c.uid in reserved:continue
  result.total+=1
  for color in view.engine.Pack.colors(view.engine,c):
   if result.has(color):result[color]+=1
 return result

func layout_left():
 left_column=Rect2(left_column.position.round(),left_column.end.round()-left_column.position.round())
 var L=left_column;var hit=view.host.ui_metrics.hit;var g=view.host.ui_metrics.gap
 var sh=roundf(hit*1.3);var zh=maxf(hit,roundf(hit*1.2))
 var ctrl_h=hit*2+g
 left_layout_step=1
 if sh*2+zh*2+ctrl_h+g*4>L.size.y:zh=hit;left_layout_step=2
 if sh*2+zh*2+ctrl_h+g*4>L.size.y:sh=hit;left_layout_step=3
 left_compact=sh*2+zh*2+ctrl_h+g*4>L.size.y
 if left_compact:left_layout_step=4
 left_single_row=left_compact and sh*2+ctrl_h+g*3>L.size.y
 if left_single_row:ctrl_h=hit;left_layout_step=5
 var free_top=L.position.y+sh+(0 if left_compact else zh+g)
 var free_bottom=L.end.y-sh-(0 if left_compact else zh+g)
 var ctrl_y=roundf((free_top+free_bottom-ctrl_h)/2)
 if left_single_row:
  var width=roundf((L.size.x-hit-g*2)/2)
  emote_rect=Rect2(L.position.x,ctrl_y,hit,hit)
  keep_colors_rect=Rect2(emote_rect.end.x+g,ctrl_y,width,hit)
  hand_toggle_rect=Rect2(keep_colors_rect.end.x+g,ctrl_y,L.end.x-keep_colors_rect.end.x-g,hit)
 else:
  keep_colors_rect=Rect2(L.position.x,ctrl_y,L.size.x,hit)
  emote_rect=Rect2(L.position.x,ctrl_y+hit+g,hit,hit)
  hand_toggle_rect=Rect2(emote_rect.end.x+g,emote_rect.position.y,L.size.x-hit-g,hit)
 view.responsive.hand_toggle_rect=hand_toggle_rect
 for who in [1-view.local_seat,view.local_seat]:
  var own=who==view.local_seat;var p=view.engine.players[who]
  var y=L.end.y-sh if own else L.position.y
  var title=("我方 牌库%d" % p.deck.size()) if own else ("对手 手牌%d·牌库%d" % [p.hand.size(),p.deck.size()])
  if left_compact:title+=" 墓%d 除%d" % [p.grave.size(),p.exile.size()]
  var pay=own and view.android_payment_panel_available()
  var before=summary(who);var after=summary(who,view.local.get("plan",[])) if pay else before
  tile("summary-"+str(who),Rect2(L.position.x,y,L.size.x,sh),{"kind":"summary","title":title,"before":before,"after":after,"pay":pay,"selected":view.android_palette_view and view.android_palette_focus_owner()==who},func():view.toggle_android_palette(who))
  if left_compact:continue
  var zy=y-g-zh if own else y+sh+g
  for i in range(2):
   var zone="grave" if i==0 else "exile";var list=p[zone]
   var usable=list.filter(func(c):return own and view.can_use_region_card(c)).size()
   var legal=view.picker_active() and view.picker.available_refs().any(func(ref):return ref.has("uid") and list.any(func(c):return c.uid==ref.uid))
   var x=roundf(L.position.x+i*(L.size.x+g)/2)
   var width=roundf((L.size.x-g)/2) if i==0 else L.end.x-x
   tile("zone-%d-%s" % [who,zone],Rect2(x,zy,width,zh),{"label":("墓地 %d" if i==0 else "除外 %d") % list.size(),"count":list.size(),"usable":usable,"legal":legal},func():view.browse_zone(who,zone))

func open_region(who: int,group: String):
 if view.android_palette_view:view.set_android_camera_focus(-1)
 opened={"who":who,"group":group};opened_revision=view.engine.revision;opened_local=not view.local.is_empty()
 anchors.erase("perm");sync();view.rebuild_badges()

func close_region():
 opened={};sync();view.rebuild_badges();view.arrow_layer.queue_redraw()

func close_expansion() -> bool:
 if not opened.is_empty():close_region();return true
 if view.android_palette_view:view.set_android_camera_focus(-1);return true
 return false

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
 var empty=sheet.get_node_or_null("Empty")
 if empty==null:
  empty=Label.new();empty.name="Empty";empty.mouse_filter=MOUSE_FILTER_IGNORE;sheet.add_child(empty)
 empty.text="空";empty.visible=list.is_empty();empty.position=Vector2(g,hit+g);empty.size=Vector2(sheet.size.x-g*2,hit)
 empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;empty.add_theme_font_size_override("font_size",view.host.ui_metrics.body)
 tile("perm-close",Rect2(sheet_rect.end.x-hit-g,sheet_rect.position.y,hit,hit),{"label":"关闭"},close_region)
 move_child(tiles["perm-close"],-1)
 var height=minf(maxf(row_h,hit*1.4),sheet_rect.size.y-hit-g*2)
 var y=sheet_rect.position.y+hit+g
 # Barriers and time spells are always landscape, independently of tapping.
 layout_row("perm",list,Rect2(sheet_rect.position.x+g,y,sheet_rect.size.x-g*2,height),opened.group=="item",false,opened.group in ["barrier","time"])

func palette_pages(list: Array,width: float,height: float,line_count: int) -> Array:
 var pages=[[]];var line=0;var used=0.0
 for c in list:
  var w=card_width(c,height,true)
  if used>0 and used+10+w>width:
   line+=1;used=0
   if line==line_count:pages.append([]);line=0
  pages.back().append(c);used+=w+(10 if used>0 else 0)
 return pages

func layout_palette():
 payment.visible=view.android_palette_view and view.android_palette_focus_owner()==view.local_seat and view.android_payment_panel_available()
 palette.visible=view.android_palette_view and not payment.visible;palette_rect=Rect2()
 if payment.visible:
  for node in cards.values():node.hide()
  payment.refresh(Rect2(position+Vector2.ONE*view.host.ui_metrics.gap,size-Vector2.ONE*view.host.ui_metrics.gap*2))
  move_child(payment,-1)
 if not palette.visible:return
 var who=view.android_palette_focus_owner();var g=view.host.ui_metrics.gap;var hit=view.host.ui_metrics.hit
 palette_rect=Rect2(position+Vector2.ONE*g,size-Vector2.ONE*g*2)
 palette.position=palette_rect.position-position;palette.size=palette_rect.size
 palette.add_theme_stylebox_override("panel",view.host.style(Color("#1b1420",0.96),Color("#6a5265")))
 move_child(palette,-1)
 var before=summary(who);var own=who==view.local_seat
 var title=("我方" if own else "对手")+"颜色盘 · 可用 %d/%d" % [before.total,before.count]
 if own and view.android_payment_panel_available():
  title="我方颜色盘 · 付前 %d → 付后 %d" % [before.total,summary(who,view.local.plan).total]
 var title_node=palette.get_node_or_null("Title")
 if title_node==null:
  title_node=Label.new();title_node.name="Title";title_node.mouse_filter=MOUSE_FILTER_IGNORE;palette.add_child(title_node)
 var entry_width=roundf(hit*1.3)
 var zones=["hand","deck","grave","exile"] if left_compact else ["hand","deck"]
 title_node.text=title;title_node.position=Vector2(g,0);title_node.size=Vector2(palette.size.x-hit-g*3-(entry_width+g)*zones.size(),hit)
 title_node.clip_text=true
 title_node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;title_node.add_theme_font_size_override("font_size",view.host.ui_metrics.small)
 for i in range(zones.size()):
  var zone=zones[i];var zone_list=view.engine.players[who][zone]
  var usable=zone_list.filter(func(c):return own and view.can_use_region_card(c)).size() if zone in ["grave","exile"] else 0
  var legal=view.picker_active() and view.picker.available_refs().any(func(ref):return ref.has("uid") and zone_list.any(func(c):return c.uid==ref.uid))
  var key="palette-"+zone;var x=palette_rect.end.x-hit-g*2-entry_width-(entry_width+g)*(zones.size()-1-i)
  tile(key,Rect2(x,palette_rect.position.y,entry_width,hit),{"label":view.ZONE_NAMES[zone]+" %d" % zone_list.size(),"count":zone_list.size(),"usable":usable,"legal":legal},func():view.browse_zone(who,zone))
  move_child(tiles[key],-1)
 tile("palette-close",Rect2(palette_rect.end.x-hit-g,palette_rect.position.y,hit,hit),{"label":"隐藏" if own and view.android_payment_panel_available() else "关闭"},func():view.set_android_camera_focus(-1))
 move_child(tiles["palette-close"],-1)
 var list=palette_cards(who).duplicate()
 var colors={};var order=["红","蓝","绿","黄","黑"]
 for c in list:colors[c.uid]=view.engine.Pack.colors(view.engine,c)
 list.sort_custom(func(a,b):
  var ac=colors[a.uid];var bc=colors[b.uid]
  var ai=order.find(ac[0]) if not ac.is_empty() else order.size()
  var bi=order.find(bc[0]) if not bc.is_empty() else order.size()
  if ai!=bi:return ai<bi
  if (ac.size()==1)!=(bc.size()==1):return ac.size()==1
  return a.uid<b.uid)
 var area=Rect2(palette_rect.position+Vector2(g,hit+g),Vector2(palette_rect.size.x-g*2,palette_rect.size.y-hit-g*3))
 var height=floorf((area.size.y-g)/2);var line_count=2
 if height<hit*1.4:line_count=1;height=area.size.y
 var pages=palette_pages(list,area.size.x,height,line_count)
 var paged=pages.size()>1
 if paged:pages=palette_pages(list,area.size.x-hit*2-g*2,height,line_count)
 var key="palette-"+str(who);var page=page_of(pages,anchors.get(key,""))
 if not pages[page].any(func(c):return c.uid in available):
  for i in range(pages.size()):
   if pages[i].any(func(c):return c.uid in available):page=i;break
 if not pages[page].is_empty():anchors[key]="card_"+str(pages[page][0].uid)
 var info={"pages":pages,"page":page,"hidden_before":0,"hidden_after":0};rows[key]=info
 if paged:
  for direction in [-1,1]:
   var hidden=[]
   for i in range(pages.size()):
    if i<page if direction<0 else i>page:hidden.append_array(pages[i])
   info["hidden_before" if direction<0 else "hidden_after"]=hidden.size()
   var x=area.position.x if direction<0 else area.end.x-hit
   tile("palette-page-"+str(who)+("-prev" if direction<0 else "-next"),Rect2(x,area.position.y,hit,area.size.y),{"kind":"pager","dir":direction,"count":hidden.size(),"disabled":hidden.is_empty(),"legal":targeting and hidden.any(func(c):return c.uid in available),"selected_hidden":hidden.any(func(c):return c.uid in chosen)},func():turn_page(key,direction))
   move_child(tiles["palette-page-"+str(who)+("-prev" if direction<0 else "-next")],-1)
  area.position.x+=hit+g;area.size.x-=hit*2+g*2
 var x=area.position.x;var line=0
 for c in pages[page]:
  var w=card_width(c,height,true)
  if x>area.position.x and x+w>area.end.x:line+=1;x=area.position.x
  var h=floorf(height/1.4) if c.get("tapped",false) else height
  card(c,Rect2(x,area.position.y+line*(height+g)+(height-h)/2,w,h),true)
  x+=w+10

func palette_owner(key: String) -> int:
 var descriptor=descriptors.get(key,{})
 if descriptor.get("zone","")=="palette":return descriptor.owner
 return -1

func card_visible(key: String) -> bool:
 if payment.visible:return false
 var actual=aliases.get(key,key)
 if palette_owner(key)>=0:return palette.visible and cards.has(key) and cards[key].visible
 if palette.visible:return false
 if not opened.is_empty():return cards.has(actual) and cards[actual].visible and cards[actual].get_meta("expanded",false)
 return cards.has(actual) and cards[actual].visible or destinations.has(actual) and destinations[actual].visible and actual==key and destinations[actual].name.ends_with("leader")

func card_rect(key: String) -> Rect2:
 var who=palette_owner(key)
 if who>=0:
  if palette.visible and cards.has(key) and cards[key].visible:return cards[key].get_global_rect()
  return zone_rect(who,"palette")
 var actual=aliases.get(key,key)
 if cards.has(actual) and cards[actual].visible:return cards[actual].get_global_rect()
 if destinations.has(actual) and destinations[actual].visible:return destinations[actual].get_global_rect()
 return Rect2()

func zone_rect(who: int,zone: String) -> Rect2:
 var key="summary-"+str(who) if zone in ["deck","palette"] else "zone-%d-%s" % [who,zone]
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
 candidates.sort_custom(func(a,b):
  # Expanded touch targets can overlap on a short screen. Prefer the visible
  # card nearest the pointer, while keeping popup controls above the board.
  var ae=a.get_meta("expanded",false);var be=b.get_meta("expanded",false)
  if (palette.visible or not opened.is_empty()) and ae!=be:return ae
  var ar=a.get_global_rect();var br=b.get_global_rect()
  var ad=point.distance_squared_to(point.clamp(ar.position,ar.end))
  var bd=point.distance_squared_to(point.clamp(br.position,br.end))
  if not is_equal_approx(ad,bd):return ad<bd
  return a.get_index()>b.get_index())
 for node in candidates:
  if palette.visible:
   if node.get_meta("expanded",false) or str(node.name).begins_with("band-") or str(node.name).begins_with("summary-"):return node
   continue
  if opened.is_empty() or node.get_meta("expanded",false):return node
 return null

func handle(event: InputEvent) -> bool:
 var touch=event is InputEventScreenTouch or event is InputEventScreenDrag
 var mouse=event is InputEventMouseButton or event is InputEventMouseMotion
 if not touch and not mouse:return false
 # Match stage_input(): Android's mouse echo may arrive before native touch.
 # It must not capture finger -1 and leave the native release unmatched.
 if mouse and event.device==-1:return false
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
  if event.pressed and not view.debug_open and not view.inspection.visible and not view.modal and not view.history_open and not view.host.menu_popup_open() and close_expansion():
   moved=true;consume(event,false);return true
  return false
 if event is InputEventMouseButton and event.button_index!=MOUSE_BUTTON_LEFT:return false
 var press=event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed
 var release=event is InputEventScreenTouch and not event.pressed or event is InputEventMouseButton and not event.pressed
 if mouse and Time.get_ticks_msec()<view.suppress_touch_mouse_until and event.position.distance_to(view.suppress_touch_mouse_point)<28:return false
 if press:
  if view.host.menu_popup_open() or view.history_open or view.revealing() or view.table.combat_animating:return false
  var surface=view.android_card_touch.surface_at(view.ui,event.position)
  if payment.visible:
   if surface==payment or surface!=null and payment.is_ancestor_of(surface):return false
   if payment.get_global_rect().has_point(event.position):consume(event,touch);return true
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
