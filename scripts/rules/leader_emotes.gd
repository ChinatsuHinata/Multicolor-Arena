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
  "greeting":"幻想乡好安静，你能帮我忙起来吗","praise":"哼哼，很聪明嘛","mistake":"哎呀哎呀，平时还是少拜托蓝好了","surprise":"很聪明啊","threat":"难道你也很无趣吗","surrender":"败了败了，你不错啊"}},
 "character-fdf-ex04":{"product_id":"emotes_tenshi","lines":{
  "greeting":"哈哈，你可敢与我一战！","praise":"看来我得认真动手了啊","mistake":"我只是没认真！","surprise":"果然有胆量！","threat":"你才是挑战者！","surrender":"哼！事已至此，改日再战！"}},
 "character-fdn-026":{"product_id":"emotes_satori_koishi","lines":{
  "greeting":"恋恋，别偷偷站在别人背后\n姐姐，她在想什么呢","praise":"恋，这位客人真是难缠呢\n姐姐，她好厉害哦","mistake":"恋，认真一点\n不怪恋恋哦。","surprise":"看不透的人啊。","threat":"看来你并不是个受欢迎的客人。\n让姐姐好好欣赏你的血肉是怎么一点一点消散的。","surrender":"恋，你要不要再试一次。\n姐姐，换我来。"}},
 "71":{"product_id":"emotes_yuyuko","greetings":{"八云紫":"紫？我只是自己出门玩"},"lines":{
  "greeting":"不是亡者还请回去吧","praise":"感觉比妖梦厉害呢","mistake":"我想过重来，不过做不到吧","surprise":"你还坚持着呢","threat":"或许，我们更适合在别的地方相见","surrender":"魂灵当归，我如花散"}},
 "79":{"product_id":"emotes_aya","lines":{
  "greeting":"能接受我的采访吗，战斗的形式","praise":"你这真能上头条啊","mistake":"只是笔误，只是笔误啦","surprise":"从没想过的素材呢","threat":"没有什么采访的价值呢","surrender":"不行了不行了，我先回去写稿了"}},
 "76":{"product_id":"emotes_satori","lines":{
  "greeting":"我感受到你的杀气了哦","praise":"你的想法是对的","mistake":"我也没想到自己会这样做呢","surprise":"没想到你会这么选择","threat":"我听到你失败的想法了","surrender":"对，这局你赢了"}},
 "74":{"product_id":"emotes_remilia","greetings":{"芙兰朵露":"芙兰，你该回地下室了"},"lines":{
  "greeting":"你是来挑战你的命运的吗","praise":"或许你真的能开辟自己的道路","mistake":"命运本不是这样的","surprise":"这会是你胜利的可能性吗","threat":"你无法更改你的命运","surrender":"胜利属于勇敢者"}},
 "75":{"product_id":"emotes_sakuya","greetings":{"蕾米莉亚":"大小姐，我想自己做个决定"},"lines":{
  "greeting":"红魔馆要出行，请让开吧","praise":"不愧是你，真是让人倾佩，让人热血沸腾啊","mistake":"真是棘手了啊","surprise":"你刚刚是不是动了！？","threat":"就用这千把刀将你彻底穿刺吧。","surrender":"命运如此，我不会否认"}}
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
