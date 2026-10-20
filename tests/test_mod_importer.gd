extends SceneTree
func _initialize():call_deferred("run")
func run():quit(preload("res://tests/support/mod_import_suite.gd").new().run())