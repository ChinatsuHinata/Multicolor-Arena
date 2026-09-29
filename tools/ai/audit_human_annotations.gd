extends SceneTree
## Reproduce annotated decisions using only the evaluated seat's visible cards.
const Archive=preload("res://scripts/replay_archive.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
var results=[]
func _initialize():call_deferred("run")
func cards(e,list: Array) -> Array:
 return list.map(func(c):return {"uid":c.uid,"id":c.card_id,"name":e.cards[c.card_id].name,"zone":c.zone,"tapped":c.tapped,"damage":c.damage,"health":e.stat(c,"health"),"power":e.stat(c,"power"),"spirit":e.stat(c,"spirit"),"locked":not e.Cat.State.can_combat(e,c) if e.is_unit(c) else false})
func run():
 for file in DirAccess.get_files_at("res://training"):
  if not file.ends_with(".training.json"):continue
  var doc=Training.normalize_json(JSON.parse_string(FileAccess.get_file_as_string("res://training/"+file)))
  var replay_path="res://replay/"+doc.replay.file
  if FileAccess.get_sha256(replay_path)!=doc.replay.sha256:
   push_error("Replay hash differs from annotation: "+doc.replay.file);quit(1);return
  var loaded=Archive.read(replay_path)
  if loaded.has("error"):push_error(str(loaded));quit(1);return
  var training=Training.new();training.archive=loaded.archive
  for row in doc.annotations:
   var raw=training.restore(row.frame_index);var who=int(row.seat)
   if "--remilia-seat" in OS.get_cmdline_user_args():
    who=0 if raw.players[0].leader.card_id==AI.REMILIA else 1
   var decision_frame=int(row.frame_index)
   if "--decision-before" in OS.get_cmdline_user_args() and raw.phase=="main":
    for index in range(decision_frame, maxi(-1,decision_frame-12), -1):
     var candidate=training.restore(index)
     if candidate.turn!=raw.turn:break
     if candidate.phase=="main" and candidate.active==who and candidate.priority==who and candidate.stack.is_empty() and candidate.combat.is_empty() and loaded.archive.frame(index).projection.get("training_context",{}).get("decision_point",false):
      raw=candidate;decision_frame=index;break
   var e=State.fork(raw,who)
   e.ai_profiles[who]=AI.PROFILE
   # Prepare/draw annotations describe the immediately following possession.
   for i in range(4):
    if e.phase not in ["prepare","draw"]:break
    e.pass_priority(e.priority)
   if e.phase=="possession":e.pending={"kind":"possession","owner":who}
   var before={"file":file,"frame":row.frame_index,"seat":who,"turn":e.turn,"phase":e.phase,"active":e.active,"priority":e.priority,"comment":row.comment,"recommended":row.recommended_text,"life":e.players.map(func(p):return p.life),"leaders":e.players.map(func(p):return p.leader.duplicate(true)),"hand":cards(e,e.players[who].hand),"palette":cards(e,e.players[who].palette),"field":cards(e,e.players[who].field),"enemy":cards(e,e.players[1-who].field),"mana":e.source_resources(who).size(),"gun_reserve":AI.gungnir_reserve_score(e,who),"upcoming_gun":AI.upcoming_gungnir_value(e,who),"removal":[]}
   before.decision_frame=decision_frame
   before.annotation_seat=row.seat
   before.replay_hash=doc.replay.sha256
   for c in e.players[who].hand:
    if c.card_id in [AI.GUNGNIR,AI.AUTUMN,AI.MIST,AI.RED]:before.removal.append({"id":c.card_id,"target":AI.removal_target(e,who,c,AI.removal_enemies(e,who))})
   if e.phase=="possession":e.ai_possession(who)
   else:AI.step(e,who)
   before.after={"hand":cards(e,e.players[who].hand),"palette":cards(e,e.players[who].palette),"stack":e.stack.duplicate(true),"combat":e.combat.duplicate(true),"phase":e.phase,"priority":e.priority,"pending":e.pending.duplicate(true),"history":e.history.duplicate(true)}
   results.append(before)
   print("ANNOTATION ",file," frame ",row.frame_index," phase ",before.phase," reserve ",before.gun_reserve," stack ",JSON.stringify(e.stack)," history ",JSON.stringify(e.history))
 var output="res://work/ai-training/human-decision-audit.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.substr(9)
 var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "));f.close()
 print("AUDIT ",results.size()," annotations ",output);quit()
