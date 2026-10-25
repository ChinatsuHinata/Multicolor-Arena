extends "res://scripts/modal_menu.gd"
## Storefront and account-owned goods share the same tiled catalogue.
## Copper is read from the existing server-owned wallet, never stored here.
const CoinIcon=preload("res://scripts/coin_icon.gd")
const ShopIcon=preload("res://scripts/shop_button.gd")
const Store=preload("res://scripts/deck_store.gd")
const Preview=preload("res://scripts/shop_preview.gd")
const PAGE_SIZE=4
const CATEGORIES=[
 {"id":"special","title":"特价商品","description":"精选好物，特惠相逢。"},
 {"id":"emotes","title":"自机对话表情","description":"让每一次对话，都带上自机的个性。"},
 {"id":"entrance","title":"单位入场特效","description":"为单位登场增添别样光彩。"},
 {"id":"spell","title":"符卡特效","description":"让符卡绽放独特的演出效果。"},
 {"id":"foil","title":"闪卡","description":"收藏闪耀的卡牌外观。"},
 {"id":"ai","title":"高级ai","description":"与更多对手切磋牌技。"},
 {"id":"other","title":"其他","description":"发现香霖堂里的其他好物。"},
]
var selected=0
var catalogue: Array=[]
var purchased_ids: Dictionary={}
var hide_purchased: CheckBox
var my_items: Button
var showing_owned=false
var product_actions: Array[Button]=[]
var tabs: Array[Button]=[]
var categories_scroll: ScrollContainer
var category_column: VBoxContainer
var category_title: Label
var category_description: Label
var balance: Label
var wallet_icon: Control
var notice: Label
var content: VBoxContainer
var empty_state: CenterContainer
var empty_icon: Control
var empty_title: Label
var empty_hint: Label
var purchase_dialog: ConfirmationDialog
var search: LineEdit
var page=0
var page_count=1
var result_count=0
var page_capacity=PAGE_SIZE
var previous_page: Button
var next_page: Button
var page_label: Label
var sale_banner: PanelContainer
var sale_heading: Label
var sale_details: Label
var sale_was_active=false
var browse_bar: HBoxContainer
var detail_overlay: Control
var detail_panel: PanelContainer
var detail_focus: WeakRef
var preview: Control
var preview_focus: WeakRef
var preview_mouse_until=0

func products_per_page() -> int:
 if not host.is_android:return PAGE_SIZE
 var width=scroll.size.x if is_instance_valid(scroll) and scroll.size.x>0 else host.ui_metrics.safe.size.x*0.7
 return clampi(floori((width+host.ui_metrics.gap)/(maxf(220,host.ui_metrics.body*8.0)+host.ui_metrics.gap)),1,PAGE_SIZE)

func build_shop(app):
 super.build(app,"香霖堂",[])
 name="ShopPopup";panel.name="ShopPanel";scroll.name="ShopProductsScroll"
 panel.add_theme_stylebox_override("panel",host.style(host.INK,host.GOLD))
 heading.name="ShopTitle"
 close_button.name="CloseShop"
 var header=heading.get_parent()
 var wallet=HBoxContainer.new();wallet.name="ShopWallet";header.add_child(wallet);header.move_child(wallet,close_button.get_index())
 wallet.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 wallet_icon=CoinIcon.new();wallet_icon.name="CoinIcon";wallet.add_child(wallet_icon)
 wallet_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;wallet_icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 balance=add_text(wallet,"",host.ui_metrics.body,host.GOLD);balance.name="ShopBalance"
 balance.autowrap_mode=TextServer.AUTOWRAP_OFF;balance.size_flags_horizontal=Control.SIZE_SHRINK_END
 var divider=HSeparator.new();body.add_child(divider);body.move_child(divider,1)
 var panes=HBoxContainer.new();panes.name="ShopPanes";body.add_child(panes);body.move_child(panes,2)
 panes.size_flags_vertical=Control.SIZE_EXPAND_FILL
 categories_scroll=ScrollContainer.new();categories_scroll.name="ShopCategories";panes.add_child(categories_scroll)
 categories_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;categories_scroll.follow_focus=true
 category_column=VBoxContainer.new();categories_scroll.add_child(category_column)
 category_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 my_items=host.button(category_column,"我的商品",Rect2(),show_my_items)
 my_items.name="MyProducts";my_items.toggle_mode=true;my_items.alignment=HORIZONTAL_ALIGNMENT_LEFT
 category_column.add_child(HSeparator.new())
 for index in range(CATEGORIES.size()):
  var tab=host.button(category_column,CATEGORIES[index].title,Rect2(),select_category.bind(index))
  tab.name="ShopCategory_"+CATEGORIES[index].id;tab.toggle_mode=true;tab.alignment=HORIZONTAL_ALIGNMENT_LEFT
  tabs.append(tab)
 var products=VBoxContainer.new();products.name="ShopProducts";panes.add_child(products)
 products.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 category_title=add_text(products,"",host.ui_metrics.title,host.WHITE);category_title.name="ShopCategoryTitle"
 hide_purchased=CheckBox.new();hide_purchased.name="HidePurchasedProducts";hide_purchased.text="隐藏已购";header.add_child(hide_purchased);header.move_child(hide_purchased,wallet.get_index())
 hide_purchased.tooltip_text="隐藏当前账号已购买的商品"
 hide_purchased.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 hide_purchased.button_pressed=host.shop_hide_purchased
 hide_purchased.toggled.connect(func(enabled):
  host.shop_hide_purchased=enabled;page=0;render_products())
 category_description=add_text(products,"",host.ui_metrics.small,host.MUTED)
 search=LineEdit.new();search.name="ShopSearch";products.add_child(search)
 search.placeholder_text="搜索自机 / 商品";search.clear_button_enabled=true
 search.tooltip_text="在当前分类中搜索自机名、称号或商品名"
 search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 search.text_changed.connect(func(_text):page=0;render_products())
 scroll.reparent(products)
 content=scroll.get_child(0)
 content.size_flags_vertical=Control.SIZE_EXPAND_FILL
 grid=GridContainer.new();grid.name="ShopProductGrid";content.add_child(grid)
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 empty_state=CenterContainer.new();empty_state.name="ShopEmptyState";content.add_child(empty_state)
 empty_state.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var empty_column=VBoxContainer.new();empty_state.add_child(empty_column)
 empty_icon=Control.new();empty_column.add_child(empty_icon);empty_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 empty_icon.draw.connect(func():ShopIcon.draw_shop(empty_icon,Rect2((empty_icon.size-Vector2.ONE*72)*0.5,Vector2.ONE*72),host.GOLD))
 empty_title=add_text(empty_column,"暂无上架商品",host.ui_metrics.body,host.WHITE);empty_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 empty_hint=add_text(empty_column,"好物筹备中，敬请期待",host.ui_metrics.small,host.MUTED);empty_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var pager=HBoxContainer.new();pager.name="ShopPagination";products.add_child(pager)
 previous_page=host.button(pager,"上一页",Rect2(),change_page.bind(-1));previous_page.name="ShopPreviousPage"
 page_label=add_text(pager,"",host.ui_metrics.small,host.MUTED);page_label.name="ShopPageLabel"
 page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;page_label.autowrap_mode=TextServer.AUTOWRAP_OFF
 next_page=host.button(pager,"下一页",Rect2(),change_page.bind(1));next_page.name="ShopNextPage"
 if host.is_android:
  browse_bar=HBoxContainer.new();browse_bar.name="ShopBrowseBar";products.add_child(browse_bar);products.move_child(browse_bar,search.get_index())
  search.reparent(browse_bar);pager.reparent(browse_bar)
 sale_banner=PanelContainer.new();sale_banner.name="ShopOpeningSale";body.add_child(sale_banner);body.move_child(sale_banner,1)
 var sale_style=host.style(Color("#642735"),Color("#ed7581"));sale_style.set_content_margin_all(host.ui_metrics.padding*0.6)
 sale_banner.add_theme_stylebox_override("panel",sale_style)
 var sale_column=VBoxContainer.new();sale_banner.add_child(sale_column)
 sale_heading=add_text(sale_column,"新店开业酬宾  ·  全场 5 折",host.ui_metrics.title,Color("#ffe6ac"))
 sale_details=add_text(sale_column,"",host.ui_metrics.small,Color("#fff0eb"))
 notice=add_text(body,"",host.ui_metrics.small,host.MUTED);notice.name="ShopWalletStatus"
 notice.autowrap_mode=TextServer.AUTOWRAP_OFF;notice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 catalogue=host.shop_inventory.catalogue
 host.task_service.changed.connect(refresh_balance)
 host.task_service.purchase_finished.connect(on_purchase_finished)
 host.shop_inventory.changed.connect(refresh_inventory)
 scroll.resized.connect(func():
  if host.is_android and page_capacity!=products_per_page():render_products(false)
  else:fit_grid())
 panel.minimum_size_changed.connect(func():call_deferred("relayout"))
 refresh_balance();refresh_inventory();select_category(0);relayout();tabs[0].grab_focus()

func add_text(parent: Node,value: String,font: int,color: Color) -> Label:
 var label=Label.new();parent.add_child(label);label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",font);label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return label

func refresh_balance():
 var service=host.task_service
 balance.text="铜钱：%d" % int(service.snapshot.coins) if service.snapshot.has("coins") else "铜钱：—"
 notice.text="登录账号后可查看自己的铜钱余额" if service.account.is_empty() else "余额同步失败，请稍后重新打开商店" if not service.error.is_empty() else "正在同步铜钱余额…" if is_instance_valid(service.client) else "好物陆续上架，欢迎常来看看。"
 notice.tooltip_text=service.error
 balance.tooltip_text="当前账号的铜钱余额" if service.snapshot.has("coins") else notice.text
 if not service.error.is_empty():notice.text=service.error
 render_products(false)

func on_purchase_finished(_ok: bool,message: String):
 notice.text=message

func buy_product(id: String):
 if is_instance_valid(purchase_dialog):return
 var item=host.shop_inventory.product(id)
 var service=host.task_service
 if item.is_empty() or host.shop_inventory.owns(id) or service.account.is_empty() or is_instance_valid(service.client):return
 var account=service.account;var token=service.token
 var price=host.shop_inventory.price_for(item)
 purchase_dialog=ConfirmationDialog.new();purchase_dialog.name="ConfirmShopPurchase"
 purchase_dialog.min_size=Vector2i(500,170)
 purchase_dialog.title="确认购买"
 purchase_dialog.dialog_text="花费 %d 铜钱购买「%s」？" % [price,str(item.name)]
 if host.shop_inventory.is_special(item):purchase_dialog.dialog_text+="\n开业酬宾 5 折 · 原价 %d 铜钱\n活动截至 %s" % [int(item.price),host.shop_inventory.sale_deadline_text()]
 purchase_dialog.get_ok_button().text="确认购买";purchase_dialog.get_cancel_button().text="取消"
 host.add_child(purchase_dialog);host.style_dialog(purchase_dialog)
 purchase_dialog.confirmed.connect(func():
  if not is_instance_valid(purchase_dialog):return
  dismiss_purchase()
  if service.account!=account or service.token!=token:return
  if host.shop_inventory.price_for(item)!=price:
   notice.text="活动价格已更新，请重新确认购买。";render_products(false);return
  service.purchase(id,price))
 purchase_dialog.canceled.connect(dismiss_purchase)
 purchase_dialog.popup_centered()

func dismiss_purchase():
 if is_instance_valid(purchase_dialog):purchase_dialog.hide();purchase_dialog.queue_free()
 purchase_dialog=null

func _exit_tree():dismiss_purchase()

func refresh_inventory():
 purchased_ids=host.shop_inventory.purchased_ids.duplicate()
 render_products(false)

func show_my_items():
 page=0
 showing_owned=true;my_items.set_pressed_no_signal(true);hide_purchased.hide()
 for tab in tabs:tab.set_pressed_no_signal(false)
 categories_scroll.call_deferred("ensure_control_visible",my_items)
 category_title.text="我的商品"
 category_description.text="选择商品是否在对战中启用。设置在下一场对战生效。"
 render_products()

func select_category(index: int):
 if index<0 or index>=CATEGORIES.size():return
 page=0
 selected=index;showing_owned=false;my_items.set_pressed_no_signal(false);hide_purchased.show()
 for i in range(tabs.size()):tabs[i].set_pressed_no_signal(i==selected)
 category_title.text=CATEGORIES[selected].title;category_description.text=CATEGORIES[selected].description
 render_products()

func is_purchased(item: Dictionary) -> bool:
 return purchased_ids.has(str(item.get("id","")))

func matches_search(item: Dictionary) -> bool:
 var query=search.text.strip_edges().to_lower()
 if query.is_empty():return true
 var leader=Store.CARDS.get(str(item.get("leader_id","")),{})
 var terms=[item.get("name",""),item.get("description",""),item.get("leader_id",""),leader.get("character",""),leader.get("title",""),leader.get("name","")]
 terms.append_array(leader.get("aliases",[]))
 return " ".join(terms).to_lower().contains(query)

func change_page(direction: int):
 var target=clampi(page+direction,0,page_count-1)
 if target==page:return
 page=target;render_products()

func _process(_delta):
 if is_instance_valid(sale_banner) and host.shop_inventory.sale_active()!=sale_was_active:render_products(false)

func render_products(reset_scroll: bool=true):
 var inventory=host.shop_inventory
 var now=inventory.current_time()
 sale_was_active=inventory.sale_active(now)
 sale_banner.visible=sale_was_active
 sale_details.text="全体商品限时半价 · 截至 "+inventory.sale_deadline_text()
 if not showing_owned and selected==0:
  category_description.text="全体商品限时 5 折，折后价向上取整。" if sale_was_active else "开业酬宾已结束，欢迎浏览其他分类。"
 var previous_scroll=scroll.scroll_vertical
 var category_count=0
 var matching_count=0
 var filtered: Array=[]
 var focused=get_viewport().gui_get_focus_owner()
 var focused_name=str(focused.name) if is_instance_valid(focused) and grid.is_ancestor_of(focused) else ""
 product_actions.clear()
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 for item in catalogue:
  if not item is Dictionary:continue
  if showing_owned:
   if not is_purchased(item):continue
  elif CATEGORIES[selected].id=="special":
   if not inventory.is_special(item,now):continue
  elif str(item.get("category",""))!=CATEGORIES[selected].id:continue
  category_count+=1
  if not matches_search(item):continue
  matching_count+=1
  if not showing_owned and hide_purchased.button_pressed and is_purchased(item):continue
  filtered.append(item)
 result_count=filtered.size()
 var capacity=products_per_page()
 page_capacity=capacity
 page_count=maxi(1,ceili(float(result_count)/capacity))
 var previous_index=page
 page=clampi(page,0,page_count-1)
 for item in filtered.slice(page*capacity,(page+1)*capacity):add_product(item)
 page_label.text="%d / %d" % [page+1,page_count] if host.is_android else "%d / %d 页 · 共 %d 件" % [page+1,page_count,result_count]
 page_label.tooltip_text="第 %d / %d 页 · 共 %d 件" % [page+1,page_count,result_count]
 previous_page.disabled=page==0;next_page.disabled=page>=page_count-1
 var has_products=grid.get_child_count()>0
 grid.visible=has_products;empty_state.visible=not has_products
 var all_purchased=not showing_owned and not has_products and matching_count>0 and hide_purchased.button_pressed
 empty_title.text="暂无未购商品" if all_purchased else "暂无上架商品"
 empty_hint.text="取消筛选可查看已购商品" if all_purchased else "好物筹备中，敬请期待"
 if not showing_owned and selected==0 and not sale_was_active:
  empty_title.text="特价活动已结束";empty_hint.text="商品仍可在原分类中购买"
 if showing_owned:
  empty_title.text="登录后查看商品" if host.shop_inventory.account.is_empty() else "暂无已购商品"
  empty_hint.text="购买或领取后可在这里管理"
 if not search.text.strip_edges().is_empty() and category_count>0 and matching_count==0:
  empty_title.text="未找到匹配商品";empty_hint.text="试试其他自机名、称号，或清空搜索"
 scroll.set_deferred("scroll_vertical",0 if reset_scroll or previous_index!=page else previous_scroll)
 fit_grid();link_focus()
 if not focused_name.is_empty():
  var replacement=grid.find_child(focused_name,true,false) as Control
  if replacement!=null:replacement.call_deferred("grab_focus")

func add_product(item: Dictionary):
 var tile=PanelContainer.new();tile.name="ShopProduct_"+str(item.get("id",grid.get_child_count()));grid.add_child(tile)
 tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var tile_style=host.style(Color("#192a38"),Color("#3d5161"));tile_style.set_content_margin_all(8 if host.is_android else host.ui_metrics.padding)
 tile.add_theme_stylebox_override("panel",tile_style)
 var column=VBoxContainer.new();tile.add_child(column)
 column.add_theme_constant_override("separation",4 if host.is_android else int(host.ui_metrics.gap))
 var art=preload("res://scripts/shop_emote_art.gd").new() if item.has("portrait_region") else TextureRect.new()
 art.name="ProductArt";column.add_child(art)
 art.custom_minimum_size.y=maxf(158,host.ui_metrics.hit*1.6)
 if host.is_android:art.size_flags_vertical=Control.SIZE_EXPAND_FILL
 if item.has("portrait_region"):
  art.centered=host.is_android;art.configure(item)
 else:
  art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  var path=str(item.get("image",""))
  if not path.is_empty() and ResourceLoader.exists(path):art.texture=load(path) as Texture2D
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if host.is_android:
  var details=Button.new();details.name="ProductDetails_"+str(item.id);art.add_child(details)
  details.flat=true;details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  details.tooltip_text="查看商品详情";details.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  details.pressed.connect(show_product_details.bind(item));product_actions.append(details)
  art.mouse_filter=Control.MOUSE_FILTER_PASS
 var special=host.shop_inventory.is_special(item)
 if special:add_sale_badge(art)
 var title=add_text(column,str(item.get("name","")),host.ui_metrics.body,host.WHITE);title.name="ProductTitle"
 if is_purchased(item) and not host.is_android:add_text(column,"已领取" if item.get("test_only",false) else "已购买",host.ui_metrics.small,host.GOLD).name="PurchasedBadge"
 if not host.is_android:add_text(column,str(item.get("description","")),host.ui_metrics.small,host.MUTED)
 var id=str(item.get("id",""))
 if not host.is_android and Preview.supports(item):
  product_actions.append(add_preview_button(column,item))
 if showing_owned:
  var toggle=CheckButton.new();toggle.name="BattleEnable_"+id;toggle.text="对战中启用";column.add_child(toggle)
  host.ui_metrics.button(toggle);toggle.custom_minimum_size.x=0
  toggle.button_pressed=host.shop_inventory.battle_enabled(id)
  toggle.toggled.connect(func(enabled):
   if not host.shop_inventory.set_battle_enabled(id,enabled):
    toggle.set_pressed_no_signal(host.shop_inventory.battle_enabled(id));host.alert(host.shop_inventory.error))
  product_actions.append(toggle)
 elif item.get("test_only",false):
  if not host.is_android:add_text(column,"测试商品 · 免费体验",host.ui_metrics.small,host.GOLD)
  if is_purchased(item):
   var manage=host.button(column,"已购买 · 管理" if host.is_android else "在我的商品中设置",Rect2(),show_my_items);host.ui_metrics.button(manage);product_actions.append(manage)
  else:
   var claim=host.button(column,"免费领取",Rect2(),func():
    if not host.shop_inventory.claim_test(id):host.alert(host.shop_inventory.error))
   claim.name="ClaimTestProduct_"+id;host.ui_metrics.button(claim)
   claim.disabled=not host.shop_inventory.can_claim_test(item)
   if claim.disabled:claim.tooltip_text="登录账号后可领取测试商品"
   product_actions.append(claim)
 elif item.has("price"):
  if is_purchased(item):
   var manage=host.button(column,"已购买 · 管理" if host.is_android else "在我的商品中设置",Rect2(),show_my_items);host.ui_metrics.button(manage);product_actions.append(manage)
  else:
   if special and not host.is_android:
    var original=add_text(column,"原价 %d 铜钱" % int(item.price),host.ui_metrics.small,host.MUTED);original.name="OriginalPrice"
   var price=host.shop_inventory.price_for(item)
   var buy=host.button(column,("购买 %d" % price) if host.is_android else str(price),Rect2(),buy_product.bind(id))
   buy.name="BuyProduct_"+id;host.ui_metrics.button(buy);buy.custom_minimum_size.x=0
   buy.icon=CoinIcon.texture(host.ui_metrics.button_font);buy.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT
   var service=host.task_service
   buy.disabled=service.account.is_empty() or is_instance_valid(service.client) or not service.snapshot.has("coins") or int(service.snapshot.get("coins",0))<price
   buy.tooltip_text="请先登录账号" if service.account.is_empty() else "正在同步，请稍候" if is_instance_valid(service.client) or not service.snapshot.has("coins") else "铜钱不足" if buy.disabled else "购买后在「我的商品」中开启，下一场对战生效"
   product_actions.append(buy)

func product_image_rect(art: Control) -> Rect2:
 if art.has_method("image_rect"):return art.image_rect()
 if art is TextureRect and art.texture!=null:
  var texture_size=art.texture.get_size()
  var image_size=texture_size*minf(art.size.x/texture_size.x,art.size.y/texture_size.y)
  return Rect2((art.size-image_size)*0.5,image_size)
 return Rect2(Vector2.ZERO,art.size)

func add_sale_badge(art: Control):
 var badge=Control.new();badge.name="SaleBadge";art.add_child(badge)
 badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var font=host.ui_metrics.small+2
 badge.size=Vector2(font*3.1,font*1.8)
 badge.draw.connect(func():
  var w=badge.size.x;var h=badge.size.y
  badge.draw_colored_polygon(PackedVector2Array([Vector2(12,0),Vector2(w,0),Vector2(w,h),Vector2(0,h)]),Color("#d9364f"))
  badge.draw_line(Vector2(13,1),Vector2(w-1,1),Color("#ff9ba7"),2,true)
  badge.draw_line(Vector2(1,h-1),Vector2(w,h-1),Color("#9e1934"),2,true))
 var label=Label.new();label.name="SaleBadgeText";badge.add_child(label)
 label.text="5折";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);label.offset_left=10
 label.add_theme_font_size_override("font_size",font);label.add_theme_color_override("font_color",Color("#fff9ee"))
 var place=func():
  var frame=product_image_rect(art)
  var factor=minf(1,minf(frame.size.x/(font*3.1),frame.size.y/(font*1.8)))
  if host.is_android:factor=minf(factor,minf(frame.size.x*0.7/(font*3.1),frame.size.y*0.3/(font*1.8)))
  badge.size=Vector2(font*3.1,font*1.8)*factor
  label.add_theme_font_size_override("font_size",maxi(1,floori(font*factor)))
  label.offset_left=10*factor
  badge.position=frame.end-badge.size
 art.resized.connect(place);place.call_deferred()

func fit_grid():
 if not is_instance_valid(grid):return
 var m=host.ui_metrics
 var available=maxf(1,scroll.size.x-(0 if host.is_android else scroll.get_v_scroll_bar().size.x+m.gap))
 # CenterContainer sizes children to their minimum; give wrapped labels a line width.
 empty_title.get_parent().custom_minimum_size.x=maxf(1,available-m.gap)
 var tile_width=maxf(220,m.body*9.0+m.padding*2)
 grid.columns=products_per_page() if host.is_android else maxi(1,floori((available+m.gap)/(tile_width+m.gap)))
 if host.is_android:
  scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
  grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
  for tile in grid.get_children():
   tile.size_flags_vertical=Control.SIZE_EXPAND_FILL
   var art=tile.find_child("ProductArt",true,false)
   art.custom_minimum_size.y=48
   var title=tile.find_child("ProductTitle",true,false)
   title.add_theme_font_size_override("font_size",mini(m.body,maxi(22,roundi(m.safe.size.y*0.032))))
   title.max_lines_visible=2;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.tooltip_text=str(title.text)

func show_product_details(item: Dictionary):
 close_product_details()
 var focused=get_viewport().gui_get_focus_owner()
 detail_focus=weakref(focused) if is_instance_valid(focused) else null
 detail_overlay=Control.new();detail_overlay.name="ShopProductDetails";backdrop.add_child(detail_overlay)
 detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();detail_overlay.add_child(shade);shade.color=Color(0,0,0,0.8)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_product_details())
 detail_panel=PanelContainer.new();detail_panel.name="ShopDetailPanel";detail_overlay.add_child(detail_panel)
 detail_panel.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 detail_panel.minimum_size_changed.connect(func():call_deferred("fit_product_details"))
 var column=VBoxContainer.new();detail_panel.add_child(column)
 var header=HBoxContainer.new();column.add_child(header)
 add_text(header,str(item.name),host.ui_metrics.title,host.GOLD)
 var close=host.button(header,"返回商店",Rect2(),close_product_details);host.ui_metrics.button(close)
 close.name="CloseProductDetails"
 var reader=ScrollContainer.new();reader.name="ProductDescriptionScroll";column.add_child(reader)
 reader.size_flags_vertical=Control.SIZE_EXPAND_FILL;reader.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var description=VBoxContainer.new();reader.add_child(description);description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_text(description,str(item.get("description","")),host.ui_metrics.body,host.WHITE).name="ProductDescription"
 if item.has("price"):
  add_text(description,"售价：%d 铜钱" % host.shop_inventory.price_for(item),host.ui_metrics.body,host.GOLD)
  if host.shop_inventory.is_special(item):add_text(description,"原价 %d 铜钱 · 开业酬宾 5 折 · 截至 %s" % [int(item.price),host.shop_inventory.sale_deadline_text()],host.ui_metrics.small,host.MUTED)
 add_text(description,"购买后可在「我的商品」设置对战开关，下一场对战生效。",host.ui_metrics.small,host.MUTED)
 if Preview.supports(item):add_preview_button(column,item)
 fit_product_details();call_deferred("fit_product_details");close.grab_focus()

func add_preview_button(parent: Node,item: Dictionary) -> Button:
 var button=host.button(parent,"预览",Rect2(),open_preview.bind(item))
 button.name="PreviewProduct_"+str(item.id);host.ui_metrics.button(button)
 return button

func open_preview(item: Dictionary):
 if is_instance_valid(preview) or is_instance_valid(purchase_dialog) or not Preview.supports(item):return
 var focused=get_viewport().gui_get_focus_owner()
 preview_focus=weakref(focused) if is_instance_valid(focused) else null
 panel.hide()
 if is_instance_valid(detail_overlay):detail_overlay.hide()
 swipe.reset()
 preview=Preview.new();backdrop.add_child(preview)
 preview.closed.connect(close_preview)
 preview.build(host,item)

func close_preview():
 if not is_instance_valid(preview):return
 preview_mouse_until=preview.suppress_mouse_until
 preview.shutdown();backdrop.remove_child(preview);preview.queue_free();preview=null
 panel.show()
 if is_instance_valid(detail_overlay):detail_overlay.show()
 var focused=preview_focus.get_ref() if preview_focus!=null else null
 preview_focus=null
 if is_instance_valid(focused) and focused.is_visible_in_tree():focused.grab_focus()
 elif is_instance_valid(detail_panel):detail_panel.find_child("CloseProductDetails",true,false).grab_focus()
 else:close_button.grab_focus()

func fit_product_details():
 if not is_instance_valid(detail_panel):return
 var safe=host.ui_metrics.safe
 detail_panel.size=Vector2(minf(1200 if host.is_android else 1000,safe.size.x),safe.size.y if host.is_android else minf(600,safe.size.y))
 detail_panel.position=safe.position+(safe.size-detail_panel.size)*0.5

func close_product_details():
 if is_instance_valid(detail_overlay):backdrop.remove_child(detail_overlay);detail_overlay.queue_free()
 detail_overlay=null;detail_panel=null
 var focused=detail_focus.get_ref() if detail_focus!=null else null
 detail_focus=null
 if is_instance_valid(focused) and focused.is_visible_in_tree():focused.grab_focus()

func _input(event: InputEvent):
 if is_instance_valid(preview):
  preview.handle_input(event)
  return
 if event is InputEventMouse and Time.get_ticks_msec()<preview_mouse_until:
  get_viewport().set_input_as_handled();return
 if is_instance_valid(detail_overlay):
  if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
   get_viewport().set_input_as_handled();close_product_details()
  elif host.is_android:swipe.handle(event,detail_overlay)
  return
 super._input(event)

func link_focus():
 var buttons: Array[Control]=[close_button,my_items]
 buttons.append_array(tabs)
 if hide_purchased.visible:buttons.append(hide_purchased)
 buttons.append(search)
 for action in product_actions:
  if not action.disabled:buttons.append(action)
 if not previous_page.disabled:buttons.append(previous_page)
 if not next_page.disabled:buttons.append(next_page)
 for i in range(buttons.size()):
  var button=buttons[i]
  var previous=button.get_path_to(buttons[(i-1+buttons.size())%buttons.size()])
  var next=button.get_path_to(buttons[(i+1)%buttons.size()])
  button.focus_previous=previous;button.focus_next=next
  if button==search:continue # Preserve caret navigation inside the text field.
  button.focus_neighbor_top=previous;button.focus_neighbor_bottom=next
  button.focus_neighbor_left=previous;button.focus_neighbor_right=next

func relayout():
 if not is_instance_valid(panel):return
 if is_instance_valid(preview):preview.relayout()
 var m=host.ui_metrics
 panel.size=Vector2(minf(1320,m.safe.size.x),m.safe.size.y if host.is_android else minf(780,m.safe.size.y))
 panel.position=m.safe.position+(m.safe.size-panel.size)*0.5
 if not is_instance_valid(categories_scroll):return
 var sidebar=minf(maxf(208,m.body*5.0),panel.size.x*0.25) if host.is_android else minf(maxf(208,m.body*7.0+m.padding*2),panel.size.x*0.38)
 categories_scroll.custom_minimum_size.x=sidebar
 body.add_theme_constant_override("separation",mini(int(m.gap),8) if host.is_android else int(m.gap))
 search.get_parent().add_theme_constant_override("separation",mini(int(m.gap),8) if host.is_android else int(m.gap))
 category_column.add_theme_constant_override("separation",int(m.gap))
 categories_scroll.get_parent().add_theme_constant_override("separation",int(m.padding))
 for tab in tabs:
  host.ui_metrics.button(tab);tab.custom_minimum_size.x=0
  if host.is_android:tab.add_theme_font_size_override("font_size",mini(m.button_font,maxi(22,roundi(m.safe.size.y*0.035))))
 host.ui_metrics.button(my_items);my_items.custom_minimum_size.x=0
 if host.is_android:my_items.add_theme_font_size_override("font_size",mini(m.button_font,maxi(22,roundi(m.safe.size.y*0.035))))
 host.ui_metrics.button(close_button)
 search.custom_minimum_size=Vector2(0,m.hit)
 search.add_theme_font_size_override("font_size",m.body)
 for button in [previous_page,next_page]:
  host.ui_metrics.button(button)
 page_label.add_theme_font_size_override("font_size",m.small)
 hide_purchased.custom_minimum_size.y=m.hit
 hide_purchased.add_theme_font_size_override("font_size",m.small)
 heading.add_theme_font_size_override("font_size",m.title)
 category_title.add_theme_font_size_override("font_size",m.title)
 category_title.visible=not host.is_android
 category_description.add_theme_font_size_override("font_size",m.small)
 category_description.visible=not host.is_android
 balance.add_theme_font_size_override("font_size",m.body)
 var compact_font=mini(m.small,maxi(18,roundi(m.safe.size.y*0.027))) if host.is_android else m.small
 notice.add_theme_font_size_override("font_size",compact_font)
 sale_heading.add_theme_font_size_override("font_size",mini(m.body+2,maxi(22,roundi(m.safe.size.y*0.035))) if host.is_android else m.title)
 sale_details.add_theme_font_size_override("font_size",compact_font)
 sale_details.visible=not host.is_android
 sale_banner.get_child(0).add_theme_constant_override("separation",4)
 var sale_style=sale_banner.get_theme_stylebox("panel")
 sale_style.content_margin_top=6;sale_style.content_margin_bottom=6
 wallet_icon.custom_minimum_size=Vector2.ONE*m.body*1.25
 empty_icon.custom_minimum_size.y=96
 empty_icon.visible=not host.is_android
 empty_title.add_theme_font_size_override("font_size",m.body)
 empty_hint.add_theme_font_size_override("font_size",m.small)
 grid.add_theme_constant_override("h_separation",int(m.gap))
 grid.add_theme_constant_override("v_separation",int(m.gap))
 fit_grid()
 fit_product_details()
