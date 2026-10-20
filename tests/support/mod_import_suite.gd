extends RefCounted
const Importer=preload("res://scripts/mod_importer.gd")
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Paths=preload("res://scripts/portable_paths.gd")
const DB=preload("res://scripts/card_database.gd")
const Fixture=preload("res://tests/support/mod_import_fixture.gd")
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
var directory=""
var files={}
var config=[]
var sequence=0


func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func reject(contents: Dictionary,title: String,fragment: String=""):
 sequence+=1
 var before=Registry.configuration();var registry=Registry._shared
 var result=Importer.import_file(Fixture.package(directory.path_join(str(sequence)+".zip"),contents),config)
 expect(result.has("error") and (fragment.is_empty() or result.error.contains(fragment)),title+": "+str(result))
 expect(Registry.configuration()==before and Registry._shared==registry,title+" preserves configuration and live registry")
 expect(Array(DirAccess.get_directories_at(Registry.install_root())).all(func(value):return not value.begins_with(".import-")),title+" cleans temporary files")

func run():
 directory=ProjectSettings.globalize_path(("user://" if OS.get_name()=="Android" else "res://work/")+"mod-importer/"+str(Time.get_ticks_usec()))
 Paths.root_override=directory;Paths.initialize()
 Registry._shared=Registry.new();files=Fixture.files()
 var first_manifest=[]
 var installed_path=""
 expect(Importer.crc32("123456789".to_utf8_buffer())==0xcbf43926,"ZIP CRC uses standard polynomial")
 for prefix in ["","second.cards/"]:
  Paths.root_override=directory.path_join("valid-"+str(prefix.length()));Paths.initialize()
  var result=Importer.import_file(Fixture.package(directory.path_join("valid.zip"),files,prefix),[])
  expect(not result.has("error"),"valid ZIP imports with prefix "+prefix+": "+str(result))
  if result.has("error"):continue
  expect(result.path==Registry.install_root().path_join("second.cards") and FileAccess.file_exists(result.path.path_join("art/card.png")),"files installed under local mod folder")
  config=Registry.configuration()
  expect(config.size()==1 and not config[0].enabled,"import saves disabled selection")
  expect(Registry.shared().packs.is_empty(),"import leaves live registry unchanged")
  var loaded=Registry.new();expect(loaded.register_pack(result.path).is_empty(),"installed external scripts compile")
  if first_manifest.is_empty():first_manifest=loaded.manifest()
  else:expect(loaded.manifest()==first_manifest,"separate clients install identical manifest hashes at different paths")
  installed_path=result.path
  var original=Registry._shared;Registry._shared=loaded
  expect(DB.load_cards().has("second.cards/draw"),"installed cards and relative artwork validate")
  Registry._shared=original
  reject(files,"duplicate ID rejected while disabled","相同模组")
  reject(Fixture.change(files,"manifest.json","version","0.9"),"older version rejected","版本较旧")
  reject(Fixture.change(files,"manifest.json","id","Second.Cards"),"ID case change cannot bypass duplicate check","相同模组")
  config=[];reject(files,"installed directory is protected even without a config entry","相同模组")
 Paths.root_override=directory.path_join("invalid");Paths.initialize();config=[]
 config=[{"path":installed_path,"enabled":false}]
 reject(files,"legacy directory configuration blocks duplicate ID","相同模组")
 config=[]
 var invalids=[
  [Fixture.change(files,"manifest.json","id","../escape"),"unsafe ID"],
  [Fixture.change(files,"manifest.json","id","CON"),"Windows device ID"],
  [Fixture.change(files,"manifest.json","id","bad\\id"),"backslash ID"],
  [Fixture.change(files,"manifest.json","id","example.cards"),"duplicate bundled pack ID"],
  [Fixture.change(files,"manifest.json","api",Registry.API_VERSION+1),"unsupported API"],
  [Fixture.change(files,"manifest.json","api","3"),"API must be numeric"],
  [Fixture.change(files,"manifest.json","api",1.5),"API must be integral"],
  [Fixture.change(files,"manifest.json","version",""),"missing version"],
  [Fixture.change(files,"manifest.json","abilities",[]),"invalid ability schema"],
  [Fixture.change(files,"manifest.json","cards",["missing.json"]),"missing card"],
  [Fixture.change(files,"manifest.json","cards",["../draw.json"]),"card path traversal"],
  [Fixture.change(files,"manifest.json","cards",["draw.json","draw.json"]),"duplicate card ID"],
  [Fixture.change(files,"manifest.json","state",{"bad":{"scope":"bad","visibility":"public"}}),"invalid state schema"],
  [Fixture.change(files,"draw.json","卡牌ID","foreign/card"),"foreign card namespace"],
  [Fixture.change(files,"draw.json","关键词",true),"invalid keyword type"],
  [Fixture.change(files,"draw.json","颜色",["invalid"]),"invalid card color"],
  [Fixture.change(files,"draw.json","图片","../escape.png"),"image path traversal"],
  [Fixture.change(files,"draw.json","图片","art/missing.png"),"missing card image"],
  [Fixture.change(files,"draw.json","能力绑定",[{"实现":"mod","实例键":"one","参数":{"能力":"missing/draw"}}]),"unknown card ability"]
 ]
 for item in invalids:reject(item[0],item[1])
 var broken=files.duplicate(true);broken.erase("manifest.json");reject(broken,"missing manifest")
 broken=files.duplicate(true);broken["manifest.json"]="{broken";reject(broken,"malformed manifest")
 broken=files.duplicate(true);broken["draw.json"]="[]";reject(broken,"malformed card")
 broken=files.duplicate(true);broken.erase("draw.gd");reject(broken,"missing ability script")
 broken=files.duplicate(true);broken["draw.gd"]="extends RefCounted\nfunc validate(_params):return \"\"\n";reject(broken,"missing script entry points")
 broken=files.duplicate(true);broken["draw.gd"]=files["draw.gd"].get_string_from_utf8().replace("extends RefCounted","extends RefCounted\nfunc _init(_required):pass").to_utf8_buffer();reject(broken,"constructor requiring arguments")
 broken=files.duplicate(true);broken["draw.gd"]=files["draw.gd"].get_string_from_utf8().replace("func describe_action(_ctx, _params: Dictionary)","func describe_action()").replace("func describe_action(_ctx,_params: Dictionary)","func describe_action()").to_utf8_buffer();reject(broken,"wrong ability entry argument count")
 broken=files.duplicate(true);broken["other/manifest.json"]=files["manifest.json"];reject(broken,"multiple packs in one archive")
 for path in ["../escape.txt","C:/escape.txt","a\\escape.txt","a//file","a/./file","a/../file","a./file","con.txt","AUX/file","README.txt","Readme.txt"]:
  broken=files.duplicate(true);broken[path]="test"
  if path in ["README.txt","Readme.txt"]:broken["readme.TXT"]="duplicate"
  reject(broken,"reject invalid ZIP path "+path)
 broken=files.duplicate(true);broken["folder"]="file";broken["folder/file"]="conflict";reject(broken,"file-directory conflict")
 var nested=Fixture.package(directory.path_join("nested.zip"),files,"a/b/")
 expect(Importer.import_file(nested,[]).has("error"),"reject deeply nested manifest")
 broken=files.duplicate(true);broken["outside.txt"]="outside"
 var outside=Fixture.package(directory.path_join("outside.zip"),files,"second.cards/")
 var zip=ZIPPacker.new();zip.open(outside,ZIPPacker.APPEND_ADDINZIP);zip.start_file("outside.txt");zip.write_file("outside".to_utf8_buffer());zip.close_file();zip.close()
 expect(Importer.import_file(outside,[]).has("error"),"reject files outside wrapper directory")
 for mutation in ["crc","large","encrypted","symlink"]:
  var path=Fixture.package(directory.path_join(mutation+".zip"),files)
  var bytes=FileAccess.get_file_as_bytes(path)
  for offset in range(bytes.size()-46):
   if bytes.decode_u32(offset)!=0x02014b50:continue
   if mutation=="crc":bytes.encode_u32(offset+16,0)
   elif mutation=="large":bytes.encode_u32(offset+24,Importer.MAX_FILE_BYTES+1)
   elif mutation=="encrypted":bytes.encode_u16(offset+8,1)
   else:bytes.encode_u32(offset+38,0xa1ff0000)
   break
  var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
  expect(Importer.import_file(path,[]).has("error"),"reject ZIP "+mutation)
 Paths.root_override=directory.path_join("save-failure");Paths.initialize()
 DirAccess.make_dir_absolute(Registry.config_path())
 var result=Importer.import_file(Fixture.package(directory.path_join("save-failure.zip"),files),[])
 expect(result.has("error") and not DirAccess.dir_exists_absolute(Registry.install_root().path_join("second.cards")),"failed config save rolls back installed files")
 expect(DirAccess.get_directories_at(Registry.install_root()).is_empty(),"failed config save cleans staging")
 lifecycle()
 print("MOD_IMPORTER: %d checks; %d failures" % [checks,failures.size()])
 return 0 if failures.is_empty() else 1

func lifecycle():
 for item in [["1.10","1.9",1],["1.2","1.2.0",0],["v1.2.3.4","1.2.3",1],["1.0.0","1.0.0-rc.1",1],["1.0-beta.10","1.0-beta.2",1],["1.0-alpha","1.0-beta",-1],["1.0-alpha.1","1.0-alpha",1],["1.0-2","1.0-alpha",-1],["1.0+build.2","1.0+build.1",0]]:
  expect(Importer.compare_versions(item[0],item[1]).get("order",99)==item[2],"version ordering "+str(item))
 expect(Importer.compare_versions("latest","1.0").has("error"),"unknown version format cannot auto replace")
 Paths.root_override=directory.path_join("lifecycle");Paths.initialize()
 var original=files.duplicate(true);original["obsolete.txt"]="old file"
 var result=Importer.import_file(Fixture.package(directory.path_join("original.zip"),original),[])
 expect(not result.has("error"),"install lifecycle fixture")
 if result.has("error"):return
 var path=result.path;config=Registry.configuration();config[0].enabled=true
 expect(Importer.apply_configuration(config).is_empty() and Store.CARDS.has("second.cards/draw"),"enable installed pack before upgrade")
 var incoming=Fixture.change(files,"manifest.json","version","1.10.0")
 incoming=Fixture.change(incoming,"draw.json","名称","新版双抽")
 incoming["draw.gd"]=(files["draw.gd"].get_string_from_utf8()+'\nfunc revision():return "new"\n').to_utf8_buffer()
 result=Importer.import_file(Fixture.package(directory.path_join("upgrade.zip"),incoming),config)
 expect(not result.has("error") and result.get("updated",false) and result.get("previous_version")=="1.0.0","newer ZIP automatically replaces same ID")
 expect(Registry.configuration().size()==1 and Registry.configuration()[0].enabled and Registry.shared().packs["second.cards"].version=="1.10.0","upgrade preserves selection and refreshes live version")
 expect(Store.CARDS["second.cards/draw"].name.contains("新版双抽") and Registry.shared().abilities["second.cards/draw"].script.new().revision()=="new","upgrade immediately reloads card definitions and scripts")
 expect(not FileAccess.file_exists(path.path_join("obsolete.txt")),"replacement removes files absent from new ZIP")
 config=Registry.configuration();var before_hash=Registry.content_hash(path)
 reject(incoming,"same version remains rejected","相同模组")
 reject(files,"upgrade cannot be downgraded","版本较旧")
 var broken=Fixture.change(incoming,"manifest.json","version","2.0");broken.erase("draw.gd")
 reject(broken,"invalid upgrade preserves enabled installation")
 expect(Registry.content_hash(path)==before_hash and Registry.shared().packs["second.cards"].version=="1.10.0","failed upgrade retains installed files and runtime")
 var upgrade=Fixture.change(incoming,"manifest.json","version","2.0")
 # A directory at mods.json.tmp forces a save failure without altering saved config.
 DirAccess.make_dir_absolute(Registry.config_path()+".tmp")
 reject(upgrade,"failed upgrade config save rolls back files")
 var live=Registry._shared;var cards=Store.CARDS;var saved=Registry.configuration()
 result=Importer.delete_mod(path,saved)
 expect(result.has("error") and Registry.content_hash(path)==before_hash and Registry.configuration()==saved and Registry._shared==live and Store.CARDS==cards,"failed deletion restores files, config and live cards")
 expect(DirAccess.get_directories_at(Registry.install_root())==PackedStringArray(["second.cards"]),"failed lifecycle operations clean staging")
 DirAccess.remove_absolute(Registry.config_path()+".tmp")
 result=Importer.delete_mod(path,saved)
 expect(not result.has("error") and result.get("removed_files",false) and not DirAccess.dir_exists_absolute(path),"delete removes managed installation")
 expect(Registry.configuration().is_empty() and Registry.shared().packs.is_empty() and not Store.CARDS.has("second.cards/draw"),"delete immediately removes config, abilities and cards")
 expect(FileAccess.file_exists(directory.path_join("original.zip")),"deletion keeps original archive")
 result=Importer.import_file(Fixture.package(directory.path_join("reinstall.zip"),files),[])
 config=Registry.configuration()
 expect(not result.has("error") and not config[0].enabled,"deleted pack can be installed again")
 result=Importer.import_file(Fixture.package(directory.path_join("disabled-upgrade.zip"),upgrade),config)
 expect(not result.has("error") and not Registry.configuration()[0].enabled and Store.CARDS.get("second.cards/draw",{}).get("inactive_mod",false) and not Registry.shared().packs.has("second.cards"),"disabled upgrade preserves read-only cards without activating abilities")
 Importer.delete_mod(path,Registry.configuration())
 var external=ProjectSettings.globalize_path("res://tests/support/mod_second")
 config=[{"path":external,"enabled":true}];expect(Importer.apply_configuration(config).is_empty(),"legacy directory fixture loads")
 result=Importer.import_file(Fixture.package(directory.path_join("external-upgrade.zip"),upgrade),config)
 expect(not result.has("error") and Registry.configuration()[0].path==path and Registry.configuration()[0].enabled and FileAccess.file_exists(external.path_join("manifest.json")),"legacy directory update migrates registration and preserves source")
 Importer.delete_mod(path,Registry.configuration())
 Importer.apply_configuration(config)
 result=Importer.delete_mod(external,config)
 expect(not result.has("error") and not result.get("removed_files",true) and FileAccess.file_exists(external.path_join("manifest.json")) and Registry.configuration().is_empty(),"deleting legacy registration preserves external files")
 var missing=Registry.install_root().path_join("missing")
 config=[{"path":missing,"enabled":true}];Registry.save_configuration(config)
 expect(not Importer.delete_mod(missing,config).has("error") and Registry.configuration().is_empty(),"missing pack registration can be removed")
