extends Node
## RSA protected account requests. The short-lived game token stays in memory.
signal finished(ok: bool,message: String,username: String)

const SERVER_URL="ws://8.137.122.187:47862"
const PUBLIC_KEY_PATH="res://data/account_public.pem"
const PREFIX="MCA1"
const Identity=preload("res://net/local_identity.gd")
const Journal=preload("res://net/journal_store.gd")
var peer: WebSocketMultiplayerPeer
var server_url=SERVER_URL
var packet=PackedByteArray()
var sent=false
var started_at=0
var session_token=""
var remember_token=""
var nickname=""
var elo=1000
var rank: Dictionary={}
var password_change_stage=""
var password_next=""
var password_confirmation=""
var password_secret=""
var password_ticket=""

static func device_id() -> String:
 var path="res://saves/lan/identity.bin" if OS.has_feature("editor") else "user://lan/identity.bin"
 var identity=Identity.load_identity(path)
 if not FileAccess.file_exists(path):Journal.save_to(path,identity)
 return str(identity.installation).sha256_text().left(32)

func platform_code() -> String:
 return "a" if OS.has_feature("android") else "p"

static func filter_password_chars(value: String) -> String:
 var result=""
 for i in range(value.length()):
  var code=value.unicode_at(i)
  if code>=33 and code<=126:result+=value[i]
 return result

static func password_error(password: String) -> String:
 if filter_password_chars(password)!=password:return "密码只能使用英文字母、数字和英文符号"
 if password.length()<8 or password.length()>64 or password.to_utf8_buffer().size()>96:return "密码须为 8–64 个字符"
 return ""

func submit(action: String,username: String,password: String):
 var pattern=RegEx.new();pattern.compile("^[A-Za-z0-9_]{3,24}$")
 if pattern.search(username)==null:
  finished.emit(false,"账号须为 3–24 位英文字母、数字或下划线","");return
 var error=password_error(password)
 if not error.is_empty():finished.emit(false,error,"");return
 var data={"a":action,"u":username,"p":password,"d":device_id(),"o":platform_code(),
  "t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()}
 send_request(data)

func change_password(username: String,old_password: String,new_password: String,confirmation: String):
 var pattern=RegEx.new();pattern.compile("^[A-Za-z0-9_]{3,24}$")
 if pattern.search(username)==null:fail("账号须为 3–24 位英文字母、数字或下划线");return
 for value in [old_password,new_password,confirmation]:
  var error=password_error(value)
  if not error.is_empty():fail(error);return
 if new_password!=confirmation:fail("两次输入的新密码不一致");return
 if old_password==new_password:fail("新密码不能与旧密码相同");return
 password_change_stage="pwa"
 password_next=new_password;password_confirmation=confirmation
 password_secret=Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(16)).trim_suffix("==").replace("+","-").replace("/","_")
 var data=password_change_data("pwa",old_password)
 data["u"]=username
 data["v"]=password_secret
 send_request(data)

func password_change_data(action: String,password: String,ticket: String="") -> Dictionary:
 var data={"a":action,"p":password,"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()}
 if not ticket.is_empty():data["s"]=ticket
 return data

func clear_password_change():
 password_change_stage="";password_next="";password_confirmation="";password_secret="";password_ticket=""

func update_nickname(value: String,token: String):
 send_request({"a":"nickname","v":value,"s":token,"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()})

func resume(saved_token: String):
 send_request({"a":"resume","r":saved_token,"d":device_id(),"o":platform_code(),"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()})

func logout(token: String,saved_token: String=""):
 send_request({"a":"logout","s":token,"r":saved_token,"d":device_id(),"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()})

func send_request(data: Dictionary):
 sent=false
 if not FileAccess.file_exists(PUBLIC_KEY_PATH):fail("客户端缺少账号服务公钥");return
 var key=CryptoKey.new()
 if key.load_from_string(FileAccess.get_file_as_string(PUBLIC_KEY_PATH),true)!=OK:fail("账号服务公钥无效");return
 var plain=JSON.stringify(data).to_utf8_buffer()
 # Quoting long passwords can overflow an otherwise valid login/register packet.
 # The existing relay forwards this compact value without needing an update.
 if plain.size()>245 and data.get("a","") in ["login","register"] and data.get("p") is String:
  data=data.duplicate();data["p"]={"b":Marshalls.raw_to_base64(data.p.to_utf8_buffer())}
  plain=JSON.stringify(data).to_utf8_buffer()
 if plain.size()>245:fail("账号或密码过长");return
 var encrypted=Crypto.new().encrypt(key,plain)
 if encrypted.size()!=256:
  fail("账号或密码过长");return
 packet=PREFIX.to_utf8_buffer()+encrypted
 peer=WebSocketMultiplayerPeer.new()
 var err=peer.create_client(server_url)
 if err!=OK:
  fail("无法连接账号服务器");return
 started_at=Time.get_ticks_msec()
 set_process(true)

func _process(_delta):
 if peer==null:set_process(false);return
 peer.poll()
 if Time.get_ticks_msec()-started_at>12000:
  fail("账号服务器响应超时");return
 match peer.get_connection_status():
  MultiplayerPeer.CONNECTION_CONNECTED:
   if not sent:
    peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
    if peer.put_packet(packet)!=OK:fail("无法发送账号请求");return
    sent=true;packet.clear()
   while peer.get_available_packet_count()>0:
    var bytes=peer.get_packet()
    if bytes.size()>2048 or bytes.size()<4 or bytes.slice(0,4).get_string_from_ascii()!=PREFIX:
     fail("账号服务器响应无效");return
    var answer=JSON.parse_string(bytes.slice(4).get_string_from_utf8())
    if not answer is Dictionary:fail("账号服务器响应无效");return
    var ok=bool(answer.get("ok",false))
    var message=str(answer.get("message","账号服务器响应无效"))
    var name=str(answer.get("username","")) if ok else ""
    peer.close();peer=null;set_process(false)
    if not password_change_stage.is_empty():
     if not ok:
      if password_change_stage=="pwa" and message=="账号须为 3–24 位英文字母、数字或下划线":message="账号服务尚未支持修改密码，请等待服务更新"
      fail(message);return
     if password_change_stage!="pw_confirm":
      if password_change_stage=="pwa":
       var public_nonce=str(answer.get("password_ticket",""))
       var pattern=RegEx.new();pattern.compile("^[a-f0-9]{32}$")
       if pattern.search(public_nonce)==null:fail("修改密码验证响应无效");return
       password_ticket=(password_secret+":"+public_nonce).sha256_text().left(32);password_secret=""
      var value=password_next if password_change_stage=="pwa" else password_confirmation
      if password_change_stage=="pwa":password_next="";password_change_stage="pw_set"
      else:password_confirmation="";password_change_stage="pw_confirm"
      send_request(password_change_data(password_change_stage,value,password_ticket));return
     clear_password_change()
    session_token=str(answer.get("token","")) if ok else ""
    remember_token=str(answer.get("remember_token","")) if ok else ""
    nickname=str(answer.get("nickname",name)) if ok else ""
    elo=int(answer.get("elo",1000)) if ok else 1000
    rank=answer.get("rank",{}) if ok else {}
    finished.emit(ok,message,name)
    return
  MultiplayerPeer.CONNECTION_DISCONNECTED:
   fail("账号服务器连接已断开")

func fail(message: String):
 if peer!=null:peer.close();peer=null
 set_process(false)
 packet.clear();clear_password_change()
 finished.emit(false,message,"")
