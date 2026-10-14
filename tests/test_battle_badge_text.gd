extends "res://tests/support/ui_base.gd"

var ordinary_unit={}
var large_unit={}
var desktop_font: Font

func frames(count: int=3):
 for index in range(count):await process_frame

func text_fits(label: Label,prefix: String):
 var font=label.get_theme_font("font")
 var font_size=label.get_theme_font_size("font_size")
 var natural=font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
 expect(natural.x<=label.size.x+0.1,prefix+" renders the complete text width: "+label.text.replace("\n"," / "))
 expect(natural.y<=label.size.y+0.1,prefix+" contains the full font line height")

func verify_stats(unit: Dictionary,expected: Array,prefix: String):
 var parts=view.card_badges["card_"+str(unit.uid)]
 var labels=[parts.values.power,parts.stat_separators[0],parts.values.health,parts.stat_separators[1],parts.values.spirit]
 expect([labels[0].text,labels[2].text,labels[4].text]==expected,prefix+" preserves all three attribute values")
 for index in range(labels.size()):
  var label=labels[index]
  text_fits(label,prefix+" attribute "+str(index))
  expect(Rect2(Vector2.ZERO,parts.stats.size).grow(0.1).encloses(label.get_rect()),prefix+" attribute text stays inside its capsule")
  for earlier in range(index):expect(not label.get_rect().intersects(labels[earlier].get_rect()),prefix+" attribute columns and separators do not overlap")
 if parts.has("counters"):
  text_fits(parts.counters,prefix+" multiline counters")
  expect(not parts.counters.get_rect().intersects(parts.stats.get_rect()),prefix+" counters leave the attribute capsule clear")
 if parts.has("courage"):
  text_fits(parts.courage,prefix+" courage")
  if parts.has("counters"):
   expect(not parts.courage.get_rect().intersects(parts.counters.get_rect()),prefix+" courage and multiline counters do not overlap")
   expect(not "勇气" in parts.counters.text,prefix+" courage is not repeated inside the counter caption")

func fill_fixture():
 clean()
 ordinary_unit=put("53","field")
 ordinary_unit.display_stats={"power":1,"health":2,"spirit":1}
 large_unit=put("54","field")
 large_unit.display_stats={"power":-12,"health":100,"spirit":12}
 large_unit.courage=123;large_unit.plus_counters=12;large_unit.minus_counters=3
 large_unit.poverty=123;large_unit.wards=[{"amount":1,"turn":-1},{"amount":3,"turn":-1},{"amount":1,"turn":-1}]
 e.players[0].leader.timer=123
 for who in [0,1]:
  for definition in [["deck",46],["grave",99],["exile",100]]:
   for index in range(definition[1]):put("164",definition[0],who)
 for index in range(100):put("token-fdf-129","field",1)

func verify_board(prefix: String):
 verify_stats(ordinary_unit,["1","2","1"],prefix+" ordinary")
 verify_stats(large_unit,["-12","100","12"],prefix+" large")
 var large_parts=view.card_badges["card_"+str(large_unit.uid)]
 expect(large_parts.courage.text=="◆ 123" and large_parts.counters.text.count("\n")>=3,prefix+" displays a three-digit courage value and multiple counter lines")
 var leader=view.card_badges["card_"+str(e.players[0].leader.uid)]
 expect(leader.sick.text=="计时 123",prefix+" preserves three-digit leader timer")
 text_fits(leader.sick,prefix+" timer")
 for seat_prefix in ["p","a"]:
  for definition in [["deck","牌库 46"],["grave","墓地 99"],["exile","除外 100"]]:
   var label=view.card_badges[seat_prefix+definition[0]].count_label
   expect(label.text==definition[1],prefix+" retains the entire "+seat_prefix+definition[0]+" label")
   text_fits(label,prefix+" "+seat_prefix+definition[0])
 var token_displays=view.table.descriptors.values().filter(func(descriptor):return descriptor.card_id=="token-fdf-129")
 expect(token_displays.size()==1 and token_displays[0].members.size()==100,prefix+" merges one hundred tokens without changing the game count")
 if not token_displays.is_empty():
  var token=view.card_badges[token_displays[0].key].token_count
  expect(token.text=="×100",prefix+" shows the full token quantity")
  text_fits(token,prefix+" token quantity")
 var copy=view.board_badge_label("12/100",16 if view.is_android else 14,app.GOLD,view.effects)
 text_fits(copy,prefix+" copy index")
 copy.queue_free()
 var capacity=view.field_capacity_badge.get_node("FieldCapacityValue") as Label
 text_fits(capacity,prefix+" battlefield capacity")
 expect(view.field_capacity_badge.get_global_rect().grow(0.1).encloses(capacity.get_global_rect()),prefix+" capacity text stays inside its panel")

func verify_life_delta(delta: int,prefix: String):
 view.life_last[0]=200
 e.players[0].life=200+delta
 view.render_life(0,view.responsive.own_life)
 var label=view.life_flashes[0] as Label
 expect(label.text==("+" if delta>0 else "")+str(delta),prefix+" preserves the signed life change")
 text_fits(label,prefix+" life change")

func screenshot(name: String):
 if DisplayServer.get_name()=="headless" or "--screenshots" not in OS.get_cmdline_user_args():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/battle-number-"+name+".png")

func run():
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/battle-badge-text/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 app.settings_path="res://work/battle-badge-text/settings.json"
 app.account_session_path="res://work/battle-badge-text/account.json"
 root.add_child(app);await frames();desktop_font=app.theme.default_font;app.load_legacy_test_decks()
 for fixture in [[false,Vector2i(1600,900),160],[false,Vector2i(1280,720),240],[false,Vector2i(2340,1080),420],[true,Vector2i(1280,720),160],[true,Vector2i(1280,720),240],[true,Vector2i(2340,1080),420]]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=fixture[1];root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if fixture[0] else Window.CONTENT_SCALE_ASPECT_KEEP
  app.is_android=fixture[0];app.layout_dpi_override=fixture[2]
  app.layout_safe_override=Rect2(20,0,fixture[1].x-40,fixture[1].y-12) if fixture[0] else Rect2()
  app.theme.default_font=preload("res://assets/fonts/NotoSansSC-Regular.tres") if fixture[0] else desktop_font
  app.refresh_ui_metrics();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;fill_fixture();await frames()
  for top_down in [false,true]:
   view.table.set_top_down_view(top_down);view.render();await settle();await frames()
   var prefix=("android-" if fixture[0] else "desktop-")+str(fixture[2])+("-2d" if top_down else "-3d")
   verify_board(prefix)
   for delta in [-123,123,-12345,12345]:verify_life_delta(delta,prefix+" change "+str(delta))
   await screenshot(prefix)
 print("BATTLE BADGE TEXT: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(0 if failures.is_empty() else 1)
