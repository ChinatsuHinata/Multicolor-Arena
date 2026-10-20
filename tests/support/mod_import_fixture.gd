extends RefCounted

static func files() -> Dictionary:
 var source="res://tests/support/mod_second"
 var result={}
 for name in ["manifest.json","draw.json","draw.gd","leader_draw.gd","hand_draw.gd"]:
  result[name]=FileAccess.get_file_as_bytes(source.path_join(name))
 var card=JSON.parse_string(result["draw.json"].get_string_from_utf8())
 card["图片"]="art/card.png";result["draw.json"]=JSON.stringify(card).to_utf8_buffer()
 var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.CORNFLOWER_BLUE)
 result["art/card.png"]=image.save_png_to_buffer()
 return result

static func package(path: String,contents: Dictionary,prefix: String="") -> String:
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var zip=ZIPPacker.new()
 if zip.open(path)!=OK:return ""
 for name in contents:
  zip.start_file(prefix+name)
  zip.write_file(contents[name] if contents[name] is PackedByteArray else str(contents[name]).to_utf8_buffer())
  zip.close_file()
 zip.close()
 return path

static func change(contents: Dictionary,file: String,key: String,value: Variant) -> Dictionary:
 var result=contents.duplicate(true)
 var data=JSON.parse_string(result[file].get_string_from_utf8());data[key]=value
 result[file]=JSON.stringify(data).to_utf8_buffer()
 return result
