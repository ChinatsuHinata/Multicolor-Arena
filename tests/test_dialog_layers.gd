extends "res://tests/support/ui_base.gd"
## Exercise embedded windows above every shared menu, including rendered pixels.
const MARKER=Color("#16e49b")
var confirmed=0
var folder="res://work/dialog-layer-tests"

class OfflineTasks extends "res://scripts/task_service.gd":
 var purchases=0
 func refresh():pass
 func purchase(product_id: String,expected_price: int=-1):
  purchases+=1;snapshot.coins-=expected_price;snapshot.purchased_product_ids=[product_id]
  changed.emit();purchase_finished.emit(true,"购买成功")

class OfflineCommunity extends Node:
 func paths() -> Array:return []
 func request(_payload: Dictionary,callback: Callable):
  callback.call_deferred({"ok":true,"announcements":[]})

func frames(count: int=8):
 for index in range(count):await process_frame

func visible_dialog() -> AcceptDialog:
 for child in app.get_children():
  if child is AcceptDialog and child.visible:return child
 return null

func activate(at: Vector2):
 var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
 root.push_input(motion,true);await process_frame
 if not app.is_android:await click(at);await frames();return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func key(code: int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func window_point(dialog: Window,control: Control,offset: Vector2=Vector2(-1,-1)) -> Vector2:
 var point=control.get_global_rect().get_center() if offset.x<0 else control.global_position+offset
 return Vector2(dialog.position)+point

func mark_dialog(dialog: AcceptDialog):
 var marker=StyleBoxFlat.new();marker.bg_color=MARKER
 marker.set_content_margin_all(12)
 for state in ["normal","hover","pressed","focus"]:dialog.get_ok_button().add_theme_stylebox_override(state,marker)
 await frames()

func verify_pixel(point: Vector2,label: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var shot=root.get_texture().get_image()
 var pixel=Vector2i(point*Vector2(shot.get_size())/root.get_visible_rect().size)
 var actual=shot.get_pixelv(pixel)
 expect(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(MARKER.r,MARKER.g,MARKER.b))<0.04,label+" is visibly drawn above the menu")
 shot.save_png(folder.path_join(label+".png"))

func verify_pixels(dialog: AcceptDialog,label: String):
 await verify_pixel(window_point(dialog,dialog.get_ok_button(),Vector2(5,5)),label)

func open_menu(kind: String):
 match kind:
  "menu":app.open_menu_popup("菜单",[["保持菜单",func():pass]])
  "shop":app.open_shop()
  "tasks":app.open_tasks()
  "announcements":app.open_announcement_mailbox()
  "rank":app.open_rank_rules()
 await frames()

func verify_menu(kind: String,prefix: String):
 await open_menu(kind)
 var popup=app.menu_popup
 expect(popup.layer>0 and popup.layer<1024,prefix+kind+" stays above the game and below embedded windows")
 app.alert("提示框必须能在菜单上显示并关闭。")
 await frames()
 var dialog=visible_dialog()
 expect(dialog!=null,prefix+kind+" opens its alert")
 if dialog==null:return
 await mark_dialog(dialog);await verify_pixels(dialog,prefix+kind+"-alert")
 await activate(popup.close_button.get_global_rect().get_center())
 expect(app.menu_popup==popup and is_instance_valid(dialog),prefix+kind+" alert blocks clicks to the menu")
 await activate(window_point(dialog,dialog.get_ok_button()))
 expect(not is_instance_valid(dialog) and app.menu_popup==popup,prefix+kind+" alert closes through its visible button and preserves the menu")
 if is_instance_valid(dialog):dialog.hide();dialog.queue_free();await frames()
 var before=confirmed
 app.confirm_action("确认框必须能取消或确认。",func():confirmed+=1)
 await frames();dialog=visible_dialog()
 await mark_dialog(dialog);await verify_pixels(dialog,prefix+kind+"-confirmation")
 await activate(window_point(dialog,dialog.get_cancel_button()))
 expect(not is_instance_valid(dialog) and confirmed==before and app.menu_popup==popup,prefix+kind+" cancel preserves the menu and does not perform the action")
 if is_instance_valid(dialog):dialog.hide();dialog.queue_free();await frames()
 app.confirm_action("确认操作",func():confirmed+=1)
 await frames();dialog=visible_dialog()
 await activate(window_point(dialog,dialog.get_ok_button()))
 expect(not is_instance_valid(dialog) and confirmed==before+1,prefix+kind+" confirmation button performs the action once")
 if is_instance_valid(dialog):dialog.hide();dialog.queue_free();await frames()
 await activate(popup.close_button.get_global_rect().get_center())
 expect(not app.menu_popup_open(),prefix+kind+" menu responds again after closing its dialogs")

func verify_purchase(prefix: String):
 app.account_name="TEST_ONLY_"+prefix;app.account_token="TEST_ONLY_"+prefix;app.sync_tasks()
 app.task_service.snapshot={"coins":128,"purchased_product_ids":[]};app.task_service.changed.emit()
 app.shop_inventory.server_time=int(app.shop_inventory.sale.starts_at)+3600
 app.shop_inventory.server_tick_ms=Time.get_ticks_msec()
 await open_menu("shop")
 var popup=app.menu_popup
 popup.select_category(1);await frames()
 var buy=popup.find_child("BuyProduct_emotes_reimu",true,false)
 var price=app.shop_inventory.price_for(app.shop_inventory.product("emotes_reimu"))
 var purchases=app.task_service.purchases
 await activate(buy.get_global_rect().get_center())
 var dialog=popup.purchase_dialog
 expect(is_instance_valid(dialog) and dialog.visible,prefix+" purchase button opens its confirmation")
 if not is_instance_valid(dialog):return
 await mark_dialog(dialog);await verify_pixels(dialog,prefix+"purchase")
 await activate(popup.next_page.get_global_rect().get_center())
 expect(popup.page==0 and app.task_service.purchases==purchases,prefix+" purchase confirmation blocks the shop and does not spend coins")
 await activate(window_point(dialog,dialog.get_cancel_button()))
 expect(not is_instance_valid(popup.purchase_dialog) and app.task_service.snapshot.coins==128,prefix+" purchase cancel releases the dialog without spending")
 await activate(buy.get_global_rect().get_center());await key(KEY_ESCAPE)
 expect(not is_instance_valid(popup.purchase_dialog) and app.menu_popup==popup,prefix+" Escape cancels only the purchase confirmation")
 await activate(buy.get_global_rect().get_center());dialog=popup.purchase_dialog
 if is_instance_valid(dialog):await activate(window_point(dialog,dialog.get_ok_button()))
 expect(app.shop_inventory.owns("emotes_reimu") and app.task_service.snapshot.coins==128-price and app.task_service.purchases==purchases+1,prefix+" actual confirmation buys once at the displayed price")
 await activate(popup.close_button.get_global_rect().get_center())
 expect(not app.menu_popup_open(),prefix+" shop remains usable after purchasing")

func verify_other_windows(prefix: String):
 await open_menu("menu")
 var popup=app.menu_popup
 var picker=FileDialog.new();picker.title="文件选择";picker.use_native_dialog=false
 picker.access=FileDialog.ACCESS_RESOURCES;picker.current_dir=folder
 picker.canceled.connect(picker.queue_free);app.add_child(picker)
 picker.popup_centered(Vector2i(800,500));await frames()
 await mark_dialog(picker);await verify_pixels(picker,prefix+"file-picker")
 await activate(window_point(picker,picker.get_cancel_button()))
 expect(not is_instance_valid(picker) and app.menu_popup==popup,prefix+" file picker cancels through its visible button")
 if is_instance_valid(picker):picker.hide();picker.queue_free();await frames()
 var choice=OptionButton.new();popup.heading.get_parent().add_child(choice)
 choice.add_item("第一项");choice.add_item("第二项");app.ui_metrics.button(choice)
 await frames();await activate(choice.get_global_rect().get_center())
 var dropdown=choice.get_popup()
 expect(dropdown.visible,prefix+" dropdown opens over the menu")
 var marker=StyleBoxFlat.new();marker.bg_color=MARKER;marker.set_content_margin_all(12)
 dropdown.add_theme_stylebox_override("panel",marker);await frames()
 await verify_pixel(Vector2(dropdown.position)+Vector2(5,5),prefix+"dropdown")
 var row_height=(dropdown.size.y-marker.get_minimum_size().y)/choice.item_count
 # PopupMenu uses mouse events, including Android's emulated touch clicks.
 await click(Vector2(dropdown.position)+Vector2(dropdown.size.x*0.5,marker.get_content_margin(SIDE_TOP)+row_height*1.5));await frames()
 expect(choice.selected==1 and not dropdown.visible and app.menu_popup==popup,prefix+" dropdown selection preserves its underlying menu")
 app.cloud_pck_download_started(100,1);await frames()
 var progress=app.auto_patch_dialog
 await mark_dialog(progress);await verify_pixels(progress,prefix+"update-progress")
 await activate(window_point(progress,progress.get_ok_button()))
 expect(not progress.visible and app.menu_popup==popup,prefix+" update progress can be hidden while the menu stays open")
 await activate(popup.close_button.get_global_rect().get_center())
 expect(not app.menu_popup_open(),prefix+" menu resumes after file, dropdown and update windows")

func run():
 var fixture=folder.path_join(str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture.path_join("portable"))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture.path_join("settings.json");app.account_session_path=fixture.path_join("account.json")
 app.tutorial_local_directory=fixture.path_join("tutorials")
 app.task_service.free();app.task_service=OfflineTasks.new()
 app.community_service=OfflineCommunity.new();app.add_child(app.community_service)
 app.tournament_server_url="ws://127.0.0.1:1"
 root.add_child(app);await frames(20)
 for mobile in [false,true]:
  app.is_android=mobile;app.refresh_ui_metrics();app.menu();await frames()
  var prefix="android-" if mobile else "desktop-"
  for kind in ["menu","shop","tasks","announcements","rank"]:await verify_menu(kind,prefix)
  await verify_purchase(prefix)
  await verify_other_windows(prefix)
 print("DIALOG LAYERS: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
