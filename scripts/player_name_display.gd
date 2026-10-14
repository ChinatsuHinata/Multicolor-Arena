extends RefCounted
const MAX_WIDTH=12

static func caption(value: String) -> String:
 var width=0
 for index in range(value.length()):
  # Chinese and other non-ASCII characters take two display units.
  width+=1 if value.unicode_at(index)<128 else 2
  if width>MAX_WIDTH:return value.left(index)
 return value

static func sorted_names(names: Array) -> Array:
 var long_names=[]
 for name in names:
  if name is String and caption(name)!=name and name not in long_names:long_names.append(name)
 long_names.sort_custom(func(a,b):return a.length()>b.length())
 return long_names

## Format messages containing full nicknames without changing stored player data.
static func in_text(value: String,names: Array) -> String:
 var long_names=sorted_names(names)
 if long_names.is_empty():return value
 var result=""
 var cursor=0
 while cursor<value.length():
  var matched=false
  for name in long_names:
   if value.substr(cursor,name.length())==name:
    result+=caption(name);cursor+=name.length();matched=true;break
  if not matched:result+=value[cursor];cursor+=1
 return result

## Battle messages also contain card names; only shorten their player references.
static func battle_text(value: String,names: Array) -> String:
 if value.begins_with("投点 ") or value.begins_with("上一局落败 · ") or value.begins_with("上一局平局，沿用选择权 · "):return in_text(value,names)
 for name in sorted_names(names):
  if value.begins_with("第 ") and value.ends_with(" 回合 · "+name):return value.left(value.length()-name.length())+caption(name)
  for prefix in ["","调试加入：","布置删除：","布置复制：","布置单位：","布置初始血量："]:
   if not value.begins_with(prefix+name):continue
   var tail=value.substr(prefix.length()+name.length())
   if prefix.is_empty() and not player_message_tail(tail):continue
   return prefix+caption(name)+tail
 return value

static func player_message_tail(value: String) -> bool:
 for prefix in ["宣言 · ","掷硬币 · ","已提交起手选择","完成调度","使用 ","洗牌","的二重身置于自机区"," · 生命 ","投降","生命归零","牌库不足，无法抓牌","具有三个或更多铜钱指示物","返魂蝶计时归零","最后ノ理想国"]:
  if value.begins_with(prefix):return true
 for zone in ["手牌","牌库","战场","颜色盘","墓地","除外","自机区","堆叠","自机返回","消失","本局游戏外"]:
  if value.begins_with(" · "+zone+" → "):return true
 return value.begins_with(" · ") and (value.ends_with("常驻减费") or value.ends_with("空场自动跳过（对方场上无单位时）"))

static func replay_filename(value: String) -> String:
 var pattern=RegEx.new()
 pattern.compile("^(\\d{4}-\\d{2}-\\d{2}T\\d{2}-\\d{2}-\\d{2} )(.+) vs (.+)(_\\d+\\.mreply)$")
 var found=pattern.search(value)
 if found==null:return value
 return found.get_string(1)+caption(found.get_string(2))+" vs "+caption(found.get_string(3))+found.get_string(4)
