extends RefCounted
## Android preparation keeps decisions in one column and long room details in
## a separate scrollable column, so names and hints cannot push actions away.
var lobby
var app
var session
var info: VBoxContainer
var actions: VBoxContainer
var footer: VBoxContainer

func text(parent: Node,value: String,heading: bool=false) -> Label:
 var label=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",clampi(app.ui_metrics.body,24,30)+(4 if heading else 0))
 label.add_theme_color_override("font_color",app.GOLD if heading else app.WHITE)
 parent.add_child(label)
 return label

func action(parent: Node,caption: String,callback: Callable,accent: bool=false) -> Button:
 var button=app.button(parent,caption,Rect2(),callback,accent)
 button.add_theme_font_size_override("font_size",clampi(app.ui_metrics.button_font,24,30))
 button.custom_minimum_size=Vector2(0,clampf(app.ui_metrics.hit,64,90))
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 button.tooltip_text=caption
 return button

func panel(parent: Node,node_name: String,with_footer: bool=false) -> VBoxContainer:
 var frame=PanelContainer.new();frame.name=node_name;parent.add_child(frame)
 frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var style=app.ui_metrics.panel_style();style.set_content_margin_all(14)
 frame.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();frame.add_child(column)
 column.add_theme_constant_override("separation",12)
 var scroll=ScrollContainer.new();scroll.name=node_name+"Scroll";column.add_child(scroll)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var content=VBoxContainer.new();content.name=node_name+"Content";scroll.add_child(content)
 content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",12)
 if with_footer:
  footer=VBoxContainer.new();footer.name="PreparationFooter";column.add_child(footer)
 return content

func workspace():
 lobby.body.offset_top=128
 lobby.status_label.hide()
 var row=HBoxContainer.new();row.name="MobilePreparation";lobby.body.add_child(row)
 row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 row.add_theme_constant_override("separation",14)
 info=panel(row,"PreparationInformation")
 (info.get_parent().get_parent().get_parent().get_parent() as Control).size_flags_stretch_ratio=1.15
 actions=panel(row,"PreparationActions",true)
 var leave_caption="离开观战" if session.read_only else "不再等待，离开对局" if session.disconnected_at>0 else "离开房间"
 if session.cloud_ranked and not session.read_only and session.room.status=="complete":leave_caption="返回云端，重新匹配"
 if lobby.can_leave_room():
  var leave=action(footer,leave_caption,leave_room);leave.name="PreparationLeaveRoom"
  leave.disabled=session.cloud_ranked and not session.read_only and session.room.status=="complete" and not session.match_settled

func leave_room():
 if not lobby.can_leave_room():return
 if session.disconnected_at>0:session.stop_waiting()
 else:session.leave(false)
 lobby.refresh(true)

func summary():
 var room=session.room
 text(info,"%s · %d : %d" % [lobby.Series.format_label(int(room.format)),room.scores[0],room.scores[1]],true).name="PreparationScore"
 text(info,"%s / %s" % [lobby.PlayerNameDisplay.caption(room.names[0]),lobby.PlayerNameDisplay.caption(room.names[1])])
 text(info,"规则集："+app.RuleSet.label_for(str(room.get("rule_set",app.RuleSet.UNRESTRICTED)))+(" · 主卡组 50 张" if room.strict else " · 主卡组张数不限"))

func room_details():
 var room=session.room
 if session.cloud_mode:
  text(info,"云端房间："+lobby.PlayerNameDisplay.in_text(session.cloud_room_name,session.cloud_seats+[session.cloud_nickname]))
  text(info,"你的座位：%d 号%s位" % [session.cloud_slot,"观战" if session.read_only else "对战"])
 elif session.is_host:
  var addresses=[]
  for address in IP.get_local_addresses():
   if ":" not in address and not address.begins_with("127."):addresses.append(address+":"+str(session.port))
  text(info,"房主地址："+" / ".join(addresses))
  action(info,"复制房主地址",func():DisplayServer.clipboard_set(" / ".join(addresses)))
 lobby.latency_label=text(info,"网络延迟 · "+session.latency_text())
 if not lobby.last_error.is_empty():text(info,lobby.last_error)
 elif not session.notice.is_empty():text(info,session.notice)
 if not lobby.leader_reveal(room).is_empty():
  text(info,lobby.leader_reveal(room)).name="OpponentLeaderReveal"
  if not session.read_only:app.public_leader_card(info,room,1-session.seat)
 if session.cloud_ranked:
  text(info,session.match_caption())
  text(info,"本场房间："+("公开 · 允许观战" if session.match_room_public else "私人 · 禁止观战"))

func deck_selection(parent: Node):
 var selected=lobby.deck_choice_button(parent)
 compact(selected)
 compact(lobby.register_deck_button(parent))

func compact(button: BaseButton):
 button.add_theme_font_size_override("font_size",clampi(app.ui_metrics.button_font,24,30))
 button.custom_minimum_size=Vector2(0,clampf(app.ui_metrics.hit,64,90))
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func prepare_actions():
 var room=session.room
 text(actions,"对手："+("已准备" if room.ready[1-session.seat] else "未准备"),true)
 if room.status=="lobby":
  if not session.cloud_ranked:deck_selection(actions)
 else:
  text(actions,"赛前换备牌 · 最多换入 3 张" if room.status=="sideboarding" else "第 %d 局准备" % (room.round+1),true)
  var sideboard=action(actions,"调整主副卡组",lobby.open_sideboard);sideboard.name="PreparationSideboard"
  sideboard.disabled=room.ready[session.seat] or not session.can_act()
 if not room.own_deck.is_empty():text(actions,room.own_deck.name+" · %d / %d" % [room.own_deck.main.size(),room.own_deck.side.size()])
 # Ready stays above explanatory text, which can grow for entertainment/mods.
 var ready=action(actions,"取消准备" if room.ready[session.seat] else "准备",func():session.room_action({"name":"unready" if room.ready[session.seat] else "ready"}),true)
 ready.name="PreparationReady";ready.disabled=room.own_deck.is_empty() or not session.can_act()
 text(info,lobby.preparation_hint(room))
 if room.status=="lobby":
  lobby.room_entertainment_selector(info)
  var choice=info.get_node_or_null("RoomEntertainmentMode")
  if choice!=null:compact(choice)

func cloud_seats():
 if session.cloud_ranked:
  text(info,"自动匹配 · 两人对战",true)
  for index in range(2):text(info,"%d 号对战位：%s" % [index+1,lobby.PlayerNameDisplay.caption(session.cloud_seats[index])])
  return
 text(info,"八个座位 · 拖动名称可换位" if session.can_move_cloud_seats() else "房间座位",true)
 var grid=lobby.cloud_seat_grid(info,4)
 grid.name="PreparationSeats"
 for tile in grid.get_children():
  compact(tile)
  tile.custom_minimum_size.y=maxf(86,clampf(app.ui_metrics.hit,64,90))
  tile.add_theme_font_size_override("font_size",clampi(app.ui_metrics.body-4,22,26))
  tile.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  tile.tooltip_text=tile.text+"\n"+tile.tooltip_text
 text(info,"1、2 号对战位都有人后才能开始对局")

func build(owner,cloud_lobby: bool):
 lobby=owner;app=lobby.app;session=lobby.session
 if session.room.is_empty():return
 workspace();summary()
 var room=session.room
 if cloud_lobby:cloud_seats()
 room_details()
 if session.read_only:
  text(actions,"观战中",true)
  text(actions,session.connection_status() if not cloud_lobby else "对局开始后自动进入战场")
  if not session.latest_snapshot.is_empty():action(actions,"查看战场",app.return_network_battle,true)
  if cloud_lobby and not session.cloud_ranked:deck_selection(actions)
  return
 if not session.applicant.is_empty():
  text(actions,lobby.PlayerNameDisplay.caption(session.applicant.name)+" 请求加入",true)
  var row=HBoxContainer.new();actions.add_child(row)
  action(row,"接受",func():session.accept_applicant(true),true)
  action(row,"拒绝",func():session.accept_applicant(false))
 elif room.status=="complete":
  text(actions,"整场结束 · "+lobby.PlayerNameDisplay.caption(room.names[room.winner])+"获胜",true)
  if room.has("end_reason"):text(info,lobby.PlayerNameDisplay.in_text(room.end_reason,room.names))
  if not session.latest_snapshot.is_empty():action(actions,"查看战场",app.return_network_battle)
  if session.cloud_ranked:
   text(actions,"匹配已结算" if session.match_settled else "正在结算 Elo，请稍候")
  else:
   var rematch=action(actions,"更换卡组，再来一场",func():session.room_action({"name":"rematch"}),true)
   rematch.disabled=not session.can_act()
 elif room.status=="aborted":
  text(actions,"连接中断，对局结束 · 不计胜负",true)
  if not session.latest_snapshot.is_empty():action(actions,"查看战场",app.return_network_battle)
 elif room.status=="playing":
  text(actions,"第 %d 局正在进行" % room.round,true)
  action(actions,"回到战场",app.return_network_battle,true)
 elif room.status=="choosing":
  text(actions,"第 %d 局 · 选择先后手" % (room.round+1),true)
  if room.round==0:text(actions,"投骰：%s %d  ·  %s %d" % [lobby.PlayerNameDisplay.caption(room.names[0]),room.roll["values"][0],lobby.PlayerNameDisplay.caption(room.names[1]),room.roll["values"][1]])
  else:text(actions,room.choice_reason)
  if session.seat==room.chooser:
   var first=action(actions,"我方先手",func():session.room_action({"name":"first","first":true}),true)
   var second=action(actions,"我方后手",func():session.room_action({"name":"first","first":false}))
   first.name="PreparationFirst";second.name="PreparationSecond"
   first.disabled=not session.can_act();second.disabled=not session.can_act()
  else:text(actions,"等待 %s 选择先后手" % lobby.PlayerNameDisplay.caption(room.names[room.chooser]))
 elif room.status in ["lobby","sideboarding","between"]:prepare_actions()
 if not session.connected and not session.is_host and not session.ended():
  action(actions,"重连",func():
   var error=session.resume_guest()
   if not error.is_empty():lobby.show_error(error),true)
  if session.wait_choice_pending and not session.ranked_match_pending():action(actions,"继续等待",func():session.continue_waiting(),true)