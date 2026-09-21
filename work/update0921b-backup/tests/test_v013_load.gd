extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
func _initialize():
 print("DATABASE ",Store.CARDS.size())
 var e=Duel.new()
 print("ENGINE OK ",e.cards.size())
 quit()


