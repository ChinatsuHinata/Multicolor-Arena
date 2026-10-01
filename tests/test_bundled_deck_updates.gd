extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Policy=preload("res://addons/share_export/release_policy.gd")
var checks=0
var failures=[]
var base=""
var bundle_path=""
var remilia={}

func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func write_json(path: String,value: Dictionary):
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify(value));file.close()

func installed_root(name: String):
 Store.Paths.root_override=base.path_join(name)
 expect(Store.Paths.initialize().is_empty(),"isolated installation created: "+name)
 var marker=FileAccess.open(Store.folder().path_join(".initialized"),FileAccess.WRITE)
 marker.store_string("1");marker.close()
 Store.file_paths.clear()

func _initialize():
 base=ProjectSettings.globalize_path("res://work/bundled-deck-updates/"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(base)
 bundle_path=base.path_join("bundle.json")
 var portable=[]
 for source in Store.scan_files("res://deck"):
  var parsed=Store.read_file(source)
  if parsed.has("deck"):portable.append(parsed.deck)
 var release=Policy.select_decks(Store.load_decks(Store.SAVE_PATH).decks,portable)
 expect(not release.has("error"),"real release decks are available")
 if release.has("error"):quit(1);return
 remilia=release.decks[-1]
 write_json(bundle_path,{"version":1,"decks":release.decks,"upgrade_deck_ids":[Policy.REMILIA_ID]})

 installed_root("upgrade")
 var personal=release.decks[0].duplicate(true);personal.id="personal";personal.name="我的自组卡组"
 expect(Store.save_file(personal).is_empty(),"personal deck saved before upgrade")
 var personal_path=Store.file_paths[personal.id]
 var original=FileAccess.get_file_as_bytes(personal_path)
 expect(Store.install_bundled_updates(bundle_path).is_empty(),"initialized installation receives new AI deck")
 var loaded=Store.load_decks()
 expect(loaded.decks.size()==2 and loaded.decks.any(func(d):return d==remilia),"only approved AI added; old presets not restored")
 expect(FileAccess.get_file_as_bytes(personal_path)==original,"personal deck remains byte-for-byte unchanged")
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks.size()==2,"repeated startup does not duplicate AI")
 expect(Store.delete_file(remilia.id).is_empty(),"player can delete delivered AI deck")
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks.size()==1,"deleted AI stays deleted after restart")

 installed_root("legacy-name")
 var legacy=remilia.duplicate(true);legacy.name="蕾米速攻（ai）"
 expect(Store.save_file(legacy).is_empty(),"older bundled AI saved with previous default name")
 var delivered=FileAccess.open(Store.bundled_update_marker(remilia.id),FileAccess.WRITE)
 delivered.store_string("1");delivered.close()
 expect(Store.install_bundled_updates(bundle_path).is_empty(),"older bundled AI name is corrected")
 var corrected=Store.load_decks().decks
 expect(corrected.size()==1 and corrected[0].name==remilia.name and corrected[0].main==legacy.main,"default name correction preserves deck contents")
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks==corrected,"name correction is stable on repeated startup")

 installed_root("existing-renamed")
 var edited=remilia.duplicate(true);edited.name="我改过的蕾米";edited.main.pop_back()
 var nested=Store.folder().path_join("个人收藏")
 DirAccess.make_dir_recursive_absolute(nested)
 var edited_path=nested.path_join(Store.filename(edited))
 expect(Store.save_file(edited,edited_path).is_empty(),"edited AI exists in nested folder")
 original=FileAccess.get_file_as_bytes(edited_path)
 expect(Store.install_bundled_updates(bundle_path).is_empty(),"existing AI ID is recognized")
 expect(Store.load_decks().decks==[edited] and FileAccess.get_file_as_bytes(edited_path)==original,"upgrade preserves renamed deck and edited card list")

 installed_root("empty-upgrade")
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks==[remilia],"empty older library receives just the new AI")
 Store.delete_file(remilia.id)
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks.is_empty(),"empty library stays empty after deleting delivered AI")

 installed_root("first-launch")
 for deck in release.decks:expect(Store.save_file(deck).is_empty(),"fresh preset saved: "+deck.name)
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks.size()==release.decks.size(),"fresh install does not duplicate seeded AI")
 for deck in Store.load_decks().decks:Store.delete_file(deck.id)
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.load_decks().decks.is_empty(),"deleting all fresh presets stays empty")

 installed_root("invalid-manifest")
 write_json(bundle_path,{"version":1,"decks":release.decks,"upgrade_deck_ids":["missing"]})
 expect(not Store.install_bundled_updates(bundle_path).is_empty() and Store.scan_files(Store.folder()).is_empty(),"invalid delivery manifest writes no decks")
 write_json(bundle_path,{"version":1,"decks":release.decks})
 expect(Store.install_bundled_updates(bundle_path).is_empty() and Store.scan_files(Store.folder()).is_empty(),"bundle without delivery metadata leaves existing library alone")
 Store.Paths.root_override=""
 print("BUNDLED_DECK_UPDATES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
