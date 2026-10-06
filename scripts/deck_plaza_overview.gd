extends Control
## Read-only card faces with the desktop / Android editor's deck arrangement.
const Store=preload("res://scripts/deck_store.gd")
const Art=preload("res://scripts/card_art.gd")
const DeckCard=preload("res://scripts/deck_card.gd")
signal card_inspected(id: String)
const MAIN_COLUMNS=10
const SIDE_COLUMNS=2
const ROWS=5
const PAGE_SIZE=MAIN_COLUMNS*ROWS
const CARD_RATIO=1.397
const CARD_GAP=4.0
var app
var deck={}
var main_page=0
var pending=false
var faces={}
var highlighted_cards: Array=[]
var card_frames: Array=[]
var fill_height=false
var input_root: Node
var touch_surfaces=preload("res://scripts/android_card_touch.gd").new()
var finger=-1
var touch_tile: WeakRef
var touch_origin=Vector2.ZERO
var suppress_mouse_until=0

func _ready():
 name="PlazaDeckOverview"
 resized.connect(queue_layout)
 queue_layout()

func queue_layout():
 if pending:return
 pending=true;call_deferred("layout_deck")

func caption(value: String,rect: Rect2) -> Label:
 var label=app.label(self,value,rect,app.ui_metrics.small,app.GOLD)
 # The overview already uses measured font sizes for its geometry. Do not
 # run those sizes through the Android requested-font conversion a second time.
 label.add_theme_font_size_override("font_size",app.ui_metrics.small)
 return label

func card_face(parent: Control,id: String,rect: Rect2,leader: bool=false,zone: String="leader",index: int=0):
 if id.is_empty():
  var frame=Panel.new();parent.add_child(frame);frame.position=rect.position;frame.size=rect.size
  frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
  frame.add_theme_stylebox_override("panel",app.style(Color("#10202c"),Color("#243948")))
  return
 var frame=DeckCard.new();frame.is_android=app.is_android;frame.draggable=false
 frame.card_id=id;frame.long_press_enabled=app.is_android
 frame.source_zone=zone;frame.source_index=index
 card_frames.append(frame)
 frame.position=rect.position;frame.size=rect.size
 frame.mouse_filter=Control.MOUSE_FILTER_STOP if is_instance_valid(input_root) else Control.MOUSE_FILTER_PASS
 frame.add_theme_stylebox_override("panel",app.style(Color("#142737"),app.GOLD if leader else Color("#677585")))
 highlight_frame(frame)
 frame.tooltip_text=str(Store.CARDS.get(id,{}).get("name",id))+("\n长按 1 秒：查看详情" if app.is_android else "\n点击或右键：查看详情")
 frame.clicked.connect(func(card_id,_zone,_index,_right):card_inspected.emit(card_id))
 parent.add_child(frame)
 if not faces.has(id):faces[id]=app.texture(id,Art.selected(deck,id,Store.CARDS))
 var art=TextureRect.new();frame.add_child(art)
 art.texture=faces[id];art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 art.offset_left=3;art.offset_top=3;art.offset_right=-3;art.offset_bottom=-3

func cards(parent: Control,ids: Array,origin: Vector2,tile: Vector2,columns: int,slots: int,start: int=0,zone: String="main"):
 for slot in range(slots):
  var index=start+slot
  var id=str(ids[index]) if index<ids.size() else ""
  card_face(parent,id,Rect2(origin+Vector2((slot%columns)*(tile.x+CARD_GAP),floori(float(slot)/columns)*(tile.y+CARD_GAP)),tile),false,zone,index)

func set_card_highlights(targets: Array):
 if highlighted_cards==targets:return
 highlighted_cards=targets.duplicate(true)
 for frame in card_frames:
  if is_instance_valid(frame):highlight_frame(frame)

func highlight_frame(frame: Control):
 var marked=highlighted_cards.any(func(target):return target.card_id==frame.card_id and (not target.has("zone") or target.zone==frame.source_zone) and (not target.has("index") or int(target.index)==frame.source_index))
 frame.set_meta("tutorial_highlighted",marked)
 var style=app.style(Color("#142737"),Color("#ff4545") if marked else app.GOLD if frame.source_zone=="leader" else Color("#677585"))
 if marked:style.set_border_width_all(6)
 frame.add_theme_stylebox_override("panel",style)

func layout_deck():
 pending=false
 if size.x<100 or size.y<100:return
 cancel_native_hold()
 cancel_card_holds(self)
 card_frames.clear()
 app.free_children(self)
 if app.is_android:layout_android()
 else:layout_desktop()

func layout_desktop():
 var gap=app.ui_metrics.gap
 var header=app.ui_metrics.small*1.8
 var card_width=maxf(1,minf((size.x-gap-16-CARD_GAP*(MAIN_COLUMNS-1))/12.2,(size.y-header*2-gap-CARD_GAP*(ROWS-1))/((ROWS+1)*CARD_RATIO)))
 var tile=Vector2(card_width,card_width*CARD_RATIO)
 var leader_width=card_width*2.2
 var main_x=leader_width+gap
 var main_height=ROWS*tile.y+(ROWS-1)*CARD_GAP
 if fill_height:main_height=maxf(main_height,size.y-header*2-gap-tile.y)
 caption("自机",Rect2(0,0,leader_width,header))
 caption("主卡组  ·  %d 张" % deck.main.size(),Rect2(main_x,0,size.x-main_x,header))
 var scroll=ScrollContainer.new();scroll.name="PlazaMainDeckScroll";add_child(scroll)
 scroll.position=Vector2(0,header);scroll.size=Vector2(size.x,main_height)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var content=Control.new();scroll.add_child(content)
 var rows=maxi(ROWS,ceili(float(deck.main.size())/MAIN_COLUMNS))
 content.custom_minimum_size=Vector2(size.x-16,rows*tile.y+(rows-1)*CARD_GAP)
 card_face(content,str(deck.leader),Rect2(0,0,leader_width,leader_width*CARD_RATIO),true)
 cards(content,deck.main,Vector2(main_x,0),tile,MAIN_COLUMNS,deck.main.size())
 var side_y=header+main_height+gap
 caption("副卡组  ·  %d 张" % deck.side.size(),Rect2(main_x,side_y,size.x-main_x,header))
 cards(self,deck.side,Vector2(main_x,side_y+header),tile,MAIN_COLUMNS,deck.side.size(),0,"side")

func change_page(value: int):
 main_page=clampi(value,0,maxi(0,ceili(float(deck.main.size())/PAGE_SIZE)-1))
 queue_layout()

func page_action(value: String,rect: Rect2,callback: Callable,disabled: bool):
 var button=app.button(self,value,rect,callback);app.ui_metrics.button(button)
 button.disabled=disabled
 return button

func layout_android():
 var gap=app.ui_metrics.gap
 var pages=maxi(1,ceili(float(deck.main.size())/PAGE_SIZE))
 var header=app.ui_metrics.hit if pages>1 else app.ui_metrics.small*1.8
 var available=size.x-gap*2-CARD_GAP*(MAIN_COLUMNS+SIDE_COLUMNS-2)
 var width_limit=available/(MAIN_COLUMNS+SIDE_COLUMNS+2.5)
 var height_limit=(size.y-header-CARD_GAP*(ROWS-1))/ROWS/CARD_RATIO
 var card_width=floorf(maxf(1,minf(160,minf(width_limit,height_limit))))
 var tile=Vector2(card_width,floorf(card_width*CARD_RATIO))
 var grid_height=ROWS*tile.y+(ROWS-1)*CARD_GAP
 var leader_width=minf(available-(MAIN_COLUMNS+SIDE_COLUMNS)*card_width,grid_height/CARD_RATIO)
 var main_x=leader_width+gap
 var main_width=MAIN_COLUMNS*tile.x+(MAIN_COLUMNS-1)*CARD_GAP
 var side_x=main_x+main_width+gap
 caption("自机",Rect2(0,0,leader_width,header))
 caption("主卡组",Rect2(main_x,0,main_width,header))
 caption("副卡组",Rect2(side_x,0,size.x-side_x,header))
 if pages>1:
  var previous=page_action("上一页",Rect2(),func():change_page(main_page-1),main_page==0)
  var next=page_action("下一页",Rect2(),func():change_page(main_page+1),main_page==pages-1)
  var number_width=app.ui_metrics.small*3
  next.position=Vector2(main_x+main_width-next.custom_minimum_size.x,0);next.size=next.custom_minimum_size
  previous.position=Vector2(next.position.x-gap-number_width-gap-previous.custom_minimum_size.x,0);previous.size=previous.custom_minimum_size
  var number=caption("%d / %d" % [main_page+1,pages],Rect2(previous.position.x+previous.size.x+gap,0,number_width,header))
  number.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 card_face(self,str(deck.leader),Rect2(0,header,leader_width,leader_width*CARD_RATIO),true)
 cards(self,deck.main,Vector2(main_x,header),tile,MAIN_COLUMNS,PAGE_SIZE,main_page*PAGE_SIZE)
 cards(self,deck.side,Vector2(side_x,header),tile,SIDE_COLUMNS,SIDE_COLUMNS*ROWS,0,"side")

func cancel_native_hold():
 var tile=touch_tile.get_ref() if touch_tile!=null else null
 if is_instance_valid(tile):tile.cancel_touch_hold()
 finger=-1;touch_tile=null

func cancel_card_holds(node: Node):
 if node is DeckCard:node.cancel_touch_hold()
 for child in node.get_children():cancel_card_holds(child)

func _input(event: InputEvent):
 if not app.is_android:return
 if event is InputEventMouseButton or event is InputEventMouseMotion:
  if finger>=0 or (Time.get_ticks_msec()<suppress_mouse_until and event.position.distance_to(touch_origin)<28):get_viewport().set_input_as_handled()
  return
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return
 if event is InputEventScreenTouch and event.pressed:
  if finger>=0:
   cancel_native_hold();suppress_mouse_until=Time.get_ticks_msec()+250
   get_viewport().set_input_as_handled();return
  var tile=touch_surfaces.surface_at(input_root if is_instance_valid(input_root) else app.screen,event.position)
  if not tile is DeckCard or not is_ancestor_of(tile):return
  finger=event.index;touch_tile=weakref(tile);touch_origin=event.position
  tile.grab_focus();tile.begin_touch_hold(event.position)
 elif event.index!=finger:return
 elif event is InputEventScreenDrag:
  var tile=touch_tile.get_ref() if touch_tile!=null else null
  if is_instance_valid(tile) and event.position.distance_to(touch_origin)>12:tile.cancel_touch_hold()
 else:cancel_native_hold()
 suppress_mouse_until=Time.get_ticks_msec()+250
 get_viewport().set_input_as_handled()

func _exit_tree():
 cancel_native_hold();cancel_card_holds(self)
