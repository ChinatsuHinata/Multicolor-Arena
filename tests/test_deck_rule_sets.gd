extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")
const Series=preload("res://net/series_controller.gd")
var checks=0
var failures=[]

func check(ok: bool,title: String):
 checks+=1
 if ok:print("PASS "+title)
 else:failures.append(title);push_error(title)

func _initialize():
 check(Rules.IDS==[Rules.UNRESTRICTED,Rules.OFFICIAL,Rules.TEST,Rules.MOD],"编辑器和房间只提供当前四种规则集")
 check(Rules.LABELS==["无限制","官限","测试卡组","模组"],"规则集名称与选项对应")
 for id in Rules.OFFICIAL_TWO:
  check(Rules.limit(id,Store.CARDS[id],Rules.OFFICIAL)==2,"官限保留特殊限二："+id)
  check(Rules.limit(id,Store.CARDS[id],Rules.UNRESTRICTED)==4,"无限制使用普通同名上限："+id)
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
 for rule in [Rules.UNRESTRICTED,Rules.OFFICIAL,Rules.TEST]:
  var series=Series.new();series.setup(Series.BO3,false,rule)
  deck.rule_set=rule
  check(series.state.rule_set==rule and series.set_deck(0,deck).is_empty(),"房间按当前规则登记卡组："+rule)
 print("DECK_RULE_SETS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
