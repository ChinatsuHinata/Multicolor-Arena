extends "res://scripts/deck_editor_layout.gd"
## The same container toolkit is used by setup/settings and the editor.
func page(host,title: String) -> VBoxContainer:
 app=host;metrics=app.ui_metrics
 var root=column(app.screen);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var header=HBoxContainer.new();root.add_child(header)
 var heading=text(header,title,metrics.title);expand(heading);heading.add_theme_color_override("font_color",app.GOLD)
 action(header,"返回",app.menu)
 return root

func build_setup(host):
 var root=page(host,"人机对战")
 var middle=HBoxContainer.new();root.add_child(middle);expand(middle,true)
 for i in range(2):
  var surface=panel(middle);expand(surface,true)
  var body=column(surface)
  text(body,"你的卡组" if i==0 else "人机的卡组",metrics.title)
  var pick=OptionButton.new();body.add_child(pick);metrics.button(pick);pick.fit_to_longest_item=false
  app.enable_android_popup_swipe(pick.get_popup())
  if app.decks.is_empty():pick.add_item("未选择")
  else:
   for deck in app.decks:pick.add_item(deck.name)
   pick.select(app.player_choice if i==0 else app.ai_choice)
  pick.item_selected.connect(func(index):
   if i==0:app.player_choice=index
   else:app.ai_choice=index
   app.setup())
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

func build_settings(host):
 var root=page(host,"设置")
 var scroll=ScrollContainer.new();root.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=column(scroll)
 if not app.is_android:
  check(body,"全屏显示",app.fullscreen,func(value):
   app.fullscreen=value
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
   app.save_settings())
 check(body,"游戏内卡牌使用 2D 上方俯视",app.top_down_view,app.set_top_down_view)
 check(body,"显示左侧卡牌效果说明栏",app.show_card_inspection,app.set_show_card_inspection)
 if not app.is_android:check(body,"测试模式：允许拖动卡牌放入战场",app.debug_drag_to_field,app.set_debug_drag_to_field)
 if app.is_test_build and not app.is_android:check(body,"回放训练模式：标注关键步骤与推荐招法",app.replay_training_mode,app.set_replay_training_mode)
