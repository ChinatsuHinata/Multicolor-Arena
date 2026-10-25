extends "res://scripts/modal_menu.gd"
const TITLES=["每日任务","赛季任务","成就任务"]
const CardInspection=preload("res://scripts/card_inspection.gd")
const CoinIcon=preload("res://scripts/coin_icon.gd")
const COIN_VICTORY_CARD="character-kmo-001"
var selected=0
var tabs: Array[Button]=[]
var content: VBoxContainer
var balance: Label
var notice: Label
var refresh_button: Button
var card_overlay: Control
var card_panel: PanelContainer
var inspected_card=""
var card_focus: WeakRef

func build_tasks(app):
 super.build(app,"任务",[])
 name="TaskPopup";panel.name="TaskPanel";scroll.name="TaskScroll"
 panel.add_theme_stylebox_override("panel",host.style(host.INK,host.GOLD))
 var header=heading.get_parent()
 balance=coin_value(header,"",host.ui_metrics.body,"TaskWallet");balance.name="TaskBalance"
 header.move_child(balance.get_parent(),close_button.get_index())
 var bar=HBoxContainer.new();bar.name="TaskTabs";body.add_child(bar);body.move_child(bar,1)
 for index in range(TITLES.size()):
  var tab=host.button(bar,TITLES[index],Rect2(),select_tab.bind(index))
  tab.name="TaskTab"+str(index);tab.toggle_mode=true;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  host.ui_metrics.button(tab);tabs.append(tab)
 content=scroll.get_child(0)
 notice=add_text(body,"",host.ui_metrics.small,host.MUTED);notice.name="TaskSyncStatus"
 refresh_button=host.button(header,"刷新",Rect2(),host.refresh_tasks);host.ui_metrics.button(refresh_button);refresh_button.name="RefreshTasks"
 header.move_child(refresh_button,close_button.get_index())
 panel.minimum_size_changed.connect(func():call_deferred("relayout"))
 host.task_service.changed.connect(render)
 render();relayout()

func select_tab(index: int):
 selected=index;render();scroll.scroll_vertical=0

func add_text(parent: Node,value: String,font: int,color: Color) -> Label:
 var label=Label.new();parent.add_child(label);label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",font);label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return label

func task_text(parent: Node,value: String,font: int,color: Color,refs: Array) -> Control:
 if refs.is_empty() and not value.contains("铜钱"):return add_text(parent,value,font,color)
 var label=RichTextLabel.new();parent.add_child(label)
 label.fit_content=true;label.scroll_active=false;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.focus_mode=Control.FOCUS_NONE if refs.is_empty() else Control.FOCUS_ALL
 label.add_theme_font_size_override("normal_font_size",font);label.add_theme_color_override("default_color",color)
 label.meta_clicked.connect(func(id):show_card_details(str(id)))
 label.meta_hover_started.connect(func(_id):label.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND)
 label.meta_hover_ended.connect(func(_id):label.mouse_default_cursor_shape=Control.CURSOR_ARROW)
 var offset=0
 while offset<value.length():
  var found=-1;var chosen={};var chosen_text=""
  for ref in refs:
   if not ref is Dictionary or not host.Store.CARDS.has(str(ref.get("id",""))):continue
   var name=str(ref.get("text",ref.get("name","")))
   if name.is_empty():continue
   var at=value.find(name,offset)
   if at>=0 and (found<0 or at<found or at==found and name.length()>chosen_text.length()):found=at;chosen=ref;chosen_text=name
  var coin_at=value.find("铜钱",offset)
  if coin_at>=0 and (found<0 or coin_at<found):
   label.add_text(value.substr(offset,coin_at-offset));label.add_image(CoinIcon.texture(font),font,font)
   offset=coin_at+2;continue
  if found<0:label.add_text(value.substr(offset));break
  label.add_text(value.substr(offset,found-offset));label.push_meta(str(chosen.id));label.push_color(host.GOLD)
  label.add_text(chosen_text);label.pop();label.pop()
  offset=found+chosen_text.length()
 return label

func coin_value(parent: Node,value: String,font: int,node_name: String) -> Label:
 var row=HBoxContainer.new();parent.add_child(row);row.name=node_name
 row.size_flags_horizontal=Control.SIZE_SHRINK_END;row.add_theme_constant_override("separation",int(host.ui_metrics.gap*0.3))
 var icon=CoinIcon.new();row.add_child(icon);icon.name="CoinIcon"
 icon.custom_minimum_size=Vector2(font*1.1,font*1.1);icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var amount=add_text(row,value,font,host.GOLD);amount.autowrap_mode=TextServer.AUTOWRAP_OFF
 amount.size_flags_horizontal=Control.SIZE_SHRINK_END
 return amount

func task_row(title: String,detail: String,reward: int,state: String,node_name: String,refs: Array=[]) -> VBoxContainer:
 var tile=PanelContainer.new();content.add_child(tile);tile.name=node_name
 tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 var column=VBoxContainer.new();tile.add_child(column)
 var row=HBoxContainer.new();column.add_child(row)
 var caption=task_text(row,title,host.ui_metrics.body,host.WHITE,refs);caption.name="TaskTitle";caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 coin_value(row,str(reward),host.ui_metrics.body,"TaskReward")
 if not detail.is_empty():task_text(column,detail,host.ui_metrics.small,host.MUTED,refs).name="TaskDetail"
 var progress=add_text(column,state,host.ui_metrics.small,host.GOLD);progress.name="TaskProgress"
 return column

func draw_reroll(control: Button):
 var center=control.size*0.5
 var radius=minf(control.size.x,control.size.y)*0.19
 var color=host.MUTED if control.disabled else host.GOLD
 control.draw_arc(center,radius,PI*0.2,PI*1.9,28,color,2.0,true)
 var end=center+Vector2.from_angle(PI*1.9)*radius
 control.draw_colored_polygon(PackedVector2Array([end+Vector2(-radius*0.5,-radius*0.25),end+Vector2(radius*0.3,-radius*0.5),end+Vector2(radius*0.3,radius*0.4)]),color)

func daily_row(task: Dictionary):
 var service=host.task_service
 var claimed=bool(task.get("claimed",false))
 var complete=bool(task.get("completed",false))
 var progress="%s %d / %d" % ["最高连胜" if task.get("group","")=="ranked_streak" else "单场最高" if task.get("aggregation","")=="max" else "累计",int(task.get("progress",0)),int(task.get("target",1))]
 var state=progress+" · "+("已领取" if claimed else "已完成，待领取" if complete else "进行中")
 var slot=str(int(task.get("slot",0)))
 var refs=task.get("card_refs",[]) if task.get("card_refs",[]) is Array else []
 var title=str(task.get("title",""));var detail=str(task.get("detail",""))
 # Presentation also applies to today's frozen definitions from the live server.
 if task.get("key","")=="special_win:coin":
  title="段位匹配投钱胜利 1 次";detail="使敌方具有三个或更多铜钱指示物并获胜。"
  refs=[{"id":COIN_VICTORY_CARD,"name":host.Store.CARDS[COIN_VICTORY_CARD].name,"text":"投钱"}]
 var column=task_row(title,detail,int(task.get("reward",0)),state,"DailyTask"+slot,refs)
 var header=column.get_child(0)
 var reroll=host.button(header,"",Rect2(),service.reroll.bind(task))
 host.ui_metrics.button(reroll);reroll.name="RerollTask"+slot
 reroll.custom_minimum_size=Vector2(host.ui_metrics.hit,host.ui_metrics.hit)
 reroll.disabled=claimed or bool(task.get("rerolled",false)) or is_instance_valid(service.client) or service.daily_expired()
 reroll.tooltip_text="已领取的任务不能更换" if claimed else "今日已更换一次" if task.get("rerolled",false) else "更换一次：进度清零，不会换回同一任务；已完成但未领取的奖励也会放弃"
 reroll.draw.connect(draw_reroll.bind(reroll))
 if complete and not claimed:
  var claim=host.button(column,"领取 %d" % int(task.get("reward",0)),Rect2(),service.claim.bind(task),true)
  host.ui_metrics.button(claim);claim.name="ClaimTask"+slot
  claim.icon=CoinIcon.texture(host.ui_metrics.button_font);claim.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  claim.size_flags_horizontal=Control.SIZE_SHRINK_END
  claim.disabled=is_instance_valid(service.client) or service.daily_expired()

func collect_buttons(parent: Node,result: Array[Button]):
 for child in parent.get_children():
  if child is Button and not child.disabled:result.append(child)
  collect_buttons(child,result)

func render():
 if not is_instance_valid(content):return
 for child in content.get_children():content.remove_child(child);child.queue_free()
 for index in range(tabs.size()):tabs[index].set_pressed_no_signal(index==selected)
 var service=host.task_service
 var data: Dictionary=service.snapshot
 var logged_in=not service.account.is_empty()
 balance.text=str(int(data.coins)) if data.has("coins") else "—"
 notice.text=service.error if not service.error.is_empty() else "正在同步任务…" if is_instance_valid(service.client) else "" if logged_in else "登录后同步任务与余额"
 notice.visible=not notice.text.is_empty()
 refresh_button.disabled=is_instance_valid(service.client) or not logged_in
 if not logged_in:
  var login=host.button(content,"登录账号",Rect2(),host.task_login);host.ui_metrics.button(login)
 if selected==0:
  var daily: Dictionary=data.get("daily",{})
  add_text(content,"北京时间 06:00 刷新 · 完成后领取",host.ui_metrics.small,host.MUTED)
  if service.daily_expired():add_text(content,"正在更新今日任务…",host.ui_metrics.body,host.GOLD)
  elif daily.get("tasks") is Array:
   for task in daily.tasks:daily_row(task)
  else:add_text(content,"登录并同步后显示今日任务" if not logged_in else "每日任务待同步",host.ui_metrics.body,host.MUTED)
  task_text(content,"每日随机 2 条初级任务各 1 铜钱，1 条高级任务 3 铜钱。每条可更换一次，更换后进度清零；仅自动匹配计入。",host.ui_metrics.small,host.MUTED,[])
  if daily.has("day"):add_text(content,"任务日期："+str(daily.day),host.ui_metrics.small,host.MUTED)
 elif selected==1:
  var season: Dictionary=data.get("season",{})
  add_text(content,str(season.get("title","当前赛季"))+" · 赛季结束后按最终段位／名次自动结算，只发最高档",host.ui_metrics.small,host.MUTED)
  if season.get("ends_at")!=null:
   add_text(content,"结束时间："+Time.get_datetime_string_from_unix_time(int(season.ends_at)+8*3600).replace("T"," ")+"（北京时间）",host.ui_metrics.small,host.GOLD).name="SeasonEndTime"
  for entry in [["第 11 名+","达到贤者段位。",12],["第 4–10 名","贤者段位排名。",20],["第 2–3 名","贤者段位排名。",28],["第 1 名","贤者段位榜首。",40]]:
   task_row(entry[0],entry[1],entry[2],"赛季结束时结算","SeasonReward"+str(entry[2]))
  var previous: Dictionary=data.get("previous",{})
  if not previous.is_empty():
   task_text(content,"%s：贤者第%d名，已发放%d铜钱" % [previous.title,int(previous.position),int(previous.coins)] if int(previous.get("position",0))>0 else str(previous.title)+"：未达贤者，无赛季奖励",host.ui_metrics.small,host.GOLD,[]).name="PreviousSeasonReward"
 else:
  add_text(content,"暂无成就任务",host.ui_metrics.body,host.MUTED).name="EmptyAchievements"
 var focus_buttons: Array[Button]=[close_button]
 focus_buttons.append_array(tabs)
 if not refresh_button.disabled:focus_buttons.append(refresh_button)
 collect_buttons(content,focus_buttons)
 for index in range(focus_buttons.size()):
  var button=focus_buttons[index]
  var previous=button.get_path_to(focus_buttons[(index-1+focus_buttons.size())%focus_buttons.size()])
  var next=button.get_path_to(focus_buttons[(index+1)%focus_buttons.size()])
  button.focus_previous=previous;button.focus_next=next
  button.focus_neighbor_left=previous;button.focus_neighbor_right=next
 call_deferred("relayout")

func relayout():
 if not is_instance_valid(panel):return
 var safe=host.ui_metrics.safe
 panel.size=Vector2(minf(1280 if host.is_android else 940,safe.size.x),safe.size.y if host.is_android else minf(770,safe.size.y))
 panel.position=safe.position+(safe.size-panel.size)*0.5
 fit_card_details()

func show_card_details(id: String):
 if not host.Store.CARDS.has(id):return
 close_card_details()
 var focused=get_viewport().gui_get_focus_owner()
 card_focus=weakref(focused) if is_instance_valid(focused) else null
 inspected_card=id
 card_overlay=Control.new();card_overlay.name="TaskCardDetails";backdrop.add_child(card_overlay)
 card_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();card_overlay.add_child(shade);shade.color=Color(0,0,0,0.8)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_card_details())
 card_panel=PanelContainer.new();card_panel.name="TaskCardDetailPanel";card_overlay.add_child(card_panel)
 card_panel.add_theme_stylebox_override("panel",host.ui_metrics.panel_style());fit_card_details()
 var column=VBoxContainer.new();card_panel.add_child(column)
 var header=HBoxContainer.new();column.add_child(header)
 add_text(header,"卡牌详情",host.ui_metrics.title,host.GOLD)
 var close=host.button(header,"返回任务",Rect2(),close_card_details);host.ui_metrics.button(close);close.name="CloseTaskCardDetails"
 var panes=HBoxContainer.new();column.add_child(panes);CardInspection.expand(panes,true)
 CardInspection.artwork(host,panes,id,{})
 CardInspection.rules(host,panes,id,maxf(100,(card_panel.size.x-host.ui_metrics.padding*2-host.ui_metrics.gap)*0.5))
 close.grab_focus()

func fit_card_details():
 if not is_instance_valid(card_panel):return
 var safe=host.ui_metrics.safe
 card_panel.size=Vector2(minf(1200,safe.size.x),safe.size.y if host.is_android else minf(770,safe.size.y))
 card_panel.position=safe.position+(safe.size-card_panel.size)*0.5

func close_card_details():
 if is_instance_valid(card_overlay):backdrop.remove_child(card_overlay);card_overlay.queue_free()
 card_overlay=null;card_panel=null;inspected_card=""
 var focused=card_focus.get_ref() if card_focus!=null else null
 card_focus=null
 if is_instance_valid(focused) and focused.is_visible_in_tree():focused.grab_focus()

func _input(event: InputEvent):
 if is_instance_valid(card_overlay):
  if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
   get_viewport().set_input_as_handled();close_card_details()
  elif host.is_android:swipe.handle(event,card_overlay)
  return
 super._input(event)
