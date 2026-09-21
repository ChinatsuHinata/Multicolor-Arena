from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/card_database.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace('const HANDLERS=', 'static var last_error=""\nconst HANDLERS=',1)
s=s.replace('  var params=binding.get("参数",{})','''  var handler=binding["实现"]
  if handler in ["marisa_enter","marisa_spell","brave","exterminate"] and d["类别"] not in ["单位","自机"]: return "单位能力不能绑定到该类别"
  if handler in ["damage","counter_card"] and d["类别"]!="符卡": return "该结算效果目前仅支持符卡"
  if handler=="mana" and d["类别"]!="道具": return "该产色实现目前仅支持道具"
  if handler=="grant_leader_abilities" and d["类别"]!="结界": return "该持续能力目前仅支持结界"
  var params=binding.get("参数",{})''')
s=s.replace('static func load_cards() -> Dictionary:\n var cards={}','static func load_cards() -> Dictionary:\n last_error=""\n var cards={}')
s=s.replace('   push_error("卡牌数据库错误：%s，第%d行" % [path,parser.get_error_line()]); return {}','   last_error="卡牌数据库错误：%s，第%d行" % [path,parser.get_error_line()]\n   push_error(last_error); return {}')
s=s.replace('   push_error("卡牌数据库错误：%s · %s" % [path,error]); return {}','   last_error="卡牌数据库错误：%s · %s" % [path,error]\n   push_error(last_error); return {}')
f.write_text(s,encoding='utf-8')
f=p/'scripts/main.gd';s=f.read_text(encoding='utf-8-sig')
s=s.replace('var table_3d: Node3D\n','').replace('var battle = {}\n','')
s=s.replace(' load_error = loaded.get("error", "")',' load_error = loaded.get("error", "")\n if Store.CARDS.is_empty(): load_error=Store.Database.last_error')
f.write_text(s,encoding='utf-8')
f=p/'tests/test_duel_rules.gd';s=f.read_text(encoding='utf-8-sig')
needle=' var file=FileAccess.open("res://work/duel-rules-test.txt",FileAccess.WRITE)'
s=s.replace(needle,''' var db=preload("res://scripts/card_database.gd")
 expect(db.load_cards().size()==8,"all eight definitions pass schema and image validation")
 var definition=JSON.parse_string(FileAccess.get_file_as_string("res://cards/99.json"))
 var bad=definition.duplicate(true); bad["费用"]["黄"]=-1
 expect(not db.validate_definition(bad,"99").is_empty(),"negative card cost rejected")
 bad=definition.duplicate(true); bad["费用"]["黄"]=1.5
 expect(not db.validate_definition(bad,"99").is_empty(),"fractional card cost rejected")
 bad=definition.duplicate(true); bad["能力绑定"][0]["实现"]="unimplemented"
 expect(not db.validate_definition(bad,"99").is_empty(),"unregistered effects rejected instead of silently ignored")
 bad=definition.duplicate(true); bad["能力绑定"][0]["参数"]["数值"]="5"
 expect(not db.validate_definition(bad,"99").is_empty(),"non-numeric effect parameter rejected")
 bad=definition.duplicate(true); bad["类别"]="道具"
 expect(not db.validate_definition(bad,"99").is_empty(),"incompatible ability category rejected")
 var deck=Store.blank("禁入测试"); deck.leader="70"; deck.main=["99"]
 Store.CARDS["99"].constructible=false
 expect(not Store.validate(deck,false).is_empty(),"test mode still refuses construction-banned card")
 expect(not Store.add_card(deck,"99","main").is_empty(),"editor refuses construction-banned card")
 Store.CARDS["99"].constructible=true
 var file=FileAccess.open("res://work/duel-rules-test.txt",FileAccess.WRITE)''')
f.write_text(s,encoding='utf-8')
f=p/'docs/卡牌数据库与编写说明.md';s=f.read_text(encoding='utf-8-sig').replace('「红魔馆的蜡烛」','「蕾米莉亚的烛台」').replace('「河童的能量瓶」','「魔理沙的元素瓶」');f.write_text(s,encoding='utf-8')
