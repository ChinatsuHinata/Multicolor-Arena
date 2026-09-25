extends SceneTree

# Trim transparent padding and create compact nine-slice textures from the
# original GPT-generated source images in assets/hakurei_sunset/.
const ROOT := "res://assets/hakurei_sunset/"

func _initialize() -> void:
 _prepare("source_button", "button", Vector2i(768, 112))
 _prepare("source_button_accent", "button_accent", Vector2i(768, 112))
 _prepare("source_panel", "panel", Vector2i(512, 512))
 _variant("button", "button_hover", Color(1.17, 1.10, 1.12))
 _variant("button", "button_pressed", Color(0.84, 0.76, 0.78))
 _variant("button_accent", "button_accent_hover", Color(1.08, 1.06, 0.98))
 quit()

func _prepare(source: String, target: String, output_size: Vector2i) -> void:
 var image := Image.load_from_file(ROOT + source + ".png")
 image.convert(Image.FORMAT_RGBA8)
 var min_x := image.get_width()
 var min_y := image.get_height()
 var max_x := -1
 var max_y := -1
 for y in range(image.get_height()):
  for x in range(image.get_width()):
   if image.get_pixel(x, y).a < 0.025: continue
   min_x = mini(min_x, x)
   min_y = mini(min_y, y)
   max_x = maxi(max_x, x)
   max_y = maxi(max_y, y)
 if max_x < 0:
  push_error("Image has no alpha content: " + source)
  return
 var crop := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
 image = image.get_region(crop)
 image.resize(output_size.x, output_size.y, Image.INTERPOLATE_LANCZOS)
 image.save_png(ROOT + target + ".png")

func _variant(source: String, target: String, tint: Color) -> void:
 var image := Image.load_from_file(ROOT + source + ".png")
 image.convert(Image.FORMAT_RGBA8)
 for y in range(image.get_height()):
  for x in range(image.get_width()):
   var p := image.get_pixel(x, y)
   if p.a == 0.0: continue
   image.set_pixel(x, y, Color(clampf(p.r * tint.r, 0.0, 1.0), clampf(p.g * tint.g, 0.0, 1.0), clampf(p.b * tint.b, 0.0, 1.0), p.a))
 image.save_png(ROOT + target + ".png")
