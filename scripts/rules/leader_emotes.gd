extends RefCounted
## Only this shipped catalogue enables a leader; deck/client data cannot opt in.
## Keys are canonical leader card IDs; each profile binds a product and six lines.
## A shipped profile supplies dialogue; ownership and equipment enable it per match.
const PROFILES={
 "character-rei-001":{"product_id":"emotes_reimu","lines":{
  "greeting":"是你啊，是要来和我对决的吧","praise":"不错的战术，那你能再接下我的攻击吗","mistake":"呼，是太激动了吗","surprise":"居然还有战意吗","threat":"不冷静下来可赢不了啊","surrender":"准备好再来一轮了吗，我是想要赢的"}},
 "character-mar-ex":{"product_id":"emotes_marisa","lines":{
  "greeting":"雾雨魔理沙，请多指教","praise":"哦，真是强劲的魔力啊","mistake":"不好不好，用错魔法了","surprise":"速度也能跟上吗","threat":"胜利者只能是我魔理沙da☆ze☆","surrender":"啊，还是锻炼不够啊"}},
 "character-fdf-ex01":{"product_id":"emotes_flandre","greetings":{"蕾米莉亚":"姐姐大人，是要和芙兰玩吗"},"lines":{
  "greeting":"你是来找芙兰玩的吗","praise":"好厉害，好久没这么玩了","mistake":"呼呣……","surprise":"好玩好玩，你还有这样的吗","threat":"你没这么弱吧，我还没玩够","surrender":"咲夜，我要吃布丁"}},
 "character-fdf-ex02":{"product_id":"emotes_yukari","greetings":{"西行寺幽幽子":"幽幽子，怎么没带着妖梦就出门了"},"lines":{
  "greeting":"幻想乡好安静，你能帮我忙起来吗","praise":"看来平时我不用忙是因为有你","mistake":"哎呀哎呀，平时还是少拜托蓝好了","surprise":"在制造麻烦上，你有与我相衬的水平","threat":"难道你也很无趣吗","surrender":"败了败了，你不错啊"}},
 "character-fdf-ex04":{"product_id":"emotes_tenshi","lines":{
  "greeting":"哈哈，你可敢与我一战！","praise":"看来我得认真动手了啊","mistake":"我只是没认真！","surprise":"果然有胆量！","threat":"你才是挑战者！","surrender":"哼！事已至此，改日再战！"}},
 "character-fdn-026":{"product_id":"emotes_satori_koishi","lines":{
  "greeting":"恋恋，别偷偷站在别人背后\n姐姐，她在想什么呢","praise":"恋，要看好这一手\n姐姐，她好厉害哦","mistake":"恋，认真一点\n觉大人，才是，不是恋恋的错哦","surprise":"看不透的人啊。\n为什么战斗中连我也顾得上啊。","threat":"恋恋，准备送客吧\n切碎浪费姐姐时间的人","surrender":"恋，你要不要再试一次。\n姐姐，换我来。"}},
 "71":{"product_id":"emotes_yuyuko","greetings":{"八云紫":"紫？我只是自己出门玩"},"lines":{
  "greeting":"不是亡者还请回去吧","praise":"比只会打扫卫生的妖梦厉害呢","mistake":"我想过重来，不过做不到吧","surprise":"你还坚持着呢","threat":"或许，我们更适合在别的地方相见","surrender":"魂灵当归，我如花散"}},
 "79":{"product_id":"emotes_aya","lines":{
  "greeting":"能接受我的采访吗，战斗的形式","praise":"你这真能上头条啊","mistake":"只是笔误，只是笔误啦","surprise":"从没想过的素材呢","threat":"没有什么采访的价值呢","surrender":"不行了不行了，我先回去写稿了"}},
 "76":{"product_id":"emotes_satori","lines":{
  "greeting":"我感受到你的杀气了哦","praise":"你的想法是对的","mistake":"我也没想到自己会这样做呢","surprise":"没想到你会这么选择","threat":"我听到你失败的想法了","surrender":"对，这局你赢了"}},
 "74":{"product_id":"emotes_remilia","greetings":{"芙兰朵露":"芙兰，你该回地下室了"},"lines":{
  "greeting":"你是来挑战你的命运的吗","praise":"或许你真的能开辟自己的道路","mistake":"命运本不是这样的","surprise":"这会是你胜利的可能性吗","threat":"你无法更改你的命运","surrender":"胜利属于勇敢者"}},
 "75":{"product_id":"emotes_sakuya","greetings":{"蕾米莉亚":"大小姐，我想自己做个决定"},"lines":{
  "greeting":"红魔馆要出行，请让开吧","praise":"不愧是你，真是让人倾佩，让人热血沸腾啊","mistake":"真是棘手了啊","surprise":"你刚刚是不是动了！？","threat":"就用这个砍下你的头吧","surrender":"命运如此，我不会否认"}},
 "85":{"product_id":"emotes_kaguya","greetings":{"藤原妹红":"妹红！受死吧！","八意永琳":"永琳，客人都回去了吧"},"lines":{
  "greeting":"你想要了解一下永恒吗","praise":"一个让人不经想要回味的瞬间，真是厉害","mistake":"须臾的失误而已，忘记这一刻吧","surprise":"真是珍惜的场景啊","threat":"汝甚不及千年前之顽童","surrender":"百年之后，能再有一战吗"}},
 "character-fdf-ex05":{"product_id":"emotes_keine","greetings":{"藤原妹红":"要一起去吃饭吗，妹红"},"lines":{
  "greeting":"这场战斗的痕迹，将在我胜利后被我消除","praise":"不虚此行呢","mistake":"希望不会留下不好的记录","surprise":"还是有记录一些的必要呢","threat":"看来不用管，你也会自己消失在历史里","surrender":"尽管把你的胜利记入脑海吧"}},
 "character-fdf-119":{"product_id":"emotes_patchouli","lines":{
  "greeting":"我还有书要看，你能快点安静下来吗","praise":"不枉我放下书来应对","mistake":"知识就是这样积累起来的","surprise":"找到了正确的答案吗","threat":"你只有这些不入流的伎俩吗","surrender":"我还要需要看更多的书"}},
 "character-ucs-068":{"product_id":"emotes_okina","lines":{
  "greeting":"迷路了吗，我可以送你回去哦","praise":"比一般的妖精们要厉害呢","mistake":"到底是哪扇门才对呢","surprise":"漂亮！太美妙了！","threat":"你看看你后面吧！门后的大手直接拿捏你！","surrender":"被干掉啦——！"}},
 "character-lof-003":{"product_id":"emotes_sanae","greetings":{"洩矢诹访子":"诹访子大人，请锻炼我吧","八坂神奈子":"神奈子大人，请锻炼我吧"},"lines":{
  "greeting":"守矢神社风祝，东风谷早苗，请多指教","praise":"向你学习，技多不压身","mistake":"身为巫女的锻炼还是不够呢","surprise":"这种事情也能做到的吗","threat":"只是这种程度的话，我就要退治你了","surrender":"不甘心，我会继续努力的"}},
 "new-eto-003":{"product_id":"emotes_renko_maribel","lines":{
  "greeting":"都说了，我们会一起回去的\n你回来了，这不说明旅程还没结束吗","praise":"好厉害的攻击啊，梅莉，欸？\n呜啊…………我回来的很快吧，莲子","mistake":"果然该离开了吧\n只是因为莲子老是突然就自己消失了","surprise":"你就是为了这一刻吗，梅莉\n很厉害吧","threat":"不要又让我一个人先回去了\n那我们尽快拿下对手吧","surrender":"梅莉，不能再继续了\n可是莲子，已经先一步离开幻想乡了吗"}},
 "new-eto-001":{"product_id":"emotes_sumireko","lines":{
  "greeting":"Yo！你也是幻想乡住民吧！","praise":"这就是幻想乡的强者吗","mistake":"糟糕糟糕，不该这样的","surprise":"这比灵异珠要厉害啊","threat":"看来只是二流的谣言啊","surrender":"好想快点醒来啊，这场恶梦"}},
 "character-kmo-001":{"product_id":"emotes_komachi","lines":{
  "greeting":"你好，平时有好好积攒铜钱吗","praise":"看来是个强者呢","mistake":"三途川原来有这么宽啊","surprise":"原来是生者在穿越三途川吗？！","threat":"我可以少收你几个铜钱哦","surrender":"再不走要被四季大人发现翘班了，溜了"}},
 "character-fdn-025":{"product_id":"emotes_scarlet_sisters","lines":{
  "greeting":"咲夜没有清理干净吗\n让我来消灭你吧","praise":"看来你有准备啊\n弱点到底在哪里呢","mistake":"芙兰你要小心\n姐姐大人那边才是","surprise":"居然能做到不落下风吗\n这是要我动真格了","threat":"别把衣服弄脏了\n芙兰会小心碾碎他的","surrender":"我认可你了\n能和芙兰继续玩吗"}},
 "character-fdf-102":{"product_id":"emotes_youmu","greetings":{"西行寺幽幽子":"幽幽子大人，饭菜都准备好了"},"lines":{
  "greeting":"来对决吧，依靠技术","praise":"精湛的技巧","mistake":"看来我还需要更多的训练","surprise":"居然能做出这样的反击","threat":"难道你只有这种水平吗","surrender":"必可，活用于下次"}},
 "soi_unit_086":{"product_id":"emotes_nue","lines":{
  "greeting":"你，想知道你在寻找的真相吗","praise":"你找到了不少线索啊","mistake":"呀，自己也看错了呢","surprise":"你是怎么破除虚妄的","threat":"你只不过是在于幻想中的敌人战斗","surrender":"真相就是，不在这里哦"}}
}
const KINDS=["greeting","praise","surprise","mistake","threat"]
const LABELS={"greeting":"问候","praise":"称赞","surprise":"惊讶","mistake":"失误","threat":"威胁","surrender":"投降"}
const DEFAULT_LINES={"greeting":"你好，请多指教！","praise":"打得漂亮！","surprise":"居然还有这一招！","mistake":"哎呀，失误了。","threat":"接下来可要小心了！","surrender":"这次是你赢了。"}
const COOLDOWN_SECONDS=10.0

static func make_profile(e,who: int) -> Dictionary:
 var leader=e.players[who].leader
 var id=str(e.cards.get(leader.card_id,{}).get("canonical_id",leader.card_id))
 var configured=PROFILES.get(id,{})
 var lines=DEFAULT_LINES.duplicate()
 for kind in DEFAULT_LINES:
  var line=configured.get("lines",{}).get(kind,"")
  if line is String and not line.strip_edges().is_empty():lines[kind]=line.substr(0,120)
 var other=e.players[1-who].leader
 var other_id=str(e.cards.get(other.card_id,{}).get("canonical_id",other.card_id))
 # Familiar greetings follow the opposing character, including other titles/art.
 var other_character=str(e.cards.get(other_id,{}).get("character",""))
 for character in configured.get("greetings",{}):
  if other_character.contains(character):
   lines.greeting=configured.greetings[character];break
 return {"enabled":false,"leader_id":id,"leader_uid":leader.uid,"lines":lines}

static func equip(e,who: int,products: Array):
 if who not in [0,1] or e.leader_emote_profiles.size()!=2:return
 var data=e.leader_emote_profiles[who]
 var product_id=str(PROFILES.get(data.leader_id,{}).get("product_id",""))
 data.enabled=not product_id.is_empty() and products.has(product_id)

static func profile(e,who: int) -> Dictionary:
 if e==null or who not in [0,1] or e.players.size()!=2:return {}
 if e.leader_emote_profiles.size()==2:return e.leader_emote_profiles[who]
 return make_profile(e,who)

static func remaining(e,who: int,now: float=-1.0) -> float:
 if who not in [0,1] or e.emote_ready_at.size()!=2:return 0.0
 if now<0:now=Time.get_unix_time_from_system()
 return maxf(0.0,float(e.emote_ready_at[who])-now)

static func send(e,who: int,kind: String,now: float=-1.0) -> String:
 if who not in [0,1] or e.players.size()!=2:return "不是有效的玩家"
 if kind not in KINDS:return "未知表情"
 if not profile(e,who).get("enabled",false):return "此自机尚未开通表情系统"
 if e.winner!=-2 or e.phase in ["mulligan","over"]:return "当前不能发送表情"
 if e.priority!=who or not e.pending.is_empty() or not e.entry_choices.is_empty():return "请在我方可响应且没有选择弹框时发送表情"
 if now<0:now=Time.get_unix_time_from_system()
 if remaining(e,who,now)>0:return "十秒内只能发送一次表情"
 e.emote_ready_at[who]=now+COOLDOWN_SECONDS
 emit_event(e,who,kind)
 e.revision+=1
 return ""

static func emit_event(e,who: int,kind: String):
 var data=profile(e,who)
 if data.is_empty() or not DEFAULT_LINES.has(kind):return
 e.emote_serial+=1
 var line=str(data.get("lines",{}).get(kind,DEFAULT_LINES[kind])) if data.get("enabled",false) else str(DEFAULT_LINES[kind])
 # Legacy clients safely show ordinary result text instead of assuming a card.
 e.presentation_events.append({"type":"result","emote":true,"serial":e.emote_serial,"owner":who,"kind":kind,"text":line,"leader_id":data.leader_id,"leader_uid":data.leader_uid})
