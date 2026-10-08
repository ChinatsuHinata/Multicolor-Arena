extends RefCounted
## Portable node illustrations: normalized PNG bytes travel with the course JSON.
const MAX_FILE_BYTES=32*1024*1024
const MAX_PNG_BYTES=16*1024*1024
const MAX_EDGE=2048
const EXTENSIONS=["png","jpg","jpeg","webp"]
const MAX_ITEMS=12
const CardArt=preload("res://scripts/card_art.gd")

static func normalize(value: Dictionary) -> Dictionary:
 if value.has("png_base64"):return {"layout":"row","columns":2,"items":[value.duplicate(true)]}
 return {"layout":value.get("layout","row"),"columns":int(value.get("columns",2)),"items":value.get("items",[]).duplicate(true)}

static func validate(value: Variant,cards: Dictionary) -> String:
 if not value is Dictionary:return "配图必须是对象。"
 if value.has("png_base64"):return read(value).error
 for key in value:
  if key not in ["layout","columns","items"]:return "配图包含不支持的字段："+str(key)
 if value.get("layout","row") not in ["row","column","grid"]:return "配图排列仅支持 row、column、grid。"
 var columns=value.get("columns",2)
 if not (columns is int or columns is float) or not is_finite(float(columns)) or float(columns)!=floor(float(columns)) or columns<1 or columns>4:return "网格列数须为 1 至 4 的整数。"
 var items=value.get("items")
 if not items is Array or items.is_empty() or items.size()>MAX_ITEMS:return "请指定 1 至 %d 张配图。" % MAX_ITEMS
 for i in range(items.size()):
  var item=items[i];var reason=""
  if not item is Dictionary:return "第 %d 张配图必须是对象。" % (i+1)
  if item.has("card_id"):
   for key in item:
    if key not in ["card_id","art_id"]:return "第 %d 张卡图包含不支持的字段：%s" % [i+1,key]
   if not item.card_id is String or not cards.has(item.card_id):reason="卡牌编号不存在。"
   elif item.has("art_id") and (not item.art_id is String or (not item.art_id.is_empty() and not CardArt.valid(item.card_id,item.art_id,cards))):reason="指定的卡图版本不存在。"
  else:reason=read(item).error
  if not reason.is_empty():return "第 %d 张配图：%s" % [i+1,reason]
 return ""

static func caption(item: Dictionary,cards: Dictionary) -> String:
 if item.has("card_id"):
  var id=item.card_id;var info=cards.get(id,{})
  var variant="默认卡面"
  for art in CardArt.options(id,cards):
   if art.id==item.get("art_id",""):variant=art.label
  var horizontal=info.get("landscape",info.get("kind","") in ["符卡","结界"])
  return "%s · #%s · %s · %s" % [info.get("name",id),id,"横卡" if horizontal else "竖卡",variant]
 return "自定义图片 · "+item.get("name","已导入图片")

static func item_texture(item: Dictionary,host) -> Texture2D:
 if item.has("card_id"):return host.preview_texture(item.card_id,item.get("art_id",""))
 return texture(item)

static func import_file(path: String) -> Dictionary:
 if path.get_extension().to_lower() not in EXTENSIONS:return {"error":"请选择 PNG、JPG 或 WebP 图片。"}
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"error":"无法读取图片："+error_string(FileAccess.get_open_error())}
 var length=file.get_length();file.close()
 if length==0 or length>MAX_FILE_BYTES:return {"error":"图片文件须非空且不超过 32 MB。"}
 var image=Image.new()
 if image.load(path)!=OK or image.is_empty():return {"error":"无法打开此图片，请检查文件是否损坏。"}
 var longest=maxi(image.get_width(),image.get_height())
 if longest>MAX_EDGE:
  image.resize(maxi(1,roundi(float(image.get_width())*MAX_EDGE/longest)),maxi(1,roundi(float(image.get_height())*MAX_EDGE/longest)),Image.INTERPOLATE_LANCZOS)
 image.convert(Image.FORMAT_RGBA8)
 var bytes=image.save_png_to_buffer()
 if bytes.is_empty() or bytes.size()>MAX_PNG_BYTES:return {"error":"配图过大，请缩小图片后重试。"}
 return {"error":"","data":{"png_base64":Marshalls.raw_to_base64(bytes)}}

static func read(value: Variant) -> Dictionary:
 if not value is Dictionary or not value.has("png_base64"):
  return {"error":"自定义配图须包含 png_base64。"}
 for key in value:
  if key not in ["png_base64","name"]:return {"error":"自定义配图包含不支持的字段："+str(key)}
 if value.has("name") and (not value.name is String or value.name.is_empty() or value.name.length()>256):return {"error":"自定义图片名称须为 1 至 256 字符。"}
 var encoded=value.png_base64
 if not encoded is String or encoded.is_empty():return {"error":"png_base64 必须是非空字符串。"}
 if encoded.length()>ceili(float(MAX_PNG_BYTES)/3)*4:return {"error":"配图 PNG 不得超过 16 MB。"}
 if encoded.length()%4!=0 or RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$").search(encoded)==null:
  return {"error":"配图不是有效的 Base64 编码。"}
 var bytes=Marshalls.base64_to_raw(encoded)
 if bytes.size()<33 or bytes.size()>MAX_PNG_BYTES or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or bytes.slice(12,16).get_string_from_ascii()!="IHDR":
  return {"error":"配图必须是有效的 PNG 图片。"}
 var width=png_integer(bytes,16);var height=png_integer(bytes,20)
 if width<1 or height<1 or width>MAX_EDGE or height>MAX_EDGE:return {"error":"配图尺寸须在 1 至 2048 像素之间。"}
 var image=Image.new()
 if image.load_png_from_buffer(bytes)!=OK or image.is_empty():return {"error":"配图 PNG 已损坏，无法读取。"}
 return {"error":"","image":image}

static func png_integer(bytes: PackedByteArray,offset: int) -> int:
 return (int(bytes[offset])<<24)|(int(bytes[offset+1])<<16)|(int(bytes[offset+2])<<8)|int(bytes[offset+3])

static func texture(value: Variant) -> Texture2D:
 var result=read(value)
 return ImageTexture.create_from_image(result.image) if result.error.is_empty() else null
