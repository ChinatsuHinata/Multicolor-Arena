extends RefCounted
## Anonymous cosmetic grants contain only product IDs and relay signatures.
## They deliberately disclose no account, device or wallet information.
const KEY_PATH="res://data/account_public.pem"

static func verify(loadout: Variant) -> Array:
 if not loadout is Dictionary or loadout.size()>64:return []
 var key=CryptoKey.new()
 if key.load(KEY_PATH,true)!=OK:return []
 var products=[]
 for product in loadout:
  var signature=loadout[product]
  if not product is String or product.length()>64 or not signature is String or signature.length()!=344:continue
  if Crypto.new().verify(HashingContext.HASH_SHA256,("MCA:leader_emotes:"+product).sha256_buffer(),Marshalls.base64_to_raw(signature),key):products.append(product)
 return products
