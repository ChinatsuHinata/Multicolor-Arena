extends SceneTree
## Reviewed replay labels: preserve human originals, export seat-correct training copies.
const Archive=preload("res://scripts/replay_archive.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const OUTPUT="res://work/ai-training/recent-2026-09-27"
const MIST_FILE="2026-09-27T07-17-45 你 vs 人机_3974996492.mreply"
const SHORT_FILE="2026-09-27T06-55-19 你 vs 人机_2285646244.mreply"
const HUMAN_FILES=[
 "2026-09-27T03-07-55 你 vs 人机_1016025273_510f312539fa.training.json",
 "2026-09-27T06-37-25 你 vs 人机_1677616425_a9cf92614702.training.json",
 "2026-09-27T06-55-19 你 vs 人机_2285646244_9ad53586daf9.training.json"]
var report={"source":"user-requested replay review","latest_replays":[],"corrections":[],"mist_labels":[],"files":[]}

func _initialize():call_deferred("run")
func fail(message: String):
 push_error(message);quit(1)
func load_training(file: String):
 var path="res://replay/"+file;var loaded=Archive.read(path)
 if loaded.has("error"):fail(str(loaded));return null
 var training=Training.new();training.setup(loaded.archive,path)
 if not training.load_error.is_empty():fail(training.load_error);return null
 return training
func curated(training):
 training.output_path=OUTPUT+"/annotations/"+training.output_path.get_file()
 training.annotations=[]
func save_row(training,index: int,seat: int,fields: Dictionary,ctx: Dictionary) -> bool:
 var saved=training.put(index,seat,fields,ctx)
 if saved.has("error"):fail(str(saved));return false
 return true
func choose(ctx: Dictionary,kind: String,id: String="") -> Dictionary:
 for choice in ctx.choices:
  if choice.action.kind==kind and (id.is_empty() or choice.action.get("card_id","")==id):return choice
 return {}
func validate_pair(ctx: Dictionary,teacher: Dictionary,id: String) -> bool:
 return ctx.decision_available and not teacher.is_empty() and teacher.endpoint_complete and ctx.computer_choice.get("endpoint_complete",false) and ctx.computer_choice.get("source","")=="replay_actual" and ctx.computer_choice.action.get("card_id","")==id and teacher.action!=ctx.computer_choice.action

func mist_frames(training) -> Array:
 var result=[];var seen={}
 for i in range(training.archive.frames.size()):
  var packet=training.archive.frame(i)
  for entry in packet.projection.state.stack:
   if entry.get("kind","")!="card" or entry.get("owner",-1)!=1 or entry.card.card_id!=AI.MIST:continue
   var key=str(packet.game_id)+":"+str(entry.id)
   if seen.has(key):continue
   seen[key]=true;result.append(i-1)
 return result

func run():
 var recent=Array(DirAccess.get_files_at("res://replay")).filter(func(file):return file.ends_with(".mreply"))
 recent.sort();recent.reverse()
 if recent.slice(0,2)!=[MIST_FILE,SHORT_FILE]:fail("Latest replay selection changed; review the new files before labeling.");return
 var mist=load_training(MIST_FILE);var short=load_training(SHORT_FILE)
 if mist==null or short==null:return
 if mist_frames(mist)!=[172,238] or not mist_frames(short).is_empty():fail("Reviewed Mist cast locations differ from the replay.");return
 for training in [mist,short]:
  report.latest_replays.append({"file":training.source_path.get_file(),"sha256":training.replay_hash,"frames":training.archive.frames.size(),"mist_before_frames":mist_frames(training)})
 # Human text described Remilia even when the original UI selected its opponent.
 # Correct only the derived corpus; retain original files, seats and timestamps.
 for file in HUMAN_FILES:
  var original=Training.normalize_json(JSON.parse_string(FileAccess.get_file_as_string("res://training/"+file)))
  var training=load_training(original.replay.file)
  if training==null:return
  if training.replay_hash!=original.replay.sha256:fail("Human replay hash changed: "+file);return
  curated(training)
  for row in original.annotations:
   var index=int(row.frame_index)
   var gun_case=(file==HUMAN_FILES[1] and index==89) or (file==HUMAN_FILES[2] and index==90)
   if gun_case:index-=2
   if training.restore(index).players[1].leader.card_id!=AI.REMILIA:fail("Reviewed Remilia seat changed.");return
   var ctx=training.context(index,1)
   var fields={"comment":row.comment,"recommended_text":row.recommended_text,"confidence":row.confidence,"hindsight":row.hindsight,"teacher_action":{},"comparison_action":{},"tags":["reviewed_human_annotation"],"annotation_source":{"kind":"reviewed_human_text","file":file,"sha256":FileAccess.get_sha256("res://training/"+file),"frame_index":row.frame_index,"seat":row.seat,"correction":"Remilia seat 1; gun cases moved to the recorded pre-cast decision"}}
   if gun_case:
    var teacher=choose(ctx,"pass")
    if not validate_pair(ctx,teacher,AI.GUNGNIR):fail("Gungnir preference could not be verified at "+file+":"+str(index));return
    fields.teacher_action=teacher;fields.comparison_action=ctx.computer_choice
    fields.tags.append("reserve_gungnir")
   if not save_row(training,index,1,fields,ctx):return
   report.corrections.append({"file":file,"original_frame":row.frame_index,"training_frame":index,"original_seat":row.seat,"training_seat":1,"outcome":training.find(index,1).outcome,"preference":gun_case})
  report.files.append(training.output_path)
 # Review each actual cast; small bodies still matter when removing one proves
 # lethal or saves the role. These two cases instead spend four mana for little
 # pressure while the role is absent and Wings is a legal cheaper expansion.
 for index in [172,238]:
  var ctx=mist.context(index,1);var teacher=choose(ctx,"cast",AI.WINGS)
  if not validate_pair(ctx,teacher,AI.MIST):fail("Mist preference could not be verified at "+str(index));return
  var e=State.fork(mist.restore(index),1);var enemy=e.find_card(ctx.computer_choice.action.target.uid)
  var expected="character-fdf-092" if index==172 else "39"
  if enemy.card_id!=expected or AI.remilia_present(e,1) or e.players[0].life<=AI.ready_units(e,1).reduce(func(n,c):return n+maxi(0,e.stat(c,"spirit")),0):fail("Reviewed Mist tactical context changed.");return
  var comment="纳兹琳的进场检索已结算；本方自机未在场，只有一只可攻击的蝙蝠。为这一点灵力的进攻花红黑各两费消灭二费小单位，消耗了通用解牌和展开费用，收益偏低。阻挡有实际价值，不能把所有小单位一律视为无威胁。" if index==172 else "妖梦的进场战斗已结算；本方战场为空，没有需要解开阻挡的攻击者。妖梦是三费、灵力一、剩余二血的普通身体，此时用四费雾川消灭它不会恢复自机或保色。应优先建立战场与颜色来源，保留通用硬解处理后续核心威胁。"
  var fields={"comment":comment,"recommended_text":"先使用宵暗之翼铺两只蝙蝠，保留雾川；后续按公开局面恢复蕾米及颜色来源，保留通用解牌给核心威胁。此处只验证第一步展开，不把后续完整路线当作已验证示范。","confidence":"medium" if index==172 else "high","hindsight":false,"teacher_action":teacher,"comparison_action":ctx.computer_choice,"tags":["mist_overuse","low_value_target","expand_before_removal"],"annotation_source":{"kind":"agent_review","request":"标注最新两期录像中蕾米 AI 对小怪乱使用雾川","reviewed_target":expected,"evidence":"own hand and public zones only"}}
  if not save_row(mist,index,1,fields,ctx):return
  report.mist_labels.append({"frame_index":index,"step":index+1,"turn":e.turn,"seat":1,"target":e.cards[enemy.card_id].name,"confidence":fields.confidence,"teacher":teacher.label,"comparison":ctx.computer_choice.label,"endpoint_complete":true})
 # Copy the new replay's complete sidecar into this run's isolated corpus.
 var new_rows=[]
 for index in [172,238]:new_rows.append(mist.find(index,1))
 curated(mist);mist.annotations=new_rows
 var saved=mist.save()
 if saved.has("error"):fail(str(saved));return
 report.files.append(mist.output_path)
 var output=FileAccess.open(OUTPUT+"/review.json",FileAccess.WRITE)
 if output==null:fail("Cannot write review report.");return
 output.store_string(JSON.stringify(report,"  "));output.close()
 print("REVIEWED ",report.corrections.size()," human labels, ",report.mist_labels.size()," Mist preferences, ",report.files.size()," replay groups")
 quit()
