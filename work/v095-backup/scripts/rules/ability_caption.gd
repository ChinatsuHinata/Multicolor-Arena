extends RefCounted
## Short stack captions identify the specific ability, never every ability on the card.
const TEXT={
 "enter_haste":"进场：目标单位本回合获得疾行。",
 "enter_drain":"进场：对手失去1点生命。",
 "enter_grave_damage":"进场：将目标墓地单位移回手牌，对目标造成其灵力值的伤害。",
 "enter_sweep":"进场：对每个对手操控的单位造成1点伤害。",
 "enter_color_evasion":"进场：目标己方单位本回合不能被所选颜色阻挡。",
 "enter_blink":"进场：移除目标其他己方单位，下个你的结束阶段移回战场。",
 "enter_fight":"进场：与目标对方单位进行一次战斗判定。",
 "enter_palette_replace":"进场：替换目标对手颜色盘中的牌，并放置贫乏指示物。",
 "enter_unblockable":"进场：本回合不能被阻挡。",
 "enter_halfghost":"进场：创造一个半灵衍生物。",
 "hand_autumn":"红色或黄色单位进场：将此牌从手牌放进战场。",
 "death_draw_life":"死去：抓一张牌，获得1点生命。",
 "death_drain":"死去：对手失去2点生命，你获得1点生命。",
 "death_damage":"死去：对目标造成2点伤害。",
 "death_palette":"死去：横置放进你的颜色盘。",
 "death_poverty":"死去：在对手颜色盘中至多两张牌上各放置一个贫乏指示物。",
 "death_undying":"死去：移回战场，放置一个+1/+1与+1指示物。",
 "death_devour":"单位死去：将其移除，在此单位上放置一个+1/+1与+1指示物。",
 "death_six":"死去：对每个单位各造成6点伤害。",
 "spell_rebirth":"被符卡消灭：在下个你的准备阶段移回战场。",
 "crystal":"结晶",
 "leave_ufo":"离场：创造一个飞碟衍生物。",
 "counter_six":"反制成功：对目标造成6点伤害。",
 "sacrifice_choice":"牺牲一个单位。",
 "delayed_return":"将该牌移回战场。",
 "combat_exile_target":"自机能力：移除受到战斗伤害的单位。",
 "token_sacrifice":"结束阶段：牺牲该衍生物。",
 "miracle":"奇迹",
 "untap":"英勇",
 "grave_return":"支付1红：从墓地移回手牌。",
 "grave_reanimate":"支付1绿1黑并弃一张牌：从墓地横置移回战场。",
 "exile_grave":"横置：移除墓地中的目标牌。若为单位，你获得1点生命，对手失去1点生命。",
 "sacrifice_buff":"牺牲一个单位：本回合获得+1/+1。",
 "leader_bounce":"自机能力：将目标己方单位移回手牌。"
}
static func text(entry: Dictionary) -> String:
 if entry.has("ability_text"): return entry.ability_text
 var effect=entry.get("effect","")
 if effect=="leader_death_damage": return "自机能力：对目标造成%d点伤害。" % int(entry.get("data",{}).get("amount",1))
 if effect=="returned_spirit_damage": return "对目标造成%d点伤害。" % int(entry.get("data",{}).get("amount",0))
 if TEXT.has(effect): return TEXT[effect]
 if entry.has("amount"):
  var name=entry.get("name","")
  var prefix="使用符卡时" if "使用符卡能力" in name else "进场" if "进战场能力" in name else "启动异能"
  return "%s：对目标%s造成%d点伤害。" % [prefix,"单位" if prefix!="启动异能" else "",int(entry.amount)]
 return ""
