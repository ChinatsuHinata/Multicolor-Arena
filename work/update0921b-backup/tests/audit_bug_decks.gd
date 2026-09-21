extends SceneTree
func _initialize():
 var store=load("res://scripts/deck_store.gd")
 print("root=",store.Paths.root()," warnings=",store.load_decks().get("warnings",[]))
 for d in store.load_decks().decks:
  print(d.name," main=",d.main.size()," self=",d.leader," error=",store.validate(d,true))
 quit()
