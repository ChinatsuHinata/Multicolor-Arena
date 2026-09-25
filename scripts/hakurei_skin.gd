extends RefCounted

const ROOT := "res://assets/hakurei_sunset/"
const CREAM := Color("#f9e9d0")
const GOLD := Color("#f2ca8b")

static func texture(name: String) -> Texture2D:
 return load(ROOT + name + ".png") as Texture2D

static func frame(name: String, corner_x: float = 66.0, corner_y: float = 18.0) -> StyleBoxTexture:
 var box := StyleBoxTexture.new()
 box.texture = texture(name)
 box.texture_margin_left = corner_x
 box.texture_margin_right = corner_x
 box.texture_margin_top = corner_y
 box.texture_margin_bottom = corner_y
 box.content_margin_left = 14.0
 box.content_margin_right = 14.0
 box.content_margin_top = 7.0
 box.content_margin_bottom = 7.0
 return box

static func large_button_frame(state: String, accent: bool = false) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color = Color("#c89258") if accent else Color("#2b253b")
 if state == "hover": box.bg_color = Color("#e0ac6e") if accent else Color("#43314b")
 if state == "pressed": box.bg_color = Color("#aa7448") if accent else Color("#392a40")
 box.border_color = Color("#f7d59c") if accent else Color("#b88975")
 box.set_border_width_all(2)
 box.set_corner_radius_all(8)
 box.shadow_color = Color(0.09, 0.04, 0.1, 0.46)
 box.shadow_size = 5
 box.content_margin_left = 18.0
 box.content_margin_right = 18.0
 box.content_margin_top = 8.0
 box.content_margin_bottom = 8.0
 return box

static func compact_frame(state: String, accent: bool = false) -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color = Color("#7d4345") if accent else Color("#2b243a")
 if state == "hover": box.bg_color = Color("#9c5050") if accent else Color("#44314b")
 if state == "pressed": box.bg_color = Color("#703542") if accent else Color("#35233c")
 box.border_color = Color("#f0c88b") if accent or state == "hover" else Color("#a47877")
 box.set_border_width_all(2)
 box.set_corner_radius_all(5)
 box.content_margin_left = 8.0
 box.content_margin_right = 8.0
 box.content_margin_top = 3.0
 box.content_margin_bottom = 3.0
 return box

static func apply_theme(theme: Theme) -> void:
 theme.set_color("font_color", "Label", CREAM)
 theme.set_color("font_color", "Button", CREAM)
 theme.set_color("font_hover_color", "Button", GOLD)
 theme.set_color("font_pressed_color", "Button", CREAM)
 theme.set_color("font_color", "OptionButton", CREAM)
 theme.set_color("font_hover_color", "OptionButton", GOLD)
 theme.set_color("font_color", "LineEdit", CREAM)
 theme.set_color("font_placeholder_color", "LineEdit", Color("#b8a8b7"))
 theme.set_color("font_color", "CheckButton", CREAM)
 theme.set_color("font_color", "PopupMenu", CREAM)
 for kind in ["Button", "OptionButton"]:
  for state in ["normal", "hover", "pressed", "disabled"]:
   theme.set_stylebox(state, kind, large_button_frame(state) if kind == "Button" else compact_frame(state))
  theme.set_stylebox("focus", kind, StyleBoxEmpty.new())
 theme.set_stylebox("normal", "LineEdit", compact_frame("normal"))
 theme.set_stylebox("focus", "LineEdit", compact_frame("hover"))
 theme.set_stylebox("panel", "PopupMenu", frame("panel", 68.0, 68.0))
 theme.set_stylebox("panel", "AcceptDialog", frame("panel", 68.0, 68.0))
