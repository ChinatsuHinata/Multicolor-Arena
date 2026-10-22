extends RefCounted
## Shared sakura and shrine palette, switchable in desktop and Android settings.
## Interface code still names the classic colors; tint() maps them at the
## shared style helpers, so gameplay highlights (selected, legal, damage) stay unchanged.
static var enabled=true

static func configure(on: bool):
 enabled=on

const SAKURA=Color("#f8c6d5")
const SAKURA_DEEP=Color("#e48aa6")
const VERMILION=Color("#cf4538")
const LACQUER=Color("#24110f")
const SHRINE_GOLD=Color("#e9c175")
const WASHI=Color("#fbf2f0")
const MIST=Color("#e0c9d2")
const NIGHT=Color("#2a1828")
const PLUM_INK=Color("#33202f")
## Battlefield: dusk sky behind the table, and how far the black playmat is lifted.
const FIELD_SKY=Color("#5a3550")
const MAT_LIFT=Color(0.34,0.22,0.29)
const MAT_TINT=Color(1.0,0.96,0.97)
const FIELD_GUIDE=Color(0.98,0.78,0.85,0.55)
const PALETTE_GUIDE=Color(0.93,0.74,0.52,0.55)

const MAP={
 # Panels and backgrounds: dusk plum rather than night.
 "101c28":"33202f","09121d":"26182a","172936":"3f2838","192a38":"43293a",
 "294354":"5e3448","142737":"3a2535","13232f":"36222f","101e2b":"33202f",
 "111d2b":"33202f","24303a":"44323f","27313d":"4a3542",
 "0f1b29":"321f2e","162636":"3d2737","24394a":"553446","172836":"3f2838",
 "111f2b":"33202f","192c3a":"43293a","223b4b":"5e3448","342d21":"8a2a2a",
 # Neutral borders and dividers.
 "2d455a":"6f475b","293c49":"6a4558",
 "30424f":"6a4558","3d5161":"85566c","416078":"95607a","3b5060":"805468",
 "304657":"744a5e","314b5a":"76495d","637a93":"b67d96","486376":"966580",
 "53606d":"86677a","677585":"a08090","8c7242":"c29a55","aaa080":"d6b0bd",
 # Classic gold accents become torii vermilion with shrine-gold trim.
 "3b3325":"8a2a2a","4b4130":"a83430","615135":"c2443a","514328":"a83430",
 # Text.
 "e8c77e":"f8c6d5","d9b775":"f8c6d5","e8edf0":"fbf2f0","b2c2ce":"e0c9d2",
 "081019":"24111d","151a24":"2a1520","f0cf93":"fad0dc",
}

static func tint(color: Color) -> Color:
 if not enabled:return color
 var mapped=MAP.get(color.to_html(false),"")
 if mapped.is_empty():return color
 var result=Color(mapped);result.a=color.a
 return result

## Shrine buttons. A StyleBoxFlat has one border colour, so the thick top edge
## is the beam: plain buttons are lacquered wood framed in vermilion, accent
## buttons are a small torii, a vermilion body under a black kasagi.
static func button_style(state: String,accent: bool=false) -> StyleBoxFlat:
 var s=StyleBoxFlat.new()
 s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=8;s.content_margin_bottom=7
 s.corner_radius_top_left=2;s.corner_radius_top_right=2;s.corner_radius_bottom_left=7;s.corner_radius_bottom_right=7
 s.border_width_left=1;s.border_width_right=1;s.border_width_top=4;s.border_width_bottom=2
 s.shadow_color=Color(0.1,0.03,0.06,0.35);s.shadow_size=3;s.shadow_offset=Vector2(0,2)
 if state=="focus":
  s.draw_center=false;s.border_color=SAKURA;s.set_border_width_all(1);s.shadow_size=0
  return s
 if accent:
  s.border_width_left=2;s.border_width_right=2;s.border_width_top=5
  s.bg_color={"normal":Color("#b8392f"),"hover":Color("#d84a3c"),"pressed":Color("#8e2a24"),"disabled":Color("#6e3a38")}.get(state,Color("#b8392f"))
  s.border_color=LACQUER if state!="disabled" else Color("#4a3030")
 else:
  s.bg_color={"normal":Color("#4d2c38"),"hover":Color("#6a3442"),"pressed":Color("#a3342e"),"disabled":Color("#3e3038")}.get(state,Color("#4d2c38"))
  s.border_color={"normal":Color("#b5473c"),"hover":SHRINE_GOLD,"pressed":SHRINE_GOLD,"disabled":Color("#5e4048")}.get(state,Color("#b5473c"))
 return s

static func dress_button(button: Control,accent: bool=false):
 for state in ["normal","hover","pressed","disabled","focus"]:
  button.add_theme_stylebox_override(state,button_style(state,accent))
 button.add_theme_color_override("font_color",WASHI)
 button.add_theme_color_override("font_hover_color",SHRINE_GOLD if not accent else Color.WHITE)
 button.add_theme_color_override("font_pressed_color",Color.WHITE)
 button.add_theme_color_override("font_disabled_color",Color("#a8949e"))

## Shared theme for built-in controls that do not go through main.style().
static func apply_theme(theme: Theme):
 if not enabled:return
 var flat=func(bg: Color,border: Color,radius: int=8,margin: float=8.0) -> StyleBoxFlat:
  var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(1)
  s.set_corner_radius_all(radius);s.set_content_margin_all(margin);return s
 for state in ["normal","hover","pressed","disabled","focus"]:
  theme.set_stylebox(state,"Button",button_style(state))
 theme.set_color("font_color","Button",WASHI);theme.set_color("font_hover_color","Button",Color.WHITE)
 theme.set_color("font_disabled_color","Button",Color("#a8949e"))
 var field=flat.call(Color("#2e1d2b"),Color("#85566c"))
 var field_focus=flat.call(Color("#3a2434"),SAKURA)
 for type in ["LineEdit","TextEdit"]:
  theme.set_stylebox("normal",type,field);theme.set_stylebox("focus",type,field_focus)
  theme.set_stylebox("read_only",type,flat.call(Color("#2a1b27"),Color("#6a4558")))
  theme.set_color("font_color",type,WASHI);theme.set_color("font_placeholder_color",type,Color("#b49aa8"))
  theme.set_color("caret_color",type,SAKURA);theme.set_color("selection_color",type,Color(0.89,0.54,0.65,0.38))
 for type in ["OptionButton","MenuButton"]:
  for state in ["normal","hover","pressed","disabled","focus"]:
   theme.set_stylebox(state,type,button_style(state))
  theme.set_color("font_color",type,WASHI);theme.set_color("font_hover_color",type,Color.WHITE)
 var popup=flat.call(Color("#3a2434f6"),Color("#b67d96"),8,6)
 theme.set_stylebox("panel","PopupMenu",popup)
 theme.set_stylebox("hover","PopupMenu",flat.call(Color("#a3342e"),Color("#a3342e"),4,4))
 theme.set_color("font_color","PopupMenu",WASHI);theme.set_color("font_hover_color","PopupMenu",Color.WHITE)
 theme.set_stylebox("panel","PopupPanel",popup)
 theme.set_stylebox("panel","TooltipPanel",flat.call(Color("#3a2434f2"),SAKURA_DEEP,6,10))
 theme.set_color("font_color","TooltipLabel",WASHI)
 theme.set_stylebox("panel","AcceptDialog",flat.call(PLUM_INK,Color("#b67d96"),0,14))
 theme.set_stylebox("embedded_border","Window",flat.call(PLUM_INK,VERMILION,8,0))
 theme.set_stylebox("embedded_unfocused_border","Window",flat.call(PLUM_INK,Color("#85566c"),8,0))
 theme.set_color("title_color","Window",SAKURA)
 for type in ["CheckButton","CheckBox"]:
  theme.set_color("font_color",type,WASHI);theme.set_color("font_hover_color",type,SAKURA)
  theme.set_color("font_pressed_color",type,WASHI);theme.set_color("font_hover_pressed_color",type,SAKURA)
 for bar in ["VScrollBar","HScrollBar"]:
  var track=StyleBoxFlat.new();track.bg_color=Color(0.15,0.08,0.13,0.5);track.set_corner_radius_all(4)
  var grab=StyleBoxFlat.new();grab.bg_color=Color("#b67d96");grab.set_corner_radius_all(4)
  var grab_hot=grab.duplicate();grab_hot.bg_color=SAKURA_DEEP
  theme.set_stylebox("scroll",bar,track);theme.set_stylebox("grabber",bar,grab)
  theme.set_stylebox("grabber_highlight",bar,grab_hot);theme.set_stylebox("grabber_pressed",bar,grab_hot)
 theme.set_stylebox("background","ProgressBar",flat.call(Color("#2e1d2b"),Color("#85566c"),6,0))
 theme.set_stylebox("fill","ProgressBar",flat.call(SAKURA_DEEP,SAKURA,6,0))
 theme.set_stylebox("panel","TabContainer",flat.call(PLUM_INK,Color("#85566c"),8,10))
 theme.set_color("font_selected_color","TabBar",SAKURA);theme.set_color("font_unselected_color","TabBar",MIST)
 theme.set_color("font_color","Label",WASHI)
