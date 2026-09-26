extends RefCounted

const Store=preload("res://scripts/deck_store.gd")
const RuleSet=preload("res://scripts/deck_rule_set.gd")
const WIDTH=2000
const MAIN_X=260
const CARD_WIDTH=160
const CARD_HEIGHT=224
const CARD_STEP_X=169
const CARD_STEP_Y=234

static func capture(owner: Control,deck: Dictionary,unsaved: bool=false) -> Dictionary:
 var folder=Store.folder().path_join("image")
 var directory_error=DirAccess.make_dir_recursive_absolute(folder)
 if directory_error!=OK:return {"error":"无法创建截图文件夹："+error_string(directory_error)}
 var main_rows=maxi(5,ceili(float(deck.main.size())/10.0))
 var side_title_y=140+main_rows*CARD_STEP_Y+24
 var side_card_y=side_title_y+48
 var height=side_card_y+CARD_HEIGHT+48
 var viewport=SubViewport.new()
 viewport.disable_3d=true
 viewport.size=Vector2i(WIDTH,height)
 viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 owner.add_child(viewport)
 var canvas=Control.new()
 canvas.size=Vector2(WIDTH,height)
 canvas.theme=owner.theme
 viewport.add_child(canvas)
 _block(canvas,Rect2(0,0,WIDTH,height),Color("#09121d"),Color("#09121d"))
 _text(canvas,deck.name+("  *未保存" if unsaved else ""),Rect2(32,24,1500,52),36,Color("#d9b775"))
 var rule=RuleSet.label_for(str(deck.get("rule_set",RuleSet.OFFICIAL)))
 _text(canvas,"规则集：%s    主卡组 %d / %d    副卡组 %d / 10    自机 %d / 1" % [rule,deck.main.size(),RuleSet.main_limit(str(deck.get("rule_set",RuleSet.OFFICIAL))),deck.side.size(),0 if str(deck.leader).is_empty() else 1],Rect2(34,82,1900,34),23,Color("#91a5b7"))
 _text(canvas,"自机",Rect2(32,118,200,36),25,Color("#d9b775"))
 _text(canvas,"主卡组",Rect2(MAIN_X,118,500,36),25,Color("#d9b775"))
 var thumbnails={}
 if not str(deck.leader).is_empty():
  _card(canvas,str(deck.leader),Rect2(32,160,210,294),thumbnails,deck)
 else:
  _block(canvas,Rect2(32,160,210,294),Color("#13232f"),Color("#3b5060"))
  _text(canvas,"尚未选择自机",Rect2(42,278,190,42),22,Color("#91a5b7"))
 for index in range(deck.main.size()):
  _card(canvas,str(deck.main[index]),Rect2(MAIN_X+(index%10)*CARD_STEP_X,160+floori(float(index)/10.0)*CARD_STEP_Y,CARD_WIDTH,CARD_HEIGHT),thumbnails,deck)
 if deck.main.is_empty():_text(canvas,"主卡组为空",Rect2(MAIN_X,250,680,48),28,Color("#91a5b7"))
 _text(canvas,"副卡组",Rect2(MAIN_X,side_title_y,600,36),25,Color("#d9b775"))
 for index in range(deck.side.size()):
  _card(canvas,str(deck.side[index]),Rect2(MAIN_X+index*CARD_STEP_X,side_card_y,CARD_WIDTH,CARD_HEIGHT),thumbnails,deck)
 if deck.side.is_empty():_text(canvas,"副卡组为空",Rect2(MAIN_X,side_card_y+72,500,42),24,Color("#91a5b7"))
 await owner.get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image=viewport.get_texture().get_image()
 viewport.queue_free()
 if image.is_empty():return {"error":"无法读取卡组截图。"}
 var title=str(deck.name).validate_filename().strip_edges().trim_suffix(".")
 if title.is_empty():title="卡组"
 var timestamp=Time.get_datetime_string_from_system().replace(":","-").replace("T","_")
 var filename=title.left(40)+"_"+str(deck.id).sha256_text().left(8)+"_"+timestamp+"_"+str(Time.get_ticks_msec()%1000).pad_zeros(3)+".png"
 var path=folder.path_join(filename)
 var write_error=image.save_png(path)
 if write_error!=OK:return {"error":"截图保存失败："+error_string(write_error)}
 return {"path":path}

static func _block(parent: Control,rect: Rect2,fill: Color,border: Color) -> Panel:
 var panel=Panel.new()
 panel.position=rect.position
 panel.size=rect.size
 var style=StyleBoxFlat.new()
 style.bg_color=fill
 style.border_color=border
 style.set_border_width_all(1)
 style.set_corner_radius_all(8)
 panel.add_theme_stylebox_override("panel",style)
 parent.add_child(panel)
 return panel

static func _text(parent: Control,value: String,rect: Rect2,font_size: int,color: Color) -> Label:
 var line=Label.new()
 line.text=value
 line.position=rect.position
 line.size=rect.size
 line.clip_text=true
 line.add_theme_font_size_override("font_size",font_size)
 line.add_theme_color_override("font_color",color)
 parent.add_child(line)
 return line

static func _card(parent: Control,id: String,rect: Rect2,cache: Dictionary,deck: Dictionary={}):
 var frame=_block(parent,rect,Color("#142737"),Color("#617887"))
 if not Store.CARDS.has(id):
  _text(frame,"未知卡牌\n"+id,Rect2(8,8,rect.size.x-16,rect.size.y-16),20,Color("#e8edf0"))
  return
 if not cache.has(id):
  var source=load(Store.Art.image_path(id,Store.Art.selected(deck,id,Store.CARDS),Store.CARDS)) as Texture2D
  if source==null:return
  var image=source.get_image()
  if image.get_width()>image.get_height():image.rotate_90(CLOCKWISE)
  image.resize(320,448,Image.INTERPOLATE_LANCZOS)
  cache[id]=ImageTexture.create_from_image(image)
 var art=TextureRect.new()
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.texture=cache[id]
 art.position=Vector2(4,4)
 art.size=rect.size-Vector2(8,8)
 frame.add_child(art)
