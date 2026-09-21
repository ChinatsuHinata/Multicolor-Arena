from pathlib import Path
from collections import Counter
import json

ROOT = Path(__file__).resolve().parents[1]
def read(relative):
    return json.loads((ROOT / relative).read_text(encoding='utf-8-sig'))
def write(relative, text):
    (ROOT / relative).write_text(text.rstrip() + '\n', encoding='utf-8')
def append(relative, text):
    path = ROOT / relative
    write(relative, path.read_text(encoding='utf-8-sig').rstrip() + '\n\n' + text)

plan = read('work/v010-import-plan.json')
cards = {p.stem: json.loads(p.read_text(encoding='utf-8-sig')) for p in (ROOT / 'cards').glob('*.json')}
decks = read('data/test_precons.json')['decks']
parts = ['# 新增卡片与测试预组 · v0.10\n\n2026-09-19。按用户确认，本批同时完成资料入库和对战效果。',
'''## 范围与归档

本轮开始时待处理目录中的57张卡图已全部移动至数据库：54张作为规则卡的主图，3张同名重复图保留在 `recourse/数据库/异画与重复/v0.10/`。另从项目已有爬虫缓存补齐11张预组缺图，以及效果需要的美宵之酒。蓬莱之药原图在本地缓存中缺失，使用可替换的药瓶SVG占位图，规则与生成效果已经实现。

本轮新增67份定义；总数据库132种，其中124种允许构筑、8种为不可构筑的衍生物。旧65个ID和原4副保存卡组保留。运行时另保留旧版UFO、半灵衍生物定义。

范围以 `work/v010-import-plan.json` 与 `work/v010-backup/新增卡片/` 为准。开发过程中后来加入待处理目录的文件不属于这份初始清单，不由导入脚本自动处理。

## 测试套牌

以下按照片顺序列出实际保存数量。每套主卡组50张、自机1张、副卡组0张，衍生物不加入。`data/test_precons.json` 是可恢复的模板，`saves/decks.json` 已保存两套预组。人机准备页默认选灵梦对魔理沙，可交换双方或选择其他牌组；“载入测试卡组”恢复内存中的两套模板，普通编辑仍须点击保存。
''']
for deck in decks:
    parts.append(f'### {deck["name"]}\n\n自机：{cards[deck["leader"]]["名称"]} ×1。\n\n| 主卡牌 | 数量 | ID |\n|---|---:|---|')
    for cid, count in Counter(deck['main']).items():
        parts.append(f'| {cards[cid]["名称"]} | {count} | `{cid}` |')
    parts.append('| **合计** | **50** | |\n')
parts.append('''## 本批效果与操作

- 多目标牌按点选顺序保留目标；扩散结界使用1、2、3……的伤害次序。允许“至多”时可提前完成或选择零张，非法及重复目标会被拒绝。
- 检索、墓地回收与复合区域选择沿用卡面窗口；魔理沙先选择三张不同名符卡作为除外费用，再选择另一张极限火花回手。费用提交前可取消。
- 多步骤效果在同一次结算内继续选择，不额外创建一个响应窗口；普通触发和启动效果仍进入堆叠。
- 白莲的X在使用时选择、计入实际支付，并作为入场指示物和回复生命的数值。极彩、极限火花别名与减费、支援、从除外区免费使用均接入既有支付校验。
- 时符保留在战场并显示计时，自己结束阶段递减；最后一个计时离开后已入堆叠的能力仍会结算。时符与乐章不充当永久物给自机供色；场上只保留一张乐章。
- 防避按独立次数逐次消耗；Escape Velocity采用本次卡图上的两次防避3。无法响应、防止伤害失效、吸血、追击和直接攻击单位均使用正常战斗与堆叠流程。
- 慧音允许使用的对手除外牌显示在当前操作者的除外标签；使用后记录操控者和原拥有者，离场回到原拥有者的区域。
- 美宵之酒、蓬莱之药等衍生物由相应效果生成，不出现在普通组卡库，也不能加入预组。原有调试移动、先制、妖梦、付款取消等操作保持可用。

## 原始资料差异

以本次提供的卡图为准，旧表与缓存仅用于核对文字和缺图：大结界的巫女按自机登记并补全退治及颜色盘角色符卡条件；「约定」为恰好两个不同名的自机单位；Escape Velocity为两次防避3；提供的吸血鬼图是2/2/2、吸血1、不占战场格版本。原文件名虽带FDF编号，未套用另一版本的3/3能力。辉光之城／辉光ノ城按同一张牌处理。照片中灵击符和魔法店的编号与缓存互换，因此按完整卡名匹配。

## 新增定义清单

下表列出本批所有新ID。完整费用、种族、数值、原文、图片和能力绑定见对应JSON。只有关键词的单位也有实际关键词判定；无能力衍生物保留原始白板规则。

| 卡牌ID | 完整名称 | 构筑 | 效果绑定 / 关键词 |
|---|---|---|---|
''')
for cid in plan['registered_new_ids']:
    c = cards[cid]
    effects = [a.get('参数', {}).get('效果', a.get('实现', '')) for a in c.get('能力绑定', [])]
    labels = effects + c.get('关键词', [])
    parts.append(f'| `{cid}` | {c["名称"]} | {"可用" if c.get("构筑资格", {}).get("允许常规构筑", True) else "衍生物，不加入"} | {"、".join(labels) or "白板"} |')
parts.append('''
## 验证与维护

规则测试 `tests/test_v010_rules.gd`、完整对局 `tests/test_v010_matches.gd`、真实图形交互 `tests/test_v010_ui.gd` 覆盖本批功能。原有规则、先制、妖梦与调试返回测试同时回归。最终计数、日志及素材核对结果见 `work/v010-validation.txt`。

`scripts/rules/precon_abilities.gd` 保存本批特殊效果；新增卡仍先归档图片，再写中文JSON与效果实现、登记ID，最后更新卡图索引。模板恢复工具 `tools/install_test_precons.gd` 只添加缺失模板，遇到玩家已修改的同ID预组会保留并报错，不覆盖玩家版本。
''')
write('docs/新增卡片与预组-v0.10.md', '\n'.join(parts))

path = ROOT / '使用说明.md'
text = path.read_text(encoding='utf-8-sig')
text = text.replace('v0.9.8', 'v0.10', 1)
text = text.replace('双方会选中各一套 50 张测试卡组，并启用「不检查卡组」「人机必定投 1」。可自行换卡组或选先后手。', '双方选中「预组-灵梦」「预组-魔理沙」，各50张主卡加1张自机，使用正常构筑检查。载入模板后启用「人机必定投1」，可自行修改。')
text = text.replace('测试卡组只使用原来的 8 种卡，含重复牌及所选自机同名牌，所以需使用「不检查卡组」。载入按钮不会立即写入卡组文件，也不会覆盖已有卡组；在组卡器主动保存时才会写入当前列表。', '两套预组已正式保存，原有4副卡组保留。载入按钮恢复内存中的两套预组模板，不立即修改存档；编辑后点击保存才写入。套牌数量、卡牌清单和新效果说明见 `docs/新增卡片与预组-v0.10.md`。')
text = text.replace('组卡器已开放65种卡。', '组卡器已开放124种可构筑卡，另有8种衍生物仅供对局生成。')
text = text.replace('角色符卡要求战场上有对应角色。', '角色符卡要求战场上有对应角色；具有「支援」时，自机区的对应角色也满足条件。')
text = text.replace('（终言同名最多 1 张）', '（终言同名最多1张，限制级同名最多2张）')
text = text.replace('65 张卡的中文资料', '132种卡的中文资料')
text = text.replace('本轮没有导入其中的新卡。', '本轮初始57张图片已处理，后续新放入的图片仍须指定批次后导入。')
text = text.replace('`scripts/rules/demo_abilities.gd`、`expanded_abilities.gd`', '`scripts/rules/demo_abilities.gd`、`expanded_abilities.gd`、`precon_abilities.gd`')
text = text.replace('当前可用范围是 65 张卡的本地人机对局与本地调试；本批 46 张新卡已登记规则效果。', '当前可用范围是132种数据库卡牌的本地人机对局与本地调试；本批新增67份定义，并实现新效果及两套合法预组。')
write('使用说明.md', text)

path = ROOT / 'docs/卡牌数据库与编写说明.md'
text = path.read_text(encoding='utf-8-sig').replace('版本：v0.9.7，2026-09-18。', '版本：v0.10，2026-09-19。')
text = text.replace('用户本轮要求暂不导入其中的新卡。', '新增文件不会因为启动游戏或更新索引就自动导入。')
text = text.replace('当前合计 65 张；', '当前合计132种（124可构筑、8衍生物）；')
write('docs/卡牌数据库与编写说明.md', text)
append('docs/卡牌数据库与编写说明.md', '''## v0.10：预组效果与人工编写入口

完整新卡清单及预组配比见 `新增卡片与预组-v0.10.md`。本批绑定形式：

```json
{"实现":"precon","名称":"这里填写卡面能力原文","参数":{"效果":"ramp_enter"}}
```

`card_database.gd` 的 `PRECON_EFFECTS` 明确允许的效果键；`precon_abilities.gd` 负责进离场、启动、触发、支付修正、动态关键词和结算。不要仅添加允许键而不实现实际逻辑。

- `衍生物:true` 搭配 `构筑资格.允许常规构筑:false`，允许无色衍生物资料，但禁止玩家放入套牌。
- `可变费用:"黄"` 记录X所在颜色；使用声明保存X，支付用实际X，堆叠费用值包含X，离开堆叠后按普通区域规则处理。
- `别名:["恋符「极限火花」"]` 只供明确涉及牌名的效果匹配；构筑同名计数仍按完整印刷卡名。
- 多目标使用 `{selection:[{pool,min,max,title,distinct_names,exclude_previous}],selection_id}` 描述约束，不生成所有排列。提交为 `{selection_id,picks:[[引用],...]}`，规则层再次验证数量、顺序、唯一性和区域版本。
- 结算中的检索、交换调用 `continue_choice`。它挂起当前效果并等待卡面选择，`choose_effect` 恢复同一次结算；不要将每一小步作为新触发重复入堆叠。
- 实例 `original_owner` 与 `owner` 分别表示拥有者和当前操控者。借用对手除外牌时维持前者，去墓地或手牌等区域恢复拥有者，换区版本阻止旧目标追踪。
- 横置通过 `tap_card`、回复生命通过 `gain_life`、伤害通过 `damage_target` 派发事件，避免直接改字段漏触发。`damage_context` 区分战斗、来源及单一伤害目标；选取费用或回收牌不算额外伤害目标。
- 独立防避次数保存在实例 `wards`；回合结束清理临时效果。时符0计时和幻象条件在状态检查处理，时符与乐章留场但不是永久物。

新增效果应测试合法性、付款取消、目标失效、结算连续选择、原拥有者换区与至少一场完整对局。资料导入与实现不可只停留在预览文字。
''')

append('docs/游戏整体开发计划.md', '''## 33. v0.10：两套预组与全部本批新效果

本轮初始待处理目录57张图先归档，补齐预组缺图和效果生成物后新增67份定义，数据库共132种；两套预组按照片保存为50主卡＋1自机，衍生物不加入，原有4副牌组保留。完整清单见 `新增卡片与预组-v0.10.md`。

状态流程增加三项：使用声明中的X和有序多目标；费用提交时的不同名牌除外与额外展示；结算中的检索、换牌与随机放回牌库底。提交前仍为本地私有状态，允许取消；提交后目标引用含区域版本，连续选择阻止双方抢先行动，完成后回到正常状态检查及执行权。

特殊效果模块覆盖新牌的时符、乐章、防避、直接单位攻击、追击、吸血、支援、极彩、别名与减费、指定区域使用及控制权。对局展示沿用卡面选择、右侧确认与堆叠说明；组卡卡图改为按需读取并限制缓存，避免卡库扩大后启动时加载全部大图。

后续工作：新一批卡牌继续按指定清单实施；完善通用替代与复制、扩充人机策略、平衡性测试、联网与确定性重放。完整对局测试证明本批可走到结束，不表示人机强度或两套牌胜率已经平衡。缺失的蓬莱之药原画待补充后替换SVG即可，规则实现无需重写。
''')

path=ROOT / 'recourse/数据库/README.md'
text=path.read_text(encoding='utf-8-sig').replace('用户本轮要求暂不导入，该区域其余文件保持原样。', '本轮初始57张卡图已处理；之后新放入的卡图不自动导入。')
write('recourse/数据库/README.md', text)
append('recourse/数据库/README.md', '''## v0.10登记

当前索引132种，含124种可构筑卡、8种衍生物。57张本批原始卡图中3张重复图存于 `异画与重复/v0.10/`，不作为独立规则卡。另从本地素材补齐11张预组卡图与美宵之酒，蓬莱之药采用可替换SVG占位图。移动与哈希清单见 `work/v010-import-plan.json`，卡表见 `docs/新增卡片与预组-v0.10.md`。
''')
print('V010 documentation written.')
