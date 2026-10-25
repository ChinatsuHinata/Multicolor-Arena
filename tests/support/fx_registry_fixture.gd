extends RefCounted
## 仅供专项测试注入的内存清单，直接使用无视觉内容的品类基类。
## 不写入 fx/definitions，也不会被正式对局发现或导出。

const Registry=preload("res://fx/fx_registry.gd")

static func create():
 var registry=Registry.new()
 registry.loaded=true
 for category in ["entrance","foil","spell"]:
  var id="probe_"+category
  registry.definitions[id]={
   "id":id,"category":category,"free":true,"budget_ms":700,
   "script":"res://fx/categories/fx_"+category+"_module.gd"
  }
 return registry
