extends Control
const Duel=preload("res://scripts/rules/duel_engine.gd")
var host
var engine
var table
var ui: Control
var local: Dictionary={}
var selection: Array=[]
var auto_pay=true
var full_response=false
var modal=false
var modal_root: Control
var view_zoom=0.82
var clock_time=0.0
var last_revision=-1
var message=""
var fast_mode=false
var phase_names={"mulligan":"起手调度","reset":"重置","prepare":"准备","draw":"抓牌","possession":"凭依","main":"主要","end":"结束","over":"对局结束"}
func begin(parent, a: Dictionary,b: Dictionary,first: int,seed_value: int=0):
 host=parent
 engine=Duel.new()
 engine.start(a,b,first,seed_value)
 render()
func _process(delta):
 if engine==null or modal or not local.is_empty() or engine.winner!=-2: return
 clock_time+=delta
 if clock_time<(0.02 if fast_mode else 0.75): return
 clock_time=0
 var before=engine.revision
 if engine.phase=="mulligan":
  if not engine.players[1].mulligan_done: engine.ai_step()
 elif not engine.pending.is_empty():
  if engine.pending.owner==1: engine.ai_step()
 elif engine.priority==1: engine.ai_step()
 elif not full_response:
  if engine.phase!="main" or not engine.combat.is_empty() or not engine.stack.is_empty():
   if engine.legal_casts(0,true).is_empty(): engine.pass_priority(0)
 if before!=engine.revision or last_revision!=engine.revision: render()
func txt(text: String,rect: Rect2,font: int=18,color: Color=Color("#e8edf0"),parent: Node=null):
 return host.label(ui if parent==null else parent,text,rect,font,color)
func btn(text: String,rect: Rect2,action: Callable,accent: bool=false,parent: Node=null):
 return host.button(ui if parent==null else parent,text,rect,action,accent)
func render():
 if is_instance_valid(table): view_zoom=table.camera_distance
 if is_instance_valid(ui): remove_child(ui); ui.queue_free()
 ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(ui)
 last_revision=engine.revision
 var container=SubViewportContainer.new()
 container.position=Vector2(0,60); container.size=Vector2(1600,800); container.stretch=true
 ui.add_child(container)
 var viewport=SubViewport.new(); viewport.size=Vector2i(1600,800); viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 container.add_child(viewport)
 table=preload("res://scripts/duel_table.gd").new(); viewport.add_child(table)
 table.camera_distance=view_zoom
 var reservations=local.get("plan",[])
 table.build(engine,host.texture,host.battlefield_background,reservations,selection)
 table.object_selected.connect(object_clicked)
 table.avatar_selected.connect(func(who): choose_target({"player":who}))
 table.stack_selected.connect(func(id): choose_target({"stack_id":id}))
 table.pile_selected.connect(func(zone):
  if zone in ["pgrave","agrave"]:
   var who=0 if zone=="pgrave" else 1
   table.inspect_cards(engine.players[who].grave.map(func(c): return c.card_id)))
 txt("极 彩",Rect2(24,10,155,42),26,host.GOLD)
 btn("响应：开" if full_response else "响应：关",Rect2(180,12,136,38),func(): full_response=not full_response; render(),full_response)
 txt("第 %d 回合  ·  %s  ·  %s" % [engine.turn,"你" if engine.active==0 else "人机",phase_names[engine.phase]],Rect2(425,12,670,42),23,host.GOLD)
 btn("设置",Rect2(1460,12,116,40),settings_menu)
 txt("人机生命 %d" % engine.players[1].life,Rect2(675,74,290,34),22)
 # Clicking either avatar is also available through these unobtrusive HUD labels.
 btn("你  %d" % engine.players[0].life,Rect2(28,770,156,46),func(): choose_target({"player":0}))
 btn("人机  %d" % engine.players[1].life,Rect2(28,712,156,46),func(): choose_target({"player":1}))
 if not engine.stack.is_empty():
  txt(engine.stack.back().name,Rect2(975,88,600,30),17,host.WHITE)
 render_hand()
 render_prompt()
 if not message.is_empty(): txt(message,Rect2(300,694,990,33),18,Color("#f0cf93"))
 if not engine.log.is_empty(): txt(engine.log.back(),Rect2(335,56,970,28),16,host.MUTED)
 if engine.winner!=-2: result_overlay()
func render_hand():
 var scroll=ScrollContainer.new(); scroll.position=Vector2(300,737); scroll.size=Vector2(1000,151)
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; ui.add_child(scroll)
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",9); scroll.add_child(row)
 for c in engine.players[0].hand:
  var panel=Control.new(); panel.custom_minimum_size=Vector2(95,140); row.add_child(panel)
  var art=host.card(panel,c.card_id,Rect2(0,0,95,133),func(): hand_clicked(c.uid))
  art.tooltip_text=engine.cards[c.card_id].name+"\n"+engine.cards[c.card_id].rules_text
  if c.uid in selection: art.add_theme_stylebox_override("panel",host.style(Color("#715932"),host.GOLD))
func render_prompt():
 var text=""
 if not local.is_empty():
  text=local_prompt()
  btn("取消使用",Rect2(1320,704,230,43),cancel_cast)
  if local.get("mode","")=="payment":
   var c=engine.find_card(local.uid)
   var valid=engine.payment_valid(0,engine.cards[c.card_id].cost,local.plan)
   var b=btn("确认支付",Rect2(1320,756,230,48),commit_local,true); b.disabled=not valid
   btn("重选费用",Rect2(1320,814,230,42),func(): local.plan=[]; render())
 elif engine.phase=="mulligan" and not engine.players[0].mulligan_done:
  text="选择要调度的手牌"
  btn("保留" if selection.is_empty() else "调度 %d 张" % selection.size(),Rect2(1320,768,230,55),func(): engine.mulligan(0,selection); selection=[]; render(),true)
 elif not engine.pending.is_empty() and engine.pending.owner==0:
  match engine.pending.kind:
   "possession":
    text="凭依：选择颜色盘与手牌"
    btn("跳过凭依",Rect2(1320,768,230,55),func(): engine.possession(); selection=[]; render(),true)
   "block":
    text="选择阻挡单位"
    btn("不阻挡" if selection.is_empty() else "确认阻挡 %d 个" % selection.size(),Rect2(1320,768,230,55),func(): engine.block(selection); selection=[]; render(),true)
   "trigger":
    text=engine.pending.trigger.name+"：选择目标单位"
    btn("不使用能力",Rect2(1320,768,230,55),func(): engine.choose_trigger({}); selection=[]; render())
   "leader_return":
    text="将自机放回自机区？"
    btn("返回自机区",Rect2(1310,756,250,48),func(): engine.choose_return(true); render(),true)
    btn("送入墓地",Rect2(1310,814,250,42),func(): engine.choose_return(false); render())
   "discard":
    text="弃置 %d 张手牌" % engine.pending.count
    var b=btn("确认弃牌",Rect2(1320,768,230,55),func(): engine.discard(selection); selection=[]; render(),true)
    b.disabled=selection.size()!=engine.pending.count
   "damage_assignment":
    text="分配战斗伤害"
    btn("分配伤害",Rect2(1320,768,230,55),damage_dialog,true)
 elif engine.priority==0 and engine.winner==-2:
  text="你的行动" if engine.active==0 and engine.phase=="main" and engine.stack.is_empty() and engine.combat.is_empty() else "响应窗口"
  btn("结束主要阶段" if text=="你的行动" else "不响应 / 继续",Rect2(1320,768,250,55),func(): engine.pass_priority(0); message=""; render(),true)
 else: text="等待人机"
 txt(text,Rect2(315,651,930,40),22,host.GOLD)
func local_prompt() -> String:
 if local.mode=="target": return "选择目标："+engine.cards[engine.find_card(local.uid).card_id].name
 var cost=engine.cards[engine.find_card(local.uid).card_id].cost
 var pieces=[]
 for color in cost:
  var paid=local.get("plan",[]).filter(func(r): return r.color==color).size()
  pieces.append("%s %d / %d" % [color,paid,cost[color]])
 return "手动支付  ·  "+"    ".join(pieces)
func hand_clicked(uid: int):
 message=""
 if engine.phase=="mulligan" or engine.pending.get("kind","")=="discard":
  toggle_selection(uid); return
 if engine.pending.get("kind","")=="possession" and engine.pending.owner==0:
  if selection.size()==1 and engine.find_card(selection[0]).zone=="palette":
   engine.possession(selection[0],uid); selection=[]; render()
  else: message="先选择一张竖置的颜色盘牌"; render()
  return
 if not local.is_empty(): return
 request_cast(uid)
func object_clicked(uid: int):
 message=""
 if not local.is_empty():
  if local.mode=="payment": reserve_resource(uid)
  elif local.mode=="target":
   var c=engine.find_card(uid)
   if not c.is_empty(): choose_target(engine.ref_target(c))
  return
 var c=engine.find_card(uid)
 if not engine.pending.is_empty() and engine.pending.owner==0:
  match engine.pending.kind:
   "trigger":
    if not c.is_empty(): choose_target(engine.ref_target(c))
   "block":
    if c in engine.legal_blockers(): toggle_selection(uid)
   "possession":
    if not c.is_empty() and c.owner==0 and c.zone=="palette" and not c.tapped: selection=[uid]; render()
  return
 if c.is_empty(): return
 if c.owner==0 and c.zone=="leader": request_cast(uid)
 elif engine.can_attack(0,uid): engine.attack(0,uid); render()
 else: message=engine.cards[c.card_id].name; render()
func toggle_selection(uid: int):
 if uid in selection: selection.erase(uid)
 else: selection.append(uid)
 render()
func request_cast(uid: int):
 var error=engine.cast_error(0,uid)
 if not error.is_empty(): message=error; render(); return
 local={"uid":uid,"target":{},"plan":[],"mode":"target"}
 var c=engine.find_card(uid)
 if engine.cards[c.card_id].kind=="符卡": render()
 else: start_payment()
func choose_target(target: Dictionary):
 if engine.pending.get("kind","")=="trigger" and engine.pending.owner==0:
  if engine.target_valid(target,true): engine.choose_trigger(target); render()
  return
 if local.is_empty() or local.mode!="target": return
 if target not in engine.targets_for(engine.find_card(local.uid).card_id): message="目标不合法"; render(); return
 local.target=target
 start_payment()
func start_payment():
 var c=engine.find_card(local.uid)
 var solution=engine.payment(0,engine.cards[c.card_id].cost)
 local.mode="payment"
 if auto_pay and (solution.ways==1 or engine.cards[c.card_id].kind!="符卡"):
  local.plan=solution.plan; commit_local(); return
 if not auto_pay: render(); return
 render()
 var panel=overlay("支付费用")
 txt("自动选择费用？",Rect2(32,74,590,50),25,host.GOLD,panel)

 btn("自动支付",Rect2(32,218,190,50),func(): modal=false; local.plan=solution.plan; commit_local(),true,panel)
 btn("手动选择",Rect2(238,218,190,50),func(): modal=false; render(),false,panel)
 btn("取消使用",Rect2(444,218,170,50),cancel_cast,false,panel)
func reserve_resource(uid: int):
 var sources=engine.source_resources(0)
 var source={}
 for s in sources:
  if s.uid==uid: source=s
 if source.is_empty(): return
 for reservation in local.plan:
  if reservation.uid==uid: local.plan.erase(reservation); render(); return
 var cost=engine.cards[engine.find_card(local.uid).card_id].cost
 var colors=[]
 for color in source.colors:
  if local.plan.filter(func(r): return r.color==color).size()<int(cost.get(color,0)): colors.append(color)
 if colors.is_empty(): message="不需要这张牌的颜色"; render(); return
 if colors.size()==1: local.plan.append({"uid":uid,"color":colors[0]}); render(); return
 var panel=overlay("选择支付颜色")
 for i in range(colors.size()):
  var color=colors[i]
  btn(color,Rect2(30+i*110,95,100,65),func(): local.plan.append({"uid":uid,"color":color}); modal=false; render(),true,panel)
 btn("返回",Rect2(440,218,170,50),func(): modal=false; render(),false,panel)
func commit_local():
 if local.is_empty(): return
 var error=engine.commit_cast(0,local.uid,local.target,local.plan)
 if error.is_empty(): local={}; selection=[]; message=""
 else: message=error
 modal=false; render()
func cancel_cast():
 local={}; selection=[]; modal=false; message=""; render()
func overlay(title: String) -> Panel:
 modal=true
 if is_instance_valid(modal_root):
  modal_root.get_parent().remove_child(modal_root); modal_root.queue_free()
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.65); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(shade)
 modal_root=shade
 var panel=host.box(shade,Rect2(450,240,650,330),Color("#101c28"),host.GOLD)
 txt(title,Rect2(30,18,590,42),27,host.GOLD,panel)
 return panel
func settings_menu():
 var panel=overlay("对战设置")
 var cb=CheckButton.new(); cb.text="自动支付"; cb.position=Vector2(30,86); cb.size=Vector2(280,46); cb.button_pressed=auto_pay; panel.add_child(cb)
 cb.toggled.connect(func(value): auto_pay=value)
 btn("继续游戏",Rect2(30,180,260,48),func(): modal=false; render(),true,panel)
 btn("投降",Rect2(330,180,260,48),func():
  var confirm=overlay("确认投降")
  btn("投降",Rect2(35,155,260,50),func(): modal=false; local={}; engine.surrender(0); render(),true,confirm)
  btn("返回",Rect2(330,155,260,50),func(): modal=false; render(); settings_menu(),false,confirm),false,panel)
func result_overlay():
 var panel=overlay("平局" if engine.winner==-1 else "胜利" if engine.winner==0 else "对局结束")
 txt(engine.log.back(),Rect2(30,90,590,80),22,host.WHITE,panel)
 btn("返回对局准备",Rect2(160,220,330,56),func(): host.setup(),true,panel)
func damage_dialog():
 var panel=overlay("分配 %d 点战斗伤害" % engine.pending.total)
 var inputs={}
 for i in range(engine.combat.blockers.size()):
  var t=engine.combat.blockers[i]; var c=engine.find_card(t.uid)
  txt(engine.cards[c.card_id].name,Rect2(25,76+i*53,455,45),17,host.WHITE,panel)
  var spin=SpinBox.new(); spin.min_value=0; spin.max_value=engine.pending.total; spin.step=1; spin.position=Vector2(500,76+i*53); spin.size=Vector2(115,45); panel.add_child(spin); inputs[str(c.uid)]=spin
 btn("确认",Rect2(220,263,200,46),func():
  var allocation={}; var total=0
  for key in inputs: allocation[key]=int(inputs[key].value); total+=allocation[key]
  if total!=engine.pending.total: return
  engine.combat_damage(allocation); modal=false; render(),true,panel)
