extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Plaza=preload("res://scripts/deck_plaza.gd")
var checks=0
var failures=[]

class DownloadHost:
 extends RefCounted
 var decks=[]
 func reload_decks():decks=Store.load_decks().decks

func _initialize():call_deferred("run")

func expect(ok: bool,title: String):
 checks+=1
 if ok:print("PASS: ",title)
 else:failures.append(title);push_error(title)

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/deck-downloads/"+str(Time.get_ticks_usec()))
 var original=Store.blank("下载去重原件");original.rule_set="test";original.leader="70"
 original.main=["21","100","21","53"];original.side=["100","53"]
 original.art_overrides={"70":"tts_151600","21":"rec_unit_097"}
 expect(Store.save_file(original).is_empty(),"save independent local fixture")
 var snapshot=Store.read_file(Store.file_paths[original.id]).deck
 var same_name=original.duplicate(true);same_name.main=["100"]
 expect(Store.download_to_local(same_name).has("deck"),"same name with different cards downloads successfully")
 var count=Store.load_decks().decks.size()
 expect(Store.download_to_local(original).get("error","").contains("本地有重复卡组"),"same name and identical cards are refused")
 var spaced=original.duplicate(true);spaced.name="  "+original.name+"  "
 expect(Store.download_to_local(spaced).has("error"),"surrounding whitespace cannot bypass an otherwise identical deck")
 var reordered=original.duplicate(true)
 reordered.main.reverse();reordered.side.reverse();reordered.erase("art_overrides")
 expect(Store.download_to_local(reordered).get("error","").contains("本地有重复卡组"),"same name and reordered cards with cosmetic art changes are refused")
 reordered.main=["rec_unit_097","53","100","21"]
 expect(Store.same_cards(original,reordered) and Store.download_to_local(reordered).has("error"),"legacy alternate print IDs count as the canonical card")
 expect(Store.load_decks().decks.size()==count and Store.read_file(Store.file_paths[original.id]).deck==snapshot,"refused downloads create no files and leave the local deck intact")
 var renamed=reordered.duplicate(true);renamed.name="不同名字相同构成"
 expect(Store.download_to_local(renamed).has("deck"),"different name with identical canonical cards downloads successfully")
 for field in ["leader","main","side","zones"]:
  var changed=original.duplicate(true)
  match field:
   "leader":changed.leader="68"
   "main":changed.main.pop_back()
   "side":changed.side.pop_back()
   "zones":changed.main.erase("21");changed.side.append("21")
  expect(not Store.same_cards(original,changed),"different "+field+" is a distinct deck")
  var result=Store.download_to_local(changed)
  expect(result.has("deck"),"same name with different "+field+" downloads successfully")
 var cloud=original.duplicate(true);cloud.name="云端独立下载";cloud.main.append("100")
 cloud.id="cloud:test:1:7";cloud.cloud_account="test";cloud.cloud_slot=1;cloud.cloud_revision=7
 var result=Store.download_to_local(cloud)
 expect(result.has("deck") and result.deck.id!=cloud.id and not result.deck.has("cloud_slot"),"cloud downloads get a new local identity without cloud ownership")
 expect(result.has("deck") and result.deck.main==cloud.main and result.deck.side==cloud.side and result.deck.art_overrides==cloud.art_overrides,"successful downloads preserve card order and art")
 expect(cloud.has("cloud_slot") and cloud.id=="cloud:test:1:7","download leaves the cloud source untouched")
 var host=DownloadHost.new()
 var plaza=Plaza.new();plaza.app=host;plaza.notice=Label.new()
 var titled=original.duplicate(true);titled.name="代码中的另一个名称"
 plaza.current_post={"title":original.name,"deck_code":Store.encode(titled)}
 plaza.download_deck()
 expect(plaza.notice.text.contains("本地有重复卡组"),"plaza checks the displayed post title before saving")
 plaza.current_post={"title":original.name,"deck_code":Store.encode(reordered)}
 plaza.download_deck()
 expect(plaza.notice.text.contains("本地有重复卡组"),"plaza rejects same-name reordered alternate print duplicates")
 plaza.current_post.title="广场异名相同构成";plaza.download_deck()
 expect(plaza.notice.text.begins_with("已下载"),"plaza permits different titles with identical card contents")
 var changed_title=original.duplicate(true);changed_title.main=["100","53"]
 plaza.current_post={"title":original.name,"deck_code":Store.encode(changed_title)};plaza.download_deck()
 expect(plaza.notice.text.begins_with("已下载"),"plaza permits the same title with different card contents")
 var fresh=original.duplicate(true);fresh.main.append("53")
 plaza.current_post={"title":"广场首次下载","deck_code":Store.encode(fresh)}
 plaza.download_deck()
 expect(plaza.notice.text.begins_with("已下载") and host.decks.any(func(deck):return deck.name=="广场首次下载"),"plaza saves a distinct local copy and refreshes the deck list")
 count=Store.load_decks().decks.size();plaza.download_deck()
 expect(plaza.notice.text.contains("本地有重复卡组") and Store.load_decks().decks.size()==count,"repeated plaza download is refused without adding a file")
 plaza.notice.free();plaza.free();Store.Paths.root_override=""
 print("DECK DOWNLOADS: ",checks," checks, ",failures.size()," failures")
 quit(1 if failures.size() else 0)
