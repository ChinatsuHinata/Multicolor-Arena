from pathlib import Path
import json,re,hashlib,importlib.util
R=Path(__file__).resolve().parents[1];O=R/'work/v012';B=R/'work/v012-backup'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
plan=read(O/'import-plan.json');new=read(O/'new-ids.json');cards=[read(p) for p in (R/'cards').glob('*.json')]
assert len(plan)==87 and len(new)==18 and len(cards)==269
for i in plan:
 assert sha(R/i['destination'])==i['sha256'],i['file']
assert not list((R/'recourse/新增卡片').glob('*.jpg'))
assert sha(R/'saves/decks.json')==sha(B/'saves/decks.json')
assert sha(R/'data/test_precons.json')==sha(B/'data/test_precons.json')
checked=set()
for i in plan:
 cid=i['id']
 if cid in checked:continue
 checked.add(cid);d=read(R/'cards'/f'{cid}.json');v=i['source']['values'];s=i['source']['sheet']
 if s.startswith('CHARACTER'):
  ordinary=str(v[17] or '').strip();leader=str(v[18] or '').strip();expected=ordinary+('\n自机能力：'+leader if leader else '')
 elif s.startswith('TOKEN'):expected=v[10]
 else:expected=str(v[16] if s.startswith('SPELL') else v[12] or '').strip()
 assert d['能力文字']==expected,(cid,d['能力文字'],expected)
tests=['test_v012_rules','test_v012_ui-visual','test_v011_rules','test_v011_edges','test_v011_ucs','test_v010_rules','test_v098_rules','test_v096_rules','test_v095_rules','test_v09_rules','test_duel_rules','test_v097_database','test_v010_ui','test_v011_ui']
results=[]
for name in tests:
 text=(O/(name+'.log')).read_text(encoding='utf-8')
 errors=[l for l in text.splitlines() if ('ERROR:' in l or 'SCRIPT ERROR' in l) and 'root certificate' not in l]
 assert not errors,(name,errors)
 matches=re.findall(r'(\d+) checks; (\d+) failures',text);assert matches,name
 n,f=map(int,matches[-1]);assert f==0
 results.append({'test':name,'checks':n,'failures':f})
for name in ['test_v010_matches','test_v011_matches','test_v012_matches']:
 text=(O/(name+'.log')).read_text(encoding='utf-8')
 assert '0 unfinished' in text and 'SCRIPT ERROR' not in text
results_summary={'checks':sum(x['checks'] for x in results),'failures':0,'completed_matches':24,'tests':results,'images':len(plan),'new_definitions':len(new),'database_count':len(cards),'excel_text_verified_ids':len(checked),'saved_decks_unchanged':True,'precon_templates_unchanged':True,'images_sha256_unchanged':True,'halfghost_sha256':sha(R/'recourse/数据库/token-ucs-099.jpg')}
write(O/'validation.json',results_summary)
count=results_summary['checks']
report=f'''# 新增卡片与 Excel 核对 v0.12

日期：2026-09-19。按本轮要求处理新增目录全部 87 张图片，卡面与 Excel 不同时以 Excel 为准，并替换半灵卡图。继续落实此前已授权的全部新效果实现。

## 入库结果

- 18 条新定义：15 条可构筑牌、3 条面具衍生物。总库 269 条：257 条可构筑、12 条衍生物。
- 全部 87 张图先归档后编写资料；18 张作为新定义主图，1 张替换半灵，68 张同名重印/异画保留在 `recourse/数据库/异画与重复/v0.12/`。原图内容与导入前 SHA256 相同。
- 半灵稳定 ID 为 `token-ucs-099`；妖梦实际生成的 `token_halfghost` 也使用这张新图。原图备份在 `work/v012-backup/old-halfghost.jpg`。
- 78 个涉及 ID 的能力文字已与来源行逐字核对。每条新定义记录文件、工作表、行号、编号。两部工作簿均重新读取，本轮图片无未匹配项。
- 原六副存档与两套预组模板逐字节不变；面具和半灵不能加入常规卡组。待处理区当前仅留 `.gdignore`。

## Excel 与印刷内容

费用、颜色、数值、角色约束、符卡类别和正文均按对应 Excel 编号读取，原图不重画。幻想「第一种永久机关」本轮 FDN-058 行为蓝 6 黄 6，已同步到沿用的稳定 ID。无能力卡预览删除原来的费用/编号说明。

Excel 的衍生物页未提供颜色列，因此小面/般若面/姥面的颜色依本次卡图明确括注分别为黄/黑/蓝。小面行的“目标但闻”保留在原文，执行对象按卡图明确的“目标单位”处理；这是原表错字的执行释义，未改写原表。

## 新卡与来源

| ID | 名称 | Excel 来源 | 实现 |
|---|---|---|---|
'''
for cid in new:
 d=read(R/'cards'/f'{cid}.json');src=d['Excel来源'];effects='、'.join(a['参数']['效果'] for a in d['能力绑定'])
 report+=f"| `{cid}` | {d['名称']} | {src['工作表']} 第{src['行']}行 · {src['编号']} | {effects} |\n"
report+='''
## 对战接入

- 秦心：准备开始的选发触发；普通情况下对手选择未选过的心情，自机能力生效时改为自己选。三种心情选完后不再出现无解选择。生成实际面具图及可牺牲的道具异能。
- 勇者琪露诺：横置伤害、勇气指示物、自机移除两个指示物并投 D6；投骰值在提交时固定，结算不重投。冰柱海潮读取己方单位勇气总量。卡边与预览可见勇气数量。
- 早苗：给自己的单位放置每种指示物时数量加一；不会强化对手放置在己方单位上的指示物。奇迹使用触发可以不选单位，仍抓牌。
- 仲夏妖精、莉莉黑、蜜桃：牺牲与等量指示物、永久颜色指示物、逐类翻倍/回复抓牌/颜色盘三模式。
- 妖精巡礼：修改堆叠对象的结算描述，保留原符卡身份、费用和使用者；原目标移除，改为该使用者生成不占格的蓝绿 3/3/3 妖精。改写后的说明显示在堆叠下方。
- 青之花：将仍在堆叠的符卡移到其拥有者牌库第三张；牌库不足两张时放到底部。
- 常夜樱：计时 2、结束阶段回收墓地单位，计时归零按状态检查离场。
- 喜怒哀乐附体：每个道具提供一个可选模式分组，允许多次选择同一模式/目标；反制要求由原牌使用者选择付款，付款结束继续本次结算剩余模式。分组先选效果，再在战场或相应区域选目标。
- 朱鹭子：复制己方道具，保留图像与能力，下一结束阶段牺牲；自己的回合第一张道具减任意两点颜色值。绵月丰姬限制双方非自己回合启动单位能力，道具异能不受限；驹草山如防止非战斗伤害。

## 维护入口与验证

新效果在 `scripts/rules/mask_abilities.gd`，由 `excel_abilities.gd` 调度，仍使用 `roster` 中文 JSON 绑定。指示物经替代接口添加；临时效果、堆叠改写、区域版本与结算续程通过现有引擎校验。数据库索引由 `tools/check_card_database.py` 校验。

'''
report+=f'最终 {count} 项规则/界面/资源检查零失败，另 24 场自动对局全部结束（原预组、v0.11 混合牌、v0.12 新牌各 8 场）。对局结束验证不代表人机强度或平衡性已经完成。真实图形测试已查看新半灵、勇气指示物、分项确认和面具生成截图。证据见 `work/v012/validation.json` 与对应日志。日志无项目脚本/纹理错误，仅既有 Windows 根证书诊断。\n'
(R/'docs/新增卡片与Excel核对-v0.12.md').write_text(report,encoding='utf-8')
def append(file,marker,content):
 p=R/file;s=p.read_text(encoding='utf-8');assert marker not in s
 p.write_text(s+'\n\n'+marker+'\n\n'+content+'\n',encoding='utf-8')
append('开发者日志.md','## 2026-09-19 · v0.12 LOF/HTK 入库与半灵换图',f'''- 本轮新增目录 87 张图片全部先归档再入库，新增 18 条定义，总库 269 条（257 可构筑、12 衍生物）。68 张同名重印/异画保留在 v0.12 归档。全部原图 SHA256 一致；备份 work/v012-backup。
- 按重新读取的 Excel 核对 78 个涉及 ID 的原文、费用与数值，修正第一种永久机关为蓝黄费用。衍生物页缺失的面具颜色按卡图括注补齐，小面原表错字保持原文并按目标单位执行。半灵主图替换，实际生成物与数据库预览共用新图。
- 新增 mask_abilities.gd，实现秦心心情/面具、勇气与D6、早苗指示物替代、牺牲妖精、颜色指示物、蜜桃模式、堆叠描述改写、置于牌库第三张、时符回收、多次模式及连续税费选择、道具复制与首张减费、丰姬限制和非战斗伤害防止。分组选择支持先选模式；勇气数量和已选心情可查看，堆叠显示改写描述。
- 专项测试捕获面具目标缺少临时属性初始化，修复后全部重跑。对原预组、先制/妖梦、混色、复杂旧卡和界面做回归；{count} 项检查零失败，24 场对局全部结束。真实图形交互 23 项通过并查看截图，完整证据 work/v012/validation.json。
- 6 副原存档和两套预组模板逐字节未变。更新开发计划、编写说明、使用说明、卡图索引及详细入库清单。全部写入和素材移动均在 test 目录内。''')
append('docs/卡牌数据库与编写说明.md','## v0.12：面具、指示物与多模式', '''`roster` 新效果由 `rules/mask_abilities.gd` 实现，注册仍在数据库 ROSTER_EFFECTS。普通效果和自机效果各自绑定，使用 `enabled` 检查自机资格。衍生物 JSON 写 `衍生物: true` 与禁止常规构筑，运行时直接按相同 ID 创建以复用卡图。

添加三项属性指示物使用 `Roster.plus(e, card, amount, placer)`；其他数字指示物使用 `Roster.Batch.counter`；颜色指示物使用 `color_counter`，必须传入放置者，确保早苗替代仅影响自己放置于自己单位的指示物。指示物数量与原始属性分开保存，换区清理。

多模式采用 selection 分组，pool 引用可含 mode；每组先选模式再选目标，不展开组合。响应税费属于原结算的 continuation，付款后接续余下项；不能把后续项作为新的可响应触发。投 D6 在费用提交后只产生一次结果并存于堆叠项。''')
append('docs/游戏整体开发计划.md','## 35. v0.12：面具与指示物扩展', '''87 张新素材已归档，库现有 269 条定义；详细范围见《新增卡片与Excel核对-v0.12.md》。新增状态为心情选择者替换、单位指示物放置替代、掷骰结果固定、堆叠文字改写、多模式结算中的税费暂停与恢复。界面继续使用右侧确认、场上目标和区域选牌，新增勇气数量显示。

下一步优先完善人机对多模式、面具与费用保留的策略，以及更多实际玩家回归。现有混合牌对局验证是运行完整性检查；联网、确定性回放、神子数字分配界面及平衡性仍按此前计划继续。''')
append('recourse/数据库/README.md','## v0.12登记', '''本批87张图片已归档，新增18条定义，现269条（257可构筑、12衍生物）。半灵 `token-ucs-099.jpg` 已替换为用户提供的新图；妖梦生成的半灵共用该图。异画/重复图片位于 `异画与重复/v0.12/`。完整来源与移动哈希见 `work/v012/import-plan.json`；效果和测试见 `docs/新增卡片与Excel核对-v0.12.md`。''')
append('使用说明.md','## v0.12 新卡与半灵', '''新增目录87张卡图已处理，新增15张可构筑牌与3张面具衍生物，卡库共269条。资料及实际效果按Excel，图上旧文字不覆盖Excel。半灵已换为这次提供的卡图；重新运行游戏即可加载。

秦心触发后选心情，面具点击发动并牺牲；勇者琪露诺的勇气数量显示在场上和预览中。喜怒哀乐附体按道具数量逐项选择效果与目标，完成后统一确认；反制税费由被询问玩家选择支付。两套预组和其他已存卡组未改变。''')
print(json.dumps(results_summary,ensure_ascii=False,indent=2))
