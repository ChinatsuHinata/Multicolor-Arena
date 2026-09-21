from pathlib import Path
import json,re,hashlib

R=Path(__file__).resolve().parents[1]
O=R/'work/v013'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
write=lambda p,s:p.write_text(s,encoding='utf-8')
data=read(O/'final-data-audit.json')
assert not data['errors']
results=[];matches=[]
for p in sorted(O.glob('*.log')):
    if p.name.startswith('import'):continue
    s=p.read_text(encoding='utf-8')
    errors=[l for l in s.splitlines() if ('ERROR:' in l or 'SCRIPT ERROR' in l) and 'root certificate' not in l]
    assert not errors,(p.name,errors)
    counts=re.findall(r'(\d+) checks; (0|\[\]) failures',s)
    if counts:
        results.append({'log':p.name,'checks':int(counts[-1][0]),'failures':0})
        if p.name.startswith('contracts-'):assert 'SKIP:' not in s
    elif '_matches' in p.name:
        found=re.search(r'MATCHES: (\d+).*?; 0 unfinished',s);assert found,p.name
        matches.append({'log':p.name,'completed':int(found[1]),'unfinished':0})
    else:assert p.name=='test_v013_load.log' and 'DATABASE 486' in s and 'ENGINE OK 494' in s
checks=sum(t['checks'] for t in results)
assert len(results)==25 and sum(t['completed'] for t in matches)==36,(len(results),matches)
validation={'version':'v0.13','date':'2026-09-19','data':data,'checks':checks,'failures':0,'tests':results,'matches':matches,'complete_matches':36,'new_spells_exercised':127,'new_nonspells_exercised':90,'new_activation_keys_exercised':25,'visual_screenshots_reviewed':['declare-name.png','library-top.png','floating-mana.png'],'project_errors':[],'environment_diagnostics':['Windows root certificate store read warning'],'scope':'All 217 newly registered definitions have explicit effect bindings. Tests cover all spell dispatches and nonspell lifecycles plus targeted rule/UI regressions; they do not enumerate all possible card combinations or establish AI balance.'}
write(O/'validation.json',json.dumps(validation,ensure_ascii=False,indent=2)+'\n')
new=read(O/'new-ids.json');cards={cid:read(R/'cards'/f'{cid}.json') for cid in new}
plan=read(O/'import-plan.json');previous={p.stem:read(p) for p in (R/'work/v013-backup/cards').glob('*.json')}
changed=[]
for cid in sorted(set(i['id'] for i in plan)&set(previous)):
    current=read(R/'cards'/f'{cid}.json')
    fields=[k for k in ['名称','类别','颜色','费用','能力文字','角色约束','符卡类型','高速','攻击力','血量','灵力','种族'] if current.get(k)!=previous[cid].get(k)]
    if fields:changed.append((cid,current['名称'],'、'.join(fields)))
intro=f'''# 新增卡片与 Excel 核对 · v0.13

2026-09-19。本批按用户要求同时导入资料和实现全部新效果。用户明确补充：水难事故的化身「村纱水蜜」的 +X 增加灵力。

## 导入范围

- 395 张原始 JPG 先归档，再写入 JSON 与规则。新增 217 条定义：单位/自机 74、符卡 127、道具 8、场景 4、衍生物 4。
- 总库 486 条：468 条可构筑、16 条衍生物、2 条梦违单位。梦违属于独立的禁入常规构筑单位，不按衍生物处理。
- 217 张主图使用稳定 ID 命名；178 张已有卡重印或异画保留于 `recourse/数据库/异画与重复/v0.13/`。所有 395 张图的 SHA256 与移动前一致，没有改绘原图或去除原有水印。
- 本批涉及的 391 个不同 ID 已重新与实际 Excel 核对原文、费用、颜色、角色约束和单位数值。来源记录保留文件、工作表、行号和编号。原图印刷文字不覆盖 Excel。
- 六副保存卡组、两套预组模板和 v0.12 替换后的半灵图逐字节未变。待处理目录当前没有剩余 JPG；目录中的下载脚本没有运行，今后新图仍需单独导入。

权威资料为 `recourse/极彩全牌表 - （圣版可检索）25-12-17.xlsx`，补充资料为 `recourse/极彩新牌表.xlsx`；规则查阅使用项目内的完整规则及关键词图。原始快照位于 `work/v013-backup/`，逐图移动清单为 `work/v013/import-plan.json`。

## 本轮规则与交互

| 类别 | 已接入的行为 |
| --- | --- |
| 使用与费用 | X、替代费用、不同名/指定类别额外费用、弃牌、牺牲、除外、移除指示物、不同名人偶洗回、角色约束、目标鬼的额外费用、攻击税费 |
| 区域权限 | 墓地/除外/颜色盘/牌库顶使用，顶牌展示后额外使用，费用提交前可取消，不支付颜色值仍检查适用的角色约束 |
| 结算选择 | 检索、回收、宣告卡名搜索、连续分组选牌、单位与玩家目标、弃牌和排序、结算中的付款与恢复 |
| 触发 | 进离场、死亡、使用、攻击、阻挡、伤害、磨牌、横置、牺牲、阶段与延迟触发；同批事件聚合、禁止触发和额外触发 |
| 复制与改目标 | 单位复制、符卡复制、X 改写、保留原模式和已付额外费用、重新选择目标，单位复制不复制不可复制的指示物 |
| 持续能力 | 动态攻血灵、种族与角色匹配、获得自机能力、妖精继承能力、战场格与构筑限制、名字/类别封锁、费用和伤害修正 |
| 战斗与生成物 | 强制战斗、指定单位攻击、强制阻挡、吸血、防避、狂乱指示物和必须攻击、梦违取得与回收、四种新增衍生物 |

界面继续在右侧选择与确认。宣告卡名可搜索完整名称；合法局外梦违显示选牌项。获得颜色值后可在手动支付中选择对应颜色值。触发中的付款、展示牌的使用也沿用自动/手动支付与取消；取消只退回当前私有声明，不擅自跳过仍待完成的触发。允许查看牌库顶的效果只公开顶牌，其余牌仍按隐藏信息处理。

新增 `catalogue_abilities.gd`、`catalogue_spells.gd`、`catalogue_units.gd`、`catalogue_state.gd`，由 `excel_abilities.gd` 转发。文本不作为脚本执行；每个效果必须有显式注册和处理分支。引擎中的来源、区域版本与连续结算上下文贯穿额外选择，避免将后续伤害误认成其他来源。

## 明确处理的资料差异

- `character-fdf-100` 村纱水蜜：X 按对手墓地符卡数量计算，仅增加灵力；攻击力和血量不增加。这是用户本轮确认的解释。
- `character-fdf-115` 增加“不明物体”别名供涉及该牌名的效果识别，不更改印刷名称。
- `character-rei-026` 根据 Excel 补齐自机类别及其自机能力，沿用已有检索处理。
- `token-fdn-082` 新闻素材：基础资料按衍生物页加天狗灵力；文文的生成效果明确另加血量时，生成实例带该修正，不覆盖所有同名衍生物。
- 两张梦违 `character-ucs-020`、`character-ucs-021` 禁止正常构筑，由已实现的效果从局外取得，并以运行时指示物处理回收。
- 角色译名中的间隔号及部分异体译字在角色匹配时归一，展示原文保持 Excel 内容，避免“帕秋莉·诺蕾姬”等角色符卡因译名差异失去合法性。
- 用户此前指定的 `soi_unit_086` 红/蓝/绿合计三点加一黑费用保留；本批不同称号的 `character-fdf-117` 使用其 Excel 费用，二者没有混为一张。
- 防避继续使用已有的逐次消耗机制；完整规则中强制战斗按战斗处理，同称号进场限制和不可响应期间的触发禁止沿用对应规则，未以直接互相伤害替代。

## 验证

最终 {checks} 项检查零失败，另 36 场完整对局正常结束。127 张新符卡逐一经过合法选项、结算及续程检查；90 张非符卡经过进场、阶段、攻击/阻挡和离场路径；25 个新启动效果键逐一提交并结算。新规则专项 120 项、边界 138 项、真实图形输入 37 项通过，另覆盖旧卡、先制/妖梦、费用、区域、数据库纹理与旧界面回归。

最终日志无项目脚本、资源或着色器错误；环境仍报告既有 Windows 根证书读取诊断。测试发现并修复的实现问题包括：旧非符反制与 Excel 类别前缀不兼容、延续选择丢失伤害来源、重复磨牌触发批量计数、被复制效果的已付费用和模式保留、衍生物离场通知、通用启动伤害改目标遗漏玩家。帕秋莉使用角色符卡后的目标选择必须先完成再继续结算，UI 测试按实际优先权流程验证。

`work/v013/validation.json` 为最终汇总，`final-data-audit.json` 为图片和 Excel 审计。覆盖测试不代表穷尽 486 张牌的全部组合，也不代表人机决策或套牌平衡已经完成。

## 本批已有定义同步

下表只列字段实际变化的旧定义；来源定位和其他维护字段另见各 JSON。

| ID | 卡名 | 同步字段 |
| --- | --- | --- |
'''
for cid,name,fields in changed:intro+=f'| `{cid}` | {name} | {fields} |\n'
intro+='\n## 新增 217 条完整清单\n\n效果键中的 `:self` 表示需具备自机能力；允许常规构筑为“否”的卡不进入普通组卡库。各行链接直接指向可人工修改的 JSON。\n\n| ID | 完整卡名 | 类别 | 可构筑 | Excel 位置 | 效果键 |\n| --- | --- | --- | --- | --- | --- |\n'
for cid in sorted(new):
    c=cards[cid];src=c['Excel来源'];keys=[]
    for b in c.get('能力绑定',[]):keys.append(b.get('参数',{}).get('效果',b['实现']))
    intro+=f"| [{cid}](../cards/{cid}.json) | {c['名称']} | {c['类别']} | {'是' if c['构筑资格']['允许常规构筑'] else '否'} | {src['工作表']} · {src['行']} · {src['编号']} | {'；'.join(keys) or '无额外能力'} |\n"
write(R/'docs/新增卡片与Excel核对-v0.13.md',intro)

def update(path,replacements,section):
    p=R/path;s=p.read_text(encoding='utf-8-sig')
    for before,after in replacements:
        assert before in s,(path,before)
        s=s.replace(before,after,1)
    assert section.splitlines()[0] not in s,(path,'already appended')
    write(p,s.rstrip()+'\n\n'+section.strip()+'\n')

update('使用说明.md',[
('# 极彩 Multicolour · v0.10','# 极彩 Multicolour · v0.13'),
('组卡器已开放124种可构筑卡，另有8种衍生物仅供对局生成。','组卡器已开放468种可构筑卡；另有16种衍生物和2种禁止常规构筑的梦违单位，供相应效果在对局中生成或取得。'),
('`cards/*.json`：132种卡','`cards/*.json`：486种卡'),
('本轮初始57张图片已处理，后续新放入的图片仍须指定批次后导入。','v0.13本批395张图片已处理，后续新放入的图片仍须指定批次后导入。'),
('`scripts/rules/demo_abilities.gd`、`expanded_abilities.gd`、`precon_abilities.gd`：原有和新增卡池能力实现。','`scripts/rules/demo_abilities.gd`、`expanded_abilities.gd`、`precon_abilities.gd`、`excel_abilities.gd`、`mask_abilities.gd` 和 `catalogue_*.gd`：各批卡池的能力实现。'),
('当前可用范围是132种数据库卡牌的本地人机对局与本地调试；本批新增67份定义，并实现新效果及两套合法预组。全牌表、梦违运行时加入、通用复制/替代框架、联网和独立导出仍属后续计划。','当前可用范围是486种数据库卡牌的本地人机对局与本地调试；本批新增217份定义及其效果，已支持对应梦违取得、复制和替代使用。尚未宣称完成Excel全牌表；联网、独立导出和进一步的人机策略仍属后续计划。'),
('普通模式双方牌库只显示卡背；调试模式可见卡面。','普通模式双方牌库通常只显示卡背；有明确允许查看自己牌库顶的效果时只公开该顶牌。调试模式可见卡面。'),
('墓地、除外区或牌库中存在当前可以使用的牌时','墓地、除外区、颜色盘或牌库中存在当前可以使用的牌时')
],'''## v0.13 新卡与使用方式

本批395张原图已归档，新增217种卡及全部对应效果。卡池共486种；资料以Excel为准，村纱水蜜的“+X”按用户确认增加灵力。重新运行项目即可加载；原有六副卡组和两套预组模板没有改动，半灵继续使用上轮替换的图片。

宣告牌名时在右侧搜索并选择完整名称后确认。效果允许使用墓地、除外、颜色盘或牌库顶的牌时，使用相应区域标签；局外梦违通过效果选牌，不能直接加入卡组。额外弃牌、牺牲等仍先选卡，确认付费才提交；免费使用不自动免除角色条件。

触发效果要求付款、或展示顶牌后允许付费使用时，也可选择自动/手动支付。取消支付回到待完成的选择，费用不会提前扣除。已有浮动颜色值可在付款界面选择使用。右键检查与观察战场保持可用。

完整卡单、来源和验证结果见 `docs/新增卡片与Excel核对-v0.13.md`。
''')
update('docs/卡牌数据库与编写说明.md',[
('版本：v0.10，2026-09-19。','版本：v0.13，2026-09-19。'),
('当前合计132种（124可构筑、8衍生物）','当前合计486种（468可构筑、16衍生物、2梦违单位）'),
('这些名字是实现绑定，不是自由中文程序；不能只写一个未实现的关键词就得到效果。当前登记的61张卡有明确能力实现，包括本批计时符卡；通用复制、梦违或开局增牌仍须扩展引擎。','这些名字是实现绑定，不是自由中文程序；不能只写一个未实现的关键词就得到效果。当前登记486条定义，本批已接入对应复制、梦违取得和计时效果；新增未登记的特殊机制仍需补充显式实现。'),
('当前没有导入梦违，也没有宣称已实现从局外取得牌或开局加入牌库。后续应加入单独的运行时卡池登记、开局事件、来源记录和选择范围；不要把梦违伪装成副卡或衍生物。','当前已导入两张禁止常规构筑的梦违单位，由指定效果从局外取得并记录梦违指示物；它们不是副卡或衍生物。尚未添加新卡要求之外的任意开局增牌规则；未来这类效果应接入独立开局事件与来源记录。')
],'''## v0.13：大量卡牌的显式实现与审计

新增217条定义，清单见《新增卡片与Excel核对-v0.13.md》。仍使用 `roster` 绑定；资料与能力名称写中文，效果键使用稳定ID，普通与自机效果分开：

```json
{"实现":"roster","名称":"这里填写Excel原文","参数":{"效果":"character-fdf-100"}}
```

模块职责：`catalogue_abilities.gd` 统一分派、选择/复制/生成物工具与额外费用；`catalogue_spells.gd` 负责符卡合法选项与结算；`catalogue_units.gd` 负责永久物事件、启动能力与连续选择；`catalogue_state.gd` 负责持续属性、权限、费用和伤害查询。`excel_abilities.gd` 将这些入口接入原引擎。登记键必须同时拥有真实处理逻辑。

- 先保存完整来源和稳定ID；同名重印沿用旧ID、图片单独归档。打印图与Excel不一致时修正JSON和实现，不把图片OCR作为执行规则。
- 额外费用分组标记 `cost`，支付提交前仅做预选；在提交时统一扣除。浮动颜色值与牌面资源经同一校验付款，取消不得提前横置或公开出牌。
- 结算中再使用牌由 `cat:grant` 保存授权和替代费用，仍正常选择目标、付款、入堆叠。`cat:trigger_pay` 处理触发中的付款；续程不能丢失原来源或伤害性质。
- 改目标保留原模式、X、已支付的牺牲/弃牌等选择，仅重新选合法目标；复制单位不携带原实例的不可复制指示物。新实例仍受进场、同称号和区域版本规则约束。
- 磨牌、牺牲、横置、伤害和换区使用统一事件入口。批量事件聚合后额外触发的每份都要保留完整数量；衍生物消失前先处理离场事件。
- 可变持续数值放到 `stat_adjust`；村纱水蜜的墓地符卡数量只修改 `spirit`。狂乱是一个命名指示物，不再额外放第二份普通属性指示物。
- 两个梦违ID填写禁止常规构筑但不填写衍生物；生成、授权和回收由对应效果控制，不能靠“不检查卡组”绕过禁入。

核验命令：`tools/check_card_database.py` 检查正式库；`work/v013_data_verify.py` 重新读取Excel并核对本批391个涉及ID、395张图及原存档；最终测试证据见 `work/v013/validation.json`。导入计划仅用于本批审计，不应重复运行已经完成的搬移脚本。
''')
update('docs/游戏整体开发计划.md',[],f'''## 36. v0.13：新卡全集接入与结算状态扩展

本批395张素材先归档，新增217种卡的资料与效果，总库486条。468种可构筑，16种衍生物和2种梦违由对局效果使用。用户确认村纱水蜜+X为灵力，已落到持续属性查询。原六副卡组与两套预组没有改动，卡表见《新增卡片与Excel核对-v0.13.md》。

| 状态/入口 | 责任与退出条件 |
| --- | --- |
| 私有使用声明 | 选择模式、X、额外费用、目标；右键取消恢复场面，付款前不公开 |
| 授权使用 | 记录可从哪个区域使用、替代费用与角色限制；确认后进入普通堆叠使用流程 |
| 连续结算付款 | 挂起原触发或展示效果，选择自动/手动支付；验证后回到原续程，取消返回选择 |
| 批量事件收集 | 区分伤害、死亡、牺牲、磨牌和离场；聚合批次、应用禁止或额外触发，再决定顺序和目标 |
| 复制/改目标 | 保留原模式与已付款选择，复制新实例；改目标只替换目标，随后重新验证合法性 |
| 持续规则查询 | 动态属性、名字封锁、区域权限、供色与角色、强制攻击/阻挡、计时与指示物 |
| 局外取得与梦违 | 从登记的禁入构筑卡中选取，生成独立实例并记录指示物；按效果回收，不污染存档卡组 |
| 结束/延迟事件 | 处理到期的控制权、颜色值、临时修正和延迟回场；状态检查后恢复正常执行权 |

本轮 {checks} 项检查通过，36场自动对局完成；127新符卡和90非符卡的入口均被执行，另有目标失效、费用取消、触发禁止与复制等专项边界和真实界面检查。该覆盖是后续修改的回归基线，不等同于全部组合穷举。

后续优先项：提高人机对额外费用、模式、保留颜色与响应目标的决策；继续依据实际对局补交互组合回归；改善多点伤害分配等复杂选择的操作效率。联网、确定性事件记录/重放、独立导出与平衡测试仍按计划推进，未在本批冒充完成。
''')
update('recourse/数据库/README.md',[],'''## v0.13登记

当前486条定义（468可构筑、16衍生物、2梦违单位）。本批395张JPG全部归档，新增217条定义，178张重印/异画存入 `异画与重复/v0.13/`；全部图像SHA256不变。来源记录和数据按Excel，规则效果已接入游戏。

本轮移动清单 `work/v013/import-plan.json`，数据审计 `work/v013/final-data-audit.json`，完整新卡表 `docs/新增卡片与Excel核对-v0.13.md`。半灵 `token-ucs-099.jpg` 保持v0.12用户提供的图片。本批完成时待处理目录无剩余JPG，之后新增图片仍不自动登记。
''')
update('开发者日志.md',[],f'''## 2026-09-19 · v0.13 395张图片归档与全部新效果

- 按用户确认同时导入与实现新效果。395张JPG先搬入数据库：217张新主图、178张重印或异画归档。新增217份定义，总库486条（468可构筑、16衍生物、2梦违）。全部图片移动前后SHA256一致；备份work/v013-backup，逐图清单work/v013/import-plan.json。
- 实际重新读取两份Excel，核对本批391个涉及ID的能力文字、费用、颜色、角色限制和单位数值。图文有差异时Excel优先。用户确认村纱水蜜“+X”增加灵力，已实现并做专项测试；同名重印不重复生成规则ID，译名匹配归一但展示原文不改写。
- 新增四个catalogue规则模块，实现127新符卡和90非符卡相关效果，接入额外费用、区域使用、牌库顶展示、梦违取得、宣告牌名、复制改目标、触发批次/禁止/追加、持续属性、指示物、强制战斗和延迟效果。补齐25个新启动效果键，维护原有角色/自机资格与隐藏信息规则。
- 界面增加宣告牌名搜索、局外卡选项、浮动颜色值付款、允许时查看牌库顶、颜色盘使用标签；触发付款和展示后使用支持普通自动/手动支付与私有取消。选择续程保持来源、伤害类型和已付费用，避免提前公开或重复扣除。
- 回归修复非符类别前缀、后续分配伤害来源、重复触发批量计数、复制/改目标保留模式和额外费用、衍生物离场通知及通用启动能力改目标的玩家对象。最后一次UI检查原先漏完成帕秋莉使用角色符卡的触发目标，按真实堆叠顺序补齐测试后正常通过。
- 最终{checks}项检查零失败，36场自动对局全部完成。127新符卡逐一检查合法选择、结算与续程；90新非符卡检查生命周期；新规则120项、边界138项、真实图形输入37项。覆盖全部486种卡的纹理与索引，并回归旧卡、先制/妖梦、费用、调试和旧交互。没有项目脚本、资源或着色器错误，仅既有Windows根证书读取诊断。完整证据work/v013/validation.json。
- 已查看宣告卡名、浮动费用与牌库顶查看截图。更新使用说明、整体计划第36节、数据库说明、素材README，新建docs/新增卡片与Excel核对-v0.13.md，含217条完整卡单及旧定义同步记录。全部写入与验证产物在test内。
- 六副原存档、两套预组模板及上轮半灵图逐字节未变。自动对局证明本批可运行至结束，不代表已穷举所有卡牌组合或完成人机/套牌平衡。
''')
print(json.dumps({'checks':checks,'matches':36,'new_cards':len(new),'changed_existing':len(changed),'docs_written':6},ensure_ascii=False))
