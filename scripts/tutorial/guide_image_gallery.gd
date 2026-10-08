extends Control
## Ordered card art and custom images share natural proportions in every layout.
const Images=preload("res://scripts/tutorial/guide_image.gd")
const ImageView=preload("res://scripts/tutorial/guide_image_view.gd")
var preview_root: Control
var host
var configuration={"layout":"row","columns":2,"items":[]}
var pictures: Array=[]
var height_limit=180.0
var gap=8.0
var texture: Texture2D:
 get:return pictures[0].texture if not pictures.is_empty() else null
var overlay: Control:
 get:
  for picture in pictures:
   if is_instance_valid(picture.overlay):return picture.overlay
  return null

func configure(owner_control: Control,app):
 preview_root=owner_control;host=app;size_flags_horizontal=Control.SIZE_EXPAND_FILL;mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(refresh_layout)

func set_data(value: Dictionary):
 clear();configuration=Images.normalize(value)
 for item in configuration.items:
  var image=Images.item_texture(item,host)
  if image==null:continue
  var picture=ImageView.new();picture.name="GuideImageItem"+str(pictures.size());add_child(picture)
  picture.configure(preview_root,host,image);picture.tooltip_text=Images.caption(item,host.Store.CARDS)+"\n点击放大配图"
  pictures.append(picture)
 visible=not pictures.is_empty();refresh_layout()

func clear():
 close_preview()
 for picture in pictures:remove_child(picture);picture.queue_free()
 pictures=[];custom_minimum_size.y=0

func open_preview():
 if not pictures.is_empty():pictures[0].open_preview()

func close_preview():
 for picture in pictures:picture.close_preview()

func set_height_limit(value: float):
 if absf(height_limit-value)<0.5:return
 height_limit=maxf(32,value);refresh_layout()

func refresh_layout():
 if pictures.is_empty():return
 var width=maxf(1,size.x);var count=pictures.size();var total_height=0.0
 var layout=configuration.layout
 if layout=="row":
  var aspect_sum=0.0
  for picture in pictures:aspect_sum+=picture.texture.get_width()/float(picture.texture.get_height())
  var height=minf(height_limit,maxf(1,(width-gap*(count-1))/aspect_sum))
  var x=maxf(0,(width-height*aspect_sum-gap*(count-1))*0.5)
  for picture in pictures:
   var extent=Vector2(height*picture.texture.get_width()/picture.texture.get_height(),height)
   picture.position=Vector2(x,0);picture.size=extent;x+=extent.x+gap
  total_height=height
 elif layout=="column":
  for picture in pictures:
   var aspect=picture.texture.get_width()/float(picture.texture.get_height())
   var height=minf(height_limit,width/aspect);var extent=Vector2(height*aspect,height)
   picture.position=Vector2((width-extent.x)*0.5,total_height);picture.size=extent;total_height+=height+gap
  total_height-=gap
 else:
  var columns=mini(count,int(configuration.columns));var cell_width=maxf(1,(width-gap*(columns-1))/columns)
  var row_height=minf(height_limit,cell_width*1.4)
  for i in range(count):
   var picture=pictures[i];var aspect=picture.texture.get_width()/float(picture.texture.get_height())
   var height=minf(row_height,cell_width/aspect);var extent=Vector2(height*aspect,height)
   picture.position=Vector2((i%columns)*(cell_width+gap)+(cell_width-extent.x)*0.5,floori(float(i)/columns)*(row_height+gap)+(row_height-height)*0.5)
   picture.size=extent
  total_height=ceili(float(count)/columns)*(row_height+gap)-gap
 if absf(custom_minimum_size.y-total_height)>0.5:custom_minimum_size.y=total_height
