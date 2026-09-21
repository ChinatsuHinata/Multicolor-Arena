extends "res://tests/test_v015_ui.gd"
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v0151/"+name+".png")
