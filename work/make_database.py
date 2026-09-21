from pathlib import Path
import re,json
r=Path(r'C:\Users\tzx20\Documents\test')
s=(r/'scripts/deck_store.gd').read_text(encoding='utf-8-sig')
a=s.index('const CARDS = ')+len('const CARDS = ');b=s.index('\nstatic func blank',a)
old=json.loads(s[a:b])
costs={'68':{'蓝':2,'黄':2},'70':{'红':2,'黄':1},'99':{'黄':3},'100':{'黄':2},'164':{'黄':2},'165':{'红':2},'167':{'蓝':2},'170':{'红':2,'黄':1}}
for id,c in old.items():
 data={'格式版本':1,'卡牌ID':id,'名称':c['name'],'类别':c['kind'],'颜色':c['colors'],'费用':costs[id],'图片':'res://recourse/demo素材/'+c['file'],'完整说明':c['description'],'来源':c['source'],'能力文字':'\n\n'.join(x for x in c['description'].split('\n\n') if x.startswith(('主动能力：','自机能力：','能力：'))),'构筑资格':{'允许常规构筑':True},'能力绑定':[]}
 if id in ['68','70']:
  data.update({'角色名':'雾雨魔理沙' if id=='68' else '博丽灵梦','称号':'普通的魔法使' if id=='68' else '乐园的可爱巫女','种族':['人类'],'攻击力':3,'血量':3 if id=='68' else 4,'灵力':2})
  data['能力绑定']=[{'实现':x} for x in (['marisa_enter','marisa_spell'] if id=='68' else ['brave','exterminate'])]
 elif id=='99':data.update({'高速':False,'角色约束':'雾雨魔理沙','能力绑定':[{'实现':'damage','参数':{'数值':5}}]})
 elif id=='100':data.update({'高速':True,'角色约束':'博丽灵梦','能力绑定':[{'实现':'counter_card'}]})
 elif id in ['164','165','167']:data.update({'能力绑定':[{'实现':'mana','参数':{'颜色':c['colors'][0]}}]})
 else:data['能力绑定']=[{'实现':'grant_leader_abilities'}]
 (r/'cards'/(id+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
s=s[:s.index('# Card text')]+'''const Database = preload("res://scripts/card_database.gd")
static var CARDS: Dictionary = Database.load_cards()
'''+s[b:]
s=s.replace(' if strict and d.main.size() != 50:', ' if strict and d.main.size() != 50:')
s=s.replace(' return ""\nstatic func add_card', ''' if strict:
  var names={}
  for id in d.main:
   var name=CARDS[id].name
   names[name]=names.get(name,0)+1
   if names[name]>4: return "同名牌最多 4 张："+name
  for id in d.main+d.side:
   if CARDS[id].name==CARDS[d.leader].name: return "主副卡组不能包含所选自机的同名牌。"
 return ""
static func add_card''',1)
(r/'scripts/deck_store.gd').write_text(s,encoding='utf-8')
