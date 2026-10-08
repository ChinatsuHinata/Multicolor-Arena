extends RefCounted
## History uses detached public artwork snapshots, never live card lookup.

static func hidden(view,art: Dictionary) -> bool:
 return art.get("card_id","")=="back" or art.get("hidden",false) and art.get("owner",-1)!=view.local_seat and not view.debug_mode and not view.replay_view()

static func stamp(view,entry: Dictionary) -> String:
 return "第%d回合 · %s" % [entry.turn,view.phase_names.get(entry.phase,entry.phase)]

static func label(view,parent: Node,text: String,font: int,color: Color,name: String="") -> Label:
 var result=Label.new();result.text=text
 if not name.is_empty():result.name=name
 result.add_theme_font_size_override("font_size",font);result.add_theme_color_override("font_color",color)
 result.mouse_filter=Control.MOUSE_FILTER_IGNORE;result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(result)
 return result

static func inspect(view,art: Dictionary):
 var concealed=hidden(view,art)
 view.inspect_card("back" if concealed else art.card_id,0,"卡牌 · 未公开" if concealed else "记录中的卡牌","" if concealed else art.get("art_id",""))

static func tile(view,parent: Node,art: Dictionary,width: float,activate: Callable=Callable()) -> Control:
 var concealed=hidden(view,art)
 var card=view.host.card(parent,"back" if concealed else art.card_id,Rect2(0,0,width,width*1.4),Callable(),"" if concealed else art.get("art_id",""))
 card.custom_minimum_size=Vector2(width,width*1.4);card.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
 card.set_meta("history_display_id","back" if concealed else art.card_id)
 card.set_meta("history_art",art.duplicate(true));card.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 if view.is_android:view.android_card_touch.bind_card(card,func():inspect(view,art),activate)
 else:card.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed:
   if event.button_index==MOUSE_BUTTON_RIGHT:inspect(view,art)
   elif event.button_index==MOUSE_BUTTON_LEFT and activate.is_valid():activate.call())
 return card

static func build(view):
 var m=view.host.ui_metrics
 var width=minf(760,m.safe.size.x*0.48) if view.is_android else 480.0
 var height=m.safe.size.y-24 if view.is_android else minf(807,m.safe.size.y-90)
 var at=Vector2(m.safe.end.x-width,m.safe.position.y+12) if view.is_android else Vector2(view.OPPONENT_HAND_COUNT.position.x-width-12,m.safe.position.y+75)
 view.history_panel=view.host.box(view.history_root,Rect2(at,Vector2(width,height)),Color("#0f1b29"),Color("#637a93"))
 view.history_panel.name="AndroidHistoryPanel" if view.is_android else "HistoryPanel"
 var title_font=m.title if view.is_android else 26
 var hit=m.hit if view.is_android else 40.0
 var title=view.txt("对局流程记录",Rect2(20,12,width-175,hit),title_font,view.host.GOLD,view.history_panel);title.name="HistoryTitle"
 var close=view.host.button(view.history_panel,"关闭记录",Rect2(width-148,12,128,hit),view.close_history)
 if view.is_android:m.button(close)
 var hint=view.txt("点按记录查看详情" if view.is_android else "点击记录查看详情",Rect2(20,hit+18,width-40,28),m.small if view.is_android else 15,view.host.MUTED,view.history_panel)
 var top=hint.position.y+hint.size.y+12
 var scroll=ScrollContainer.new();scroll.name="HistoryScroll";scroll.position=Vector2(16,top);scroll.size=Vector2(width-32,height-top-16)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;view.history_panel.add_child(scroll)
 var column=VBoxContainer.new();column.name="HistoryEntries";column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",int(m.gap) if view.is_android else 8);scroll.add_child(column)
 var events=view.engine.history.duplicate();events.reverse()
 if events.is_empty():label(view,column,"暂无对局记录",m.body if view.is_android else 18,view.host.MUTED)
 for entry in events:
  var row=PanelContainer.new();row.name="HistoryEntry";row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(row)
  row.mouse_filter=Control.MOUSE_FILTER_STOP;row.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  row.set_meta("history_entry",entry.duplicate(true))
  var style=view.host.style(Color("#162636"),Color("#2d455a"));style.set_content_margin_all(16 if view.is_android else 12)
  row.add_theme_stylebox_override("panel",style)
  var open=func():view.open_history_entry(entry)
  if view.is_android:view.android_card_touch.bind_card(row,Callable(),open)
  else:row.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:open.call())
  var content=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_PASS;content.add_theme_constant_override("separation",12 if view.is_android else 6);row.add_child(content)
  label(view,content,stamp(view,entry),m.small if view.is_android else 14,view.host.MUTED)
  var body=HBoxContainer.new();body.mouse_filter=Control.MOUSE_FILTER_PASS;body.add_theme_constant_override("separation",20 if view.is_android else 12);content.add_child(body)
  if not entry.get("art",[]).is_empty():tile(view,body,entry.art[0],100 if view.is_android else 62,open)
  label(view,body,entry.text,m.body if view.is_android else 17,view.host.WHITE,"HistoryText")
  if not entry.get("revealed_cards",[]).is_empty():
   label(view,content,"展示 %d 张牌 · 查看全部" % entry.revealed_cards.size(),m.small if view.is_android else 14,view.host.GOLD,"HistoryRevealCount")

static func card_grid(view,parent: Node,cards: Array,available_width: float,name: String):
 var gap=16.0
 var columns=maxi(1,floori((available_width+gap)/(180+gap)))
 var width=minf(180 if view.is_android else 210,(available_width-gap*(columns-1))/columns)
 var grid=GridContainer.new();grid.name=name;grid.columns=columns
 grid.add_theme_constant_override("h_separation",int(gap));grid.add_theme_constant_override("v_separation",int(gap));parent.add_child(grid)
 for art in cards:
  var cell=VBoxContainer.new();cell.custom_minimum_size.x=width;cell.set_meta("history_art",art.duplicate(true));grid.add_child(cell)
  tile(view,cell,art,width)
  var id="back" if hidden(view,art) else str(art.get("card_id",""))
  var text="未公开" if id=="back" else str(view.engine.cards.get(id,{}).get("name","未知卡牌"))
  var caption=label(view,cell,text,mini(22,view.host.ui_metrics.small) if view.is_android else 18,view.host.WHITE)
  caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

static func detail(view,entry: Dictionary):
 view.close_history_entry()
 view.android_card_touch.cancel();view.android_swipe_scroll.reset()
 var shade=ColorRect.new();shade.name="HistoryDetailRoot";shade.color=Color(0,0,0,0.65)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.history_root.add_child(shade);view.history_detail_root=shade
 var safe=view.host.ui_metrics.safe
 var dimensions=Vector2(minf(1120,safe.size.x-32),minf(780,safe.size.y-32))
 var panel=view.host.box(shade,Rect2(safe.get_center()-dimensions/2,dimensions),Color("#101c28"),view.host.GOLD)
 panel.name="HistoryDetailPanel";view.history_detail_panel=panel;panel.set_meta("history_entry",entry.duplicate(true))
 var font=view.host.ui_metrics.body if view.is_android else 21
 view.txt("记录详情",Rect2(24,16,panel.size.x-48,42),view.host.ui_metrics.title if view.is_android else 27,view.host.GOLD,panel)
 var footer_height=maxf(44,view.host.ui_metrics.hit)
 var scroll=ScrollContainer.new();scroll.name="HistoryDetailScroll";scroll.position=Vector2(24,70);scroll.size=Vector2(panel.size.x-48,panel.size.y-70-footer_height-32)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var body=VBoxContainer.new();body.name="HistoryDetailBody";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",16);scroll.add_child(body)
 label(view,body,stamp(view,entry),view.host.ui_metrics.small if view.is_android else 17,view.host.MUTED)
 label(view,body,entry.text,font,view.host.WHITE,"HistoryDetailText")
 if not entry.get("art",[]).is_empty():
  if entry.get("revealed_cards",[]).is_empty():
   label(view,body,"相关卡牌",font,view.host.GOLD)
   card_grid(view,body,entry.art,scroll.size.x-18,"HistoryRelatedCards")
  else:
   var related=HBoxContainer.new();related.name="HistoryRelatedCards";related.add_theme_constant_override("separation",16);body.add_child(related)
   for art in entry.art:
    tile(view,related,art,60)
    var id="back" if hidden(view,art) else str(art.get("card_id",""))
    label(view,related,"未公开" if id=="back" else str(view.engine.cards.get(id,{}).get("name","未知卡牌")),font,view.host.WHITE)
 if not entry.get("revealed_cards",[]).is_empty():
  label(view,body,"展示的全部牌（%d 张）" % entry.revealed_cards.size(),font,view.host.GOLD,"HistoryRevealedTitle")
  card_grid(view,body,entry.revealed_cards,scroll.size.x-18,"HistoryRevealedCards")
 label(view,body,"长按卡牌查看牌面详情" if view.is_android else "右键卡牌查看牌面详情",view.host.ui_metrics.small if view.is_android else 16,view.host.MUTED)
 var back=view.host.button(panel,"返回记录",Rect2(24,panel.size.y-footer_height-16,panel.size.x-48,footer_height),view.close_history_entry)
 back.name="HistoryDetailBack"
 if view.is_android:view.host.ui_metrics.button(back)
 view.refresh_observation()
