from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
rows=json.loads((root/'work/v09-all-source-rows.json').read_text('utf-8'))
entries=[('91','CHARACTER',96,'image91.png',['end_grave_return','grave_return_replace'],['威吓']),('133','SPELL',43,'image133.png',['pair_fight'],[]),('rec_unit_097','CHARACTER',247,'蓬莱的人之形「藤原妹红」__character-rec-097.jpg',['grave_return'],[]),('soi_unit_086','CHARACTER',87,'未确认幻想飞行物「封兽ぬえ」__character-soi-086.jpg',['leader_enter_modes'],['威吓','疾行'])]
manifest=[]
for id,sheet,row,image,effects,keywords in entries:
 source=next(r for r in rows if r['sheet'].startswith(sheet) and r['row']==row);v=source['values']; unit=sheet=='CHARACTER'
 offset=8 if unit else 6; colors=['红','蓝','绿','黄','黑']; cost={c:int(v[offset+i]) for i,c in enumerate(colors) if v[offset+i] is not None and int(v[offset+i])>0}
 text=((v[17] or '')+('\n自机能力：'+v[18].strip() if v[18] else '')) if unit else v[16]
 name=v[5]+'「'+v[6]+'」' if unit else v[5]
 d={'格式版本':1,'卡牌ID':id,'名称':name,'类别':'自机' if id in ['91','soi_unit_086'] else '单位' if unit else '符卡','颜色':list(cost),'费用':cost,'图片':'res://recourse/新增卡片/'+image,'完整说明':text,'能力文字':text,'来源':source['sheet']+'!行'+str(row)+' · '+v[2],'构筑资格':{'允许常规构筑':True},'关键词':keywords,'能力绑定':[{'实现':'extension','参数':{'效果':e}} for e in effects]}
 if unit:d.update({'角色名':v[6],'称号':v[5],'种族':[v[7]],'攻击力':int(v[14]),'血量':int(v[15]),'灵力':int(v[16])})
 else:d.update({'高速':False,'符卡类型':'非符','角色约束':''})
 (root/'cards'/f'{id}.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n','utf-8');manifest.append({'id':id,'name':name,'source':d['来源'],'image':image})
(root/'work/v095-import-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n','utf-8')
p=root/'scripts/card_database.gd';s=p.read_text('utf-8');s=s.replace('"169","174"]','"169","174","91","133","rec_unit_097","soi_unit_086"]',1).replace('const EXTENSION_EFFECTS=[','const EXTENSION_EFFECTS=["end_grave_return","grave_return_replace","pair_fight","leader_enter_modes",',1);p.write_text(s,'utf-8')
print(json.dumps(manifest,ensure_ascii=False))
