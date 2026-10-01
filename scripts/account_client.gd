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

func submit(action: String,username: String,password: String):
 var pattern=RegEx.new();pattern.compile("^[A-Za-z0-9_]{3,24}$")
 if pattern.search(username)==null:
  finished.emit(false,"账号须为 3–24 位英文字母、数字或下划线","");return
 if filter_password_chars(password)!=password:
  finished.emit(false,"密码只能使用英文字母、数字和英文符号","");return
 if password.length()<8 or password.length()>64 or password.to_utf8_buffer().size()>96:
  finished.emit(false,"密码须为 8–64 个字符","");return
 var data={"a":action,"u":username,"p":password,"d":device_id(),"o":platform_code(),
  "t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()}
 send_request(data)

func update_nickname(value: String,token: String):
 send_request({"a":"nickname","v":value,"s":token,"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()})

func resume(saved_token: String):
 send_request({"a":"resume","r":saved_token,"d":device_id(),"o":platform_code(),"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()})

func logout(token: String,saved_token: String=""):
 send_request({"a":"logout","s":token,"r":saved_token,"d":device_id(),"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode()})

func send_request(data: Dictionary):
 sent=false
 if not FileAccess.file_exists(PUBLIC_KEY_PATH):finished.emit(false,"客户端缺少账号服务公钥","");return
 var key=CryptoKey.new()
 if key.load_from_string(FileAccess.get_file_as_string(PUBLIC_KEY_PATH),true)!=OK:finished.emit(false,"账号服务公钥无效","");return
 var plain=JSON.stringify(data).to_utf8_buffer()
 var encrypted=Crypto.new().encrypt(key,plain)
 if encrypted.size()!=256:
  finished.emit(false,"账号或密码过长","");return
 packet=PREFIX.to_utf8_buffer()+encrypted
 peer=WebSocketMultiplayerPeer.new()
 var err=peer.create_client(server_url)
 if err!=OK:
  peer=null;finished.emit(false,"无法连接账号服务器","");return
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
    session_token=str(answer.get("token","")) if ok else ""
    remember_token=str(answer.get("remember_token","")) if ok else ""
    nickname=str(answer.get("nickname",name)) if ok else ""
    peer.close();peer=null;set_process(false)
    finished.emit(ok,message,name)
    return
  MultiplayerPeer.CONNECTION_DISCONNECTED:
   fail("账号服务器连接已断开")

func fail(message: String):
 if peer!=null:peer.close();peer=null
 set_process(false)
 finished.emit(false,message,"")
