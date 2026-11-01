extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")
const Series=preload("res://net/series_controller.gd")
const Session=preload("res://net/lan_session.gd")
var checks=0
var failures=[]

func check(ok: bool,title: String):
 checks+=1
 if ok:print("PASS "+title)
 else:failures.append(title);push_error(title)

func _initialize():
 check(Rules.IDS==[Rules.UNRESTRICTED,Rules.OFFICIAL,Rules.RANKED,Rules.TEST,Rules.MOD],"编辑器和房间提供独立的官限及段位匹配规则集")
 check(Rules.LABELS==["无限制","官限","段位匹配","测试卡组","模组"],"规则集名称与选项对应")
 for id in Rules.OFFICIAL_TWO:
  check(Rules.limit(id,Store.CARDS[id],Rules.OFFICIAL)==2,"官限保留特殊限二："+id)
  check(Rules.limit(id,Store.CARDS[id],Rules.RANKED)==2,"段位匹配保留官限限二："+id)
  check(Rules.limit(id,Store.CARDS[id],Rules.UNRESTRICTED)==4,"无限制使用普通同名上限："+id)
 check(Rules.limit("spell-ucs-011",Store.CARDS["spell-ucs-011"],Rules.OFFICIAL)==4,"Subterranean Rose 官限仍可使用四张")
 check(Rules.limit("spell-ucs-011",Store.CARDS["spell-ucs-011"],Rules.RANKED)==2,"Subterranean Rose 段位匹配最多两张")
 var rose=Store.blank("乐章限二");rose.leader="70"
 check(Store.add_card(rose,"spell-ucs-011","main",Rules.RANKED).is_empty(),"段位匹配主卡组可加入第一张乐章")
 check(Store.add_card(rose,"spell-ucs-011","side",Rules.RANKED).is_empty(),"段位匹配备牌可加入第二张乐章")
 check(not Store.add_card(rose,"spell-ucs-011","main",Rules.RANKED).is_empty() and rose.main.size()+rose.side.size()==2,"主副卡组合计限二且拒绝第三张时不修改卡组")
 check(Store.validate(rose,false,Rules.RANKED).is_empty(),"段位匹配主副卡组合计两张乐章合法")
 rose.side.append("spell-ucs-011")
 check(not Store.validate(rose,false,Rules.RANKED).is_empty(),"已有卡组含第三张乐章时段位匹配校验拒绝")
 for rule in [Rules.UNRESTRICTED,Rules.OFFICIAL,Rules.MOD,Rules.TEST]:
  var relaxed=rose.duplicate(true);relaxed.rule_set=rule
  check(Store.add_card(relaxed,"spell-ucs-011","main",rule).is_empty(),"其他规则保留第四张乐章："+rule)
 var official_series=Series.new();official_series.setup(Series.BO3,false,Rules.OFFICIAL)
 var ranked_series=Series.new();ranked_series.setup(Series.BO1_SIDEBOARD,false,Rules.RANKED)
 rose.rule_set=Rules.TEST
 check(official_series.set_deck(0,rose).is_empty(),"官限房间接受三张乐章卡组")
 check(not ranked_series.set_deck(0,rose).is_empty(),"段位匹配房间拒绝带测试标签的超量乐章卡组")
 rose.rule_set=Rules.OFFICIAL
 check(Store.prune_for_rule(rose,Rules.OFFICIAL)==0 and rose.main.size()+rose.side.size()==3,"切换到官限保留三张乐章")
 check(Store.prune_for_rule(rose,Rules.RANKED)==1 and rose.main.size()+rose.side.size()==2,"切换到段位匹配时保留两张并裁去超量乐章")
 var queue_deck=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks[0].duplicate(true)
 queue_deck.rule_set=Rules.OFFICIAL;queue_deck.main[0]="spell-ucs-011";queue_deck.main[1]="spell-ucs-011";queue_deck.side=["spell-ucs-011"]
 check(Store.validate(queue_deck,true,Rules.OFFICIAL).is_empty(),"三张乐章的五十张官限卡组合法")
 check(not Session.match_deck_error(queue_deck,"ranked").is_empty() and Session.match_deck_error(queue_deck,"casual").is_empty(),"入队按匹配模式校验乐章上限，不取卡组自身标签")
 var deck=Store.blank("规则集迁移");deck.leader="70";deck.main=["100"];deck.side=["103"]
 for rule in Rules.IDS:
  deck.rule_set=rule
  var imported=Store.decode(Store.encode(deck),false)
  check(imported.has("deck") and imported.deck.rule_set==rule,"卡组代码保留当前规则集："+rule)
 var retired=deck.duplicate(true);retired.rule_set="official_spx"
 check(not Store.validate(retired).is_empty(),"已移除规则不能作为当前构筑规则")
 var migrated=Store.decode(JSON.stringify(retired),false)
 check(migrated.has("deck") and migrated.deck.rule_set==Rules.UNRESTRICTED,"旧规则卡组代码迁移为无限制")
 check(migrated.has("deck") and migrated.deck.main==retired.main and migrated.deck.side==retired.side,"规则迁移保留主副卡组")
 check(retired.rule_set=="official_spx","读取迁移不修改原输入")
 var payload=JSON.stringify([retired.name,retired.leader,retired.main,retired.side,retired.rule_set])
 var bytes=payload.to_utf8_buffer()
 var compressed="MA1Z:"+str(bytes.size())+":"+Store._base64_short(bytes.compress(FileAccess.COMPRESSION_DEFLATE))
 for code in ["MA1:"+payload,compressed]:
  var imported=Store.decode(code,false)
  check(imported.has("deck") and imported.deck.rule_set==Rules.UNRESTRICTED,"普通及压缩旧卡组代码均可迁移")
 var path="res://work/deck-rule-sets-test/legacy.mdeck"
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"format":"multicolor:arena/deck","version":1,"deck":retired}));file.close()
 var saved=Store.read_file(path)
 check(saved.has("deck") and saved.deck.rule_set==Rules.UNRESTRICTED and saved.deck.main==retired.main,"本地旧卡组读取后迁移并保留卡牌")
 check(JSON.parse_string(FileAccess.get_file_as_string(path)).deck.rule_set==Rules.UNRESTRICTED,"迁移后的本地文件保存当前规则")
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(path+".bak")
 var unknown=deck.duplicate(true);unknown.rule_set="unknown"
 check(Store.decode(JSON.stringify(unknown),false).has("error"),"未知规则仍拒绝导入")
 for rule in [Rules.UNRESTRICTED,Rules.OFFICIAL,Rules.RANKED,Rules.TEST]:
  var series=Series.new();series.setup(Series.BO3,false,rule)
  deck.rule_set=rule
  check(series.state.rule_set==rule and series.set_deck(0,deck).is_empty(),"房间按当前规则登记卡组："+rule)
 print("DECK_RULE_SETS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
