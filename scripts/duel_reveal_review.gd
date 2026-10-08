extends RefCounted
## Public snapshots survive movement, shuffling, disappearing tokens and recovery.
static func render(view):
 var review=view.engine.pending
 var can_confirm=review.owner==view.acting_player()
 var panel=view.overlay("确认展示牌 · %d 张" % review.cards.size() if can_confirm else "等待对手确认展示牌",true)
 panel.name="RevealReviewPanel"
 var safe=view.host.ui_metrics.safe
 panel.size=Vector2(minf(1180,safe.size.x-32),minf(760,safe.size.y-32))
 view.center_panel(panel)
 var heading=panel.get_node("DialogTitle")
 heading.position=Vector2(24,16);heading.size=Vector2(panel.size.x-48,42)
 heading.add_theme_font_size_override("font_size",view.host.ui_metrics.title if view.is_android else 27)
 var caption="本次结算展示的全部牌如下。确认后结束结算。" if can_confirm else "对手正在查看本次结算展示的全部牌，请等待对手确认。"
 caption+="\n查看期间，双方不能使用牌或启动场上能力。"
 var notice_font=view.host.ui_metrics.small if view.is_android else 19
 var notice_height=view.responsive.wrapped_height(caption,panel.size.x-48,notice_font)+8
 var notice=view.txt(caption,Rect2(24,66,panel.size.x-48,notice_height),notice_font,view.host.WHITE,panel)
 notice.add_theme_font_size_override("font_size",notice_font)
 notice.name="RevealReviewNotice";notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var hit=maxf(48,view.host.ui_metrics.hit)
 var scroll=ScrollContainer.new();scroll.name="RevealReviewScroll";panel.add_child(scroll)
 var content_top=66+notice_height+12
 scroll.position=Vector2(24,content_top);scroll.size=Vector2(panel.size.x-48,panel.size.y-content_top-hit-32)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var grid=GridContainer.new();grid.name="RevealReviewGrid";scroll.add_child(grid)
 var gap=16.0;var width=minf(240 if view.is_android else 190,(scroll.size.x-18-gap*3)/4)
 grid.columns=maxi(1,int((scroll.size.x-18+gap)/(width+gap)))
 grid.add_theme_constant_override("h_separation",int(gap));grid.add_theme_constant_override("v_separation",int(gap))
 for card in review.cards:
  var cell=VBoxContainer.new();cell.name="RevealedCard";cell.set_meta("revealed_card",card.duplicate(true));grid.add_child(cell)
  cell.custom_minimum_size.x=width
  var tile=view.host.card(cell,card.card_id,Rect2(0,0,width,width*1.4),Callable(),card.get("art_id",""))
  tile.name="RevealedCardArt";tile.custom_minimum_size=Vector2(width,width*1.4)
  tile.tooltip_text=view.engine.cards[card.card_id].name
  if view.is_android:view.android_card_touch.bind_card(tile,func():view.inspect_card(card.card_id,0,"展示牌",card.get("art_id","")),Callable())
  else:tile.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:view.inspect_card(card.card_id,0,"展示牌",card.get("art_id","")))
  var title_font=mini(22,view.host.ui_metrics.small) if view.is_android else 17
  var card_name=str(view.engine.cards[card.card_id].name)
  var quote=card_name.find("「")
  if quote>0:card_name=card_name.substr(0,quote).strip_edges()+"\n"+card_name.substr(quote)
  var name_lines=view.responsive.wrap_choice_prompt(card_name,width,title_font)
  var title=view.txt(name_lines,Rect2(),title_font,view.host.WHITE,cell)
  title.add_theme_font_size_override("font_size",title_font)
  title.custom_minimum_size=Vector2(width,maxf(44,title_font*1.6*name_lines.split("\n").size()));title.autowrap_mode=TextServer.AUTOWRAP_OFF
  title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.clip_text=false
 var footer=Rect2(24,panel.size.y-hit-16,panel.size.x-48,hit)
 if can_confirm:
  var serial=int(review.serial)
  var confirm=view.btn("已查看全部展示牌，确认",footer,func():
   view.message=view.engine.confirm_revealed(view.acting_player(),serial);view.render(),true,panel)
  confirm.name="RevealReviewConfirm"
  confirm.disabled=view.network_session!=null and not view.network_session.can_act(true)
 else:
  var waiting=view.txt("等待对手确认…",footer,view.host.ui_metrics.body,view.host.GOLD,panel)
  waiting.name="RevealReviewWaiting";waiting.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
