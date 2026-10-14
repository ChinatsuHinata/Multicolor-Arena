extends "res://tests/support/ui_base.gd"
const RankBadge=preload("res://scripts/rank_badge.gd")

class PreviewSession:
 extends RefCounted
 var room={"undo_request":{},"status":"playing","ranks":[]}
 var read_only=false
 var replay_mode=false
 var connected=true
 var paused=false
 var latency_caption="42 ms"
 func ended() -> bool:return false
 func can_act(_in_match: bool=false) -> bool:return not read_only
 func latency_text() -> String:return latency_caption
 func connection_status() -> String:return "观战 · 公开视角" if read_only else "已连接"

func frames(count: int=3):
 for i in range(count):await process_frame

func check_player(who: int,rank: Dictionary):
 var widget=view.life_widgets[who]
 var button=widget.button
 var labels=[widget.BattlePlayerName,widget.BattleLifeValue,widget.BattleRank]
 expect(widget.BattleRank.text==RankBadge.caption(rank),"rank follows engine seat "+str(who))
 expect(widget.BattlePlayerName.text==view.player_caption(who) and widget.BattleLifeValue.text==str(e.players[who].life),"nickname and life value remain available "+str(who))
 for label in labels:
  expect(button.get_global_rect().grow(1).encloses(label.get_global_rect()),"player information fits its life panel: "+str(label.name))
  expect(not label.get_rect().intersects(widget.bar.get_rect()),"player information leaves the blood bar clear: "+str(label.name))
  expect(label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"rank information does not intercept target selection")
 expect(not widget.BattlePlayerName.get_rect().intersects(widget.BattleLifeValue.get_rect()) and not widget.BattlePlayerName.get_rect().intersects(widget.BattleRank.get_rect()),"nickname, life and rank have separate rows")
 expect(app.ui_metrics.safe.grow(1).encloses(button.get_global_rect()),"ranked life panel fits the safe screen")
 for warning in widget.get("curse_warnings",[]):
  expect(labels.all(func(label):return not warning.get_rect().intersects(label.get_rect())) and not warning.get_rect().intersects(widget.bar.get_rect()),"curse warnings do not cover rank or blood")

func run():
 root.gui_embed_subwindows=true;root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/battle-rank-display/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 var desktop_font=app.theme.default_font
 app.load_legacy_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;clean()
 e.player_names=["很长的对局选手昵称一二三四五六七八","另一位实际对局选手"]
 e.players[0].life=123;e.players[1].life=7
 e.players[0].etb_curse=4;e.players[1].etb_curse=4
 var offline=e
 e=preload("res://net/remote_duel.gd").new()
 e.apply_snapshot(preload("res://net/observer_projection.gd").build(offline));view.engine=e;view.table.duel=e
 var session=PreviewSession.new();view.network_session=session
 e.session=session
 var ranks=[{"tier":1,"level":2,"stars":2},{"tier":4,"position":1234}]
 session.room.ranks=ranks
 for fixture in [[false,Vector2i(1600,900),0],[true,Vector2i(1280,720),160],[true,Vector2i(1280,720),240],[true,Vector2i(2340,1080),420]]:
  root.size=fixture[1]
  root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if fixture[0] else Window.CONTENT_SCALE_ASPECT_KEEP
  app.is_android=fixture[0];view.is_android=fixture[0];app.layout_dpi_override=fixture[2]
  app.layout_safe_override=Rect2(20,0,fixture[1].x-40,fixture[1].y-12) if fixture[0] else Rect2()
  app.theme.default_font=preload("res://assets/fonts/NotoSansSC-Regular.tres") if fixture[0] else desktop_font
  app.refresh_ui_metrics();view.resize_world();await frames()
  for seat in [0,1]:
   view.local_seat=seat;view.table.local_seat=seat;e.seat=seat
   e.players[0].etb_curse=4;e.players[1].etb_curse=4
   view.render();await frames()
   for who in [0,1]:check_player(who,ranks[who])
   if view.is_android:
    expect(not view.life_widgets[1-seat].button.get_global_rect().intersects(view.hud.get_node("AndroidCameraFocusToggle").get_global_rect()),"rank panel clears the camera button")
    expect(not view.life_widgets[seat].button.get_global_rect().intersects(view.hud.get_node("HandDisplayToggle").get_global_rect()),"rank panel clears the hand toggle")
  session.read_only=true;session.replay_mode=true
  app.account_rank={"tier":0,"level":2,"stars":0}
  view.render();await frames()
  expect(view.life_widgets[0].BattleRank.text==RankBadge.caption(ranks[0]) and view.life_widgets[1].BattleRank.text==RankBadge.caption(ranks[1]),"spectating and replay show contestants rather than the viewer account")
  session.read_only=false;session.replay_mode=false
  for latency in ["你 30000 ms · 对手 30000 ms","你 123456 ms · 对手 987654 ms","42 ms"]:
   session.latency_caption=latency
   view.update_network_latency_text();await frames()
   var latency_label=view.network_latency_label
   var natural=latency_label.get_theme_font("font").get_multiline_string_size(latency_label.text,HORIZONTAL_ALIGNMENT_RIGHT,latency_label.size.x,latency_label.get_theme_font_size("font_size"))
   expect(latency_label.text.ends_with(latency) and natural.x<=latency_label.size.x+1 and natural.y<=latency_label.size.y+1,"long latency values fit and remain complete after refresh")
   if view.is_android:expect(view.responsive.network_latency_rect().size.y>=latency_label.size.y,"layout reserves the actual refreshed latency height")
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://work/battle-rank-"+("android-" if fixture[0] else "desktop-")+str(fixture[2])+".png")
 for invalid in [[],{},[{}],[{},{}],["invalid",null]]:
  session.room.ranks=invalid
  view.render();await frames()
  expect(view.life_widgets.values().all(func(widget):return not widget.has("BattleRank")),"missing or invalid rank data hides rank without inventing a default")
 session.room.ranks=ranks
 expect(view.battle_rank(-1).is_empty() and view.battle_rank(2).is_empty(),"invalid player seat has no rank")
 view.network_session=null
 view.engine=offline;view.table.duel=offline
 view.render();await frames()
 expect(view.life_widgets.values().all(func(widget):return not widget.has("BattleRank") and not widget.button.text.is_empty()),"offline battle keeps the existing life display")
 print("BATTLE RANK DISPLAY: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
