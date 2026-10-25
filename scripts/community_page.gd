extends Control
var app
var body: VBoxContainer
var notice: Label
var rows: VBoxContainer
var busy=false
var tab="reviews"
var latest: Dictionary={}

func _ready():
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
 busy=true;notice.text="正在连接服务器…"
 app.online_community().request(payload,func(answer):
  if not is_instance_valid(self):return
  busy=false;notice.text=str(answer.get("message",""))
  if answer.get("ok",false):callback.call(answer))

func refresh():
 request({"action":"submissions"},build)

func build(answer: Dictionary):
 latest=answer
 app.free_children(rows)
 if app.online_community().allowed("super_admin"):
  var tabs=HFlowContainer.new();rows.add_child(tabs)
  for item in [["reviews","教程审核"],["roles","成员权限"],["announcements","公告发布"]]:
   action(tabs,item[1],func():tab=item[0];build(latest))
  if tab!="reviews":build_admin();return
 label_text(rows,"群组成员可编辑旧教程或新增教程；提交后由 bigcake 审核，批准后所有玩家打开教程时自动同步。")
 action(rows,"新增教程",app.tutorial_editor)
 label_text(rows,"待审及历史提交",true)
 for submission in answer.get("submissions",[]):
  label_text(rows,"#%d · %s · %s · %s" % [int(submission.id),str(submission.lesson_id),str(submission.author),{"pending":"待审核","approved":"已批准","rejected":"已退回"}.get(submission.status,submission.status)])
  if not str(submission.get("note","")).is_empty():label_text(rows,submission.note)
  action(rows,"审阅教程" if app.online_community().allowed("super_admin") and submission.status=="pending" else "查看提交",func():
   request({"action":"submission","id":int(submission.id)},func(detail):app.tutorial_review(detail.document,int(submission.id) if submission.status=="pending" else 0,int(detail.base_revision))))

func build_admin():
 label_text(rows,"bigcake · 超级管理员",true)
 if tab=="announcements":build_announcement();return
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
 var lines=["bigcake：超级管理员（所有权限）"]
 for entry in answer.get("roles",[]):lines.append(str(entry.username)+"："+("赛事管理员" if entry.role=="tournament_admin" else "教程群组成员"))
 app.alert("\n".join(lines),"群组成员")
