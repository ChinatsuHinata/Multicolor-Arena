extends "res://tests/test_v092.gd"
const Database=preload("res://scripts/card_database.gd")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 var migration=JSON.parse_string(FileAccess.get_file_as_string("res://work/v097-migration.json"))
 var cards=Database.load_cards()
 expect(Database.last_error.is_empty() and cards.size()==269,"registered database loads with no missing-art error")
 expect(migration.ids.all(func(id): return id in Database.IDS),"all 65 previously registered IDs remain available")
 if cards.size()!=269: quit(1); return
 for id in Database.IDS:
  var path=cards[id].image
  expect(path.begins_with(Database.ART_DIRECTORY) and path.get_file().get_basename()==id,"canonical database image: "+id)
  var art=load(path) as Texture2D
  expect(art!=null and art.get_width()>0 and art.get_height()>0,"Godot can decode actual imported texture: "+id)
 var definition=JSON.parse_string(FileAccess.get_file_as_string("res://cards/177.json"))
 var invalid=definition.duplicate(true); invalid["图片"]="res://recourse/新增卡片/image177.png"
 expect("卡图未归档" in Database.validate_definition(invalid,"177"),"pending folder cannot be used as runtime art directory")
 invalid=definition.duplicate(true); invalid["图片"]="res://recourse/数据库/177.webp"
 expect(Database.validate_definition(invalid,"177")=="图片不存在：res://recourse/数据库/177.webp","missing-art diagnostic includes exact image path")
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 expect(app.load_error.is_empty(),"main menu does not show the reported database error")
 app.load_legacy_test_decks(); app.editor(); app.selected="177"; app.update_preview(); await process_frame
 var texture=app.texture("177")
 expect(texture!=null and texture.get_size()==Vector2(1200,1676),"card 177 previews at normalized resolution in deck editor")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/v097-card177-editor.png")
 app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine; clean()
 var spell=put("177","hand"); var target=put("53","field"); put("165","palette"); put("164","palette")
 view.render(); await settle(); await click(view.hand_nodes[spell.uid].get_global_rect().get_center())
 view.choose_target(e.ref_target(target)); await press("确定")
 expect(spell.zone=="stack","relocated spell can be cast through battle interface")
 resolve(); view.render(); await settle()
 expect(spell.zone=="grave" and e.stat(target,"power")==4 and e.stat(target,"health")==1,"card 177 resolves its existing effect without changing rules")
 view.inspect_card("177",spell.uid)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/v097-card177-battle.png")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"saved decks remain unchanged")
 var report="%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)]
 FileAccess.open("res://work/v097-database-tests.txt",FileAccess.WRITE).store_string(report)
 print("V097_DATABASE: "+report); quit(0 if failures.is_empty() else 1)
