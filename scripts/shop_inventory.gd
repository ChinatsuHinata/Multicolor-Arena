extends RefCounted
## Ownership comes from the account snapshot. Local files hold only equipment
## preferences and explicitly labelled, free development-only trial claims.
signal changed
var catalogue: Array=[]
var account=""
var purchased_ids: Dictionary={}
var server_purchases: Dictionary={}
var preferences: Dictionary={}
var storage_path=""
var allow_test_products=false
var error=""
var grants: Dictionary={}
var sale: Dictionary={}
var server_time=-1
var server_tick_ms=0

func initialize(path: String,test_products: bool=false):
 storage_path=path;allow_test_products=test_products;preferences={};error="";sale={}
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/shop.json"))
 catalogue=[]
 if data is Dictionary and data.get("products") is Array:
  if data.get("sale") is Dictionary:sale=data.sale.duplicate(true)
  for item in data.products:
   if item is Dictionary and (not item.get("test_only",false) or allow_test_products):catalogue.append(item.duplicate(true))
 if FileAccess.file_exists(storage_path):
  var saved=JSON.parse_string(FileAccess.get_file_as_string(storage_path))
  if saved is Dictionary and saved.get("accounts") is Dictionary:preferences=saved.accounts
  else:error="商品使用设置读取失败，请检查本地设置文件。"

func sync_session(username: String,snapshot: Dictionary):
 grants=snapshot.get("shop_grants",{}).duplicate(true) if snapshot.get("shop_grants") is Dictionary else {}
 var next_account=username.to_lower()
 if account!=next_account:server_time=-1
 if snapshot.has("server_time") and int(snapshot.server_time)!=server_time:
  server_time=int(snapshot.server_time);server_tick_ms=Time.get_ticks_msec()
 var next_purchases: Dictionary={}
 var ids=snapshot.get("purchased_product_ids",[])
 if not next_account.is_empty() and ids is Array:
  for id in ids:
   if id is String and not id.is_empty():next_purchases[id]=true
 var updated=account!=next_account or server_purchases!=next_purchases
 account=next_account;server_purchases=next_purchases
 rebuild_ownership()
 if updated:changed.emit()

func account_preferences() -> Dictionary:
 var result=preferences.get(account,{})
 return result if result is Dictionary else {}

func product(id: String) -> Dictionary:
 for item in catalogue:
  if str(item.get("id",""))==id:return item
 return {}

func current_time() -> float:
 return server_time+(Time.get_ticks_msec()-server_tick_ms)/1000.0 if server_time>=0 else Time.get_unix_time_from_system()

func sale_active(now: float=-1) -> bool:
 if now<0:now=current_time()
 return float(sale.get("starts_at",0))<=now and now<float(sale.get("ends_at",0))

func is_special(item: Dictionary,now: float=-1) -> bool:
 return not item.get("test_only",false) and item.has("price") and sale_active(now) and (sale.get("all_products",false) or item.get("special",false))

static func discounted_price(price: int) -> int:
 # All present and future discounts are half price, rounded up to whole copper.
 return ceili(price*0.5)

func price_for(item: Dictionary,now: float=-1) -> int:
 var price=int(item.get("price",0))
 return discounted_price(price) if is_special(item,now) else price

func sale_deadline_text() -> String:
 var date=Time.get_datetime_dict_from_unix_time(int(sale.get("ends_at",0))+8*3600)
 return "%d月%d日 %02d:%02d（北京时间）" % [date.month,date.day,date.hour,date.minute]

func rebuild_ownership():
 purchased_ids=server_purchases.duplicate()
 if account.is_empty():purchased_ids.clear();return
 var claims=account_preferences().get("test_claims",[])
 if not allow_test_products or not claims is Array:return
 for id in claims:
  if id is String and can_claim_test(product(id)):purchased_ids[id]=true

func can_claim_test(item: Dictionary) -> bool:
 return allow_test_products and not account.is_empty() and item.get("test_only",false)==true and item.get("free_test",false)==true

func owns(id: String) -> bool:
 return not account.is_empty() and purchased_ids.has(id)

func battle_enabled(id: String) -> bool:
 var settings=account_preferences().get("battle_enabled",{})
 return owns(id) and settings is Dictionary and settings.get(id,true)==true

func set_battle_enabled(id: String,enabled: bool) -> bool:
 if not owns(id) or product(id).is_empty():error="当前账号尚未拥有此商品。";return false
 var next=account_preferences().duplicate(true)
 var switches=next.get("battle_enabled",{})
 if not switches is Dictionary:switches={}
 switches[id]=enabled;next.battle_enabled=switches
 return save_preferences(next)

func claim_test(id: String) -> bool:
 if not can_claim_test(product(id)):error="请登录测试账号后领取体验商品。";return false
 if owns(id):return true
 var next=account_preferences().duplicate(true)
 var claims=next.get("test_claims",[])
 if not claims is Array:claims=[]
 if not claims.has(id):claims.append(id)
 next.test_claims=claims
 return save_preferences(next)

func save_preferences(next: Dictionary) -> bool:
 var saved=preferences.duplicate(true);saved[account]=next
 if storage_path.is_empty():error="商品使用设置尚未初始化。";return false
 var temporary=storage_path+".tmp"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:error="无法保存商品使用设置。";return false
 file.store_string(JSON.stringify({"accounts":saved}));file.flush()
 var ok=file.get_error()==OK;file.close()
 if not ok or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(storage_path))!=OK:
  error="无法保存商品使用设置。";return false
 preferences=saved;error="";rebuild_ownership();changed.emit()
 return true

func battle_loadout(include_test: bool=false) -> Dictionary:
 var result: Dictionary={}
 for item in catalogue:
  var id=str(item.get("id",""))
  if not battle_enabled(id):continue
  if item.get("test_only",false) and (not allow_test_products or not include_test):continue
  result[id]=item.duplicate(true)
 return result

func network_loadout() -> Dictionary:
 var result={}
 for id in battle_loadout():
  if grants.get(id) is String:result[id]=grants[id]
 return result
