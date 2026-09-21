extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var files=[]
 for file in DirAccess.get_files_at("res://recourse/新增卡片"):
  if file.get_extension() in ["png","jpg"]: files.append(file)
 files.sort_custom(func(a,b): return a.naturalnocasecmp_to(b)<0)
 root.size=Vector2i(1600,900)
 var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei"])
 for page in range(ceili(files.size()/10.0)):
  var scene=Control.new(); root.add_child(scene)
  for offset in range(10):
   var index=page*10+offset
   if index>=files.size(): break
   var file=files[index]; var x=(offset%5)*320; var y=(offset/5)*450
   var label=Label.new(); label.position=Vector2(x,y); label.size=Vector2(320,26); label.text=file; label.add_theme_font_override("font",font); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; scene.add_child(label)
   var img=Image.load_from_file("res://recourse/新增卡片/"+file)
   if img.get_width()>img.get_height(): img.rotate_90(CLOCKWISE)
   var art=TextureRect.new(); art.position=Vector2(x+10,y+27); art.size=Vector2(300,420); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.texture=ImageTexture.create_from_image(img); scene.add_child(art)
  await process_frame; await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/v09-card-sheet-%d.png" % page)
  root.remove_child(scene); scene.queue_free()
 quit()
