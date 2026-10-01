extends "res://tests/support/rules_base.gd"

const DEATH_EFFECTS=["mystia_life","nether_ghost","leader_death_damage","death_devour","cat:night_timer","spell-fdn-005"]

func observers():
 put("22") # 夜雀：己方单位死亡回血
 put("175") # 冥界：非衍生物单位死亡造亡灵
 put("41") # 饕餮：非衍生物单位死亡时吞食
 var yuyuko=put("71") # 幽幽子自机能力
 yuyuko.leader=true
 put("spell-fdf-040","field",1) # 对手单位死亡时加计时
 put("spell-fdn-005","field",1) # 对手单位消灭时强化
 put("spell-fdn-019") # 己方单位死亡能力额外触发
 put("character-htk-005") # 牺牲任意永久物仍应生效

func effect_count(key: String) -> int:
 return e.triggers.filter(func(t):return t.get("effect","")==key).size()

func run():
 for card_id in ["164","170","token-fdf-127","token-fdf-129"]:
  for mode in ["destroy","sacrifice","exile"]:
   fresh();observers()
   var victim=put(card_id)
   if card_id.begins_with("token-"):expect(victim.get("token",false),"%s 使用衍生物移动路径" % card_id)
   if mode=="destroy":e.destroy(victim)
   elif mode=="sacrifice":e.sacrifice(victim)
   else:e.move_to(victim,"exile")
   var action={"destroy":"消灭","sacrifice":"牺牲","exile":"移除"}[mode]
   for key in DEATH_EFFECTS:
    expect(effect_count(key)==0,"%s%s不触发单位死亡效果 %s" % [e.cards[card_id].kind,action,key])
   expect(not victim.has("died_turn"),"%s%s不记录为单位死亡" % [e.cards[card_id].kind,action])
   expect(effect_count("character-htk-005")==int(mode!="destroy"),"%s%s按永久物牺牲或移除规则处理" % [e.cards[card_id].kind,action])
 for mode in ["destroy","sacrifice"]:
  fresh();observers()
  var unit=put("53")
  if mode=="destroy":e.destroy(unit)
  else:e.sacrifice(unit)
  for key in ["mystia_life","nether_ghost","leader_death_damage","death_devour"]:
   expect(effect_count(key)==2,"己方单位%s使 %s 触发并额外触发一次" % ["死亡" if mode=="destroy" else "牺牲",key])
  for key in ["cat:night_timer","spell-fdn-005"]:
   expect(effect_count(key)==1,"己方单位%s使对手的 %s 触发一次" % ["死亡" if mode=="destroy" else "牺牲",key])
  expect(unit.get("died_turn",-1)==e.turn,"单位%s仍记录死亡回合" % ("死亡" if mode=="destroy" else "牺牲"))
 fresh();observers()
 var exiled=put("53")
 e.move_to(exiled,"exile")
 expect(effect_count("spell-fdn-005")==1,"单位被移除触发单位移除能力")
 for key in ["mystia_life","nether_ghost","leader_death_damage","death_devour","cat:night_timer"]:
  expect(effect_count(key)==0,"单位被移除不触发死亡效果 %s" % key)
 expect(not exiled.has("died_turn"),"单位被移除不记录为死亡")
 print("UNIT_DEATH_TRIGGERS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
