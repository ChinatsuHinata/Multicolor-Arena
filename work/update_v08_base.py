from pathlib import Path
import shutil,json
root=Path('.')
b=root/'work/v08-backup'; b.mkdir(exist_ok=True)
for rel in ['scripts/duel_view.gd','scripts/duel_table.gd','scripts/duel_hand_card.gd','scripts/card_database.gd','cards/50.json','cards/53.json','cards/54.json','cards/57.json','cards/112.json']:
 shutil.copy2(root/rel,b/Path(rel).name)
for id in ['50','53','54','57','112']:
 p=root/f'cards/{id}.json';d=json.loads(p.read_text(encoding='utf-8'))
 d['能力文字']='' if id in ['53','57'] else d['能力文字'].split('\n\n')[0]
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=root/'scripts/card_database.gd';s=p.read_text(encoding='utf-8').replace('"完整说明","能力文字","来源"','"完整说明","来源"').replace(' if d["类别"] not in',' if not d.get("能力文字") is String: return "能力文字必须是文字"\n if d["类别"] not in',1);p.write_text(s,encoding='utf-8')
(root/'assets/combat_sword.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="M10 56L21 45M14 34L31 51" fill="none" stroke="#141b26" stroke-width="13" stroke-linecap="round"/><path d="M24 39L47 10L58 6L54 20L29 45Z" fill="#fff5cf" stroke="#bd8522" stroke-width="3"/><path d="M10 56L21 45M14 34L31 51" fill="none" stroke="#ffd65c" stroke-width="7" stroke-linecap="round"/><path d="M29 39L50 16" stroke="#d3dce7" stroke-width="3"/></svg>''',encoding='utf-8')
(root/'assets/combat_shield.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="M32 5L55 14L52 38Q48 52 32 60Q16 52 12 38L9 14Z" fill="#19293e" stroke="#10151e" stroke-width="6"/><path d="M32 7L53 15L50 37Q46 50 32 57Q18 50 14 37L11 15Z" fill="#285682" stroke="#a8d9ff" stroke-width="4"/><path d="M32 16V46M21 30H43" stroke="#e8f5ff" stroke-width="5" stroke-linecap="round"/></svg>''',encoding='utf-8')
p=root/'scripts/duel_hand_card.gd';s=p.read_text(encoding='utf-8').replace('style.border_color=Color("#ffd65c")','style.border_color=Color("#ffd65c") if selected else Color("#359bff")').replace('style.shadow_color=Color(1.0,0.67,0.13,0.72)','style.shadow_color=Color(1.0,0.67,0.13,0.72) if selected else Color(0.12,0.48,1.0,0.65)');p.write_text(s,encoding='utf-8')
p=root/'scripts/duel_table.gd';s=p.read_text(encoding='utf-8')
s=s.replace('signal empty_right_clicked','signal combat_animation_finished\nsignal combat_impact(attacker_uid: int,blocker_uid: int)\nsignal empty_right_clicked')
s=s.replace('var animation_duration=0.42','var animation_duration=0.42\nvar combat_animating=false\nvar deferred_sync={}\nvar collision_count=0\nvar last_collision_targets=[]')
s=s.replace('"gold":c.uid in highlighted or c.uid in chosen or reserved.any(func(r): return r.uid==c.uid)','"tapped":tapping,"blue":c.uid in highlighted,"gold":c.uid in chosen or reserved.any(func(r): return r.uid==c.uid)')
s=s.replace('  d.gold=entry.owner==0','  d.gold=entry.owner==0; d.blue=false; d.tapped=false')
s=s.replace(' reserved=payment_reservations; chosen=selection; highlighted=available',''' if combat_animating:
  deferred_sync={"reserved":payment_reservations.duplicate(true),"chosen":selection.duplicate(),"available":available.duplicate()}
  return
 if animate and duel.combat.get("step","")=="damage_window" and last_combat.get("step","")!="damage_window" and visuals.has("card_"+str(duel.combat.attacker.uid)):
  deferred_sync={"reserved":payment_reservations.duplicate(true),"chosen":selection.duplicate(),"available":available.duplicate()}
  animate_combat_resolution()
  return
 reserved=payment_reservations; chosen=selection; highlighted=available''')
s=s.replace('  outline.visible=d.gold or can_possess','  outline.visible=d.gold or d.blue or can_possess')
s=s.replace('  var hit=node.get_node("Hit")','''  var face_mat=node.get_node("Face").material_override
  face_mat.albedo_color=Color(0.43,0.46,0.51) if d.tapped and d.zone in ["field","palette"] else Color.WHITE
  var hit=node.get_node("Hit")''',1)
s=s.replace(' plane(root,Vector3.ZERO,CARD_SIZE,material(d.card_id)).name="Face"',' plane(root,Vector3.ZERO,CARD_SIZE,material(d.card_id).duplicate()).name="Face"')
s=s.replace('func mark_busy(): busy_until=Time.get_ticks_msec()+int(animation_duration*1000)','func mark_busy(): busy_until=maxi(busy_until,Time.get_ticks_msec()+int(animation_duration*1000))')
s=s.replace('func is_animating() -> bool: return Time.get_ticks_msec()<busy_until','func is_animating() -> bool: return combat_animating or Time.get_ticks_msec()<busy_until')
s += '''

func animate_combat_resolution():
 # Hold the pre-damage meshes, including dead units, until impact has been shown.
 combat_animating=true
 last_collision_targets=[]
 var fight=duel.combat.duplicate(true)
 var attacker=visuals["card_"+str(fight.attacker.uid)]
 stop_tween("card_"+str(fight.attacker.uid))
 var home=attacker.position
 var duration=maxf(0.025,animation_duration*0.5)
 var sequence=create_tween()
 if fight.blockers.is_empty():
  last_collision_targets.append(0)
  var destination=home+Vector3(0,0.7,-5.1 if fight.owner==0 else 5.1)
  sequence.tween_property(attacker,"position",destination,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
  sequence.tween_callback(func(): combat_impact.emit(fight.attacker.uid,0); collision_count+=1)
  sequence.tween_interval(duration*0.3)
  sequence.tween_property(attacker,"position",home,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 else:
  for target in fight.blockers:
   var key="card_"+str(target.uid)
   if not visuals.has(key): continue
   var blocker=visuals[key]
   stop_tween(key)
   var block_home=blocker.position
   var center=(home+block_home)*0.5+Vector3(0,0.65,0)
   var direction=(block_home-home).normalized()
   last_collision_targets.append(target.uid)
   sequence.tween_property(attacker,"position",center-direction*0.42,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
   sequence.parallel().tween_property(blocker,"position",center+direction*0.42,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
   sequence.tween_callback(func(): combat_impact.emit(fight.attacker.uid,target.uid); collision_count+=1)
   sequence.tween_interval(duration*0.3)
   sequence.tween_property(attacker,"position",home,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   sequence.parallel().tween_property(blocker,"position",block_home,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 animation_count+=1
 sequence.tween_callback(func():
  last_combat=duel.combat.duplicate(true)
  combat_animating=false
  var pending_sync=deferred_sync; deferred_sync={}
  sync(pending_sync.get("reserved",[]),pending_sync.get("chosen",[]),pending_sync.get("available",[]),true)
  combat_animation_finished.emit())
'''
p.write_text(s,encoding='utf-8')
print('Descriptions, outline colors, tap shading and combat animation written')
