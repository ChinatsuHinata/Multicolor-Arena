extends "res://tests/support/ui_base.gd"

class PreviewSession:
 extends RefCounted
 var room={"undo_request":{},"status":"playing","ranks":[]}
 var read_only=false
 var replay_mode=false
 var connected=true
 var paused=false
 var local_game_id="preview"
 func ended() -> bool:return false
 func can_act(_in_match: bool=false) -> bool:return not read_only
 func latency_text() -> String:return "42 ms"
 func connection_status() -> String:return "已连接"

func frames(count: int=3):
 for i in range(count):await process_frame

func check_player(who: int,rect: Rect2,prefix: String):
 var widget=view.life_widgets[who]
 var button=widget.button as Button
 expect(button.size.is_equal_approx(rect.size),prefix+" life panel keeps its layout size: "+str(button.size)+" vs "+str(rect.size))
 expect(app.ui_metrics.safe.grow(1).encloses(button.get_global_rect()),prefix+" life panel fits the safe screen")
 var name_label=widget.get("BattlePlayerName") as Label
 var value_label=widget.get("BattleLifeValue") as Label
 expect(name_label!=null and value_label!=null,prefix+" life panel uses separate name and life labels")
 if name_label==null or value_label==null:return
 expect(button.text.is_empty(),prefix+" button text does not draw outside the labels")
 expect(value_label.text==str(e.players[who].life),prefix+" life value is complete")
 var font=value_label.get_theme_font("font")
 var natural=font.get_string_size(value_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,value_label.get_theme_font_size("font_size"))
 expect(natural.x<=value_label.size.x+0.5 and font.get_height(value_label.get_theme_font_size("font_size"))<=value_label.size.y+0.5,prefix+" life value fits its label")
 var inner=Rect2(Vector2.ZERO,button.size).grow(0.5)
 for control in [name_label,value_label,widget.bar]:
  expect(inner.encloses(control.get_rect()),prefix+" "+str(control.name)+" stays inside the life panel")
 for label in [name_label,value_label]:
  expect(not label.get_rect().intersects(widget.bar.get_rect()),prefix+" "+str(label.name)+" leaves the blood bar clear")
 expect(not name_label.get_rect().intersects(value_label.get_rect()),prefix+" name and life do not overlap")
 for warning in widget.get("curse_warnings",[]):
  expect(inner.encloses(warning.get_rect()),prefix+" curse warning stays inside the life panel")
  expect(not warning.get_rect().intersects(name_label.get_rect()) and not warning.get_rect().intersects(value_label.get_rect()),prefix+" curse warning does not cover name or life")

func run():
 root.gui_embed_subwindows=true;root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-life-panel/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;clean()
 e.player_names=["很长的对局选手昵称一二三四五六七八","Another_Very_Long_Player_Name"]
 var offline=e
 e=preload("res://net/remote_duel.gd").new()
 e.apply_snapshot(preload("res://net/observer_projection.gd").build(offline));view.engine=e;view.table.duel=e
 var session=PreviewSession.new();view.network_session=session
 e.session=session
 for fixture in [[Vector2i(1280,720),160],[Vector2i(1280,720),240],[Vector2i(2340,1080),420],[Vector2i(1920,1080),320]]:
  root.size=fixture[0];root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  app.is_android=true;view.is_android=true;app.layout_dpi_override=fixture[1]
  app.layout_safe_override=Rect2(20,0,fixture[0].x-40,fixture[0].y-12)
  app.theme.default_font=preload("res://assets/fonts/NotoSansSC-Regular.tres")
  app.refresh_ui_metrics();view.resize_world();await frames()
  for state in [[20,20,0],[123,-45,0],[12345,7,4]]:
   e.players[0].life=state[0];e.players[1].life=state[1]
   e.players[0].etb_curse=state[2];e.players[1].etb_curse=state[2]
   for seat in [0,1]:
    view.local_seat=seat;view.table.local_seat=seat;e.seat=seat
    view.render();await frames()
    var prefix="android-"+str(fixture[1])+" life "+str(state)+" seat "+str(seat)
    check_player(1-seat,view.responsive.enemy_life,prefix+" enemy")
    check_player(seat,view.responsive.own_life,prefix+" own")
   if DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://work/android-life-"+str(fixture[1])+"-"+str(state[0])+".png")
 print("ANDROID LIFE PANEL: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
