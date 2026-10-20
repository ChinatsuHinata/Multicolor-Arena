extends "res://tests/support/rules_base.gd"

const Importer=preload("res://scripts/mod_importer.gd")
const Registry=DB.ModRegistry
var output=""

func write_json(path: String,data: Variant):
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify(data));file.close()

func run():
 output=ProjectSettings.globalize_path("res://work/unavailable-cards/"+str(Time.get_ticks_usec()))
 Store.Paths.root_override=output
 expect(Store.Paths.initialize().is_empty(),"使用隔离卡组与模组目录")
 Registry._shared=Registry.new();Store.CARDS=DB.load_cards(true)
 blocked_cards()
 legacy_inputs()
 mod_lifecycle()
 print("UNAVAILABLE_CARDS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func blocked_cards():
 fresh();mana()
 for id in DB.DISABLED_IDS:
  var info=Store.CARDS[id]
  expect(info.get("disabled",false) and not info.constructible,"限定卡全局屏蔽："+id)
  var deck=Store.blank("限定卡");deck.leader="70"
  for rule in Store.RuleSet.IDS:
   expect(not Store.RuleSet.allowed(id,info,rule) and Store.RuleSet.limit(id,info,rule)==0,"每种规则集均不可使用："+id+" · "+rule)
   expect(not Store.add_card(deck,id,"main",rule).is_empty(),"规则集加入操作被拒绝："+rule)
  expect(not Store.add_card(deck,id,"side").is_empty(),"未显式指定规则时也不能加入备牌")
  deck.main=[id]
  expect(not Store.validate(deck).is_empty(),"旧数据不能绕过构筑校验")
  var card=put(id,"hand")
  var before=JSON.stringify([e.players,e.stack,e.revision])
  expect(e.cast_error(0,card.uid).contains("屏蔽") and not e.commit_cast(0,card.uid,{},[]).is_empty(),"引擎拒绝使用已屏蔽卡："+id)
  expect(JSON.stringify([e.players,e.stack,e.revision])==before,"拒绝时不扣费、不移动卡牌")
  e.move_to(card,"field",false)
  expect(e.available_actions(0,card.uid,true).is_empty() and e.extension_activation_error(0,card,"n21:gourd_counter").contains("屏蔽"),"旧战场卡也不能发动能力")

func legacy_inputs():
 var source=Store.blank("旧有限定卡卡组");source.id="legacy-blocked";source.rule_set=Store.RuleSet.TEST
 source.leader="new-spx-001";source.main=["164","new-spx-007","167"]+DB.DISABLED_IDS
 source.side=["new-spx-007","165"]
 source.art_overrides={"new-spx-001":"obsolete"}
 var expected=Store.migrate_unavailable_cards(source)
 expect(expected.main==["164","167"] and expected.side==["165"] and expected.leader=="" and expected.art_overrides.is_empty(),"清理主备牌、自机和异画设置，保留其余卡牌顺序")
 expect(source.main.has("new-spx-007") and source.leader=="new-spx-001","过滤不修改调用者的原始对象")
 expected=Store.clean_deck(expected)
 var parts=[source.name,source.leader,Store._pack_cards(source.main),Store._pack_cards(source.side),source.rule_set,source.art_overrides]
 var payload=JSON.stringify(parts);var bytes=payload.to_utf8_buffer()
 for code in [JSON.stringify(source),"MA1:"+payload,"MA1Z:"+str(bytes.size())+":"+Store._base64_short(bytes.compress(FileAccess.COMPRESSION_DEFLATE))]:
  var decoded=Store.decode(code,false)
  expect(decoded.has("deck") and decoded.deck.main==expected.main and decoded.deck.side==expected.side and decoded.deck.leader.is_empty(),"JSON、普通代码与压缩代码均可加载并清理")
 var path=Store.folder().path_join("legacy.mdeck")
 write_json(path,{"format":"multicolor:arena/deck","version":1,"deck":source})
 var loaded=Store.read_file(path)
 expect(loaded.get("deck",{})==expected,"单独卡组文件保留缺失自机的卡组")
 expect(JSON.parse_string(FileAccess.get_file_as_string(path)).deck==expected and FileAccess.file_exists(path+".bak"),"加载时保存清理结果并保留原文件备份")
 expect(Store.read_file(path).get("deck",{})==expected,"重复加载稳定")
 expect(not Store.validate(expected,true,Store.RuleSet.TEST).is_empty(),"缺失自机的卡组仍不能用于对战")
 path=output.path_join("legacy.json")
 write_json(path,{"version":1,"decks":[source]})
 expect(Store.load_decks(path).get("decks",[]).map(Store.clean_deck)==[expected],"旧版集合文件自动清理")
 expect(Store.recover_legacy_decks(path).get("decks",[])==[expected],"旧存档迁移保留清理后的不完整卡组")
 source.leader="70";source.main=["unknown-base-card"]
 expect(Store.decode(JSON.stringify(source)).has("error"),"未知本体卡仍按损坏数据处理")

func mod_lifecycle():
 var config=[{"path":"res://examples/testmod","enabled":true}]
 expect(Importer.apply_configuration(config).is_empty(),"登记真实模组样例")
 var leaders=Store.CARDS.keys().filter(func(id):return id.begins_with("testmod/") and Store.CARDS[id].kind=="自机")
 expect(not leaders.is_empty(),"样例提供模组自机")
 if leaders.is_empty():return
 var source=Store.blank("删除模组后待修复卡组");source.id="mod-lifecycle";source.rule_set=Store.RuleSet.MOD
 source.leader=leaders[0];source.main=["164","testmod/control","testmod/fuel"];source.side=["testmod/control","167"]
 var path=Store.folder().path_join("mod.mdeck")
 expect(Store.save_file(source,path).is_empty(),"保存含模组自机与主备牌的卡组")
 var code=Store.encode(source);var original=FileAccess.get_file_as_string(path)
 expect(Importer.apply_configuration([{"path":config[0].path,"enabled":false}]).is_empty(),"关闭模组")
 expect(not Registry.shared().packs.has("testmod") and Store.CARDS[source.leader].get("inactive_mod",false),"只读展示资料可用，模组脚本未登记")
 expect(Store.read_file(path).get("deck",{})==source and FileAccess.get_file_as_string(path)==original,"关闭模组后加载不改变卡组内容或文件")
 expect(Store.decode(code,false).get("deck",{}).get("main",[])==source.main,"关闭模组后导入仍完整保留卡牌")
 expect(not Store.validate(source,false,Store.RuleSet.MOD).is_empty(),"关闭的模组卡保留但不能开始对战")
 expect(Importer.apply_configuration(config).is_empty(),"重新启用模组")
 expect(Store.read_file(path).get("deck",{})==source and Store.validate(source,false,Store.RuleSet.MOD).is_empty(),"重新启用后卡组完整恢复使用")
 var removed=Importer.delete_mod(config[0].path,config)
 expect(not removed.has("error"),"删除外部模组登记")
 var expected=Store.migrate_unavailable_cards(source)
 expect(expected.leader.is_empty() and expected.main==["164"] and expected.side==["167"],"仅删除模组时清理对应自机、主牌和备牌")
 expect(Store.read_file(path).get("deck",{})==expected,"删除后的卡组仍正常加载")
 expect(JSON.parse_string(FileAccess.get_file_as_string(path)).deck==expected,"删除模组后的清理结果自动保存")
 expect(Store.decode(code,false).get("deck",{}).get("main",[])==["164"],"旧模组卡组代码加载时同样清理")
 var portable=Store.load_decks()
 expect(not portable.has("error") and portable.decks.any(func(deck):return deck.id==source.id and deck.leader.is_empty()),"画廊数据保留待补自机的卡组")
