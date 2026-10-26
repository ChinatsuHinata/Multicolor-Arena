extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Export=preload("res://addons/share_export/deck_export.gd")
var checks=0
var failures=[]
var base=""

func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func write_json(path: String,value: Dictionary):
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var file=FileAccess.open(path,FileAccess.WRITE)
 check(file!=null,"Fixture can be written inside isolated workspace")
 if file==null:return
 file.store_string(JSON.stringify(value));file.close()

func use_root(name: String):
 Store.Paths.root_override=base.path_join(name)
 Store.file_paths.clear()
 check(DirAccess.make_dir_recursive_absolute(Store.Paths.root())==OK,"Isolated root created: "+name)

func _initialize():
 base=ProjectSettings.globalize_path("res://work/repository-bootstrap/"+str(Time.get_ticks_usec()))
 var presets=Store.load_decks(Store.PRESET_DECKS_PATH)
 check(not presets.has("error") and not presets.decks.is_empty(),"Public preset source is sufficient without player saves")
 if presets.has("error") or presets.decks.is_empty():quit(1);return
 var public_bytes=FileAccess.get_file_as_bytes(Store.PRESET_DECKS_PATH)
 var release=Export.release_decks()
 check(not release.has("error") and not release.decks.is_empty(),"Export loads public presets directly")
 use_root("fresh-clone")
 check(Store.initial_decks_path()==Store.PRESET_DECKS_PATH,"Fresh source checkout selects public presets")
 var loaded=Store.load_decks()
 check(not loaded.has("error"),"Fresh source checkout initializes successfully")
 check(loaded.decks.size()==presets.decks.size(),"Fresh checkout installs all official presets")
 for preset in presets.decks:
  check(loaded.decks.any(func(deck):return deck==Store.clean_deck(preset)),"Official preset installed intact: "+preset.name)
 check(FileAccess.file_exists(Store.folder().path_join(".initialized")),"Fresh checkout creates initialization marker")
 check(not FileAccess.file_exists(Store.Paths.root().path_join("saves/decks.json")),"Initialization does not create a private legacy collection")
 for deck in loaded.decks:check(Store.delete_file(deck.id).is_empty(),"Only isolated fixture deck can be deleted")
 check(Store.load_decks().decks.is_empty(),"Deleted presets do not reappear on next startup")

 use_root("legacy-player")
 var legacy=presets.decks[0].duplicate(true);legacy.id="private_legacy";legacy.name="个人旧卡组"
 var legacy_path=Store.Paths.root().path_join("saves/decks.json")
 write_json(legacy_path,{"version":1,"decks":[legacy]})
 var legacy_bytes=FileAccess.get_file_as_bytes(legacy_path)
 check(Store.initial_decks_path()==legacy_path,"Existing source checkout still selects legacy migration input")
 loaded=Store.load_decks()
 check(not loaded.has("error") and loaded.decks==[Store.clean_deck(legacy)],"Existing legacy decks migrate without replacing player choices")
 check(FileAccess.get_file_as_bytes(legacy_path)==legacy_bytes,"Legacy collection remains byte-for-byte unchanged")
 var personal=presets.decks[0].duplicate(true);personal.id="private_portable";personal.name="个人便携卡组"
 check(Store.save_file(personal).is_empty(),"Private portable deck exists in isolated root")
 check(Export.release_decks()==release,"Legacy and portable player decks never change exported presets")
 check(FileAccess.get_file_as_bytes(legacy_path)==legacy_bytes,"Export leaves legacy collection unchanged")

 use_root("broken-legacy")
 legacy_path=Store.Paths.root().path_join("saves/decks.json")
 write_json(legacy_path,{"version":1,"decks":"invalid"})
 legacy_bytes=FileAccess.get_file_as_bytes(legacy_path)
 loaded=Store.load_decks()
 check(loaded.has("error") and Store.scan_files(Store.folder()).is_empty(),"Broken legacy data is reported without silently replacing it")
 check(FileAccess.get_file_as_bytes(legacy_path)==legacy_bytes,"Broken legacy data is preserved for recovery")
 check(Export.release_decks()==release,"Broken private legacy data cannot block an official export")
 check(FileAccess.get_file_as_bytes(Store.PRESET_DECKS_PATH)==public_bytes,"All initialization and export checks preserve public source")
 Store.Paths.root_override=""
 Store.file_paths.clear()
 print("REPOSITORY_BOOTSTRAP: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
