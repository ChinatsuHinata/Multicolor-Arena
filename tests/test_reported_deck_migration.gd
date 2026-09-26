extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const CODE="MA1Z:510:eJxtkE0OgkAMhe/SNZO0zACHIS4IDJEEjAESOYBbE927cesVjMdBr2HnRwNmdjPfa99rm8Prep8vz/l8mk+39+MIEZTboi/KUfei141AJIjyHDKESG6ifCHXVS30ZHQWYKcPYthPvgEoWE5GjNfcpsSx58Net61jtGamHzEJ1LGnMowQ7YsfihdxJV3Rc4mCtQ9951v4YOp9lt4YmCGzDOpGt5VvTYz/Ekg/ibnbVxm6jhXlkx2rqx2npMbx/yylsHvwXrF0icG9fqOxkeQ0IElrSplxaUbdub9SNm7zAW+ElvM"
const LEGACY_PATH="res://work/test-reported-legacy-decks.json"
const DECK_PATH="res://work/test-reported-import.mdeck"
var failures=[]

func check(ok: bool, description: String):
 if ok:print("PASS "+description)
 else:failures.append(description);push_error(description)

func _initialize():
 var decoded=Store.decode(CODE)
 check(decoded.has("deck"),"reported code decodes")
 if not decoded.has("deck"):
  quit(1)
  return
 var deck=decoded.deck
 check(deck.main.size()==50 and deck.side.size()==10 and Store.validate(deck).is_empty(),"reported deck passes unrestricted save validation")
 check(Store.save_file(deck,DECK_PATH).is_empty(),"reported deck saves as mdeck")
 var loaded_file=Store.read_file(DECK_PATH)
 check(loaded_file.has("deck") and loaded_file.deck.main==deck.main,"saved mdeck reads back")
 var broken=deck.duplicate(true)
 broken.main[0]="missing-card"
 var duplicate=deck.duplicate(true)
 var missing_id=deck.duplicate(true)
 missing_id.erase("id")
 var original=JSON.stringify({"version":1,"decks":[deck,broken,duplicate,missing_id]},"  ")
 var file=FileAccess.open(LEGACY_PATH,FileAccess.WRITE)
 file.store_string(original)
 file.close()
 var strict=Store.load_decks(LEGACY_PATH)
 check(strict.has("error") and "第 2 副" in strict.error,"strict loader identifies invalid legacy deck")
 var recovered=Store.recover_legacy_decks(LEGACY_PATH)
 check(recovered.decks.size()==3 and recovered.warnings.size()==4,"migration keeps valid decks and reports skipped data")
 check(recovered.decks[0].id==deck.id and recovered.decks[1].id!=deck.id and recovered.decks[2].id!=deck.id,"duplicate and missing IDs receive distinct IDs")
 check(FileAccess.get_file_as_string(LEGACY_PATH)==original,"migration leaves original legacy file untouched")
 file=FileAccess.open(LEGACY_PATH,FileAccess.WRITE)
 file.store_string("{broken")
 file.close()
 var malformed=Store.recover_legacy_decks(LEGACY_PATH)
 check(malformed.decks.is_empty() and not malformed.warnings.is_empty(),"malformed legacy file does not abort recovery")
 for path in [LEGACY_PATH,DECK_PATH,DECK_PATH+".bak"]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("REPORTED_DECK_MIGRATION ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
