extends Node
## Only text and the standard deck code travel to the account service.
signal finished(answer: Dictionary)
const Account=preload("res://scripts/account_client.gd")
const PREFIX="MCP1"
const MAX_FRAME=16384
var server_url=Account.SERVER_URL
var peer: WebSocketMultiplayerPeer
var packet=PackedByteArray()
var sent=false
var started_at=0

func request(payload: Dictionary,token: String):
 if token.is_empty():finished.emit({"ok":false,"auth_required":true,"message":"请先登录玩家账号"});return
 var key=CryptoKey.new()
 if key.load_from_string(FileAccess.get_file_as_string(Account.PUBLIC_KEY_PATH),true)!=OK:
  fail("客户端缺少有效账号服务公钥");return
 var body=JSON.stringify(payload).to_utf8_buffer()
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(body)
 var auth={"s":token,"t":int(Time.get_unix_time_from_system()),"n":Crypto.new().generate_random_bytes(8).hex_encode(),"h":hash.finish().hex_encode()}
 var encrypted=Crypto.new().encrypt(key,JSON.stringify(auth).to_utf8_buffer())
 if encrypted.size()!=256:fail("无法加密登录凭据");return
 packet=PREFIX.to_utf8_buffer()+encrypted+body
 if packet.size()>MAX_FRAME:fail("上传内容过长，请缩短描述或卡组代码");return
 peer=WebSocketMultiplayerPeer.new()
 if peer.create_client(server_url)!=OK:peer=null;fail("无法连接套牌广场");return
 started_at=Time.get_ticks_msec();sent=false;set_process(true)

func _process(_delta):
 if peer==null:set_process(false);return
 peer.poll()
 if Time.get_ticks_msec()-started_at>15000:fail("套牌广场响应超时，请重试");return
 match peer.get_connection_status():
  MultiplayerPeer.CONNECTION_CONNECTED:
   if not sent:
    peer.set_target_peer(1);peer.transfer_channel=0;peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
    if peer.put_packet(packet)!=OK:fail("无法发送套牌请求");return
    sent=true;packet.clear()
   while peer.get_available_packet_count()>0:
    var bytes=peer.get_packet()
    if bytes.size()<4 or bytes.size()>65536 or bytes.slice(0,4).get_string_from_ascii()!=PREFIX:
     fail("套牌广场响应无效");return
    var answer=JSON.parse_string(bytes.slice(4).get_string_from_utf8())
    if not answer is Dictionary:fail("套牌广场响应无效");return
    close();finished.emit(answer);return
  MultiplayerPeer.CONNECTION_DISCONNECTED:fail("套牌广场连接已断开，请重试")

func close():
 if peer!=null:peer.close();peer=null
 packet.clear();set_process(false)

func fail(message: String):
 close();finished.emit({"ok":false,"message":message})

func _exit_tree():close()
