extends Node
## Account-scoped private decks. Local deck files never store cloud credentials or slots.
signal changed
const Store=preload("res://scripts/deck_store.gd")
const Client=preload("res://scripts/deck_plaza_client.gd")
const LIMIT=10
var account=""
var token=""
var server_url=Client.Account.SERVER_URL
var decks: Array=[]
var busy=false
var status=""
var client
var generation=0

func set_session(username: String,session_token: String):
 if account==username and token==session_token:return
 generation+=1
 if is_instance_valid(client):client.queue_free();client=null
 account=username;token=session_token;decks=[];busy=false;status=""
 changed.emit()
 if not token.is_empty():refresh()

func refresh():request({"action":"list"})

func owns(deck: Dictionary) -> bool:
 return not account.is_empty() and deck.get("cloud_account","")==account.to_lower() and int(deck.get("cloud_slot",0)) in range(1,LIMIT+1)

func save_deck(deck: Dictionary,done: Callable):
 var error=Store.validate(deck,false,str(deck.get("rule_set",Store.RuleSet.OFFICIAL)))
 if not error.is_empty():done.call({"ok":false,"message":error});return
 if deck.has("cloud_slot") and not owns(deck):done.call({"ok":false,"message":"请登录该云端卡组所属的账号"});return
 request({"action":"save","slot":int(deck.get("cloud_slot",0)),"revision":int(deck.get("cloud_revision",0)),"deck_code":Store.encode(deck)},done)

func delete_deck(deck: Dictionary,done: Callable):
 if not owns(deck):done.call({"ok":false,"message":"请登录该云端卡组所属的账号"});return
 request({"action":"delete","slot":int(deck.cloud_slot),"revision":int(deck.cloud_revision)},done)

func unpack(answer: Dictionary) -> Dictionary:
 if not answer.get("decks") is Array or answer.decks.size()>LIMIT:return {"error":"云端卡组响应无效"}
 var result=[];var seen={}
 for item in answer.decks:
  if not item is Dictionary:return {"error":"云端卡组响应无效"}
  var slot=int(item.get("slot",0));var revision=int(item.get("revision",0));var identity=int(item.get("identity",0))
  if slot<1 or slot>LIMIT or seen.has(slot) or revision<1 or identity<1:return {"error":"云端卡组槽无效"}
  var decoded=Store.decode(str(item.get("deck_code","")),false)
  if decoded.has("error"):return {"error":"云端卡组无法读取："+decoded.error}
  var deck=decoded.deck
  deck.id="cloud:"+account.to_lower()+":"+str(slot)+":"+str(identity)
  deck.cloud_account=account.to_lower();deck.cloud_slot=slot;deck.cloud_revision=revision
  result.append(deck);seen[slot]=true
 return {"decks":result}

func request(payload: Dictionary,done: Callable=Callable()):
 if busy:
  if done.is_valid():done.call({"ok":false,"message":"正在同步云端卡组，请稍后重试"})
  return
 if token.is_empty():
  status="请先登录玩家账号"
  if done.is_valid():done.call({"ok":false,"message":status,"auth_required":true})
  changed.emit();return
 busy=true;status="正在同步云端卡组…";changed.emit()
 var session_generation=generation
 client=Client.new();client.protocol_prefix="MCK1";client.service_name="云端卡组";client.response_limit=131072;client.server_url=server_url;add_child(client)
 client.finished.connect(func(answer):
  if session_generation!=generation:return
  var completed=client;client=null;completed.queue_free();busy=false
  if answer.get("ok",false):
   var parsed=unpack(answer)
   if parsed.has("error"):answer={"ok":false,"message":parsed.error}
   else:decks=parsed.decks
  status="已同步 %d / %d 个云端卡组" % [decks.size(),LIMIT] if answer.get("ok",false) else str(answer.get("message","云端卡组同步失败"))
  if done.is_valid():done.call(answer)
  changed.emit())
 client.request(payload,token)
