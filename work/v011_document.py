from pathlib import Path
import json,re,hashlib
R=Path(__file__).resolve().parents[1];O=R/'work/v011'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
report=read(O/'audit.json');new=read(O/'new-ids.json')+read(O/'supplement/new-ids.json')
plans=read(O/'import-plan.json')+read(O/'supplement/import-plan.json')
tests=['test_v011_rules','test_v011_edges','test_v011_ucs','test_duel_rules','test_v09_rules','test_v095_rules','test_v096_rules','test_v098_rules','test_v010_rules','test_v010_ui','test_v011_ui','test_v097_database']
rows=[];total=0
for test in tests:
 s=(O/(test+'.log')).read_text(encoding='utf-8-sig')
 errors=[line for line in s.splitlines() if ('SCRIPT ERROR' in line or 'ERROR:' in line) and 'root certificate' not in line]
 assert not errors,(test,errors)
 count,fail=re.findall(r'(\d+) checks; (\d+) failures',s)[-1];assert int(fail)==0
 total+=int(count);rows.append({'测试':test,'检查':int(count),'失败':0})
for test in ['test_v010_matches','test_v011_matches']:
 s=(O/(test+'.log')).read_text(encoding='utf-8-sig');assert '0 unfinished' in s and 'SCRIPT ERROR' not in s
visual=(O/'test_v011_ui-visual.log').read_text(encoding='utf-8-sig');assert '22 checks; 0 failures' in visual and 'SCRIPT ERROR' not in visual
validation={**report,'检查总数':total,'规则与交互测试':rows,'完整对局':16,'图形界面检查':22,'已查看截图':['discard-selection.png','satori-hand-choice.png','copied-unit.png']}
(O/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
text='''# 新增卡片入库与 Excel 核对 v0.11

日期：2026-09-19。用户授权导入新增卡片，并明确卡面文字有出入时以 Excel 为准；本轮继续包含卡牌效果的对战实现。

## 入库结果

- 两批共170张图片已从 `recourse/新增卡片` 移入 `recourse/数据库`。逐张SHA256核对，原始图片内容不变。
- 新增119条定义。当前251条定义：242张可构筑卡、9张衍生物。衍生物可由效果生成，不在普通组卡库中，不加入预组。
- 同名、同规则重印沿用稳定ID；异画和重复图保留在 `recourse/数据库/异画与重复/v0.11`。同名但有不同自机能力的SMM07早苗单独保留，原REI版本不覆盖。
- 待处理区的当前图片已全部处理，仅保留`.gdignore`。之后放入的图片不会自动导入。
- 六副原卡组及 `data/test_precons.json` 均逐字节未变，包含「预组-灵梦」和「预组-魔理沙」。不自动把新牌塞入原预组。

## 资料权威与差异处理

规则、颜色、费用、属性、完整牌名和自机能力采用本地《极彩全牌表 - （圣版可检索）25-12-17.xlsx》。新版牌表用于图片与牌名定位；本地爬虫缓存只用于图名与卡目编号匹配，没有联网查询。每份本轮处理的JSON含 `Excel来源`，记录文件、工作表、行、编号。共有153个不同ID完成原文逐字核对；未在本轮范围的旧定义保持原规则。

小町KMO-001行只写「吸血」，同一完整牌名的REC-013行明确写「吸血2」；本轮采用后者的明确数值，并将REC-013记入来源。相关说明已询问用户，尚无新回复，当前实现按这一明确Excel记录执行。

图片中的印刷文字不重画；游戏内预览、费用与结算使用Excel定义。例：本批爱丽丝普通能力为红色检索人偶，自机能力为黄色牺牲并回收；即使旧图上的能力顺序不同，仍按Excel。小径灵梦的「任意时机使用」同时保留为高速标记。2X费用记录倍率2，X=3时该颜色实际支付6点。

## 对战接入

新效果集中在 `scripts/rules/excel_abilities.gd`，通过JSON的 `roster` 实现绑定。包括多目标、分配伤害、费用追加弃牌、X及2X、减费、免费使用、墓地/除外使用、检索和排序、弃牌检查、临时控制、复制与生成物、正负指示物、触发/启动异能、时符与乐章、额外回合及立即结束回合。

法兰西人偶、动态增益和减益使用持续属性计算。状态检查先同时确定死亡对象，再处理死亡与后续持续效果变化；先制后的普通伤害保留独立窗口。百百世以-1/-1指示物替代单位伤害标记，双方伤害计算使用伤判开始时的攻击力，避免先执行的一方错误降低同时反击。

河童背包在对手能力完成目标声明后触发，对方选择支付任意颜色1点或不支付；付款成功才横置来源，不支付则反制原能力。神子选择X后，在必发入场能力中按每一点选择对象，同一个单位可以分得多点，结算时合计后一次造成相应伤害。此操作目前复用右侧分组选牌，尚非独立数字滑杆界面。

冈格尼尔只限制对手响应，仍会产生自己的使用符卡触发。心之箱每个自己的回合使用一次，时符进场后也保留之后入墓改除外的记录。额外弃牌是确认声明时才提交的费用，右键取消不会弃牌或横置颜色来源。

区域选牌采用卡面窗口，支持当前效果授权查看的对手手牌；复制品沿用原卡图，独立保存复制的规则和身份。没有专属图的小鬼、青蛙、御柱等运行时生成物使用可替换的统一SVG占位图，数值、颜色和关键词为实际效果数据。已有本批半灵原图已接入。

## 验证与维护

'''
text+=f'最终 {total} 项数据库、规则与界面检查通过，16场完整自动对局正常结束（8场原预组、8场含两批新牌的混合卡组）。其中22项新界面检查另在真实图形模式下运行并查看截图。测试验证功能与流程，不代表人机强度或卡组平衡性结论。\n\n'
text+='| 测试 | 检查数 |\n|---|---:|\n'+''.join(f'| `{x["测试"]}` | {x["检查"]} |\n' for x in rows)
text+='''
日志位于 `work/v011/`，最终汇总为 `validation.json`，素材和来源审计为 `audit.json`。初始备份在 `work/v011-backup`；补充批图片与中间定义另保存在其中的 `supplement-input` 和 `supplement-definitions`。

`tools/import_excel_v011.py` 是本次审核批次的导入工具，不是任意图片自动识别器。后续新卡仍需要先匹配Excel、分配稳定ID、移动卡图、编写显式效果，再登记和测试。检查已有数据库使用 `tools/check_card_database.py`；只有核对通过后才加 `--write-index` 重建索引。

## 本次新增定义

| ID | 完整牌名 | Excel位置 | 能力实现 |
|---|---|---|---|
'''
for cid in new:
 d=read(R/'cards'/f'{cid}.json');src=d['Excel来源'];effects='、'.join(a.get('参数',{}).get('效果',a['实现']) for a in d['能力绑定']) or ('衍生物/关键词' if d.get('衍生物') else '关键词/基础属性')
 text+=f'| `{cid}` | {d["名称"]} | {src["编号"]} · {src["工作表"]} 行{src["行"]} | {effects} |\n'
(R/'docs/新增卡片与Excel核对-v0.11.md').write_text(text,encoding='utf-8')
def append(path,marker,body):
 p=R/path;s=p.read_text(encoding='utf-8-sig');assert marker not in s,path;p.write_text(s+'\n\n'+marker+'\n\n'+body+'\n',encoding='utf-8')
append('开发者日志.md','## 2026-09-19 · v0.11 全部新增卡入库，以Excel为准',f'''- 按用户本轮指令处理初始119张图及工作期间补入的51张UCS图，全部先移动至数据库后编写定义。新增119个ID，现251条定义（242可构筑、9衍生物），重印沿用已有ID，异画与重复原图保留。170张原图移动前后SHA256一致，当前待处理区无剩余卡图。
- 使用本地Excel核对规则资料，153个涉及ID的预览原文逐字核对；JSON标明工作表、行与编号。小町按同名REC-013明确的吸血2处理，SMM07早苗保留单独版本及其自机能力。卡图不重画，运行时费用与规则依Excel；半灵原画接入，其他没有专图的运行时生成物采用统一可替换SVG。
- 新增excel_abilities.gd及roster注册，实现两批新牌效果。扩展多异能选择、授权对手手牌检查、2X支付、额外弃牌、复制、动态光环、减益伤害、临时控制、墓地使用、额外回合、立即结束回合、掷硬币与河童背包付费反制。神子分配按每一点选择对象并合计伤害。
- 持续效果死亡判定按同时批次处理，伤判前缓存反击攻击力；心之箱时符进场保留入墓改除外权限。派生触发显示来源中文能力。小径灵梦重印导入时误重置高速标志，回归捕获后修复；键山雏改目标时堆叠引用误判单位的异常也已修复。早期测试夹具费用或存放区域不匹配已经修正并重跑，不将有脚本错误的通过输出计作最终验证。
- 最终{total}项检查零失败，日志逐项扫描无脚本/资源/着色器错误；仅既有Windows根证书诊断。8场原预组及8场含两批新牌的完整对局均结束。新界面22项另以真实图形运行，已查看弃牌、对手手牌选择及复制单位截图。结果见work/v011/validation.json。
- 六副保存卡组与两套预组模板逐字节未变。所有项目写入、素材移动、备份、测试日志和截图均在test内。备份work/v011-backup，更新卡图索引、使用说明、整体计划和编写说明；详细卡单见docs/新增卡片与Excel核对-v0.11.md。''')
append('docs/游戏整体开发计划.md','## 34. v0.11：Excel权威卡库与复杂效果', '''两批170张图片已归档，新卡池251条定义。数据来源与完整新增表见《新增卡片与Excel核对-v0.11.md》。原预组与玩家存档保持不变；新卡可直接在组卡器检索并用于对战。

引擎继续使用GDScript显式效果与中文JSON资料。当前状态扩展：声明时私有选择额外弃牌和X；提交后触发针对能力的额外付款；结算中授权检查手牌、分配多点伤害、排序牌库顶；回合清理时归还临时控制权，并处理额外回合队列。复制品拥有独立定义与实例，自机资格依旧由自机区身份、神社或自机指示物决定。

维护优先项：继续按来源行添加卡牌与专项用例；完善神子伤害分配的数字界面与生成物专用图；提高人机对模式和响应的策略；联网、回放与确定性状态同步仍属后续开发，当前自动对局仅验证能完整结束。''')
append('docs/卡牌数据库与编写说明.md','## v0.11：Excel原文、倍率与新效果模块','''卡图文本与Excel不一致时，以Excel为准。新增 `Excel来源` 保存文件、工作表、行、编号；已入库原图不修改，不把识别文字当执行代码。

绑定示例：`{"实现":"roster","名称":"该牌对每个单位造成3点伤害。","参数":{"效果":"sweep_three"}}`。对应允许键在 `card_database.gd/ROSTER_EFFECTS`，实现入口在 `rules/excel_abilities.gd`。必须同时具备实现、合法目标和专项测试，不能只增加注册键。

`可变费用`记录X的颜色，`X费用倍率`为正整数（默认1，2X填写2）。支付与堆叠费用值都乘倍率，效应中的X仍是玩家选择值。免费替代使用时X为0。

生命周期区分提交费用、触发入堆叠、结算中的连续选择、状态检查和清理；费用选择仍在提交前私有。每个启动异能传入自己的效果键，不能总执行卡牌的第一个启动能力。检索/弃牌/排列用现有分组描述；分配伤害允许不同分组重复同一个对象，结算时汇总后一次造成伤害。

增加指示物调用 `Roster.plus`，掷硬币调用 `engine.flip_coin`，付款通过既有payment接口，伤害通过damage_target。动态属性由stat_adjust计算，禁止把临时光环直接永久写入基本属性。复制实例的定义在当前引擎内，不能污染组卡用的全局卡库。''')
append('使用说明.md','## v0.11 新卡与Excel规则','''新增卡片目录的两批170张图已入库，卡池共251条定义（242可构筑、9衍生物）。重新运行项目即可在组卡界面使用新卡；「预组-灵梦」「预组-魔理沙」及其他已保存卡组保持不变。

预览文字、费用和效果按Excel；原卡图保留，印刷内容有差异时以左侧文字及实际规则为准。额外弃牌使用卡面窗口，确认前右键可取消；多种启动异能分别选卡面；神子的X点伤害按右侧提示逐点分配，同一单位可分配多点。河童背包触发时选择支付一种颜色1点或不支付。

详细入库清单、来源差异和测试结果见 `docs/新增卡片与Excel核对-v0.11.md`。''')
append('recourse/数据库/README.md','## v0.11登记','''当前251条定义，242条可构筑、9条衍生物。本轮170张原图全部归档，新增119条定义；异画与重复图保留在 `异画与重复/v0.11/`。全部图像SHA256核对通过，来源与定义清单见 `docs/新增卡片与Excel核对-v0.11.md`；原文以Excel为准。

本轮清单为 `work/v011/import-plan.json` 与 `work/v011/supplement/import-plan.json`。当前待处理目录已清空卡图；今后新放入的图片仍需收到导入指令后处理。''')
print('Documented',total,'checks, 16 matches,',report['新增定义'],'new definitions.')
