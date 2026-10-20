extends SceneTree
const Registry=preload("res://scripts/rules/mod_registry.gd")
const DB=preload("res://scripts/card_database.gd")
const Art=preload("res://scripts/card_art.gd")
var checks=0
var failures=[]

func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func _initialize():call_deferred("run")

func run():
 Registry._shared=Registry.new()
 expect(Registry.shared().register_pack("res://examples/testmod").is_empty(),"project pack registers")
 var project_manifest=Registry.shared().manifest()
 var project_cards=DB.load_cards()
 expect(not project_cards.is_empty(),"project images load: "+DB.last_error)
 var source="res://examples/testmod"
 # Absolute OS paths exercise the portable-mod route, without imported textures.
 var external=ProjectSettings.globalize_path("res://work/mod-card-art-test/"+str(Time.get_ticks_usec()))
 expect(DirAccess.make_dir_recursive_absolute(external.path_join("art"))==OK,"external fixture directory")
 for file in DirAccess.get_files_at(source):
  if file.ends_with(".uid") or file.ends_with(".import"):continue
  expect(DirAccess.copy_absolute(source.path_join(file),external.path_join(file))==OK,"copy "+file)
 for file in DirAccess.get_files_at(source.path_join("art")):
  if file.get_extension().to_lower() in ["png","jpg","jpeg","webp","svg"]:expect(DirAccess.copy_absolute(source.path_join("art").path_join(file),external.path_join("art").path_join(file))==OK,"copy art "+file)
 Registry._shared=Registry.new()
 expect(Registry.shared().register_pack(external).is_empty(),"external pack registers")
 expect(Registry.shared().manifest()==project_manifest,"pack content hash is independent of absolute location")
 var cards=DB.load_cards()
 expect(not cards.is_empty(),"external card images load: "+DB.last_error)
 if cards.is_empty():quit(1);return
 for item in Registry.shared().card_files:
  var raw=JSON.parse_string(item.content)
  var id=raw["卡牌ID"]
  expect(cards.has(id),"external card present: "+id)
  if not cards.has(id):continue
  var c=cards[id]
  var external_art=not raw["图片"].begins_with("res://")
  expect(c.image.begins_with(external+"/art/") if external_art else c.image==raw["图片"],"relative art resolves inside pack or preserves an existing base-card reference: "+id)
  var texture=Art.load_texture(c.image)
  expect(texture!=null,"external texture decodes: "+id)
  if texture!=null:
   var original=Art.load_texture(project_cards[id].image)
   expect(original!=null and texture.get_size()==original.get_size(),"external art preserves source resolution: "+id)
  var before=project_cards.get(id,{}).duplicate(true)
  var after=c.duplicate(true)
  before.erase("image");after.erase("image")
  expect(before==after,"portable cards retain rules: "+id)
 expect(Art.load_texture(external+"/art/missing.png")==null,"missing file returns null")
 expect(Registry.local_path(external,"../outside.png").is_empty(),"parent traversal rejected")
 var app=load("res://scripts/main.gd").new()
 app.Store.CARDS=cards
 for id in ["testmod/utsuho","testmod/blade"]:
  var hand=app.texture(id,"test-default")
  expect(hand!=null and hand.get_size()==Vector2(1200,1676),"hand texture loads and rotates: "+id)
  var preview=app.preview_texture(id,"test-default")
  var expected=Vector2(1676,1200) if cards[id].landscape else Vector2(1200,1676)
  expect(preview!=null and preview.get_size()==expected,"inspection orientation: "+id)
 var leader=load("res://scripts/public_leader_card.gd").new()
 leader.app=app;leader.card_id="testmod/byakuren";leader._ready()
 expect(leader.picture.texture!=null,"public leader uses external art")
 leader.free()
 var parent=Control.new();var cache={}
 preload("res://scripts/deck_image_export.gd")._card(parent,"testmod/blade",Rect2(0,0,320,448),cache)
 expect(cache.has("testmod/blade"),"deck image export loads external art")
 parent.free()
 # Main._ready normally attaches this node; this fixture never enters the tree.
 app.tournament_unread.free();app.free()
 var entry=Registry.shared().card_files[0]
 var invalid=JSON.parse_string(entry.content)
 invalid["图片"]="../outside.png";entry.content=JSON.stringify(invalid)
 expect(DB.load_cards().is_empty() and "相对路径" in DB.last_error,"database rejects escaping image path")
 print("MOD CARD ART: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
