extends Control
var app
var session
var body: Control
var status_label: Label
var latency_label: Label
var name_input: LineEdit
var address_input: LineEdit
var port_input: SpinBox
var format_input: OptionButton
var interface_input: OptionButton
var strict_input: CheckButton
var rooms_list: VBoxContainer
var signature=""
var side_draft={}
var deck_index=0
func build(parent,net):
 app=parent;session=net;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 session.changed.connect(refresh);session.error_raised.connect(show_error)
 app.header("局域网联机",func():session.leave(false);app.menu())
 status_label=app.label(self,"",Rect2(70,118,1460,65),20,app.GOLD);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 body=Control.new();add_child(body);refresh(true)
func show_error(message: String):status_label.text=message
func _process(_delta):
 if is_instance_valid(latency_label):latency_label.text="网络延迟 · "+session.latency_text()
func refresh(force: bool=false):
 status_label.text=session.notice if not session.notice.is_empty() else session.discovery.error
 var next=JSON.stringify([session.room_id,session.room,session.applicant,session.connected,session.paused])
 if force or next!=signature:
  signature=next
  for child in body.get_children():body.remove_child(child);child.queue_free()
  if session.room_id.is_empty():build_home()
  else:build_room()
 refresh_rooms()
func input(text: String,rect: Rect2) -> LineEdit:
 var edit=LineEdit.new();edit.position=rect.position;edit.size=rect.size;edit.text=text;body.add_child(edit);return edit
func build_home():
 app.box(body,Rect2(70,190,500,620));app.box(body,Rect2(600,190,930,620))
 app.label(body,"显示 ID",Rect2(100,210,120,35),21)
 name_input=input(session.identity.nickname,Rect2(230,208,302,44));name_input.max_length=20
 app.label(body,"对局形式",Rect2(100,280,120,40),21)
 format_input=OptionButton.new();format_input.position=Vector2(230,279);format_input.size=Vector2(302,43);format_input.add_item("BO3 · 先赢两局");format_input.add_item("BO1 · 单局");body.add_child(format_input)
 strict_input=CheckButton.new();strict_input.text="检查卡组";strict_input.position=Vector2(95,341);strict_input.size=Vector2(440,45);strict_input.button_pressed=true;body.add_child(strict_input)
 app.label(body,"端口",Rect2(100,403,120,42),21)
 port_input=SpinBox.new();port_input.min_value=1024;port_input.max_value=65535;port_input.value=47861;port_input.position=Vector2(230,402);port_input.size=Vector2(302,42);body.add_child(port_input)
 interface_input=OptionButton.new();interface_input.position=Vector2(100,466);interface_input.size=Vector2(432,43);interface_input.add_item("所有网卡");interface_input.set_item_metadata(0,"*")
 for address in IP.get_local_addresses():
  if address.is_valid_ip_address() and ":" not in address and not address.begins_with("127."):
   interface_input.add_item(address);interface_input.set_item_metadata(interface_input.item_count-1,address)
 body.add_child(interface_input)
 app.button(body,"创建房间",Rect2(100,540,432,54),func():
  session.set_display_name(name_input.text)
  var error=session.create_room(3 if format_input.selected==0 else 1,strict_input.button_pressed,int(port_input.value),interface_input.get_selected_metadata())
  if not error.is_empty():show_error(error),true)
 app.button(body,"恢复房主对局",Rect2(100,626,432,49),func():
  var error=session.restore_host()
  if not error.is_empty():show_error(error))
 app.button(body,"重连上次房间",Rect2(100,693,432,49),func():
  session.set_display_name(name_input.text)
  var error=session.resume_guest(address_input.text)
  if not error.is_empty():show_error(error))
 app.label(body,"发现的房间",Rect2(625,208,500,43),25,app.GOLD)
 var scroll=ScrollContainer.new();scroll.position=Vector2(625,264);scroll.size=Vector2(877,350);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 rooms_list=VBoxContainer.new();rooms_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rooms_list.add_theme_constant_override("separation",12);scroll.add_child(rooms_list)
 app.label(body,"输入地址加入",Rect2(625,638,210,40),21)
 address_input=input("",Rect2(625,690,620,49));address_input.placeholder_text="房主的局域网或虚拟局域网 IP"
 app.button(body,"加入",Rect2(1265,690,235,49),func():join(address_input.text,int(port_input.value)),true)
 app.label(body,"首次联网请允许 Windows 的专用网络访问。",Rect2(625,753,855,38),17,app.MUTED)
func join(address: String,port: int):
 session.set_display_name(name_input.text)
 var error=session.join_room(address,port)
 if not error.is_empty():show_error(error)
func refresh_rooms():
 if not is_instance_valid(rooms_list):return
 for child in rooms_list.get_children():rooms_list.remove_child(child);child.queue_free()
 for id in session.discovery.rooms:
  var info=session.discovery.rooms[id]
  var row=Button.new();row.custom_minimum_size=Vector2(850,68);rooms_list.add_child(row)
  row.text="%s · BO%d · %d/2    %s:%d" % [info.name,info.format,info.players,info.address,info.port]
  if info.version!=session.fingerprint:row.text+=" · 版本不一致";row.disabled=true
  row.pressed.connect(func():join(info.address,int(info.port)))
 if rooms_list.get_child_count()==0:
  var label=Label.new();label.text="正在查找同一局域网内的房间…";label.custom_minimum_size=Vector2(800,58);rooms_list.add_child(label)
func build_room():
 rooms_list=null
 var room=session.room
 if room.is_empty():return
 latency_label=app.label(body,"网络延迟 · "+session.latency_text(),Rect2(103,642,890,45),20,app.MUTED)
 latency_label.tooltip_text="双方各自测到对端的往返延迟（RTT），约每2秒更新；不需要同步电脑时钟。"
 var own=session.seat;var other=1-own
 app.box(body,Rect2(70,195,1460,604))
 app.label(body,"BO%d    %s  %d : %d  %s" % [room.format,room.names[0],room.scores[0],room.scores[1],room.names[1]],Rect2(100,210,1320,46),27,app.GOLD)
 app.label(body,"检查卡组" if room.strict else "不检查卡组",Rect2(105,265,300,34),20)
 if session.is_host:
  var addresses=[]
  for ip in IP.get_local_addresses():
   if ":" not in ip and not ip.begins_with("127."):addresses.append(ip+":"+str(session.port))
  app.label(body,"房间地址："+" / ".join(addresses),Rect2(420,265,1000,36),18,app.MUTED)
  app.button(body,"复制地址",Rect2(1260,311,220,42),func():DisplayServer.clipboard_set(" / ".join(addresses)))
 if not session.applicant.is_empty():
  app.label(body,session.applicant.name+" 请求加入",Rect2(105,365,810,44),23)
  app.button(body,"接受",Rect2(950,365,235,48),func():session.accept_applicant(true),true)
  app.button(body,"拒绝",Rect2(1205,365,235,48),func():session.accept_applicant(false))
 elif room.status=="complete":
  app.label(body,"整场结束 · "+room.names[room.winner]+"获胜",Rect2(100,382,1180,70),31,app.GOLD)
 elif room.status=="playing":
  app.label(body,"第 %d 局正在进行" % room.round,Rect2(105,370,1000,45),25)
  app.button(body,"回到战场",Rect2(1070,415,355,60),func():app.return_network_battle(),true)
 elif room.status in ["lobby","between"]:
  app.label(body,"对手："+("已准备" if room.ready[other] else "未准备"),Rect2(105,312,620,42),21)
  if room.status=="lobby":
   var pick=OptionButton.new();pick.position=Vector2(105,395);pick.size=Vector2(665,51);body.add_child(pick)
   for deck in app.decks:pick.add_item(deck.name)
   deck_index=clampi(deck_index,0,maxi(0,app.decks.size()-1));pick.selected=deck_index
   pick.item_selected.connect(func(index):deck_index=index)
   app.button(body,"选择此卡组",Rect2(800,395,270,51),func():
    if not app.decks.is_empty():session.room_action({"name":"deck","deck":app.decks[deck_index]}))
  else:
   app.button(body,"调整主副卡组",Rect2(105,395,665,51),open_sideboard)
   app.label(body,"第 %d 局准备" % (room.round+1),Rect2(800,395,500,51),25,app.GOLD)
  if not room.own_deck.is_empty():
   app.label(body,room.own_deck.name+" · 主卡组 %d / 副卡组 %d" % [room.own_deck.main.size(),room.own_deck.side.size()],Rect2(105,468,1030,46),22,app.GOLD)
  app.label(body,"双方准备后投硬币决定先后手",Rect2(105,552,900,45),22)
  var ready=app.button(body,"已准备" if room.ready[own] else "准备",Rect2(1070,550,355,60),func():session.room_action({"name":"ready"}),true)
  ready.disabled=room.ready[own] or room.own_deck.is_empty() or not session.can_act()
 if not session.connected and not session.is_host:
  app.button(body,"重连",Rect2(1070,650,355,52),func():
   var error=session.resume_guest()
   if not error.is_empty():show_error(error),true)
 app.button(body,"离开房间",Rect2(1070,714,355,48),func():session.leave(false);refresh(true))
func open_sideboard():
 side_draft=session.room.own_deck.duplicate(true);draw_sideboard()
func draw_sideboard():
 for child in body.get_children():body.remove_child(child);child.queue_free()
 var pool=side_draft.main+side_draft.side;var ids=[]
 for id in pool:
  if id not in ids:ids.append(id)
 ids.sort_custom(func(a,b):return app.Store.CARDS[a].name<app.Store.CARDS[b].name)
 app.box(body,Rect2(70,190,1460,610))
 app.label(body,"换备牌 · 主卡组 %d / 副卡组 %d" % [side_draft.main.size(),side_draft.side.size()],Rect2(105,207,1250,48),26,app.GOLD)
 var scroll=ScrollContainer.new();scroll.position=Vector2(102,280);scroll.size=Vector2(1365,410);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 var rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
 for id in ids:
  var row=HBoxContainer.new();row.custom_minimum_size=Vector2(1300,48);rows.add_child(row)
  var title=Label.new();title.text=app.Store.CARDS[id].name;title.custom_minimum_size=Vector2(770,45);row.add_child(title)
  for zone in ["main","side"]:
   var button=Button.new();button.text=("主 → 副 " if zone=="main" else "副 → 主 ")+str(side_draft[zone].count(id));button.custom_minimum_size=Vector2(240,45);row.add_child(button)
   button.disabled=side_draft[zone].count(id)==0
   button.pressed.connect(func():side_draft[zone].erase(id);side_draft["side" if zone=="main" else "main"].append(id);draw_sideboard())
 app.button(body,"保存换牌",Rect2(1140,719,315,51),func():session.room_action({"name":"deck","deck":side_draft});refresh(true),true)
 app.button(body,"取消",Rect2(805,719,315,51),func():refresh(true))
