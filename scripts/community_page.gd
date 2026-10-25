extends Control
var app
var body: VBoxContainer
var notice: Label
var rows: VBoxContainer
var busy=false
var tab="reviews"
var latest: Dictionary={}
var grant_kind=0
var grant_target=""
var grant_amount=1
var grant_kind_input: OptionButton
var grant_target_input: LineEdit
var grant_amount_input: SpinBox
var grant_button: Button

func _ready():
 var pending=app.online_community().pending_coin_grant()
 if not pending.is_empty():
  tab="coins";grant_kind=1 if pending.has("target_player_id") else 0
  grant_target=str(int(pending.target_player_id)) if grant_kind==1 else str(pending.target_username)
  grant_amount=int(pending.coins)
 name="CommunityManagement";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 body=VBoxContainer.new();margin.add_child(body)
 var header=HBoxContainer.new();body.add_child(header)
 label_text(header,"教程群组与超级管理员",true)
 action(header,"刷新",refresh);action(header,"返回教程",app.tutorials)
 notice=label_text(body,"")
 var scroll=ScrollContainer.new();body.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 rows=VBoxContainer.new();scroll.add_child(rows);rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 refresh()

func action(parent: Node,caption: String,callback: Callable) -> Button:
 var button=app.button(parent,caption,Rect2(),callback);app.ui_metrics.button(button);return button

func label_text(parent: Node,caption: String,title: bool=false) -> Label:
 var label=Label.new();parent.add_child(label);label.text=caption;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",app.ui_metrics.title if title else app.ui_metrics.body)
 return label

func field(parent: Node,caption: String,value: String="") -> LineEdit:
 label_text(parent,caption)
 var control=LineEdit.new();parent.add_child(control);control.text=value;control.custom_minimum_size.y=app.ui_metrics.hit
 return control

func request(payload: Dictionary,callback: Callable):
 if busy:return
 busy=true;notice.text="正在连接服务器…";update_grant_controls()
 app.online_community().request(payload,func(answer):
  if not is_instance_valid(self):return
  busy=false;notice.text=str(answer.get("message",""));update_grant_controls()
  if answer.get("ok",false):callback.call(answer))

func refresh():
 request({"action":"submissions"},build)

func build(answer: Dictionary):
 latest=answer
 app.free_children(rows)
 if app.online_community().allowed("super_admin"):
  var tabs=HFlowContainer.new();rows.add_child(tabs)
  for item in [["reviews","教程审核"],["roles","成员权限"],["announcements","公告发布"],["coins","赠予铜钱"]]:
   action(tabs,item[1],func():tab=item[0];build(latest))
  if tab!="reviews":build_admin();return
 label_text(rows,"群组成员可编辑旧教程或新增教程；提交后由超级管理员审核，批准后所有玩家打开教程时自动同步。")
 action(rows,"新增教程",app.tutorial_editor)
 label_text(rows,"待审及历史提交",true)
 for submission in answer.get("submissions",[]):
  label_text(rows,"#%d · %s · %s · %s" % [int(submission.id),str(submission.lesson_id),str(submission.author),{"pending":"待审核","approved":"已批准","rejected":"已退回"}.get(submission.status,submission.status)])
  if not str(submission.get("note","")).is_empty():label_text(rows,submission.note)
  action(rows,"审阅教程" if app.online_community().allowed("super_admin") and submission.status=="pending" else "查看提交",func():
   request({"action":"submission","id":int(submission.id)},func(detail):app.tutorial_review(detail.document,int(submission.id) if submission.status=="pending" else 0,int(detail.base_revision))))

func build_admin():
 label_text(rows,"超级管理员",true)
 if tab=="announcements":build_announcement();return
 if tab=="coins":build_coin_grant();return
 label_text(rows,"bigcake 固定属于超级管理员组；该组拥有全部管理权限，包括赠予铜钱。")
 var username=field(rows,"玩家账号（不是昵称）")
 var role=OptionButton.new();rows.add_child(role);role.add_item("赛事管理员");role.add_item("教程群组成员");app.ui_metrics.button(role)
 var tools=HFlowContainer.new();rows.add_child(tools)
 for enabled in [true,false]:
  action(tools,"加入" if enabled else "移除",func():
   request({"action":"set_role","username":username.text.strip_edges(),"role":"tournament_admin" if role.selected==0 else "tutorial_editor","enabled":enabled},show_roles))
 action(tools,"查看成员",func():request({"action":"roles"},show_roles))

func build_announcement():
 label_text(rows,"发布公告与铜钱奖励",true)
 var id=field(rows,"公告 ID（相同 ID 每个账号只可领取一次）")
 var version=field(rows,"公告版本",str(ProjectSettings.get_setting("application/config/version")))
 var title=field(rows,"公告标题")
 var content=TextEdit.new();rows.add_child(content);content.placeholder_text="公告正文";content.custom_minimum_size.y=app.ui_metrics.hit*4;content.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 var amount=SpinBox.new();rows.add_child(amount);amount.max_value=1000000;amount.suffix=" 铜钱";amount.custom_minimum_size.y=app.ui_metrics.hit
 action(rows,"发布公告",func():
  request({"action":"publish_announcement","entry":{"id":id.text.strip_edges(),"version":version.text.strip_edges(),"title":title.text,"body":content.text},"coins":int(amount.value)},func(result):notice.text=result.message))

func show_roles(answer: Dictionary):
 var lines=[]
 var names={"super_admin":"超级管理员","tournament_admin":"赛事管理员","tutorial_editor":"教程群组成员"}
 for entry in answer.get("roles",[]):
  lines.append(str(entry.username)+"："+str(names.get(entry.role,entry.role))+("（固定成员）" if str(entry.username).to_lower()=="bigcake" and entry.role=="super_admin" else ""))
 app.alert("\n".join(lines),"群组成员")

func build_coin_grant():
 label_text(rows,"为玩家赠予铜钱",true)
 label_text(rows,"仅超级管理员可使用。铜钱直接增加到目标玩家余额；单次可赠予 1–1,000,000 铜钱。")
 if not app.online_community().pending_coin_grant().is_empty():label_text(rows,"上次赠予尚未确认，可保持目标和金额重试；同一次赠予不会重复发放。")
 grant_kind_input=OptionButton.new();grant_kind_input.name="CoinGrantTargetKind";rows.add_child(grant_kind_input)
 grant_kind_input.add_item("登录账号 ID");grant_kind_input.add_item("数字玩家 ID");grant_kind_input.select(grant_kind);app.ui_metrics.button(grant_kind_input)
 grant_target_input=field(rows,"目标玩家 ID（不是昵称）",grant_target);grant_target_input.name="CoinGrantTarget"
 grant_target_input.placeholder_text="输入玩家的登录账号" if grant_kind==0 else "输入数字玩家 ID"
 label_text(rows,"赠予数额")
 grant_amount_input=SpinBox.new();grant_amount_input.name="CoinGrantAmount";rows.add_child(grant_amount_input)
 grant_amount_input.min_value=1;grant_amount_input.max_value=1000000;grant_amount_input.step=1;grant_amount_input.rounded=true
 grant_amount_input.value=grant_amount;grant_amount_input.suffix=" 铜钱";grant_amount_input.custom_minimum_size.y=app.ui_metrics.hit
 grant_button=action(rows,"赠予铜钱",submit_coin_grant);grant_button.name="GrantCoins"
 grant_kind_input.item_selected.connect(func(index):grant_kind=index;grant_target="";build(latest))
 grant_target_input.text_changed.connect(func(value):grant_target=value;update_grant_controls())
 grant_amount_input.value_changed.connect(func(value):grant_amount=int(value))
 update_grant_controls()

func update_grant_controls():
 if not is_instance_valid(grant_button):return
 grant_button.disabled=busy or grant_target.strip_edges().is_empty() or not app.online_community().allowed("super_admin")
 grant_kind_input.disabled=busy;grant_target_input.editable=not busy;grant_amount_input.editable=not busy

func submit_coin_grant():
 if busy or not app.online_community().allowed("super_admin"):return
 var target=grant_target.strip_edges()
 if target.is_empty():notice.text="请填写目标玩家 ID";return
 var payload={"action":"grant_coins","coins":grant_amount}
 if grant_kind==0:payload.target_username=target
 else:
  if not target.is_valid_int() or int(target)<1 or int(target)>9007199254740991:notice.text="数字玩家 ID 须为有效的正整数";return
  payload.target_player_id=int(target)
 var prepared=app.online_community().prepare_coin_grant(payload)
 request(prepared,func(_answer):
  app.online_community().confirm_coin_grant(str(prepared.request_id));grant_target=""
  if tab=="coins":build(latest)
  app.refresh_tasks())
