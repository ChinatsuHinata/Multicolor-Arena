extends RefCounted
## Address typed by a player. A tunnel can provide a DNS name and a UDP port.

static func parse(value: String,default_port: int) -> Dictionary:
 var input=value.strip_edges()
 if input.begins_with("udp://"):input=input.substr(6)
 var host=input
 var port=default_port
 if input.begins_with("["):
  var closing=input.find("]")
  if closing<0:return {"error":"IPv6 地址缺少右方括号"}
  host=input.substr(1,closing-1)
  var suffix=input.substr(closing+1)
  if not suffix.is_empty():
   if not suffix.begins_with(":"):return {"error":"地址格式应为 [IPv6]:端口"}
   var number=suffix.substr(1)
   if not number.is_valid_int():return {"error":"端口必须是数字"}
   port=int(number)
 elif not input.is_valid_ip_address() and input.count(":")==1:
  var split_at=input.rfind(":")
  host=input.substr(0,split_at)
  var number=input.substr(split_at+1)
  if not number.is_valid_int():return {"error":"端口必须是数字"}
  port=int(number)
 if port<1 or port>65535:return {"error":"端口必须在 1 至 65535 之间"}
 if host.is_empty():return {"error":"请输入房主的 IP 或域名"}
 if input.begins_with("[") and not host.is_valid_ip_address():return {"error":"IPv6 地址无效"}
 if not host.is_valid_ip_address():
  if host.length()>253 or host.begins_with(".") or host.ends_with("."):return {"error":"域名格式无效"}
  for part in host.split("."):
   if part.is_empty() or part.length()>63 or part.begins_with("-") or part.ends_with("-"):return {"error":"域名格式无效"}
   for character in part:
    var code=character.unicode_at(0)
    if not (code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122 or code==45):return {"error":"请输入 IP 或有效域名，不要输入网页链接"}
 return {"host":host,"port":port}

static func resolve(host: String) -> String:
 if host.is_valid_ip_address():return host
 var ipv4=IP.resolve_hostname(host,IP.TYPE_IPV4)
 return ipv4 if not ipv4.is_empty() else IP.resolve_hostname(host,IP.TYPE_IPV6)
