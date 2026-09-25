extends Panel
## Room chat travels on its own ENet channel and never enters the rules log or replay.
var session
var transcript: RichTextLabel
var entry: LineEdit
var feedback: Label

func build(net,area: Rect2):
 session=net;position=area.position;size=area.size
 var frame=StyleBoxFlat.new();frame.bg_color=Color("#241d32");frame.border_color=Color("#f3d397");frame.set_border_width_all(2);frame.set_corner_radius_all(10)
 add_theme_stylebox_override("panel",frame)
 var title=Label.new();title.text="联机聊天";title.position=Vector2(15,12);title.size=Vector2(area.size.x-70,30);title.add_theme_font_size_override("font_size",21);title.add_theme_color_override("font_color",Color("#f3d397"));add_child(title)
 var close=Button.new();close.text="×";close.position=Vector2(area.size.x-48,8);close.size=Vector2(36,34);close.pressed.connect(func():visible=false);add_child(close)
 transcript=RichTextLabel.new();transcript.position=Vector2(14,50);transcript.size=Vector2(area.size.x-28,area.size.y-133);transcript.scroll_active=true;transcript.selection_enabled=true;transcript.add_theme_font_size_override("normal_font_size",17);add_child(transcript)
 entry=LineEdit.new();entry.position=Vector2(14,area.size.y-70);entry.size=Vector2(area.size.x-108,39);entry.placeholder_text="输入消息（最多 200 字）";entry.max_length=200;add_child(entry)
 entry.text_submitted.connect(func(_value):submit())
 var send=Button.new();send.text="发送";send.position=Vector2(area.size.x-86,area.size.y-70);send.size=Vector2(72,39);send.pressed.connect(submit);add_child(send)
 feedback=Label.new();feedback.position=Vector2(14,area.size.y-30);feedback.size=Vector2(area.size.x-28,24);feedback.add_theme_font_size_override("font_size",14);feedback.add_theme_color_override("font_color",Color("#f6ae91"));add_child(feedback)
 session.chat_received.connect(refresh)
 refresh()

func submit():
 var error=session.send_chat(entry.text)
 if error.is_empty():entry.clear();feedback.text=""
 else:feedback.text=error

func refresh():
 if not is_instance_valid(transcript):return
 transcript.clear()
 for item in session.chat_log:
  transcript.add_text("%s  %s：%s\n" % [str(item.at).substr(11,5),item.name,item.text])
 transcript.scroll_to_line(transcript.get_line_count()-1)
