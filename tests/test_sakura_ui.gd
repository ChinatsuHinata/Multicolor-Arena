extends "res://tests/support/ui_base.gd"
const Palette=preload("res://scripts/ui_palette.gd")
var settings_fixture=""

func frames(count: int=6):
 for i in range(count):await process_frame

func saved_flag():
 var data=JSON.parse_string(FileAccess.get_file_as_string(settings_fixture))
 return data.get("sakura_ui",null) if data is Dictionary else null

func style_toggle() -> CheckButton:
 return app.screen.find_child("SakuraUI",true,false) as CheckButton

func run():
 var folder="res://work/sakura-ui/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 Store.Paths.root_override=ProjectSettings.globalize_path(folder)
 settings_fixture=folder.path_join("settings.json")
 app=load("res://main.tscn").instantiate();app.settings_path=settings_fixture
 root.add_child(app);await frames()

 expect(Palette.enabled and is_instance_valid(app.sakura_backdrop) and app.sakura_backdrop.visible,"PC starts with the sakura UI and its backdrop")
 expect(app.GOLD==Palette.SAKURA and app.style(Color("#192a38")).bg_color==Color("#43293a"),"classic colors are mapped to the sakura palette")
 expect(app.screen.find_child("MenuTitle",true,false)!=null,"desktop menu shows the sakura title")
 var battle_entry=find_button(app.screen,"人机对战")
 expect(battle_entry!=null and battle_entry.get_theme_stylebox("normal").border_width_top==4,"the main-menu AI battle entry uses the ordinary shrine button style")
 var plain_entry=find_button(app.screen,"设置")
 expect(plain_entry!=null and plain_entry.get_theme_stylebox("normal").border_width_top==4 and plain_entry.get_theme_stylebox("disabled")!=null,"plain buttons use the lacquer style with a vermilion beam")
 await capture("sakura-menu")

 app.settings();await frames()
 var toggle=style_toggle()
 expect(toggle!=null and toggle.button_pressed,"settings show the new UI switch turned on")
 if toggle!=null:await click(toggle.get_global_rect().get_center());await frames()
 expect(not Palette.enabled and not is_instance_valid(app.sakura_backdrop),"switching off restores the classic UI")
 expect(app.GOLD==Color("#e8c77e") and app.style(Color("#192a38")).bg_color==Color("#192a38"),"classic colors are no longer mapped")
 expect(saved_flag()==false,"the classic choice is saved")
 toggle=style_toggle()
 expect(toggle!=null and not toggle.button_pressed,"settings page is rebuilt with the switch off")
 await capture("classic-settings")
 app.menu();await frames()
 expect(app.screen.find_child("MenuTitle",true,false)==null,"classic menu has no sakura title")
 var classic_entry=find_button(app.screen,"设置")
 expect(classic_entry!=null and classic_entry.get_theme_stylebox("normal").bg_color==Color("#192a38") and classic_entry.get_theme_stylebox("normal").border_width_top==1,"classic buttons keep the original style")

 app.sakura_ui=true;app.apply_ui_style();app.save_settings()
 expect(Palette.enabled and is_instance_valid(app.sakura_backdrop) and saved_flag()==true,"switching back restores the sakura UI")
 Palette.configure(true)
 expect(Palette.enabled,"the sakura palette is available on desktop and Android")

 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;clean()
 e.debug_enabled=true;e.debug_free_payment=true
 put("character-fdf-ex02","field")
 expect(not app.sakura_backdrop.visible,"battle hides the menu backdrop")
 var world=view.table.find_children("*","WorldEnvironment",false,false)
 expect(not world.is_empty() and world[0].environment.background_color==Palette.FIELD_SKY,"battlefield uses the lighter dusk sky")
 var mat=view.table.board.material_override if view.table.board.material_override!=null else view.table.board.get_surface_override_material(0)
 if mat is ShaderMaterial:expect(mat.get_shader_parameter("lift")==Palette.MAT_LIFT,"the playmat is lifted out of black")
 for count in range(3):
  var spell=put("spell-fdf-014","hand");e.priority=0
  if count==0:
   var error=e.commit_cast(0,spell.uid,{"none":true},[])
   expect(error.is_empty(),"spell enters the stack %s" % error)
  elif not e.stack.is_empty():
   # Same-speed copies; only the layout of several entries matters here.
   var copy=e.stack[0].duplicate(true);copy.id=900+count;copy.card=spell.duplicate(true)
   e.players[0].hand.erase(spell);e.stack.append(copy)
 e.presentation_events.clear();view.reveal_player.reset()
 view.render();await frames()
 var stack=view.stack_panel
 var ids=e.unresolved_stack_entries().map(func(entry):return entry.id)
 ids.reverse()
 expect(stack.tiles.size()==3 and stack.backing!=null,"stack panel has a backing and three entries")
 if stack.tiles.size()==3:
  expect(not stack.tiles[ids[0]].compact and stack.tiles[ids[0]].tile.size.x>=stack.LEAD_SIZE.x-1,"the next entry keeps a readable card face")
  expect(stack.tiles[ids[1]].compact and stack.tiles[ids[2]].compact,"later entries use compact rows")
  var scroll_rect=stack.scroll.get_global_rect()
  var visible=ids.filter(func(id):return scroll_rect.encloses(stack.tiles[id].tile.get_global_rect()))
  expect(visible.size()>=2,"compact rows show more than one entry without scrolling")
  var thumb=stack.card_rect(stack.tiles[ids[1]].tile.get_meta("uid"))
  expect(thumb.size.x<=stack.THUMB_SIZE.x+1,"cards leave compact rows from their thumbnail")
  expect(stack.arrival_rect().size==stack.LEAD_SIZE,"new cards fly to the lead slot")
 await capture("sakura-stack")
 app.duel_view=null;view=null;e=null
 app.is_android=true;app.layout_dpi_override=240
 root.size=Vector2i(1280,720)
 app.settings();await frames()
 toggle=style_toggle()
 expect(toggle!=null and toggle.button_pressed and Palette.enabled,"Android settings expose the enabled sakura theme")
 expect(app.ui_metrics.touch and app.GOLD==Palette.SAKURA,"Android keeps responsive touch metrics with sakura colors")
 await capture("sakura-android-settings")
 if toggle!=null:await click(toggle.get_global_rect().get_center());await frames()
 expect(not Palette.enabled and saved_flag()==false and app.page=="settings" and app.screen.find_child("AndroidSettingsSwitches",true,false)!=null,"Android can save the classic theme and rebuild responsive settings")
 toggle=style_toggle()
 if toggle!=null:await click(toggle.get_global_rect().get_center());await frames()
 expect(Palette.enabled and saved_flag()==true and app.GOLD==Palette.SAKURA,"Android can restore and save the sakura theme")
 app.menu();await frames();await capture("sakura-android-menu")
 for mobile in [false,true]:
  app.is_android=mobile
  for sakura in [false,true]:
   app.sakura_ui=sakura;app.apply_ui_style()
   for mode in ["standard","exploration","exploration_random"]:
    app.battle_mode=mode;app.menu();await frames()
    var ai_button=find_button(app.screen,"人机对战")
    var settings_button=find_button(app.screen,"设置")
    var ai_style=ai_button.get_theme_stylebox("normal") as StyleBoxFlat
    var plain_style=settings_button.get_theme_stylebox("normal") as StyleBoxFlat
    expect(ai_style.bg_color==plain_style.bg_color and ai_style.border_color==plain_style.border_color and ai_button.get_theme_color("font_color")==settings_button.get_theme_color("font_color"),"AI battle has no accent on %s with sakura=%s in %s" % ["Android" if mobile else "desktop",str(sakura),mode])
 print("SAKURA UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
