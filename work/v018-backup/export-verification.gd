extends Node
const Store=preload("res://scripts/deck_store.gd")
var failures=[]
var checks=0
func check(ok: bool,text: String):
 checks+=1
 if not ok: failures.append(text);push_error(text)
func _ready():call_deferred("run")
func run():
 check(not OS.has_feature("editor"),"must run with exported release template")
 check(Store.CARDS.size()==486,"all registered definitions load")
 for id in Store.CARDS:
  var art=load(Store.CARDS[id].image) as Texture2D
  check(art!=null and art.get_width()>0 and art.get_height()>0,"texture: "+id)
 check(Store.active_save_path()=="user://decks.json","release uses writable user saves")
 check(not ResourceLoader.exists("res://tests/test_decks.gd"),"test scripts excluded")
 check(not ResourceLoader.exists("res://work/v0152/card-back-and-hand.png"),"work screenshots excluded")
 check(not FileAccess.file_exists("res://saves/decks.json"),"developer saves not loaded directly")
 var bundled=Store.load_decks(Store.BUNDLED_DECKS_PATH)
 check(not bundled.has("error") and bundled.decks.size()==4,"four current saved decks bundled")
 var loaded=Store.load_decks()
 check(not loaded.has("error"),"release player save readable")
 var mode=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "first"
 if mode=="first":
  check(loaded.decks==bundled.decks,"first launch seeds exact bundled decks")
  check(FileAccess.file_exists(Store.USER_SAVE_PATH),"first launch creates writable save")
  var edited=loaded.decks.duplicate(true);edited[0].name="发行保存测试"
  check(Store.persist(edited).is_empty(),"release saves edits")
 elif mode=="restart":
  check(loaded.decks[0].name=="发行保存测试","restart preserves player edits")
  check(Store.persist([]).is_empty(),"release saves deletion of all decks")
 elif mode=="empty":
  check(loaded.decks.is_empty(),"empty save is not reseeded")
  check(Store.persist(bundled.decks).is_empty(),"restore verification profile")
 var app=load("res://main.tscn").instantiate();get_tree().root.add_child.call_deferred(app);await get_tree().process_frame
 check(app.load_error.is_empty(),"main menu opens without missing-resource alert")
 check(app.settings_path=="user://settings.json","release settings path")
 check(app.texture("back")!=null,"card back loads")
 check(load(app.battlefield_background)!=null,"playmat loads")
 var settings_file=FileAccess.open(app.settings_path,FileAccess.WRITE)
 check(settings_file!=null,"settings are writable")
 if settings_file:settings_file.store_string('{"fullscreen":false}');settings_file.close()
 app.load_test_decks();check(app.decks.size()>=2,"precon templates are included")
 app.begin_battle(true);await get_tree().process_frame
 check(is_instance_valid(app.duel_view) and not app.duel_view.engine.cards.is_empty(),"release battlefield starts")
 if DisplayServer.get_name()!="headless":
  await get_tree().create_timer(1).timeout
  await RenderingServer.frame_post_draw
  get_tree().root.get_texture().get_image().save_png(OS.get_environment("MULTICOLOUR_EXPORT_SCREENSHOT"))
 print("EXPORT_CHECK: ",mode,"; ",checks," checks; ",failures.size()," failures")
 get_tree().quit(0 if failures.is_empty() else 1)
