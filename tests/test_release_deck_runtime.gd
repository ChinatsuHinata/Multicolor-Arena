extends Node
## Loaded by tools/check-release-runtime.ps1 inside the actual release template.
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
var root: Window

func quit(code: int):get_tree().quit(code)

func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func _ready():
 root=get_tree().root
 call_deferred("run")

func run():
 var test_root=""
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--test-root="):test_root=argument.trim_prefix("--test-root=")
 if OS.has_feature("editor") or not test_root.is_absolute_path():
  push_error("Use tools/check-release-runtime.ps1 with an exported game.")
  quit(1);return
 var bundle=JSON.parse_string(FileAccess.get_file_as_string(Store.BUNDLED_DECKS_PATH))
 var remilia=bundle.decks.filter(func(d):return d.id in bundle.upgrade_deck_ids)[0]

 Store.Paths.root_override=test_root.path_join("upgrade")
 Store.Paths.initialize()
 var marker=FileAccess.open(Store.folder().path_join(".initialized"),FileAccess.WRITE)
 marker.store_string("1");marker.close()
 var personal=bundle.decks[0].duplicate(true);personal.id="personal-runtime";personal.name="升级前的个人卡组"
 expect(Store.save_file(personal).is_empty(),"existing installation fixture saved")
 var personal_path=Store.file_paths[personal.id]
 var original=FileAccess.get_file_as_bytes(personal_path)
 var loaded=Store.load_decks()
 expect(not loaded.has("error") and loaded.decks.size()==2,"release startup delivers AI to initialized installation")
 expect(loaded.decks.any(func(d):return d==remilia),"delivered deck matches packed official AI")
 expect(FileAccess.get_file_as_bytes(personal_path)==original,"release upgrade preserves personal file")
 expect(Store.load_decks().decks.size()==2,"release restart does not duplicate delivery")
 Store.delete_file(remilia.id)
 expect(Store.load_decks().decks==[personal],"release restart respects deliberate AI deletion")

 Store.Paths.root_override=test_root.path_join("fresh")
 loaded=Store.load_decks()
 expect(not loaded.has("error") and loaded.decks.any(func(d):return d==remilia),"fresh release startup seeds AI")
 expect(loaded.decks.filter(func(d):return d.id==remilia.id).size()==1,"fresh installation has exactly one official AI")
 var app=load("res://main.tscn").instantiate()
 app.settings_path=test_root.path_join("settings.json")
 root.add_child(app);await get_tree().process_frame
 app.setup()
 var picks=[app.screen.find_child("PlayerDeckSelect",true,false),app.screen.find_child("AIDeckSelect",true,false)]
 expect(picks.all(func(pick):return pick is Button and not pick is OptionButton),"release human-versus-AI screen shows both deck selection buttons")
 var index=-1
 if picks[1]!=null:
  picks[1].pressed.emit();await get_tree().process_frame
  app.deck_picker_ui.search.text=remilia.name
  app.deck_picker_ui.search.text_changed.emit(remilia.name)
  var tile=app.deck_picker_ui.grid.get_children().filter(func(node):return node is Button and node.get_meta("deck_id","")==remilia.id)
  expect(tile.size()==1,"official Remilia AI is searchable in opponent gallery")
  if tile.size()==1:
   tile[0].pressed.emit()
   index=app.ai_choice
 if index>=0:
  expect(app.decks[app.ai_choice].id==remilia.id,"selecting opponent chooses delivered AI deck")
  app.begin_battle(true)
  var view=app.duel_view
  view.set_process(false)
  var engine=view.engine
  expect(not view.debug_mode and engine.ai_profiles[1]==engine.RemiliaAI.PROFILE,"normal release battle activates dedicated Remilia AI")
  engine.ai_step(1)
  expect(engine.players[1].mulligan_done,"Remilia AI acts in actual release battle")
  for who in [0,1]:
   if not engine.players[who].mulligan_done:engine.ai_step(who)
  for i in range(12):
   var who=engine.priority
   if not engine.pending.is_empty():who=int(engine.pending.get("owner",who))
   engine.ai_step(who)
  expect(engine.turn>0 and engine.history.size()>2,"packed game proceeds beyond opening choices")
 app.queue_free();await get_tree().process_frame
 for deck in Store.load_decks().decks:Store.delete_file(deck.id)
 expect(Store.load_decks().decks.is_empty(),"deleting fresh presets leaves library empty on restart")
 print("RELEASE_DECK_RUNTIME: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
