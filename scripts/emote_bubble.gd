extends Control
## Literal text speech bubble, with an optional subtle effect on the second speaker.
const Palette=preload("res://scripts/ui_palette.gd")
const ReplyEffect=preload("res://scripts/emote_text_effect.gd")
const TAIL=14.0
var kind="greeting"
var points_down=true
var tip_x=-1.0
var message=""
var text_label: RichTextLabel
var distort_reply=false
var red_reply=false

func _init():
 name="LeaderEmoteBubble"
 size=Vector2(280,80)
 mouse_filter=Control.MOUSE_FILTER_IGNORE

func _ready():
 ensure_labels();layout_labels();queue_redraw()

func ensure_labels():
 if is_instance_valid(text_label):return
 text_label=RichTextLabel.new();text_label.name="EmoteText";text_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 text_label.bbcode_enabled=false;text_label.scroll_active=false;text_label.focus_mode=Control.FOCUS_NONE
 text_label.clip_contents=false
 text_label.add_theme_color_override("default_color",Color("#33202f"));text_label.add_theme_font_size_override("normal_font_size",20)
 text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 add_child(text_label)

func configure(text: String,emote_kind: String,down: bool=true,animated_reply: bool=false):
 message=text;kind=emote_kind;points_down=down
 ensure_labels()
 distort_reply=animated_reply and message.contains("\n")
 red_reply=distort_reply and kind=="threat"
 text_label.text=message
 if distort_reply:
  text_label.clear()
  var reply_start=message.find("\n")+1
  text_label.add_text(message.substr(0,reply_start))
  text_label.push_customfx(ReplyEffect.new(),{})
  if red_reply:text_label.push_color(Color("#c52c45"))
  text_label.add_text(message.substr(reply_start))
  if red_reply:text_label.pop()
  text_label.pop()
 # Profile lines can be longer than the default greeting. Measure with the
 # actual inherited font before positioning the bubble so text stays inside it.
 var font_size=20
 text_label.size.x=maxf(80,size.x-36)
 text_label.add_theme_font_size_override("normal_font_size",font_size)
 var needed=text_label.get_content_height()
 while needed>212 and font_size>14:
  font_size-=1
  text_label.add_theme_font_size_override("normal_font_size",font_size)
  needed=text_label.get_content_height()
 size.y=maxf(size.y,ceilf(needed)+38)
 layout_labels();queue_redraw()

func set_tip_x(value: float):
 tip_x=value;queue_redraw()

func body_rect() -> Rect2:
 return Rect2(2,2 if points_down else TAIL, maxf(0,size.x-4),maxf(0,size.y-TAIL-4))

func layout_labels():
 if not is_instance_valid(text_label):return
 var body=body_rect()
 text_label.position=body.position+Vector2(16,10)
 text_label.size=Vector2(maxf(0,body.size.x-32),maxf(0,body.size.y-20))

func _notification(what):
 if what==NOTIFICATION_RESIZED:layout_labels();queue_redraw()

func _draw():
 var body=body_rect()
 if body.size.x<30 or body.size.y<20:return
 var fill=Color("#fff6ee") if Palette.enabled else Color("#f3f1e9")
 var border=Color("#d7a0b4") if Palette.enabled else Color("#b8ab86")
 var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border;style.set_border_width_all(2);style.set_corner_radius_all(14)
 style.shadow_color=Color(0.08,0.03,0.07,0.25);style.shadow_size=4;style.shadow_offset=Vector2(0,2)
 draw_style_box(style,body)
 var x=clampf(size.x*0.5 if tip_x<0 else tip_x,body.position.x+22,body.end.x-22)
 var edge=body.end.y-1 if points_down else body.position.y+1
 var tip=Vector2(x,size.y-2 if points_down else 1)
 var tail=PackedVector2Array([Vector2(x-12,edge),tip,Vector2(x+12,edge)])
 draw_colored_polygon(tail,fill);draw_polyline(tail,border,2.0,true)
