extends "res://tests/support/ui_base.gd"
const ShopPopup=preload("res://scripts/shop_popup.gd")
const DEMO="emotes_reimu"
const EmoteProfiles=preload("res://scripts/rules/leader_emotes.gd")

class OfflineTasks extends "res://scripts/task_service.gd":
 func refresh():pass
 func purchase(product_id: String,expected_price: int=-1):
  if product_id not in snapshot.get("purchased_product_ids",[]):
   snapshot.coins-=expected_price
   snapshot.purchased_product_ids=[product_id]
  changed.emit();purchase_finished.emit(true,"购买成功，可在我的商品中管理对战开关")

func frames(count: int=8):
 for i in range(count):await process_frame

func click(at: Vector2,button: int=MOUSE_BUTTON_LEFT):
 var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
 root.push_input(motion,true);await process_frame
 await super.click(at,button)

func check_bounds(popup):
 var safe=app.ui_metrics.safe.grow(2)
 if not safe.encloses(popup.panel.get_global_rect()):print("SHOP BOUNDS safe=",safe," panel=",popup.panel.get_global_rect()," min=",popup.panel.get_combined_minimum_size())
 expect(safe.encloses(popup.panel.get_global_rect()),"shop panel fits the safe area")
 for control in [popup.heading,popup.balance,popup.close_button,popup.categories_scroll,popup.scroll,popup.notice,popup.hide_purchased,popup.search,popup.previous_page,popup.next_page,popup.page_label]:
  if not control.visible:continue
  expect(popup.panel.get_global_rect().grow(1).encloses(control.get_global_rect()),"shop contains "+control.name)
 if popup.sale_banner.visible:
  expect(popup.panel.get_global_rect().encloses(popup.sale_banner.get_global_rect()),"opening sale banner fits inside the shop")
  expect(not popup.sale_banner.get_global_rect().intersects(popup.search.get_global_rect()),"opening banner does not overlap browsing controls")
 for tile in popup.grid.get_children():
  var art=tile.find_child("ProductArt",true,false)
  if app.is_android:
   expect(popup.scroll.get_global_rect().grow(1).encloses(tile.get_global_rect()),"Android product tile is fully visible without scrolling")
   expect(is_equal_approx(tile.position.y,popup.grid.get_child(0).position.y),"Android products occupy one row")
   expect(art.size.y>=48,"Android product keeps visible artwork")
   var column=tile.get_child(0)
   expect(column.get_child_count()==3,"Android tile contains only artwork, title and action")
  var badge=art.get_node_or_null("SaleBadge")
  if badge==null:continue
  expect(badge.get_parent()==art and popup.product_image_rect(art).grow(1).encloses(badge.get_rect()),"sale badge is inside its product image")
  expect(badge.position.is_equal_approx(popup.product_image_rect(art).end-badge.size),"sale badge sits at the bottom right of the image")
 expect(not popup.balance.get_global_rect().intersects(popup.heading.get_global_rect()),"wallet does not overlap the title")
 expect(not popup.balance.get_global_rect().intersects(popup.close_button.get_global_rect()),"wallet does not overlap close")
 expect(not popup.hide_purchased.get_global_rect().intersects(popup.category_title.get_global_rect()),"purchase filter does not overlap category title")
 if app.is_android:
  expect(popup.scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and popup.scroll.get_v_scroll_bar().max_value<=popup.scroll.size.y+1,"Android product row does not need vertical scrolling")
 for button in [popup.previous_page,popup.next_page]:
  var text_width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
  expect(button.size.x>=text_width+app.ui_metrics.padding*2,"pagination button caption remains visible")
 if popup.showing_owned:expect(popup.categories_scroll.get_global_rect().encloses(popup.my_items.get_global_rect()),"My Products keeps its selected navigation entry visible")
 if popup.empty_state.visible:
  expect(popup.empty_title.get_line_count()==1,"empty-state title stays on one line")
  expect(popup.scroll.get_global_rect().encloses(popup.empty_hint.get_global_rect()),"empty-state hint remains visible")

func close_with(key: int):
 var event=InputEventKey.new();event.keycode=key;event.pressed=true;root.push_input(event,true)
 await frames()
 expect(not app.menu_popup_open(),"back key closes shop")

func search_for(popup,text: String):
 popup.search.grab_focus();popup.search.text=text;popup.search.text_changed.emit(text);await frames()
 expect(root.gui_get_focus_owner()==popup.search,"search keeps keyboard focus while results change")

func set_sale_time(now: int):
 app.shop_inventory.server_time=now;app.shop_inventory.server_tick_ms=Time.get_ticks_msec()

func verify_sale(popup):
 var sale=app.shop_inventory.sale
 set_sale_time(int(sale.starts_at)+3600)
 popup.select_category(0);await frames()
 expect(popup.result_count==popup.catalogue.size() and popup.page_count==ceili(float(popup.catalogue.size())/ShopPopup.PAGE_SIZE),"every product appears in the special category with pagination")
 expect(popup.sale_banner.visible and popup.sale_heading.text.contains("新店开业酬宾") and popup.sale_details.text.contains("11月2日 00:00"),"opening sale and deadline are prominent")
 check_bounds(popup)
 await capture("shop-opening-sale")
 app.task_service.snapshot.coins=5;app.task_service.changed.emit();await frames()
 var buy=popup.find_child("BuyProduct_"+DEMO,true,false)
 expect(buy.text=="5" and not buy.disabled,"five copper is enough for the discounted purchase")
 popup.buy_product(DEMO);await frames()
 expect(popup.purchase_dialog.dialog_text.contains("花费 5 铜钱") and popup.purchase_dialog.dialog_text.contains("原价 10"),"confirmation shows the actual sale price and original price")
 set_sale_time(int(sale.ends_at));await frames()
 expect(not popup.sale_banner.visible and popup.grid.get_child_count()==0 and popup.empty_title.text.contains("已结束"),"open shop expires its banner and specials automatically at the deadline")
 popup.purchase_dialog.confirmed.emit();await frames()
 expect(not app.shop_inventory.owns(DEMO) and app.task_service.snapshot.coins==5 and popup.notice.text.contains("重新确认"),"stale sale confirmation never spends the higher regular price")
 popup.select_category(1);await frames()
 expect(popup.result_count==popup.catalogue.size() and popup.find_child("SaleBadge",true,false)==null,"original category still contains all products after expiry without discount badges")
 expect(popup.find_child("BuyProduct_"+DEMO,true,false).text=="10","regular price returns at the deadline")
 await capture("shop-sale-ended")
 set_sale_time(int(sale.starts_at)+3600)
 app.task_service.snapshot.coins=128;app.task_service.changed.emit();await frames()

func verify_browsing(popup):
 expect(popup.page==0 and popup.page_count==3 and popup.previous_page.disabled and not popup.next_page.disabled,"first page shows bounded navigation")
 await click(popup.next_page.get_global_rect().get_center());await frames()
 expect(popup.page==1 and popup.grid.get_child_count()==4 and not popup.next_page.disabled,"next page renders the middle products")
 expect(popup.grid.get_node_or_null("ShopProduct_6")!=null and popup.grid.get_node_or_null("ShopProduct_0")==null,"pages contain different products")
 await click(popup.next_page.get_global_rect().get_center());await frames()
 expect(popup.page==2 and popup.grid.get_child_count()==1 and popup.next_page.disabled,"last page renders only the remaining product")
 app.menu();await frames()
 expect(popup.page==2,"menu layout rebuild retains current page")
 await search_for(popup,"测试闪卡 8")
 expect(popup.page==0 and popup.page_count==1 and popup.result_count==1,"search on last page resets to first matching page")
 expect(popup.previous_page.disabled and popup.next_page.disabled,"one result disables both page buttons")
 await search_for(popup,"   ")
 expect(popup.result_count==9 and popup.page_count==3,"whitespace search restores category")
 await click(popup.next_page.get_global_rect().get_center());await frames()
 await click(popup.previous_page.get_global_rect().get_center());await frames()
 expect(popup.page==0,"previous page returns to the first page")
 await click(popup.hide_purchased.get_global_rect().get_center());await frames()
 popup.change_page(2);await frames()
 app.task_service.snapshot.purchased_product_ids=["4","5","6","7","8"];app.task_service.changed.emit();await frames()
 expect(popup.page==0 and popup.page_count==1 and popup.result_count==4,"new purchases clamp a vanished last page")
 app.task_service.snapshot.purchased_product_ids=[];app.task_service.changed.emit();await frames()
 await click(popup.hide_purchased.get_global_rect().get_center());await frames()
 popup.select_category(1);await frames()
 await search_for(popup," 灵梦 ")
 expect(popup.result_count==1 and popup.grid.get_node_or_null("ShopProduct_"+DEMO)!=null,"leader name supports partial search and trimmed whitespace")
 await search_for(popup,"大结界的巫女")
 expect(popup.result_count==1,"leader title finds its dialogue pack")
 await search_for(popup,"CHARACTER-REI-001")
 expect(popup.result_count==1,"leader ID search ignores letter case")
 await search_for(popup,"不存在的自机")
 expect(popup.result_count==0 and popup.empty_title.text=="未找到匹配商品" and popup.page_count==1,"no matches explains search and keeps valid pagination")
 await capture("shop-search-empty")
 await search_for(popup,"")
 popup.select_category(4);await frames()

func verify_dialogue_pages(popup):
 popup.select_category(1);await frames()
 for index in range(popup.page_count):
  popup.page=index;popup.render_products();await frames()
  expect(popup.grid.get_child_count()==mini(ShopPopup.PAGE_SIZE,popup.result_count-index*ShopPopup.PAGE_SIZE),"dialogue page shows its products: "+str(index+1))
  check_bounds(popup)
  await capture("shop-dialogue-page-"+str(index+1))
 popup.page=0;popup.render_products();await frames()

func verify_purchase_filter(popup):
 app.task_service.snapshot.purchased_product_ids=["0","2","unlisted",null,3,""]
 app.task_service.changed.emit();await frames()
 expect((popup.result_count==9 and popup.grid.get_child_count()==mini(9,ShopPopup.PAGE_SIZE)),"default filter still shows purchased products")
 expect(popup.grid.get_node("ShopProduct_0").find_child("PurchasedBadge",true,false)!=null,"purchased products have a visible badge")
 await click(popup.hide_purchased.get_global_rect().get_center());await frames()
 expect(popup.hide_purchased.button_pressed and (popup.result_count==7 and popup.grid.get_child_count()==mini(7,ShopPopup.PAGE_SIZE)),"filter hides only purchased product IDs")
 expect(popup.grid.get_node_or_null("ShopProduct_0")==null and popup.grid.get_node_or_null("ShopProduct_2")==null,"purchased tiles are removed from the grid")
 popup.select_category(0);await frames()
 expect(popup.hide_purchased.button_pressed and popup.result_count==popup.catalogue.size()-2,"special category keeps the same purchased-product filtering")
 popup.select_category(4);await frames()
 expect((popup.result_count==7 and popup.grid.get_child_count()==mini(7,ShopPopup.PAGE_SIZE)),"category switch keeps purchase filtering")
 app.menu();await frames()
 expect(app.menu_popup==popup and popup.hide_purchased.button_pressed and (popup.result_count==7 and popup.grid.get_child_count()==mini(7,ShopPopup.PAGE_SIZE)),"menu rebuild retains filter state")
 app.task_service.snapshot.purchased_product_ids=["0","1","2","3","4","5","6","7","8"]
 app.task_service.changed.emit();await frames()
 expect(popup.grid.get_child_count()==0 and popup.empty_state.visible,"new purchases immediately update the filtered grid")
 expect(popup.empty_title.text=="暂无未购商品" and popup.empty_hint.text.contains("取消筛选"),"all-purchased category explains how to reveal hidden goods")
 await capture("shop-purchased-filter")
 await click(popup.hide_purchased.get_global_rect().get_center());await frames()
 expect(not popup.hide_purchased.button_pressed and (popup.result_count==9 and popup.grid.get_child_count()==mini(9,ShopPopup.PAGE_SIZE)),"unchecking filter restores purchased goods")
 await click(popup.hide_purchased.get_global_rect().get_center());await frames()
 app.account_name="OTHER_TEST_ONLY";app.account_token="other";app.sync_tasks();await frames()
 expect((popup.result_count==9 and popup.grid.get_child_count()==mini(9,ShopPopup.PAGE_SIZE)) and popup.purchased_ids.is_empty(),"account switch clears previous purchase ownership")
 app.account_name="TEST_ONLY_shop";app.account_token="TEST_ONLY_offline";app.sync_tasks()
 app.task_service.snapshot={"coins":128,"purchased_product_ids":["0"]};app.task_service.changed.emit();await frames()
 expect((popup.result_count==8 and popup.grid.get_child_count()==mini(8,ShopPopup.PAGE_SIZE)),"current account purchase snapshot reapplies filtering")
 app.task_service.snapshot.erase("purchased_product_ids");app.task_service.changed.emit();await frames()
 expect((popup.result_count==9 and popup.grid.get_child_count()==mini(9,ShopPopup.PAGE_SIZE)),"snapshots without purchase records preserve all products")

func verify_my_products(popup):
 popup.select_category(1);await frames()
 popup.hide_purchased.set_pressed_no_signal(false);app.shop_hide_purchased=false;popup.render_products();await frames()
 var claim=popup.find_child("BuyProduct_"+DEMO,true,false)
 expect(claim!=null and not claim.disabled,"logged-in player can claim leader dialogue product")
 expect(claim.text=="5" and claim.icon!=null and claim.icon_alignment==HORIZONTAL_ALIGNMENT_RIGHT,"purchase button shows five copper during the sale")
 popup.scroll.ensure_control_visible(claim);await frames()
 await capture("shop-emote-products")
 await click(claim.get_global_rect().get_center());await frames()
 expect(is_instance_valid(popup.purchase_dialog) and popup.purchase_dialog.visible,"click opens purchase confirmation")
 expect(not app.shop_inventory.owns(DEMO) and app.task_service.snapshot.coins==128,"opening confirmation never purchases")
 popup.purchase_dialog.canceled.emit();await frames()
 expect(not app.shop_inventory.owns(DEMO) and app.task_service.snapshot.coins==128,"cancelling confirmation never spends copper")
 await click(claim.get_global_rect().get_center());await frames()
 expect(is_instance_valid(popup.purchase_dialog) and popup.purchase_dialog.visible,"every purchase attempt opens confirmation again")
 await capture("shop-purchase-confirmation")
 popup.purchase_dialog.confirmed.emit();await frames()
 expect(app.shop_inventory.owns(DEMO) and app.task_service.snapshot.coins==123,"purchase grants ownership and debits the discounted price")
 popup.categories_scroll.ensure_control_visible(popup.my_items);await frames()
 await click(popup.my_items.get_global_rect().get_center());await frames()
 expect(popup.showing_owned and popup.grid.get_child_count()==1,"My Products shows only current account's purchased item")
 await search_for(popup,"魔理沙")
 expect(popup.result_count==0,"owned search cannot reveal unowned products")
 await search_for(popup,"灵梦")
 expect(popup.result_count==1,"owned search finds a purchased leader")
 await search_for(popup,"")
 expect(not popup.hide_purchased.visible,"hide-purchased filter does not hide owned inventory")
 var toggle=popup.find_child("BattleEnable_"+DEMO,true,false)
 expect(toggle!=null and toggle.button_pressed,"owned item offers a default-on battle switch")
 popup.scroll.ensure_control_visible(toggle);await frames()
 await click(toggle.get_global_rect().get_center());await frames()
 expect(not app.shop_inventory.battle_enabled(DEMO),"battle switch disables the purchased product")
 toggle=popup.find_child("BattleEnable_"+DEMO,true,false)
 await click(toggle.get_global_rect().get_center());await frames()
 expect(app.shop_inventory.battle_enabled(DEMO),"battle switch re-enables the purchased product")
 await capture("shop-my-products")
 app.menu();await frames()
 expect(app.menu_popup==popup and popup.showing_owned,"menu rebuild retains My Products view")
 app.close_menu_popup();app.open_shop();await frames();popup=app.menu_popup;popup.show_my_items();await frames()
 expect(popup.find_child("BattleEnable_"+DEMO,true,false).button_pressed,"reopening inventory preserves the saved switch")
 # Use the real battle and existing emote presenter, not a storefront-only flag.
 app.decks[app.player_choice].leader="character-rei-001"
 app.debug_mode=true;app.begin_battle(true);await frames(20)
 view=app.duel_view;e=view.engine;view.replay_recording.finished=true
 expect(view.battle_products.has(DEMO) and view.emotes.button.visible,"enabled pack activates the actual local battle emote entry")
 expect(e.leader_emote_profiles[0].enabled and not e.leader_emote_profiles[1].enabled,"pack enables only the local player's leader")
 e.phase="main";e.pending={};e.entry_choices=[];e.priority=0;e.presentation_events.clear();view.reveal_player.reset()
 for kind in EmoteProfiles.KINDS:
  e.emote_ready_at[0]=0
  expect(e.send_emote(0,kind).is_empty(),"equipped pack sends leader emote "+kind)
  view.render();await frames()
  expect(view.emotes.bubbles.has(0) and view.emotes.bubbles[0].message==EmoteProfiles.PROFILES["character-rei-001"].lines[kind],"battle displays configured dialogue "+kind)
 await capture("shop-emote-battle")
 app.shop_inventory.set_battle_enabled(DEMO,false)
 expect(view.battle_products.has(DEMO),"current battle keeps its starting equipment")
 app.begin_battle(true);await frames(15);view=app.duel_view;e=view.engine;view.replay_recording.finished=true
 expect(not view.battle_products.has(DEMO) and not view.emotes.button.visible,"disabled pack no longer enables emotes in next battle")
 app.debug_mode=false;app.menu();await frames();app.open_shop();await frames()
 return app.menu_popup

func verify_mobile_layout():
 app.close_menu_popup();app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 for case in [{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(2340,1080),"dpi":360.0},{"size":Vector2i(1024,576),"dpi":192.0},{"size":Vector2i(1280,720),"dpi":420.0}]:
  root.size=case.size;app.layout_dpi_override=case.dpi
  app.layout_safe_override=Rect2(60,0,case.size.x-84,case.size.y-24)
  await frames();app.menu();await frames();app.open_shop();await frames()
  var popup=app.menu_popup;popup.select_category(1);await frames()
  for index in range(popup.page_count):
   popup.page=index;popup.render_products();await frames();check_bounds(popup)
  popup.page=0;popup.render_products();await frames()
  var image=popup.grid.get_child(0).find_child("ProductDetails_*",true,false)
  await click(image.get_global_rect().get_center());await frames()
  expect(is_instance_valid(popup.detail_overlay),"mobile image opens product details")
  expect(app.ui_metrics.safe.grow(2).encloses(popup.detail_panel.get_global_rect()),"product details fit the mobile safe area")
  await capture("shop-details-android-%d" % int(case.dpi))
  await click(popup.find_child("CloseProductDetails",true,false).get_global_rect().get_center());await frames()
  expect(app.menu_popup==popup and not is_instance_valid(popup.detail_overlay),"closing product details preserves mobile catalogue")
  await capture("shop-products-android-%d" % int(case.dpi))
  app.close_menu_popup();await frames()

func run():
 var folder="res://work/shop-ui/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 Store.Paths.root_override=ProjectSettings.globalize_path(folder)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=folder.path_join("settings.json");app.account_session_path=folder.path_join("account.json")
 app.tutorial_local_directory=folder.path_join("tutorials")
 app.tournament_server_url="ws://127.0.0.1:1"
 app.task_service.free();app.task_service=OfflineTasks.new()
 root.add_child(app);await frames(30)
 set_sale_time(int(app.shop_inventory.sale.starts_at)+3600)
 expect(is_instance_valid(app.shop_button),"main menu includes shop entry")
 expect(app.shop_button.get_global_rect().position.x>app.screen.size.x*0.5,"shop entry is at top right")
 for other in [app.task_button,app.mailbox_button,app.tournament_button]:
  expect(not app.shop_button.get_global_rect().intersects(other.get_global_rect()),"shop avoids "+other.name)
 app.shop_button.grab_focus()
 await click(app.shop_button.get_global_rect().get_center());await frames()
 var popup=app.menu_popup
 expect(popup is ShopPopup and popup.heading.text=="香霖堂","shop icon opens 香霖堂")
 expect(popup.tabs.size()==7,"shop has seven categories")
 expect(not popup.catalogue.is_empty() and popup.catalogue.all(func(item):return item.price==10 and not item.get("test_only",false)) and popup.result_count==popup.catalogue.size(),"all paid products appear in specials without changing base prices")
 expect(not popup.hide_purchased.button_pressed,"purchased-product filter starts disabled")
 expect(popup.balance.text=="铜钱：—" and popup.notice.text.contains("登录"),"guest wallet has a clear unknown state")
 check_bounds(popup)
 await capture("shop-desktop")
 for index in range(popup.tabs.size()):
  popup.categories_scroll.ensure_control_visible(popup.tabs[index]);await frames()
  await click(popup.tabs[index].get_global_rect().get_center());await frames()
  expect(popup.selected==index and popup.empty_state.visible==(index not in [0,1]),"category switches to expected catalogue "+str(index))
  if index==1:expect(popup.find_child("BuyProduct_"+DEMO,true,false).disabled,"guest cannot claim paid product")
  expect(popup.tabs.filter(func(tab):return tab.button_pressed).size()==1,"exactly one category remains selected")
 app.account_name="TEST_ONLY_shop";app.account_token="TEST_ONLY_offline";app.sync_tasks()
 app.task_service.snapshot={"coins":128};app.task_service.changed.emit();await frames()
 set_sale_time(int(app.shop_inventory.sale.starts_at)+3600)
 expect(popup.balance.text=="铜钱：128" and app.task_balance.text=="铜钱：128","shop shares the current account wallet")
 if "--mobile-only" in OS.get_cmdline_user_args():
  await verify_mobile_layout()
  print("SHOP MOBILE: ",checks," checks; ",failures.size()," failures")
  app.queue_free();await frames();quit(0 if failures.is_empty() else 1);return
 if "--preview-only" in OS.get_cmdline_user_args():
  popup.select_category(1);await frames();await capture("shop-emote-products")
  app.queue_free();await frames();quit(0);return
 await capture("shop-wallet")
 await verify_sale(popup)
 await verify_dialogue_pages(popup)
 app.task_service.snapshot.coins=0;app.task_service.changed.emit();await frames()
 expect(popup.balance.text=="铜钱：0","zero balance is shown as zero")
 app.task_service.snapshot.coins=999999999;app.task_service.changed.emit();await frames();check_bounds(popup)
 app.task_service.snapshot.coins=128;app.task_service.changed.emit()
 popup.select_category(4);app.menu();await frames()
 expect(app.menu_popup==popup and popup.selected==4,"menu refresh preserves shop and selected category")
 # Fixture products verify the grid; nothing is written to the catalogue.
 for index in range(9):popup.catalogue.append({"id":str(index),"category":"foil","name":"测试闪卡 "+str(index),"description":"仅用于布局验证","image":"res://assets/card_back.svg","price":10})
 popup.select_category(4);await frames()
 expect(popup.grid.columns>=2 and (popup.result_count==9 and popup.grid.get_child_count()==mini(9,ShopPopup.PAGE_SIZE)) and not popup.empty_state.visible,"goods are tiled in multiple columns")
 var first=popup.grid.get_child(0);var second=popup.grid.get_child(1)
 expect(first.position.y==second.position.y and first.position.x<second.position.x,"goods occupy the same grid row")
 await capture("shop-grid")
 await verify_browsing(popup)
 await verify_purchase_filter(popup)
 popup=await verify_my_products(popup)
 app.shop_hide_purchased=true;popup.hide_purchased.set_pressed_no_signal(true)
 popup.select_category(0);await frames()
 expect(popup.result_count==popup.catalogue.size()-1 and not popup.empty_state.visible,"special category includes unpurchased goods from every original category")
 await close_with(KEY_ESCAPE)
 expect(root.gui_get_focus_owner()==app.shop_button or root.gui_get_focus_owner()==null,"close does not focus a freed menu entry")
 app.is_android=true;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 for case in [{"size":Vector2i(1280,720),"dpi":240.0},{"size":Vector2i(2340,1080),"dpi":360.0},{"size":Vector2i(1024,576),"dpi":192.0},{"size":Vector2i(1280,720),"dpi":420.0}]:
  root.size=case.size;app.layout_dpi_override=case.dpi
  app.layout_safe_override=Rect2(60,0,case.size.x-84,case.size.y-24)
  await frames();app.menu();await frames()
  expect(app.ui_metrics.safe.grow(2).encloses(app.shop_button.get_global_rect()),"Android shop entry fits safe area "+str(case.size))
  for other in [app.task_button,app.mailbox_button,app.tournament_button,app.task_balance.get_parent()]:
   expect(not app.shop_button.get_global_rect().intersects(other.get_global_rect()),"Android shop entry avoids "+other.name)
  await click(app.shop_button.get_global_rect().get_center());await frames()
  popup=app.menu_popup;check_bounds(popup)
  popup.select_category(1);await frames();check_bounds(popup)
  var product=popup.grid.get_child(0)
  var details=product.find_child("ProductDetails_*",true,false)
  await click(details.get_global_rect().get_center());await frames()
  expect(is_instance_valid(popup.detail_overlay) and popup.detail_panel.get_global_rect().encloses(popup.find_child("ProductDescription",true,false).get_global_rect()),"Android image click opens readable product description")
  var back=InputEventKey.new();back.keycode=KEY_BACK;back.pressed=true;root.push_input(back,true);await frames()
  expect(not is_instance_valid(popup.detail_overlay) and app.menu_popup==popup,"Android back closes details and retains shop")
  popup.change_page(1);await frames();check_bounds(popup)
  expect(popup.grid.get_child_count()<=popup.products_per_page(),"Android pagination keeps one row on later pages")
  expect(popup.hide_purchased.button_pressed,"reopening shop remembers purchase filter")
  expect(popup.hide_purchased.size.y>=app.ui_metrics.hit,"purchase filter has a full touch target")
  await click(popup.hide_purchased.get_global_rect().get_center());await frames()
  expect(not popup.hide_purchased.button_pressed,"Android filter responds to input")
  await click(popup.hide_purchased.get_global_rect().get_center());await frames()
  expect(popup.hide_purchased.button_pressed,"Android filter can be enabled again")
  for tab in popup.tabs:expect(tab.size.y>=app.ui_metrics.hit,"category preserves touch target")
  popup.categories_scroll.ensure_control_visible(popup.tabs[6]);await frames()
  await click(popup.tabs[6].get_global_rect().get_center());await frames()
  expect(popup.selected==6,"last category remains reachable on Android")
  await capture("shop-android-%d" % int(case.dpi))
  popup.show_my_items();await frames();check_bounds(popup)
  expect(popup.search.size.y>=app.ui_metrics.hit and popup.next_page.size.y>=app.ui_metrics.hit,"Android search and pagination preserve touch targets")
  var mobile_toggle=popup.find_child("BattleEnable_"+DEMO,true,false)
  expect(mobile_toggle!=null and mobile_toggle.size.y>=app.ui_metrics.hit,"Android owned product has an accessible battle switch")
  popup.scroll.ensure_control_visible(mobile_toggle);await frames()
  var was_enabled=app.shop_inventory.battle_enabled(DEMO)
  await click(mobile_toggle.get_global_rect().get_center());await frames()
  expect(app.shop_inventory.battle_enabled(DEMO)!=was_enabled,"Android battle switch changes saved equipment")
  await capture("shop-my-products-android-%d" % int(case.dpi))
  await close_with(KEY_BACK)
 app.is_android=false;app.layout_safe_override=Rect2();root.size=Vector2i(1600,900)
 app.sakura_ui=false;app.apply_ui_style();app.menu();await frames()
 app.shop_button.grab_focus();await click(app.shop_button.get_global_rect().get_center());await frames()
 popup=app.menu_popup;check_bounds(popup)
 await capture("shop-classic")
 app.account_name="OTHER_TEST_ONLY";app.account_token="other";app.sync_tasks();await frames()
 expect(popup.balance.text=="铜钱：—","account switch clears the previous balance")
 popup.show_my_items();await frames()
 expect(popup.grid.get_child_count()==0 and popup.empty_state.visible,"My Products clears when switching to another account")
 app.account_name="";app.account_token="";app.sync_tasks();await frames()
 expect(popup.balance.text=="铜钱：—" and popup.notice.text.contains("登录"),"logout clears shop wallet")
 expect(popup.empty_title.text.contains("登录") and popup.grid.get_child_count()==0,"guest My Products explains login requirement")
 await click(popup.close_button.get_global_rect().get_center());await frames()
 expect(not app.menu_popup_open() and root.gui_get_focus_owner()==app.shop_button,"close button restores entry focus")
 print("SHOP UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await frames()
 quit(0 if failures.is_empty() else 1)
