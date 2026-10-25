extends "res://tests/support/ui_base.gd"
const Emotes=preload("res://scripts/rules/leader_emotes.gd")
const Session=preload("res://net/lan_session.gd")
const Remote=preload("res://net/remote_duel.gd")
const Observer=preload("res://net/observer_projection.gd")
var fixture="res://work/leader-emotes-ui/"+str(Time.get_ticks_usec())

func frames(count: int=5):
 for i in range(count):await process_frame

func tap(at: Vector2):
 if not app.is_android:
  # Native mouse users move onto each target; let Godot update hover before pressing.
  var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
  root.push_input(motion,true);await process_frame
  await click(at);await frames();return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func prepare(enabled: bool=true):
 clean();view.emotes.reset();view.replay_recording.finished=true
 e.leader_emote_profiles[0].enabled=enabled
 view.local_seat=0;view.table.local_seat=0;view.render();await frames()

func refresh():
 view.emotes.refresh();await frames()

func rules_snapshot() -> String:
 return JSON.stringify({"players":e.players,"priority":e.priority,"active":e.active,"phase":e.phase,"pending":e.pending,"stack":e.stack,"combat":e.combat,"passes":e.passes,"log":e.log,"history":e.history,"response_clock":e.response_clock})

func emit_bubble(who: int,kind: String="greeting") -> Dictionary:
 Emotes.emit_event(e,who,kind)
 var event=e.presentation_events.back().duplicate(true)
 view.render()
 return event

func move_leader(who: int,zone: String):
 var leader=e.players[who].leader
 e.detach(leader);e.shift(leader,zone)
 if zone!="leader":e.players[who][zone].append(leader)
 e.presentation_events.clear();view.reveal_player.reset();view.render();await frames()
 view.emotes.refresh()

func check_gate(label: String):
 expect(not view.emotes.available() and view.emotes.button.disabled,label+" 禁用入口")
 view.emotes.open_wheel()
 expect(not is_instance_valid(view.emotes.wheel),label+" 无法打开饼图")

func check_input_and_gates(label: String):
 await prepare(false)
 expect(not view.emotes.button.visible and not view.emotes.available(),label+" 未开通时不显示我方表情入口")
 expect(not e.leader_emote_profiles[1].enabled,label+" 对方配置也保持未开通")
 e.leader_emote_profiles[0].enabled=true;await refresh()
 expect(view.emotes.button.visible and not view.emotes.button.disabled,label+" 临时开通测试自机后出现可用入口")
 expect(app.ui_metrics.safe.grow(1).encloses(view.emotes.button.get_global_rect()),label+" 左侧按钮位于安全区域")
 expect(view.emotes.button.get_global_rect().get_center().x<view.STAGE.get_center().x*0.5,label+" 表情入口位于战场左侧")
 expect(not view.emotes.button.get_rect().intersects(view.keep_button_rect()),label+" 表情入口不遮挡自动支付保留按钮")
 var before=rules_snapshot()
 await tap(view.emotes.button.get_global_rect().get_center())
 expect(is_instance_valid(view.emotes.wheel),label+" 实际点击表情按钮打开饼图")
 expect(rules_snapshot()==before,label+" 打开饼图不改变对局或响应时钟")
 if is_instance_valid(view.emotes.wheel):
  expect(app.ui_metrics.safe.grow(1).encloses(view.emotes.wheel.get_global_rect()),label+" 五分饼图完整位于安全区域")
  expect(view.emotes.wheel.KINDS==Emotes.KINDS,label+" 五个扇区依次为问候称赞惊讶犯错威胁")
  await capture("leader-emotes-wheel-"+label)
 var outside=view.STAGE.get_center();var outside_before=rules_snapshot()
 await tap(outside)
 expect(not is_instance_valid(view.emotes.wheel) and rules_snapshot()==outside_before,label+" 点击饼图外关闭且不会点击穿透战场")
 for index in range(Emotes.KINDS.size()):
  e.emote_ready_at[0]=0;await refresh()
  expect(view.emotes.available() and not view.emotes.button.disabled,label+" 点击前响应权与弹框条件允许发送 "+Emotes.KINDS[index])
  await tap(view.emotes.button.get_global_rect().get_center())
  var wheel=view.emotes.wheel
  expect(is_instance_valid(wheel),label+" 可以打开第 "+str(index+1)+" 个表情")
  if not is_instance_valid(wheel):continue
  var before_send=rules_snapshot()
  await tap(wheel.global_position+wheel.sector_center(index))
  expect(not is_instance_valid(view.emotes.wheel),label+" 点击扇区后关闭饼图")
  expect(view.emotes.bubbles.has(0) and view.emotes.bubbles[0].text_label.text==e.leader_emote_profiles[0].lines[Emotes.KINDS[index]],label+" 实际输入发送当前自机的配置台词 "+Emotes.KINDS[index])
  expect(rules_snapshot()==before_send,label+" 表情发送不改变游戏状态 "+Emotes.KINDS[index])
  await refresh()
  expect(e.emote_remaining(0)>9 and not view.emotes.available() and view.emotes.button.disabled,label+" 表情发送后立即进入十秒冷却")
  var serial=e.emote_serial;view.emotes.send("greeting")
  expect(e.emote_serial==serial,label+" 冷却中不能绕过入口重复发送")
 e.emote_ready_at[0]=0;e.priority=1;await refresh();check_gate(label+" 对方响应中")
 e.priority=0;e.pending={"kind":"discard","owner":0};await refresh();check_gate(label+" 规则选择弹框中")
 e.pending={};view.modal=true;await refresh();check_gate(label+" 界面弹框中")
 view.modal=false;view.local={"kind":"test"};await refresh();check_gate(label+" 未完成本地操作中")
 view.local={};app.confirm_action("表情系统测试确认框",func():pass);await refresh();check_gate(label+" 原生确认弹框中")
 for child in app.get_children():
  if child is ConfirmationDialog:child.hide();child.queue_free()
 await refresh()
 view.emotes.open_wheel();expect(is_instance_valid(view.emotes.wheel),label+" 阻碍解除后可再次打开饼图")
 e.priority=1;await refresh()
 expect(not is_instance_valid(view.emotes.wheel),label+" 失去响应权时自动关闭饼图")
 e.priority=0;await refresh();view.emotes.open_wheel()
 var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true
 root.push_input(cancel,true);await frames()
 expect(not is_instance_valid(view.emotes.wheel),label+" Escape 关闭饼图且不发送")

func check_bubble_positions(label: String):
 await prepare()
 for who in [0,1]:
  var event=emit_bubble(who);await frames();view.emotes.refresh()
  expect(view.emotes.bubbles.has(who),label+" 显示座位 "+str(who)+" 的气泡")
  if not view.emotes.bubbles.has(who):continue
  var bubble=view.emotes.bubbles[who]
  expect(bubble.points_down==(who==view.local_seat),label+" 我方尾巴向下、敌方尾巴向上")
  expect(bubble.find_child("EmoteCaption",true,false)==null and bubble.get_child_count()==1,label+" 气泡只显示台词，不包含标题或图案")
  expect(bubble.text_label.scale==Vector2.ONE and is_zero_approx(bubble.text_label.rotation) and bubble.text_label.text==event.text,label+" 敌我文字均保持正向")
  var target=view.emotes.bubble_target(who)
  expect(target.has_area(),label+" 自机区自机有气泡锚点")
  if target.has_area():
   var leader_visual=view.table.visuals.get("card_"+str(e.players[who].leader.uid))
   expect(leader_visual!=null and target.get_center().distance_to(view.projected_card_rect(leader_visual).get_center())<2,label+" 锚点指向对应自机区卡牌")
  var old=bubble;view.render();await frames()
  expect(view.emotes.bubbles.get(who)==old,label+" 重绘界面不会丢失或重建气泡")
  view.emotes.show_event(event)
  expect(view.emotes.bubbles.get(who)==old,label+" 重复事件不会再次冒泡")
  await move_leader(who,"field")
  expect(view.emotes.bubble_target(who).has_area(),label+" 自机登场后气泡跟随战场自机")
  var field_target=view.emotes.bubble_target(who)
  var visual=view.table.visuals.get("card_"+str(e.players[who].leader.uid))
  if visual!=null:expect(field_target.get_center().distance_to(view.projected_card_rect(visual).get_center())<2,label+" 场上锚点跟随当前卡牌投影")
  expect(bubble.mouse_filter==Control.MOUSE_FILTER_IGNORE and bubble.text_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,label+" 气泡不会拦截卡牌操作")
  if who==0:
   await create_timer(0.4).timeout;view.emotes.refresh();await capture("leader-emotes-field-"+label)
  await move_leader(who,"hand")
  var layout=view.emotes.bubble_layout(who,bubble.size)
  expect(not view.emotes.bubble_target(who).has_area() and layout.fallback,label+" 自机离开自机区和战场后使用边缘气泡")
  expect(layout.position.y+bubble.size.y<=view.HAND.position.y+1 if who==view.local_seat else layout.position.y<view.STAGE.get_center().y,label+" 离场时我方气泡位于手牌上方、敌方气泡位于顶部")
 emit_bubble(0);emit_bubble(1);await frames()
 if app.is_android:
  for shortcut in view.android_zone_shortcuts.buttons.values():
   if shortcut.visible:
    expect(view.emotes.bubbles.values().all(func(bubble):return not bubble.get_global_rect().intersects(shortcut.get_global_rect())),label+" 显示中的区域快捷图标不会覆盖气泡文字")
 await capture("leader-emotes-bubbles-"+label)
 view.local_seat=1;view.table.local_seat=1;view.emotes.reset();e.leader_emote_profiles[1].enabled=true
 emit_bubble(0);emit_bubble(1);await frames();view.emotes.refresh()
 expect(view.emotes.bubbles.has(1) and view.emotes.bubbles[1].points_down and view.emotes.bubbles.has(0) and not view.emotes.bubbles[0].points_down,label+" 座位一视角也按敌我关系决定尾巴方向")
 view.local_seat=0;view.table.local_seat=0
 Emotes.emit_event(e,0,"surprise");e.presentation_events.back().text="这是一段测试自机专属台词，确认长文字可以完整显示。".repeat(5)
 view.render();await frames()
 var long_bubble=view.emotes.bubbles.get(0)
 expect(long_bubble!=null and long_bubble.size.y>104,label+" 专属长台词会自动增加气泡高度")
 if long_bubble!=null:
  var text=long_bubble.text_label
  expect(text.text.length()==120 and text.size.y>=text.get_content_height()-2,label+" 最长台词限制为120字且文字不会被截断")
 for kind in ["greeting","praise","mistake","threat","surrender","surprise"]:
  var paired_line=Emotes.PROFILES["character-fdn-026"].lines[kind]
  Emotes.emit_event(e,0,kind);e.presentation_events.back().text=paired_line;e.presentation_events.back().leader_id="character-fdn-026"
  view.render();await frames()
  var text=view.emotes.bubbles[0].text_label
  expect(text.text==paired_line and text.get_line_count()>=(2 if kind!="surprise" else 1),label+" 觉恋台词完整分行显示 "+kind)
  expect(view.emotes.bubbles[0].distort_reply==(kind!="surprise"),label+" 仅觉恋双句启用恋恋的文字特效 "+kind)
  expect(view.emotes.bubbles[0].red_reply==(kind=="threat"),label+" 仅觉恋威胁的后半句显示红色 "+kind)
  expect(text.size.y>=text.get_content_height()-2,label+" 觉恋双句气泡容纳全部文字 "+kind)
  expect(app.ui_metrics.safe.grow(1).encloses(view.emotes.bubbles[0].get_global_rect()),label+" 觉恋双句气泡位于安全区域 "+kind)
  if kind=="greeting":await capture("leader-emotes-sisters-"+label)

func check_surrender(label: String):
 await prepare();emit_bubble(0);e.emote_ready_at[0]=Time.get_unix_time_from_system()+10
 e.surrender(0);view.render();await frames()
 expect(view.emotes.bubbles.has(0) and view.emotes.bubbles[0].text_label.text==e.leader_emote_profiles[0].lines.surrender,label+" 已开通我方投降即使在冷却中也出现配置的投降气泡")
 var serial=e.emote_serial;e.surrender(0);view.render()
 expect(e.emote_serial==serial,label+" 重复投降不会重发气泡")
 await prepare(false);e.surrender(0);view.render();await frames()
 expect(not view.emotes.bubbles.has(0),label+" 未开通我方投降不显示气泡")
 await prepare(false);e.surrender(1);view.render();await frames()
 expect(view.emotes.bubbles.has(1) and view.emotes.bubbles[1].text_label.text==Emotes.DEFAULT_LINES.surrender,label+" 未开通敌方投降仍然显示气泡")

func check_spectator(label: String):
 await prepare()
 var authority=e
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/spectator-"+label);session.set_process(false)
 session.read_only=true;session.connected=true;session.paused=false
 session.series.setup(1,true,"test");session.series.state.status="playing";session.series.state.game_id="emote-spectator"
 session.room=session.series.public_state(-1);session.local_game_id=session.room.game_id
 var remote=Remote.new();remote.session=session
 view.network_session=session;view.engine=remote;view.table.duel=remote
 for seat in [0,1]:
  session.seat=seat;remote.seat=seat;view.local_seat=seat;view.table.local_seat=seat;view.emotes.reset()
  for who in [0,1]:authority.leader_emote_profiles[who].enabled=true
  for kind in Emotes.KINDS+["surrender"]:
   # Surrender is public even when neither leader has purchased emotes.
   if kind=="surrender":
    for who in [0,1]:authority.leader_emote_profiles[who].enabled=false
   authority.presentation_events.clear()
   for who in [0,1]:Emotes.emit_event(authority,who,kind)
   var events=authority.presentation_events.duplicate(true)
   var projection=Observer.build(authority,events)
   remote.apply_snapshot(projection.duplicate(true));view.render();await frames()
   expect(view.spectator_view() and not view.emotes.button.visible and not view.emotes.available(),label+" 观战座位 "+str(seat)+" 隐藏表情发送入口 "+kind)
   for who in [0,1]:
    var bubble=view.emotes.bubbles.get(who)
    expect(bubble!=null and bubble.text_label.text==events[who].text,label+" 观战座位 "+str(seat)+" 显示玩家 "+str(who)+" 的表情 "+kind)
    if bubble==null:continue
    expect(bubble.points_down==(who==seat) and app.ui_metrics.safe.grow(1).encloses(bubble.get_global_rect()),label+" 观战双方气泡方向和位置正确 "+str(who)+" "+kind)
   var bubbles=view.emotes.bubbles.duplicate()
   remote.apply_snapshot(projection.duplicate(true));view.render();await frames()
   expect(view.emotes.bubbles==bubbles,label+" 重复观战快照不重建表情气泡 "+kind)
  view.emotes.open_wheel()
  expect(not is_instance_valid(view.emotes.wheel),label+" 第三方观战不能打开表情饼图")
  await capture("leader-emotes-spectator-"+label+"-"+str(seat))
 view.network_session=null;view.engine=authority;view.table.duel=authority;e=authority
 view.local_seat=0;view.table.local_seat=0;view.emotes.reset()
 session.leave(false);session.queue_free();await frames()

func check_surface(android: bool):
 app.is_android=android;app.layout_dpi_override=240 if android else 0
 root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
 await frames();app.refresh_responsive_layout();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine;view.replay_recording.finished=true
 if DisplayServer.get_name()!="headless":root.grab_focus();await frames()
 var label="android" if android else "desktop"
 expect(e.leader_emote_profiles.all(func(profile):return not profile.enabled),label+" 新对局未装备商品时不会自动开通配置中的表情")
 await check_input_and_gates(label);await check_bubble_positions(label);await check_surrender(label);await check_spectator(label)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture+"/tutorials"))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await frames();app.load_legacy_test_decks()
 # Randomly choose one existing fixture leader, reproducible across platforms.
 var random=RandomNumberGenerator.new();random.seed=7406
 if random.randi_range(0,1)==1:
  var previous=app.player_choice;app.player_choice=app.ai_choice;app.ai_choice=previous
 print("EMOTE UI FIXTURE LEADER: ",app.decks[app.player_choice].leader)
 await check_surface(false);await check_surface(true)
 print("LEADER_EMOTES_UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
