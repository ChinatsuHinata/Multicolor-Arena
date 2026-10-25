extends "res://scripts/deck_editor_layout.gd"
## The same container toolkit is used by setup/settings and the editor.
func page(host,title: String,back: Callable=Callable()) -> VBoxContainer:
 app=host;metrics=app.ui_metrics
 var root=column(app.screen);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var header=HBoxContainer.new();root.add_child(header)
 var heading=text(header,title,metrics.title);expand(heading);heading.add_theme_color_override("font_color",app.GOLD)
 action(header,"返回",back if back.is_valid() else app.menu)
 return root

func build_setup(host):
 var root=page(host,"人机对战")
 app.battle_mode_selector(root)
 if app.entertainment_battle():text(root,"人机全程让过，不出牌、不攻击、不发动能力。")
 var middle=HBoxContainer.new();root.add_child(middle);expand(middle,true)
 for i in range(2):
  var surface=panel(middle);expand(surface,true)
  var body=column(surface)
  text(body,"你的卡组" if i==0 else "人机的卡组",metrics.title)
  var pick=action(body,app.setup_deck_caption(i),func():app.open_match_deck_picker(i))
  pick.disabled=app.entertainment_battle() or i==1 and app.remilia_challenge()
  pick.name="PlayerDeckSelect" if i==0 else "AIDeckSelect"
  pick.custom_minimum_size.x=0;expand(pick)
  var chosen=app.match_setup_deck(i)
  if not chosen.is_empty():
   var art=TextureRect.new();art.texture=app.deck_cover_texture(chosen);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   body.add_child(art);expand(art,true)
   text(body,"拜访 ×15 · 探索 ×15\n旅行包 ×8 · 活动 ×12" if app.entertainment_battle() else "主卡组 %d   ·   副卡组 %d" % [chosen.main.size(),chosen.side.size()])
 if not app.is_android:
  var options=HBoxContainer.new();root.add_child(options)
  check(options,"测试模式（手动控制双方）",app.debug_mode,func(value):app.debug_mode=value;app.setup())
  var free=check(options,"无需付费",app.debug_free_payment,func(value):app.debug_free_payment=value);free.disabled=not app.debug_mode
  if app.LocalExperiment.available():
   var experiment=check(root,"使用试验 AI（仅本机测试端）",app.experimental_ai and not app.debug_mode and not app.entertainment_battle(),func(value):app.experimental_ai=value;app.setup())
   experiment.name="ExperimentalAI";experiment.disabled=app.debug_mode or app.entertainment_battle()
   var model=action(root,"选择模型…",app.choose_experiment_model);model.disabled=app.debug_mode or app.entertainment_battle() or not app.experimental_ai
 var actions=HBoxContainer.new();root.add_child(actions)
 expand(action(actions,"开始对战",app.start_match,true))
 action(actions,"编辑牌组",app.editor)
 if not app.is_android and FileAccess.file_exists("res://data/test_precons.json"):action(actions,"载入测试卡组",app.load_test_decks)

func check(parent: Node,caption: String,checked: bool,callback: Callable) -> CheckButton:
 var result=CheckButton.new();result.text=caption;parent.add_child(result);metrics.button(result)
 result.button_pressed=checked;result.toggled.connect(callback)
 return result

func frame_rate_limit_control(parent: Node) -> HBoxContainer:
 var row=HBoxContainer.new();row.name="FrameRateLimitControl";parent.add_child(row)
 row.add_theme_constant_override("separation",metrics.gap)
 expand(text(row,"帧率上限"))
 var presets=["60","120","custom"]
 var preset=OptionButton.new();preset.name="FrameRatePreset";row.add_child(preset)
 for caption in ["60 FPS","120 FPS","自定义"]:preset.add_item(caption)
 preset.select(presets.find(app.frame_rate_preset));metrics.button(preset)
 var limit=LineEdit.new();limit.name="FrameRateLimit";row.add_child(limit)
 limit.text=str(app.frame_rate_limit);limit.editable=app.frame_rate_preset=="custom"
 limit.alignment=HORIZONTAL_ALIGNMENT_RIGHT;limit.max_length=4
 limit.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
 limit.custom_minimum_size=Vector2(metrics.body*4,metrics.hit)
 limit.tooltip_text="选择自定义后输入 0–1000 的整数，按回车或移开焦点即可生效并保存。0 为不限帧；实际帧率受设备性能和垂直同步影响。"
 text(row,"FPS")
 var host=app
 var commit=func():
  if not limit.editable or host.frame_rate_preset!="custom":return
  var value=limit.text.strip_edges()
  if value.is_valid_int():host.set_frame_rate_limit(value.to_float())
  limit.text=str(host.frame_rate_limit)
 limit.text_submitted.connect(func(_value):commit.call())
 limit.focus_exited.connect(commit)
 preset.item_selected.connect(func(index):
  host.set_frame_rate_preset(presets[index])
  limit.editable=host.frame_rate_preset=="custom";limit.text=str(host.frame_rate_limit)
  if limit.editable:limit.grab_focus();limit.select_all())
 return row

func room_join_volume_control(parent: Node) -> HBoxContainer:
 var row=HBoxContainer.new();row.name="RoomJoinVolumeControl";parent.add_child(row)
 row.add_theme_constant_override("separation",metrics.gap)
 text(row,"房间加入提醒音量")
 var slider=HSlider.new();slider.name="RoomJoinVolume";row.add_child(slider);expand(slider)
 slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=roundf(app.room_join_volume*100.0)
 slider.custom_minimum_size=Vector2(metrics.hit*3,metrics.hit)
 slider.tooltip_text="玩家或观众加入时提醒房主；0% 为静音。"
 var value_label=text(row,"%d%%" % slider.value);value_label.name="RoomJoinVolumeValue"
 value_label.custom_minimum_size.x=metrics.body*3.0;value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var host=app
 slider.value_changed.connect(func(value):
  value_label.text="%d%%" % value
  host.set_room_join_volume(value/100.0))
 action(row,"试听",host.preview_room_join_sound).name="PreviewRoomJoinSound"
 return row

func card_preview_duration_control(parent: Node) -> HBoxContainer:
 var row=HBoxContainer.new();row.name="AndroidCardPreviewDurationControl";parent.add_child(row)
 row.add_theme_constant_override("separation",metrics.gap)
 text(row,"长按预览判定")
 var slider=HSlider.new();slider.name="AndroidCardPreviewDuration";row.add_child(slider);expand(slider)
 var setting=app.CardPreviewHold
 slider.min_value=setting.MIN_SECONDS;slider.max_value=setting.MAX_SECONDS;slider.step=setting.STEP_SECONDS
 slider.value=app.android_card_preview_seconds
 slider.custom_minimum_size=Vector2(metrics.hit*3,metrics.hit)
 slider.tooltip_text="拖动调整长按卡牌打开详情的时间。"
 var value_label=text(row,"%.2f 秒" % slider.value);value_label.name="AndroidCardPreviewDurationValue"
 value_label.custom_minimum_size.x=metrics.body*5.0;value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var host=app
 slider.value_changed.connect(func(value):
  host.set_android_card_preview_seconds(value)
  value_label.text="%.2f 秒" % host.android_card_preview_seconds)
 return row

func build_settings(host):
 var root=page(host,"设置")
 var scroll=ScrollContainer.new();root.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=column(scroll)
 var frame_rate=frame_rate_limit_control(body)
 room_join_volume_control(body)
 if app.is_android:
  var preview_duration=card_preview_duration_control(body)
  if frame_rate.get_combined_minimum_size().x+preview_duration.get_combined_minimum_size().x+metrics.gap<=app.screen.size.x:
   var timing=HBoxContainer.new();timing.name="SettingsTimingControls";body.add_child(timing);body.move_child(timing,0)
   frame_rate.reparent(timing);preview_duration.reparent(timing)
   expand(frame_rate);expand(preview_duration)
 if not app.is_android:
  check(body,"全屏显示",app.fullscreen,func(value):
   app.fullscreen=value
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
   app.save_settings())
 var switches: Node=body
 if app.is_android:
  var grid=GridContainer.new();grid.name="AndroidSettingsSwitches";grid.columns=2 if app.screen.size.x>=metrics.hit*13 else 1
  body.add_child(grid);switches=grid
 var toggles=[]
 toggles.append(check(switches,"游戏内卡牌使用 2D 上方俯视",app.top_down_view,app.set_top_down_view))
 toggles.append(check(switches,"显示左侧卡牌效果说明栏",app.show_card_inspection,app.set_show_card_inspection))
 var delay=check(switches,"延迟回合结束（长按 1 秒）",app.delay_turn_end,app.set_delay_turn_end);delay.name="DelayTurnEnd";toggles.append(delay)
 if app.is_android:
  var auto_focus=check(switches,"自动跳转视角",app.auto_camera_focus,app.set_auto_camera_focus);auto_focus.name="AutoCameraFocus";toggles.append(auto_focus)
  var manual=check(switches,"允许手动拖动和缩放视角",app.android_manual_camera,app.set_android_manual_camera);manual.name="AndroidManualCamera";toggles.append(manual)
  var shortcuts=check(switches,"显示墓地与除外区悬浮按钮",app.android_zone_shortcuts,app.set_android_zone_shortcuts);shortcuts.name="AndroidZoneShortcutsSetting";toggles.append(shortcuts)
  var sakura=check(switches,"新版界面（樱花神社）",app.sakura_ui,app.set_sakura_ui);sakura.name="SakuraUI";toggles.append(sakura)
  for toggle in toggles:
   toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   toggle.custom_minimum_size.y=maxf(56.0,metrics.hit*0.76)
 if not app.is_android:check(body,"测试模式：允许拖动卡牌放入战场",app.debug_drag_to_field,app.set_debug_drag_to_field)
 if app.is_test_build and not app.is_android:check(body,"回放训练模式：标注关键步骤与推荐招法",app.replay_training_mode,app.set_replay_training_mode)
 var footer: Node=body
 if app.is_android:
  var row=HBoxContainer.new();row.name="AndroidSettingsFooter";body.add_child(row);footer=row
 var version=text(footer,"当前版本："+app.patch_manager().active_version)
 if app.is_android:expand(version)
 action(footer,"模组",app.mod_settings).name="ModSettings"
 action(footer,"关于",app.about)

func build_about(host):
 var root=page(host,"关于",host.settings)
 var scroll=ScrollContainer.new();root.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=column(scroll)
 text(body,"极彩：对决  "+str(ProjectSettings.get_setting("application/config/version")),metrics.title).add_theme_color_override("font_color",app.GOLD)
 var description=text(body,"本作品基于开源游戏引擎godot和东方project的二次创作“极彩multicolor”，由chatgpt辅助代码所制成。所有卡图等知识产权均归属于社团“The 495th Complex”")
 description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
