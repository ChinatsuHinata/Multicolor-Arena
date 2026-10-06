extends "res://scripts/patch_manager.gd"
var fail_commit=false

func _write_index(entries: Array) -> Error:
 return ERR_CANT_CREATE if fail_commit else super._write_index(entries)
