extends RefCounted
## Versioned, closed JSON schema. Reject unsupported data before touching a duel.
const Actions=preload("res://scripts/tutorial/ui_actions.gd")
const GuideImage=preload("res://scripts/tutorial/guide_image.gd")
const COMPONENTS=["battlefield","hand","opponent_hand","inspection","hud","stack","interaction","deck_surface","editor_surface"]
const EVENTS=["state_changed","phase_changed","priority_changed","command_accepted","step_entered","ui_action_accepted"]
const ZONES=["deck","hand","field","palette","grave","exile"]
const CAMERA_VIEWS=["battlefield","own_palette","enemy_palette"]
const CARD_FLAGS=["tapped","attacked"]
const ENTITY_CONDITIONS=["combat_attacker","entity_zone","entity_state","entity_color_counter","entity_count"]
const CARD_COUNTS=["damage","timer","entered","entered_turns","plus_counters","minus_counters","poverty","leader_counters","courage"]
const CARD_COLOR_LISTS=["color_counters","token_colors"]
const PLAYER_FLAGS=["potato","mulligan_done"]
const PLAYER_COUNTS=["turns","possession_count"]
var errors: Array=[]
var course="?"
var definitions: Dictionary

static func leader_zone(player: Dictionary) -> String:
 var zone=player.get("leader_zone","field" if player.get("leader_on_field",false) else "leader")
 return zone if zone is String or zone is StringName else "leader"

func error(path: String,reason: String):
 errors.append("课程 %s · %s：%s" % [course,path,reason])

func object(value: Variant,path: String,keys: Array) -> bool:
 if not value is Dictionary:error(path,"必须是对象");return false
 for key in value:
  if key not in keys:error(path+"."+str(key),"不支持的字段")
 return true

func array(value: Variant,path: String) -> bool:
 if value is Array:return true
 error(path,"必须是数组");return false

func text_value(value: Variant,path: String) -> bool:
 if (value is String or value is StringName) and not value.is_empty():return true
 error(path,"必须是非空字符串");return false

func integer(value: Variant,path: String,minimum: int=0) -> bool:
 if (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum:return true
 error(path,"必须是大于等于 %d 的整数" % minimum);return false

func boolean(value: Variant,path: String):
 if not value is bool:error(path,"必须是布尔值")

func choice(value: Variant,path: String,options: Array):
 # Godot JSON numbers are floats; require integrality before normalizing.
 if value is float and is_finite(value) and value==floor(value) and options.all(func(item):return item is int):value=int(value)
 if value not in options:error(path,"仅支持 "+str(options))

func check_ref(value: Variant,path: String,targets: Dictionary):
 if text_value(value,path) and not targets.has(value):error(path,"引用不存在："+str(value))

func load_file(path: String,cards: Dictionary) -> Dictionary:
 errors=[];course=path
 if not FileAccess.file_exists(path):error("file","文件不存在");return result({})
 var json=JSON.new()
 if json.parse(FileAccess.get_file_as_string(path))!=OK:
  error("file","JSON 第 %d 行：%s" % [json.get_error_line(),json.get_error_message()]);return result({})
 return validate(json.data,cards)

func result(data: Dictionary) -> Dictionary:
 return {"ok":errors.is_empty(),"errors":errors.duplicate(),"data":data.duplicate(true) if errors.is_empty() else {}}

func validate(data: Variant,cards: Dictionary) -> Dictionary:
 errors=[];definitions=cards
 if data is Dictionary:course=str(data.get("id","?"))
 if not object(data,"tutorial",["schema_version","id","title","category","initial_scenario","start_step","completion","scenarios","steps"]):return result({})
 choice(data.get("schema_version"),"schema_version",[1])
 text_value(data.get("id"),"id");text_value(data.get("title"),"title")
 if data.has("category"):choice(data.category,"category",["beginner","advanced","leader"])
 var scenarios=data.get("scenarios",{})
 var steps=data.get("steps",{})
 if not scenarios is Dictionary or scenarios.is_empty():error("scenarios","必须是非空的 ID → 场景对象");return result({})
 if not steps is Dictionary or steps.is_empty():error("steps","必须是非空的 ID → 步骤对象");return result({})
 check_ref(data.get("initial_scenario"),"initial_scenario",scenarios)
 check_ref(data.get("start_step"),"start_step",steps)
 var aliases={}
 for id in scenarios:
  text_value(id,"scenarios.ID")
  aliases[id]=scenario(scenarios[id],"scenarios."+str(id),steps)
 for id in steps:
  text_value(id,"steps.ID")
  step(steps[id],"steps."+str(id),steps,scenarios)
 condition(data.get("completion"),"completion",steps)
 # Check unknown aliases even in unreachable steps, then check each reachable
 # step/scene pair so an alias from a different tableau cannot satisfy a ref.
 var all_aliases={}
 for set_of_aliases in aliases.values():all_aliases.merge(set_of_aliases)
 for id in steps:
  var s=steps[id]
  if not s is Dictionary:continue
  check_aliases(s,"steps."+str(id),all_aliases)
 for id in scenarios:check_aliases(scenarios[id],"scenarios."+str(id),aliases[id])
 if errors.is_empty():check_reachable_aliases(data,aliases)
 if errors.is_empty():check_auto_cycles(steps)
 return result(data)

func scenario(s: Variant,path: String,steps: Dictionary) -> Dictionary:
 var aliases={}
 if not object(s,path,["type","focus","deck","screen","seed","first","turn","phase","active","priority","players","components","opponent"]):return aliases
 var kind=s.get("type","battlefield")
 choice(kind,path+".type",["battlefield","deck","in_game"])
 if kind in ["deck","in_game"]:
  deck(s.get("deck"),path+".deck")
  if kind=="in_game":choice(s.get("screen"),path+".screen",["deck_editor"])
  elif s.has("screen"):error(path+".screen","仅游戏内场景支持 screen")
  for key in ["seed","first","turn","phase","active","priority","players","opponent","focus"]:
   if s.has(key):error(path+"."+key,"该字段仅适用于战场场景")
  components(s.get("components",{}),path+".components")
  return aliases
 if s.has("deck") or s.has("screen"):error(path,"战场场景不接受 deck/screen")
 if s.has("focus"):
  if object(s.focus,path+".focus",["alias"]):text_value(s.focus.get("alias"),path+".focus.alias")
 integer(s.get("seed"),path+".seed",1)
 choice(s.get("first",0),path+".first",[0,1])
 var phase=s.get("phase","main")
 choice(phase,path+".phase",["mulligan","prepare","main","end"])
 integer(s.get("turn",1),path+".turn",0 if phase=="mulligan" else 1)
 if phase=="mulligan" and s.get("turn")!=0:error(path+".turn","起手调度必须从第 0 回合开始")
 choice(s.get("active",0),path+".active",[0,1]);choice(s.get("priority",0),path+".priority",[0,1])
 var players=s.get("players")
 if array(players,path+".players"):
  if players.size()!=2:error(path+".players","必须恰好配置双方")
  for i in range(players.size()):
   var p=players[i];var pp=path+".players."+str(i)
   if not object(p,pp,["name","life","leader","leader_zone","leader_on_field","extra_leaders","deck_order","hand","field","palette","grave","exile","state"]):continue
   if p.has("name"):text_value(p.name,pp+".name")
   integer(p.get("life",20),pp+".life",1)
   state(p.get("state",{}),pp+".state",PLAYER_FLAGS,PLAYER_COUNTS)
   card(p.get("leader"),pp+".leader","leader",aliases)
   if p.has("leader_zone"):choice(p.leader_zone,pp+".leader_zone",ZONES+["leader"])
   if p.has("leader_on_field"):boolean(p.leader_on_field,pp+".leader_on_field")
   if array(p.get("extra_leaders",[]),pp+".extra_leaders"):
    for index in range(p.get("extra_leaders",[]).size()):
     var extra=p.extra_leaders[index];var ep=pp+".extra_leaders."+str(index)
     if not extra is Dictionary:error(ep,"必须是对象");continue
     var destination=extra.get("zone","leader")
     choice(destination,ep+".zone",ZONES+["leader"])
     if destination not in ZONES+["leader"]:continue
     var entry=extra.duplicate(true);entry.erase("zone")
     card(entry,ep,destination,aliases)
     if definitions.has(entry.get("card_id","")) and definitions[entry.card_id].kind!="自机":error(ep+".card_id","额外自机需要自机牌")
   for zone in ZONES:
    var key="deck_order" if zone=="deck" else zone
    var entries=p.get(key,[])
    if not array(entries,pp+"."+key):continue
    if zone=="palette":
     var extra_count=1 if leader_zone(p)=="palette" else 0
     if p.get("extra_leaders",[]) is Array:
      for extra in p.get("extra_leaders",[]):
       if extra is Dictionary and extra.get("zone","leader")==zone:extra_count+=1
     if entries.size()+extra_count>8:error(pp+"."+key,"颜色盘不能超过 8 张")
    var slots=[]
    for index in range(entries.size()):
     var entry=entries[index];var cp=pp+"."+key+"."+str(index)
     card(entry,cp,zone,aliases)
     if zone=="field" and entry is Dictionary:
      var slot=entry.get("position",index)
      if integer(slot,cp+".position"):
       if slot>=entries.size() or slot in slots:error(cp+".position","位置须唯一且在本方战场数组范围内")
       slots.append(slot)
 components(s.get("components",{}),path+".components")
 opponent(s.get("opponent",{"strategy":"paused"}),path+".opponent",steps)
 return aliases

func deck(d: Variant,path: String):
 var errors_before=errors.size()
 if not object(d,path,["name","leader","main","side","rule_set"]):return
 text_value(d.get("name"),path+".name")
 choice(d.get("rule_set","official"),path+".rule_set",preload("res://scripts/deck_rule_set.gd").IDS)
 var leader=d.get("leader")
 if text_value(leader,path+".leader"):
  if not definitions.has(leader):error(path+".leader","真实卡库中不存在："+str(leader))
  elif definitions[leader].kind!="自机":error(path+".leader","需要自机牌")
 for zone in ["main","side"]:
  if not array(d.get(zone,[]),path+"."+zone):continue
  for i in range(d.get(zone,[]).size()):check_ref(d[zone][i],path+"."+zone+"."+str(i),definitions)
 if errors.size()==errors_before:
  var candidate=d.duplicate(true);candidate.main=candidate.get("main",[]);candidate.side=candidate.get("side",[])
  var reason=preload("res://scripts/deck_store.gd").validate(candidate,false,str(candidate.get("rule_set","official")))
  if not reason.is_empty():error(path,reason)

func state(s: Variant,path: String,flags: Array,counts: Array,color_lists: Array=[]):
 if not object(s,path,flags+counts+color_lists):return
 for key in s:
  if key in flags:boolean(s[key],path+"."+key)
  elif key in counts:integer(s[key],path+"."+key)
  elif key in color_lists and array(s[key],path+"."+key):
   for i in range(s[key].size()):choice(s[key][i],path+"."+key+"."+str(i),["红","蓝","绿","黄","黑"])

func card(c: Variant,path: String,zone: String,aliases: Dictionary):
 if not object(c,path,["card_id","alias","state","position","token_value","token_spirit","token_name"]):return
 var id=c.get("card_id")
 if text_value(id,path+".card_id"):
  if id=="roster_token_frog":
   if zone!="field":error(path+".card_id","青蛙衍生物只能预置在战场")
   integer(c.get("token_value"),path+".token_value",1)
   integer(c.get("token_spirit"),path+".token_spirit",0)
   choice(c.get("token_name"),path+".token_name",["青蛙衍生物"])
  elif not definitions.has(id):error(path+".card_id","真实卡库中不存在："+id)
  elif zone=="leader" and definitions[id].kind!="自机":error(path+".card_id","自机区需要自机牌")
  elif zone=="field" and definitions[id].kind not in ["自机","单位","道具","结界"]:error(path+".card_id","该牌不能作为战场永久物")
 if c.has("token_value") and id!="roster_token_frog":error(path+".token_value","只有青蛙衍生物可配置数值")
 if c.has("token_spirit") and id!="roster_token_frog":error(path+".token_spirit","只有青蛙衍生物可配置灵力")
 if c.has("token_name") and id!="roster_token_frog":error(path+".token_name","只有青蛙衍生物可配置名称")
 if c.has("position") and zone!="field":error(path+".position","仅战场支持位置")
 if c.has("alias") and text_value(c.alias,path+".alias"):
  if aliases.has(c.alias):error(path+".alias","场景内别名重复")
  aliases[c.alias]=true
 state(c.get("state",{}),path+".state",CARD_FLAGS,CARD_COUNTS,CARD_COLOR_LISTS)

func components(c: Variant,path: String):
 if not object(c,path,COMPONENTS):return
 for key in c:
  var allowed=["enabled"] if key=="interaction" else ["visible","highlight"]
  if not object(c[key],path+"."+key,allowed):continue
  for property in c[key]:boolean(c[key][property],path+"."+key+"."+property)

func step(s: Variant,path: String,steps: Dictionary,scenarios: Dictionary):
 if not object(s,path,["type","scenario","scenario_mode","camera_view","open_zone","guide","sequence","task","wait_event","next","failure","restore_on_failure"]):return
 var kind=s.get("type")
 choice(kind,path+".type",["info","task","wait"])
 if s.has("scenario"):check_ref(s.scenario,path+".scenario",scenarios)
 if s.has("scenario_mode"):
  choice(s.scenario_mode,path+".scenario_mode",["reset","resume"])
  if not s.has("scenario"):error(path+".scenario_mode","场景切换方式需要 scenario")
 if s.has("camera_view"):choice(s.camera_view,path+".camera_view",CAMERA_VIEWS)
 if s.has("open_zone") and object(s.open_zone,path+".open_zone",["player","zone"]):
  choice(s.open_zone.get("player"),path+".open_zone.player",[0,1])
  choice(s.open_zone.get("zone"),path+".open_zone.zone",["grave","exile"])
 for key in ["next","failure"]:
  if key=="failure" and not s.has(key):continue
  if s.get(key)!="$complete":check_ref(s.get(key),path+"."+key,steps)
 if s.has("restore_on_failure"):boolean(s.restore_on_failure,path+".restore_on_failure")
 var g=s.get("guide")
 if object(g,path+".guide",["text","targets","popup","next_button","layout","focus","image"]):
  text_value(g.get("text"),path+".guide.text")
  if g.has("image"):
   var reason=GuideImage.validate(g.image,definitions)
   if not reason.is_empty():error(path+".guide.image",reason)
  choice(g.get("popup","show"),path+".guide.popup",["show","hidden"])
  if g.has("layout"):choice(g.layout,path+".guide.layout",["modal","side"])
  if g.has("focus"):
   if object(g.focus,path+".guide.focus",["alias","card_id"]):
    if g.focus.has("alias")==g.focus.has("card_id"):error(path+".guide.focus","需要且只能指定 alias 或 card_id")
    if g.focus.has("alias"):text_value(g.focus.alias,path+".guide.focus.alias")
    if g.focus.has("card_id"):check_ref(g.focus.card_id,path+".guide.focus.card_id",definitions)
  var button=g.get("next_button","manual" if kind=="info" else "hidden")
  choice(button,path+".guide.next_button",["manual","auto","hidden"])
  if kind=="info" and button=="hidden":error(path+".guide.next_button","讲解须有手动或自动推进方式")
  if kind=="info" and g.get("popup","show")=="hidden" and button=="manual":error(path+".guide.popup","隐藏弹框的讲解不能等待手动按钮")
  if kind!="info" and button!="hidden":error(path+".guide.next_button","任务和等待步骤由判定推进")
  if array(g.get("targets",[]),path+".guide.targets"):
   for i in range(g.get("targets",[]).size()):target(g.targets[i],path+".guide.targets."+str(i))
 if kind=="info" and s.has("task"):error(path+".task","讲解不评估任务")
 if s.has("sequence"):
  if kind!="info":error(path+".sequence","固定演示序列只用于对话步骤")
  sequence(s.sequence,path+".sequence")
  if g is Dictionary:
   if g.get("popup","show")!="show" or g.get("next_button","manual")!="manual":error(path+".guide","演示结束后须显示对话框并由玩家手动推进")
 if kind in ["task","wait"]:
  var t=s.get("task")
  if object(t,path+".task",["success","failure","timing","action","allowed_actions","quiz","required_aliases","required_choice","allow_turn_end","sequence"]):
   choice(t.get("timing","state_changed"),path+".task.timing",["enter","state_changed","event","action","answer","mulligan_selection"])
   if t.has("allow_turn_end"):boolean(t.allow_turn_end,path+".task.allow_turn_end")
   if t.has("sequence"):
    if kind!="task" or t.get("timing","state_changed")!="state_changed":error(path+".task.sequence","互动动作需要局面判定任务")
    sequence(t.sequence,path+".task.sequence",true)
   if t.get("timing")=="answer":
    quiz(t.get("quiz"),path+".task.quiz")
    for key in ["success","failure","action","allowed_actions"]:
     if t.has(key):error(path+".task."+key,"答题任务只由正确答案推进")
    for key in ["failure","restore_on_failure"]:
     if s.has(key):error(path+"."+key,"答错应留在当前题目重选")
   elif t.has("quiz"):error(path+".task.quiz","答题框需要 answer 判定时点")
   if t.get("timing")=="mulligan_selection":
    if kind!="task":error(path+".task.timing","调度选择须使用任务步骤")
    if array(t.get("required_aliases"),path+".task.required_aliases"):
     if t.required_aliases.size()!=2:error(path+".task.required_aliases","须指定恰好两张起手牌")
     var selected={}
     for i in range(t.required_aliases.size()):
      var alias=t.required_aliases[i]
      if text_value(alias,path+".task.required_aliases."+str(i)):
       if selected.has(alias):error(path+".task.required_aliases","卡牌别名不能重复")
       selected[alias]=true
    for key in ["success","failure","action","allowed_actions"]:
     if t.has(key):error(path+".task."+key,"调度选择由确认的两张手牌推进")
    if s.has("failure"):error(path+".failure","选错后应留在当前任务重选")
   elif t.has("required_aliases"):error(path+".task.required_aliases","只有调度选择任务支持此字段")
   if t.has("required_choice"):
    if kind!="task" or t.get("timing","state_changed")!="state_changed":error(path+".task.required_choice","颜色选择约束需要状态判定任务")
    if object(t.required_choice,path+".task.required_choice",["effect","color"]):
     choice(t.required_choice.get("effect"),path+".task.required_choice.effect",["lily_color"])
     choice(t.required_choice.get("color"),path+".task.required_choice.color",["红","蓝","绿","黄","黑"])
   if t.get("timing")=="action":ui_action(t.get("action"),path+".task.action")
   elif t.has("action"):error(path+".task.action","动作约束需要 action 判定时点")
   if t.has("allowed_actions") and array(t.allowed_actions,path+".task.allowed_actions"):
    for id in t.allowed_actions:choice(id,path+".task.allowed_actions",Actions.ALLOWED)
   if kind=="wait" and t.get("timing")!="event":error(path+".task.timing","等待步骤须按事件判定")
   if kind=="task" and t.get("timing")=="event":error(path+".task.timing","event 判定请使用 wait 步骤")
   if t.get("timing") not in ["answer","mulligan_selection"]:condition(t.get("success"),path+".task.success",steps)
   if t.has("failure"):
    condition(t.failure,path+".task.failure",steps)
    if not s.has("failure"):error(path+".failure","失败条件需要回退目标")
 if kind=="wait":choice(s.get("wait_event"),path+".wait_event",EVENTS)
 elif s.has("wait_event"):error(path+".wait_event","仅等待步骤支持")

func sequence(value: Variant,path: String,interactive: bool=false):
 if not object(value,path,["actions","random_results","advance_rng"]+(["student"] if interactive else [])):return
 if value.has("advance_rng"):boolean(value.advance_rng,path+".advance_rng")
 if interactive:
  choice(value.get("student",0),path+".student",[0])
  if value.get("actions",[]) is Array and not value.actions.any(func(a):return a is Dictionary and a.get("player")==0):error(path+".actions","互动任务至少需要一个我方动作")
 if array(value.get("actions"),path+".actions"):
  if value.actions.is_empty() or value.actions.size()>600:error(path+".actions","须包含 1 至 600 个固定动作")
  for i in range(value.actions.size()):sequence_action(value.actions[i],path+".actions."+str(i))
 if array(value.get("random_results",[]),path+".random_results"):
  if value.get("random_results",[]).size()>600:error(path+".random_results","最多预设 600 个随机结果")
  for i in range(value.get("random_results",[]).size()):
   var result=value.random_results[i];var rp=path+".random_results."+str(i)
   if not object(result,rp,["type","value"]):continue
   choice(result.get("type"),rp+".type",["coin","d6"])
   choice(result.get("value"),rp+".value",[0,1] if result.get("type")=="coin" else [1,2,3,4,5,6])

func sequence_action(a: Variant,path: String):
 if not a is Dictionary:error(path,"动作必须是对象");return
 var keys={"pass_priority":[],"cast":["card","target","payment"],"ability":["source","index","key","target","payment"],"possession":["palette","hand"],"attack":["card","target","payment"],"block":["cards"],"discard":["cards"],"mulligan":["cards"],"choose_trigger":["target"],"choose_effect":["target","grant_payment"],"choose_trigger_order":["index"],"choose_ward":["index"],"choose_return":["yes"],"choose_grave_replacement":["yes"],"choose_timer":["value"],"combat_damage":["assignments"],"delay":["seconds"],"toggle_ran_discount":["card"],"toggle_murder_dolls_skip":["card"]}
 var kind=a.get("type","")
 keys.cast.append("pay_colors")
 if not keys.has(kind):error(path+".type","不支持的固定动作："+str(kind));return
 object(a,path,["type"]+([] if kind=="delay" else ["player"])+keys[kind])
 if kind=="delay":
  var seconds=a.get("seconds")
  if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds<=0 or seconds>60:error(path+".seconds","等待时长须大于 0 且不超过 60 秒")
  return
 choice(a.get("player"),path+".player",[0,1])
 if a.has("payment"):payment(a.payment,path+".payment")
 if a.has("grant_payment"):boolean(a.grant_payment,path+".grant_payment")
 if a.has("pay_colors"):boolean(a.pay_colors,path+".pay_colors")
 if kind in ["cast","ability"]:
  var move=a.duplicate(true);move.erase("player");move.erase("payment");move.erase("pay_colors");opponent_action(move,path)
 elif kind=="possession":
  if a.has("palette")!=a.has("hand"):error(path,"凭依须同时指定 palette 和 hand，或同时省略以结束凭依")
  for key in ["palette","hand"]:
   if a.has(key):opponent_card(a[key],path+"."+key)
 elif kind in ["attack","toggle_ran_discount","toggle_murder_dolls_skip"]:
  opponent_card(a.get("card"),path+".card")
  if a.has("target") and a.target is Dictionary and not a.target.is_empty():opponent_card(a.target,path+".target")
  elif a.has("target") and not a.target is Dictionary:error(path+".target","目标必须是对象")
 elif kind in ["block","discard","mulligan"]:
  var move={"type":"block","cards":a.get("cards")};opponent_action(move,path)
 elif kind in ["choose_trigger","choose_effect"]:
  if a.has("target"):opponent_target(a.target,path+".target")
 elif kind in ["choose_trigger_order","choose_ward"]:integer(a.get("index"),path+".index")
 elif kind in ["choose_return","choose_grave_replacement"]:boolean(a.get("yes"),path+".yes")
 elif kind=="choose_timer":choice(a.get("value"),path+".value",[-1,0,1])
 elif kind=="combat_damage" and array(a.get("assignments"),path+".assignments"):
  var chosen=[]
  for i in range(a.assignments.size()):
   var item=a.assignments[i];var ip=path+".assignments."+str(i)
   if not object(item,ip,["card","amount"]):continue
   opponent_card(item.get("card"),ip+".card");integer(item.get("amount"),ip+".amount")
   if item.get("card") is Dictionary and item.card.has("alias"):
    if item.card.alias in chosen:error(ip+".card.alias","伤害分配不能重复选择同一单位")
    chosen.append(item.card.alias)

func quiz(q: Variant,path: String):
 if not object(q,path,["answers","correct_answer"]):return
 var answers=q.get("answers")
 var ids=[]
 if array(answers,path+".answers"):
  if answers.size()<2:error(path+".answers","至少需要两个答案选项")
  for i in range(answers.size()):
   var answer=answers[i];var ap=path+".answers."+str(i)
   if not object(answer,ap,["id","text","card_id"]):continue
   if text_value(answer.get("id"),ap+".id"):
    if answer.id in ids:error(ap+".id","答案 ID 重复")
    ids.append(answer.id)
   if not answer.has("text") and not answer.has("card_id"):error(ap,"需要文字或卡图")
   if answer.has("text"):text_value(answer.text,ap+".text")
   if answer.has("card_id"):check_ref(answer.card_id,ap+".card_id",definitions)
 if text_value(q.get("correct_answer"),path+".correct_answer") and q.correct_answer not in ids:error(path+".correct_answer","必须引用已配置的答案 ID")

func ui_action(a: Variant,path: String):
 if not object(a,path,["id","args"]):return
 choice(a.get("id"),path+".id",Actions.ALLOWED)
 if a.has("args"):
  if not object(a.args,path+".args",["card_id","zone","value","source_zone","source_index","target_index"]):return
  if a.args.has("card_id"):check_ref(a.args.card_id,path+".args.card_id",definitions)
  for key in ["zone","source_zone"]:
   if a.args.has(key):choice(a.args[key],path+".args."+key,["main","side","leader","library"])
  for key in ["source_index","target_index"]:
   if a.args.has(key):integer(a.args[key],path+".args."+key,-1)
  if a.args.has("value") and not (a.args.value is String or a.args.value is bool or ((a.args.value is int or a.args.value is float) and is_finite(float(a.args.value)))):error(path+".args.value","仅支持字符串、布尔值或有限数值")

func target(t: Variant,path: String):
 if not object(t,path,["component","alias","player","card_id","zone","index"]):return
 var selectors=["component","alias","player","card_id"].filter(func(key):return t.has(key))
 if selectors.size()!=1:error(path,"目标须且只能包含 component、alias、player 或 card_id 中的一项")
 if t.has("card_id"):
  check_ref(t.card_id,path+".card_id",definitions)
  if t.has("zone"):choice(t.zone,path+".zone",["leader","main","side"])
  if t.has("index"):
   integer(t.index,path+".index")
   if not t.has("zone"):error(path+".index","指定副本索引时需要 zone")
 elif t.has("zone") or t.has("index"):error(path,"zone/index 仅适用于 card_id 目标")
 if t.has("component"):choice(t.component,path+".component",COMPONENTS.filter(func(c):return c!="interaction"))
 if t.has("alias"):text_value(t.alias,path+".alias")
 if t.has("player"):choice(t.player,path+".player",[0,1])

func condition(c: Variant,path: String,steps: Dictionary,depth: int=0):
 if depth>12:error(path,"条件嵌套过深");return
 if not c is Dictionary:error(path,"条件必须是对象");return
 var kind=c.get("type")
 var keys={"always":["type"],"all":["type","conditions"],"any":["type","conditions"],"not":["type","condition"],"steps_completed":["type","steps"],"phase":["type","value"],"priority":["type","value"],"pending":["type","kind","owner"],"combat_attacker":["type","alias"],"entity_zone":["type","alias","zone"],"entity_state":["type","alias","key","value"],"entity_color_counter":["type","alias","color"],"player_count":["type","player","key","value","op"],"life":["type","player","value","op"],"deck_count":["type","zone","value","op"],"entity_count":["type","alias","key","value","op"],"zone_count":["type","player","zone","card_id","kind","value","op"]}
 keys.combat_step=["type","value"]
 keys.combat_attacker_rank=["type","player","key","count","count_player","ties"]
 keys.deck_count.append("card_id")
 keys.ui_action=["type","action"]
 for entity_type in ENTITY_CONDITIONS:keys[entity_type].append("created")
 if not keys.has(kind):error(path+".type","不支持的条件："+str(kind));return
 object(c,path,keys[kind])
 if kind in ENTITY_CONDITIONS:
  var selectors=["alias","created"].filter(func(key):return c.has(key))
  if selectors.size()!=1:error(path,"需要且只能指定 alias 或 created 中的一项")
  elif c.has("created"):integer(c.created,path+".created")
  else:text_value(c.alias,path+".alias")
 match kind:
  "all","any":
   if array(c.get("conditions"),path+".conditions"):
    if c.conditions.is_empty():error(path+".conditions","不能为空")
    for i in range(c.conditions.size()):condition(c.conditions[i],path+".conditions."+str(i),steps,depth+1)
  "not":condition(c.get("condition"),path+".condition",steps,depth+1)
  "steps_completed":
   if array(c.get("steps"),path+".steps"):
    if c.steps.is_empty():error(path+".steps","不能为空")
    for id in c.steps:check_ref(id,path+".steps",steps)
  "phase":choice(c.get("value"),path+".value",["prepare","main","end","reset","draw","possession","over","mulligan"])
  "priority":choice(c.get("value"),path+".value",[0,1])
  "pending":choice(c.get("kind"),path+".kind",["possession","discard","block","damage_assignment","trigger_order","ward_order","trigger","leader_return","grave_replacement","effect_choice","timer"]);choice(c.get("owner"),path+".owner",[0,1])
  "combat_step":choice(c.get("value"),path+".value",["none","attack_window","block_window","first_damage_window","damage_window"])
  "combat_attacker_rank":
   choice(c.get("player"),path+".player",[0,1]);choice(c.get("key"),path+".key",["spirit","power","health"])
   if c.has("count")==c.has("count_player"):error(path,"排名范围需要且只能指定 count 或 count_player 中的一项")
   if c.has("count"):integer(c.count,path+".count",1)
   if c.has("count_player"):choice(c.count_player,path+".count_player",[0,1])
   if c.has("ties"):choice(c.ties,path+".ties",["all","field_order"])
  "entity_zone":choice(c.get("zone"),path+".zone",ZONES+["leader","stack"])
  "entity_state":
   choice(c.get("key"),path+".key",CARD_FLAGS)
   boolean(c.get("value"),path+".value")
  "entity_color_counter":choice(c.get("color"),path+".color",["红","蓝","绿","黄","黑"])
  "entity_count":
   choice(c.get("key"),path+".key",CARD_COUNTS);integer(c.get("value"),path+".value");choice(c.get("op","eq"),path+".op",["eq","le","ge"])
  "zone_count":
   choice(c.get("player"),path+".player",[0,1]);choice(c.get("zone"),path+".zone",ZONES)
   if c.has("card_id"):check_ref(c.card_id,path+".card_id",definitions)
   if c.has("kind"):choice(c.kind,path+".kind",["单位","自机","道具","结界","符卡"])
   integer(c.get("value"),path+".value");choice(c.get("op","eq"),path+".op",["eq","le","ge"])
  "player_count":choice(c.get("player"),path+".player",[0,1]);choice(c.get("key"),path+".key",PLAYER_COUNTS);integer(c.get("value"),path+".value",0);choice(c.get("op","eq"),path+".op",["eq","le","ge"])
  "life":choice(c.get("player"),path+".player",[0,1]);integer(c.get("value"),path+".value",-100000);choice(c.get("op","eq"),path+".op",["eq","le","ge"])
  "deck_count":
   choice(c.get("zone"),path+".zone",["main","side","leader"]);integer(c.get("value"),path+".value");choice(c.get("op","eq"),path+".op",["eq","le","ge"])
   if c.has("card_id"):check_ref(c.card_id,path+".card_id",definitions)
  "ui_action":ui_action(c.get("action"),path+".action")

func opponent(o: Variant,path: String,steps: Dictionary):
 if not object(o,path,["strategy","rules","auto_response"]):return
 if o.has("auto_response"):boolean(o.auto_response,path+".auto_response")
 choice(o.get("strategy","paused"),path+".strategy",["paused","rules"])
 var rules=o.get("rules",[]);var ids=[]
 if not array(rules,path+".rules"):return
 if o.get("strategy","paused")=="paused" and not rules.is_empty():error(path+".rules","paused 策略不能配置响应规则")
 for i in range(rules.size()):
  var r=rules[i];var rp=path+".rules."+str(i)
  if not object(r,rp,["id","event","when","action","max_times","on_action","sequence","otherwise"]):continue
  if text_value(r.get("id"),rp+".id"):
   if r.id in ids:error(rp+".id","规则 ID 重复")
   ids.append(r.id)
  choice(r.get("event"),rp+".event",EVENTS)
  condition(r.get("when"),rp+".when",steps)
  if r.has("sequence"):
   if r.has("action"):error(rp,"响应只能指定 action 或 sequence 中的一项")
   sequence(r.sequence,rp+".sequence")
   if r.sequence is Dictionary and r.sequence.get("actions") is Array:
    for a in r.sequence.actions:
     if a is Dictionary and a.get("type")!="delay" and a.get("player")!=1:error(rp+".sequence.actions","AI 响应序列只能包含对方动作")
  else:opponent_action(r.get("action"),rp+".action")
  if r.has("otherwise"):
   choice(r.otherwise,rp+".otherwise",["no_block"])
   if not r.get("action") is Dictionary or r.action.get("type")!="block" or not r.action.has("priorities"):error(rp+".otherwise","自动放行需要按优先级阻挡响应")
   if r.get("event")!="state_changed" or r.has("on_action"):error(rp+".otherwise","自动放行须监听 state_changed 且不限定操作")
  if r.has("on_action"):
   if r.get("event")!="command_accepted":error(rp+".on_action","动作触发须监听 command_accepted")
   sequence_action(r.on_action,rp+".on_action")
  integer(r.get("max_times"),rp+".max_times",1)

func opponent_action(a: Variant,path: String):
 # Keep the original string form compatible with existing courses.
 if a is String:
  choice(a,path,["pass_priority"]);return
 if not a is Dictionary:error(path,"动作必须是字符串或对象");return
 var keys={"pass_priority":["type"],"block":["type","cards","priorities"],"cast":["type","card","target"],"ability":["type","source","index","key","target"]}
 var kind=a.get("type")
 if not keys.has(kind):error(path+".type","不支持的对手动作："+str(kind));return
 object(a,path,keys[kind])
 if a.get("type")=="pass_priority":
  if a.has("cards"):error(path+".cards","让过执行权不接受卡牌参数")
 elif kind=="block" and a.has("priorities"):
  if a.has("cards"):error(path,"阻挡只能指定 cards 或 priorities 中的一项")
  block_priorities(a.priorities,path+".priorities")
 elif a.get("type")=="block" and array(a.get("cards"),path+".cards"):
  if a.cards.size()>100:error(path+".cards","最多选择 100 张牌")
  var chosen=[]
  for i in range(a.cards.size()):
   var card=a.cards[i];var cp=path+".cards."+str(i)
   opponent_card(card,cp)
   if card in chosen:error(cp,"不能重复选择同一阻挡单位")
   chosen.append(card)
 elif kind=="cast":
  opponent_card(a.get("card"),path+".card",true)
  if a.has("target"):opponent_target(a.target,path+".target")
 elif kind=="ability":
  opponent_card(a.get("source"),path+".source")
  if a.has("index")==a.has("key"):error(path,"能力必须恰好指定 index 或 key")
  if a.has("index"):integer(a.index,path+".index")
  if a.has("key"):text_value(a.key,path+".key")
  if a.has("target"):opponent_target(a.target,path+".target")

func block_priorities(options: Variant,path: String):
 if not array(options,path):return
 if options.is_empty() or options.size()>5:error(path,"阻挡优先级需要 1 至 5 个选项")
 var strategies=[];var enabled=false
 for i in range(options.size()):
  var option=options[i];var op=path+"."+str(i)
  if not object(option,op,["strategy","enabled","cards"]):continue
  choice(option.get("strategy"),op+".strategy",preload("res://scripts/tutorial/block_priorities.gd").STRATEGIES)
  if option.get("strategy") in strategies:error(op+".strategy","不能重复设置同一种阻挡方案")
  strategies.append(option.get("strategy"))
  if option.has("enabled"):boolean(option.enabled,op+".enabled")
  if option.get("enabled",true) is bool and option.get("enabled",true):enabled=true
  if option.get("strategy")=="selected":
   opponent_action({"type":"block","cards":option.get("cards")},op)
  elif option.has("cards"):error(op+".cards","只有指定单位阻挡接受卡牌参数")
 if not enabled:error(path,"请至少启用一种阻挡方案")

func opponent_card(c: Variant,path: String,allow_definition: bool=false):
 if not object(c,path,["alias","created","card_id"] if allow_definition else ["alias","created"]):return
 var selectors=["alias","created","card_id"].filter(func(key):return c.has(key))
 if selectors.size()!=1:error(path,"需要且只能指定 alias、created 或 card_id 中的一项");return
 if c.has("created"):integer(c.created,path+".created");return
 if allow_definition and c.has("card_id"):
  if c.has("alias"):error(path,"alias 与 card_id 只能选择一项")
  check_ref(c.card_id,path+".card_id",definitions)
 else:text_value(c.get("alias"),path+".alias")

func payment(value: Variant,path: String):
 if not array(value,path):return
 if value.size()>100:error(path,"支付来源最多 100 项")
 for i in range(value.size()):
  var item=value[i];var ip=path+"."+str(i)
  if not object(item,ip,["card","resource","color"]):continue
  if item.has("card")==item.has("resource"):error(ip,"支付须指定 card 或 resource 中的一项")
  if item.has("card"):opponent_card(item.card,ip+".card")
  if item.has("resource"):
   if integer(item.resource,ip+".resource",-1000000) and int(item.resource)>=0:error(ip+".resource","临时资源编号须为负数")
  choice(item.get("color"),ip+".color",["红","蓝","绿","黄","黑","黄/绿"])

func opponent_target(t: Variant,path: String,depth: int=0):
 if depth>6:error(path,"目标嵌套过深");return
 if not object(t,path,["alias","created","player","stack","none","mode","color","x","selection_id","picks","parts","sacrifice","payment","pay","self","free"]):return
 var selectors=0
 for key in ["alias","created","player","stack","none","picks","parts"]:
  if t.has(key):selectors+=1
 if selectors>1:error(path,"目标只能指定一个实体、玩家、堆叠对象、无目标或多组选牌")
 if t.has("alias"):text_value(t.alias,path+".alias")
 if t.has("created"):integer(t.created,path+".created")
 if t.has("payment"):payment(t.payment,path+".payment")
 for key in ["pay","self","free"]:
  if t.has(key):boolean(t[key],path+"."+key)
 if t.has("player"):choice(t.player,path+".player",[0,1])
 if t.has("stack"):opponent_card(t.stack,path+".stack")
 if t.has("none"):
  boolean(t.none,path+".none")
  if t.none is bool and not t.none:error(path+".none","无目标只能填写 true")
 if t.has("mode"):text_value(t.mode,path+".mode")
 if t.has("color"):choice(t.color,path+".color",["红","蓝","绿","黄","黑"])
 if t.has("x"):integer(t.x,path+".x")
 if t.has("selection_id"):text_value(t.selection_id,path+".selection_id")
 if t.has("sacrifice"):opponent_card(t.sacrifice,path+".sacrifice")
 if t.has("parts") and array(t.parts,path+".parts"):
  if t.parts.is_empty() or t.parts.size()>16:error(path+".parts","须包含 1 至 16 个目标")
  for i in range(t.parts.size()):opponent_target(t.parts[i],path+".parts."+str(i),depth+1)
 if t.has("picks") and array(t.picks,path+".picks"):
  if t.picks.size()>16:error(path+".picks","最多选择 16 组目标")
  for i in range(t.picks.size()):
   var gp=path+".picks."+str(i)
   if not array(t.picks[i],gp):continue
   if t.picks[i].size()>100:error(gp,"每组最多选择 100 项")
   for j in range(t.picks[i].size()):opponent_target(t.picks[i][j],gp+"."+str(j),depth+1)

func check_aliases(value: Variant,path: String,aliases: Dictionary,scope: String=""):
 if value is Dictionary:
  for key in value:
   if key=="alias":
    if scope.is_empty():check_ref(value[key],path+".alias",aliases)
    elif not aliases.has(value[key]):error(path+".alias","场景 %s 中不存在实体别名：%s" % [scope,value[key]])
   else:check_aliases(value[key],path+"."+str(key),aliases,scope)
 elif value is Array:
  for i in range(value.size()):check_aliases(value[i],path+"."+str(i),aliases,scope)

func check_reachable_aliases(data: Dictionary,aliases: Dictionary):
 var pending=[{"step":data.start_step,"scene":data.initial_scenario}];var seen={}
 while not pending.is_empty():
  var item=pending.pop_back();var s=data.steps[item.step]
  var scene=s.get("scenario",item.scene)
  if seen.get(item.step,{}).has(scene):continue
  if not seen.has(item.step):seen[item.step]={}
  seen[item.step][scene]=true
  check_aliases(s,"steps."+item.step,aliases[scene],scene)
  var kind=data.scenarios[scene].get("type","battlefield")
  if kind!="battlefield":
   for key in ["camera_view","open_zone","sequence"]:
    if s.has(key):error("steps."+item.step+"."+key,"该字段仅适用于战场场景")
   if s.get("task",{}).has("sequence"):error("steps."+item.step+".task.sequence","互动动作只用于战场场景")
  var focus=s.guide.get("focus",{})
  if focus.has("card_id"):
   if kind!="deck":error("steps."+item.step+".guide.focus.card_id","卡图讲解仅适用于卡组场景")
   else:
    var focused_deck=data.scenarios[scene].deck
    if focus.card_id not in focused_deck.main+focused_deck.side+[focused_deck.leader]:error("steps."+item.step+".guide.focus.card_id","当前卡组中不存在该卡牌")
  var available=["interaction","deck_surface"] if kind=="deck" else ["interaction","editor_surface"] if kind=="in_game" else COMPONENTS.filter(func(c):return c not in ["deck_surface","editor_surface"])
  check_scene_fields(s,"steps."+item.step,kind,available)
  for i in range(s.guide.get("targets",[]).size()):
   var target=s.guide.targets[i]
   if not target.has("card_id"):continue
   var path="steps."+item.step+".guide.targets."+str(i)
   if kind!="deck":error(path+".card_id","卡牌标红仅适用于卡组场景");continue
   var deck=data.scenarios[scene].deck
   var zones=[target.zone] if target.has("zone") else ["leader","main","side"]
   var found=false
   for zone in zones:
    var ids=[deck.leader] if zone=="leader" else deck[zone]
    if target.has("index"):
     var index=int(target.index)
     found=found or (index<ids.size() and ids[index]==target.card_id)
    else:found=found or target.card_id in ids
   if not found:error(path,"当前卡组中不存在该卡牌或指定副本")
  check_scene_fields(data.scenarios[scene].get("components",{}),"scenarios."+scene+".components",kind,available,true)
  if s.get("task",{}).get("timing")=="action":
   if kind=="battlefield":error("steps."+item.step+".task.timing","action 任务需要卡组或组卡器场景")
   elif kind=="deck" and s.task.action.id!="editor.inspect":error("steps."+item.step+".task.action","只读卡组任务仅支持查看卡牌")
  if s.get("task",{}).get("timing")=="mulligan_selection":
   var sc=data.scenarios[scene]
   if kind!="battlefield" or sc.get("phase")!="mulligan":error("steps."+item.step+".task.timing","调度选择需要起手调度场景")
   elif not sc.get("components",{}).get("interaction",{}).get("enabled",true):error("steps."+item.step+".task.timing","调度选择需要启用战场交互")
   elif sc.get("first",0)!=0 or sc.get("active",0)!=0 or sc.get("priority",0)!=0 or sc.players[0].get("state",{}).get("mulligan_done",true) or not sc.players[1].get("state",{}).get("mulligan_done",false):error("steps."+item.step+".task.timing","我方须为先手且尚未调度，对手须已完成调度")
   else:
    var hand_aliases=sc.players[0].get("hand",[]).map(func(card):return card.get("alias",""))
    for alias in s.task.required_aliases:
     if alias not in hand_aliases:error("steps."+item.step+".task.required_aliases","别名必须指向我方起手牌："+str(alias))
  if kind!="battlefield" and s.type=="task" and s.task.get("timing") not in ["action","answer"]:error("steps."+item.step+".task.timing","当前原生界面任务须使用 action 或 answer 判定")
  if kind!="battlefield" and s.type=="wait" and s.wait_event not in ["ui_action_accepted","step_entered"]:error("steps."+item.step+".wait_event","该界面不产生此游戏事件")
  for key in ["next","failure"]:
   if s.has(key) and s[key]!="$complete":pending.append({"step":s[key],"scene":scene})

func check_scene_fields(value: Variant,path: String,kind: String,available: Array,component_map: bool=false):
 if value is Dictionary:
  if component_map:
   for id in value:
    if id not in available:error(path+"."+id,"当前场景没有该组件")
  if value.has("component") and value.component not in available:error(path+".component","当前场景没有该组件")
  if kind!="battlefield" and value.get("type") in ["phase","priority","pending","combat_attacker","combat_attacker_rank","combat_step","entity_zone","entity_state","entity_color_counter","entity_count","zone_count","player_count","life"]:error(path+".type","当前界面不支持该对局条件")
  if kind=="battlefield" and value.get("type") in ["deck_count","ui_action"]:error(path+".type","该条件适用于卡组或游戏内界面")
  for key in value:check_scene_fields(value[key],path+"."+str(key),kind,available)
 elif value is Array:
  for i in range(value.size()):check_scene_fields(value[i],path+"."+str(i),kind,available)

func check_auto_cycles(steps: Dictionary):
 var edges={}
 for id in steps:
  var s=steps[id]
  if (s.type=="info" and s.guide.get("next_button","manual")=="auto") or (s.type=="task" and s.task.get("timing","state_changed")=="enter") or (s.type=="wait" and s.wait_event=="step_entered"):
   edges[id]=[s.next]
   if s.has("failure"):edges[id].append(s.failure)
 for origin in edges:
  var pending=edges[origin].duplicate();var seen={}
  while not pending.is_empty():
   var id=pending.pop_back()
   if id==origin:error("steps."+origin+".next","可能造成自动跳转死循环");break
   if seen.has(id) or not edges.has(id):continue
   seen[id]=true;pending.append_array(edges[id])
