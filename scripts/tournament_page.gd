extends Control
const Client=preload("res://scripts/tournament_client.gd")
const Series=preload("res://net/series_controller.gd")
const PlayerNameDisplay=preload("res://scripts/player_name_display.gd")
const PHASES={"registration":"报名中", "checkin":"比赛签到中", "locked":"等待首轮", "running":"比赛进行中", "complete":"比赛已结束"}
const FORMATS={"swiss":"瑞士轮", "swiss_top2":"瑞士轮 + 2 强淘汰赛", "swiss_top4":"瑞士轮 + 4 强淘汰赛", "swiss_top8":"瑞士轮 + 8 强淘汰赛", "swiss_top16":"瑞士轮 + 16 强淘汰赛"}
const KNOCKOUT_ROUNDS={"swiss_top2":1,"swiss_top4":2,"swiss_top8":3,"swiss_top16":4}
const STAGES={"swiss":"瑞士轮", "round_of_16":"十六强赛", "quarterfinal":"四分之一决赛", "semifinal":"半决赛", "final":"决赛"}
const TASKS={"open_checkin":"开启签到", "close_checkin":"结束签到", "start_round":"推进下一轮"}
var app
var mode="list"
var busy=false
var can_create=false
var client
var tournaments: Array=[]
var current: Dictionary={}
var members: Array=[]
var page_index=0
var pages=1
var member_page=0
var member_pages=1
var roster_only=false
var margin: MarginContainer
var heading: Label
var notice: Label
var body: VBoxContainer
var create_button: Button
var refresh_button: Button
var back_button: Button
var title_input: LineEdit
var description_input: TextEdit
var submit_button: Button
var format_input: OptionButton
var game_format_input: OptionButton
var start_time_input: LineEdit
var rounds_input: SpinBox
var interval_input: SpinBox
var task_input: OptionButton
var time_input: LineEdit
var result_input: OptionButton
var result_pairing: Dictionary={}
var my_pairing: Dictionary={}
var pairings: Array=[]
var standings: Array=[]
var schedules: Array=[]
var detail_tab="group"
var pairing_page=0
var pairing_pages=1
var standing_page=0
var standing_pages=1
var silent_request=false
var retained_scroll=0

func expand(control: Control,vertical: bool=false):
 control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if vertical:control.size_flags_vertical=Control.SIZE_EXPAND_FILL

func text(parent: Node,value: String,font: int=0,color: Color=Color("#e8edf0")) -> Label:
 var result=Label.new();parent.add_child(result);result.text=value;expand(result)
 result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 result.add_theme_color_override("font_color",color)
 if font>0:result.add_theme_font_size_override("font_size",font)
 return result

func action(parent: Node,caption: String,callback: Callable,accent: bool=false,node_name: String="") -> Button:
 var result=app.button(parent,caption,Rect2(),callback,accent)
 app.ui_metrics.button(result)
 if not node_name.is_empty():result.name=node_name
 return result

func _ready():
 name="TournamentPage";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var root=VBoxContainer.new();margin.add_child(root)
 root.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var header=HBoxContainer.new();root.add_child(header)
 heading=text(header,"比赛",app.ui_metrics.title,app.GOLD)
 create_button=action(header,"创建比赛",show_create,false,"TournamentCreate");create_button.hide()
 refresh_button=action(header,"刷新",refresh,false,"TournamentRefresh")
 back_button=action(header,"返回主菜单",go_back,false,"TournamentBack")
 notice=text(root,"正在加载比赛群组…",app.ui_metrics.small,app.MUTED);notice.name="TournamentNotice"
 body=VBoxContainer.new();root.add_child(body);expand(body,true)
 relayout();call_deferred("fetch_list",0)
 var timer=Timer.new();add_child(timer);timer.wait_time=5.0
 timer.timeout.connect(func():
  if mode!="detail" or busy or app.menu_popup_open():return
  if app.get_children().any(func(node):return node is Window and node.visible):return
  silent_request=true;fetch_detail(int(current.id)))
 timer.start()

func relayout():
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 for control in find_children("*","Button",true,false):app.ui_metrics.button(control)
 heading.add_theme_font_size_override("font_size",app.ui_metrics.title)
 notice.add_theme_font_size_override("font_size",app.ui_metrics.small)

func clear_body():
 app.free_children(body);title_input=null;description_input=null;submit_button=null
 create_button.visible=can_create and mode=="list"
 refresh_button.visible=mode in ["list","detail"]
 back_button.text="主菜单" if mode=="list" else "返回列表"
 app.ui_metrics.button(back_button)

func scroll_body(node_name: String) -> VBoxContainer:
 var scroll=ScrollContainer.new();scroll.name=node_name;body.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
 scroll.set_meta("android_swipe_prefer_vertical",true)
 var column=VBoxContainer.new();scroll.add_child(column);expand(column)
 column.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 return column

func pagination(parent: Node,index: int,total: int,previous: Callable,next: Callable):
 if total<=1:return
 var row=HBoxContainer.new();parent.add_child(row)
 var before=action(row,"上一页",previous);before.disabled=index<=0;before.set_meta("page_disabled",index<=0)
 var count=text(row,"第 %d / %d 页" % [index+1,total],app.ui_metrics.small);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var after=action(row,"下一页",next);after.disabled=index>=total-1;after.set_meta("page_disabled",index>=total-1)

func show_list():
 mode="list";clear_body();heading.text="比赛"
 var column=scroll_body("TournamentListScroll")
 text(column,"查看比赛描述、赛制和时间后选择是否报名。比赛时间到达后停止报名，仅已报名玩家可签到；只有已签到玩家会被纳入参赛名单。",app.ui_metrics.body,app.MUTED)
 if tournaments.is_empty():text(column,"暂无比赛，等待主办方创建。",app.ui_metrics.title,app.GOLD)
 for entry in tournaments:
  var panel=PanelContainer.new();column.add_child(panel);panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
  var content=VBoxContainer.new();panel.add_child(content)
  text(content,str(entry.title),app.ui_metrics.title,app.GOLD)
  text(content,Series.format_label(int(entry.get("game_format",Series.BO1_SIDEBOARD)))+" · "+start_caption(entry),app.ui_metrics.small,app.GOLD)
  text(content,"%s · 群组 %d 人 · 已签到 %d 人" % [PHASES.get(entry.phase,""),entry.member_count,entry.checkin_count],app.ui_metrics.small,app.MUTED)
  if entry.joined:text(content,"我的状态："+my_status(entry),app.ui_metrics.small)
  action(content,"查看比赛",func():member_page=0;pairing_page=0;standing_page=0;roster_only=false;detail_tab="group";fetch_detail(int(entry.id)),false,"TournamentEntry_"+str(int(entry.id)))
 pagination(body,page_index,pages,func():fetch_list(page_index-1),func():fetch_list(page_index+1))
 set_busy(busy)

func my_status(entry: Dictionary) -> String:
 if not entry.joined:return "未加入群组"
 if entry.phase in ["locked","running","complete"]:return "已纳入参赛名单" if entry.in_roster else "未签到，未纳入参赛名单"
 if entry.checked_in:return "已完成赛前签到"
 return "已报名，等待比赛时间到达后签到" if entry.phase=="registration" else "已报名，尚未签到"

func start_caption(entry: Dictionary) -> String:
 var stamp=int(entry.get("start_at",0))
 return "比赛时间："+china_time(stamp)+"（北京时间）" if stamp>0 else "比赛时间尚未设置"

func registration_open() -> bool:
 return current.get("phase","")=="registration" and int(current.get("start_at",0))>int(Time.get_unix_time_from_system())

func show_detail():
 mode="detail";clear_body();heading.text="比赛详情"
 if current.phase in ["registration","checkin","locked"]:
  var my_state=text(body,"我的状态："+my_status(current),app.ui_metrics.small,app.GOLD);my_state.name="TournamentMyStatus"
 var controls=HFlowContainer.new();controls.name="TournamentActions";body.add_child(controls)
 if current.phase in ["registration","checkin"]:
  if current.joined:
   if current.phase=="checkin" and not current.checked_in:action(controls,"赛前签到",func():mutate("checkin"),true,"TournamentCheckin")
   action(controls,"退出群组",func():app.confirm_action("退出群组会取消本次签到，是否退出？",func():mutate("leave")),false,"TournamentLeave")
 if current.owned:
  if current.phase=="checkin":action(controls,"结束签到",confirm_close_checkin,false,"TournamentCloseCheckin")
  elif current.phase in ["locked","running"]:action(controls,advance_caption(),advance_round,true,"TournamentAdvanceRound")
 if current.phase=="running" and not my_pairing.is_empty() and my_pairing.result==null and not my_pairing.bye:
  action(controls,"游戏对战",func():enter_game(my_pairing),true,"TournamentEnterGame")
  if not my_pairing.game_active:
   action(controls,"填结果表",func():show_result_form(my_pairing,false),false,"TournamentReportResult")
   var other=my_pairing.reports[1-int(my_pairing.actor)]
   if other!=null:
    var proposal=my_pairing.duplicate(true)
    action(controls,"确认结果",func():app.confirm_action("确认结果："+result_caption(proposal,other)+"？",func():send_request({"action":"confirm_result","id":int(current.id),"pairing_id":int(proposal.id),"result":int(other),"revision":int(proposal.revision)})),true,"TournamentConfirmResult")
 if controls.get_child_count()==0:controls.hide()
 var tabs=HFlowContainer.new();body.add_child(tabs)
 for entry in [["group","群组"],["pairings","对阵"],["standings","排名"]]:
  action(tabs,entry[1],func():detail_tab=entry[0];show_detail(),detail_tab==entry[0],"TournamentTab_"+entry[0])
 if current.owned:
  action(tabs,"管理",func():detail_tab="manage";show_detail(),detail_tab=="manage","TournamentTab_manage")
 var column=scroll_body("TournamentDetailScroll")
 if detail_tab=="pairings":text(column,round_caption(),app.ui_metrics.small,app.GOLD);build_pairings(column);set_busy(busy);return
 if detail_tab=="standings":build_standings(column);set_busy(busy);return
 if detail_tab=="manage":build_management(column);set_busy(busy);return
 text(column,str(current.title),app.ui_metrics.title,app.GOLD)
 var game_label=text(column,"对局赛制："+Series.format_label(int(current.get("game_format",Series.BO1_SIDEBOARD))),app.ui_metrics.body,app.GOLD);game_label.name="TournamentGameFormatDisplay"
 var date_label=text(column,start_caption(current),app.ui_metrics.body,app.GOLD);date_label.name="TournamentStartTimeDisplay"
 text(column,FORMATS.get(current.get("format","swiss"),"")+" · "+round_caption(),app.ui_metrics.body,app.GOLD)
 text(column,"%s · 群组 %d 人 · 已签到 %d 人 · 参赛名单 %d 人" % [PHASES.get(current.phase,""),current.member_count,current.checkin_count,current.roster_count],app.ui_metrics.small,app.MUTED)
 text(column,"比赛描述",app.ui_metrics.body,app.GOLD)
 var description=text(column,str(current.description) if not str(current.description).is_empty() else "主办方尚未填写比赛描述。",app.ui_metrics.body);description.name="TournamentDescriptionDisplay"
 if not current.joined:
  if registration_open():
   text(column,"报名后，需在比赛时间到达后完成签到。",app.ui_metrics.small,app.MUTED)
   action(column,"加入比赛",func():mutate("join"),true,"TournamentJoin")
   action(column,"暂不加入，返回列表",func():fetch_list(page_index),false,"TournamentDeclineJoin")
  elif current.phase=="checkin":text(column,"报名已截止。比赛时间到达后仅已报名玩家可以签到。",app.ui_metrics.body,app.GOLD)
  elif current.phase=="registration":text(column,"报名已截止，等待刷新签到状态。" if int(current.get("start_at",0))>0 else "比赛时间尚未设置，暂不能报名。",app.ui_metrics.body,app.MUTED)
 if not str(current.get("timer_notice","")).is_empty():text(column,str(current.timer_notice),app.ui_metrics.small,app.GOLD)
 text(column,"加入群组不等于完成签到；签到结束后，仅已签到玩家进入参赛名单。",app.ui_metrics.small,app.MUTED)
 var member_header=HBoxContainer.new();column.add_child(member_header)
 text(member_header,"参赛名单" if roster_only else "群组成员",app.ui_metrics.body,app.GOLD)
 if current.phase in ["locked","running","complete"]:action(member_header,"查看群组成员" if roster_only else "查看参赛名单",func():roster_only=not roster_only;member_page=0;fetch_detail(int(current.id)),false,"TournamentRosterToggle")
 if members.is_empty():text(column,"暂无参赛玩家" if roster_only else "暂无群组成员",app.ui_metrics.small,app.MUTED)
 for member in members:
  var state="已纳入参赛名单" if member.in_roster else "未纳入参赛名单" if current.phase in ["locked","running","complete"] else "已签到" if member.checked_in else "未签到"
  text(column,PlayerNameDisplay.caption(str(member.nickname))+("（我）" if member.self else "")+" · "+state,app.ui_metrics.body)
 pagination(body,member_page,member_pages,func():member_page-=1;fetch_detail(int(current.id)),func():member_page+=1;fetch_detail(int(current.id)))
 set_busy(busy)

func confirm_close_checkin():
 app.confirm_action("结束签到后将确定参赛名单，未签到成员不会被纳入，且不能再加入或签到。是否结束签到？",func():mutate("close_checkin"))

func show_create():
 if busy or not can_create:return
 mode="create";clear_body();heading.text="创建比赛";notice.text=""
 var column=scroll_body("TournamentCreateScroll")
 text(column,"指定比赛时间后，玩家可在该时间前报名。到点自动关闭报名并开放签到。",app.ui_metrics.body,app.MUTED)
 text(column,"比赛名称",app.ui_metrics.body)
 title_input=LineEdit.new();title_input.name="TournamentTitle";column.add_child(title_input);expand(title_input)
 title_input.max_length=40;title_input.placeholder_text="填写比赛名称";title_input.custom_minimum_size.y=app.ui_metrics.hit
 text(column,"比赛描述（选填，最多 2000 字）",app.ui_metrics.body)
 description_input=TextEdit.new();description_input.name="TournamentDescription";column.add_child(description_input);expand(description_input,true)
 description_input.custom_minimum_size.y=app.ui_metrics.hit*2.5;description_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 description_input.placeholder_text="可填写比赛规则、奖励、集合说明和签到提醒"
 build_settings_fields(column,false)
 submit_button=action(body,"创建比赛群组",submit_create,true,"TournamentSubmit")
 title_input.text_changed.connect(func(_value):validate_create())
 description_input.text_changed.connect(validate_create)
 validate_create();title_input.grab_focus()

func validate_create():
 if is_instance_valid(submit_button):submit_button.disabled=busy or title_input.text.strip_edges().is_empty() or description_input.text.length()>2000
 if is_instance_valid(description_input) and description_input.text.length()>2000:notice.text="比赛描述最多 2000 个字符"
 elif not busy:notice.text=""

func submit_create():
 if busy or not can_create:return
 if title_input.text.strip_edges().is_empty() or description_input.text.length()>2000:return
 var payload=settings_payload()
 if payload.is_empty():return
 payload.merge({"action":"create","title":title_input.text.strip_edges(),"description":description_input.text})
 send_request(payload)

func go_back():
 if mode=="list":app.menu()
 elif not busy:fetch_list(page_index)

func refresh():
 if busy:return
 if mode=="detail":fetch_detail(int(current.id))
 else:fetch_list(page_index)

func fetch_list(index: int=0):
 if busy:return
 send_request({"action":"list","page":index})

func fetch_detail(id: int):
 if busy:return
 send_request({"action":"detail","id":id,"member_page":member_page,"roster_only":roster_only,"pairing_page":pairing_page,"standing_page":standing_page})

func mutate(operation: String):
 if busy or current.is_empty():return
 send_request({"action":operation,"id":int(current.id)})

func set_busy(value: bool):
 busy=value
 for control in find_children("*","Button",true,false):
  if control==back_button:control.disabled=busy and mode!="list"
  else:control.disabled=busy or control.get_meta("page_disabled",false)
 if is_instance_valid(title_input):title_input.editable=not busy
 if is_instance_valid(description_input):description_input.editable=not busy
 if mode=="create":validate_create()
 if mode=="description":validate_description()

func send_request(payload: Dictionary):
 set_busy(true)
 if not silent_request:say("正在连接比赛服务…")
 client=Client.new();add_child(client);client.server_url=app.tournament_server_url
 client.finished.connect(receive)
 client.request(payload,app.account_token)

func receive(answer: Dictionary):
 if is_instance_valid(client):client.queue_free();client=null
 set_busy(false)
 if answer.get("auth_required",false):app.tournament_login_expired(str(answer.get("message","请重新登录")));return
 if not silent_request or not answer.get("ok",false):say(str(answer.get("message","")))
 silent_request=false
 if not answer.get("ok",false):
  if answer.get("tournament_missing",false):fetch_list(page_index)
  return
 if answer.has("tournaments"):
  tournaments=answer.tournaments;can_create=answer.get("can_create",false)
  page_index=int(answer.get("page",0));pages=int(answer.get("pages",1));show_list()
 elif answer.has("tournament"):
  var scroll=find_child("TournamentDetailScroll",true,false)
  retained_scroll=scroll.scroll_vertical if scroll is ScrollContainer and mode=="detail" else 0
  if int(answer.tournament.get("round_number",0))!=int(current.get("round_number",0)):
   detail_tab="pairings";retained_scroll=0
  if mode=="list" or mode=="create":detail_tab="group";retained_scroll=0
  current=answer.tournament;members=answer.get("members",[])
  app.tournament_unread.mark_read(int(current.id))
  member_page=int(answer.get("member_page",0));member_pages=int(answer.get("member_pages",1))
  my_pairing=answer.get("my_pairing",{});pairings=answer.get("pairings",[]);standings=answer.get("standings",[]);schedules=answer.get("schedules",[])
  pairing_page=int(answer.get("pairing_page",0));pairing_pages=int(answer.get("pairing_pages",1))
  standing_page=int(answer.get("standing_page",0));standing_pages=int(answer.get("standing_pages",1))
  roster_only=answer.get("roster_only",false);show_detail()
  var next_scroll=find_child("TournamentDetailScroll",true,false)
  if next_scroll is ScrollContainer:next_scroll.set_deferred("scroll_vertical",retained_scroll)

func _unhandled_key_input(event: InputEvent):
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled();go_back()

func round_caption() -> String:
 var number=int(current.get("round_number",0))
 if number==0:return "瑞士轮轮数："+("按签到人数自动确定" if int(current.get("swiss_rounds",0))==0 else str(int(current.swiss_rounds)))
 return "%s · 第 %d 轮 · 待结束 %d 桌" % [STAGES.get(current.get("round_stage",""),""),number,int(current.get("pending_matches",0))]

func advance_caption() -> String:
 if current.phase=="locked":return "开始首轮"
 if int(current.get("pending_matches",0))>0:return "等待本轮结果"
 var last=int(current.total_swiss_rounds)+int(KNOCKOUT_ROUNDS.get(current.format,0))
 return "结束比赛" if int(current.round_number)>=last else "开始下一轮"

func advance_round():
 if int(current.get("pending_matches",0))>0:say("请先在对阵页面裁定未结束对局");return
 var expected=int(current.get("round_number",0))
 app.confirm_action(advance_caption()+"？系统将按照当前成绩确定对阵或最终排名。",func():send_request({"action":"start_round","id":int(current.id),"expected_round":expected}))

func build_settings_fields(parent: Node,editing: bool):
 text(parent,"比赛时间（北京时间，YYYY-MM-DD HH:MM，必填）",app.ui_metrics.body,app.GOLD)
 start_time_input=LineEdit.new();start_time_input.name="TournamentStartTime";parent.add_child(start_time_input);expand(start_time_input)
 start_time_input.custom_minimum_size.y=app.ui_metrics.hit;start_time_input.placeholder_text="例如：2026-10-18 20:00"
 start_time_input.text=china_time(int(current.start_at)) if editing and int(current.get("start_at",0))>0 else "" if editing else china_time(int(Time.get_unix_time_from_system())+3600)
 start_time_input.editable=not editing or current.phase=="registration"
 if not editing:start_time_input.text_changed.connect(func(_value):validate_create())
 text(parent,"到达比赛时间后停止报名，自动开放签到。比赛时间到达后不可修改。",app.ui_metrics.small,app.MUTED)
 var locked=editing and int(current.get("round_number",0))>0
 text(parent,"对局赛制",app.ui_metrics.body,app.GOLD)
 game_format_input=OptionButton.new();parent.add_child(game_format_input);game_format_input.name="TournamentGameFormat"
 for value in [Series.BO1,Series.BO1_SIDEBOARD,Series.BO3,Series.EXPLORATION,Series.EXPLORATION_RANDOM]:game_format_input.add_item(Series.format_label(value),value)
 app.ui_metrics.button(game_format_input);expand(game_format_input)
 game_format_input.select(game_format_input.get_item_index(int(current.get("game_format",Series.BO1_SIDEBOARD)) if editing else Series.BO1_SIDEBOARD))
 game_format_input.disabled=locked;game_format_input.set_meta("page_disabled",locked)
 text(parent,"BO1 单局；BO1 换备牌可赛前换入最多 3 张备牌；BO3 三局两胜、局间换备牌；娱乐模式使用双方固定卡组。首轮开始后不可修改对局赛制。",app.ui_metrics.small,app.MUTED)
 text(parent,"赛程",app.ui_metrics.body,app.GOLD)
 format_input=OptionButton.new();parent.add_child(format_input);format_input.name="TournamentFormat"
 for value in FORMATS.values():format_input.add_item(value)
 app.ui_metrics.button(format_input);expand(format_input)
 format_input.select(FORMATS.keys().find(current.get("format","swiss")) if editing else 0)
 format_input.disabled=locked;format_input.set_meta("page_disabled",locked)
 text(parent,"瑞士轮轮数（0 为按签到人数自动确定）",app.ui_metrics.small)
 rounds_input=SpinBox.new();rounds_input.name="TournamentSwissRounds";parent.add_child(rounds_input)
 rounds_input.min_value=0;rounds_input.max_value=16;rounds_input.step=1;rounds_input.value=current.get("swiss_rounds",0) if editing else 0
 rounds_input.custom_minimum_size.y=app.ui_metrics.hit;rounds_input.editable=not locked
 text(parent,"自动轮次间隔 / 分钟（0 为手动推进）",app.ui_metrics.small)
 interval_input=SpinBox.new();interval_input.name="TournamentRoundInterval";parent.add_child(interval_input)
 interval_input.min_value=0;interval_input.max_value=10080;interval_input.step=1;interval_input.value=float(current.get("round_interval",0))/60.0 if editing else 0
 interval_input.custom_minimum_size.y=app.ui_metrics.hit
 text(parent,"自动轮数为签到人数的 log₂ 向上取整。胜 3 分、平 1 分、负 0 分，轮空 3 分；同分依次比较对手积分总和、胜场及抽签序号。",app.ui_metrics.small,app.MUTED)
 text(parent,"可选瑞士轮前 2、4、8、16 名进入单败淘汰赛，签到人数须达到所选名额。按种子高低配对，前两名分处上下半区，胜者逐轮晋级直至决出冠军；半决赛、八强赛、十六强赛败者分别并列第 3、5、9 名。",app.ui_metrics.small,app.MUTED)
 text(parent,"轮次间隔从本轮开始计时。到点后有未结束或待确认对局，等待主办方裁定后再推进；自动轮次只在首轮开始后生效。",app.ui_metrics.small,app.MUTED)

func settings_payload() -> Dictionary:
 var stamp=parse_china_time(start_time_input.text)
 if mode=="configure" and int(current.get("start_at",0))>0 and start_time_input.text==china_time(int(current.start_at)):stamp=int(current.start_at)
 if stamp<=0:say("请输入有效比赛时间，格式为 YYYY-MM-DD HH:MM（北京时间）");return {}
 return {"format":FORMATS.keys()[format_input.selected],"swiss_rounds":int(rounds_input.value),"round_interval":int(interval_input.value*60),"game_format":game_format_input.get_selected_id(),"start_at":stamp}

func show_settings():
 if busy or not current.owned:return
 mode="configure";clear_body();heading.text="比赛设置"
 var column=scroll_body("TournamentSettingsScroll")
 build_settings_fields(column,true)
 action(body,"保存设置",submit_settings,true,"TournamentSaveSettings")

func submit_settings():
 if busy:return
 var payload=settings_payload()
 if payload.is_empty():return
 payload.merge({"action":"configure","id":int(current.id)});send_request(payload)

func show_description_editor():
 if busy or not current.owned:return
 mode="description";clear_body();heading.text="编辑比赛描述"
 var column=scroll_body("TournamentDescriptionScroll")
 text(column,str(current.title),app.ui_metrics.title,app.GOLD)
 text(column,"比赛描述（最多 2000 字，可留空）",app.ui_metrics.body)
 description_input=TextEdit.new();description_input.name="TournamentDescription";column.add_child(description_input);expand(description_input,true)
 description_input.custom_minimum_size.y=app.ui_metrics.hit*4;description_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 description_input.text=str(current.description)
 submit_button=action(body,"保存比赛描述",func():send_request({"action":"update_description","id":int(current.id),"description":description_input.text}),true,"TournamentSaveDescription")
 description_input.text_changed.connect(validate_description);validate_description()

func validate_description():
 if is_instance_valid(submit_button):submit_button.disabled=busy or description_input.text.length()>2000
 if not busy:say("比赛描述最多 2000 个字符" if description_input.text.length()>2000 else "")

func confirm_delete():
 if busy or not current.owned:return
 var id=int(current.id)
 app.confirm_action("删除比赛“%s”？报名、签到、对阵和定时任务将被清除，进行中的比赛对局将结束。删除后无法恢复。" % str(current.title),func():send_request({"action":"delete","id":id,"page":page_index}))

func build_management(parent: Node):
 if not current.owned:return
 action(parent,"编辑比赛描述",show_description_editor,false,"TournamentEditDescription")
 action(parent,"删除比赛",confirm_delete,false,"TournamentDelete")
 if current.phase!="complete":
  action(parent,"比赛设置",show_settings,false,"TournamentSettings")
  action(parent,"安排定时任务",show_schedule,false,"TournamentSchedule")
 text(parent,"自动轮次："+("手动推进" if int(current.get("round_interval",0))==0 else "每 %d 分钟检查并推进" % int(current.round_interval/60)),app.ui_metrics.body)
 text(parent,"定时任务（北京时间）",app.ui_metrics.body,app.GOLD)
 if schedules.is_empty():text(parent,"暂无定时任务",app.ui_metrics.small,app.MUTED)
 for task in schedules:
  var status={"scheduled":"待执行","waiting":"等待主办方裁定","done":"已执行","failed":"未执行","cancelled":"已取消"}.get(task.status,task.status)
  text(parent,"%s · %s · %s" % [china_time(int(task.due_at)),TASKS.get(task.action,""),status],app.ui_metrics.small)
  if not str(task.message).is_empty():text(parent,str(task.message),app.ui_metrics.small,app.MUTED)
  if task.status in ["scheduled","waiting"]:action(parent,"取消此定时任务",func():send_request({"action":"cancel_schedule","id":int(current.id),"schedule_id":int(task.id)}),false,"TournamentCancelSchedule_"+str(int(task.id)))

func china_time(unix_time: int) -> String:
 return Time.get_datetime_string_from_unix_time(unix_time+8*3600).replace("T"," ").left(16)

func parse_china_time(value: String) -> int:
 value=value.strip_edges()
 var pattern=RegEx.new();pattern.compile("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$")
 if pattern.search(value)==null:return -1
 var local_seconds=Time.get_unix_time_from_datetime_string(value+":00")
 if Time.get_datetime_string_from_unix_time(local_seconds).replace("T"," ").left(16)!=value:return -1
 return local_seconds-8*3600

func show_schedule():
 if busy or not current.owned:return
 mode="schedule";clear_body();heading.text="定时任务"
 var column=scroll_body("TournamentScheduleScroll")
 text(column,"任务",app.ui_metrics.body,app.GOLD)
 task_input=OptionButton.new();task_input.name="TournamentTask";column.add_child(task_input)
 for value in TASKS.values():task_input.add_item(value)
 app.ui_metrics.button(task_input)
 if current.phase in ["locked","running"]:task_input.selected=2
 text(column,"执行时间（北京时间，YYYY-MM-DD HH:MM）",app.ui_metrics.small)
 time_input=LineEdit.new();time_input.name="TournamentTaskTime";column.add_child(time_input);expand(time_input)
 time_input.text=china_time(int(Time.get_unix_time_from_system())+600);time_input.custom_minimum_size.y=app.ui_metrics.hit
 text(column,"服务器按指定时间开启或结束签到、推进下一轮。轮次任务到点仍有未结束对局时，会等待主办方裁定后执行。",app.ui_metrics.small,app.MUTED)
 action(body,"保存定时任务",submit_schedule,true,"TournamentScheduleSubmit")

func submit_schedule():
 if busy:return
 var value=time_input.text.strip_edges()
 var pattern=RegEx.new();pattern.compile("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}$")
 if pattern.search(value)==null:say("时间格式须为 YYYY-MM-DD HH:MM");return
 var local_seconds=Time.get_unix_time_from_datetime_string(value+":00")
 if Time.get_datetime_string_from_unix_time(local_seconds).replace("T"," ").left(16)!=value:say("请输入有效日期与时间");return
 send_request({"action":"schedule","id":int(current.id),"task":TASKS.keys()[task_input.selected],"due_at":local_seconds-8*3600,"expected_round":int(current.get("round_number",0))})

func result_caption(pairing: Dictionary,result) -> String:
 if result==null:return "未结束"
 if pairing.bye:return "轮空 · 3 分"
 if int(result)==-1:return "平局"
 return PlayerNameDisplay.caption(str(pairing.names[int(result)]))+" 获胜"

func build_pairings(parent: Node):
 if int(current.get("round_number",0))==0:
  text(parent,"首轮尚未开始。签到结束后，主办方可手动或定时开始首轮。",app.ui_metrics.body,app.MUTED);return
 if not my_pairing.is_empty():
  text(parent,"我的对局",app.ui_metrics.body,app.GOLD)
  build_pairing(parent,my_pairing,true)
 text(parent,"本轮对阵",app.ui_metrics.body,app.GOLD)
 for pairing in pairings:build_pairing(parent,pairing,false)
 pagination(body,pairing_page,pairing_pages,func():pairing_page-=1;fetch_detail(int(current.id)),func():pairing_page+=1;fetch_detail(int(current.id)))

func build_pairing(parent: Node,pairing: Dictionary,personal: bool):
 var panel=PanelContainer.new();parent.add_child(panel);expand(panel)
 panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 var column=VBoxContainer.new();panel.add_child(column)
 text(column,"第 %d 桌：%s vs %s" % [int(pairing.table),PlayerNameDisplay.caption(str(pairing.names[0])),"轮空" if pairing.bye else PlayerNameDisplay.caption(str(pairing.names[1]))],app.ui_metrics.body,app.GOLD)
 text(column,result_caption(pairing,pairing.result),app.ui_metrics.body)
 if pairing.result!=null:
  text(column,{"game":"游戏对战自动回填","agreement":"双方确认的结果","organizer":"主办方裁定","bye":"轮空"}.get(pairing.source,""),app.ui_metrics.small,app.MUTED)
 elif pairing.game_active:text(column,"游戏对局进行中，成绩结束后自动回填。",app.ui_metrics.small,app.MUTED)
 elif not pairing.bye:
  for actor in range(2):
   if pairing.reports[actor]!=null:text(column,"%s 提交：%s" % [PlayerNameDisplay.caption(str(pairing.names[actor])),result_caption(pairing,pairing.reports[actor])],app.ui_metrics.small)
  if pairing.reports[0]!=null and pairing.reports[1]!=null and pairing.reports[0]!=pairing.reports[1]:text(column,"结果不一致，待双方重新确认或主办方裁定。",app.ui_metrics.small,app.GOLD)
 if not personal and current.owned and current.phase=="running" and not pairing.bye:
  action(column,"主办方裁定" if pairing.result==null else "修正本桌结果",func():show_result_form(pairing,true),false,"TournamentJudge_"+str(int(pairing.id)))

func show_result_form(pairing: Dictionary,judge: bool):
 if busy:return
 mode="judge" if judge else "result";result_pairing=pairing.duplicate(true);clear_body();heading.text="主办方裁定" if judge else "比赛结果表"
 var column=scroll_body("TournamentResultScroll")
 text(column,"第 %d 桌：%s vs %s" % [int(pairing.table),PlayerNameDisplay.caption(str(pairing.names[0])),PlayerNameDisplay.caption(str(pairing.names[1]))],app.ui_metrics.body,app.GOLD)
 result_input=OptionButton.new();result_input.name="TournamentResultChoice";column.add_child(result_input)
 for winner in range(2):result_input.add_item(result_caption(pairing,winner),winner)
 if current.round_stage=="swiss":result_input.add_item("平局",2)
 app.ui_metrics.button(result_input)
 text(column,"裁定将直接计入成绩并允许推进轮次。" if judge else "结果表须由本桌对手确认后才计入成绩。双方意见不一致时，可修改结果或联系主办方裁定。",app.ui_metrics.small,app.MUTED)
 action(body,"确认裁定" if judge else "提交结果表",submit_result,true,"TournamentResultSubmit")

func submit_result():
 if busy:return
 var result=result_input.get_selected_id();result=-1 if result==2 else result
 var payload={"action":"judge_result" if mode=="judge" else "report_result","id":int(current.id),"pairing_id":int(result_pairing.id),"result":result,"revision":int(result_pairing.revision)}
 if mode=="judge":app.confirm_action("将本桌裁定为："+result_caption(result_pairing,result)+"？",func():send_request(payload))
 else:send_request(payload)

func enter_game(pairing: Dictionary):
 if busy:return
 app.ensure_lan_session()
 if app.lan_session.ranked_match_pending() or app.lan_session.matchmaking:say("请先结束或恢复当前云端对局");return
 var game_format=int(current.get("game_format",Series.BO1_SIDEBOARD))
 if Series.is_entertainment(game_format):start_game(Series.entertainment_deck(game_format),pairing,game_format)
 else:app.open_deck_picker(func(index):start_game(app.decks[index],pairing,game_format),"","选择本轮比赛卡组")

func start_game(deck: Dictionary,pairing: Dictionary,game_format: int):
 app.lan_session.cloud_token=app.account_token;app.lan_session.cloud_nickname=app.account_nickname;app.lan_session.cloud_account=app.account_name
 var match_mode="exploration_random" if game_format==Series.EXPLORATION_RANDOM else "exploration" if game_format==Series.EXPLORATION else "casual"
 var error=app.lan_session.start_matchmaking(app.tournament_server_url,deck,true,match_mode,str(pairing.match_id),game_format)
 if not error.is_empty():app.alert(error,"无法进入比赛对局");return
 app.online()

func build_standings(parent: Node):
 text(parent,"瑞士轮积分排名",app.ui_metrics.body,app.GOLD)
 text(parent,"胜 3 分 · 平 1 分 · 负 0 分 · 轮空 3 分。排序：积分、对手积分总和、胜场、抽签序号。",app.ui_metrics.small,app.MUTED)
 if standings.is_empty():text(parent,"签到结束后显示参赛排名。",app.ui_metrics.body,app.MUTED)
 for entry in standings:
  var suffix=" · 淘汰赛第 %d 名" % int(entry.placement) if entry.has("placement") else ""
  text(parent,"%d. %s · %d 分 · 对手分 %d · %d 胜 / %d 平 / %d 负 · 轮空 %d%s" % [int(entry.rank),PlayerNameDisplay.caption(str(entry.nickname)),int(entry.points),int(entry.buchholz),int(entry.wins),int(entry.draws),int(entry.losses),int(entry.byes),suffix],app.ui_metrics.body)
 pagination(body,standing_page,standing_pages,func():standing_page-=1;fetch_detail(int(current.id)),func():standing_page+=1;fetch_detail(int(current.id)))

func say(message: String):
 notice.text=message;notice.visible=not message.is_empty()
