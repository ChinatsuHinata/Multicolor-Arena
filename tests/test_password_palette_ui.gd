extends "res://tests/support/ui_base.gd"

const AccountClient=preload("res://scripts/account_client.gd")
const OUTPUT="res://work/android-palette-compact"

func frames(count: int=5):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var path=ProjectSettings.globalize_path(OUTPUT)
 DirAccess.make_dir_recursive_absolute(path)
 root.get_texture().get_image().save_png(path.path_join(name+".png"))

func check_password_field(field: LineEdit,label: String):
 field.text="Ab9!中Ａ🙂空 格"
 field.set_caret_column(field.text.length())
 field.text_changed.emit(field.text)
 expect(field.text=="Ab9!" and field.get_caret_column()==4,label+" removes Chinese, fullwidth, emoji and spaces")
 expect(app.account_status_label.text.contains("英文符号"),label+" explains allowed characters")

func check_palette(dimensions: Vector2i,dpi: float,safe: Rect2,name: String):
 root.size=dimensions
 app.layout_dpi_override=dpi
 app.layout_safe_override=safe
 await frames(8)
 app.refresh_responsive_layout()
 view.render()
 await frames(8)
 var panel=view.android_palette_panel
 var scroll=view.android_palette_scroll
 expect(panel!=null and scroll!=null,name+" palette remains open")
 expect(panel.size.x/panel.size.y>3.3,name+" palette is wide and compact")
 expect(app.ui_metrics.safe.grow(2).encloses(panel.get_global_rect()),name+" palette stays in safe area")
 expect(panel.get_global_rect().grow(1).encloses(scroll.get_global_rect()),name+" scroll stays inside panel")
 var hand_toggle=view.hud.get_node("HandDisplayToggle")
 expect(not hand_toggle.get_global_rect().intersects(panel.get_global_rect()),name+" hand toggle remains unobstructed")
 var opponent_count=view.hud.get_node("OpponentHandCount")
 expect(app.ui_metrics.safe.grow(2).encloses(opponent_count.get_global_rect()) and opponent_count.get_node("HandCountValue").text==str(e.players[1].hand.size()),name+" opponent hand count remains visible and correct")
 expect(opponent_count.mouse_filter==Control.MOUSE_FILTER_IGNORE,name+" opponent hand count remains a label")
 var caption=opponent_count.get_node("OpponentHandCaption") as Label
 var caption_width=caption.get_theme_font("font").get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
 expect(caption.size.x>=caption_width+1,name+" opponent hand caption is not clipped")
 expect(caption.get_rect().end.x<=opponent_count.get_node("HandCountValue").position.x,name+" opponent caption and number do not overlap")
 var row=scroll.get_child(0)
 expect(row.get_child(6).get_global_rect().end.x<=scroll.get_global_rect().end.x+2,name+" shows seven cards across without scrolling")
 for i in range(2):
  var holder=row.get_child(i)
  var tile=holder.get_child(0)
  var art=tile.get_child(0)
  var tapped=i==0
  expect((is_equal_approx(art.rotation,PI/2) if tapped else is_zero_approx(art.rotation)),name+" card %d shows its actual orientation" % i)
  expect(scroll.get_global_rect().grow(2).end.y>=tile.get_global_rect().end.y,name+" card %d is fully visible" % i)
  for corner in [Vector2.ZERO,Vector2(art.size.x,0),art.size,Vector2(0,art.size.y)]:
   expect(tile.get_global_rect().grow(2).has_point(art.get_global_transform()*corner),name+" card %d artwork stays in its tile" % i)
 await shot(name)
 var first=view.android_palette_tiles[e.players[0].palette[0].uid]
 var at=first.get_global_rect().get_center()
 var selected_before=view.selected_in_zone("palette")
 var press=InputEventScreenTouch.new();press.index=0;press.position=at;press.pressed=true
 root.push_input(press,true);await process_frame
 await create_timer(0.65).timeout
 expect(view.inspection.visible and view.inspect_uid==e.players[0].palette[0].uid,name+" long press opens card details")
 expect(view.selected_in_zone("palette")==selected_before,name+" long press does not select the card")
 await shot(name+"-long-press-details")
 press=press.duplicate();press.pressed=false;root.push_input(press,true);await process_frame
 expect(view.selected_in_zone("palette")==selected_before,name+" releasing the long press does not select the card")
 view.inspect_id="";view.update_inspection()
 var seventh_uid=e.players[0].palette[6].uid
 at=view.android_palette_tiles[seventh_uid].get_global_rect().get_center()
 press=InputEventScreenTouch.new();press.index=0;press.position=at;press.pressed=true
 root.push_input(press,true);await process_frame
 await create_timer(0.65).timeout
 expect(view.inspection.visible and view.inspect_uid==seventh_uid,name+" seventh card long press opens its own details")
 press=press.duplicate();press.pressed=false;root.push_input(press,true);await process_frame
 view.inspect_id="";view.update_inspection()
 await click(hand_toggle.get_global_rect().get_center())
 expect(not view.hand_display_enabled,name+" hand toggle hides the hand rows")
 hand_toggle=view.hud.get_node("HandDisplayToggle")
 await click(hand_toggle.get_global_rect().get_center())
 expect(view.hand_display_enabled,name+" hand toggle restores the hand rows")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures"))
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(2160,1080)
 root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app)
 await frames()
 app.is_android=true;app.layout_dpi_override=360;app.layout_safe_override=Rect2(60,0,2076,1056)
 app.refresh_ui_metrics()
 app.account_page();await frames()
 check_password_field(app.account_password_input,"login password")
 await shot("android-login-password-filter")
 app.account_mode="register";app.account_page();await frames()
 check_password_field(app.account_password_input,"registration password")
 check_password_field(app.account_confirm_input,"registration confirmation")
 await shot("android-registration-password-filter")
 var client=AccountClient.new();app.add_child(client)
 var rejected=[]
 client.finished.connect(func(ok,message,_username):rejected.append({"ok":ok,"message":message}))
 client.submit("login","sample_user","Password中1!")
 expect(rejected.size()==1 and not rejected[0].ok and rejected[0].message.contains("英文符号"),"account request rejects non ASCII passwords before network access")
 client.queue_free()
 app.load_legacy_test_decks()
 app.begin_battle(true);view=app.duel_view;e=view.engine;view.set_process(false)
 await settle();await frames()
 var cards=app.decks[app.player_choice].main
 for i in range(12):
  var card=e.make_card(cards[i],0,"palette")
  card.tapped=i%2==0
  e.players[0].palette.append(card)
 e.phase="possession";e.pending={"kind":"possession","owner":0}
 view.render();await frames()
 await check_palette(Vector2i(2160,1080),360,Rect2(60,0,2076,1056),"android-palette-2160x1080")
 await check_palette(Vector2i(1280,720),240,Rect2(40,0,1220,704),"android-palette-1280x720")
 print("PASSWORD PALETTE UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
