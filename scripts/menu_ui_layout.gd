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
 var middle=HBoxContainer.new();root.add_child(middle);expand(middle,true)
 for i in range(2):
  var surface=panel(middle);expand(surface,true)
  var body=column(surface)
  text(body,"你的卡组" if i==0 else "人机的卡组",metrics.title)
  var pick=action(body,app.deck_choice_caption(app.player_choice if i==0 else app.ai_choice),func():app.open_match_deck_picker(i))
  pick.name="PlayerDeckSelect" if i==0 else "AIDeckSelect"
  pick.custom_minimum_size.x=0;expand(pick)
  if not app.decks.is_empty():
   var chosen=app.decks[app.player_choice if i==0 else app.ai_choice]
   var art=TextureRect.new();art.texture=app.texture(chosen.leader);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   body.add_child(art);expand(art,true)
   text(body,"主卡组 %d   ·   副卡组 %d" % [chosen.main.size(),chosen.side.size()])
 if not app.is_android:
  var options=HBoxContainer.new();root.add_child(options)
  check(options,"测试模式（手动控制双方）",app.debug_mode,func(value):app.debug_mode=value;app.setup())
  var free=check(options,"无需付费",app.debug_free_payment,func(value):app.debug_free_payment=value);free.disabled=not app.debug_mode
  if app.LocalExperiment.available():
   var experiment=check(root,"使用试验 AI（仅本机测试端）",app.experimental_ai and not app.debug_mode,func(value):app.experimental_ai=value;app.setup())
   experiment.name="ExperimentalAI";experiment.disabled=app.debug_mode
   var model=action(root,"选择模型…",app.choose_experiment_model);model.disabled=app.debug_mode or not app.experimental_ai
 var actions=HBoxContainer.new();root.add_child(actions)
 expand(action(actions,"开始对战",app.start_match,true))
 action(actions,"编辑牌组",app.editor)
 if not app.is_android and FileAccess.file_exists("res://data/test_precons.json"):action(actions,"载入测试卡组",app.load_test_decks)

func check(parent: Node,caption: String,checked: bool,callback: Callable) -> CheckButton:
 var result=CheckButton.new();result.text=caption;parent.add_child(result);metrics.button(result)
 result.button_pressed=checked;result.toggled.connect(callback)
 return result

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

func build_settings(host):
 var root=page(host,"设置")
 var scroll=ScrollContainer.new();root.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=column(scroll)
 room_join_volume_control(body)
 if not app.is_android:
  check(body,"全屏显示",app.fullscreen,func(value):
   app.fullscreen=value
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
   app.save_settings())
 check(body,"游戏内卡牌使用 2D 上方俯视",app.top_down_view,app.set_top_down_view)
 check(body,"显示左侧卡牌效果说明栏",app.show_card_inspection,app.set_show_card_inspection)
 check(body,"延迟回合结束（长按 1 秒）",app.delay_turn_end,app.set_delay_turn_end).name="DelayTurnEnd"
 if app.is_android:
  check(body,"自动跳转视角",app.auto_camera_focus,app.set_auto_camera_focus).name="AutoCameraFocus"
  check(body,"允许手动拖动和缩放视角",app.android_manual_camera,app.set_android_manual_camera).name="AndroidManualCamera"
  check(body,"显示墓地与除外区悬浮按钮",app.android_zone_shortcuts,app.set_android_zone_shortcuts).name="AndroidZoneShortcutsSetting"
 if not app.is_android:check(body,"测试模式：允许拖动卡牌放入战场",app.debug_drag_to_field,app.set_debug_drag_to_field)
 if app.is_test_build and not app.is_android:check(body,"回放训练模式：标注关键步骤与推荐招法",app.replay_training_mode,app.set_replay_training_mode)
 text(body,"当前版本："+app.patch_manager().active_version)
 action(body,"加载 PCK 补丁…",app.choose_pck_patch)
 action(body,"关于",app.about)

func build_about(host):
 var root=page(host,"关于",host.settings)
 var scroll=ScrollContainer.new();root.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=column(scroll)
 text(body,"multicolor:arena  "+str(ProjectSettings.get_setting("application/config/version")),metrics.title).add_theme_color_override("font_color",app.GOLD)
 var description=text(body,"本作品基于开源游戏引擎godot和东方project的二次创作“极彩multicolor”，由chatgpt辅助代码所制成。所有卡图等知识产权均归属于社团“The 495th Complex”")
 description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
