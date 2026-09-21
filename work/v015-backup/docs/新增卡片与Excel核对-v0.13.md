# 新增卡片与 Excel 核对 · v0.13

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

最终 3227 项检查零失败，另 36 场完整对局正常结束。127 张新符卡逐一经过合法选项、结算及续程检查；90 张非符卡经过进场、阶段、攻击/阻挡和离场路径；25 个新启动效果键逐一提交并结算。新规则专项 120 项、边界 138 项、真实图形输入 37 项通过，另覆盖旧卡、先制/妖梦、费用、区域、数据库纹理与旧界面回归。

最终日志无项目脚本、资源或着色器错误；环境仍报告既有 Windows 根证书读取诊断。测试发现并修复的实现问题包括：旧非符反制与 Excel 类别前缀不兼容、延续选择丢失伤害来源、重复磨牌触发批量计数、被复制效果的已付费用和模式保留、衍生物离场通知、通用启动伤害改目标遗漏玩家。帕秋莉使用角色符卡后的目标选择必须先完成再继续结算，UI 测试按实际优先权流程验证。

`work/v013/validation.json` 为最终汇总，`final-data-audit.json` 为图片和 Excel 审计。覆盖测试不代表穷尽 486 张牌的全部组合，也不代表人机决策或套牌平衡已经完成。

## 本批已有定义同步

下表只列字段实际变化的旧定义；来源定位和其他维护字段另见各 JSON。

| ID | 卡名 | 同步字段 |
| --- | --- | --- |
| `106` | 「彼岸ノ神想」 | 符卡类型 |
| `11` | 巡秋而来「秋静叶」 | 角色约束、符卡类型 |
| `110` | 「背德ノ吸血鬼」 | 符卡类型 |
| `112` | 「甜蜜时刻」 | 角色约束、符卡类型 |
| `118` | 空观剑「六根清净斩」 | 符卡类型 |
| `120` | 「反魂蝶」 | 符卡类型 |
| `130` | 「永夜蛰居」 | 符卡类型 |
| `14` | 「小恶魔」 | 角色约束、符卡类型 |
| `141` | 「出鞘」 | 符卡类型 |
| `143` | 「极光」 | 符卡类型 |
| `147` | 「无意识ノ雨」 | 符卡类型 |
| `15` | 宵暗的妖怪「露米娅」 | 能力文字、角色约束、符卡类型 |
| `162` | 「Hell's Tokamak」 | 符卡类型 |
| `163` | 「萤燈ノ森」 | 符卡类型 |
| `165` | 「蕾米莉亚的烛台」 | 能力文字、角色约束、符卡类型、高速 |
| `166` | 「早苗的御币」 | 角色约束、符卡类型、高速 |
| `169` | 红魔馆 | 角色约束、符卡类型、高速 |
| `170` | 博丽神社 | 能力文字、角色约束、符卡类型、高速 |
| `176` | 「异星弹幕ノ空」 | 符卡类型 |
| `177` | 「正义宝塔ノ光」 | 符卡类型 |
| `18` | 天狗记者「射命丸文」 | 角色约束、符卡类型 |
| `21` | 蓬莱的人之形「藤原妹红」 | 角色约束、符卡类型 |
| `23` | 地壳下的嫉妒心「水桥帕露西」 | 角色约束、符卡类型 |
| `28` | 提琴手「露娜萨·普莉兹姆利巴」 | 角色约束、符卡类型 |
| `33` | 狂气月兔「铃仙·优昙华院·因幡」 | 角色约束、符卡类型 |
| `35` | 地狱的最高裁判长「四季映姬」 | 角色约束、符卡类型 |
| `38` | 引雷的亡灵「苏我屠自古」 | 能力文字、角色约束、符卡类型 |
| `39` | 苍天的庭师「魂魄妖梦」 | 角色约束、符卡类型 |
| `41` | 刚欲同盟盟主「饕餮尤魔」 | 角色约束、符卡类型 |
| `50` | 「鬼神长」 | 角色约束、符卡类型、高速 |
| `53` | 「山童士兵」 | 角色约束、符卡类型、高速 |
| `54` | 「埴轮泰坦」 | 角色约束、符卡类型、高速 |
| `56` | 「龙宫使者」 | 高速 |
| `6` | 可怕的波动「芙兰朵露·斯卡蕾特」 | 角色约束、符卡类型 |
| `64` | 未知力量X「封兽ぬえ」 | 角色约束、符卡类型 |
| `70` | 乐园的可爱巫女「博丽灵梦」 | 能力文字 |
| `71` | 华胥的亡灵「西行寺幽幽子」 | 角色约束、符卡类型 |
| `77` | 七色的人偶使「爱丽丝·玛格特洛依德」 | 能力文字 |
| `79` | 飞散红叶的天狗「射命丸文」 | 角色约束、符卡类型、高速 |
| `91` | 地狱的轮祸「火焰猫燐」 | 角色约束、符卡类型、高速 |
| `93` | 土著神之顶「洩矢诹访子」 | 能力文字 |
| `94` | 「秋意ノ溪」 | 符卡类型 |
| `96` | 「樱华ノ月」 | 角色约束、符卡类型 |
| `character-rei-026` | 祭祀风之人「东风谷早苗」 | 类别、能力文字 |

## 新增 217 条完整清单

效果键中的 `:self` 表示需具备自机能力；允许常规构筑为“否”的卡不进入普通组卡库。各行链接直接指向可人工修改的 JSON。

| ID | 完整卡名 | 类别 | 可构筑 | Excel 位置 | 效果键 |
| --- | --- | --- | --- | --- | --- |
| [character-fdf-029](../cards/character-fdf-029.json) | 川雾的引航人「小野冢小町」 | 自机 | 是 | CHARACTER (单位) · 266 · FDF-029 | character-fdf-029；character-fdf-029:self |
| [character-fdf-041](../cards/character-fdf-041.json) | 完美而潇洒的从者「十六夜咲夜」 | 自机 | 是 | CHARACTER (单位) · 267 · FDF-041 | character-fdf-041；character-fdf-041:self |
| [character-fdf-046](../cards/character-fdf-046.json) | 禁止通行「云居一轮&云山」 | 单位 | 是 | CHARACTER (单位) · 268 · FDF-046 | character-fdf-046 |
| [character-fdf-065](../cards/character-fdf-065.json) | 污秽的有机怪物「天火人血枪」 | 单位 | 是 | CHARACTER (单位) · 269 · FDF-065 | character-fdf-065 |
| [character-fdf-069](../cards/character-fdf-069.json) | 诵经的山彦「幽谷响子」 | 单位 | 是 | CHARACTER (单位) · 270 · FDF-069 | character-fdf-069 |
| [character-fdf-090](../cards/character-fdf-090.json) | 幻胧的月兔「铃仙·优昙华院·因幡」 | 自机 | 是 | CHARACTER (单位) · 272 · FDF-090 | character-fdf-090；character-fdf-090:self |
| [character-fdf-091](../cards/character-fdf-091.json) | 鲜红的恶魔「蕾米莉亚·斯卡雷特」 | 单位 | 是 | CHARACTER (单位) · 273 · FDF-091 | character-fdf-091 |
| [character-fdf-092](../cards/character-fdf-092.json) | 小小的贤将「纳兹琳」 | 单位 | 是 | CHARACTER (单位) · 274 · FDF-092 | character-fdf-092 |
| [character-fdf-093](../cards/character-fdf-093.json) | 控龙的少女「物部布都」 | 单位 | 是 | CHARACTER (单位) · 275 · FDF-093 | character-fdf-093 |
| [character-fdf-094](../cards/character-fdf-094.json) | 深夜食堂店长「米斯蒂娅·萝蕾拉」 | 单位 | 是 | CHARACTER (单位) · 276 · FDF-094 | character-fdf-094 |
| [character-fdf-098](../cards/character-fdf-098.json) | 巧言令色的白兔「因幡帝」 | 单位 | 是 | CHARACTER (单位) · 278 · FDF-098 | character-fdf-098 |
| [character-fdf-100](../cards/character-fdf-100.json) | 水难事故的化身「村纱水蜜」 | 单位 | 是 | CHARACTER (单位) · 280 · FDF-100 | character-fdf-100 |
| [character-fdf-101](../cards/character-fdf-101.json) | 雪中的天狗「犬走椛」 | 单位 | 是 | CHARACTER (单位) · 281 · FDF-101 | character-fdf-101 |
| [character-fdf-102](../cards/character-fdf-102.json) | 幽冥的剑术家「魂魄妖梦」 | 自机 | 是 | CHARACTER (单位) · 282 · FDF-102 | character-fdf-102；character-fdf-102:self |
| [character-fdf-103](../cards/character-fdf-103.json) | 「胆小的小人士兵」 | 单位 | 是 | CHARACTER (单位) · 283 · FDF-103 | character-fdf-103 |
| [character-fdf-104](../cards/character-fdf-104.json) | 萤火的行踪「莉格露·奈特巴格」 | 单位 | 是 | CHARACTER (单位) · 284 · FDF-104 | character-fdf-104 |
| [character-fdf-105](../cards/character-fdf-105.json) | 无间之钟「姬海棠果」 | 单位 | 是 | CHARACTER (单位) · 285 · FDF-105 | character-fdf-105 |
| [character-fdf-106](../cards/character-fdf-106.json) | 天才的造型神「埴安神袿姬」 | 单位 | 是 | CHARACTER (单位) · 286 · FDF-106 | character-fdf-106 |
| [character-fdf-109](../cards/character-fdf-109.json) | 花田的新人「梅蒂欣·梅兰可莉」 | 单位 | 是 | CHARACTER (单位) · 287 · FDF-109 | character-fdf-109 |
| [character-fdf-110](../cards/character-fdf-110.json) | 华之大江山「星熊勇仪」 | 单位 | 是 | CHARACTER (单位) · 288 · FDF-110 | character-fdf-110 |
| [character-fdf-111](../cards/character-fdf-111.json) | 神明后裔的亡灵「苏我屠自古」 | 单位 | 是 | CHARACTER (单位) · 289 · FDF-111 | character-fdf-111 |
| [character-fdf-112](../cards/character-fdf-112.json) | 布加勒斯特的人偶师「爱丽丝·玛格特罗伊德」 | 单位 | 是 | CHARACTER (单位) · 290 · FDF-112 | character-fdf-112 |
| [character-fdf-113](../cards/character-fdf-113.json) | 狂气的地狱妖精「克劳恩皮丝」 | 单位 | 是 | CHARACTER (单位) · 291 · FDF-113 | character-fdf-113 |
| [character-fdf-114](../cards/character-fdf-114.json) | 耳边低语的邪恶白狐「菅牧典」 | 单位 | 是 | CHARACTER (单位) · 292 · FDF-114 | character-fdf-114 |
| [character-fdf-115](../cards/character-fdf-115.json) | 「自异星而来的物体」 | 单位 | 是 | CHARACTER (单位) · 293 · FDF-115 | character-fdf-115 |
| [character-fdf-117](../cards/character-fdf-117.json) | 平安时代的妖怪「封兽鵺」 | 自机 | 是 | CHARACTER (单位) · 295 · FDF-117 | character-fdf-117；character-fdf-117:self |
| [character-fdf-119](../cards/character-fdf-119.json) | 不动的大图书馆「帕秋莉·诺蕾姬」 | 自机 | 是 | CHARACTER (单位) · 301 · FDF-119 | character-fdf-119；character-fdf-119:self |
| [character-fdn-004](../cards/character-fdn-004.json) | 战栗的蓬莱人「藤原妹红」 | 自机 | 是 | CHARACTER (单位) · 339 · FDN-004 | character-fdn-004；character-fdn-004:self |
| [character-fdn-006](../cards/character-fdn-006.json) | 「妖怪之山的妖精」 | 单位 | 是 | CHARACTER (单位) · 340 · FDN-006 | character-fdn-006 |
| [character-fdn-007](../cards/character-fdn-007.json) | 「妖精们的居所」 | 自机 | 是 | CHARACTER (单位) · 341 · FDN-007 | character-fdn-007；character-fdn-007:self |
| [character-fdn-013](../cards/character-fdn-013.json) | 「魔法之森的妖精」 | 单位 | 是 | CHARACTER (单位) · 342 · FDN-013 | character-fdn-013 |
| [character-fdn-014](../cards/character-fdn-014.json) | 「红魔馆的吸血鬼妖精」 | 单位 | 是 | CHARACTER (单位) · 343 · FDN-014 | character-fdn-014 |
| [character-fdn-021](../cards/character-fdn-021.json) | 彼岸的鸡之神「庭渡久侘歌」 | 单位 | 是 | CHARACTER (单位) · 344 · FDN-021 | character-fdn-021 |
| [character-fdn-024](../cards/character-fdn-024.json) | 「地灵殿的妖精」 | 单位 | 是 | CHARACTER (单位) · 345 · FDN-024 | character-fdn-024 |
| [character-fdn-025](../cards/character-fdn-025.json) | 背德的姐妹「蕾米莉亚&芙兰朵露」 | 自机 | 是 | CHARACTER (单位) · 346 · FDN-025 | character-fdn-025；character-fdn-025:self |
| [character-fdn-026](../cards/character-fdn-026.json) | 意识之底「古明地觉&古明地恋」 | 自机 | 是 | CHARACTER (单位) · 347 · FDN-026 | character-fdn-026；character-fdn-026:self |
| [character-fdn-027](../cards/character-fdn-027.json) | 栖息于淡水的人鱼「若鹭姬」 | 单位 | 是 | CHARACTER (单位) · 348 · FDN-027 | character-fdn-027 |
| [character-fdn-034](../cards/character-fdn-034.json) | 辘轳首的怪奇「赤蛮奇」 | 单位 | 是 | CHARACTER (单位) · 349 · FDN-034 | character-fdn-034 |
| [character-fdn-035](../cards/character-fdn-035.json) | 沉着冷静的人狼「今泉影狼」 | 单位 | 是 | CHARACTER (单位) · 350 · FDN-035 | character-fdn-035 |
| [character-fdn-036](../cards/character-fdn-036.json) | 传统的幻想记者 「射命丸文」 | 自机 | 是 | CHARACTER (单位) · 351 · FDN-036 | character-fdn-036；character-fdn-036:self |
| [character-fdn-037](../cards/character-fdn-037.json) | 「要塞的天狗」 | 单位 | 是 | CHARACTER (单位) · 352 · FDN-037 | character-fdn-037 |
| [character-fdn-038](../cards/character-fdn-038.json) | 「侦察的天狗」 | 单位 | 是 | CHARACTER (单位) · 353 · FDN-038 | character-fdn-038 |
| [character-fdn-041](../cards/character-fdn-041.json) | 「红魔馆的吸血鬼女仆」 | 单位 | 是 | CHARACTER (单位) · 354 · FDN-041 | character-fdn-041 |
| [character-fdn-042](../cards/character-fdn-042.json) | 难以驾驭的神之火「灵乌路空」 | 单位 | 是 | CHARACTER (单位) · 355 · FDN-042 | character-fdn-042 |
| [character-fdn-043](../cards/character-fdn-043.json) | 「富士见之女」 | 单位 | 是 | CHARACTER (单位) · 356 · FDN-043 | character-fdn-043 |
| [character-fdn-045](../cards/character-fdn-045.json) | 试作型超巨大人偶「歌莉娅人偶」 | 单位 | 是 | CHARACTER (单位) · 357 · FDN-045 | character-fdn-045 |
| [character-fdn-048](../cards/character-fdn-048.json) | 绯红的霄暗「蕾米莉亚·斯卡雷特」 | 自机 | 是 | CHARACTER (单位) · 359 · FDN-048 | character-fdn-048；character-fdn-048:self |
| [character-fdn-071](../cards/character-fdn-071.json) | 究极的绝对秘神「摩多罗隐崎奈」 | 自机 | 是 | CHARACTER (单位) · 375 · FDN-071 | character-fdn-071；character-fdn-071:self |
| [character-htk-005](../cards/character-htk-005.json) | 使人做梦的妖怪「哆来咪·苏伊特」 | 单位 | 是 | CHARACTER (单位) · 193 · HTK-005 | character-htk-005 |
| [character-kmo-005](../cards/character-kmo-005.json) | 竹林中的狼人「今泉影狼」 | 单位 | 是 | CHARACTER (单位) · 102 · KMO-005 | character-kmo-005 |
| [character-lof-002](../cards/character-lof-002.json) | 雾之湖公主「大妖精」 | 单位 | 是 | CHARACTER (单位) · 177 · LOF-002 | character-lof-002 |
| [character-lof-004](../cards/character-lof-004.json) | 「花田的妖精」 | 单位 | 是 | CHARACTER (单位) · 179 · LOF-004 | character-lof-004 |
| [character-smm05](../cards/character-smm05.json) | 小人的公主「少名针妙丸」 | 单位 | 是 | CHARACTER (单位) · 115 · SMM05 | character-smm05 |
| [character-ucs-003](../cards/character-ucs-003.json) | 繁星的引导者「饭纲丸龙」 | 单位 | 是 | CHARACTER (单位) · 127 · UCS-003 | character-ucs-003 |
| [character-ucs-010](../cards/character-ucs-010.json) | 洞窟之网「黑谷山女」 | 单位 | 是 | CHARACTER (单位) · 129 · UCS-010 | 无额外能力 |
| [character-ucs-016](../cards/character-ucs-016.json) | 腹黑的人鱼公主「若鹭姬」 | 单位 | 是 | CHARACTER (单位) · 130 · UCS-016 | character-ucs-016 |
| [character-ucs-020](../cards/character-ucs-020.json) | 少女秘封俱乐部「宇佐见莲子」 | 单位 | 否 | CHARACTER (单位) · 131 · UCS-020 | character-ucs-020 |
| [character-ucs-021](../cards/character-ucs-021.json) | 少女秘封俱乐部「玛艾露贝莉·赫恩」 | 单位 | 否 | CHARACTER (单位) · 132 · UCS-021 | character-ucs-021 |
| [character-ucs-023](../cards/character-ucs-023.json) | 柳树下的首级「赤蛮奇」 | 单位 | 是 | CHARACTER (单位) · 133 · UCS-023 | character-ucs-023 |
| [character-ucs-025](../cards/character-ucs-025.json) | 「诹访子与赤口大人」 | 单位 | 是 | CHARACTER (单位) · 134 · UCS-025 | character-ucs-025 |
| [character-ucs-034](../cards/character-ucs-034.json) | 空想人格的保持者「古明地恋」 | 单位 | 是 | CHARACTER (单位) · 138 · UCS-034 | character-ucs-034 |
| [character-ucs-036](../cards/character-ucs-036.json) | 孤影悄然的妖怪「古明地觉」 | 单位 | 是 | CHARACTER (单位) · 139 · UCS-036 | character-ucs-036 |
| [character-ucs-044](../cards/character-ucs-044.json) | 深山的妖怪「山城高岭」 | 单位 | 是 | CHARACTER (单位) · 143 · UCS-044 | character-ucs-044 |
| [character-ucs-046](../cards/character-ucs-046.json) | 水中的迷彩「河城荷取」 | 单位 | 是 | CHARACTER (单位) · 144 · UCS-046 | character-ucs-046 |
| [character-ucs-053](../cards/character-ucs-053.json) | 幻想的策士「八云蓝」 | 单位 | 是 | CHARACTER (单位) · 147 · UCS-053 | character-ucs-053 |
| [character-ucs-056](../cards/character-ucs-056.json) | 妖怪之山的哨戒「犬走椛」 | 单位 | 是 | CHARACTER (单位) · 149 · UCS-056 | character-ucs-056 |
| [character-ucs-058](../cards/character-ucs-058.json) | 地狱的口岸神「庭渡久诧歌」 | 单位 | 是 | CHARACTER (单位) · 150 · UCS-058 | character-ucs-058 |
| [character-ucs-061](../cards/character-ucs-061.json) | 天地上等「比那名居天子」 | 自机 | 是 | CHARACTER (单位) · 152 · UCS-061 | character-ucs-061；character-ucs-061:self |
| [character-ucs-063](../cards/character-ucs-063.json) | 「灵」 | 单位 | 是 | CHARACTER (单位) · 153 · UCS-063 | character-ucs-063 |
| [character-ucs-065](../cards/character-ucs-065.json) | 逆袭的天邪鬼「鬼人正邪」 | 单位 | 是 | CHARACTER (单位) · 154 · UCS-065 | character-ucs-065:health；character-ucs-065:spirit |
| [character-ucs-066](../cards/character-ucs-066.json) | 畜生界的藏匿者「吉吊八千慧」 | 单位 | 是 | CHARACTER (单位) · 155 · UCS-066 | character-ucs-066 |
| [character-ucs-067](../cards/character-ucs-067.json) | 绯红的宵暗「蕾米莉亚·斯卡蕾特」 | 自机 | 是 | CHARACTER (单位) · 156 · UCS-067 | character-ucs-067；character-ucs-067:self |
| [character-ucs-068](../cards/character-ucs-068.json) | 究极的绝对秘神「摩多罗·隐岐奈」 | 自机 | 是 | CHARACTER (单位) · 157 · UCS-068 | character-ucs-068；character-ucs-068:self |
| [character-ucs-073](../cards/character-ucs-073.json) | 剧毒的死体「宫古芳香」 | 单位 | 是 | CHARACTER (单位) · 162 · UCS-073 | character-ucs-073 |
| [field-fdf-089](../cards/field-fdf-089.json) | 再思ノ道 | 结界 | 是 | FIELD(结界) · 20 · FDF-089 | field-fdf-089 |
| [field-fdf-107](../cards/field-fdf-107.json) | 守矢神社 | 结界 | 是 | FIELD(结界) · 21 · FDF-107 | field-fdf-107 |
| [field-rei-013](../cards/field-rei-013.json) | 辉光ノ城 | 结界 | 是 | FIELD(结界) · 26 · REI-013 | field-rei-013 |
| [field-ucs-064](../cards/field-ucs-064.json) | 白玉ノ阶梯 | 结界 | 是 | FIELD(结界) · 11 · UCS-064 | field-ucs-064 |
| [item-fdf-096](../cards/item-fdf-096.json) | 「蓬莱的玉枝」 | 道具 | 是 | ITEM {道具} · 28 · FDF-096 | item-fdf-096 |
| [item-fdf-097](../cards/item-fdf-097.json) | 「月兔制造机」 | 道具 | 是 | ITEM {道具} · 29 · FDF-097 | item-fdf-097 |
| [item-fdn-044](../cards/item-fdn-044.json) | 「因幡帝的幸运萝卜」 | 道具 | 是 | ITEM {道具} · 32 · FDN-044 | item-fdn-044 |
| [item-htk-008](../cards/item-htk-008.json) | 「香霖堂的谜之书籍」 | 道具 | 是 | ITEM {道具} · 19 · HTK-008 | item-htk-008 |
| [item-lof-009](../cards/item-lof-009.json) | 「妖精公主的信物」 | 道具 | 是 | ITEM {道具} · 18 · LOF-009 | item-lof-009 |
| [item-ucs-005](../cards/item-ucs-005.json) | 「幽香的阳伞」 | 道具 | 是 | ITEM {道具} · 14 · UCS-005 | item-ucs-005 |
| [item-ucs-013](../cards/item-ucs-013.json) | 「风祝的头饰」 | 道具 | 是 | ITEM {道具} · 16 · UCS-013 | item-ucs-013 |
| [item-ucs-017](../cards/item-ucs-017.json) | 「死神的大镰」 | 道具 | 是 | ITEM {道具} · 17 · UCS-017 | item-ucs-017 |
| [spell-fdf-001](../cards/spell-fdf-001.json) | 道符「掌上の天道」 | 符卡 | 是 | SPELL （符卡） · 195 · FDF-001 | spell-fdf-001 |
| [spell-fdf-002](../cards/spell-fdf-002.json) | 名誉「十二阶の色彩」 | 符卡 | 是 | SPELL （符卡） · 196 · FDF-002 | spell-fdf-002 |
| [spell-fdf-003](../cards/spell-fdf-003.json) | 「逸脱者ノ光」 | 符卡 | 是 | SPELL （符卡） · 197 · FDF-003 | spell-fdf-003 |
| [spell-fdf-005](../cards/spell-fdf-005.json) | 「夏」 | 符卡 | 是 | SPELL （符卡） · 199 · FDF-005 | spell-fdf-005 |
| [spell-fdf-006](../cards/spell-fdf-006.json) | 死灵「死ノ妖精」 | 符卡 | 是 | SPELL （符卡） · 200 · FDF-006 | spell-fdf-006 |
| [spell-fdf-008](../cards/spell-fdf-008.json) | 魔炮「Final Master Spark」 | 符卡 | 是 | SPELL （符卡） · 202 · FDF-008 | spell-fdf-008 |
| [spell-fdf-009](../cards/spell-fdf-009.json) | 新史「新幻想史-现代史-」 | 符卡 | 是 | SPELL （符卡） · 203 · FDF-009 | spell-fdf-009 |
| [spell-fdf-010](../cards/spell-fdf-010.json) | 虚史「幻想乡传说」 | 符卡 | 是 | SPELL （符卡） · 204 · FDF-010 | spell-fdf-010 |
| [spell-fdf-012](../cards/spell-fdf-012.json) | 猫符「Cat’s Walk」 | 符卡 | 是 | SPELL （符卡） · 206 · FDF-012 | spell-fdf-012 |
| [spell-fdf-013](../cards/spell-fdf-013.json) | 要石「天空ノ灵石」 | 符卡 | 是 | SPELL （符卡） · 207 · FDF-013 | spell-fdf-013 |
| [spell-fdf-014](../cards/spell-fdf-014.json) | 结界「梦境与现实ノ诅咒」 | 符卡 | 是 | SPELL （符卡） · 208 · FDF-014 | spell-fdf-014 |
| [spell-fdf-015](../cards/spell-fdf-015.json) | 神符「天人ノ系谱」 | 符卡 | 是 | SPELL （符卡） · 209 · FDF-015 | spell-fdf-015 |
| [spell-fdf-016](../cards/spell-fdf-016.json) | 换命「不惜身命，可惜身命」 | 符卡 | 是 | SPELL （符卡） · 210 · FDF-016 | spell-fdf-016 |
| [spell-fdf-017](../cards/spell-fdf-017.json) | 女仆秘技「杀人玩偶」 | 符卡 | 是 | SPELL （符卡） · 211 · FDF-017 | spell-fdf-017 |
| [spell-fdf-018](../cards/spell-fdf-018.json) | 反应「妖怪测谎仪」 | 符卡 | 是 | SPELL （符卡） · 212 · FDF-018 | spell-fdf-018 |
| [spell-fdf-021](../cards/spell-fdf-021.json) | 表象「弹幕偏执狂」 | 符卡 | 是 | SPELL （符卡） · 215 · FDF-021 | spell-fdf-021 |
| [spell-fdf-022](../cards/spell-fdf-022.json) | 深层「无意识ノ基因」 | 符卡 | 是 | SPELL （符卡） · 216 · FDF-022 | spell-fdf-022 |
| [spell-fdf-024](../cards/spell-fdf-024.json) | 月符「静寂ノ月神」 | 符卡 | 是 | SPELL （符卡） · 218 · FDF-024 | spell-fdf-024 |
| [spell-fdf-025](../cards/spell-fdf-025.json) | 诅咒「魔光ノ上海人形」 | 符卡 | 是 | SPELL （符卡） · 219 · FDF-025 | spell-fdf-025 |
| [spell-fdf-026](../cards/spell-fdf-026.json) | 「幻想春花」 | 符卡 | 是 | SPELL （符卡） · 220 · FDF-026 | spell-fdf-026 |
| [spell-fdf-027](../cards/spell-fdf-027.json) | 爆符「Mage-Flare」 | 符卡 | 是 | SPELL （符卡） · 221 · FDF-027 | spell-fdf-027 |
| [spell-fdf-028](../cards/spell-fdf-028.json) | 核热「核反应制御不能」 | 符卡 | 是 | SPELL （符卡） · 222 · FDF-028 | spell-fdf-028 |
| [spell-fdf-030](../cards/spell-fdf-030.json) | 操符「乙女文乐」 | 符卡 | 是 | SPELL （符卡） · 223 · FDF-030 | spell-fdf-030 |
| [spell-fdf-031](../cards/spell-fdf-031.json) | 花符「Flower Land」 | 符卡 | 是 | SPELL （符卡） · 224 · FDF-031 | spell-fdf-031 |
| [spell-fdf-032](../cards/spell-fdf-032.json) | 脑符「Brain Fingerprint」 | 符卡 | 是 | SPELL （符卡） · 225 · FDF-032 | spell-fdf-032 |
| [spell-fdf-033](../cards/spell-fdf-033.json) | 心花「Camera-Shy Rose」 | 符卡 | 是 | SPELL （符卡） · 226 · FDF-033 | spell-fdf-033 |
| [spell-fdf-035](../cards/spell-fdf-035.json) | 红符「不夜城-RED-」 | 符卡 | 是 | SPELL （符卡） · 228 · FDF-035 | spell-fdf-035 |
| [spell-fdf-037](../cards/spell-fdf-037.json) | 夜符「Queen of Midnight」 | 符卡 | 是 | SPELL （符卡） · 230 · FDF-037 | spell-fdf-037 |
| [spell-fdf-038](../cards/spell-fdf-038.json) | 冥符「虹色ノ冥界」 | 符卡 | 是 | SPELL （符卡） · 231 · FDF-038 | spell-fdf-038 |
| [spell-fdf-039](../cards/spell-fdf-039.json) | 「新绿ノ音·延伸ノ景」 | 符卡 | 是 | SPELL （符卡） · 232 · FDF-039 | spell-fdf-039 |
| [spell-fdf-040](../cards/spell-fdf-040.json) | 幻葬「夜雾ノ幻影杀人鬼」 | 符卡 | 是 | SPELL （符卡） · 233 · FDF-040 | spell-fdf-040 |
| [spell-fdf-042](../cards/spell-fdf-042.json) | 「冬」 | 符卡 | 是 | SPELL （符卡） · 234 · FDF-042 | spell-fdf-042 |
| [spell-fdf-043](../cards/spell-fdf-043.json) | 萃符「户隐山ノ投」 | 符卡 | 是 | SPELL （符卡） · 235 · FDF-043 | spell-fdf-043 |
| [spell-fdf-044](../cards/spell-fdf-044.json) | 「圣ノ鼓动·法界ノ火」 | 符卡 | 是 | SPELL （符卡） · 236 · FDF-044 | spell-fdf-044 |
| [spell-fdf-045](../cards/spell-fdf-045.json) | 魂符「生魂流离ノ镰」 | 符卡 | 是 | SPELL （符卡） · 237 · FDF-045 | spell-fdf-045 |
| [spell-fdf-047](../cards/spell-fdf-047.json) | 亡乡「亡我乡-彷徨ノ灵魂」 | 符卡 | 是 | SPELL （符卡） · 238 · FDF-047 | spell-fdf-047 |
| [spell-fdf-048](../cards/spell-fdf-048.json) | 樱符「Sense of Cherry Blossom」 | 符卡 | 是 | SPELL （符卡） · 239 · FDF-048 | spell-fdf-048 |
| [spell-fdf-049](../cards/spell-fdf-049.json) | 人鬼「未来永劫斩-樱-」 | 符卡 | 是 | SPELL （符卡） · 240 · FDF-049 | spell-fdf-049 |
| [spell-fdf-050](../cards/spell-fdf-050.json) | 断迷剑「迷津慈航斩」 | 符卡 | 是 | SPELL （符卡） · 241 · FDF-050 | spell-fdf-050 |
| [spell-fdf-051](../cards/spell-fdf-051.json) | 禁弹「Catadioptric」 | 符卡 | 是 | SPELL （符卡） · 242 · FDF-051 | spell-fdf-051 |
| [spell-fdf-052](../cards/spell-fdf-052.json) | 幻波「赤眼催眠」 | 符卡 | 是 | SPELL （符卡） · 243 · FDF-052 | spell-fdf-052 |
| [spell-fdf-053](../cards/spell-fdf-053.json) | 魔法「紫云ノ兆」 | 符卡 | 是 | SPELL （符卡） · 244 · FDF-053 | spell-fdf-053 |
| [spell-fdf-055](../cards/spell-fdf-055.json) | 幻在「Clock Corpse」 | 符卡 | 是 | SPELL （符卡） · 246 · FDF-055 | spell-fdf-055 |
| [spell-fdf-056](../cards/spell-fdf-056.json) | 投钱「宵越ノ钱」 | 符卡 | 是 | SPELL （符卡） · 247 · FDF-056 | spell-fdf-056 |
| [spell-fdf-057](../cards/spell-fdf-057.json) | 狂符「幻视调率」 | 符卡 | 是 | SPELL （符卡） · 248 · FDF-057 | spell-fdf-057 |
| [spell-fdf-058](../cards/spell-fdf-058.json) | 禁忌「Four of a Kind」 | 符卡 | 是 | SPELL （符卡） · 249 · FDF-058 | spell-fdf-058 |
| [spell-fdf-059](../cards/spell-fdf-059.json) | 妖剑「辉针剑」 | 符卡 | 是 | SPELL （符卡） · 250 · FDF-059 | spell-fdf-059 |
| [spell-fdf-060](../cards/spell-fdf-060.json) | 「永夜归还-待宵-」 | 符卡 | 是 | SPELL （符卡） · 251 · FDF-060 | spell-fdf-060 |
| [spell-fdf-061](../cards/spell-fdf-061.json) | 秘术「天文密葬法」 | 符卡 | 是 | SPELL （符卡） · 252 · FDF-061 | spell-fdf-061 |
| [spell-fdf-062](../cards/spell-fdf-062.json) | 鬼群「Imp Swarm」 | 符卡 | 是 | SPELL （符卡） · 253 · FDF-062 | spell-fdf-062 |
| [spell-fdf-063](../cards/spell-fdf-063.json) | 秘法「九字切」 | 符卡 | 是 | SPELL （符卡） · 254 · FDF-063 | spell-fdf-063 |
| [spell-fdf-064](../cards/spell-fdf-064.json) | 「Mooned Insect」 | 符卡 | 是 | SPELL （符卡） · 255 · FDF-064 | spell-fdf-064 |
| [spell-fdf-066](../cards/spell-fdf-066.json) | 「畜生调服」 | 符卡 | 是 | SPELL （符卡） · 256 · FDF-066 | spell-fdf-066 |
| [spell-fdf-067](../cards/spell-fdf-067.json) | 秘仪「弹幕ノ玉茧」 | 符卡 | 是 | SPELL （符卡） · 257 · FDF-067 | spell-fdf-067 |
| [spell-fdf-068](../cards/spell-fdf-068.json) | 门符「最后ノ理想国」 | 符卡 | 是 | SPELL （符卡） · 258 · FDF-068 | spell-fdf-068 |
| [spell-fdf-071](../cards/spell-fdf-071.json) | 「游星弹幕“X”」 | 符卡 | 是 | SPELL （符卡） · 259 · FDF-071 | spell-fdf-071 |
| [spell-fdf-072](../cards/spell-fdf-072.json) | 「平安京ノ恶梦」 | 符卡 | 是 | SPELL （符卡） · 260 · FDF-072 | spell-fdf-072 |
| [spell-fdf-073](../cards/spell-fdf-073.json) | 执符「御射山御狩神事」 | 符卡 | 是 | SPELL （符卡） · 261 · FDF-073 | spell-fdf-073 |
| [spell-fdf-074](../cards/spell-fdf-074.json) | 神祭「Expanded Onbashira」 | 符卡 | 是 | SPELL （符卡） · 262 · FDF-074 | spell-fdf-074 |
| [spell-fdf-075](../cards/spell-fdf-075.json) | 金符「Metal Fatigue」 | 符卡 | 是 | SPELL （符卡） · 263 · FDF-075 | spell-fdf-075 |
| [spell-fdf-076](../cards/spell-fdf-076.json) | 土符「Lazy Trilithon」 | 符卡 | 是 | SPELL （符卡） · 264 · FDF-076 | spell-fdf-076 |
| [spell-fdf-077](../cards/spell-fdf-077.json) | 水符「Princess Undine」 | 符卡 | 是 | SPELL （符卡） · 265 · FDF-077 | spell-fdf-077 |
| [spell-fdf-078](../cards/spell-fdf-078.json) | 火符「Agni Shine」 | 符卡 | 是 | SPELL （符卡） · 266 · FDF-078 | spell-fdf-078 |
| [spell-fdf-079](../cards/spell-fdf-079.json) | 木符「Sylphy Horn」 | 符卡 | 是 | SPELL （符卡） · 267 · FDF-079 | spell-fdf-079 |
| [spell-fdf-080](../cards/spell-fdf-080.json) | 「招雨ノ雨蛙」 | 符卡 | 是 | SPELL （符卡） · 268 · FDF-080 | spell-fdf-080 |
| [spell-fdf-081](../cards/spell-fdf-081.json) | 「最凶&最恶」 | 符卡 | 是 | SPELL （符卡） · 269 · FDF-081 | spell-fdf-081 |
| [spell-fdf-082](../cards/spell-fdf-082.json) | 结界「光与暗ノ网目」 | 符卡 | 是 | SPELL （符卡） · 270 · FDF-082 | spell-fdf-082 |
| [spell-fdf-084](../cards/spell-fdf-084.json) | 「守护ノ要石」 | 符卡 | 是 | SPELL （符卡） · 272 · FDF-084 | spell-fdf-084 |
| [spell-fdf-085](../cards/spell-fdf-085.json) | 「5:30 PM」 | 符卡 | 是 | SPELL （符卡） · 273 · FDF-085 | spell-fdf-085 |
| [spell-fdf-086](../cards/spell-fdf-086.json) | 「全人类ノ绯想天」 | 符卡 | 是 | SPELL （符卡） · 274 · FDF-086 | spell-fdf-086 |
| [spell-fdf-087](../cards/spell-fdf-087.json) | 秘术「遗忘ノ祭仪」 | 符卡 | 是 | SPELL （符卡） · 275 · FDF-087 | spell-fdf-087 |
| [spell-fdf-088](../cards/spell-fdf-088.json) | 「Wall of Issun」 | 符卡 | 是 | SPELL （符卡） · 276 · FDF-088 | spell-fdf-088 |
| [spell-fdf-120](../cards/spell-fdf-120.json) | 「天空の魔法使」 | 符卡 | 是 | SPELL （符卡） · 277 · FDF-120 | spell-fdf-120 |
| [spell-fdf-121](../cards/spell-fdf-121.json) | 赎罪「旧地狱的针山」 | 符卡 | 是 | SPELL （符卡） · 278 · FDF-121 | spell-fdf-121 |
| [spell-fdf-122](../cards/spell-fdf-122.json) | 光晕「唐伞惊吓闪光」 | 符卡 | 是 | SPELL （符卡） · 279 · FDF-122 | spell-fdf-122 |
| [spell-fdf-123](../cards/spell-fdf-123.json) | 雨符「雨夜ノ怪谈」 | 符卡 | 是 | SPELL （符卡） · 280 · FDF-123 | spell-fdf-123 |
| [spell-fdn-001](../cards/spell-fdn-001.json) | 「飘上月球、不死之烟」 | 符卡 | 是 | SPELL （符卡） · 307 · FDN-001 | spell-fdn-001 |
| [spell-fdn-002](../cards/spell-fdn-002.json) | 蓬莱「凯风快晴-Fujiyama Volcano-」 | 符卡 | 是 | SPELL （符卡） · 308 · FDN-002 | spell-fdn-002 |
| [spell-fdn-003](../cards/spell-fdn-003.json) | 不死「火鳥-鳳翼天翔-」 | 符卡 | 是 | SPELL （符卡） · 309 · FDN-003 | spell-fdn-003 |
| [spell-fdn-005](../cards/spell-fdn-005.json) | 「U.N.OWEN 就是她吗？」 | 符卡 | 是 | SPELL （符卡） · 310 · FDN-005 | spell-fdn-005 |
| [spell-fdn-008](../cards/spell-fdn-008.json) | 夜王「Deacula Cradle」 | 符卡 | 是 | SPELL （符卡） · 311 · FDN-008 | spell-fdn-008 |
| [spell-fdn-009](../cards/spell-fdn-009.json) | 「不详」 | 符卡 | 是 | SPELL （符卡） · 312 · FDN-009 | spell-fdn-009 |
| [spell-fdn-010](../cards/spell-fdn-010.json) | 「幼心ノ地，有顶天变」 | 符卡 | 是 | SPELL （符卡） · 313 · FDN-010 | spell-fdn-010 |
| [spell-fdn-011](../cards/spell-fdn-011.json) | 结界「魅力ノ四重结界」 | 符卡 | 是 | SPELL （符卡） · 314 · FDN-011 | spell-fdn-011 |
| [spell-fdn-012](../cards/spell-fdn-012.json) | 魂魄「幽冥求闻持聪ノ法」 | 符卡 | 是 | SPELL （符卡） · 315 · FDN-012 | spell-fdn-012 |
| [spell-fdn-015](../cards/spell-fdn-015.json) | 雾符「云集雾散」 | 符卡 | 是 | SPELL （符卡） · 316 · FDN-015 | spell-fdn-015 |
| [spell-fdn-017](../cards/spell-fdn-017.json) | QED「495年ノ波纹」 | 符卡 | 是 | SPELL （符卡） · 317 · FDN-017 | spell-fdn-017 |
| [spell-fdn-018](../cards/spell-fdn-018.json) | 死歌「八重雾中渡」 | 符卡 | 是 | SPELL （符卡） · 318 · FDN-018 | spell-fdn-018 |
| [spell-fdn-019](../cards/spell-fdn-019.json) | 死价「price of life」 | 符卡 | 是 | SPELL （符卡） · 319 · FDN-019 | spell-fdn-019 |
| [spell-fdn-020](../cards/spell-fdn-020.json) | 「白玉楼ノ夕」 | 符卡 | 是 | SPELL （符卡） · 320 · FDN-020 | spell-fdn-020 |
| [spell-fdn-022](../cards/spell-fdn-022.json) | 「冰精ノ花环」 | 符卡 | 是 | SPELL （符卡） · 321 · FDN-022 | spell-fdn-022 |
| [spell-fdn-023](../cards/spell-fdn-023.json) | 小弹「小人ノ道路」 | 符卡 | 是 | SPELL （符卡） · 322 · FDN-023 | spell-fdn-023 |
| [spell-fdn-028](../cards/spell-fdn-028.json) | 生药「国士无双ノ药」 | 符卡 | 是 | SPELL （符卡） · 323 · FDN-028 | spell-fdn-028 |
| [spell-fdn-029](../cards/spell-fdn-029.json) | 「昼酒」 | 符卡 | 是 | SPELL （符卡） · 324 · FDN-029 | spell-fdn-029 |
| [spell-fdn-030](../cards/spell-fdn-030.json) | 「根下」 | 符卡 | 是 | SPELL （符卡） · 325 · FDN-030 | spell-fdn-030 |
| [spell-fdn-031](../cards/spell-fdn-031.json) | 天符「天道是非ノ剑」 | 符卡 | 是 | SPELL （符卡） · 326 · FDN-031 | spell-fdn-031 |
| [spell-fdn-032](../cards/spell-fdn-032.json) | 「幻波ノ影、狂气ノ瞳」 | 符卡 | 是 | SPELL （符卡） · 327 · FDN-032 | spell-fdn-032 |
| [spell-fdn-033](../cards/spell-fdn-033.json) | 回忆「恐怖催眠术」 | 符卡 | 是 | SPELL （符卡） · 328 · FDN-033 | spell-fdn-033 |
| [spell-fdn-039](../cards/spell-fdn-039.json) | 突符「天狗巨漾流」 | 符卡 | 是 | SPELL （符卡） · 329 · FDN-039 | spell-fdn-039 |
| [spell-fdn-040](../cards/spell-fdn-040.json) | 「凭坐ノ缚」 | 符卡 | 是 | SPELL （符卡） · 331 · FDN-040 | spell-fdn-040 |
| [spell-fdn-046](../cards/spell-fdn-046.json) | 实验中「歌莉娅人形」 | 符卡 | 是 | SPELL （符卡） · 332 · FDN-046 | spell-fdn-046 |
| [spell-htk-004](../cards/spell-htk-004.json) | 「奏中ノ能乐、亡失ノ感情」 | 符卡 | 是 | SPELL （符卡） · 139 · HTK-004 | spell-htk-004 |
| [spell-kmo-003](../cards/spell-kmo-003.json) | 塞符「天上天下的照国」 | 符卡 | 是 | SPELL （符卡） · 77 · KMO-003 | spell-kmo-003 |
| [spell-lof-006](../cards/spell-lof-006.json) | 「可爱ノ妖精叠奏曲」 | 符卡 | 是 | SPELL （符卡） · 128 · LOF-006 | spell-lof-006 |
| [spell-rec-054](../cards/spell-rec-054.json) | 小槌「变大吧」 | 符卡 | 是 | SPELL （符卡） · 168 · REC-054 | spell-rec-054 |
| [spell-rec-055](../cards/spell-rec-055.json) | 开海「摩西ノ奇迹」 | 符卡 | 是 | SPELL （符卡） · 169 · REC-055 | spell-rec-055 |
| [spell-rec-056](../cards/spell-rec-056.json) | 塞符「天上天下ノ照国」 | 符卡 | 是 | SPELL （符卡） · 170 · REC-056 | spell-rec-056 |
| [spell-smm-002](../cards/spell-smm-002.json) | 小锤「变大吧」 | 符卡 | 是 | SPELL （符卡） · 86 · SMM-002 | spell-smm-002 |
| [spell-smm-003](../cards/spell-smm-003.json) | 开海「摩根的奇迹」 | 符卡 | 是 | SPELL （符卡） · 87 · SMM-003 | spell-smm-003 |
| [spell-soi-119](../cards/spell-soi-119.json) | 幻巢「飞光虫ノ巢」 | 符卡 | 是 | SPELL （符卡） · 23 · SOI-119 | spell-soi-119 |
| [spell-ucs-004](../cards/spell-ucs-004.json) | 「起床ノ地灵殿」 | 符卡 | 是 | SPELL （符卡） · 94 · UCS-004 | spell-ucs-004 |
| [spell-ucs-009](../cards/spell-ucs-009.json) | 「月ノ闲暇」 | 符卡 | 是 | SPELL （符卡） · 97 · UCS-009 | spell-ucs-009 |
| [spell-ucs-015](../cards/spell-ucs-015.json) | 「神ノ通径」 | 符卡 | 是 | SPELL （符卡） · 100 · UCS-015 | spell-ucs-015 |
| [spell-ucs-018](../cards/spell-ucs-018.json) | 「鲸落」 | 符卡 | 是 | SPELL （符卡） · 101 · UCS-018 | spell-ucs-018 |
| [spell-ucs-022](../cards/spell-ucs-022.json) | 「世界ノ间隙·大空魔术」 | 符卡 | 是 | SPELL （符卡） · 103 · UCS-022 | spell-ucs-022 |
| [spell-ucs-031](../cards/spell-ucs-031.json) | 时符「Private Square」 | 符卡 | 是 | SPELL （符卡） · 108 · UCS-031 | spell-ucs-031 |
| [spell-ucs-033](../cards/spell-ucs-033.json) | 「神明ノ威光」 | 符卡 | 是 | SPELL （符卡） · 109 · UCS-033 | spell-ucs-033 |
| [spell-ucs-035](../cards/spell-ucs-035.json) | 花符「幻想乡ノ开花」 | 符卡 | 是 | SPELL （符卡） · 110 · UCS-035 | spell-ucs-035 |
| [spell-ucs-037](../cards/spell-ucs-037.json) | 「花ノ都」 | 符卡 | 是 | SPELL （符卡） · 111 · UCS-037 | spell-ucs-037 |
| [spell-ucs-039](../cards/spell-ucs-039.json) | 神志「思兼ノ意志」 | 符卡 | 是 | SPELL （符卡） · 112 · UCS-039 | spell-ucs-039 |
| [spell-ucs-041](../cards/spell-ucs-041.json) | 日符「皇家烈焰」 | 符卡 | 是 | SPELL （符卡） · 113 · UCS-041 | spell-ucs-041 |
| [spell-ucs-043](../cards/spell-ucs-043.json) | 后符「秘神ノ后光」 | 符卡 | 是 | SPELL （符卡） · 114 · UCS-043 | spell-ucs-043 |
| [spell-ucs-050](../cards/spell-ucs-050.json) | 雨符「虹彩细雨」 | 符卡 | 是 | SPELL （符卡） · 118 · UCS-050 | spell-ucs-050 |
| [spell-ucs-052](../cards/spell-ucs-052.json) | 「雾川」 | 符卡 | 是 | SPELL （符卡） · 119 · UCS-052 | spell-ucs-052 |
| [spell-ucs-054](../cards/spell-ucs-054.json) | 「永夜归返-丑ノ刻-」 | 符卡 | 是 | SPELL （符卡） · 120 · UCS-054 | spell-ucs-054 |
| [spell-ucs-057](../cards/spell-ucs-057.json) | 光符「最初ノ人形」 | 符卡 | 是 | SPELL （符卡） · 121 · UCS-057 | spell-ucs-057 |
| [spell-ucs-059](../cards/spell-ucs-059.json) | 「承诏必慎」 | 符卡 | 是 | SPELL （符卡） · 122 · UCS-059 | spell-ucs-059 |
| [token-fdf-127](../cards/token-fdf-127.json) | 烤八目鳗 | 道具 | 否 | TOKEN (衍生物） · 15 · FDF-127 | token-fdf-127 |
| [token-fdf-129](../cards/token-fdf-129.json) | 要石 | 结界 | 否 | TOKEN (衍生物） · 17 · FDF-129 | token-fdf-129 |
| [token-fdf-131](../cards/token-fdf-131.json) | 不明物体 | 单位 | 否 | TOKEN (衍生物） · 19 · FDF-131 | token-fdf-131 |
| [token-fdn-082](../cards/token-fdn-082.json) | 新闻素材 | 道具 | 否 | TOKEN (衍生物） · 24 · FDN-082 | token-fdn-082 |
