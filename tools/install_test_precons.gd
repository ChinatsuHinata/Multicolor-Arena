extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
func _initialize():
 var loaded=Store.load_decks()
 if loaded.has("error"): fail(loaded.error); return
 var templates=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json"))
 if not templates is Dictionary or not templates.get("decks") is Array:
  fail("预组模板格式错误"); return
 var original=loaded.decks.duplicate(true)
 var updated=original.duplicate(true)
 for template in templates.decks:
  var error=Store.validate(template,true)
  if not error.is_empty(): fail(error); return
  var existing=updated.filter(func(d): return d.id==template.id)
  if not existing.is_empty():
   if existing[0]!=template: fail("已有预组被修改，保留玩家版本："+template.name); return
   continue
  updated.append(template.duplicate(true))
 if updated!=original:
  var error=Store.persist(updated)
  if not error.is_empty(): fail(error); return
 var reloaded=Store.load_decks()
 if reloaded.has("error") or reloaded.decks!=updated or reloaded.decks.slice(0,original.size())!=original:
  fail("保存后核对失败"); return
 print("PRECONS_SAVED: %d decks; original %d preserved; strict 50+1 templates installed" % [updated.size(),original.size()])
 quit()
func fail(message: String):
 push_error(message); quit(1)
