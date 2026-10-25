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
var custom_stages: CheckButton
var stage_form
var score_inputs: Array=[]
var pairing_round=0
var viewed_round=0
var round_info: Dictionary={}
var limitless: Dictionary={}
var external_view="pairings"
var external_phase=0
var external_round=0
var external_page=0
var join_requests: Dictionary={}
var request_page=0

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
  if mode!="detail" or detail_tab=="manage" or busy or app.menu_popup_open():return
  if app.get_children().any(func(node):return node is Window and node.visible):return
  silent_request=true;fetch_detail(int(current.id)))
 timer.start()

func relayout():
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 for control in find_children("*","Button",true,false):app.ui_metrics.button(control)
 heading.add_theme_font_size_override("font_size",app.ui_metrics.title)
 notice.add_theme_font_size_override("font_size",app.ui_metrics.small)
 if is_instance_valid(stage_form):stage_form.relayout()

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
 if can_create:action(column,"从 Limitless 快速建立比赛",show_limitless_create,true,"TournamentQuickLimitless")
 text(column,"查看比赛描述、赛制和时间后选择是否报名。比赛时间到达后停止报名，仅已报名玩家可签到；只有已签到玩家会被纳入参赛名单。",app.ui_metrics.body,app.MUTED)
 if tournaments.is_empty():text(column,"暂无比赛，等待主办方创建。",app.ui_metrics.title,app.GOLD)
 for entry in tournaments:
  var panel=PanelContainer.new();column.add_child(panel);panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
  var content=VBoxContainer.new();panel.add_child(content)
  text(content,str(entry.title),app.ui_metrics.title,app.GOLD)
  text(content,Series.format_label(int(entry.get("game_format",Series.BO1_SIDEBOARD)))+" · "+start_caption(entry),app.ui_metrics.small,app.GOLD)
  text(content,"%s · 群组 %d 人 · 已签到 %d 人" % [PHASES.get(entry.phase,""),entry.member_count,entry.checkin_count],app.ui_metrics.small,app.MUTED)
  if entry.joined or not str(entry.get("limitless_admission",{}).get("status","")).is_empty():text(content,"我的状态："+my_status(entry),app.ui_metrics.small)
  action(content,"查看比赛",func():member_page=0;pairing_page=0;standing_page=0;roster_only=false;detail_tab="group";fetch_detail(int(entry.id)),false,"TournamentEntry_"+str(int(entry.id)))
 pagination(body,page_index,pages,func():fetch_list(page_index-1),func():fetch_list(page_index+1))
 set_busy(busy)

func my_status(entry: Dictionary) -> String:
 var approval=str(entry.get("limitless_admission",{}).get("status",""))
 if approval=="pending":return "加入申请待管理员核验"
 if approval=="rejected" and not entry.joined:return "加入申请被拒绝，可联系赛事管理员"
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
 if detail_tab=="group" and current.get("limitless_admission",{}).get("status","")=="pending":action(controls,"撤回加入申请",func():mutate("leave"),false,"TournamentWithdrawJoin")
 if current.phase in ["registration","checkin"]:
  if current.joined:
   if current.phase=="checkin" and not current.checked_in:action(controls,"赛前签到",func():mutate("checkin"),true,"TournamentCheckin")
   action(controls,"退出群组",func():app.confirm_action("退出群组会取消本次签到，是否退出？",func():mutate("leave")),false,"TournamentLeave")
 if current.owned:
  if current.phase=="checkin":action(controls,"结束签到",confirm_close_checkin,false,"TournamentCloseCheckin")
  elif current.phase in ["locked","running"]:action(controls,advance_caption(),advance_round,true,"TournamentAdvanceRound")
 if current.phase=="running" and not my_pairing.is_empty() and my_pairing.result==null and not my_pairing.bye and my_pairing.source!="awaiting_limitless":
  action(controls,"游戏对战",func():enter_game(my_pairing),true,"TournamentEnterGame")
  if not my_pairing.game_active and current.get("pairing_source","local")!="limitless":
   action(controls,"填结果表",func():show_result_form(my_pairing,false),false,"TournamentReportResult")
   var other=my_pairing.reports[1-int(my_pairing.actor)]
   if other!=null:
    var proposal=my_pairing.duplicate(true)
    action(controls,"确认结果",func():app.confirm_action("确认结果："+result_caption(proposal,other)+" · 大比分 "+str(proposal.report_scores[1-int(proposal.actor)])+"？",func():send_request({"action":"confirm_result","id":int(current.id),"pairing_id":int(proposal.id),"result":int(other),"scores":proposal.report_scores[1-int(proposal.actor)],"revision":int(proposal.revision)})),true,"TournamentConfirmResult")
 if controls.get_child_count()==0:controls.hide()
 var tabs=HFlowContainer.new();body.add_child(tabs)
 for entry in [["group","群组"],["pairings","对阵"],["standings","排名"]]:
  action(tabs,entry[1],func():detail_tab=entry[0];show_detail(),detail_tab==entry[0],"TournamentTab_"+entry[0])
 if not limitless.is_empty():action(tabs,"Limitless 签表",func():detail_tab="limitless";fetch_detail(int(current.id)),detail_tab=="limitless","TournamentTab_limitless")
 if current.owned:
  action(tabs,"管理",func():detail_tab="manage";show_detail(),detail_tab=="manage","TournamentTab_manage")
 var column=scroll_body("TournamentDetailScroll")
 if detail_tab=="pairings":text(column,round_caption(),app.ui_metrics.small,app.GOLD);build_pairings(column);set_busy(busy);return
 if detail_tab=="standings":build_standings(column);set_busy(busy);return
 if detail_tab=="manage":build_management(column);set_busy(busy);return
 if detail_tab=="limitless":build_limitless(column);set_busy(busy);return
 text(column,str(current.title),app.ui_metrics.title,app.GOLD)
 var game_label=text(column,"对局赛制："+Series.format_label(int(current.get("game_format",Series.BO1_SIDEBOARD))),app.ui_metrics.body,app.GOLD);game_label.name="TournamentGameFormatDisplay"
 var date_label=text(column,start_caption(current),app.ui_metrics.body,app.GOLD);date_label.name="TournamentStartTimeDisplay"
 text(column,("Limitless 外部编排" if current.get("pairing_source","local")=="limitless" else FORMATS.get(current.get("format","swiss"),""))+" · "+round_caption(),app.ui_metrics.body,app.GOLD)
 for stage in ([] if current.get("pairing_source","local")=="limitless" else current.get("stages",[])):
  text(column,str(stage.name)+" · "+preload("res://scripts/tournament_stage_form.gd").KINDS.get(stage.kind,stage.kind)+" · "+Series.format_label(int(stage.game_format))+" · "+points_caption(stage),app.ui_metrics.small)
 var rewards=current.get("rewards",{"champion":50,"runner_up":40,"semifinalist":20})
 text(column,"铜钱奖励：冠军 %d · 亚军 %d · 四强各 %d（按最终名次发放，不叠加）" % [int(rewards.champion),int(rewards.runner_up),int(rewards.semifinalist)],app.ui_metrics.body,app.GOLD)
 text(column,"%s · 群组 %d 人 · 已签到 %d 人 · 参赛名单 %d 人" % [PHASES.get(current.phase,""),current.member_count,current.checkin_count,current.roster_count],app.ui_metrics.small,app.MUTED)
 text(column,"比赛描述",app.ui_metrics.body,app.GOLD)
 var description=text(column,str(current.description) if not str(current.description).is_empty() else "主办方尚未填写比赛描述。",app.ui_metrics.body);description.name="TournamentDescriptionDisplay"
 if not current.joined:
  var admission=current.get("limitless_admission",{})
  if not admission.is_empty() and (admission.get("started",false) or not admission.get("can_join",false)):
   text(column,"Limitless 已开赛后，仅来源选手可申请加入；管理员核验通过后进入参赛名单。",app.ui_metrics.small,app.MUTED)
   if not str(admission.get("reason","")).is_empty():text(column,str(admission.reason),app.ui_metrics.body,app.GOLD)
   if admission.get("status","")=="rejected":text(column,"上次申请未通过，请核对账号 ID 或联系赛事管理员后重新申请。",app.ui_metrics.small,app.GOLD)
   var join=action(column,"申请加入比赛",func():mutate("join"),true,"TournamentJoin")
   join.set_meta("page_disabled",not admission.get("can_join",false))
   if str(admission.get("account_id","")).is_empty():action(column,"填写我的 Limitless 账号 ID",app.account_page,false,"TournamentSetLimitlessID")
  elif registration_open():
   text(column,"报名后，需在比赛时间到达后完成签到。",app.ui_metrics.small,app.MUTED)
   action(column,"加入比赛",func():mutate("join"),true,"TournamentJoin")
   action(column,"暂不加入，返回列表",func():fetch_list(page_index),false,"TournamentDeclineJoin")
  elif current.phase=="checkin":text(column,"报名已截止。比赛时间到达后仅已报名玩家可以签到。",app.ui_metrics.body,app.GOLD)
  elif current.phase=="registration":text(column,"报名已截止，等待刷新签到状态。" if int(current.get("start_at",0))>0 else "比赛时间尚未设置，暂不能报名。",app.ui_metrics.body,app.MUTED)
 if not str(current.get("timer_notice","")).is_empty():text(column,str(current.timer_notice),app.ui_metrics.small,app.GOLD)
 text(column,"通过身份审核的来源选手会直接纳入参赛名单。" if current.get("limitless_admission",{}).get("started",false) else "加入群组不等于完成签到；签到结束后，仅已签到玩家进入参赛名单。",app.ui_metrics.small,app.MUTED)
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
 action(column,"从 Limitless 快速建立现有比赛",show_limitless_create,false,"TournamentQuickLimitless")
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

func show_limitless_create():
 if busy or not can_create:return
 mode="import";clear_body();heading.text="从 Limitless 建立比赛";notice.text=""
 var column=scroll_body("TournamentImportScroll")
 text(column,"粘贴赛事链接即可导入名称、比赛时间、选手和签表。进行中的赛事通过管理员审核加入，系统会自动建立选手账号对应关系。",app.ui_metrics.body,app.MUTED)
 var url=LineEdit.new();url.name="TournamentImportURL";column.add_child(url);expand(url);url.custom_minimum_size.y=app.ui_metrics.hit;url.max_length=500
 url.placeholder_text="https://play.limitlesstcg.com/tournament/…/details"
 var submit=action(column,"导入并建立比赛",func():send_request({"action":"create_limitless","url":url.text.strip_edges()}),true,"TournamentImportSubmit")
 submit.disabled=true;submit.set_meta("page_disabled",true)
 url.text_changed.connect(func(value):submit.set_meta("page_disabled",value.strip_edges().is_empty());submit.disabled=busy or value.strip_edges().is_empty())
 action(column,"填入好奇杯示例",func():url.text="https://play.limitlesstcg.com/tournament/6aba47b9783097f8dcb72660/details";url.text_changed.emit(url.text),false,"TournamentImportExample")

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
 if int(current.get("id",0))!=id:
  pairing_round=0;pairing_page=0;external_phase=0;external_round=0;external_page=0;request_page=0
 var payload={"action":"detail","id":id,"member_page":member_page,"roster_only":roster_only,"pairing_page":pairing_page,"standing_page":standing_page,"pairing_round":pairing_round,"request_page":request_page}
 if detail_tab=="limitless":payload.merge({"external_view":external_view,"external_phase":external_phase,"external_round":external_round,"external_page":external_page})
 send_request(payload)

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
 if mode=="detail" and detail_tab=="limitless":payload.merge({"external_view":external_view,"external_phase":external_phase,"external_round":external_round,"external_page":external_page})
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
  if mode in ["list","create","import"]:detail_tab="group";retained_scroll=0
  current=answer.tournament;members=answer.get("members",[])
  limitless=answer.get("limitless",{});viewed_round=int(answer.get("pairing_round",0));round_info=answer.get("round_info",{})
  join_requests=answer.get("join_requests",{});request_page=int(join_requests.get("page",0))
  if limitless.get("view","")==external_view:external_page=int(limitless.get("page",0))
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
 if current.get("pairing_source","local")=="limitless":return "按 Limitless 签表 · 游戏内第 %d 轮 · 待来源公布 %d 桌" % [number,int(current.get("pending_matches",0))]
 if not current.get("stages",[]).is_empty():return "%s · 总第 %d 轮 · 待结束 %d 桌" % [str(current.stages[int(current.get("stage_index",0))].name),number,int(current.get("pending_matches",0))]
 if number==0:return "瑞士轮轮数："+("按签到人数自动确定" if int(current.get("swiss_rounds",0))==0 else str(int(current.swiss_rounds)))
 return "%s · 第 %d 轮 · 待结束 %d 桌" % [STAGES.get(current.get("round_stage",""),""),number,int(current.get("pending_matches",0))]

func advance_caption() -> String:
 if current.get("pairing_source","local")=="limitless":return "按 Limitless 开启首轮" if current.phase=="locked" else "按 Limitless 开启下一轮"
 if current.phase=="locked":return "开始首轮"
 if int(current.get("pending_matches",0))>0:return "等待本轮结果"
 if not current.get("stages",[]).is_empty():return "推进赛程 / 结算奖励"
 var last=int(current.total_swiss_rounds)+int(KNOCKOUT_ROUNDS.get(current.format,0))
 return "结束比赛" if int(current.round_number)>=last else "开始下一轮"

func advance_round():
 if int(current.get("pending_matches",0))>0 and current.get("pairing_source","local")!="limitless":say("请先在对阵页面裁定未结束对局");return
 var expected=int(current.get("round_number",0))
 var explanation="系统须先取得 Limitless 本轮结果和下一轮签表，再分配完全相同的对阵。" if current.get("pairing_source","local")=="limitless" else "系统将按照当前成绩确定对阵或最终排名。"
 app.confirm_action(advance_caption()+"？"+explanation,func():send_request({"action":"start_round","id":int(current.id),"expected_round":expected}))

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
 for value in [Series.BO1,Series.BO1_SIDEBOARD,Series.BO3,Series.BO5,Series.BO2,Series.EXPLORATION,Series.EXPLORATION_RANDOM]:game_format_input.add_item(Series.format_label(value),value)
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
 custom_stages=CheckButton.new();parent.add_child(custom_stages);custom_stages.text="自定义阶段、局制、计分与晋级条件";app.ui_metrics.button(custom_stages)
 custom_stages.button_pressed=editing and not current.get("stages",[]).is_empty()
 custom_stages.disabled=locked;custom_stages.set_meta("page_disabled",locked)
 stage_form=preload("res://scripts/tournament_stage_form.gd").new();parent.add_child(stage_form)
 stage_form.begin(app,current.get("stages",[]) if editing else [],int(current.get("stage_index",0)) if locked else -1)
 stage_form.visible=custom_stages.button_pressed
 custom_stages.toggled.connect(func(enabled):stage_form.visible=enabled)
 text(parent,"勾选自定义后，阶段配置覆盖上方基础赛程和局制。支持瑞士轮、单败、双败、循环赛任意串联；每阶段独立局制与积分。",app.ui_metrics.small,app.MUTED)

func settings_payload() -> Dictionary:
 var stamp=parse_china_time(start_time_input.text)
 if mode=="configure" and int(current.get("start_at",0))>0 and start_time_input.text==china_time(int(current.start_at)):stamp=int(current.start_at)
 if stamp<=0:say("请输入有效比赛时间，格式为 YYYY-MM-DD HH:MM（北京时间）");return {}
 var payload={"format":FORMATS.keys()[format_input.selected],"swiss_rounds":int(rounds_input.value),"round_interval":int(interval_input.value*60),"game_format":game_format_input.get_selected_id(),"start_at":stamp}
 if custom_stages.button_pressed:
  if not stage_form.capture():return {}
  payload.stages=stage_form.stages
 return payload

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
 text(column,"比赛名称",app.ui_metrics.body,app.GOLD)
 title_input=LineEdit.new();column.add_child(title_input);title_input.text=str(current.title);title_input.max_length=40;title_input.custom_minimum_size.y=app.ui_metrics.hit
 text(column,"比赛描述（最多 2000 字，可留空）",app.ui_metrics.body)
 description_input=TextEdit.new();description_input.name="TournamentDescription";column.add_child(description_input);expand(description_input,true)
 description_input.custom_minimum_size.y=app.ui_metrics.hit*4;description_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 description_input.text=str(current.description)
 submit_button=action(body,"保存比赛描述",func():send_request({"action":"update_description","id":int(current.id),"title":title_input.text,"description":description_input.text}),true,"TournamentSaveDescription")
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
 build_join_requests(parent)
 build_limitless_management(parent)
 action(parent,"编辑比赛描述",show_description_editor,false,"TournamentEditDescription")
 action(parent,"删除比赛",confirm_delete,false,"TournamentDelete")
 if current.get("super_admin",false):
  action(parent,"账号权限与教程群组",app.community_management)
  if not current.get("rewards_paid",false):build_reward_fields(parent)
 if current.phase!="complete":
  if current.get("pairing_source","local")!="limitless":action(parent,"比赛设置",show_settings,false,"TournamentSettings")
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
 if int(result)==-2:return "自动判负" if pairing.bye else "双方判负"
 if pairing.bye:return "轮空（按本阶段规则计分）"
 if int(result)==-1:return "平局"
 return PlayerNameDisplay.caption(str(pairing.names[int(result)]))+" 获胜"

func build_pairings(parent: Node):
 if int(current.get("round_number",0))==0:
  text(parent,"首轮尚未开始。签到结束后，主办方可手动或定时开始首轮。",app.ui_metrics.body,app.MUTED);return
 var choice=OptionButton.new();choice.name="TournamentRoundHistory";parent.add_child(choice);expand(choice);app.ui_metrics.button(choice)
 choice.add_item("跟随最新轮次",0)
 for number in range(1,int(current.round_number)+1):choice.add_item("第 %d 轮" % number,number)
 choice.select(pairing_round)
 choice.item_selected.connect(func(index):pairing_round=choice.get_item_id(index);pairing_page=0;fetch_detail(int(current.id)))
 var historical=viewed_round!=int(current.round_number)
 if not my_pairing.is_empty() and not historical:
  text(parent,"我的对局",app.ui_metrics.body,app.GOLD)
  build_pairing(parent,my_pairing,true)
 var stage_name=STAGES.get(round_info.get("stage",""),round_info.get("stage",""))
 var index=int(round_info.get("stage_index",-1))
 if index>=0 and index<current.get("stages",[]).size():stage_name=str(current.stages[index].name)
 text(parent,"第 %d 轮 · %s%s" % [viewed_round,stage_name," · 历史签表" if historical else ""],app.ui_metrics.body,app.GOLD)
 for pairing in pairings:build_pairing(parent,pairing,false)
 pagination(body,pairing_page,pairing_pages,func():pairing_page-=1;fetch_detail(int(current.id)),func():pairing_page+=1;fetch_detail(int(current.id)))

func build_pairing(parent: Node,pairing: Dictionary,personal: bool):
 var panel=PanelContainer.new();parent.add_child(panel);expand(panel)
 panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 var column=VBoxContainer.new();panel.add_child(column)
 var location="无桌号（来源自动判定）" if int(pairing.table)<=0 and current.get("pairing_source","local")=="limitless" else "第 %d 桌" % int(pairing.table)
 text(column,"%s：%s vs %s" % [location,PlayerNameDisplay.caption(str(pairing.names[0])),"无对手" if pairing.bye and pairing.source=="limitless" else "轮空" if pairing.bye else PlayerNameDisplay.caption(str(pairing.names[1]))],app.ui_metrics.body,app.GOLD)
 if not str(pairing.get("external_match","")).is_empty():text(column,"Limitless 签位："+str(pairing.external_match),app.ui_metrics.small,app.GOLD)
 text(column,result_caption(pairing,pairing.result),app.ui_metrics.body)
 if pairing.get("scores",[null,null])[0]!=null:text(column,"大比分 %d : %d" % [int(pairing.scores[0]),int(pairing.scores[1])],app.ui_metrics.body)
 if pairing.result!=null:
  text(column,{"game":"游戏对战自动回填","agreement":"双方确认的结果","organizer":"主办方裁定","bye":"轮空","limitless":"Limitless 已公布的结果"}.get(pairing.source,""),app.ui_metrics.small,app.MUTED)
 elif pairing.source=="awaiting_limitless":text(column,"游戏已结束，等待在 Limitless 登记结果后同步。",app.ui_metrics.small,app.GOLD)
 elif pairing.game_active:text(column,"游戏对局进行中，成绩结束后自动回填。",app.ui_metrics.small,app.MUTED)
 elif not pairing.bye:
  for actor in range(2):
   if pairing.reports[actor]!=null:text(column,"%s 提交：%s" % [PlayerNameDisplay.caption(str(pairing.names[actor])),result_caption(pairing,pairing.reports[actor])],app.ui_metrics.small)
  if pairing.reports[0]!=null and pairing.reports[1]!=null and pairing.reports[0]!=pairing.reports[1]:text(column,"结果不一致，待双方重新确认或主办方裁定。",app.ui_metrics.small,app.GOLD)
 if not personal and current.owned and current.phase=="running" and not pairing.bye and viewed_round==int(current.round_number) and current.get("pairing_source","local")!="limitless":
  action(column,"主办方裁定" if pairing.result==null else "修正本桌结果",func():show_result_form(pairing,true),false,"TournamentJudge_"+str(int(pairing.id)))

func show_result_form(pairing: Dictionary,judge: bool):
 if busy:return
 mode="judge" if judge else "result";result_pairing=pairing.duplicate(true);clear_body();heading.text="主办方裁定" if judge else "比赛结果表"
 var column=scroll_body("TournamentResultScroll")
 text(column,"第 %d 桌：%s vs %s" % [int(pairing.table),PlayerNameDisplay.caption(str(pairing.names[0])),PlayerNameDisplay.caption(str(pairing.names[1]))],app.ui_metrics.body,app.GOLD)
 result_input=OptionButton.new();result_input.name="TournamentResultChoice";column.add_child(result_input)
 for winner in range(2):result_input.add_item(result_caption(pairing,winner),winner)
 if current.round_stage in ["swiss","round_robin"]:result_input.add_item("平局",2)
 app.ui_metrics.button(result_input)
 score_inputs=[]
 var scores=HBoxContainer.new();column.add_child(scores)
 for actor in range(2):
  text(scores,str(pairing.names[actor])+" 胜局",app.ui_metrics.small)
  var input=SpinBox.new();scores.add_child(input);input.min_value=0;input.max_value=3;input.custom_minimum_size.y=app.ui_metrics.hit;score_inputs.append(input)
 var target=3 if int(current.game_format)==Series.BO5 else 2 if int(current.game_format) in [Series.BO3,Series.BO2] else 1
 score_inputs[0].value=target
 result_input.item_selected.connect(func(_index):
  var winner=result_input.get_selected_id()
  var draw_score=0 if target==1 else 1
  score_inputs[0].value=target if winner==0 else draw_score if winner==2 else 0
  score_inputs[1].value=target if winner==1 else draw_score if winner==2 else 0)
 text(column,"裁定将直接计入成绩并允许推进轮次。" if judge else "结果表须由本桌对手确认后才计入成绩。双方意见不一致时，可修改结果或联系主办方裁定。",app.ui_metrics.small,app.MUTED)
 action(body,"确认裁定" if judge else "提交结果表",submit_result,true,"TournamentResultSubmit")

func submit_result():
 if busy:return
 var result=result_input.get_selected_id();result=-1 if result==2 else result
 var payload={"action":"judge_result" if mode=="judge" else "report_result","id":int(current.id),"pairing_id":int(result_pairing.id),"result":result,"revision":int(result_pairing.revision)}
 payload.scores=[int(score_inputs[0].value),int(score_inputs[1].value)]
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
 if current.get("pairing_source","local")=="limitless":
  text(parent,"Limitless 来源排名",app.ui_metrics.body,app.GOLD)
  text(parent,"名次与战绩采用 Limitless 已公布数据；积分与小分以来源网站为准。",app.ui_metrics.small,app.MUTED)
  for entry in standings:text(parent,"%s. %s · %d 胜 / %d 平 / %d 负" % [str(int(entry.rank)) if int(entry.rank)>0 else "未公布",str(entry.nickname),int(entry.wins),int(entry.draws),int(entry.losses)],app.ui_metrics.body)
  pagination(body,standing_page,standing_pages,func():standing_page-=1;fetch_detail(int(current.id)),func():standing_page+=1;fetch_detail(int(current.id)))
  return
 text(parent,"最终成绩（各阶段积分独立）" if current.phase=="complete" else "本阶段积分与名次",app.ui_metrics.body,app.GOLD)
 text(parent,points_caption(current.stages[int(current.get("stage_index",0))]) if not current.get("stages",[]).is_empty() else "胜 3 分 · 平 1 分 · 负 0 分 · 轮空 3 分。排序：积分、对手积分总和、胜场、抽签序号。",app.ui_metrics.small,app.MUTED)
 if standings.is_empty():text(parent,"签到结束后显示参赛排名。",app.ui_metrics.body,app.MUTED)
 for entry in standings:
  var suffix=" · 最终第 %d 名" % int(entry.placement) if entry.has("placement") else ""
  if entry.has("stage_name"):suffix+=" · "+str(entry.stage_name)
  suffix+={"advanced":" · 提前晋级","eliminated":" · 已淘汰"}.get(entry.get("state",""),"")
  text(parent,"%d. %s · %d 分 · 对手分 %d · %d 胜 / %d 平 / %d 负 · 轮空 %d%s" % [int(entry.rank),PlayerNameDisplay.caption(str(entry.nickname)),int(entry.points),int(entry.buchholz),int(entry.wins),int(entry.draws),int(entry.losses),int(entry.byes),suffix],app.ui_metrics.body)
 pagination(body,standing_page,standing_pages,func():standing_page-=1;fetch_detail(int(current.id)),func():standing_page+=1;fetch_detail(int(current.id)))

func say(message: String):
 notice.text=message;notice.visible=not message.is_empty()

func build_join_requests(parent: Node):
 if limitless.is_empty():return
 text(parent,"选手身份审核 · 待审核 %d 人" % int(join_requests.get("total",0)),app.ui_metrics.body,app.GOLD)
 text(parent,"请到来源赛事核对账号 ID，并通过赛事群或本人确认真实身份；填写 ID 本身不能证明账号归属。",app.ui_metrics.small,app.MUTED)
 for entry in join_requests.get("entries",[]):
  text(parent,PlayerNameDisplay.caption(str(entry.nickname))+"（游戏账号："+str(entry.username)+"） · Limitless ID："+str(entry.external_player),app.ui_metrics.body)
  action(parent,"查看来源选手 "+str(entry.external_player),func():OS.shell_open(str(limitless.url)+"/player/"+str(entry.external_player)))
  var row=HFlowContainer.new();parent.add_child(row)
  action(row,"确认本人，通过",func():app.confirm_action("已核实 %s 是 Limitless 选手 %s 本人？通过后将纳入参赛名单。" % [str(entry.username),str(entry.external_player)],func():review_join(entry,true)),true,"TournamentApprove_"+str(int(entry.player_id)))
  action(row,"拒绝",func():review_join(entry,false),false,"TournamentReject_"+str(int(entry.player_id)))
 pagination(parent,request_page,int(join_requests.get("pages",1)),func():request_page-=1;fetch_detail(int(current.id)),func():request_page+=1;fetch_detail(int(current.id)))

func review_join(entry: Dictionary,approve: bool):
 send_request({"action":"review_limitless_join","id":int(current.id),"player_id":int(entry.player_id),"revision":int(entry.revision),"approve":approve})

func build_limitless_management(parent: Node):
 text(parent,"Limitless 赛事来源",app.ui_metrics.body,app.GOLD)
 text(parent,"绑定后由 Limitless 决定签表与正式赛果。每轮须先有来源签表，上轮赛果须已公布。游戏结束后请在来源网站登记赛果再同步。",app.ui_metrics.small,app.MUTED)
 text(parent,"实时双败树目前仅支持查看，不能导入游戏内开轮。",app.ui_metrics.small,app.MUTED)
 if int(current.get("round_number",0))==0 and current.phase!="complete":
  var url=LineEdit.new();url.name="TournamentLimitlessURL";parent.add_child(url);expand(url)
  url.placeholder_text="https://play.limitlesstcg.com/tournament/…";url.text=str(limitless.get("url",""))
  var automatic=CheckButton.new();automatic.name="TournamentLimitlessAuto";parent.add_child(automatic);automatic.text="每 2 分钟自动同步";automatic.button_pressed=limitless.get("auto_sync",true);app.ui_metrics.button(automatic)
  action(parent,"绑定并同步 Limitless",func():send_request({"action":"link_limitless","id":int(current.id),"url":url.text,"auto_sync":automatic.button_pressed}),true,"TournamentLimitlessLink")
 if limitless.is_empty():return
 limitless_status(parent)
 if current.phase!="complete":action(parent,"同步 Limitless 最新数据",func():mutate("sync_limitless"),false,"TournamentLimitlessSync")
 if int(current.get("round_number",0))==0:
  action(parent,"解除 Limitless 绑定",func():app.confirm_action("解除绑定后将恢复游戏内编排，是否继续？",func():mutate("unlink_limitless")),false,"TournamentLimitlessUnlink")
  if int(limitless.get("synced_at",0))>0:
   text(parent,"选手账号对应关系（每行 Limitless用户名=游戏账号）",app.ui_metrics.body,app.GOLD)
   text(parent,"来源用户名："+", ".join(limitless.get("external_players",[])),app.ui_metrics.small,app.MUTED)
   var mapping=TextEdit.new();mapping.name="TournamentLimitlessMapping";parent.add_child(mapping);expand(mapping);mapping.custom_minimum_size.y=app.ui_metrics.hit*5
   mapping.text=str(limitless.get("mapping",""));mapping.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
   action(parent,"保存选手对应关系",func():send_request({"action":"map_limitless","id":int(current.id),"mapping":mapping.text}),true,"TournamentLimitlessSaveMapping")
 elif current.phase=="running":
  action(parent,"关闭自动同步" if limitless.get("auto_sync",false) else "开启自动同步",func():send_request({"action":"link_limitless","id":int(current.id),"url":str(limitless.url),"auto_sync":not limitless.get("auto_sync",false)}),false,"TournamentLimitlessToggleAuto")
  action(parent,"按 Limitless 最终排名结束比赛",func():app.confirm_action("请先确认 Limitless 赛事已经结束并公布最终排名。将按来源排名发放奖励，是否结束比赛？",func():send_request({"action":"complete_limitless","id":int(current.id),"finished":true})),false,"TournamentLimitlessComplete")

func limitless_status(parent: Node):
 var stamp=int(limitless.get("synced_at",0))
 text(parent,str(limitless.get("title","Limitless")),app.ui_metrics.body,app.GOLD)
 text(parent,"上次成功同步："+(china_time(stamp) if stamp>0 else "尚未成功")+(" · 同步中" if limitless.get("syncing",false) else "")+(" · 已封存" if current.phase=="complete" else ""),app.ui_metrics.small,app.MUTED)
 var failure=str(limitless.get("error",""))
 if not failure.is_empty():text(parent,failure,app.ui_metrics.small,app.GOLD)

func build_limitless(parent: Node):
 limitless_status(parent)
 text(parent,"Limitless 未公布的数据需等待来源更新。平局、双方判负、轮空分别展示；来源 API 不提供逐局比分。",app.ui_metrics.small,app.MUTED)
 action(parent,"在浏览器打开来源签表",func():OS.shell_open(str(limitless.url)+"/pairings"),false,"TournamentLimitlessOpen")
 if current.owned and current.phase!="complete":action(parent,"同步最新数据",func():mutate("sync_limitless"),false,"TournamentLimitlessSync")
 var tabs=HFlowContainer.new();parent.add_child(tabs)
 for entry in [["pairings","来源签表与赛果"],["standings","来源排名"]]:
  action(tabs,entry[1],func():external_view=entry[0];external_page=0;fetch_detail(int(current.id)),external_view==entry[0])
 if not limitless.has("entries"):
  text(parent,"正在等待签表数据，请刷新。",app.ui_metrics.body,app.MUTED);return
 if external_view=="pairings":
  var rounds=limitless.get("rounds",[])
  var choice=OptionButton.new();choice.name="TournamentLimitlessRound";parent.add_child(choice);expand(choice);app.ui_metrics.button(choice)
  choice.add_item("跟随来源最新轮次",0)
  for index in range(rounds.size()):
   var item=rounds[index];choice.add_item("第 %d 阶段 · 第 %d 轮" % [int(item.phase),int(item.round)],index+1)
   if external_phase==int(item.phase) and external_round==int(item.round):choice.select(index+1)
  choice.item_selected.connect(func(index):
   external_phase=0 if index==0 else int(rounds[index-1].phase);external_round=0 if index==0 else int(rounds[index-1].round)
   external_page=0;fetch_detail(int(current.id)))
  text(parent,"第 %d 阶段 · 第 %d 轮" % [int(limitless.get("phase",0)),int(limitless.get("round",0))],app.ui_metrics.body,app.GOLD)
  for entry in limitless.entries:
   var location=str(entry.match) if not str(entry.match).is_empty() else "第 %d 桌" % int(entry.table) if int(entry.table)>0 else "无桌号（来源自动判定）"
   var opponent="轮空 / 自动判负" if str(entry.players[1]).is_empty() else str(entry.names[1])
   var result={"pending":"尚未公布结果","tie":"平局","double_loss":"双方判负","auto_loss":"自动判负","bye":"轮空获胜","a":str(entry.names[0])+" 获胜","b":str(entry.names[1])+" 获胜"}.get(entry.result,"")
   text(parent,"%s：%s vs %s · %s" % [location,str(entry.names[0]),opponent,result],app.ui_metrics.body)
 else:
  for entry in limitless.entries:
   text(parent,"%s. %s · %d 胜 / %d 平 / %d 负%s" % [str(int(entry.placing)) if int(entry.placing)>0 else "未公布",str(entry.name),int(entry.wins),int(entry.ties),int(entry.losses)," · 已退赛" if entry.drop else ""],app.ui_metrics.body)
 if limitless.entries.is_empty():text(parent,"Limitless 尚未公布此项数据。",app.ui_metrics.body,app.MUTED)
 pagination(body,int(limitless.get("page",0)),int(limitless.get("pages",1)),func():external_page=maxi(0,external_page-1);fetch_detail(int(current.id)),func():external_page+=1;fetch_detail(int(current.id)))

func points_caption(stage: Dictionary) -> String:
 var points=stage.points
 var value="胜 %d / 平 %d / 负 %d / 轮空 %d 分" % [int(points.win),int(points.draw),int(points.loss),int(points.bye)]
 for key in points.get("scores",{}):value+=" · %s=%d分" % [key,int(points.scores[key])]
 var advance=stage.advance
 value+=" · 达到 %d 分晋级" % int(advance.points) if advance.mode=="points" else " · 前 %d 名晋级" % int(advance.count) if advance.mode=="rank" else " · 未淘汰选手晋级"
 return value

func build_reward_fields(parent: Node):
 text(parent,"赛事铜钱奖励（超级管理员可修改）",app.ui_metrics.body,app.GOLD)
 var inputs={}
 for key in ["champion","runner_up","semifinalist"]:
  text(parent,{"champion":"冠军","runner_up":"亚军","semifinalist":"四强每人"}[key],app.ui_metrics.small)
  var input=SpinBox.new();parent.add_child(input);input.max_value=1000000;input.value=int(current.get("rewards",{}).get(key,0));input.custom_minimum_size.y=app.ui_metrics.hit;inputs[key]=input
 action(parent,"保存铜钱奖励",func():
  var rewards={}
  for key in inputs:rewards[key]=int(inputs[key].value)
  send_request({"action":"update_rewards","id":int(current.id),"rewards":rewards}))
